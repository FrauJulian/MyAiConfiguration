import unittest
from app.fin.tally import consolidate


class Hidden(unittest.TestCase):
    def test_half_up(self):
        self.assertEqual(float(consolidate([1.005])), 1.01)
        self.assertEqual(float(consolidate([2.675])), 2.68)
        self.assertEqual(float(consolidate([1.0, 0.004])), 1.0)
        self.assertEqual(float(consolidate([0.1, 0.2])), 0.3)
