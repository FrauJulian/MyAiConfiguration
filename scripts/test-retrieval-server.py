import importlib.util
from array import array
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('retrieval_server', ROOT / 'shared/retrieval/server.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RetrievalServerTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('QWEN_TEST_MODEL_CACHE'), 'Set QWEN_TEST_MODEL_CACHE to run the real-model check.')
    def test_real_models(self):
        os.environ['HF_HOME'] = os.environ['QWEN_TEST_MODEL_CACHE']
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'authentication.md').write_text('Password reset tokens are created by create_reset_token. The reset_password endpoint sends the user a password reset email.', encoding='utf-8')
            (root / 'weather.md').write_text('The weather service fetches temperature and rainfall forecasts for a city.', encoding='utf-8')
            index = MODULE.Index(root, root / 'data')
            try:
                for query, expected in [('Where are password reset tokens created?', 'authentication.md'),
                                        ('Which service provides rainfall forecasts?', 'weather.md')]:
                    started = time.monotonic()
                    results = index.search(query, 2)
                    self.assertEqual(results[0]['path'], expected)
                    self.assertEqual(len(results), 2)
                    self.assertGreater(results[0]['score'], results[1]['score'])
                    print(f'Qwen real search: {expected}, {time.monotonic() - started:.2f}s, embedding device {index.encoder().device}, reranker device {index.reranker().device}', flush=True)
            finally:
                index.db.close()

    def test_isolation_freshness_and_incremental_encoding(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            first, second = root / 'first', root / 'second'
            first.mkdir()
            second.mkdir()
            file = first / 'a.md'
            file.write_text('alpha', encoding='utf-8')
            (second / 'a.md').write_text('other', encoding='utf-8')
            indexes = [MODULE.Index(repository, root / 'data') for repository in (first, second)]
            encoded = []

            def encode(values, **kwargs):
                self.assertEqual(kwargs.get('prompt_name'), 'query' if values == ['query'] else None)
                encoded.extend(values)
                return [array('f', [1.0]) for _ in values]

            for index in indexes:
                index.encoder = lambda: SimpleNamespace(encode=encode)
                index.rerank = lambda query, rows, limit: rows[:limit]
            numpy = SimpleNamespace(dot=lambda a, b: sum(x * y for x, y in zip(a, b)),
                                    frombuffer=lambda blob, **kwargs: array('f', blob), float32=None)
            try:
                with patch.dict('sys.modules', numpy=numpy):
                    self.assertEqual(indexes[0].search('query', 5)[0]['text'], 'alpha')
                    self.assertEqual(indexes[1].search('query', 5)[0]['text'], 'other')
                    encoded.clear()
                    with ThreadPoolExecutor(max_workers=1) as executor:
                        self.assertEqual(executor.submit(indexes[0].search, 'query', 5).result()[0]['text'], 'alpha')
                    self.assertEqual(encoded, ['query'])
                    timestamp = file.stat()
                    file.write_text('bravo', encoding='utf-8')
                    os.utime(file, ns=(timestamp.st_atime_ns, timestamp.st_mtime_ns))
                    self.assertEqual(indexes[0].search('query', 5)[0]['text'], 'bravo')
                    file.rename(first / 'renamed.md')
                    self.assertEqual(indexes[0].search('query', 5)[0]['path'], 'renamed.md')
                    (first / 'renamed.md').unlink()
                    encoded.clear()
                    self.assertEqual(indexes[0].search('query', 5), [])
                    self.assertEqual(indexes[0].search('query', 5), [])
                    self.assertEqual(encoded, [])
                    self.assertEqual(indexes[1].search('query', 5)[0]['text'], 'other')
            finally:
                for index in indexes:
                    index.db.close()

    def test_failed_refresh_preserves_previous_index(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'a.md').write_text('before', encoding='utf-8')
            index = MODULE.Index(root, root / 'data')
            index.encoder = lambda: SimpleNamespace(encode=lambda values, **kwargs: [array('f', [1.0]) for _ in values])
            try:
                index.rebuild()
                (root / 'a.md').write_text('after', encoding='utf-8')
                (root / 'b.md').write_text('fail', encoding='utf-8')

                def encode(values, **kwargs):
                    if values == ['fail']:
                        raise RuntimeError('encoder failed')
                    return [array('f', [1.0]) for _ in values]

                index.encoder = lambda: SimpleNamespace(encode=encode)
                with self.assertRaisesRegex(RuntimeError, 'encoder failed'):
                    index.rebuild()
                self.assertEqual(index.db.execute('select path, text from chunks').fetchall(), [('a.md', 'before')])
            finally:
                index.db.close()

    def test_scan_prunes_ignored_directories_and_stops_at_limit(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            index = MODULE.Index(root, root / 'data')
            (root / 'visible.md').write_text('visible', encoding='utf-8')
            for name in ('node_modules', '.git', 'generated', 'data'):
                directory = root / name
                directory.mkdir(exist_ok=True)
                (directory / 'hidden.md').write_text('hidden', encoding='utf-8')
            try:
                self.assertEqual(index.files(), [(root / 'visible.md').resolve()])
                filenames = ['visible.md'] * 2001
                with patch.object(MODULE.os, 'walk', return_value=iter([(str(root), [], filenames)])):
                    self.assertEqual(len(index.files()), 2000)
            finally:
                index.db.close()

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
