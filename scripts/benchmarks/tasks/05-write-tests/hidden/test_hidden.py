import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

MUTANTS = [
    ('.rstrip("-")', ''),
    ('.lower()', ''),
    ('"ascii", "ignore"', '"ascii", "replace"'),
]


def run_tests(root):
    return subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-t', '.'], cwd=root, capture_output=True, text=True, timeout=120)


class Hidden(unittest.TestCase):
    def test_tests_pass(self):
        result = run_tests('.')
        self.assertEqual(result.returncode, 0, result.stderr[-2000:])
        self.assertRegex(result.stderr, r'Ran ([3-9]|\d\d+) tests')

    def test_tests_catch_mutants(self):
        source = Path('app/slug.py').read_text()
        for old, new in MUTANTS:
            with self.subTest(old), tempfile.TemporaryDirectory() as directory:
                shutil.copytree('.', directory, dirs_exist_ok=True, ignore=shutil.ignore_patterns('.git', 'bench_hidden'))
                Path(directory, 'app/slug.py').write_text(source.replace(old, new, 1))
                self.assertNotEqual(run_tests(directory).returncode, 0, f'tests miss mutant {old!r}')
