import unittest
from pathlib import Path
from app import client, config


class Hidden(unittest.TestCase):
    def test_default(self):
        self.assertEqual(config.DEFAULT_TIMEOUT, 60)
        self.assertEqual(client.request('x'), 60)
        self.assertEqual(client.request('x', 5), 5)

    def test_docs(self):
        for path in ('README.md', 'app/client.py'):
            text = Path(path).read_text()
            self.assertIn('60 seconds', text)
            self.assertNotIn('30 seconds', text)
