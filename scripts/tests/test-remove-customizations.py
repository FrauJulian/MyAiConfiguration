import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEST_ROOT = ROOT / '.ai-session' / 'test-remove-customizations'


class RemoveCustomizationTests(unittest.TestCase):
    def setUp(self):
        TEST_ROOT.mkdir(parents=True, exist_ok=True)
        self.assertTrue(TEST_ROOT.resolve().is_relative_to(ROOT.resolve()))
        self.temporary = tempfile.TemporaryDirectory(dir=TEST_ROOT)
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.environment = os.environ.copy()
        for name in ('TEMP', 'TMP', 'TMPDIR'):
            self.environment[name] = str(self.home)

    def run_command(self, *arguments, input=None):
        return subprocess.run(arguments, input=input, capture_output=True, text=True,
                              cwd=ROOT, env=self.environment, timeout=20)

    def test_remove_last_exact_instruction_and_keep_other_lines(self):
        directory = self.home / '.my-ai-configuration' / 'instructions'
        directory.mkdir(parents=True)
        path = directory / 'codex.md'
        path.write_bytes(b'Before\r\nRemove this\r\nKeep this\r\nRemove this\r\n')
        command = (sys.executable, str(ROOT / 'scripts/lib/remove-instruction.py'),
                   '--client', 'codex', '--instruction', 'Remove this', '--home', str(self.home))

        first = self.run_command(*command)
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(b'Before\r\nRemove this\r\nKeep this\r\n', path.read_bytes())
        second = self.run_command(*command)
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertEqual(b'Before\r\nKeep this\r\n', path.read_bytes())
        third = self.run_command(*command)
        self.assertEqual(0, third.returncode, third.stderr)
        self.assertIn('Instruction not found for codex.', third.stdout)

    def test_remove_both(self):
        directory = self.home / '.my-ai-configuration' / 'instructions'
        directory.mkdir(parents=True)
        for client in ('codex', 'claude'):
            (directory / f'{client}.md').write_text('Remove me\n', encoding='utf-8')
        result = self.run_command(sys.executable, str(ROOT / 'scripts/lib/remove-instruction.py'),
                                  '--client', 'both', '--instruction', 'Remove me', '--home', str(self.home))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse((directory / 'codex.md').exists())
        self.assertFalse((directory / 'claude.md').exists())

    def test_linked_instruction_directory_is_rejected(self):
        parent = self.home / '.my-ai-configuration'
        parent.mkdir()
        elsewhere = self.home / 'elsewhere'
        elsewhere.mkdir()
        path = elsewhere / 'codex.md'
        path.write_text('Keep this\n', encoding='utf-8')
        try:
            (parent / 'instructions').symlink_to(elsewhere, target_is_directory=True)
        except OSError:
            self.skipTest('Directory symlinks are unavailable.')
        result = self.run_command(sys.executable, str(ROOT / 'scripts/lib/remove-instruction.py'),
                                  '--client', 'codex', '--instruction', 'Keep this', '--home', str(self.home))
        self.assertNotEqual(0, result.returncode)
        self.assertEqual('Keep this\n', path.read_text(encoding='utf-8'))

    def test_powershell_remove_instruction_entry_point(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        if powershell is None:
            self.skipTest('PowerShell is unavailable.')
        path = self.home / '.my-ai-configuration' / 'instructions' / 'codex.md'
        path.parent.mkdir(parents=True)
        path.write_text('Keep this\nRemove this\n', encoding='utf-8')
        result = self.run_command(powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                                  str(ROOT / 'scripts/commands/remove-instruction.ps1'),
                                  '-Client', 'Codex', '-Instruction', 'Remove this   ', '-HomePath', str(self.home))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual('Keep this\n', path.read_text(encoding='utf-8'))

        bash = Path('C:/Program Files/Git/bin/bash.exe') if os.name == 'nt' else shutil.which('bash')
        if bash and Path(bash).is_file():
            path.write_text('Keep this\nRemove from Bash\n', encoding='utf-8')
            self.environment['TEST_HOME'] = str(self.home)
            if os.name == 'nt':
                script = ('python3() { python.exe "$@"; }; '
                          'source scripts/commands/remove-instruction.sh --client codex '
                          '--instruction "Remove from Bash" --home "$TEST_HOME"')
                removed = self.run_command(str(bash), '-c', script)
            else:
                removed = self.run_command(str(bash), str(ROOT / 'scripts/commands/remove-instruction.sh'),
                                           '--client', 'codex', '--instruction', 'Remove from Bash', '--home', str(self.home))
            self.assertEqual(0, removed.returncode, removed.stderr)
            self.assertEqual('Keep this\n', path.read_text(encoding='utf-8'))

        added = self.run_command(powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                                 str(ROOT / 'scripts/commands/add-instruction.ps1'),
                                 '-Client', 'Both', '-Instruction', 'New shared instruction', '-HomePath', str(self.home))
        self.assertEqual(0, added.returncode, added.stderr)
        removed = self.run_command(powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                                   str(ROOT / 'scripts/commands/remove-instruction.ps1'),
                                   '-Client', 'Both', '-Instruction', 'New shared instruction', '-HomePath', str(self.home))
        self.assertEqual(0, removed.returncode, removed.stderr)
        self.assertEqual('Keep this\n', path.read_text(encoding='utf-8'))
        self.assertFalse((path.parent / 'claude.md').exists())

    def test_powershell_remove_credential_scopes_and_missing_key(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        if powershell is None:
            self.skipTest('PowerShell is unavailable.')
        commands = self.home / 'fixture' / 'scripts' / 'commands'
        library = self.home / 'fixture' / 'scripts' / 'lib'
        commands.mkdir(parents=True)
        library.mkdir(parents=True)
        for name in ('remove-credentials.ps1', 'remove-credentials.sh'):
            shutil.copy2(ROOT / 'scripts' / 'commands' / name, commands / name)
        shutil.copy2(ROOT / 'scripts/lib/install-targets.ps1', library / 'install-targets.ps1')
        (library / 'credentials.ps1').write_text('''
function Assert-CredentialKey { param([string]$Value)
    if ($Value -notmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$') { throw 'Invalid credential key.' }
}
function Remove-ManagedCredential { param([string]$Client, [string]$Key)
    if ($Key -eq 'MISSING') { throw [ComponentModel.Win32Exception]::new(1168) }
    [IO.File]::AppendAllText($env:TEST_CREDENTIAL_LOG, "$Client/$Key`n")
}
''', encoding='utf-8')
        log = self.home / 'credential-calls.txt'
        self.environment['TEST_CREDENTIAL_LOG'] = str(log)
        base = (powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                str(commands / 'remove-credentials.ps1'), '-Client', 'Both', '-Key')

        removed = self.run_command(*base, 'TEST_KEY')
        self.assertEqual(0, removed.returncode, removed.stderr)
        self.assertEqual(['Codex/TEST_KEY', 'Claude/TEST_KEY'], log.read_text().splitlines())
        missing = self.run_command(*base, 'MISSING')
        self.assertEqual(0, missing.returncode, missing.stderr)
        self.assertEqual(2, missing.stdout.count('Credential not found'))
        rejected = self.run_command(*base, 'BAD-KEY')
        self.assertNotEqual(0, rejected.returncode)
        self.assertEqual(['Codex/TEST_KEY', 'Claude/TEST_KEY'], log.read_text().splitlines())

        bash = Path('C:/Program Files/Git/bin/bash.exe') if os.name == 'nt' else shutil.which('bash')
        if bash and Path(bash).is_file():
            if os.name == 'nt':
                self.environment['TEST_SCRIPT'] = str(commands / 'remove-credentials.sh')
                removed = self.run_command(str(bash), '-c',
                                           'source "$(cygpath -u "$TEST_SCRIPT")" --client codex --key TEST_KEY')
            else:
                removed = self.run_command(str(bash), str(commands / 'remove-credentials.sh'),
                                           '--client', 'codex', '--key', 'TEST_KEY')
            self.assertEqual(0, removed.returncode, removed.stderr)
            self.assertEqual(['Codex/TEST_KEY', 'Claude/TEST_KEY', 'codex/TEST_KEY'],
                             log.read_text().splitlines())


if __name__ == '__main__':
    unittest.main()
