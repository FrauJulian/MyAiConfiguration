import unittest
from app.pagination import paginate


class PaginationTests(unittest.TestCase):
    def test_first_page(self):
        self.assertEqual(paginate(list(range(10)), 1, 3), [0, 1, 2])
