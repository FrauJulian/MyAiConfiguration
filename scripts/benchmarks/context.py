"""Report the context the installed clients actually load, as the clients report it.

Complements the byte-based prompt budget gate: Claude's own `/context` and `/skill-doctor`
output and its init event, and Codex's `debug prompt-input`. No model request is made.
With --check, fail when an installed skill is missing from the client listing or is listed
without description context (for example because the client's skill budget dropped it).
"""
import argparse
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import tomllib

TIMEOUT = 180


def kill_tree(process):
    if os.name == 'nt':
        subprocess.run(['taskkill', '/T', '/F', '/PID', str(process.pid)], capture_output=True, timeout=30)
    else:
        process.kill()
    process.wait(timeout=30)


def clean_env():
    return {key: value for key, value in os.environ.items() if not key.startswith(('BUN_INSPECT', 'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT'))}


def skill_names(root):
    names = set()
    for path in root.rglob('SKILL.md') if root.is_dir() else []:
        match = re.search(r'(?m)^name:\s*"?([^"\r\n]+?)"?\s*$', path.read_text(encoding='utf-8-sig', errors='replace'))
        if match:
            names.add(match.group(1))
    return names


def tokens(text):
    text = text.strip().lstrip('~')
    if text in ('', '-'):
        return 0
    return round(float(text[:-1]) * 1000) if text.endswith('k') else round(float(text))


def table_rows(markdown, heading):
    section = re.search(rf'(?ms)^### {re.escape(heading)}\s*$(.*?)(?=^### |\Z)', markdown)
    rows = []
    for line in (section.group(1) if section else '').splitlines():
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if line.startswith('|') and len(cells) >= 2 and not set(cells[0]) <= set('-') and cells[0] not in ('Category', 'Skill', 'Agent Type', 'Type', 'Tool'):
            rows.append(cells)
    return rows


def claude_print(claude, work, prompt, extra=()):
    result = subprocess.run([claude, '-p', prompt, '--output-format', 'json', *extra], cwd=work, env=clean_env(),
                            capture_output=True, text=True, encoding='utf-8', timeout=TIMEOUT)
    return json.loads(result.stdout).get('result', '')


def claude_init(claude, work, extra=()):
    process = subprocess.Popen([claude, '-p', 'context probe', '--output-format', 'stream-json', '--verbose', *extra], cwd=work,
                               env=clean_env(), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               text=True, encoding='utf-8')
    lines = queue.Queue()
    threading.Thread(target=lambda: [lines.put(line) for line in process.stdout], daemon=True).start()
    try:
        while True:
            event = json.loads(lines.get(timeout=TIMEOUT))
            if event.get('subtype') == 'init':
                return event
    finally:
        kill_tree(process)


def measure_claude(home, work):
    claude = shutil.which('claude')
    if not claude:
        return {'available': False}
    context = claude_print(claude, work, '/context')
    doctor = claude_print(claude, work, '/skill-doctor')
    init = claude_init(claude, work)
    listed = {row[0]: tokens(row[2]) for row in table_rows(context, 'Skills') if len(row) >= 3}
    doctor_context = {}
    for line in doctor.splitlines():
        cells = line.split()
        if len(cells) >= 3 and re.fullmatch(r'~?\d+(\.\d+)?k?|-', cells[2]):
            doctor_context[cells[0]] = tokens(cells[2])
    installed = skill_names(home / '.claude/skills')
    return {
        'available': True,
        'categories': {row[0]: tokens(row[1]) for row in table_rows(context, 'Estimated usage by category')},
        'plugins': sorted(plugin.get('name', str(plugin)) if isinstance(plugin, dict) else str(plugin) for plugin in init.get('plugins', [])),
        'agents': len(init.get('agents', [])),
        'mcp_servers': len(init.get('mcp_servers', [])),
        'skills_listed': len(listed),
        'installed_skills_missing': sorted(installed - set(listed)),
        'skills_without_context': sorted(name for name, value in {**listed, **doctor_context}.items() if value == 0),
    }


def measure_codex(home, work):
    codex = shutil.which('codex')
    if not codex:
        return {'available': False}
    result = subprocess.run([codex, 'debug', 'prompt-input', 'context probe'], cwd=work, env=clean_env(),
                            capture_output=True, text=True, encoding='utf-8', timeout=TIMEOUT)
    prompt = result.stdout
    listed = set(re.findall(r'(?m)^- ([^:\n]+?): .+?\(file: ', '\n'.join(
        part.get('text', '') for item in json.loads(prompt or '[]') for part in item.get('content', []) if isinstance(part, dict))))
    config_path = home / '.codex/config.toml'
    config = tomllib.loads(config_path.read_text(encoding='utf-8-sig')) if config_path.is_file() else {}
    installed = skill_names(home / '.agents/skills')
    return {
        'available': True,
        'prompt_input_tokens_estimate': len(prompt.encode('utf-8')) // 4,
        'plugins': sorted(name for name, value in config.get('plugins', {}).items() if isinstance(value, dict) and value.get('enabled', True)),
        'skills_listed': len(listed),
        'installed_skills_missing': sorted(installed - listed),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='ai-config-context-', ignore_cleanup_errors=True) as directory:
        subprocess.run(['git', 'init', '-q'], cwd=directory, check=True, timeout=60)
        report = {'claude': measure_claude(args.home, directory), 'codex': measure_codex(args.home, directory)}
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for client, data in report.items():
            if not data['available']:
                print(f'{client}: CLI unavailable')
                continue
            print(f'{client}: {data["skills_listed"]} skills listed, plugins: {", ".join(data["plugins"]) or "none"}')
            for key, value in data.items():
                if key not in ('available', 'plugins', 'skills_listed'):
                    print(f'  {key}: {value}')
    problems = [name for data in report.values() if data['available'] for name in data['installed_skills_missing'] + data.get('skills_without_context', [])]
    return 1 if args.check and problems else 0


if __name__ == '__main__':
    sys.exit(main())
