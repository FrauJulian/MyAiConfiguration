import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('extensions', Path(__file__).parents[2] / 'scripts/lib/managed-extensions.py')
extensions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extensions)


def plugin(name='Example'):
    return dict(name=name, codex_method='plugin', codex_plugin=name.lower() + '@test', codex_marketplace='-',
                claude_plugin=name.lower() + '@test', claude_marketplace='-')


def skill():
    return dict(name='Humanizer', codex_method='skill', codex_source='blader/humanizer', codex_skill='humanizer', codex_plugin='-')


def mcporter():
    return dict(name='MCPorter', codex_method='cli', codex_source='mcporter', codex_plugin='-', codex_marketplace='-', claude_plugin='-', claude_marketplace='-')


def mcp():
    return dict(name='Context7', codex_method='plugin', codex_plugin='context7@test', codex_marketplace='-',
                claude_plugin='context7@test', claude_marketplace='-', mcporter_name='context7',
                mcporter_url='https://mcp.context7.com/mcp')


class ManagedExtensionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.installed = {'codex': {}, 'claude': {}}
        self.commands = []
        self.addCleanup(patch.stopall)
        patch.object(extensions, 'installed_plugins', side_effect=lambda client, home: dict(self.installed[client])).start()
        patch.object(extensions, 'run_command', side_effect=self.command).start()
        patch.object(extensions, 'fetch_skill', return_value=('humanizer', {'SKILL.md': (b'original', False), 'references/old.md': (b'old', False)})).start()
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def command(self, args, summary, home=None):
        self.commands.append(args)
        if len(args) > 3 and args[2] in ('add', 'install') and args[1] == 'plugin':
            self.installed[args[0]][args[3]] = {'scope': 'user'}
        if args[2] in ('remove', 'uninstall'):
            self.installed[args[0]].pop(args[3], None)
        return ''

    def manager(self, **kwargs):
        return extensions.Manager(self.home, **kwargs)

    def test_foreign_plugin_is_never_claimed_or_removed(self):
        self.installed['codex']['example@test'] = {}
        self.manager(update=True).sync([plugin()], ['codex'], {'Example'})
        self.manager().sync([], ['codex'], set())
        self.assertEqual([], self.commands)
        self.assertEqual([], self.manager().state['resources'])

    def test_owned_plugin_removed_after_manifest_entry_disappears(self):
        self.manager().sync([plugin()], ['codex'], {'Example'})
        self.manager().sync([], ['codex'], set())
        self.assertEqual(['codex', 'plugin', 'remove', 'example@test'], self.commands[-1])
        self.assertEqual([], self.manager().state['resources'])

    def test_client_scope_is_preserved(self):
        self.manager().sync([plugin()], ['claude', 'codex'], {'Example'})
        self.manager().sync([], ['codex'], set())
        self.assertEqual(['claude'], [r['client'] for r in self.manager().state['resources']])

    def test_partial_plugin_failure_retains_successful_ownership(self):
        with patch.object(extensions, 'run_command', side_effect=[None, ValueError('failure')]):
            with self.assertRaises(ValueError):
                self.manager().sync([plugin(), plugin('Second')], ['codex'], {'Example', 'Second'})
        self.assertEqual(['Example'], [r['name'] for r in self.manager().state['resources']])

    def test_failed_removal_retains_ownership(self):
        self.manager().sync([plugin()], ['codex'], {'Example'})
        with patch.object(extensions, 'run_command', side_effect=ValueError('failure')):
            with self.assertRaises(ValueError):
                self.manager().sync([], ['codex'], set())
        self.assertEqual(1, len(self.manager().state['resources']))

    def test_foreign_skill_directory_is_preserved(self):
        target = self.home / '.agents/skills/humanizer/SKILL.md'
        target.parent.mkdir(parents=True)
        target.write_text('foreign')
        self.manager(update=True).sync([skill()], ['codex'], {'Humanizer'})
        self.manager().sync([], ['codex'], set())
        self.assertEqual('foreign', target.read_text())
        self.assertEqual([], self.manager().state['resources'])

    def test_skill_removal_preserves_modified_and_foreign_files(self):
        self.manager().sync([skill()], ['codex'], {'Humanizer'})
        directory = self.home / '.agents/skills/humanizer'
        (directory / 'SKILL.md').write_text('modified')
        (directory / 'foreign.txt').write_text('foreign')
        self.manager().sync([], ['codex'], set())
        self.assertEqual('modified', (directory / 'SKILL.md').read_text())
        self.assertTrue((directory / 'foreign.txt').exists())
        self.assertFalse((directory / 'references/old.md').exists())
        self.assertEqual(1, len(self.manager().state['resources'][0]['files']))

    def test_skill_update_cleans_only_owned_stale_files(self):
        self.manager().sync([skill()], ['codex'], {'Humanizer'})
        directory = self.home / '.agents/skills/humanizer'
        (directory / 'foreign.txt').write_text('foreign')
        with patch.object(extensions, 'fetch_skill', return_value=('humanizer', {'SKILL.md': (b'new', False)})):
            self.manager(update=True).sync([skill()], ['codex'], {'Humanizer'})
        self.assertEqual('new', (directory / 'SKILL.md').read_text())
        self.assertTrue((directory / 'foreign.txt').exists())
        self.assertFalse((directory / 'references/old.md').exists())

    def test_skill_records_resolved_revision(self):
        with patch.object(extensions, 'resolve_revision', return_value='a' * 40):
            self.manager().sync([skill()], ['codex'], {'Humanizer'})
        record = self.manager().state['resources'][0]
        self.assertEqual(record['source'], 'blader/humanizer')
        self.assertEqual(record['resolvedRevision'], 'a' * 40)

    def test_skill_partial_failure_records_each_successful_file(self):
        original_write = extensions.atomic_write
        def write(path, content):
            if path.name == 'old.md':
                raise OSError('simulated disk failure')
            original_write(path, content)
        with patch.object(extensions, 'atomic_write', side_effect=write):
            with self.assertRaises(OSError):
                self.manager().sync([skill()], ['codex'], {'Humanizer'})
        self.assertEqual(['.agents/skills/humanizer/SKILL.md'], list(self.manager().state['resources'][0]['files']))
        self.manager().sync([skill()], ['codex'], {'Humanizer'})
        self.assertEqual(2, len(self.manager().state['resources'][0]['files']))
        self.assertTrue(self.manager().state['resources'][0]['complete'])

    def test_dry_run_has_no_commands_network_or_writes(self):
        self.manager(dry_run=True).sync([plugin(), skill()], ['codex'], {'Example', 'Humanizer'})
        self.assertEqual([], list(self.home.iterdir()))
        self.assertEqual([], self.commands)
        extensions.fetch_skill.assert_not_called()

    def test_traversal_ledger_is_rejected(self):
        path = self.home / '.my-ai-configuration/extensions.json'
        path.parent.mkdir()
        path.write_text(json.dumps({'version': 1, 'resources': [dict(client='codex', name='Bad', kind='skill', directory='.agents/skills/bad', files={'.agents/skills/bad/../../../other': '0' * 64})]}))
        with self.assertRaises(ValueError):
            self.manager()

    def test_marketplace_failure_never_removes_existing_source(self):
        entry = plugin()
        entry['codex_marketplace'] = 'owner/repository'
        with patch.object(extensions, 'run_command', side_effect=ValueError('different source')) as command:
            with self.assertRaises(ValueError):
                self.manager().sync([entry], ['codex'], {'Example'})
        self.assertEqual(1, command.call_count)
        self.assertEqual('add', command.call_args.args[0][3])

    def test_owned_codex_update_upgrades_marketplace(self):
        entry = plugin()
        entry['codex_marketplace'] = 'owner/repository'
        self.manager().sync([entry], ['codex'], {'Example'})
        self.commands.clear()
        self.manager(update=True).sync([entry], ['codex'], {'Example'})
        self.assertEqual([['codex', 'plugin', 'marketplace', 'upgrade', 'test'], ['codex', 'plugin', 'add', 'example@test']], self.commands)

    def test_owned_disabled_claude_is_enabled(self):
        self.manager().sync([plugin()], ['claude'], {'Example'})
        self.installed['claude']['example@test']['enabled'] = False
        self.manager(update=True).sync([plugin()], ['claude'], {'Example'})
        self.assertEqual(['claude', 'plugin', 'enable', 'example@test'], self.commands[-1])

    def test_dry_run_summary_has_one_line(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.manager(dry_run=True, summary=True).sync([plugin(), skill()], ['codex'], {'Example', 'Humanizer'})
        self.assertEqual('EXTENSIONS: reconciliation complete (dry run)\n', output.getvalue())

    def test_qmd_installs_once_as_a_cli_without_registering_mcp(self):
        entry = dict(name='QMD', codex_method='qmd', codex_source='@tobilu/qmd', codex_skill='qmd', codex_plugin='-', codex_marketplace='-', claude_plugin='qmd@qmd', claude_marketplace='tobi/qmd')
        self.manager().sync([entry], ['codex'], {'QMD'})
        self.assertEqual([['npm', 'install', '--global', '@tobilu/qmd']], self.commands)
        self.manager().sync([], ['codex'], set())
        self.assertEqual(['npm', 'uninstall', '--global', '@tobilu/qmd'], self.commands[-1])

    def test_qmd_installs_once_for_both_clients(self):
        entry = dict(name='QMD', codex_method='qmd', codex_source='@tobilu/qmd', codex_skill='qmd', codex_plugin='-', codex_marketplace='-', claude_plugin='qmd@qmd', claude_marketplace='tobi/qmd')
        self.manager().sync([entry], ['claude', 'codex'], {'QMD'})
        self.assertEqual(1, self.commands.count(['npm', 'install', '--global', '@tobilu/qmd']))
        self.assertIn(['claude', 'plugin', 'install', 'qmd@qmd', '--scope', 'user'], self.commands)
        self.assertNotIn(['codex', 'mcp', 'add', 'qmd', '--', 'qmd', 'mcp'], self.commands)

    def test_mcporter_replaces_direct_context7_plugin(self):
        self.manager().sync([mcp(), mcporter()], ['codex'], {'Context7', 'MCPorter'})
        config = str(self.home / '.mcporter/mcporter.json')
        self.assertIn(['mcporter', '--config', config, 'config', 'add', 'context7', 'https://mcp.context7.com/mcp'], self.commands)
        self.assertNotIn(['codex', 'plugin', 'add', 'context7@test'], self.commands)

    def test_foreign_empty_directory_survives_skill_removal(self):
        self.manager().sync([skill()], ['codex'], {'Humanizer'})
        foreign = self.home / '.agents/skills/humanizer/foreign-empty'
        foreign.mkdir()
        self.manager().sync([], ['codex'], set())
        self.assertTrue(foreign.is_dir())

    def test_foreign_skill_link_is_preserved(self):
        foreign = self.home / 'foreign'
        foreign.mkdir()
        target = self.home / '.agents/skills/humanizer'
        target.parent.mkdir(parents=True)
        try:
            target.symlink_to(foreign, target_is_directory=True)
        except OSError:
            self.skipTest('Symbolic links are unavailable on this host.')
        self.manager().sync([skill()], ['codex'], {'Humanizer'})
        self.assertTrue(target.is_symlink())
        extensions.fetch_skill.assert_not_called()


class CommandTests(unittest.TestCase):
    def test_subprocess_uses_intended_home_and_cmd_launcher(self):
        with tempfile.TemporaryDirectory(prefix='managed extensions ') as temporary:
            home = Path(temporary)
            executable = home / ('mock.cmd' if os.name == 'nt' else 'mock')
            if os.name == 'nt':
                executable.write_text('@echo off\necho %CODEX_HOME%\necho %CLAUDE_CONFIG_DIR%\n')
            else:
                executable.write_text('#!/bin/sh\nprintf "%s\\n" "$CODEX_HOME" "$CLAUDE_CONFIG_DIR"\n')
                executable.chmod(0o700)
            with contextlib.redirect_stdout(io.StringIO()):
                result = extensions.run_command([str(executable), 'plugin', 'list', '--json'], True, home)
            self.assertEqual([str(home / '.codex'), str(home / '.claude')], result.splitlines())


if __name__ == '__main__':
    unittest.main()
