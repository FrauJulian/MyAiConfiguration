import importlib.util
from array import array
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import re
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('retrieval_server', ROOT / 'shared/retrieval/server.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def tokenize(text, **kwargs):
    offsets = [match.span() for match in re.finditer(r'\S+', text)]
    return {'offset_mapping': offsets, 'input_ids': list(range(len(offsets)))}


def embedding():
    return array('f', [1.0] + [0.0] * (MODULE.EMBEDDING_DIMENSIONS - 1))


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
                tokenizer = index.encoder().tokenizer
                for source in ['alpha beta gamma ' * 450, 'Grüße 世界 🙂 ' * 300]:
                    windows = list(MODULE.chunks(source, 'sample.txt', tokenizer))
                    self.assertGreater(len(windows), 1)
                    self.assertTrue(all(len(tokenizer(value, add_special_tokens=False)['input_ids']) <= 400
                                        for _, value in windows))
                    self.assertTrue(all('\ufffd' not in value for _, value in windows))
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
                return [embedding() for _ in values]

            for index in indexes:
                index.encoder = lambda: SimpleNamespace(encode=encode, tokenizer=tokenize)
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
            index.encoder = lambda: SimpleNamespace(encode=lambda values, **kwargs: [embedding() for _ in values], tokenizer=tokenize)
            try:
                index.rebuild()
                (root / 'a.md').write_text('after', encoding='utf-8')
                (root / 'b.md').write_text('fail', encoding='utf-8')

                def encode(values, **kwargs):
                    if any(value.endswith('\n\nfail') for value in values):
                        raise RuntimeError('encoder failed')
                    return [embedding() for _ in values]

                index.encoder = lambda: SimpleNamespace(encode=encode, tokenizer=tokenize)
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
            def predict(self, pairs, **kwargs):
                self.pairs = pairs
                return [0.1, 0.8, 0.5]

        reranker = Reranker()
        index.reranker = lambda: reranker
        rows = [
            {'path': 'a.md', 'symbol': 'A', 'score': 0.9, 'text': 'first'},
            {'path': 'b.md', 'symbol': 'B', 'score': 0.8, 'text': 'second'},
            {'path': 'c.md', 'symbol': 'C', 'score': 0.7, 'text': 'third'},
        ]

        result = index.rerank('query', rows, 2)

        self.assertEqual([item['path'] for item in result], ['b.md', 'c.md'])
        self.assertEqual(reranker.pairs, [('query', 'Path: a.md\nSymbol: A\n\nfirst'),
                                        ('query', 'Path: b.md\nSymbol: B\n\nsecond'),
                                        ('query', 'Path: c.md\nSymbol: C\n\nthird')])

    def test_token_windows_have_exact_overlap_and_no_redundant_tail(self):
        for size, lengths in [(0, []), (400, [400]), (401, [400, 65]), (736, [400, 400]), (800, [400, 400, 128])]:
            words = [f'token{number}' for number in range(size)]
            result = list(MODULE.chunks(' '.join(words), 'plain.txt', tokenize))
            windows = [content.split() for _, content in result]
            self.assertEqual([len(window) for window in windows], lengths)
            for first, second in zip(windows, windows[1:]):
                self.assertEqual(first[-64:], second[:64])
            if windows:
                reconstructed = windows[0] + [word for window in windows[1:] for word in window[64:]]
                self.assertEqual(reconstructed, words)

    def test_python_symbols_include_decorators_and_restore_parent(self):
        source = 'class Service:\n    @cached\n    def load(self):\n        return 1\n\nvalue = 2\n\nasync def refresh():\n    return value\n'
        result = list(MODULE.sections(source, 'service.py'))
        self.assertEqual([symbol for symbol, _ in result], ['Service', 'Service.load', '<module>', 'refresh'])
        self.assertIn('@cached', result[1][1])
        self.assertEqual(''.join(content for _, content in result), source)
        broken = 'def incomplete(\n' + 'word ' * 450
        self.assertEqual(len(list(MODULE.chunks(broken, 'broken.py', tokenize))), 2)

    def test_markdown_sections_ignore_fenced_headings(self):
        source = '# Setup\nIntro\n## Install\n```sh\n# not a heading\n```\nSteps\n## Run\nStart\n'
        result = list(MODULE.chunks(source, 'guide.md', tokenize))
        self.assertEqual([symbol for symbol, _ in result], ['Setup', 'Setup / Install', 'Setup / Run'])
        self.assertIn('# not a heading', result[1][1])

    def test_common_declarations_and_config_sections(self):
        for path, source, symbols in [
            ('service.ts', 'export function load() {\n return 1;\n}\nexport const save = () => 2;\n', ['load', 'save']),
            ('service.cs', 'public class Service\n{\n public void Load()\n {\n }\n}\n', ['Service', 'Load']),
            ('setup.ps1', 'function Get-Result {\n return 1\n}\n', ['Get-Result']),
            ('config.toml', '[server]\nport = 1\n[client]\nport = 2\n', ['server', 'client']),
        ]:
            self.assertEqual([symbol for symbol, _ in MODULE.sections(source, path)], symbols)

    def test_old_cache_is_preserved_but_not_reused(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / 'data'
            data.mkdir()
            identity = os.path.normcase(str(root.resolve())) + '\n' + MODULE.MODEL
            old = data / (MODULE.hashlib.sha256(identity.encode()).hexdigest() + '.sqlite3')
            old.write_bytes(b'old cache')
            index = MODULE.Index(root, data)
            try:
                self.assertNotEqual(Path(index.db.execute('pragma database_list').fetchone()[2]), old)
                self.assertEqual(old.read_bytes(), b'old cache')
            finally:
                index.db.close()


if __name__ == '__main__':
    unittest.main()
