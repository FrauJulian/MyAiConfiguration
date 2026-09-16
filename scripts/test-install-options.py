import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('install_options', ROOT / 'scripts/lib/install-options.py')
OPTIONS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(OPTIONS)


class InstallOptionsTests(unittest.TestCase):
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

    def test_native_option_helpers_select_clients_and_restore_environment(self):
        shells = [('powershell', shutil.which('powershell') or shutil.which('pwsh')),
                  ('bash', str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
                   if os.name == 'nt' else shutil.which('bash'))]
        for kind, executable in shells:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=kind):
                if kind == 'powershell':
                    command = [executable, '-NoProfile', '-Command',
                               "$ErrorActionPreference='Stop'; . ./scripts/lib/install-options.ps1; "
                               "function Test-CodexProcessActive { $false }; function Test-GlobalNpmCodex { $false }; "
                               "function Invoke-PluginCommand { param($Command,$Arguments,[switch]$DryRun,[switch]$Summary) "
                               "Write-Output ($Command + ':' + ($Arguments -join ' ')) }; "
                               "$env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE='original'; "
                               "Update-SelectedAgentClis -Client Both; "
                               "if ($env:CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE -ne 'original') { throw 'Environment leaked' }"]
                else:
                    command = [executable, '-c',
                               '. ./scripts/lib/install-options.sh; '
                               'codex_process_active() { return 1; }; global_npm_codex() { return 1; }; '
                               'run_plugin_command() { shift; printf "%s:%s\\n" "$1" "$2"; }; '
                               'client=both; dry_run=false; summary=false; '
                               'CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=original; update_selected_agent_clis; '
                               '[ "$CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE" = original ]']
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stdout.splitlines(), ['codex:update', 'claude:update'])

    def test_running_codex_is_skipped_and_npm_install_is_used_when_available(self):
        shell = shutil.which('powershell') or shutil.which('pwsh')
        if shell:
            skipped = subprocess.run([
                shell, '-NoProfile', '-Command',
                "$ErrorActionPreference='Stop'; . ./scripts/lib/install-options.ps1; "
                "function Test-CodexProcessActive { $true }; function Test-GlobalNpmCodex { $true }; "
                "function Invoke-PluginCommand { param($Command,$Arguments,[switch]$DryRun,[switch]$Summary) Write-Output $Command }; "
                "Update-SelectedAgentClis -Client Both"
            ], cwd=ROOT, capture_output=True, text=True, timeout=20)
            self.assertEqual(skipped.returncode, 0, skipped.stdout + skipped.stderr)
            self.assertEqual(skipped.stdout.splitlines()[-1], 'claude')
            self.assertIn('Codex CLI update skipped', skipped.stdout + skipped.stderr)
            npm = subprocess.run([
                shell, '-NoProfile', '-Command',
                "$ErrorActionPreference='Stop'; . ./scripts/lib/install-options.ps1; "
                "function Test-CodexProcessActive { $false }; function Test-GlobalNpmCodex { $true }; "
                "function Invoke-PluginCommand { param($Command,$Arguments,[switch]$DryRun,[switch]$Summary) "
                "Write-Output ($Command + ':' + ($Arguments -join ' ')) }; Update-SelectedAgentClis -Client Codex"
            ], cwd=ROOT, capture_output=True, text=True, timeout=20)
            self.assertEqual(npm.returncode, 0, npm.stdout + npm.stderr)
            self.assertEqual(npm.stdout.strip(), 'npm:install -g @openai/codex@latest')

        bash = (str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
                if os.name == 'nt' else shutil.which('bash'))
        if bash and Path(bash).exists():
            result = subprocess.run([
                bash, '-c',
                '. ./scripts/lib/install-options.sh; codex_process_active() { return 0; }; '
                'global_npm_codex() { return 0; }; run_plugin_command() { shift; printf "%s\\n" "$1"; }; '
                'client=both; dry_run=false; summary=false; update_selected_agent_clis'
            ], cwd=ROOT, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['claude'])
            self.assertIn('Codex CLI update skipped', result.stderr)

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
                shutil.copytree(ROOT / 'scripts/lib', scripts / 'lib', ignore=shutil.ignore_patterns('__pycache__'))
                home = Path(directory) / 'home'
                home.mkdir()
                (root / 'adapters').mkdir()
                shutil.copyfile(ROOT / 'adapters/plugins.tsv', root / 'adapters/plugins.tsv')
                for client in ('codex', 'claude'):
                    package = root / 'generated' / (client + '-bash')
                    (package / 'skills').mkdir(parents=True)
                    (package / 'skills' / 'test.txt').write_text('managed')
                    config = ('[[hooks.Stop]]\n[[hooks.Stop.hooks]]\ncommand = \'bash "__AI_CONFIG_ROOT__/flashbang.sh"\'\n'
                              if client == 'codex' else '{"hooks":{"Stop":[{"hooks":[{"command":"bash flashbang.sh"}]}]}}')
                    (package / ('config.toml' if client == 'codex' else 'settings.json')).write_text(config)
                suffix = 'ps1' if kind == 'powershell' else 'sh'
                for name in ('install', 'update'):
                    content = (ROOT / 'scripts' / (name + '.' + suffix)).read_text(encoding='utf-8-sig')
                    content = content.replace("[Environment]::GetFolderPath('UserProfile')", '$env:TEST_INSTALL_HOME')
                    (scripts / (name + '.' + suffix)).write_text(content)
                (scripts / ('build.' + suffix)).write_text('param([switch]$Summary)' if kind == 'powershell' else 'exit 0\n')
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
                for name, quick, answers in [('install', False, 'y\nn\n'), ('update', True, '')]:
                    entry = str(scripts / (name + '.' + suffix))
                    command = ([executable, '-NoProfile', '-File', entry, '-Shell', 'Bash', '-Client', 'Both', '-Summary']
                               if kind == 'powershell' else [executable, entry, '--shell', 'bash', '--client', 'both', '--summary'])
                    if quick:
                        command.append('-Quick' if kind == 'powershell' else '--quick')
                    result = subprocess.run(command, env=environment, input=answers, capture_output=True, text=True, timeout=25)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertTrue('CLI-MOCK codex' in result.stdout or
                                    'Codex CLI update skipped' in result.stdout + result.stderr)
                    self.assertIn('CLI-MOCK claude', result.stdout)
                    if quick:
                        self.assertNotIn('Enable the Flashbang', result.stdout + result.stderr)
                    state = json.loads((home / '.my-ai-configuration/selection.json').read_text())
                    self.assertTrue(state['update_agents'])
                    self.assertFalse(state['flashbang'])
                    self.assertEqual(state['shell'], 'bash')
                    self.assertNotIn('Stop', json.loads((home / '.claude/settings.json').read_text()).get('hooks', {}))


if __name__ == '__main__':
    unittest.main()
