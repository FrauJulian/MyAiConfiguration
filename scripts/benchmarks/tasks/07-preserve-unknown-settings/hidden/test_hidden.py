import json
import tempfile
import unittest
from pathlib import Path
from app.settings_store import save_settings


class Hidden(unittest.TestCase):
    def test_unknown_keys_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'settings.json'
            path.write_text(json.dumps({'theme': 'dark', 'plugins': {'a': True}, 'x': 1}))
            save_settings(path, {'language': 'de'})
            self.assertEqual(json.loads(path.read_text()), {'theme': 'dark', 'plugins': {'a': True}, 'x': 1, 'language': 'de'})

    def test_new_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'settings.json'
            save_settings(path, {'theme': 'light'})
            self.assertEqual(json.loads(path.read_text()), {'theme': 'light'})
