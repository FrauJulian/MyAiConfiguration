import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('semantic_retrieval', ROOT / 'scripts/lib/semantic-retrieval.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SemanticRetrievalTests(unittest.TestCase):
    def test_claude_registration_places_name_before_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'home'
            calls = []
            original = MODULE.command
            original_runtime = MODULE.ensure_runtime
            MODULE.command = lambda client, arguments, home, dry_run: calls.append((client, arguments))
            MODULE.ensure_runtime = lambda target, dry_run: target / '.venv' / 'bin' / 'python'
            try:
                MODULE.sync(ROOT, home, ['claude'], True, False, False)
            finally:
                MODULE.command = original
                MODULE.ensure_runtime = original_runtime
            add = calls[0][1]
            self.assertEqual(add[:5], ['claude', 'mcp', 'add', MODULE.NAME, '--scope'])
            self.assertIn('-e', add)

    def test_disable_removes_owned_runtime_and_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'home'
            target = home / '.my-ai-configuration/semantic-retrieval'
            target.mkdir(parents=True)
            for name in MODULE.FILES:
                (target / name).write_text(name)
            state_path = target.parent / 'semantic-retrieval.json'
            state_path.write_text(json.dumps({'version': 1, 'clients': ['codex'], 'files': {
                name: hashlib.sha256((target / name).read_bytes()).hexdigest() for name in MODULE.FILES}}))
            calls = []
            original = MODULE.command
            MODULE.command = lambda client, arguments, home, dry_run: calls.append((client, arguments))
            try:
                MODULE.sync(ROOT, home, ['codex'], False, False, False)
            finally:
                MODULE.command = original
            self.assertEqual(calls[0][1], ['codex', 'mcp', 'remove', MODULE.NAME])
            self.assertFalse(target.exists())
            self.assertFalse(state_path.exists())


if __name__ == '__main__':
    unittest.main()
