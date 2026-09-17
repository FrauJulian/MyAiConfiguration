import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent


class TelemetryTests(unittest.TestCase):
    def test_bash_record_disable_and_summary(self):
        bash = shutil.which('bash')
        if not bash:
            self.skipTest('Bash unavailable')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'scripts/telemetry.sh'
            script.parent.mkdir()
            shutil.copy(ROOT / 'scripts/telemetry.sh', script)
            env = dict(os.environ, AI_CONFIG_TELEMETRY='1')
            result = subprocess.run([bash, str(script), 'record', 'subagent-stop', '--role', 'reviewer', '--filesRead', '3', '--outcome', 'findings'], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            event = json.loads((root / '.ai-session/telemetry.jsonl').read_text().strip())
            self.assertEqual(event['role'], 'reviewer')
            self.assertEqual(event['filesRead'], 3)
            self.assertNotIn('prompt', event)
            disabled = dict(env, AI_CONFIG_TELEMETRY='0')
            subprocess.run([bash, str(script), 'record', 'ignored'], env=disabled, check=True)
            summary = subprocess.run([bash, str(script), 'summary'], env=env, capture_output=True, text=True, check=True)
            self.assertIn('reviewer: runs 1 findings 1', summary.stdout)


if __name__ == '__main__':
    unittest.main()
