"""Run the benchmark tasks with and without the installed setup and compare the results.

Each run copies a task fixture into a fresh Git repository, gives the client the task prompt,
then runs hidden checks the agent never saw. A failed check gets one rework turn with the check
output. Results land in <out>/results.jsonl and <out>/summary.md.

Arms:
  setup     the installed configuration (CLAUDE.md, settings, plugins, skills, MCP servers).
  baseline  Claude with --setting-sources "" --strict-mcp-config (no user settings, plugins,
            user skills, CLAUDE.md, or MCP servers); Codex with CODEX_HOME set to --codex-baseline-home,
            an empty home where you ran `codex login` once, with every user and plugin skill disabled.

Both arms of a client use the same pinned model and reasoning effort. Before any run, a preflight
records what each arm actually loads (model, effort, skills by source, plugins, MCP servers,
instructions) in <out>/provenance.json and stops if the arms are not comparable.
"""
import argparse
import fnmatch
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import queue
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time

TASKS = Path(__file__).resolve().parent / 'tasks'
CHECK = [sys.executable, '-m', 'unittest', 'discover', '-s', 'bench_hidden', '-t', '.']
CLAUDE_TOOLS = ['Read', 'Edit', 'Write', 'Glob', 'Grep', 'Agent', 'Skill', 'TodoWrite', 'Bash(python *)', 'Bash(git *)',
                'Bash(ls *)', 'Bash(dotnet *)', 'Bash(node *)', 'PowerShell(python *)', 'PowerShell(git *)', 'PowerShell(Get-ChildItem *)',
                'PowerShell(dotnet *)', 'PowerShell(node *)']


def clean_env(**values):
    env = {key: value for key, value in os.environ.items() if not key.startswith(('BUN_INSPECT', 'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT'))}
    env.update(values)
    return env


def kill_tree(process):
    if os.name == 'nt':
        subprocess.run(['taskkill', '/T', '/F', '/PID', str(process.pid)], capture_output=True, timeout=30)
    else:
        process.kill()
    process.wait(timeout=30)


def run_jsonl(command, cwd, env, timeout, prompt):
    """Run a client, return (events, seconds, timed_out); output is read on a thread so the deadline holds.

    The prompt goes through stdin: on Windows the clients start through .cmd shims that cut arguments at newlines.
    """
    start = time.monotonic()
    process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, text=True, encoding='utf-8', errors='replace')
    threading.Thread(target=lambda: (process.stdin.write(prompt), process.stdin.close()), daemon=True).start()
    lines = queue.Queue()
    threading.Thread(target=lambda: ([lines.put(line) for line in process.stdout], lines.put(None)), daemon=True).start()
    events, timed_out = [], False
    while True:
        try:
            line = lines.get(timeout=max(1, timeout - (time.monotonic() - start)))
        except queue.Empty:
            timed_out = True
            break
        if line is None:
            break
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    kill_tree(process) if process.poll() is None else process.wait()
    return events, time.monotonic() - start, timed_out


def claude_flags(arm, args):
    flags = ['--model', args.claude_model, '--effort', args.claude_effort]
    if arm == 'baseline':
        flags += ['--setting-sources', '', '--strict-mcp-config']
    if arm == 'setup-no-search':
        flags += ['--disallowedTools', 'Skill(semantic-search)', 'Bash(*qmd-search*)', 'PowerShell(*qmd-search*)',
                  '--append-system-prompt', 'The semantic-search skill and the QMD search wrapper are unavailable in this session.']
    return flags


def codex_env(arm, args):
    return clean_env(CODEX_HOME=str(args.codex_baseline_home)) if arm == 'baseline' else clean_env()


def claude_turn(prompt, cwd, arm, args, session):
    command = [shutil.which('claude'), '-p', '--output-format', 'stream-json', '--verbose',
               '--permission-mode', 'auto', '--allowedTools', *CLAUDE_TOOLS, *claude_flags(arm, args)]
    if session:
        command += ['--resume', session]
    timeout = args.timeout
    events, seconds, timed_out = run_jsonl(command, cwd, clean_env(), timeout, prompt)
    result = next((event for event in reversed(events) if event.get('type') == 'result'), {})
    usage = result.get('usage', {})
    calls = [block for event in events if event.get('type') == 'assistant'
             for block in event.get('message', {}).get('content', []) if block.get('type') == 'tool_use']
    commands = [str(call.get('input', {}).get('command', '')) for call in calls if call.get('name') in ('Bash', 'PowerShell')]
    return {
        'session': result.get('session_id') or session, 'seconds': seconds, 'timed_out': timed_out,
        'input_tokens': usage.get('input_tokens', 0) + usage.get('cache_read_input_tokens', 0) + usage.get('cache_creation_input_tokens', 0),
        'output_tokens': usage.get('output_tokens', 0), 'cost_usd': result.get('total_cost_usd') or 0,
        'tool_calls': len(calls), 'agents': sum(call.get('name') == 'Agent' for call in calls),
        'skills': [str(call.get('input', {}).get('skill', '')) for call in calls if call.get('name') == 'Skill'],
        'commands': commands, 'final': str(result.get('result', '')),
        'models': sorted({str(event['message']['model']) for event in events
                          if event.get('type') == 'assistant' and event.get('message', {}).get('model')}),
        'error': str(result.get('result', '') or 'no result event')[:300] if result.get('is_error') or not result else '',
    }


def codex_turn(prompt, cwd, arm, args, session):
    command = [shutil.which('codex'), 'exec']
    if session:
        command += ['resume', session]
    # `exec resume` rejects --sandbox; the config key works for both forms.
    command += ['--json', '--skip-git-repo-check', '-c', 'sandbox_mode="workspace-write"',
                '-m', args.codex_model, '-c', f'model_reasoning_effort="{args.codex_effort}"']
    command += ['-C', str(cwd)] if not session else []
    command.append('-')
    events, seconds, timed_out = run_jsonl(command, cwd, codex_env(arm, args), args.timeout, prompt)
    items = [event.get('item', {}) for event in events if event.get('type') == 'item.completed']
    tools = [item for item in items if item.get('type') not in ('agent_message', 'reasoning', 'error')]
    usage = [event.get('usage', {}) for event in events if event.get('type') == 'turn.completed']
    thread = next((event.get('thread_id') for event in events if event.get('type') == 'thread.started'), session)
    return {
        'session': thread, 'seconds': seconds, 'timed_out': timed_out,
        'input_tokens': sum(entry.get('input_tokens', 0) for entry in usage),
        'output_tokens': sum(entry.get('output_tokens', 0) for entry in usage), 'cost_usd': 0,
        'tool_calls': len(tools), 'agents': sum(item.get('type') == 'collab_tool_call' for item in tools),
        'skills': [], 'commands': [str(item.get('command', '')) for item in tools if item.get('type') == 'command_execution'],
        'final': next((str(item.get('text', '')) for item in reversed(items) if item.get('type') == 'agent_message'), ''),
        'models': [args.codex_model],
        'error': next((str(event.get('message', event.get('error', '')))[:300] for event in events if event.get('type') in ('error', 'turn.failed')
                       and not str(event.get('message', '')).startswith('Reconnecting')), 'no turn.completed event') if not usage else '',
    }


class AppServer:
    """Minimal JSON-RPC client for `codex app-server`; every wait has a deadline."""

    def __init__(self, env, cwd):
        self.process = subprocess.Popen([shutil.which('codex'), 'app-server'], cwd=cwd, env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding='utf-8')
        self.lines, self.next_id = queue.Queue(), 0
        threading.Thread(target=lambda: [self.lines.put(line) for line in self.process.stdout], daemon=True).start()
        self.call('initialize', {'clientInfo': {'name': 'ai-config-benchmark', 'version': '1'}})
        self.process.stdin.write(json.dumps({'jsonrpc': '2.0', 'method': 'initialized'}) + '\n')

    def call(self, method, params):
        self.next_id += 1
        self.process.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': self.next_id, 'method': method, 'params': params}) + '\n')
        self.process.stdin.flush()
        while True:
            message = json.loads(self.lines.get(timeout=120))
            if message.get('id') == self.next_id:
                if 'error' in message:
                    raise RuntimeError(f'{method}: {message["error"]}')
                return message['result']

    def close(self):
        kill_tree(self.process)


def codex_configured(env, cwd):
    server = AppServer(env, cwd)
    try:
        return server.call('config/read', {})['config']
    finally:
        server.close()


def codex_provenance(arm, args, cwd):
    server = AppServer(codex_env(arm, args), cwd)
    try:
        config = server.call('config/read', {})['config']
        listing = lambda: server.call('skills/list', {'cwds': [str(cwd)], 'forceReload': True})['data'][0]['skills']
        skills = listing()
        if arm == 'baseline':
            # Codex reads ~/.agents/skills from the real profile even with another CODEX_HOME; disable those skills there.
            for skill in skills:
                if skill.get('enabled', True) and (skill.get('scope') == 'user' or skill.get('pluginId')):
                    server.call('skills/config/write', {'path': skill['path'], 'enabled': False})
            skills = listing()
    finally:
        server.close()
    prompt = subprocess.run([shutil.which('codex'), 'debug', 'prompt-input', '-c', f'model="{args.codex_model}"',
                             '-c', f'model_reasoning_effort="{args.codex_effort}"', 'provenance probe'],
                            cwd=cwd, env=codex_env(arm, args), capture_output=True, text=True, encoding='utf-8', timeout=180).stdout
    setup_agents = Path.home() / '.codex' / 'AGENTS.md'
    marker = next((line.strip() for line in setup_agents.read_text(encoding='utf-8-sig').splitlines() if line.strip()), '') if setup_agents.is_file() else ''
    enabled = [skill for skill in skills if skill.get('enabled', True)]
    return {
        'model': args.codex_model, 'effort': args.codex_effort,
        'configured_model': config.get('model'), 'configured_effort': config.get('model_reasoning_effort'),
        'sandbox_mode': config.get('sandbox_mode'), 'approval_policy': config.get('approval_policy'),
        'skills_by_scope': {scope: sum(skill.get('scope') == scope and not skill.get('pluginId') for skill in enabled)
                            for scope in sorted({skill.get('scope') for skill in enabled})},
        'plugin_skills': sorted(skill['name'] for skill in enabled if skill.get('pluginId')),
        'user_skills': sorted(skill['name'] for skill in enabled if skill.get('scope') == 'user' and not skill.get('pluginId')),
        'mcp_servers': sorted(config.get('mcp_servers') or {}),
        'global_instructions_loaded': bool(marker) and marker in prompt,
        'prompt_input_tokens_estimate': len(prompt.encode('utf-8')) // 4,
    }


def claude_provenance(arm, args, cwd):
    claude = shutil.which('claude')
    process = subprocess.Popen([claude, '-p', 'provenance probe', '--output-format', 'stream-json', '--verbose', *claude_flags(arm, args)],
                               cwd=cwd, env=clean_env(), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               text=True, encoding='utf-8')
    lines = queue.Queue()
    threading.Thread(target=lambda: [lines.put(line) for line in process.stdout], daemon=True).start()
    try:
        init = {}
        while init.get('subtype') != 'init':
            init = json.loads(lines.get(timeout=180))
    finally:
        kill_tree(process)
    context = json.loads(subprocess.run([claude, '-p', '/context', '--output-format', 'json', *claude_flags(arm, args)], cwd=cwd, env=clean_env(),
                                        capture_output=True, text=True, encoding='utf-8', timeout=180).stdout).get('result', '')

    def rows(heading):
        section = re.search(rf'(?ms)^### {re.escape(heading)}\s*$(.*?)(?=^### |\Z)', context)
        cells = [[cell.strip() for cell in line.strip().strip('|').split('|')] for line in (section.group(1) if section else '').splitlines() if line.startswith('|')]
        return [row for row in cells[2:] if row and row[0]]

    sources = {}
    for row in rows('Skills'):
        source = row[1].split(' (')[0] if len(row) > 1 else '?'
        sources[source] = sources.get(source, 0) + 1
    model = re.search(r'\*\*Model:\*\*\s*(\S+)', context)
    return {
        'model': init.get('model') or (model.group(1) if model else None), 'effort': args.claude_effort,
        'permission_mode': init.get('permissionMode'),
        'skills_by_source': sources, 'skills_listed': len(init.get('skills', [])),
        'plugins': sorted(plugin.get('name', str(plugin)) if isinstance(plugin, dict) else str(plugin) for plugin in init.get('plugins', [])),
        'mcp_servers': sorted(server.get('name', str(server)) if isinstance(server, dict) else str(server) for server in init.get('mcp_servers', [])),
        'memory_files': [row[1] for row in rows('Memory Files') if len(row) > 1],
    }


def preflight(args, clients, arms):
    """Record what each arm loads and return the problems that make the comparison invalid."""
    provenance, problems = {}, []
    with tempfile.TemporaryDirectory(prefix='ai-bench-preflight-', ignore_cleanup_errors=True) as directory:
        subprocess.run(['git', 'init', '-q'], cwd=directory, check=True, timeout=60)
        for client in clients:
            for arm in arms:
                if client == 'codex' and arm == 'setup-no-search':
                    continue
                data = (claude_provenance if client == 'claude' else codex_provenance)(arm, args, Path(directory))
                provenance[f'{client}/{arm}'] = data
                if client == 'claude' and arm == 'baseline':
                    if set(data['skills_by_source']) - {'Built-in'}:
                        problems.append(f'claude baseline loads non-built-in skills: {data["skills_by_source"]}')
                    if data['memory_files'] or data['mcp_servers']:
                        problems.append(f'claude baseline loads memory files {data["memory_files"]} or MCP servers {data["mcp_servers"]}')
                if client == 'codex' and arm == 'baseline':
                    if data['user_skills'] or data['plugin_skills']:
                        problems.append(f'codex baseline still enables user or plugin skills: {data["user_skills"] + data["plugin_skills"]}')
                    if data['global_instructions_loaded'] or data['mcp_servers']:
                        problems.append('codex baseline loads the global AGENTS.md or MCP servers')
            models = {provenance[key]['model'] for key in provenance if key.startswith(client + '/')}
            if len(models) > 1:
                problems.append(f'{client} arms resolve to different models: {sorted(models)}')
    return provenance, problems


QMD_SCRIPTS = Path.home() / '.my-ai-configuration/qmd'
FILLER_TOPICS = [
    ('statement', 'download', 'Render a statement download for the export queue.'),
    ('trial', 'banner', 'Show the trial banner text in the marketing header.'),
    ('upload', 'progress', 'Track upload progress for the dashboard widget.'),
    ('network', 'status', 'Describe the network status shown in the footer.'),
    ('invoice', 'label', 'Format the invoice label printed on envelopes.'),
    ('retry', 'hint', 'Return the retry hint shown next to a failed form field.'),
    ('cent', 'display', 'Format a cent amount for the price badge.'),
    ('customer', 'greeting', 'Pick the greeting for a customer newsletter.'),
]


def generate_filler(work, count):
    """Write deterministic distractor modules that share vocabulary with the task prompts but not their logic."""
    for number in range(count):
        noun, verb, doc = FILLER_TOPICS[number % len(FILLER_TOPICS)]
        name = f'{noun}_{verb}_{number:03d}'
        path = work / 'app' / 'modules' / f'{name}.py'
        path.parent.mkdir(parents=True, exist_ok=True)
        body = [f'def {name}(value, locale="en"):', f'    """{doc}"""', '    text = str(value).strip()',
                f'    return f"{{locale}}:{noun}:{verb}:{{text}}"', '']
        path.write_text('\n'.join(body), encoding='utf-8')
    (work / 'app' / 'modules' / '__init__.py').write_text('', encoding='utf-8')


def warm_index(work):
    """Index the fixture and start the QMD daemon before the session, as in a repository that was searched before."""
    script = QMD_SCRIPTS / 'qmd-warm.mjs'
    if script.is_file():
        subprocess.run(['node', str(script), '--root', str(work)], capture_output=True, timeout=1800)


def check(work, task):
    hidden = work / 'bench_hidden'
    shutil.rmtree(hidden, ignore_errors=True)
    shutil.copytree(task / 'hidden', hidden)
    spec = json.loads((task / 'task.json').read_text(encoding='utf-8'))
    command = CHECK
    if spec.get('check'):
        program, *arguments = spec['check']
        command = [sys.executable if program == 'python' else shutil.which(program) or program, *arguments]
    result = subprocess.run(command, cwd=work, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=600)
    shutil.rmtree(hidden, ignore_errors=True)
    return result.returncode == 0, (result.stdout + result.stderr)[-3000:]


def workflow_violations(spec, turns):
    skills = [skill for turn in turns for skill in turn['skills']]
    agents = sum(turn['agents'] for turn in turns)
    calls = sum(turn['tool_calls'] for turn in turns)
    commands = [command for turn in turns for command in turn['commands']]
    problems = [f'used planning skill {skill}' for skill in skills if skill in spec.get('forbid_skills', [])]
    if agents > spec.get('max_agents', 99):
        problems.append(f'{agents} agents > {spec["max_agents"]}')
    if agents < spec.get('min_agents', 0):
        problems.append(f'{agents} agents < {spec["min_agents"]}')
    if calls > spec.get('max_tool_calls', 10 ** 6):
        problems.append(f'{calls} tool calls > {spec["max_tool_calls"]}')
    if spec.get('require_command') and not any(re.search(spec['require_command'], command) for command in commands):
        problems.append(f'no command matching {spec["require_command"]}')
    return problems


def run_one(job, args):
    client, arm, task, repetition = job
    spec = json.loads((task / 'task.json').read_text(encoding='utf-8'))
    with tempfile.TemporaryDirectory(prefix=f'ai-bench-{task.name[:2]}-', ignore_cleanup_errors=True) as directory:
        work = Path(directory)
        shutil.copytree(task / 'repo', work, dirs_exist_ok=True)
        if spec.get('generate', {}).get('filler_modules'):
            generate_filler(work, spec['generate']['filler_modules'])
        for git in (['init', '-q'], ['add', '-A'], ['-c', 'user.name=bench', '-c', 'user.email=bench@example.invalid', 'commit', '-qm', 'fixture']):
            subprocess.run(['git', '-c', 'core.autocrlf=false', *git], cwd=work, check=True, timeout=60)
        if args.warm_index and arm == 'setup':
            warm_index(work)
        turns, prompt, session = [], spec['prompt'], None
        for round_number in range(1 + args.rework):
            turn = (claude_turn if client == 'claude' else codex_turn)(prompt, work, arm, args, session)
            turns.append(turn)
            session = turn['session']
            if turn['error']:
                passed, output = False, ''
                break
            passed, output = check(work, task)
            if passed or turn['timed_out'] or not session:
                break
            prompt = f'The acceptance checks failed:\n\n{output}\n\nFix the code so they pass.'
        if not passed and args.keep_failed:
            shutil.copytree(work, args.out / 'failed' / f'{client}-{arm}-{task.name}-{repetition}', ignore=shutil.ignore_patterns('.git'))
    return {
        'client': client, 'arm': arm, 'task': task.name, 'repetition': repetition, 'passed': passed,
        'error': next((turn['error'] for turn in turns if turn['error']), ''),
        'first_try': passed and len(turns) == 1, 'rework_turns': len(turns) - 1,
        'seconds': round(sum(turn['seconds'] for turn in turns), 1),
        'input_tokens': sum(turn['input_tokens'] for turn in turns), 'output_tokens': sum(turn['output_tokens'] for turn in turns),
        'cost_usd': round(sum(turn['cost_usd'] for turn in turns), 4), 'tool_calls': sum(turn['tool_calls'] for turn in turns),
        'agents': sum(turn['agents'] for turn in turns), 'skills': [skill for turn in turns for skill in turn['skills']],
        'commands': [command for turn in turns for command in turn['commands']],
        'models': sorted({model for turn in turns for model in turn['models']}),
        'searches': sum('qmd-search' in command for turn in turns for command in turn['commands'])
                    + sum(skill == 'semantic-search' for turn in turns for skill in turn['skills']),
        'timed_out': any(turn['timed_out'] for turn in turns), 'workflow_kind': spec['workflow'].get('kind'),
        'workflow_violations': workflow_violations(spec['workflow'], turns), 'check_output': '' if passed else output,
    }


def summarize(results):
    errors = [result for result in results if result.get('error')]
    results = [result for result in results if not result.get('error')]
    lines = [f'Excluded {len(errors)} runs that ended with a client or API error (for example a usage limit).',
             'Rows are per task category; an overall average would hide a category where one arm is worse.', '',
             '| category | client | arm | runs | pass | first try | rework turns | median s | median input tok | median output tok | median tool calls | cost USD | workflow ok |',
             '|---|---|---|---|---|---|---|---|---|---|---|---|---|']
    groups = {}
    for result in results:
        spec = TASKS / result['task'] / 'task.json'
        category = json.loads(spec.read_text(encoding='utf-8')).get('category', '?') if spec.is_file() else '?'
        groups.setdefault((category, result['client'], result['arm']), []).append(result)
    for (category, client, arm), runs in sorted(groups.items()):
        median = lambda key: statistics.median(run[key] for run in runs)
        lines.append(f'| {category} | {client} | {arm} | {len(runs)} | {sum(run["passed"] for run in runs) / len(runs):.0%} | '
                     f'{sum(run["first_try"] for run in runs) / len(runs):.0%} | {sum(run["rework_turns"] for run in runs)} | '
                     f'{median("seconds"):.0f} | {median("input_tokens"):.0f} | {median("output_tokens"):.0f} | {median("tool_calls"):.0f} | '
                     f'{sum(run["cost_usd"] for run in runs):.2f} | {sum(not run["workflow_violations"] for run in runs) / len(runs):.0%} |')
    lines += ['', '## Workflow checks', '', '| client | arm | task | violations |', '|---|---|---|---|']
    for result in sorted(results, key=lambda run: (run['client'], run['arm'], run['task'], run['repetition'])):
        if result['workflow_violations']:
            lines.append(f'| {result["client"]} | {result["arm"]} | {result["task"]} #{result["repetition"]} | {"; ".join(result["workflow_violations"])} |')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0], formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    parser.add_argument('--clients', nargs='+', choices=('claude', 'codex'), default=['claude', 'codex'])
    parser.add_argument('--arms', nargs='+', choices=('setup', 'baseline', 'setup-no-search'), default=['setup', 'baseline'],
                        help='setup-no-search is the setup with the semantic-search skill and CLI blocked (Claude only)')
    parser.add_argument('--warm-index', action='store_true', help='start the QMD daemon and index the fixture before setup-arm sessions, outside the timing')
    parser.add_argument('--tasks', nargs='+', help='task directory names or patterns such as 11-* (default: all)')
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--first-repetition', type=int, default=1, help='number of the first repetition, to rerun selected repetitions')
    parser.add_argument('--rework', type=int, default=1, help='rework turns after a failed check')
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--timeout', type=int, default=900, help='seconds per client turn')
    parser.add_argument('--claude-model', default='sonnet')
    parser.add_argument('--claude-effort', default='medium', choices=('low', 'medium', 'high', 'xhigh', 'max'))
    parser.add_argument('--codex-model', help="default: the setup's configured model, pinned for both arms")
    parser.add_argument('--codex-effort', help="default: the setup's configured reasoning effort, pinned for both arms")
    parser.add_argument('--allow-unisolated', action='store_true', help='run even when the preflight finds the arms not comparable')
    parser.add_argument('--codex-baseline-home', type=Path, default=Path.home() / '.my-ai-configuration/benchmark/codex-home')
    parser.add_argument('--out', type=Path, default=Path(tempfile.gettempdir()) / f'ai-config-ab-{time.strftime("%Y%m%d-%H%M%S")}')
    parser.add_argument('--dry-run', action='store_true', help='list the runs without starting clients')
    parser.add_argument('--keep-failed', action='store_true', help='copy failed work trees to <out>/failed')
    parser.add_argument('--summarize', nargs='+', type=Path, metavar='RESULTS', help='only summarize results.jsonl files; a later file replaces runs of an earlier one')
    args = parser.parse_args()
    if args.summarize:
        merged = {}
        for path in args.summarize:
            for line in path.read_text(encoding='utf-8').splitlines():
                result = json.loads(line)
                key = (result['client'], result['arm'], result['task'], result['repetition'])
                if not result.get('error') or key not in merged:
                    merged[key] = result
        print(summarize(list(merged.values())))
        return 0
    tasks = [path for path in sorted(TASKS.iterdir()) if path.is_dir() and (not args.tasks or any(fnmatch.fnmatch(path.name, pattern) for pattern in args.tasks))]
    for client in args.clients:
        if not shutil.which(client):
            parser.error(f'{client} CLI unavailable')
    if 'codex' in args.clients and 'baseline' in args.arms and not (args.codex_baseline_home / 'auth.json').is_file():
        parser.error(f'Codex baseline needs a login: run CODEX_HOME="{args.codex_baseline_home}" codex login')
    jobs = [(client, arm, task, repetition) for repetition in range(args.first_repetition, args.first_repetition + args.repetitions)
            for task in tasks for client in args.clients for arm in args.arms if not (client == 'codex' and arm == 'setup-no-search')]
    if 'codex' in args.clients and not (args.codex_model and args.codex_effort):
        configured = codex_configured(clean_env(), Path.cwd())
        args.codex_model = args.codex_model or configured.get('model')
        args.codex_effort = args.codex_effort or configured.get('model_reasoning_effort') or 'medium'
        if not args.codex_model:
            parser.error('the setup configures no Codex model; pass --codex-model')
    provenance, problems = preflight(args, args.clients, args.arms)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'provenance.json').write_text(json.dumps({'provenance': provenance, 'problems': problems}, indent=2), encoding='utf-8')
    for key, data in provenance.items():
        print(f'{key}: model={data["model"]} effort={data["effort"]} ' + ' '.join(f'{name}={value}' for name, value in data.items()
                                                                                if name in ('skills_by_source', 'skills_by_scope', 'plugins', 'mcp_servers')))
    for problem in problems:
        print(f'NOT COMPARABLE: {problem}')
    if problems and not args.allow_unisolated:
        return 2
    print(f'{len(jobs)} runs -> {args.out}')
    if args.dry_run:
        for client, arm, task, repetition in jobs:
            print(f'  {client} {arm} {task.name} #{repetition}')
        return 0
    args.out.mkdir(parents=True, exist_ok=True)
    results, lock = [], threading.Lock()

    def record(job):
        result = run_one(job, args)
        with lock:
            results.append(result)
            with open(args.out / 'results.jsonl', 'a', encoding='utf-8') as stream:
                stream.write(json.dumps(result) + '\n')
            print(f'[{len(results)}/{len(jobs)}] {result["client"]} {result["arm"]} {result["task"]} #{result["repetition"]}: '
                  f'{"PASS" if result["passed"] else "FAIL"} {result["seconds"]}s {result["tool_calls"]} tools', flush=True)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(record, jobs))
    (args.out / 'summary.md').write_text(summarize(results), encoding='utf-8')
    print(summarize(results))
    return 0


if __name__ == '__main__':
    sys.exit(main())
