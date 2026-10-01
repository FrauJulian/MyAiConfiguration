"""Check that generated agent limits and permissions take effect, not only that the clients accept them.

Static checks (always, when the CLI is installed): the generated Codex package keeps the V1 multi-agent
implementation that honors agents.max_depth, and Codex reads the configured limits back.
Live checks (only with AI_CONFIG_LIVE_TESTS=1, they start short Haiku sessions): Claude, with only the generated
settings env applied, withholds the Agent tool from subagents and refuses an over-limit burst of parallel subagents;
with only the generated deny rules applied, blocks a destructive git command in every shell tool.
"""
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent.parent
SHELL = 'powershell' if os.name == 'nt' else 'bash'
LIVE = os.environ.get('AI_CONFIG_LIVE_TESTS') == '1'
TIMEOUT = 600


def clean_env(**values):
    env = {key: value for key, value in os.environ.items() if not key.startswith(('BUN_INSPECT', 'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT', 'CODEX'))}
    env.update(values)
    return env


def stop(process):
    if os.name == 'nt':
        subprocess.run(['taskkill', '/T', '/F', '/PID', str(process.pid)], capture_output=True, timeout=30)
    else:
        process.kill()
    process.wait(timeout=30)


def stream_events(command, cwd, env):
    """Collect JSON lines until the process exits or TIMEOUT passes."""
    process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               text=True, encoding='utf-8', errors='replace')
    lines = queue.Queue()
    threading.Thread(target=lambda: ([lines.put(line) for line in process.stdout], lines.put(None)), daemon=True).start()
    events, deadline = [], time.monotonic() + TIMEOUT
    try:
        while True:
            line = lines.get(timeout=max(1, deadline - time.monotonic()))
            if line is None:
                return events
            try:
                events.append(json.loads(line))
            except ValueError:
                pass
    except queue.Empty:
        raise AssertionError(f'client did not finish within {TIMEOUT}s') from None
    finally:
        if process.poll() is None:
            stop(process)


class CodexAgentLimitTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('codex'), 'Codex CLI unavailable')
    def test_generated_limits_use_the_implementation_that_honors_them(self):
        generated = (ROOT / f'generated/codex-{SHELL}/config.toml').read_text(encoding='utf-8-sig')
        config = tomllib.loads(generated.replace('__AI_CONFIG_ROOT__', '/x').replace('__HOOK_COMMAND__', 'x')
                               .replace('__POWERSHELL_HOOK_COMMAND__', 'x').replace('__POWERSHELL_COMMAND__', 'x'))
        self.assertEqual(config['agents']['max_depth'], 1)
        with tempfile.TemporaryDirectory() as home:
            (Path(home) / 'config.toml').write_text(generated.replace('__AI_CONFIG_ROOT__', Path(home).as_posix()), encoding='utf-8')
            listing = subprocess.run([shutil.which('codex'), 'features', 'list'], env=clean_env(CODEX_HOME=home),
                                     capture_output=True, text=True, timeout=120).stdout
        states = {line.split()[0]: line.split()[-1] for line in listing.splitlines() if len(line.split()) >= 2}
        # Codex documents agents.max_depth as a limit of the V1 multi-agent implementation; V2 ignores it.
        self.assertEqual(states.get('multi_agent'), 'true', listing)
        self.assertEqual(states.get('multi_agent_v2'), 'false', 'multi_agent_v2 is enabled, so agents.max_depth has no effect')


class ClaudeAgentLimitTests(unittest.TestCase):
    """Live checks with forced test agents, so the result does not depend on how the model paraphrases a task."""

    AGENTS = {
        'spawner': {'description': 'Test agent that starts another agent.', 'tools': ['Agent'],
                    'prompt': 'Your first action: call the Agent tool with subagent_type "general-purpose", description "nested", '
                              'prompt "Reply OK", and run_in_background false. Then output the exact tool result text verbatim.'},
        'sleeper': {'description': 'Test agent that replies once.', 'tools': [], 'prompt': 'Reply with the word OK. Do not use tools.'},
    }

    def setUp(self):
        if not (LIVE and shutil.which('claude')):
            self.skipTest('set AI_CONFIG_LIVE_TESTS=1 with the Claude CLI installed')
        settings = json.loads((ROOT / f'generated/claude-{SHELL}/settings.json').read_text(encoding='utf-8-sig'))
        self.env = {key: value for key, value in settings['env'].items() if not value.startswith('__')}

    def run_claude(self, prompt, env):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as work:
            subprocess.run(['git', 'init', '-q'], cwd=work, check=True, timeout=60)
            events = stream_events([shutil.which('claude'), '-p', prompt, '--output-format', 'stream-json', '--verbose', '--model', 'haiku',
                                    '--setting-sources', '', '--strict-mcp-config', '--settings', json.dumps({'env': env}),
                                    '--agents', json.dumps(self.AGENTS), '--permission-mode', 'auto', '--allowedTools', 'Agent'], work, clean_env())
        return json.dumps(events)

    def test_spawn_depth_removes_the_agent_tool_from_subagents(self):
        self.assertEqual(self.env.get('CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH'), '1')
        prompt = ('Call the Agent tool exactly once with subagent_type "spawner", description "spawn test", prompt "go", and '
                  'run_in_background false. Wait for its result, then quote it verbatim.')
        limited = self.run_claude(prompt, self.env)
        self.assertTrue('matched no tools in this session [Agent]' in limited or 'Subagent nesting limit reached' in limited,
                        'a subagent still had the Agent tool')
        # Control: without the limit the same agent reaches its nested agent, so the check above can fail.
        unlimited = self.run_claude(prompt, {key: value for key, value in self.env.items() if key != 'CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH'})
        self.assertNotIn('matched no tools in this session [Agent]', unlimited)

    def test_concurrency_limit_refuses_the_extra_parallel_subagent(self):
        limit = int(self.env['CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS'])
        prompt = (f'In ONE single message, call the Agent tool {limit + 1} times in parallel with subagent_type "sleeper" and prompt "go". '
                  'Then quote every tool result and error verbatim.')
        self.assertIn(f'You can run {limit} subagents at once', self.run_claude(prompt, self.env))


class ClaudePermissionTests(unittest.TestCase):
    def test_deny_rules_block_destructive_git_in_every_shell_tool(self):
        if not (LIVE and shutil.which('claude')):
            self.skipTest('set AI_CONFIG_LIVE_TESTS=1 with the Claude CLI installed')
        deny = json.loads((ROOT / f'generated/claude-{SHELL}/settings.json').read_text(encoding='utf-8-sig'))['permissions']['deny']
        for tool in ('Bash', 'PowerShell') if os.name == 'nt' else ('Bash',):
            with self.subTest(tool), tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as work:
                for command in (['init', '-q'], ['add', '-A'], ['-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-qm', 'c', '--allow-empty']):
                    subprocess.run(['git', *command], cwd=work, check=True, timeout=60)
                Path(work, 'tracked.txt').write_text('v1')
                subprocess.run(['git', 'add', '-A'], cwd=work, check=True, timeout=60)
                subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-qm', 'v1'], cwd=work, check=True, timeout=60)
                Path(work, 'tracked.txt').write_text('local edit')
                # bypassPermissions isolates the deny rules: nothing else may stop the command.
                events = stream_events([shutil.which('claude'), '-p', f'Use the {tool} tool to run exactly this command and nothing else: git reset --hard',
                               '--output-format', 'stream-json', '--verbose', '--model', 'haiku', '--setting-sources', '', '--strict-mcp-config',
                               '--settings', json.dumps({'permissions': {'deny': deny}}), '--permission-mode', 'bypassPermissions'], work, clean_env())
                attempts = [block for event in events if event.get('type') == 'assistant' for block in event.get('message', {}).get('content', [])
                            if isinstance(block, dict) and block.get('type') == 'tool_use' and block.get('name') == tool]
                self.assertTrue(attempts, f'the model never tried the {tool} tool, so the deny rule was not exercised')
                self.assertEqual(Path(work, 'tracked.txt').read_text(), 'local edit', f'git reset --hard ran through the {tool} tool')


if __name__ == '__main__':
    unittest.main()
