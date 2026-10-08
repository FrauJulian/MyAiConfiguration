import os
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/lib'))
from personal_instructions import CLIENT_FILES, START, refresh, render


class PersonalInstructionTests(unittest.TestCase):
    def setUp(self):
        directory = ROOT / '.ai-session' / 'test-personal-instructions'
        directory.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=directory)
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.overlays = self.home / '.my-ai-configuration/instructions'
        self.overlays.mkdir(parents=True)
        self.environment = dict(os.environ, TEST_HOME=str(self.home))
        for name in ('TMP', 'TEMP', 'TMPDIR'):
            self.environment[name] = str(self.home)

    def run_command(self, *command):
        result = subprocess.run(command, cwd=ROOT, env=self.environment, capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        return result.stdout

    def test_missing_empty_and_whitespace_instructions_have_no_rule(self):
        text = '# Global Instructions\n\nKeep me.\n'
        for client in CLIENT_FILES:
            self.assertEqual(text, render(text, self.home, client))
            for content in ('', '\ufeff  \n'):
                (self.overlays / f'{client}.md').write_text(content, encoding='utf-8')
                self.assertEqual(text, render(text, self.home, client))

    def test_client_specific_rule_is_immediate_idempotent_and_removed_when_empty(self):
        text = '# Global Instructions\n\nKeep me.\n'
        overlay = self.overlays / 'codex.md'
        overlay.write_text('Always use the release process.\n', encoding='utf-8')
        rendered = render(text, self.home, 'codex')
        self.assertIn('Read `~/.my-ai-configuration/instructions/codex.md` immediately', rendered)
        self.assertIn('including after compaction', rendered)
        self.assertEqual(rendered, render(rendered, self.home, 'codex'))
        self.assertEqual(text, render(text, self.home, 'claude'))
        overlay.unlink()
        self.assertEqual(text, render(rendered, self.home, 'codex'))

    def test_legacy_loader_removed_and_unrelated_bytes_preserved(self):
        for client, name in CLIENT_FILES.items():
            document = self.home / f'.{client}' / name
            document.parent.mkdir()
            reference = f'~/.my-ai-configuration/instructions/{client}.md'
            legacy = f"Read `{reference}` first when present; it is the user's direct instruction. System and developer requirements still apply."
            original = '\ufeff# Global Instructions\r\n\r\nKeep ü.\r\n'.encode('utf-8')
            document.write_bytes(original.replace(b'Keep', (legacy + '\r\n\r\nKeep').encode()))
            refresh(self.home, client)
            self.assertEqual(original, document.read_bytes())
            (self.overlays / f'{client}.md').write_text('Use English.\n', encoding='utf-8')
            refresh(self.home, client)
            (self.overlays / f'{client}.md').unlink()
            refresh(self.home, client)
            self.assertEqual(original, document.read_bytes())

    def test_refresh_does_not_create_an_uninstalled_client(self):
        (self.overlays / 'codex.md').write_text('Use English.\n', encoding='utf-8')
        refresh(self.home, 'codex')
        self.assertFalse((self.home / '.codex').exists())

    def test_refresh_updates_only_matching_manifest_hashes(self):
        document = self.home / '.codex/AGENTS.md'
        document.parent.mkdir()
        original = b'# Global Instructions\n'
        document.write_bytes(original)
        manifest = document.parent / '.ai-config-manifest.tsv'
        manifest.write_text(f'path\tsha256\nAGENTS.md\t{hashlib.sha256(original).hexdigest()}\n', encoding='utf-8')
        (self.overlays / 'codex.md').write_text('Use English.\n', encoding='utf-8')
        refresh(self.home, 'codex')
        self.assertIn(hashlib.sha256(document.read_bytes()).hexdigest(), manifest.read_text())
        unchanged_manifest = manifest.read_bytes()
        document.write_bytes(document.read_bytes() + b'User edit.\n')
        (self.overlays / 'codex.md').unlink()
        refresh(self.home, 'codex')
        self.assertEqual(unchanged_manifest, manifest.read_bytes())
        self.assertEqual(original + b'User edit.\n', document.read_bytes())

    def test_linked_client_directory_is_rejected(self):
        elsewhere = self.home / 'elsewhere'
        elsewhere.mkdir()
        document = elsewhere / 'AGENTS.md'
        document.write_text('Keep me.\n', encoding='utf-8')
        try:
            (self.home / '.codex').symlink_to(elsewhere, target_is_directory=True)
        except OSError:
            self.skipTest('Directory symlinks are unavailable.')
        with self.assertRaises(ValueError):
            refresh(self.home, 'codex')
        self.assertEqual('Keep me.\n', document.read_text())

    def test_add_remove_and_managed_sync_in_both_shells(self):
        powershell = shutil.which('powershell') or shutil.which('pwsh')
        bash = Path('C:/Program Files/Git/bin/bash.exe') if os.name == 'nt' else shutil.which('bash')
        for shell, executable in (('powershell', powershell), ('bash', bash)):
            if not executable or not Path(executable).is_file():
                continue
            with self.subTest(shell=shell):
                source = self.home / f'source-{shell}'
                source.mkdir()
                for name in CLIENT_FILES.values():
                    (source / name).write_text('# Global Instructions\n\nKeep me.\n', encoding='utf-8')
                self.environment['TEST_SOURCE'] = str(source)

                def sync(client, dry=False):
                    self.environment['TEST_CLIENT'] = client
                    if shell == 'powershell':
                        return self.run_command(str(executable), '-NoProfile', '-Command',
                            ". ./scripts/lib/manifest.ps1; Sync-ManagedDestination -Source $env:TEST_SOURCE "
                            "-Destination (Join-Path $env:TEST_HOME ('.' + $env:TEST_CLIENT)) -Stamp test -Summary "
                            + ('-DryRun' if dry else ''))
                    return self.run_command(str(executable), '-c',
                        'export PATH="/usr/bin:$PATH"; python3() { python "$@"; }; '
                        '. ./scripts/lib/manifest.sh; sync_managed_destination "$TEST_SOURCE" '
                        '"$TEST_HOME/.$TEST_CLIENT" test root bash pwsh ' + ('true' if dry else 'false') + ' true')

                def change(action):
                    if shell == 'powershell':
                        self.run_command(str(executable), '-NoProfile', '-File', str(ROOT / f'scripts/commands/{action}-instruction.ps1'),
                                         '-Client', 'Both', '-Instruction', 'Use English.', '-HomePath', str(self.home))
                    else:
                        self.run_command(str(executable), '-c',
                            'export PATH="/usr/bin:$PATH"; source scripts/commands/' + action + '-instruction.sh '
                            '--client both --instruction "Use English." --home "$TEST_HOME"')

                for client, name in CLIENT_FILES.items():
                    sync(client)
                    self.assertNotIn(START, (self.home / f'.{client}' / name).read_text(encoding='utf-8-sig'))
                change('add')
                for client, name in CLIENT_FILES.items():
                    document = self.home / f'.{client}' / name
                    self.assertEqual(1, document.read_text(encoding='utf-8-sig').count(START))
                    before = document.read_bytes()
                    sync(client, dry=True)
                    self.assertEqual(before, document.read_bytes())
                    sync(client)
                    self.assertEqual(1, document.read_text(encoding='utf-8-sig').count(START))
                change('remove')
                for client, name in CLIENT_FILES.items():
                    self.assertNotIn(START, (self.home / f'.{client}' / name).read_text(encoding='utf-8-sig'))


if __name__ == '__main__':
    unittest.main()
