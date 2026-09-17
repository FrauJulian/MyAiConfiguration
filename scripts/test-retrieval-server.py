import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('retrieval_server', ROOT / 'shared/retrieval/server.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RetrievalServerTests(unittest.TestCase):
    def test_rerank_uses_cross_encoder_scores(self):
        index = MODULE.Index.__new__(MODULE.Index)

        class Reranker:
            def predict(self, pairs):
                self.pairs = pairs
                return [0.1, 0.8, 0.5]

        reranker = Reranker()
        index.reranker = lambda: reranker
        rows = [
            {'path': 'a.md', 'score': 0.9, 'text': 'first'},
            {'path': 'b.md', 'score': 0.8, 'text': 'second'},
            {'path': 'c.md', 'score': 0.7, 'text': 'third'},
        ]

        result = index.rerank('query', rows, 2)

        self.assertEqual([item['path'] for item in result], ['b.md', 'c.md'])
        self.assertEqual(reranker.pairs, [('query', 'first'), ('query', 'second'), ('query', 'third')])


if __name__ == '__main__':
    unittest.main()
