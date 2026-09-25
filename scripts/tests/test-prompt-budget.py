import runpy
import unittest
from pathlib import Path


MODULE = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'lib' / 'prompt-budget.py'))


class PromptBudgetTests(unittest.TestCase):
    def setUp(self):
        self.baseline = {
            'regression_percent': 10,
            'permanent_context_soft_target_tokens': 4000,
            'permanent_context_hard_limit_tokens': 6000,
            'metrics': {
                metric: {'claude': 100, 'codex': 100}
                for metric in MODULE['METRICS']
            },
        }
        self.current = {
            client: {metric: 110 for metric in MODULE['METRICS']}
            for client in MODULE['CLIENTS']
        }

    def test_ten_percent_growth_passes(self):
        failures, warnings = MODULE['evaluate'](self.current, self.baseline)
        self.assertEqual(failures, [])
        self.assertEqual(warnings, [])

    def test_growth_above_ten_percent_fails(self):
        self.current['claude']['permanent_context_tokens'] = 111
        failures, _ = MODULE['evaluate'](self.current, self.baseline)
        self.assertEqual(len(failures), 1)
        self.assertIn('permanent_context_tokens claude', failures[0])

    def test_permanent_context_hard_limit_fails(self):
        self.current['codex']['permanent_context_tokens'] = 6001
        failures, _ = MODULE['evaluate'](self.current, self.baseline)
        self.assertTrue(any('permanent_context_tokens codex' in failure for failure in failures))

    def test_soft_target_warns_in_tokens(self):
        self.baseline['metrics']['permanent_context_tokens']['claude'] = 4000
        self.current['claude']['permanent_context_tokens'] = 4001
        failures, warnings = MODULE['evaluate'](self.current, self.baseline)
        self.assertEqual(failures, [])
        self.assertTrue(any('permanent_context_tokens claude' in warning for warning in warnings))


if __name__ == '__main__':
    unittest.main()
