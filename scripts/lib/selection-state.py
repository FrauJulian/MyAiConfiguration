import argparse
import csv
import json
import os
from pathlib import Path
import sys
import tempfile


def validate(state, allow_legacy=False):
    if isinstance(state, dict) and state.get('version') == 1:
        if not allow_legacy:
            raise ValueError('Saved selection predates install options. Run update once without Quick.')
        state = dict(state, version=2, shell={'windows': 'powershell', 'linux': 'bash'}.get(state.get('platform')),
                     update_agents=False, flashbang=True)
        state.pop('platform', None)
    if not isinstance(state, dict) or state.get('version') != 2:
        raise ValueError('Unsupported saved selection.')
    if state.get('shell') not in ('powershell', 'bash') or state.get('client') not in ('codex', 'claude', 'both'):
        raise ValueError('Invalid saved shell or client.')
    if 'semantic_retrieval' not in state:
        state['semantic_retrieval'] = False
    if any(type(state.get(key)) is not bool for key in ('update_agents', 'flashbang', 'semantic_retrieval')):
        raise ValueError('Invalid saved install options. Run update once without Quick.')
    for key in ('selected', 'deselected'):
        values = state.get(key)
        if not isinstance(values, list) or any(not isinstance(value, str) or not value or any(ord(c) < 32 for c in value) for value in values):
            raise ValueError('Invalid saved plugin selection.')
        if len(values) != len(set(values)):
            raise ValueError('Duplicate saved plugin selection.')
    if set(state['selected']) & set(state['deselected']):
        raise ValueError('Conflicting saved plugin selection.')
    return state


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('read', 'write'))
    parser.add_argument('--home', required=True)
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--format', choices=('json', 'tsv'), default='json')
    parser.add_argument('--shell')
    parser.add_argument('--allow-legacy', action='store_true')
    parser.add_argument('--update-agents', choices=('true', 'false'))
    parser.add_argument('--flashbang', choices=('true', 'false'))
    parser.add_argument('--semantic-retrieval', choices=('true', 'false'))
    parser.add_argument('--client')
    parser.add_argument('--selected', nargs='*', default=[])
    parser.add_argument('--deselected', nargs='*', default=[])
    args = parser.parse_args()
    path = Path(args.home) / '.my-ai-configuration' / 'selection.json'
    with open(args.manifest, encoding='utf-8-sig', newline='') as stream:
        names = {row['name'] for row in csv.DictReader(stream, delimiter='\t')}
    if args.action == 'read':
        if not path.is_file():
            raise ValueError('No saved selection. Run install or update once without Quick.')
        state = validate(json.loads(path.read_text(encoding='utf-8-sig')), args.allow_legacy)
        for key in ('selected', 'deselected'):
            state[key] = [name for name in state[key] if name in names]
        if args.format == 'json':
            print(json.dumps(state))
        else:
            print('shell\t' + state['shell'])
            print('client\t' + state['client'])
            for key in ('update_agents', 'flashbang', 'semantic_retrieval'):
                print(key + '\t' + str(state[key]).lower())
            for key in ('selected', 'deselected'):
                for name in state[key]:
                    print(key + '\t' + name)
        return
    state = validate(dict(version=2, shell=args.shell, client=args.client,
                          update_agents=None if args.update_agents is None else args.update_agents == 'true',
                          flashbang=None if args.flashbang is None else args.flashbang == 'true',
                          semantic_retrieval=False if args.semantic_retrieval is None else args.semantic_retrieval == 'true',
                          selected=args.selected, deselected=args.deselected))
    if (set(state['selected']) | set(state['deselected'])) - names:
        raise ValueError('Unknown plugin in selection.')
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(state, stream, indent=2)
            stream.write('\n')
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f'Selection state: {error}', file=sys.stderr)
        sys.exit(1)
