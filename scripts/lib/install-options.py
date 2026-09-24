import argparse
import json
from pathlib import Path
import re
import sys
import tomllib


def is_flashbang(hook):
    return any(re.search(r'(?:[/\\\s"\x27]|^)flashbang\.(?:ps1|sh)(?:[\s"\x27]|$)', str(hook.get(key, '')), re.I)
               for key in ('command', 'command_windows'))


def filter_options(path, flashbang_enabled=True, statusline_enabled=True):
    content = path.read_text(encoding='utf-8-sig')
    if path.name == 'settings.json':
        settings = json.loads(content)
        if not flashbang_enabled:
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
        if not statusline_enabled:
            settings.pop('statusLine', None)
        return json.dumps(settings, indent=2, ensure_ascii=False) + '\n'
    if path.name != 'config.toml':
        raise ValueError('Install option filtering only supports client configuration files.')
    tomllib.loads(content)
    result = content
    if not flashbang_enabled:
        sections = re.split(r'(?m)(?=^\s*\[\[?[^\r\n]+\]\]?\s*$)', result)
        filtered = []
        for section in sections:
            if re.match(r'\s*\[\[hooks\.Stop\.hooks\]\]', section):
                hook = tomllib.loads(section)['hooks']['Stop']['hooks'][0]
                if is_flashbang(hook):
                    continue
            filtered.append(section)
        result = ''.join(filtered)
        result = re.sub(r'(?m)^\[\[hooks\.Stop\]\][ \t]*\r?\n\s*(?=\[|\Z)(?!\[\[hooks\.Stop\.hooks\]\])', '', result)
    if not statusline_enabled:
        sections = re.split(r'(?m)(?=^\s*\[\[?[^\r\n]+\]\]?\s*$)', result)
        for index, section in enumerate(sections):
            header = re.match(r'\s*\[\[?([^\]\r\n]+)\]\]?\s*(?:#.*)?(?:\r?\n|$)', section)
            if header and header.group(1).strip() == 'tui':
                sections[index] = re.sub(r'(?m)^[ \t]*status_line[ \t]*=.*(?:\r?\n|$)', '', section)
                break
        result = ''.join(sections)
    tomllib.loads(result)
    return result


def filter_flashbang(path):
    return filter_options(path, flashbang_enabled=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('filter',))
    parser.add_argument('--path', type=Path, required=True)
    parser.add_argument('--flashbang', choices=('true', 'false'), required=True)
    parser.add_argument('--statusline', choices=('true', 'false'), default='true')
    args = parser.parse_args()
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        print(filter_options(args.path, args.flashbang == 'true', args.statusline == 'true'), end='')
    except (OSError, ValueError, KeyError) as error:
        print(f'Install options: {error}', file=sys.stderr)
        sys.exit(1)
