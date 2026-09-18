import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent.parent
SHELLS = [
    ('powershell', shutil.which('powershell') or shutil.which('pwsh')),
    ('bash', str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
     if os.name == 'nt' else shutil.which('bash')),
]


class SessionStateHookTests(unittest.TestCase):
    def test_git_identity_and_stale_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            env = dict(os.environ, GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid', GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.invalid')
            subprocess.run(['git', '-C', str(workspace), 'init', '-q'], check=True)
            (workspace / 'file').write_text('one')
            subprocess.run(['git', '-C', str(workspace), 'add', 'file'], check=True)
            subprocess.run(['git', '-C', str(workspace), 'commit', '-qm', 'one'], check=True, env=env)
            command = [sys.executable, str(ROOT / 'shared/hooks/scripts/session-state.py'), '--workspace', str(workspace)]
            self.assertEqual(subprocess.run(command + ['--verified', 'check'], capture_output=True).returncode, 0)
            state = json.loads((workspace / '.ai-session/state.json').read_text())
            self.assertTrue(state['head'])
            self.assertEqual(state['verification'][0]['head'], state['head'])
            (workspace / 'file').write_text('two')
            subprocess.run(['git', '-C', str(workspace), 'add', 'file'], check=True)
            subprocess.run(['git', '-C', str(workspace), 'commit', '-qm', 'two'], check=True, env=env)
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            state = json.loads((workspace / '.ai-session/state.json').read_text())
            self.assertTrue(state['verificationStale'])
            self.assertTrue(state['verification'][0]['stale'])

    def test_writer_migrates_legacy_state_and_requires_reset_for_new_goal(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            state_file = workspace / '.ai-session/state.json'
            state_file.parent.mkdir()
            state_file.write_text(json.dumps({'goal': 'Original', 'changedFiles': ['a'],
                                             'pending': ['b'], 'importantFindings': ['c']}))
            command = [sys.executable, str(ROOT / 'shared/hooks/scripts/session-state.py'),
                       '--workspace', str(workspace)]
            result = subprocess.run(command + ['--verified', 'passed'], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            state = json.loads(state_file.read_text())
            self.assertEqual(state['changed'], ['a'])
            self.assertEqual(state['open'], ['b'])
            self.assertEqual(state['decisions'], ['c'])
            self.assertFalse({'changedFiles', 'pending', 'importantFindings'} & state.keys())
            before = state_file.read_bytes()
            result = subprocess.run(command + ['--goal', 'New'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(state_file.read_bytes(), before)
            result = subprocess.run(command + ['--reset', '--goal', 'New'], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            state = json.loads(state_file.read_text())
            self.assertEqual(state['goal'], 'New')
            self.assertEqual(state['verified'], [])
            self.assertEqual(state['changed'], [])
            state_file.write_text('{"goal":"New","verified":"invalid"}')
            before = state_file.read_bytes()
            result = subprocess.run(command + ['--open', 'next'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(state_file.read_bytes(), before)

    def test_writers_preserve_partial_updates_and_escape_values(self):
        for shell, executable in SHELLS:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                repository = base / 'repository'
                shutil.copytree(ROOT / 'shared/hooks/scripts', repository / 'shared/hooks/scripts')
                (repository / 'scripts').mkdir()
                for filename in ('session-state.ps1', 'session-state.sh'):
                    shutil.copy(ROOT / 'scripts' / filename, repository / 'scripts' / filename)
                workspace = base / 'workspace ü'
                workspace.mkdir()
                environment = dict(os.environ, TASK_WORKSPACE=str(workspace),
                                   TASK_GOAL='Repair "quotes"\n' + 'x' * 300)
                if shell == 'powershell':
                    prefix = [executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command']
                    commands = [
                        '& ./scripts/commands/session-state.ps1 -Workspace $env:TASK_WORKSPACE -Goal $env:TASK_GOAL -Decisions @("keep", "line two") -Pending @("check")',
                        '& ./scripts/commands/session-state.ps1 -Workspace $env:TASK_WORKSPACE -Verified @("passed")',
                        '& ./scripts/commands/session-state.ps1 -Workspace $env:TASK_WORKSPACE -Pointer',
                    ]
                else:
                    prefix = [executable, '-c']
                    commands = [
                        'bash ./scripts/commands/session-state.sh --workspace "$TASK_WORKSPACE" --goal "$TASK_GOAL" --decisions keep "line two" --open check',
                        'bash ./scripts/commands/session-state.sh --workspace "$TASK_WORKSPACE" --verified passed',
                        'bash ./scripts/commands/session-state.sh --workspace "$TASK_WORKSPACE" --pointer',
                    ]
                for command in commands:
                    result = subprocess.run(prefix + [command], cwd=repository, capture_output=True,
                                            encoding='utf-8', timeout=20, env=environment)
                    self.assertEqual(result.returncode, 0, result.stderr)
                state_file = workspace / '.ai-session/state.json'
                self.assertIn(str(state_file), result.stdout)
                state = json.loads(state_file.read_text(encoding='utf-8-sig'))
                self.assertEqual(state['goal'], environment['TASK_GOAL'])
                self.assertEqual(state['decisions'], ['keep', 'line two'])
                self.assertEqual(state['open'], ['check'])
                self.assertEqual(state['verified'], ['passed'])
                self.assertEqual(state['workspace'], str(workspace))
                self.assertFalse((repository / '.ai-session').exists())
                self.assertEqual([p.name for p in state_file.parent.iterdir()], ['state.json'])

    def run_hook(self, shell, executable, hook, config, workspace, payload):
        names = {'pointer': ('Show-SessionStatePointer.ps1', 'show-session-state-pointer.sh'),
                 'compact': ('Record-Compact.ps1', 'record-compact.sh')}
        script = config / 'hooks/scripts' / names[hook][shell == 'bash']
        command = ([executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script)]
                   if shell == 'powershell' else [executable, str(script)])
        result = subprocess.run(command, cwd=workspace, input=payload, capture_output=True,
                                encoding='utf-8', timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout

    def test_workspace_selection_and_read_only_state(self):
        for shell, executable in SHELLS:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                config = base / 'installed config'
                shutil.copytree(ROOT / 'shared/hooks/scripts', config / 'hooks/scripts')
                workspace = base / 'working project'
                selected = base / 'selected project ü'
                empty = base / 'empty project'
                for folder in (config, workspace, selected, empty):
                    folder.mkdir(exist_ok=True)
                for folder in (config, workspace, selected):
                    (folder / '.ai-session').mkdir()
                    (folder / '.ai-session/state.json').write_text('private state content')
                for hook in ('pointer', 'compact'):
                    for payload, expected in (
                        ('', workspace),
                        ('{}', workspace),
                        (json.dumps({'cwd': str(selected)}, ensure_ascii=False), selected),
                        (json.dumps({'cwd': str(empty)}), None),
                        ('{"cwd":"relative/path"}', None),
                        ('{"cwd":null}', None),
                        ('{"cwd":12}', None),
                        ('{"cwd":""}', None),
                        ('{bad json', None),
                        ('[]', None),
                    ):
                        with self.subTest(hook=hook, payload=payload):
                            output = self.run_hook(shell, executable, hook, config, workspace, payload)
                            if expected is None:
                                self.assertEqual(output, '')
                            else:
                                self.assertIn(str(expected / '.ai-session/state.json'), output)
                                self.assertNotIn(str(config), output)
                            self.assertNotIn('private state content', output)
                for folder in (config, workspace, selected):
                    self.assertEqual((folder / '.ai-session/state.json').read_text(), 'private state content')
                self.assertFalse((empty / '.ai-session').exists())
                events = (config / '.ai-session/telemetry.jsonl').read_text(encoding='utf-8-sig').splitlines()
                self.assertEqual(len(events), 10)
                self.assertTrue(all(json.loads(line)['event'] == 'compact' for line in events))

    def test_missing_workspace_state_succeeds_without_config_fallback(self):
        for shell, executable in SHELLS:
            if not executable or not Path(executable).exists():
                continue
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                config = base / 'config'
                shutil.copytree(ROOT / 'shared/hooks/scripts', config / 'hooks/scripts')
                (config / '.ai-session').mkdir()
                (config / '.ai-session/state.json').write_text('{}')
                workspace = base / 'workspace'
                workspace.mkdir()
                for hook in ('pointer', 'compact'):
                    self.assertEqual(self.run_hook(shell, executable, hook, config, workspace, ''), '')
                self.assertEqual(list(workspace.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
