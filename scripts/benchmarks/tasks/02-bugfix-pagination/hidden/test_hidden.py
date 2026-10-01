import unittest
from app.pagination import paginate


class Hidden(unittest.TestCase):
    def test_last_page(self):
        self.assertEqual(paginate(list(range(10)), 4, 3), [9])
        self.assertEqual(paginate(list(range(9)), 3, 3), [6, 7, 8])

    def test_out_of_range(self):
        self.assertEqual(paginate(list(range(3)), 5, 3), [])
