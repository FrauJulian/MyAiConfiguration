import sqlite3
import unittest
from app.users import find_user


class Hidden(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(':memory:')
        self.conn.execute('CREATE TABLE users (id INTEGER, name TEXT)')
        self.conn.executemany('INSERT INTO users VALUES (?, ?)', [(1, "O'Brien"), (2, 'admin')])

    def test_apostrophe(self):
        self.assertEqual(find_user(self.conn, "O'Brien"), (1, "O'Brien"))

    def test_injection(self):
        self.assertIsNone(find_user(self.conn, "x' OR '1'='1"))
