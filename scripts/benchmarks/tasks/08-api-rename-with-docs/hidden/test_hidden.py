import inspect
import unittest
from pathlib import Path
from app import api, cli


class Hidden(unittest.TestCase):
    def test_signature(self):
        self.assertEqual(list(inspect.signature(api.fetch).parameters), ['url', 'max_retries'])
        self.assertEqual(cli.main('u'), 2)

    def test_docs(self):
        text = Path('README.md').read_text()
        self.assertIn('max_retries', text)
        self.assertNotRegex(text, r'(?<![\w])retries(?=[=`])')
