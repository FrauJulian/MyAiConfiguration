import shutil
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).parents[2]


class UserCustomizationTests(unittest.TestCase):
    def test_build_references_the_shell_specific_credential_helper(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        if powershell is None:
            self.skipTest('PowerShell is unavailable.')
        result = subprocess.run([
            powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(ROOT / 'scripts/commands/build.ps1'), '-Summary',
        ], capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('with-credential.ps1', (ROOT / 'generated/codex-powershell/AGENTS.md').read_text())
        self.assertIn('with-credential.sh', (ROOT / 'generated/claude-bash/CLAUDE.md').read_text())

    def test_add_instruction_creates_client_overlays_outside_managed_configuration(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        if powershell is None:
            self.skipTest('PowerShell is unavailable.')
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            result = subprocess.run([
                powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                str(ROOT / 'scripts/commands/add-instruction.ps1'),
                '-Client', 'Both', '-Instruction', 'Always use the local release process.',
                '-HomePath', str(home),
            ], capture_output=True, text=True, timeout=20)
            self.assertEqual(0, result.returncode, result.stderr)
            for client in ('codex', 'claude'):
                self.assertEqual('Always use the local release process.\n',
                                 (home / '.my-ai-configuration/instructions' / f'{client}.md').read_text())
            appended = subprocess.run([
                powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                str(ROOT / 'scripts/commands/add-instruction.ps1'),
                '-Client', 'Codex', '-Instruction', 'Keep the release notes current.',
                '-HomePath', str(home),
            ], capture_output=True, text=True, timeout=20)
            self.assertEqual(0, appended.returncode, appended.stderr)
            self.assertEqual('Always use the local release process.\nKeep the release notes current.\n',
                             (home / '.my-ai-configuration/instructions/codex.md').read_text())

    def test_add_credentials_installs_a_client_scoped_helper(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        if powershell is None:
            self.skipTest('PowerShell is unavailable.')
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            key = f'MY_TEST_TOKEN_{uuid.uuid4().hex}'
            stored = False
            try:
                result = subprocess.run([
                    powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                    str(ROOT / 'scripts/commands/add-credentials.ps1'),
                    '-Client', 'Codex', '-Key', key, '-ValueFromStdin',
                    '-HomePath', str(home),
                ], input='test-value', capture_output=True, text=True, timeout=20)
                self.assertEqual(0, result.returncode, result.stderr)
                stored = True
                helper = home / '.my-ai-configuration/bin/with-credential.ps1'
                self.assertTrue(helper.is_file())
                self.assertTrue((home / '.my-ai-configuration/bin/with-credential.sh').is_file())
                child = f"if ([Environment]::GetEnvironmentVariable('{key}', 'Process')) {{ exit 0 }}; exit 1"
                injected = subprocess.run([
                    powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(helper),
                    '-Client', 'Codex', '-Key', key, '-FilePath', powershell,
                    '-NoProfile', '-Command', child,
                ], capture_output=True, text=True, timeout=20)
                self.assertEqual(0, injected.returncode, injected.stderr)
            finally:
                cleanup = subprocess.run([
                    powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
                    f". '{ROOT / 'scripts/lib/credentials.ps1'}'; Remove-ManagedCredential -Client Codex -Key {key}",
                ], capture_output=True, text=True, timeout=20)
                if stored:
                    self.assertEqual(0, cleanup.returncode, cleanup.stderr)


if __name__ == '__main__':
    unittest.main()
