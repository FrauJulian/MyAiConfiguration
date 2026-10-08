import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('qmd_setup', ROOT / 'scripts/lib/qmd.py')
qmd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qmd)


class FakeRunner:
    def __init__(self, installed=False, gpu='cuda', gpu_result=None, cpu_result=None, previous=None, fail_pull=False, list_output=None):
        self.calls, self.installed, self.gpu = [], installed, gpu
        self.previous, self.fail_pull, self.list_output = previous, fail_pull, list_output
        self.results = {'gpu': gpu_result, 'cpu': cpu_result}

    def __call__(self, arguments, env=None, timeout=None, check=True):
        self.calls.append(list(arguments))
        joined = ' '.join(arguments)
        if arguments[:2] == ['node', '--version']:
            return 'v22.4.0'
        if arguments[-1:] == ['set-models']:
            return json.dumps({'previous': self.previous}) + chr(10)
        if self.fail_pull and arguments[:2] == ['qmd', 'pull']:
            raise ValueError('pull failed')
        if 'npm list' in joined and self.list_output is not None:
            return self.list_output
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

    def test_previous_models_are_restored_on_disable(self):
        runner = FakeRunner(previous={'embed': 'mine'})
        setup = self.setup(runner)
        setup.enable(['claude'])
        self.assertEqual(self.state()['previous_models'], {'embed': 'mine'})
        setup.disable(['claude'])
        self.assertIn(['node', str(self.home / '.my-ai-configuration/qmd/qmd-config.mjs'), 'restore-models', '{"embed": "mine"}'], runner.calls)
        self.assertFalse(any(c[-1:] == ['unset-models'] for c in runner.calls))

    def test_models_block_removed_when_none_existed(self):
        runner = FakeRunner()
        setup = self.setup(runner)
        setup.enable(['claude'])
        self.assertIsNone(self.state()['previous_models'])
        setup.disable(['claude'])
        self.assertTrue(any(c[-1:] == ['unset-models'] for c in runner.calls))
        self.assertFalse(any('restore-models' in c for c in runner.calls))

    def ledger(self, base):
        base.mkdir(parents=True, exist_ok=True)
        (base / 'extensions.json').write_text(json.dumps({'version': 1, 'resources': [
            {'client': 'shared', 'name': 'QMD', 'kind': 'qmd', 'package': '@tobilu/qmd', 'clients': ['codex']}]}))

    def test_disable_without_state_uninstalls_adopted_package(self):
        base = self.home / '.my-ai-configuration'
        self.ledger(base)
        runner = FakeRunner(installed=True)
        self.setup(runner).disable(['claude'])
        self.assertIn(['npm', 'uninstall', '--global', '@tobilu/qmd'], runner.calls)
        self.assertFalse((base / 'qmd.json').exists())

    def test_ownership_is_persisted_before_ledger_rewrite(self):
        base = self.home / '.my-ai-configuration'
        self.ledger(base)
        real = qmd.atomic_json

        def failing(path, value):
            if path.name == 'extensions.json':
                raise OSError('disk full')
            real(path, value)
        with mock.patch.object(qmd, 'atomic_json', failing):
            with self.assertRaises(OSError):
                self.setup(FakeRunner(installed=True)).enable(['claude'])
        self.assertTrue(self.state()['owned_package'])
        self.assertEqual(len(json.loads((base / 'extensions.json').read_text())['resources']), 1)

    def test_symlinked_script_directory_is_refused(self):
        base = self.home / '.my-ai-configuration'
        base.mkdir(parents=True)
        target = self.home / 'elsewhere'
        target.mkdir()
        try:
            (base / 'qmd').symlink_to(target, target_is_directory=True)
        except OSError:
            self.skipTest('symlinks unavailable')
        with self.assertRaises(ValueError):
            self.setup(FakeRunner()).enable(['claude'])
        self.assertEqual(list(target.iterdir()), [])

    def test_non_dict_benchmark_result_counts_as_failure(self):
        runner = FakeRunner(gpu=False, cpu_result=['unexpected'])
        self.assertFalse(self.setup(runner).benchmark())

    def test_package_installed_parses_listing(self):
        self.assertTrue(self.setup(FakeRunner(installed=True)).package_installed())
        self.assertFalse(self.setup(FakeRunner()).package_installed())

    def test_package_installed_rejects_unreliable_listings(self):
        for output in ('', '  ', 'not json', '{"error": {"code": "ELSPROBLEMS"}}', '{}', '[]'):
            with self.assertRaises(ValueError, msg=repr(output)):
                self.setup(FakeRunner(list_output=output)).package_installed()
        self.assertTrue(self.setup(FakeRunner(list_output='{"dependencies": {"@tobilu/qmd": {}}, "error": {}}')).package_installed())
        self.assertFalse(self.setup(FakeRunner(list_output='{"dependencies": {}}')).package_installed())

    def test_non_mapping_previous_models_are_restored_verbatim(self):
        runner = FakeRunner(previous='custom.gguf')
        setup = self.setup(runner)
        setup.enable(['claude'])
        self.assertEqual(self.state()['previous_models'], 'custom.gguf')
        setup.disable(['claude'])
        self.assertTrue(any(c[-2:] == ['restore-models', '"custom.gguf"'] for c in runner.calls))

    def test_dry_run_changes_nothing(self):
        runner = FakeRunner()
        self.setup(runner, dry_run=True).enable(['claude'])
        self.assertFalse((self.home / '.my-ai-configuration/qmd.json').exists())
        self.assertFalse(any('npm install' in ' '.join(c) for c in runner.calls))


if __name__ == '__main__':
    unittest.main()
