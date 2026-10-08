# scripts/tests/test-qmd-setup.py
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('qmd_setup', ROOT / 'scripts/lib/qmd.py')
qmd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qmd)


class FakeRunner:
    def __init__(self, installed=False, gpu='cuda', gpu_result=None, cpu_result=None):
        self.calls, self.installed, self.gpu = [], installed, gpu
        self.results = {'gpu': gpu_result, 'cpu': cpu_result}

    def __call__(self, arguments, env=None, timeout=None):
        self.calls.append(list(arguments))
        joined = ' '.join(arguments)
        if arguments[:2] == ['node', '--version']:
            return 'v22.4.0'
        if 'npm list' in joined:
            return json.dumps({'dependencies': {'@tobilu/qmd': {}} if self.installed else {}})
        if 'npm install' in joined:
            self.installed = True
        if 'npm uninstall' in joined:
            self.installed = False
        if '--detect' in joined:
            return json.dumps({'gpu': self.gpu, 'devices': ['GPU 0', 'GPU 1'] if self.gpu else [], 'threads': 32})
        if '--device' in joined:
            device = arguments[arguments.index('--device') + 1]
            return json.dumps(self.results[device])
        return ''


class SetupTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        (self.home / '.cache/qmd/models').mkdir(parents=True)

    def setup(self, runner, dry_run=False):
        return qmd.Setup(self.home, ROOT, runner, dry_run=dry_run, summary=True)

    def state(self):
        return json.loads((self.home / '.my-ai-configuration/qmd.json').read_text(encoding='utf-8'))

    def test_decide_prefers_gpu_then_cpu(self):
        self.assertEqual(qmd.decide([{'device': 'gpu', 'passed': True}, {'device': 'cpu', 'passed': True}]), 'gpu')
        self.assertEqual(qmd.decide([{'device': 'gpu', 'passed': False}, {'device': 'cpu', 'passed': True}]), 'cpu')
        self.assertIsNone(qmd.decide([{'device': 'gpu', 'passed': False}, {'device': 'cpu', 'passed': False}]))
        self.assertIsNone(qmd.decide([]))

    def test_node_version(self):
        self.assertTrue(qmd.node_version_ok('v22.0.0'))
        self.assertFalse(qmd.node_version_ok('v20.11.1'))
        self.assertFalse(qmd.node_version_ok('garbage'))

    def test_enable_installs_package_scripts_and_records_ownership(self):
        runner = FakeRunner()
        self.setup(runner).enable(['claude'])
        state = self.state()
        self.assertTrue(state['owned_package'])
        self.assertEqual(state['device'], 'gpu')
        self.assertTrue(state['models_block'])
        self.assertTrue((self.home / '.my-ai-configuration/qmd/qmd-search.mjs').is_file())
        self.assertIn(['npm', 'install', '--global', '@tobilu/qmd@2.8.3'], runner.calls)

    def test_enable_keeps_foreign_package_unowned(self):
        runner = FakeRunner(installed=True)
        self.setup(runner).enable(['claude'])
        self.assertFalse(self.state()['owned_package'])
        self.assertFalse(any('npm install' in ' '.join(c) for c in runner.calls))

    def test_disable_never_removes_foreign_package(self):
        runner = FakeRunner(installed=True)
        setup = self.setup(runner)
        setup.enable(['claude'])
        setup.disable(['claude'])
        self.assertFalse(any('npm uninstall' in ' '.join(c) for c in runner.calls))
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())

    def test_disable_removes_owned_models_and_collections(self):
        runner = FakeRunner()
        setup = self.setup(runner)
        setup.enable(['claude'])
        state = self.state()
        model = self.home / '.cache/qmd/models' / 'qwen3-embedding.gguf'
        model.write_text('x')
        state['owned_models'] = ['qwen3-embedding.gguf']
        (self.home / '.my-ai-configuration/qmd.json').write_text(json.dumps(state))
        (self.home / '.my-ai-configuration/qmd/collections.json').write_text(json.dumps(['repo-abcdefabcdef']))
        setup.disable(['claude'])
        self.assertFalse(model.exists())
        self.assertIn(['qmd', 'collection', 'remove', 'repo-abcdefabcdef'], runner.calls)
        self.assertIn(['npm', 'uninstall', '--global', '@tobilu/qmd'], runner.calls)

    def test_benchmark_unsuitable_cleans_up(self):
        runner = FakeRunner(gpu=False, cpu_result={'device': 'cpu', 'passed': False, 'querySeconds': 9, 'chunksPerSecond': 3})
        self.assertFalse(self.setup(runner).benchmark())
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())
        self.assertIn(['npm', 'uninstall', '--global', '@tobilu/qmd'], runner.calls)
        self.assertFalse(any('--device' in c and 'gpu' in c for c in runner.calls), 'no GPU means no GPU run')

    def test_benchmark_falls_back_to_cpu(self):
        runner = FakeRunner(gpu='vulkan', gpu_result={'device': 'gpu', 'passed': False, 'querySeconds': 7, 'chunksPerSecond': 30},
                            cpu_result={'device': 'cpu', 'passed': True, 'querySeconds': 4, 'chunksPerSecond': 25})
        self.assertTrue(self.setup(runner).benchmark())
        self.assertEqual(self.state()['device'], 'cpu')

    def test_migration_removes_python_retrieval_and_adopts_ledger_package(self):
        base = self.home / '.my-ai-configuration'
        (base / 'semantic-retrieval/.venv').mkdir(parents=True)
        (base / 'semantic-retrieval.json').write_text('{"version": 1, "clients": [], "files": {}}')
        (base / 'extensions.json').write_text(json.dumps({'version': 1, 'resources': [
            {'client': 'shared', 'name': 'QMD', 'kind': 'qmd', 'package': '@tobilu/qmd', 'clients': ['codex']},
            {'client': 'claude', 'name': 'QMD', 'kind': 'plugin', 'selector': 'qmd@qmd'}]}))
        runner = FakeRunner(installed=True)
        self.setup(runner).enable(['claude'])
        self.assertFalse((base / 'semantic-retrieval').exists())
        self.assertFalse((base / 'semantic-retrieval.json').exists())
        ledger = json.loads((base / 'extensions.json').read_text())
        self.assertEqual([r['kind'] for r in ledger['resources']], ['plugin'], 'plugin record stays so reconcile uninstalls qmd@qmd')
        self.assertTrue(self.state()['owned_package'], 'ledger-owned package is adopted')

    def test_dry_run_changes_nothing(self):
        runner = FakeRunner()
        self.setup(runner, dry_run=True).enable(['claude'])
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())
        self.assertFalse(any('npm install' in ' '.join(c) for c in runner.calls))


if __name__ == '__main__':
    unittest.main()
