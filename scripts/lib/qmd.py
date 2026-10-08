"""Install, benchmark, migrate, and remove the setup-owned QMD local search."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

PACKAGE = '@tobilu/qmd'
VERSION = '2.8.3'
SCRIPTS = ('qmd-lib.mjs', 'qmd-config.mjs', 'qmd-daemon.mjs', 'qmd-search.mjs', 'qmd-warm.mjs', 'qmd-benchmark.mjs')
DEVICE_TIMEOUT = 600
WINDOWS = os.name == 'nt'


def run(arguments, env=None, timeout=1800, check=True):
    result = subprocess.run(arguments, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                            timeout=timeout, shell=WINDOWS and arguments[0] in ('npm', 'qmd'))
    if check and result.returncode != 0:
        raise ValueError(f'{" ".join(arguments[:3])} failed: {(result.stderr or result.stdout).strip()[-300:]}')
    return result.stdout


def decide(results):
    for device in ('gpu', 'cpu'):
        if any(r.get('device') == device and r.get('passed') is True for r in results):
            return device
    return None


def node_version_ok(text):
    match = re.fullmatch(r'v(\d+)\.\d+\.\d+', text.strip())
    return bool(match) and int(match.group(1)) >= 22


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, delete=False) as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
    os.replace(stream.name, path)


class Setup:
    def __init__(self, home, root, runner=run, dry_run=False, summary=False):
        self.home, self.root, self.run, self.dry_run, self.summary = Path(home), Path(root), runner, dry_run, summary
        self.base = self.home / '.my-ai-configuration'
        self.state_path = self.base / 'qmd.json'
        self.scripts = self.base / 'qmd'
        self.models = self.home / '.cache' / 'qmd' / 'models'

    def say(self, text):
        if not self.summary:
            print(text)

    def load(self):
        if not self.state_path.exists():
            return {'version': 1, 'clients': [], 'device': None, 'owned_package': False, 'owned_models': [], 'models_block': False, 'previous_models': None, 'files': {}}
        state = json.loads(self.state_path.read_text(encoding='utf-8'))
        if state.get('version') != 1 or state.get('device') not in (None, 'gpu', 'cpu'):
            raise ValueError('Invalid QMD setup state.')
        return state

    def node(self, script, *arguments, env=None, timeout=1800):
        return self.run(['node', str(self.scripts / script), *arguments], env=env, timeout=timeout)

    def package_installed(self):
        # npm list exits non-zero on tree problems (ELSPROBLEMS) but still prints valid JSON.
        output = self.run(['npm', 'list', '--global', '--depth=0', '--json'], check=False)
        try:
            listing = json.loads(output)
        except json.JSONDecodeError:
            raise ValueError('npm list did not return JSON.')
        if not isinstance(listing, dict) or not isinstance(listing.get('dependencies'), dict):
            raise ValueError('npm list did not report the global packages.')
        return PACKAGE in listing['dependencies']

    def require_node(self):
        if not node_version_ok(self.run(['node', '--version'])):
            raise ValueError('QMD local search needs Node.js 22 or newer.')

    def stop_legacy_daemon(self, legacy):
        """Ask the old Python daemon to exit so its files can be deleted (Windows keeps open files locked)."""
        python = legacy / '.venv' / ('Scripts/python.exe' if WINDOWS else 'bin/python')
        server = legacy / 'server.py'
        if python.is_file() and server.is_file():
            try:
                self.run([str(python), str(server), 'stop', '--data-dir', str(legacy / 'data'),
                          '--model-cache', str(legacy / 'model-cache')], timeout=60, check=False)
            except (ValueError, OSError, subprocess.SubprocessError):
                pass

    def migrate(self, state=None):
        state = self.load() if state is None else state
        legacy_state = self.base / 'semantic-retrieval.json'
        legacy = self.base / 'semantic-retrieval'
        if legacy_state.exists() or legacy.exists():
            if legacy.is_symlink():
                raise ValueError('Legacy semantic retrieval directory must not be a symbolic link.')
            if legacy.exists():
                self.stop_legacy_daemon(legacy)
                shutil.rmtree(legacy)
            legacy_state.unlink(missing_ok=True)
            self.say('Removed the previous Python semantic retrieval installation.')
        ledger_path = self.base / 'extensions.json'
        if ledger_path.exists():
            ledger = json.loads(ledger_path.read_text(encoding='utf-8'))
            owned = [r for r in ledger.get('resources', []) if r.get('kind') == 'qmd']
            if owned:
                state['owned_package'] = True
                atomic_json(self.state_path, state)  # record ownership before the ledger forgets it
                ledger['resources'] = [r for r in ledger['resources'] if r.get('kind') != 'qmd']
                atomic_json(ledger_path, ledger)

    def install_scripts(self, state):
        if self.scripts.is_symlink():
            raise ValueError('QMD script directory must not be a symbolic link.')
        self.scripts.mkdir(parents=True, exist_ok=True)
        for name in SCRIPTS:
            target = self.scripts / name
            if target.is_symlink():
                raise ValueError(f'QMD script must not be a symbolic link: {name}')
            expected = state['files'].get(name)
            if target.exists() and expected and digest(target) != expected:
                raise ValueError(f'Setup-owned QMD script changed: {name}')
            shutil.copy2(self.root / 'shared' / 'qmd' / name, target)
            state['files'][name] = digest(target)

    def install(self, state):
        """Steps shared by Yes and Auto: package, scripts, models block, model download."""
        self.require_node()
        self.migrate(state)
        if not self.package_installed():
            self.run(['npm', 'install', '--global', f'{PACKAGE}@{VERSION}'])
            state['owned_package'] = True
        self.install_scripts(state)
        atomic_json(self.state_path, state)
        if not state['models_block']:
            output = self.node('qmd-config.mjs', 'set-models')
            try:
                previous = json.loads(output.strip().splitlines()[-1])['previous']
            except (IndexError, KeyError, TypeError, json.JSONDecodeError):
                raise ValueError('qmd-config set-models returned no previous models.')
            state['previous_models'] = previous
            state['models_block'] = True
            atomic_json(self.state_path, state)
        before = {p.name for p in self.models.iterdir()} if self.models.is_dir() else set()
        self.run(['qmd', 'pull'], timeout=3600)
        after = {p.name for p in self.models.iterdir()} if self.models.is_dir() else set()
        state['owned_models'] = sorted(set(state['owned_models']) | (after - before))
        atomic_json(self.state_path, state)

    def detect_gpu(self):
        try:
            found = json.loads(self.node('qmd-benchmark.mjs', '--detect', timeout=DEVICE_TIMEOUT) or '{}')
            gpu = found.get('gpu') or False
        except Exception as error:  # any probe failure means: use the CPU
            self.say(f'QMD GPU detection failed, using the CPU: {str(error)[:200]}')
            return False
        names = ', '.join(found.get('devices') or []) or 'unnamed device'
        self.say(f"QMD devices: {f'{str(gpu).upper()}: {names}' if gpu else 'no GPU'}; CPU threads: {found.get('threads', '?')}")
        return gpu

    def enable(self, clients):
        state = self.load()
        if self.dry_run:
            self.say('DRYRUN enable QMD local search: Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B, QMD query expansion 1.7B')
            return
        self.install(state)
        if state['device'] is None:
            state['device'] = 'gpu' if self.detect_gpu() else 'cpu'
        state['clients'] = sorted(set(state['clients']) | set(clients))
        atomic_json(self.state_path, state)
        self.say(f'QMD local search enabled on {state["device"].upper()}.')

    def remove_all(self, state):
        try:
            if self.scripts.joinpath('qmd-search.mjs').exists():
                self.node('qmd-search.mjs', '--stop', timeout=60)
        except (ValueError, subprocess.SubprocessError):
            pass
        collections = self.scripts / 'collections.json'
        names = json.loads(collections.read_text(encoding='utf-8')) if collections.exists() else []
        for name in names:
            if re.fullmatch(r'repo-[0-9a-f]{12}', name):
                try:
                    self.run(['qmd', 'collection', 'remove', name])
                except (ValueError, subprocess.SubprocessError):
                    pass
        if state['models_block'] and self.scripts.joinpath('qmd-config.mjs').exists():
            previous = state.get('previous_models')
            if previous is not None:
                self.node('qmd-config.mjs', 'restore-models', json.dumps(previous))
            else:
                self.node('qmd-config.mjs', 'unset-models')
        for name in state['owned_models']:
            path = self.models / name
            if name == Path(name).name and path.is_file() and not path.is_symlink():
                path.unlink()
        if state['owned_package']:
            self.run(['npm', 'uninstall', '--global', PACKAGE])
        if self.scripts.exists() and not self.scripts.is_symlink():
            shutil.rmtree(self.scripts)
        self.state_path.unlink(missing_ok=True)

    def disable(self, clients):
        state = self.load()
        if not self.state_path.exists():
            if not self.dry_run:
                self.migrate(state)
                if state['owned_package']:
                    self.run(['npm', 'uninstall', '--global', PACKAGE])
                    self.state_path.unlink(missing_ok=True)
            return
        if self.dry_run:
            self.say('DRYRUN disable QMD local search')
            return
        state['clients'] = [c for c in state['clients'] if c not in clients]
        if state['clients']:
            atomic_json(self.state_path, state)
            return
        self.remove_all(state)
        self.say('QMD local search removed.')

    def benchmark(self):
        state = self.load()
        if self.dry_run:
            self.say('DRYRUN benchmark QMD local search on GPU, then CPU')
            return True
        try:
            self.install(state)
        except (ValueError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
            print(f'QMD local search is not suitable for this computer: {error}')
            try:
                self.remove_all(state)
            except (ValueError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as cleanup:
                print(f'QMD cleanup was incomplete: {cleanup}')
            return False
        results = []
        devices = (['gpu'] if self.detect_gpu() else []) + ['cpu']
        for device in devices:
            env = dict(os.environ)
            env.pop('QMD_FORCE_CPU' if device == 'gpu' else 'QMD_LLAMA_GPU', None)
            env['QMD_LLAMA_GPU' if device == 'gpu' else 'QMD_FORCE_CPU'] = 'auto' if device == 'gpu' else '1'
            try:
                result = json.loads(self.node('qmd-benchmark.mjs', '--device', device, env=env, timeout=DEVICE_TIMEOUT))
                if not isinstance(result, dict):
                    raise ValueError('benchmark returned a non-object result')
            except (ValueError, subprocess.SubprocessError) as error:
                result = {'device': device, 'passed': False, 'error': str(error)[:200]}
            results.append(result)
            print(f'QMD benchmark {device.upper()}: ' + ('passed' if result.get('passed') else 'failed')
                  + f" (search {result.get('querySeconds', '-')} s, embedding {result.get('chunksPerSecond', '-')} chunks/s)")
            if result.get('passed'):
                break
        device = decide(results)
        if device is None:
            self.remove_all(state)
            print('QMD local search is not suitable for this computer; removed what the setup installed.')
            return False
        state['device'] = device
        atomic_json(self.state_path, state)
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('sync', 'benchmark'))
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--home', required=True, type=Path)
    parser.add_argument('--client', choices=('codex', 'claude', 'both'))
    parser.add_argument('--enabled', choices=('true', 'false'))
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true')
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    setup = Setup(args.home.resolve(), args.root.resolve(), run, args.dry_run, args.summary)
    if args.action == 'benchmark':
        raise SystemExit(0 if setup.benchmark() else 2)
    if args.client is None or args.enabled is None:
        parser.error('sync requires --client and --enabled')
    clients = ['codex', 'claude'] if args.client == 'both' else [args.client]
    (setup.enable if args.enabled == 'true' else setup.disable)(clients)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f'QMD local search: {error}', file=sys.stderr)
        raise SystemExit(1)
