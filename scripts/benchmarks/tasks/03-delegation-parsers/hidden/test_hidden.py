import unittest
from app.parsers.csv_parser import parse_csv
from app.parsers.ini_parser import parse_ini
from app.parsers.json_parser import parse_json_lines


class Hidden(unittest.TestCase):
    def test_csv(self):
        self.assertEqual(parse_csv('a, b\n1, "x,y"\n\n2,3\n'), [{'a': '1', 'b': 'x,y'}, {'a': '2', 'b': '3'}])

    def test_json(self):
        self.assertEqual(parse_json_lines('{"a": 1}\n\n[2]\n'), [{'a': 1}, [2]])
        with self.assertRaisesRegex(ValueError, '2'):
            parse_json_lines('{}\n{bad\n')

    def test_ini(self):
        self.assertEqual(parse_ini('top = 1\n; c\n[s]\n# c\n k = v \n'), {'': {'top': '1'}, 's': {'k': 'v'}})
