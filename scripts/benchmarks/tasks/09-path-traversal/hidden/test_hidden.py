import os
import tempfile
import unittest
from pathlib import Path
from app.files import read_upload


class Hidden(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        (root / 'uploads/sub').mkdir(parents=True)
        (root / 'uploads/sub/a.txt').write_bytes(b'ok')
        (root / 'secret.txt').write_bytes(b'secret')
        self.base = str(root / 'uploads')

    def tearDown(self):
        self.directory.cleanup()

    def test_nested(self):
        self.assertEqual(read_upload(self.base, 'sub/a.txt'), b'ok')

    def test_traversal(self):
        for name in ('../secret.txt', 'sub/../../secret.txt', os.path.join(os.path.dirname(self.base), 'secret.txt')):
            with self.subTest(name), self.assertRaises((ValueError, PermissionError, FileNotFoundError)):
                read_upload(self.base, name)
