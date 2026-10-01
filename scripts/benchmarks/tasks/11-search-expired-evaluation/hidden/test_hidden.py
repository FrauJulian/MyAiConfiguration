import unittest
from datetime import date
from app.accounts import Account
from app.ledger.archive import render_period_summary


class Hidden(unittest.TestCase):
    def test_expired_evaluation_blocked(self):
        with self.assertRaises(PermissionError):
            render_period_summary(Account('evaluation', date(2026, 1, 1)), '2026-01', today=date(2026, 2, 1))

    def test_running_evaluation_and_paid_allowed(self):
        self.assertIsInstance(render_period_summary(Account('evaluation', date(2026, 3, 1)), '2026-01', today=date(2026, 2, 1)), bytes)
        self.assertIsInstance(render_period_summary(Account('paid'), '2026-01', today=date(2026, 2, 1)), bytes)
