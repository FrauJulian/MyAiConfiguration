import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / 'scripts/lib/selection-state.py'


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.path = self.home / '.my-ai-configuration/selection.json'

    def run_state(self, action, *arguments):
        return subprocess.run([sys.executable, str(HELPER), action, '--home', str(self.home),
                               '--manifest', str(ROOT / 'adapters/plugins.tsv'), *arguments],
                              capture_output=True, text=True, timeout=10)

    def save(self, *arguments):
        result = self.run_state('write', '--platform', 'windows', '--client', 'both', *arguments)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_selection_fails_without_creating_state(self):
        result = self.run_state('read')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('without Quick', result.stderr)
        self.assertFalse(self.path.exists())

    def test_selection_round_trip_and_last_successful_write(self):
        self.save('--selected', 'Superpowers', 'Anthropic Frontend Design', '--deselected', 'Context7')
        original = self.path.read_bytes()
        state = json.loads(self.run_state('read').stdout)
        self.assertEqual(state['platform'], 'windows')
        self.assertEqual(state['client'], 'both')
        self.assertEqual(state['selected'], ['Superpowers', 'Anthropic Frontend Design'])
        self.assertEqual(state['deselected'], ['Context7'])
        self.assertEqual(self.path.read_bytes(), original)
        self.assertIn('selected\tAnthropic Frontend Design', self.run_state('read', '--format', 'tsv').stdout)
        self.save('--selected', 'Context7')
        self.assertEqual(json.loads(self.run_state('read').stdout)['selected'], ['Context7'])

    def test_empty_selection_does_not_select_everything(self):
        self.save()
        self.assertEqual(json.loads(self.run_state('read').stdout)['selected'], [])

    def test_invalid_write_preserves_last_selection(self):
        self.save('--selected', 'Superpowers')
        original = self.path.read_bytes()
        result = self.run_state('write', '--platform', 'linux', '--client', 'codex', '--selected', 'Unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), original)

    def test_corrupt_or_conflicting_state_is_rejected(self):
        self.path.parent.mkdir()
        for state in ('{', '[]', json.dumps(dict(version=1, platform='windows', client='both',
                                               selected=['Context7'], deselected=['Context7']))):
            self.path.write_text(state)
            self.assertNotEqual(self.run_state('read').returncode, 0)

    def test_removed_plugins_are_ignored_and_new_plugins_not_selected(self):
        self.save('--selected', 'Superpowers')
        state = json.loads(self.path.read_text())
        state['selected'].append('Removed plugin')
        self.path.write_text(json.dumps(state))
        self.assertEqual(json.loads(self.run_state('read').stdout)['selected'], ['Superpowers'])

    def test_powershell_quick_preview_uses_saved_selection_without_writes(self):
        shell = shutil.which('powershell') or shutil.which('pwsh')
        if not shell:
            self.skipTest('PowerShell unavailable')
        environment = dict(os.environ, TEST_SELECTION_HOME=str(self.home), TEST_REPOSITORY_ROOT=str(ROOT))
        save = subprocess.run([shell, '-NoProfile', '-Command',
                               "$ErrorActionPreference = 'Stop'; . (Join-Path $env:TEST_REPOSITORY_ROOT 'scripts/lib/selection-state.ps1'); "
                               "Save-UpdateSelection -HomePath $env:TEST_SELECTION_HOME -RepositoryRoot $env:TEST_REPOSITORY_ROOT "
                               "-Platform Windows -Client Both -Plugins @{ Selected = @([pscustomobject]@{name='Superpowers'}); Deselected = @() }"],
                              env=environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(save.returncode, 0, save.stdout + save.stderr)
        original = self.path.read_bytes()
        source = (ROOT / 'scripts/update.ps1').read_text(encoding='utf-8-sig')
        source = source.replace("[Environment]::GetFolderPath('UserProfile')", '$env:TEST_SELECTION_HOME')
        with tempfile.NamedTemporaryFile(mode='w', suffix='.tmp.ps1', dir=ROOT / 'scripts',
                                         encoding='utf-8', delete=False) as stream:
            stream.write(source)
            entry = Path(stream.name)
        self.addCleanup(entry.unlink)
        result = subprocess.run([shell, '-NoProfile', '-File', str(entry), '-Quick', '-DryRun'],
                                env=environment, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('Select plugins', result.stdout)
        self.assertIn('codex plugin add superpowers@openai-curated-remote', result.stdout)
        self.assertNotIn('codex plugin add context7', result.stdout)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse((self.home / '.codex').exists())
        failed = subprocess.run([shell, '-NoProfile', '-File', str(entry), '-Quick'], env=environment,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(self.path.read_bytes(), original)

    def test_bash_quick_preview_uses_saved_selection_without_writes(self):
        shell = shutil.which('bash')
        if os.name == 'nt':
            candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe'
            shell = str(candidate) if candidate.exists() else None
        if not shell:
            self.skipTest('Bash unavailable')
        save = subprocess.run([shell, '-c',
                               'set -euo pipefail; root=$1; home_path=$2; platform=windows; client=both; '
                               'selected_plugins=(Superpowers); deselected_plugins=(); '
                               '. "$root/scripts/lib/selection-state.sh"; save_update_selection',
                               'test', ROOT.as_posix(), self.home.as_posix()],
                              capture_output=True, text=True, timeout=10)
        self.assertEqual(save.returncode, 0, save.stdout + save.stderr)
        original = self.path.read_bytes()
        environment = dict(os.environ, HOME=self.home.as_posix())
        result = subprocess.run([shell, str(ROOT / 'scripts/update.sh'), '--quick', '--dry-run'],
                                env=environment, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('Select plugins', result.stdout)
        self.assertIn('codex plugin add superpowers@openai-curated-remote', result.stdout)
        self.assertNotIn('codex plugin add context7', result.stdout)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse((self.home / '.codex').exists())


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]], verbosity=1)
