import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


NAME = 'my-ai-qwen3-retrieval'
FILES = ('server.py', 'requirements.txt')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(client, arguments, home, dry_run):
    if dry_run:
        print('DRYRUN ' + ' '.join(arguments))
        return True
    executable = shutil.which(client)
    if executable is None:
        raise ValueError(f'{client} CLI is required for semantic retrieval.')
    result = subprocess.run([executable, *arguments[1:]], stdin=subprocess.DEVNULL, capture_output=True, text=True,
                            timeout=180, env=dict(os.environ, HOME=str(home), USERPROFILE=str(home), CODEX_HOME=str(home / '.codex'), CLAUDE_CONFIG_DIR=str(home / '.claude')))
    if result.returncode:
        raise ValueError(f'Semantic retrieval command failed: {client} {" ".join(arguments[1:])}\n{result.stdout}{result.stderr}')
    return True


def python_path(target):
    return target / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')


def ensure_runtime(target, dry_run):
    if dry_run:
        return python_path(target / '.venv')
    venv = target / '.venv'
    if not venv.exists():
        subprocess.run([sys.executable, '-m', 'venv', str(venv)], check=True, timeout=180)
    python = python_path(venv)
    if not python.is_file():
        raise ValueError('Semantic retrieval virtual environment is incomplete.')
    subprocess.run([str(python), '-m', 'pip', 'install', '--disable-pip-version-check', '-r', str(target / 'requirements.txt')],
                   check=True, timeout=900)
    return python


def load_state(path):
    if not path.exists():
        return {'version': 1, 'clients': [], 'files': {}}
    state = json.loads(path.read_text(encoding='utf-8'))
    if state.get('version') != 1 or not isinstance(state.get('clients'), list) or not isinstance(state.get('files'), dict):
        raise ValueError('Invalid semantic retrieval ownership state.')
    if any(client not in ('codex', 'claude') for client in state['clients']):
        raise ValueError('Invalid semantic retrieval client state.')
    if any(name not in FILES or not isinstance(value, str) or len(value) != 64 or any(character not in '0123456789abcdef' for character in value) for name, value in state['files'].items()):
        raise ValueError('Invalid semantic retrieval file state.')
    return state


def save_state(path, state, dry_run):
    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')


def sync(root, home, clients, enabled, dry_run, update):
    base = home / '.my-ai-configuration'
    target = base / 'semantic-retrieval'
    state_path = base / 'semantic-retrieval.json'
    state = load_state(state_path)
    clients = list(dict.fromkeys(clients))
    if base.exists() and base.is_symlink():
        raise ValueError('Semantic retrieval state directory must not be a symbolic link.')
    if not enabled:
        owned = [client for client in state['clients'] if client in clients]
        if dry_run:
            print('DRYRUN disable semantic retrieval: ' + (', '.join(owned) if owned else 'nothing owned'))
            return
        for client in owned:
            command(client, [client, 'mcp', 'remove', NAME] + (['--scope', 'user'] if client == 'claude' else []), home, False)
        state['clients'] = [client for client in state['clients'] if client not in clients]
        if state['clients']:
            save_state(state_path, state, False)
            return
        if target.is_symlink():
            raise ValueError('Semantic retrieval directory must not be a symbolic link.')
        if target.exists() and target.is_dir():
            shutil.rmtree(target)
        state_path.unlink(missing_ok=True)
        return

    if target.exists() and not state['files']:
        raise ValueError('Semantic retrieval directory exists without setup ownership; refusing to overwrite it.')
    if dry_run:
        print('DRYRUN enable semantic retrieval: Qwen3-Embedding-0.6B')
        return
    target.mkdir(parents=True, exist_ok=True)
    source = root / 'shared' / 'retrieval'
    for name in FILES:
        shutil.copy2(source / name, target / name)
        state['files'][name] = digest(target / name)
    python = ensure_runtime(target, False)
    existing_clients = set(state['clients'])
    state['clients'] = list(dict.fromkeys(state['clients']))
    save_state(state_path, state, False)
    arguments = ['--', str(python), str(target / 'server.py'), '--root', '.', '--data-dir', str(target / 'data'), '--model-cache', str(target / 'model-cache')]
    for client in clients:
        command_args = [client, 'mcp', 'add']
        if client == 'claude':
            command_args += ['--scope', 'user', '-e', f'HF_HOME={target / "model-cache"}']
        else:
            command_args += ['--env', f'HF_HOME={target / "model-cache"}']
        command_args += [NAME] + arguments
        if update and client in existing_clients:
            command(client, [client, 'mcp', 'remove', NAME] + (['--scope', 'user'] if client == 'claude' else []), home, False)
        command(client, command_args, home, False)
        if client not in state['clients']:
            state['clients'].append(client)
            save_state(state_path, state, False)
    save_state(state_path, state, False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('sync',))
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--home', required=True, type=Path)
    parser.add_argument('--client', choices=('codex', 'claude', 'both'), required=True)
    parser.add_argument('--enabled', choices=('true', 'false'), required=True)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true')
    args = parser.parse_args()
    clients = ('codex', 'claude') if args.client == 'both' else (args.client,)
    sync(args.root.resolve(), args.home.resolve(), clients, args.enabled == 'true', args.dry_run, args.update)
    print('SEMANTIC RETRIEVAL: reconciliation complete' + (' (dry run)' if args.dry_run else ''))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f'Semantic retrieval: {error}', file=sys.stderr)
        raise SystemExit(1)
