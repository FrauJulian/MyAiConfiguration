import argparse
import json
from pathlib import Path
import re
import sys
import tomllib


def is_flashbang(hook):
    return any(re.search(r'(?:[/\\\s"\x27]|^)flashbang\.(?:ps1|sh)(?:[\s"\x27]|$)', str(hook.get(key, '')), re.I)
               for key in ('command', 'command_windows'))


def filter_flashbang(path):
    content = path.read_text(encoding='utf-8-sig')
    if path.name == 'settings.json':
        settings = json.loads(content)
        groups = settings.get('hooks', {}).get('Stop', [])
        remaining = []
        for group in groups:
            hooks = [hook for hook in group.get('hooks', []) if not is_flashbang(hook)]
            if hooks:
                remaining.append(dict(group, hooks=hooks))
        if remaining:
            settings['hooks']['Stop'] = remaining
        elif 'Stop' in settings.get('hooks', {}):
            del settings['hooks']['Stop']
        return json.dumps(settings, indent=2, ensure_ascii=False) + '\n'
    if path.name != 'config.toml':
        raise ValueError('Flashbang filtering only supports client configuration files.')
    tomllib.loads(content)
    sections = re.split(r'(?m)(?=^\s*\[\[?[^\r\n]+\]\]?\s*$)', content)
    filtered = []
    for section in sections:
        if re.match(r'\s*\[\[hooks\.Stop\.hooks\]\]', section):
            hook = tomllib.loads(section)['hooks']['Stop']['hooks'][0]
            if is_flashbang(hook):
                continue
        filtered.append(section)
    result = ''.join(filtered)
    result = re.sub(r'(?m)^\[\[hooks\.Stop\]\][ \t]*\r?\n\s*(?=\[|\Z)(?!\[\[hooks\.Stop\.hooks\]\])', '', result)
    tomllib.loads(result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('filter',))
    parser.add_argument('--path', type=Path, required=True)
    parser.add_argument('--flashbang', choices=('true', 'false'), required=True)
    args = parser.parse_args()
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        print(filter_flashbang(args.path) if args.flashbang == 'false' else args.path.read_text(encoding='utf-8-sig'), end='')
    except (OSError, ValueError, KeyError) as error:
        print(f'Install options: {error}', file=sys.stderr)
        sys.exit(1)
