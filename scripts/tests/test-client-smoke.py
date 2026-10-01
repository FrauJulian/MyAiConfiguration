"""Behavioral client smoke tests against an isolated installation.

Each test installs a generated package into a temporary home that already holds
foreign settings, then asks the real client CLI what it discovered. Claude runs
with an invalid API key and is stopped at its init event; Codex is queried
through `codex app-server`. No model request completes.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent.parent
SHELL = 'powershell' if os.name == 'nt' else 'bash'
MARKER_SCRIPT = "import sys; open(sys.argv[1], 'w').write('ok')"


def frontmatter_names(directory, pattern):
    names = set()
    for path in directory.rglob(pattern):
        match = re.search(r'(?m)^name\s*[:=]\s*"?([^"\r\n]+)"?\s*$', path.read_text(encoding='utf-8-sig'))
        if match:
            names.add(match.group(1).strip())
    return names


def marker_command(marker):
    return f'"{sys.executable}" -c "{MARKER_SCRIPT}" "{marker}"'


def clean_env(**values):
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('BUN_INSPECT', 'CLAUDE', 'ANTHROPIC', 'CODEX', 'OPENAI'))}
    env.update(values)
    return env


def install(client, home):
    if SHELL == 'powershell':
        script = ('$ErrorActionPreference = "Stop"; '
                  f'. "{ROOT}/scripts/lib/manifest.ps1"; . "{ROOT}/scripts/lib/install-targets.ps1"; '
                  '$command = "powershell -NoProfile -ExecutionPolicy Bypass -File"; '
                  f'foreach ($item in (Get-InstallTargets -Generated "{ROOT}/generated" -HomePath "{home}" -Shell PowerShell -Client {client})) {{ '
                  'Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp smoke '
                  '-AiConfigRoot $item.Destination.Replace("\\","/") -ShellCommand $command -PowerShellCommand $command -Summary | Out-Null }')
        args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script]
    else:
        script = (f'set -e; . "{ROOT}/scripts/lib/manifest.sh"; . "{ROOT}/scripts/lib/install-targets.sh"; '
                  f'get_install_targets "{ROOT}/generated" "{home}" bash {client.lower()} | '
                  'while IFS="|" read -r source destination; do '
                  'sync_managed_destination "$source" "$destination" smoke "$destination" bash "pwsh -NoProfile -File" false true >/dev/null; done')
        args = ['bash', '-c', script]
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"install failed: {result.stdout}{result.stderr}")


class ClientSmokeTests(unittest.TestCase):
    def setUp(self):
        self.base = Path(tempfile.mkdtemp(prefix='ai-config-client-smoke-'))
        self.home = self.base / 'home'
        self.work = self.base / 'work'
        self.work.mkdir(parents=True)
        subprocess.run(['git', 'init', '-q'], cwd=self.work, check=True)
        self.marker = self.base / 'foreign-hook.txt'

    def tearDown(self):
        shutil.rmtree(self.base, ignore_errors=True)

    @unittest.skipUnless(shutil.which('claude'), 'Claude CLI unavailable')
    def test_claude_discovers_package_and_keeps_foreign_settings(self):
        package = ROOT / f'generated/claude-{SHELL}'
        config = self.home / '.claude'
        config.mkdir(parents=True)
        foreign_hook = {'hooks': [{'type': 'command', 'command': marker_command(self.marker), 'timeout': 10}]}
        (config / 'settings.json').write_text(json.dumps({'foreignSetting': 'keep', 'hooks': {'SessionStart': [foreign_hook]}}))
        install('Claude', self.home)

        process = subprocess.Popen([shutil.which('claude'), '-p', 'smoke', '--output-format', 'stream-json', '--verbose', '--max-turns', '1'],
                                   cwd=self.work, env=clean_env(CLAUDE_CONFIG_DIR=str(config), ANTHROPIC_API_KEY='sk-ant-invalid-smoke'),
                                   stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding='utf-8')
        events = []
        try:
            for line in process.stdout:
                events.append(json.loads(line))
                if events[-1].get('subtype') == 'init':
                    break
        finally:
            process.kill()
            for stream in (process.stdin, process.stdout):
                if stream:
                    stream.close()
            process.wait(timeout=30)
        init = next((event for event in events if event.get('subtype') == 'init'), None)
        self.assertIsNotNone(init, 'Claude emitted no init event')

        with self.subTest('skills'):
            self.assertEqual(sorted(frontmatter_names(package / 'skills', 'SKILL.md') - set(init['skills'])), [])
        with self.subTest('agents'):
            self.assertEqual(sorted(frontmatter_names(package / 'agents', '*.md') - set(init['agents'])), [])
        with self.subTest('hooks'):
            failed = [(event.get('hook_name'), event.get('exit_code'), event.get('stderr', '')[:200])
                      for event in events if event.get('subtype') == 'hook_response' and event.get('exit_code') != 0]
            self.assertEqual(failed, [])
            self.assertTrue(self.marker.exists(), 'foreign SessionStart hook did not run')
        with self.subTest('foreign settings'):
            self.assertEqual(json.loads((config / 'settings.json').read_text(encoding='utf-8-sig')).get('foreignSetting'), 'keep')

    @unittest.skipUnless(shutil.which('codex'), 'Codex CLI unavailable')
    def test_codex_discovers_package_and_keeps_foreign_settings(self):
        package = ROOT / f'generated/codex-{SHELL}'
        codex_home = self.home / '.codex'
        codex_home.mkdir(parents=True)
        command = json.dumps(marker_command(self.marker))
        (codex_home / 'config.toml').write_text(
            '[mcp_servers.smoke_demo]\ncommand = "smoke-demo"\nenabled = false\n\n'
            f'[[hooks.SessionStart]]\n[[hooks.SessionStart.hooks]]\ntype = "command"\ncommand = {command}\ntimeout = 10\n')
        install('Codex', self.home)

        process = subprocess.Popen([shutil.which('codex'), 'app-server'], cwd=self.work,
                                   env=clean_env(CODEX_HOME=str(codex_home), OPENAI_API_KEY='sk-invalid-smoke'),
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding='utf-8')

        def call(request_id, method, params):
            process.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': request_id, 'method': method, 'params': params}) + '\n')
            process.stdin.flush()
            while True:
                message = json.loads(process.stdout.readline())
                if message.get('id') == request_id:
                    self.assertNotIn('error', message, method)
                    return message['result']

        try:
            call(1, 'initialize', {'clientInfo': {'name': 'ai-config-smoke', 'version': '1'}})
            process.stdin.write(json.dumps({'jsonrpc': '2.0', 'method': 'initialized'}) + '\n')
            # Codex resolves ~/.agents/skills from the real Windows profile, so register the isolated root explicitly.
            skills_root = self.home / '.agents/skills'
            call(2, 'skills/extraRoots/set', {'extraRoots': [str(skills_root)]})
            skills = call(3, 'skills/list', {'cwds': [str(self.work)], 'forceReload': True})['data'][0]['skills']
            hooks = call(4, 'hooks/list', {'cwds': [str(self.work)]})['data'][0]['hooks']
            config = call(5, 'config/read', {})['config']
        finally:
            process.kill()
            for stream in (process.stdin, process.stdout):
                if stream:
                    stream.close()
            process.wait(timeout=30)

        isolated = {skill['name'] for skill in skills if Path(skill['path']).resolve().is_relative_to(skills_root.resolve())}
        self.assertEqual(sorted(frontmatter_names(package / 'skills', 'SKILL.md') - isolated), [], 'skills not discovered')
        events = {(hook['eventName'], hook['enabled']) for hook in hooks if hook.get('source') == 'user'}
        self.assertIn(('stop', True), events, 'managed Stop hook not registered')
        self.assertIn(('sessionStart', True), events, 'foreign SessionStart hook lost')
        self.assertEqual(config['mcp_servers']['smoke_demo']['command'], 'smoke-demo')
        self.assertTrue((codex_home / 'agents').is_dir() and frontmatter_names(codex_home / 'agents', '*.toml') == frontmatter_names(package / 'agents', '*.toml'))


if __name__ == '__main__':
    unittest.main()
