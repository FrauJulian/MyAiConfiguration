import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parent.parent.parent
SPEC = importlib.util.spec_from_file_location('install_options', ROOT / 'scripts/lib/install-options.py')
OPTIONS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(OPTIONS)


class InstallOptionsTests(unittest.TestCase):
    def test_merge_toml_preserves_local_plugin_table_indentation(self):
        plugin_state = ('  [marketplaces.ponytail]\n'
                        '    source_type = "git"\n'
                        '    source = "https://github.com/DietrichGebert/ponytail.git"\n'
                        '  [plugins."ponytail@ponytail"]\n'
                        '    enabled = true\n'
                        '  [plugins."disabled@market"]\n'
                        '    enabled = false')
        current = "model = 'old'\napprovals_reviewer = 'user'\n" + plugin_state + '\n'
        managed = "approvals_reviewer = 'auto_review'\n\n[tui]\n"

        result = OPTIONS.merge_toml(current, managed)

        self.assertIn(plugin_state, result)

    def test_merge_toml_preserves_unmanaged_tables(self):
        foreign = ('[mcp_servers.demo]\ncommand = "demo"\n\n[mcp_servers.demo.env]\nTOKEN_NAME = "x"\n\n'
                   '[model_providers.custom]\nname = "Custom"\nbase_url = "https://example.invalid"\n')
        current = "model = 'old'\n\n[tui]\nstatus_line = ['a']\ntheme = 'dark'\n\n" + foreign
        managed = "model = 'new'\n\n[tui]\nstatus_line = ['b']\n"

        result = tomllib.loads(OPTIONS.merge_toml(current, managed))

        self.assertEqual(result['model'], 'new')
        self.assertEqual(result['tui'], {'status_line': ['b'], 'theme': 'dark'})
        self.assertEqual(result['mcp_servers'], {'demo': {'command': 'demo', 'env': {'TOKEN_NAME': 'x'}}})
        self.assertEqual(result['model_providers'], {'custom': {'name': 'Custom', 'base_url': 'https://example.invalid'}})

    def test_merge_json_removes_only_owned_hooks_from_mixed_group(self):
        owned = {'type': 'command', 'command': 'bash "/old/hooks/flashbang.sh"', 'timeout': 8}
        foreign = {'type': 'command', 'command': 'notify-done', 'timeout': 3}
        current = {'hooks': {'Stop': [{'matcher': 'custom', 'hooks': [owned, foreign]}],
                             'PreCompact': [{'hooks': [{'type': 'command', 'command': 'bash "/old/record-compact.sh"'}]}]}}
        managed_stop = {'hooks': [{'type': 'command', 'command': 'bash "/new/hooks/flashbang.sh"', 'timeout': 8}]}
        managed = {'hooks': {'Stop': [managed_stop], 'PreCompact': []}}

        hooks = OPTIONS.merge_json(current, managed)['hooks']

        self.assertEqual(hooks['Stop'], [managed_stop, {'matcher': 'custom', 'hooks': [foreign]}])
        self.assertNotIn('PreCompact', hooks)

    def test_merge_cli_accepts_bom_input_and_preserves_non_ascii(self):
        with tempfile.TemporaryDirectory() as directory:
            current = Path(directory) / 'config.toml'
            current.write_text('# Größe\n[mcp_servers.demo]\ncommand = "ä"\n', encoding='utf-8')
            output = Path(directory) / 'out.toml'
            script = str(ROOT / 'scripts/lib/install-options.py')
            managed = '﻿model = "new"\n'.encode('utf-8')
            piped = subprocess.run([sys.executable, script, 'merge-toml', '--current', str(current), '--output', str(output)], input=managed)
            self.assertEqual(piped.returncode, 0)
            self.assertEqual(tomllib.loads(output.read_text(encoding='utf-8'))['mcp_servers']['demo']['command'], 'ä')
            managed_path = Path(directory) / 'managed.toml'
            managed_path.write_bytes(managed)
            subprocess.run([sys.executable, script, 'merge-toml', '--current', str(current), '--managed', str(managed_path), '--output', str(output)], check=True)
            self.assertIn('# Größe', output.read_text(encoding='utf-8'))

    def test_semantic_retrieval_disabled_removes_qmd_session_hook(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = Path(directory) / 'settings.json'
            settings.write_text(json.dumps({'hooks': {'SessionStart': [
                {'hooks': [{'type': 'command', 'command': 'bash "/c/hooks/scripts/show-session-state-pointer.sh"'}]},
                {'hooks': [{'type': 'command', 'command': 'bash "/c/hooks/scripts/qmd-warm.sh"'}]}]}}), encoding='utf-8')
            result = json.loads(OPTIONS.filter_options(settings, semantic_retrieval_enabled=False))
            commands = [hook['command'] for group in result['hooks']['SessionStart'] for hook in group['hooks']]
            self.assertEqual(commands, ['bash "/c/hooks/scripts/show-session-state-pointer.sh"'])

    def test_semantic_retrieval_disabled_removes_codex_session_hook(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'config.toml'
            config.write_text('[features]\nhooks = true\n\n[[hooks.SessionStart]]\n[[hooks.SessionStart.hooks]]\ntype = "command"\n'
                              'command = \'bash "/c/hooks/scripts/qmd-warm.sh"\'\ncommand_windows = \'pwsh "/c/hooks/scripts/Start-QmdWarm.ps1"\'\ntimeout = 4\n',
                              encoding='utf-8')
            result = OPTIONS.filter_options(config, semantic_retrieval_enabled=False)
            self.assertNotIn('qmd-warm', result)
            self.assertNotIn('hooks.SessionStart', result)

    def test_instruction_line_only_with_semantic_search(self):
        text = 'Line one.\nWhen `semantic-search` is installed, run it first.\nLine three.\n'
        self.assertEqual(OPTIONS.filter_instructions(text, False), 'Line one.\nLine three.\n')
        self.assertEqual(OPTIONS.filter_instructions(text, True), text)

    def test_qmd_warm_match_is_anchored(self):
        self.assertTrue(OPTIONS.is_qmd_warm({'command': 'bash "/c/hooks/scripts/qmd-warm.sh"'}))
        self.assertTrue(OPTIONS.is_qmd_warm({'command_windows': 'pwsh "C:\hooks\Start-QmdWarm.ps1"'}))
        self.assertFalse(OPTIONS.is_qmd_warm({'command': 'bash "/c/hooks/scripts/my-qmd-warm.sh"'}))

    def test_merge_json_keeps_user_session_hook_and_drops_qmd_when_disabled(self):
        user = {'type': 'command', 'command': 'bash "/home/me/my-start.sh"'}
        pointer = {'type': 'command', 'command': 'bash "/c/hooks/scripts/show-session-state-pointer.sh"'}
        qmd = {'type': 'command', 'command': 'bash "/c/hooks/scripts/qmd-warm.sh"'}
        current = {'hooks': {'SessionStart': [{'hooks': [user]}]}}
        managed = {'hooks': {'SessionStart': [{'hooks': [pointer]}, {'hooks': [qmd]}]}}
        once = OPTIONS.merge_json(current, managed)
        twice = OPTIONS.merge_json(once, managed)
        self.assertEqual(twice['hooks']['SessionStart'], [{'hooks': [pointer]}, {'hooks': [qmd]}, {'hooks': [user]}])
        disabled = OPTIONS.merge_json(twice, {'hooks': {'SessionStart': [{'hooks': [pointer]}]}})
        commands = [hook['command'] for group in disabled['hooks']['SessionStart'] for hook in group['hooks']]
        self.assertEqual(commands, [pointer['command'], user['command']])
        removed = OPTIONS.merge_json(twice, {'hooks': {}})
        self.assertEqual(removed['hooks']['SessionStart'], [{'hooks': [user]}])

    def test_merge_toml_hook_groups_do_not_grow_and_user_hook_survives(self):
        managed = ('[features]\nhooks = true\n\n[[hooks.SessionStart]]\n[[hooks.SessionStart.hooks]]\ntype = "command"\n'
                   'command = \'bash "/c/hooks/scripts/qmd-warm.sh"\'\n\n[[hooks.Stop]]\n[[hooks.Stop.hooks]]\ntype = "command"\n'
                   'command = \'bash "/c/hooks/flashbang.sh"\'\n')
        user = '\n[[hooks.SessionStart]]\n[[hooks.SessionStart.hooks]]\ntype = "command"\ncommand = \'bash "/home/me/my-start.sh"\'\n'
        text = managed + user
        for _ in range(3):
            text = OPTIONS.merge_toml(text, managed)
        hooks = tomllib.loads(text)['hooks']
        self.assertEqual(len(hooks['Stop']), 1)
        self.assertEqual(len(hooks['SessionStart']), 2)
        commands = [hook['command'] for group in hooks['SessionStart'] for hook in group['hooks']]
        self.assertEqual(sorted(commands), ['bash "/c/hooks/scripts/qmd-warm.sh"', 'bash "/home/me/my-start.sh"'])
        disabled = OPTIONS.merge_toml(text, '[features]\nhooks = true\n')
        hooks = tomllib.loads(disabled)['hooks']
        self.assertNotIn('Stop', hooks)
        self.assertEqual([hook['command'] for group in hooks['SessionStart'] for hook in group['hooks']], ['bash "/home/me/my-start.sh"'])

    def test_filter_preserves_other_claude_hooks_and_status(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'settings.json'
            settings = {'hooks': {'Stop': [{'hooks': [
                {'command': 'bash "root/hooks/flashbang.sh"'}, {'command': 'echo keep'}]}],
                'PreCompact': [{'hooks': [{'command': 'echo compact'}]}]},
                'statusLine': {'command': 'echo status'}}
            path.write_text(json.dumps(settings))
            result = json.loads(OPTIONS.filter_flashbang(path))
            self.assertEqual(result['hooks']['Stop'][0]['hooks'], [{'command': 'echo keep'}])
            self.assertEqual(result['hooks']['PreCompact'], settings['hooks']['PreCompact'])
            self.assertEqual(result['statusLine'], settings['statusLine'])

    def test_filter_preserves_other_codex_stop_hooks_and_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.toml'
            path.write_text('approval_policy = "on-request"\n[[hooks.Stop]]\n'
                            '[[hooks.Stop.hooks]]\ncommand = \'bash "root/flashbang.sh"\'\n'
                            '[[hooks.Stop.hooks]]\ncommand = "echo keep"\n'
                            '[tui]\nstatus_line = ["model"]\n')
            result = tomllib.loads(OPTIONS.filter_flashbang(path))
            self.assertEqual(result['hooks']['Stop'][0]['hooks'], [{'command': 'echo keep'}])
            self.assertEqual(result['tui']['status_line'], ['model'])

    def test_flashbang_toggle_is_applied_by_both_manifest_writers(self):
        shells = [('powershell', shutil.which('powershell') or shutil.which('pwsh')),
                  ('bash', str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
                   if os.name == 'nt' else shutil.which('bash'))]
        for kind, executable in shells:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=kind), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / 'source'
                source.mkdir()
                destination = Path(directory) / 'destination'
                settings = {'hooks': {'Stop': [{'hooks': [{'command': 'bash "__AI_CONFIG_ROOT__/flashbang.sh"'}]}],
                                      'PreCompact': [{'hooks': [{'command': 'echo keep'}]}]}}
                (source / 'settings.json').write_text(json.dumps(settings))
                (source / 'config.toml').write_text('[[hooks.Stop]]\n[[hooks.Stop.hooks]]\n'
                                                   'command = \'bash "__AI_CONFIG_ROOT__/flashbang.sh"\'\n')
                environment = dict(os.environ, OPTION_SOURCE=str(source), OPTION_DESTINATION=str(destination))
                for enabled in (False, True):
                    if kind == 'powershell':
                        command = [executable, '-NoProfile', '-Command',
                                   "$ErrorActionPreference='Stop'; . ./scripts/lib/manifest.ps1; "
                                   "Sync-ManagedDestination -Source $env:OPTION_SOURCE -Destination $env:OPTION_DESTINATION "
                                   "-Stamp test -AiConfigRoot root -ShellCommand bash -PowerShellCommand pwsh "
                                   "-Summary -FlashbangEnabled $" + str(enabled).lower()]
                    else:
                        command = [executable, '-c',
                                   'set -euo pipefail; . ./scripts/lib/manifest.sh; '
                                   'sync_managed_destination "$OPTION_SOURCE" "$OPTION_DESTINATION" test root bash pwsh false true '
                                   + str(enabled).lower()]
                        environment.update(OPTION_SOURCE=source.as_posix(), OPTION_DESTINATION=destination.as_posix())
                    result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    installed = json.loads((destination / 'settings.json').read_text(encoding='utf-8-sig'))
                    self.assertEqual('Stop' in installed['hooks'], enabled)
                    self.assertIn('PreCompact', installed['hooks'])
                    codex = tomllib.loads((destination / 'config.toml').read_text(encoding='utf-8-sig'))
                    self.assertEqual(bool(codex.get('hooks', {}).get('Stop')), enabled)
                    self.assertTrue((destination / '.ai-config-manifest.tsv').is_file())

    def test_entrypoints_save_normal_choices_and_replay_quick_without_prompts(self):
        executables = [('powershell', shutil.which('powershell') or shutil.which('pwsh')),
                       ('bash', str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
                        if os.name == 'nt' else shutil.which('bash'))]
        for kind, executable in executables:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'repo'
                scripts = root / 'scripts'
                commands = scripts / 'commands'
                commands.mkdir(parents=True)
                shutil.copytree(ROOT / 'scripts/lib', scripts / 'lib', ignore=shutil.ignore_patterns('__pycache__'))
                home = Path(directory) / 'home'
                home.mkdir()
                (root / 'adapters').mkdir()
                shutil.copyfile(ROOT / 'adapters/plugins.tsv', root / 'adapters/plugins.tsv')
                for client in ('codex', 'claude'):
                    package = root / 'generated' / (client + '-bash')
                    (package / 'skills').mkdir(parents=True)
                    (package / 'skills' / 'test.txt').write_text('managed')
                    if client == 'claude':
                        (package / 'statusline').mkdir()
                        (package / 'statusline' / 'statusline.sh').write_text('managed status line')
                    config = ('[[hooks.Stop]]\n[[hooks.Stop.hooks]]\ncommand = \'bash "__AI_CONFIG_ROOT__/flashbang.sh"\'\n'
                              '[tui]\nstatus_line = ["model"]\n' if client == 'codex' else
                              '{"hooks":{"Stop":[{"hooks":[{"command":"bash flashbang.sh"}]}]},'
                              '"statusLine":{"type":"command","command":"bash statusline.sh"}}')
                    (package / ('config.toml' if client == 'codex' else 'settings.json')).write_text(config)
                suffix = 'ps1' if kind == 'powershell' else 'sh'
                for name in ('install', 'update'):
                    content = (ROOT / 'scripts/commands' / (name + '.' + suffix)).read_text(encoding='utf-8-sig')
                    content = content.replace("[Environment]::GetFolderPath('UserProfile')", '$env:TEST_INSTALL_HOME')
                    (commands / (name + '.' + suffix)).write_text(content)
                (commands / ('build.' + suffix)).write_text('param([switch]$Summary)' if kind == 'powershell' else 'exit 0\n')
                if kind == 'powershell':
                    (scripts / 'lib/plugins.ps1').write_text(
                        'function Select-ConfiguredPlugins { @{Selected=@(); Deselected=@()} }\n'
                        'function Get-ConfiguredPluginEntries { @() }\n'
                        'function Sync-ConfiguredPlugins {}\n'
                        'function Invoke-PluginCommand { param($Command,$Arguments,[switch]$DryRun,[switch]$Summary) '
                        'Write-Output "CLI-MOCK $Command" }\n')
                else:
                    (scripts / 'lib/plugins.sh').write_text(
                        'select_configured_plugins() { :; }\nsync_configured_plugins() { :; }\n'
                        'run_plugin_command() { printf "CLI-MOCK %s\\n" "$2"; }\n')
                environment = dict(os.environ, HOME=home.as_posix(), TEST_INSTALL_HOME=str(home))
                for name, quick, answers in [('install', False, 'n\nn\nn\n'), ('update', True, '')]:
                    entry = str(commands / (name + '.' + suffix))
                    command = ([executable, '-NoProfile', '-File', entry, '-Shell', 'Bash', '-Client', 'Both', '-Summary']
                               if kind == 'powershell' else [executable, entry, '--shell', 'bash', '--client', 'both', '--summary'])
                    if quick:
                        command.append('-Quick' if kind == 'powershell' else '--quick')
                    result = subprocess.run(command, env=environment, input=answers, capture_output=True, text=True, timeout=25)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn('CLI-MOCK', result.stdout)
                    if quick:
                        self.assertNotIn('Enable the Flashbang', result.stdout + result.stderr)
                        self.assertNotIn('Apply the custom status line', result.stdout + result.stderr)
                    state = json.loads((home / '.my-ai-configuration/selection.json').read_text())
                    self.assertFalse(state['flashbang'])
                    self.assertFalse(state['statusline'])
                    self.assertEqual(state['shell'], 'bash')
                    self.assertNotIn('Stop', json.loads((home / '.claude/settings.json').read_text()).get('hooks', {}))
                    self.assertNotIn('statusLine', json.loads((home / '.claude/settings.json').read_text()))
                    self.assertFalse((home / '.claude/statusline/statusline.sh').exists())
                    self.assertNotIn('status_line', tomllib.loads((home / '.codex/config.toml').read_text()).get('tui', {}))


if __name__ == '__main__':
    unittest.main()
