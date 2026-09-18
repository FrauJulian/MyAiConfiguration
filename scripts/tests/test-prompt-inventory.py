import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


SPEC = importlib.util.spec_from_file_location('prompt_inventory', Path(__file__).parent / 'lib/prompt-inventory.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PromptInventoryTests(unittest.TestCase):
    def test_counts_metadata_separately_and_reports_duplicate_names(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            metadata = 'name: "example"\ndescription: Example skill.\n'
            for name in ('first', 'second'):
                directory = root / name
                directory.mkdir()
                (directory / 'SKILL.md').write_text(f'---\n{metadata}---\n\nBody\n---\nMore body', encoding='utf-8-sig')
            count, header_bytes, body_bytes, duplicates = MODULE.inventory([root, root / 'missing'])
            self.assertEqual(count, 2)
            self.assertEqual(header_bytes, 2 * len(metadata.encode()))
            self.assertGreater(body_bytes, header_bytes)
            self.assertEqual(duplicates, ['example'])


if __name__ == '__main__':
    unittest.main()
