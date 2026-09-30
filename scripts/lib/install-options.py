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


def merge_json(current, managed):
    if not isinstance(current, dict) or not isinstance(managed, dict):
        return managed
    result = dict(current)
    if 'statusLine' not in managed:
        result.pop('statusLine', None)
    for key, value in managed.items():
        if key == 'hooks' and isinstance(value, dict) and isinstance(result.get(key), dict):
            hooks = dict(result[key])
            for event in set(value) | {'Stop'}:
                groups = value.get(event, [])
                old_groups = hooks.get(event, [])
                if isinstance(groups, list) and isinstance(old_groups, list):
                    retained = [group for group in old_groups if not any(
                        re.search(r'(?:flashbang|statusline|record-compact|session-state-pointer)\.(?:ps1|sh)',
                                  str(hook.get('command', '')) + str(hook.get('command_windows', '')), re.I)
                        for hook in group.get('hooks', []) if isinstance(hook, dict)
                    )]
                    merged = groups + [group for group in retained if group not in groups]
                    if merged:
                        hooks[event] = merged
                    else:
                        hooks.pop(event, None)
                else:
                    hooks[event] = value
            result[key] = hooks
        elif isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge_json(result[key], value)
        else:
            result[key] = value
    return result


def merge_toml(current_text, managed_text):
    tomllib.loads(current_text)
    tomllib.loads(managed_text)
    managed_root_keys = set(tomllib.loads(managed_text))
    lines = current_text.splitlines(keepends=True)
    root = []
    blocks = []
    active = root
    for line in lines:
        header = re.match(r'^\s*(\[\[?.+?\]\]?)\s*(?:#.*)?$', line.rstrip('\r\n'))
        if header:
            active = []
            blocks.append((header.group(1), active))
        if active is root:
            assignment = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=', line)
            if assignment and assignment.group(1) in managed_root_keys:
                continue
        active.append(line)

    managed_headers = set(re.findall(r'(?m)^\s*(\[\[?.+?\]\]?)\s*(?:#.*)?$', managed_text))
    extras = []
    for header, block in blocks:
        plugin_table = re.match(r'^\[(?:plugins|marketplaces)(?:\.|\])', header)
        array_table = header.startswith('[[')
        owned_hook = any(re.search(r'(?:flashbang|statusline|record-compact|session-state-pointer)\.(?:ps1|sh)', line, re.I) for line in block)
        if plugin_table and header in managed_headers:
            raise ValueError('Cannot merge conflicting managed plugin tables.')
        if header not in managed_headers or (array_table and not owned_hook):
            extras.extend(block)

    result = managed_text
    if root and ''.join(root).strip():
        managed_lines = managed_text.splitlines(keepends=True)
        split = next((i for i, line in enumerate(managed_lines) if re.match(r'^\s*\[', line)), len(managed_lines))
        result = ''.join(managed_lines[:split]).rstrip() + '\n' + ''.join(root).strip() + '\n' + ''.join(managed_lines[split:])
    if extras:
        result = result.rstrip() + '\n\n' + ''.join(extras).lstrip()
    tomllib.loads(result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('filter', 'merge-json', 'merge-toml'))
    parser.add_argument('--path', type=Path)
    parser.add_argument('--current', type=Path)
    parser.add_argument('--flashbang', choices=('true', 'false'))
    parser.add_argument('--statusline', choices=('true', 'false'), default='true')
    args = parser.parse_args()
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        if args.action == 'filter':
            print(filter_options(args.path, args.flashbang == 'true', args.statusline == 'true'), end='')
        else:
            if args.action == 'merge-json':
                current = json.loads(args.current.read_text(encoding='utf-8-sig'))
                managed = json.load(sys.stdin)
                print(json.dumps(merge_json(current, managed), indent=2, ensure_ascii=False) + '\n', end='')
            else:
                print(merge_toml(args.current.read_text(encoding='utf-8-sig'), sys.stdin.read()), end='')
    except (OSError, ValueError, KeyError) as error:
        print(f'Install options: {error}', file=sys.stderr)
        sys.exit(1)
