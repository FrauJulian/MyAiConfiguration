import unittest
from pathlib import Path
from app.report import cost_report, sales_report

ROWS = [(' widgets ', 1234.5), ('gadgets', 99)]
EXPECTED = 'Widgets                 1,234.50\nGadgets                    99.00\nTotal                   1,333.50'


class Hidden(unittest.TestCase):
    def test_output(self):
        self.assertEqual(sales_report(ROWS), EXPECTED)
        self.assertEqual(cost_report(ROWS), EXPECTED)
        self.assertEqual(sales_report([]), f"{'Total':<20}{0:>12,.2f}")

    def test_deduplicated(self):
        self.assertEqual(Path('app/report.py').read_text().count('.title()'), 1)
