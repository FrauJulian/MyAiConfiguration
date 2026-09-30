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
        elif isinstance(value, list) and isinstance(result.get(key), list):
            result[key] = value + [item for item in result[key] if item not in value]
        else:
            result[key] = value
    return result


def split_toml_sections(content):
    root = []
    sections = []
    active = root
    for line in content.splitlines(keepends=True):
        match = re.match(r'^\s*(\[\[?.+?\]\]?)\s*(?:#.*)?$', line.rstrip('\r\n'))
        if match:
            active = []
            sections.append((match.group(1), active))
        active.append(line)
    return root, sections


def merge_toml(current_text, managed_text, statusline_enabled=True):
    tomllib.loads(current_text)
    tomllib.loads(managed_text)
    managed_root_keys = set(tomllib.loads(managed_text))
    current_root, current_sections = split_toml_sections(current_text)
    managed_root, managed_sections = split_toml_sections(managed_text)
    root_extras = []
    for line in current_root:
        assignment = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=', line)
        if not assignment or assignment.group(1) not in managed_root_keys:
            root_extras.append(line)

    managed_headers = {header for header, _ in managed_sections}
    extras = []
    fields_by_header = {}
    for header, block in current_sections:
        plugin_table = re.match(r'^\[(?:plugins|marketplaces)(?:\.|\])', header)
        array_table = header.startswith('[[')
        owned_hook = any(re.search(r'(?:flashbang|statusline|record-compact|session-state-pointer)\.(?:ps1|sh)', line, re.I) for line in block)
        if plugin_table and header in managed_headers:
            raise ValueError('Cannot merge conflicting managed plugin tables.')
        if (plugin_table and header not in managed_headers) or (array_table and not owned_hook):
            extras.extend(block)
            continue
        if header not in managed_headers:
            continue
        if array_table:
            continue
        generated_block = next(lines for name, lines in managed_sections if name == header)
        generated_keys = {match.group(1) for line in generated_block
                          if (match := re.match(r'^\s*([A-Za-z0-9_-]+)\s*=', line))}
        retained = []
        active_statement = False
        for line in block[1:]:
            assignment = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=', line)
            if assignment:
                active_statement = assignment.group(1) not in generated_keys
                if header == '[tui]' and assignment.group(1) == 'status_line' and not statusline_enabled:
                    active_statement = False
            if active_statement:
                retained.append(line)
        if retained:
            fields_by_header.setdefault(header, []).extend(retained)

    result = ''.join(managed_root).rstrip()
    if root_extras:
        result += '\n' + ''.join(root_extras).strip('\r\n')
    result += '\n'
    for header, block in managed_sections:
        result += ''.join(block)
        if header in fields_by_header:
            result += ''.join(fields_by_header.pop(header))
        if not result.endswith('\n\n'):
            result += '\n'
    if extras:
        result = result.rstrip() + '\n\n' + ''.join(extras).lstrip('\r\n')
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
                print(merge_toml(args.current.read_text(encoding='utf-8-sig'), sys.stdin.read(), args.statusline == 'true'), end='')
    except (OSError, ValueError, KeyError) as error:
        print(f'Install options: {error}', file=sys.stderr)
        sys.exit(1)
