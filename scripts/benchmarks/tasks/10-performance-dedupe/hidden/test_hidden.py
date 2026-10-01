import time
import unittest
from app.dedupe import dedupe


class Hidden(unittest.TestCase):
    def test_behavior(self):
        self.assertEqual(dedupe([3, 1, 3, 2, 1]), [3, 1, 2])
        self.assertEqual(dedupe([]), [])
        self.assertEqual(dedupe(['a', 'b', 'a']), ['a', 'b'])

    def test_fast(self):
        items = list(range(100000)) * 2
        start = time.perf_counter()
        self.assertEqual(len(dedupe(items)), 100000)
        self.assertLess(time.perf_counter() - start, 1.0)
