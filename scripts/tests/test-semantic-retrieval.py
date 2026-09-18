import hashlib
import importlib.util
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent.parent
SPEC = importlib.util.spec_from_file_location('semantic_retrieval', ROOT / 'scripts/lib/semantic-retrieval.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SemanticRetrievalTests(unittest.TestCase):
    def test_sync_does_not_register_mcp(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'home'
            output = io.StringIO()
            with redirect_stdout(output):
                MODULE.sync(ROOT, home, ['codex', 'claude'], True, True, False)
            self.assertNotIn('mcp', output.getvalue().lower())

    def test_runtime_prefers_cuda_packages_for_nvidia_gpu(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            python = MODULE.python_path(target / '.venv')
            python.parent.mkdir(parents=True)
            python.touch()
            with patch.object(MODULE.shutil, 'which', return_value='nvidia-smi'), patch.object(MODULE.subprocess, 'run') as run:
                MODULE.ensure_runtime(target, False)

            self.assertEqual(run.call_args.args[0][-2:], ['--extra-index-url', MODULE.CUDA_INDEX])

    def test_runtime_falls_back_to_cpu_packages_when_cuda_install_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            python = MODULE.python_path(target / '.venv')
            python.parent.mkdir(parents=True)
            python.touch()
            failure = MODULE.subprocess.CalledProcessError(1, 'pip')
            with patch.object(MODULE.shutil, 'which', return_value='nvidia-smi'), patch.object(MODULE.subprocess, 'run', side_effect=[failure, None]) as run:
                MODULE.ensure_runtime(target, False)

            self.assertEqual(run.call_count, 2)
            self.assertNotIn('--extra-index-url', run.call_args.args[0])

    def test_summary_dry_run_omits_details_without_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'home'
            for enabled in (True, False):
                output = io.StringIO()
                with redirect_stdout(output):
                    MODULE.sync(ROOT, home, ['codex'], enabled, True, False, summary=True)
                self.assertEqual(output.getvalue(), '')
                self.assertFalse(home.exists())

    def test_disable_removes_owned_runtime_without_cli_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'home'
            target = home / '.my-ai-configuration/semantic-retrieval'
            target.mkdir(parents=True)
            for name in MODULE.FILES:
                (target / name).write_text(name)
            state_path = target.parent / 'semantic-retrieval.json'
            state_path.write_text(json.dumps({'version': 1, 'clients': ['codex'], 'files': {
                name: hashlib.sha256((target / name).read_bytes()).hexdigest() for name in MODULE.FILES}}))
            MODULE.sync(ROOT, home, ['codex'], False, False, False)
            self.assertFalse(target.exists())
            self.assertFalse(state_path.exists())


if __name__ == '__main__':
    unittest.main()
