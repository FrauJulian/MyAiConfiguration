import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
from datetime import datetime, timezone


def state_path(workspace):
    if not isinstance(workspace, str) or not workspace or any(ord(c) < 32 for c in workspace):
        raise ValueError('Invalid workspace')
    root = Path(workspace)
    if not root.is_absolute() or not root.is_dir():
        raise ValueError('Invalid workspace')
    root = root.resolve()
    directory = root / '.ai-session'
    path = directory / 'state.json'
    if directory.is_symlink() or path.is_symlink() or directory.resolve().parent != root:
        raise ValueError('Invalid state path')
    return path


def show_pointer(path):
    if path.is_file():
        print('Task state is available at ' + str(path) + '; validate its workspace and goal before reuse.')


def hook_pointer():
    try:
        raw = '' if sys.stdin.isatty() else sys.stdin.buffer.read(1048577).decode('utf-8-sig')
        if len(raw) > 1048576:
            return
        event = json.loads(raw) if raw.strip() else {}
        if not isinstance(event, dict):
            return
        show_pointer(state_path(event.get('cwd', os.getcwd())))
    except (ValueError, OSError, RecursionError):
        return


def update_state(args):
    path = state_path(args.workspace)
    if args.pointer:
        show_pointer(path)
        return
    state = json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else {}
    if not isinstance(state, dict):
        raise ValueError('Invalid task state')
    workspace = str(path.parent.parent)
    if state.get('workspace', workspace) != workspace:
        raise ValueError('Task state belongs to another workspace')
    for old, new in (('changedFiles', 'changed'), ('pending', 'open'), ('importantFindings', 'decisions')):
        if old in state:
            state.setdefault(new, state.pop(old))
    for field in ('goal', 'decisions', 'changed', 'verified', 'open', 'risks'):
        if field not in state:
            continue
        value = state[field]
        if field == 'goal':
            valid = isinstance(value, str)
        else:
            valid = isinstance(value, list) and all(isinstance(item, str) for item in value)
        if not valid:
            raise ValueError('Invalid task state field')
    if args.reset:
        state = {}
    elif args.goal is not None and state.get('goal') and state['goal'] != args.goal:
        raise ValueError('A different goal requires reset')
    state['workspace'] = workspace
    for field in ('goal', 'decisions', 'changed', 'verified', 'open', 'risks'):
        value = getattr(args, field)
        if value is not None:
            state[field] = value
        else:
            state.setdefault(field, '' if field == 'goal' else [])
    state['updatedAt'] = datetime.now(timezone.utc).isoformat()
    path.parent.mkdir(exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         prefix='.state-', suffix='.tmp', delete=False) as output:
            temporary = output.name
            json.dump(state, output, ensure_ascii=False, indent=2)
            output.write('\n')
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            os.unlink(temporary)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser()
    parser.add_argument('--hook', action='store_true')
    parser.add_argument('--update-json', action='store_true')
    parser.add_argument('--workspace', default=os.getcwd())
    parser.add_argument('--pointer', action='store_true')
    parser.add_argument('--reset', action='store_true')
    parser.add_argument('--goal')
    for field in ('decisions', 'changed', 'verified', 'open', 'risks'):
        parser.add_argument('--' + field, nargs='*')
    args = parser.parse_args()
    if args.hook:
        hook_pointer()
    else:
        try:
            if args.update_json:
                values = json.loads(sys.stdin.buffer.read().decode('utf-8-sig'))
                if not isinstance(values, dict):
                    raise ValueError('Invalid task state update')
                for field, value in values.items():
                    if field not in ('workspace', 'goal', 'decisions', 'changed', 'verified', 'open', 'risks'):
                        raise ValueError('Invalid task state field')
                    if field in ('workspace', 'goal'):
                        if not isinstance(value, str):
                            raise ValueError('Invalid task state value')
                    elif not isinstance(value, list) or any(not isinstance(item, str) for item in value):
                        raise ValueError('Invalid task state list')
                    setattr(args, field, value)
            update_state(args)
        except (ValueError, OSError):
            parser.exit(1, 'Cannot read or update task state for this workspace.\n')


if __name__ == '__main__':
    main()
