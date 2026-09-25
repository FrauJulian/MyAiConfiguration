import argparse
from collections import Counter
from pathlib import Path
import re


def inventory(roots):
    names = Counter()
    count = metadata_bytes = body_bytes = 0
    for root in roots:
        for path in sorted(root.rglob('SKILL.md')):
            content = path.read_text(encoding='utf-8-sig')
            count += 1
            body_bytes += len(content.encode('utf-8'))
            header = re.match(r'\A---\r?\n(.*?)^---\s*$', content, re.MULTILINE | re.DOTALL)
            if header:
                metadata_bytes += len(header.group(1).encode('utf-8'))
                name = re.search(r'^name:\s*(.+)$', header.group(1), re.MULTILINE)
                if name:
                    names[name.group(1).strip().strip('\"\'')] += 1
    return count, metadata_bytes, body_bytes, sorted(name for name, total in names.items() if total > 1)


def report(label, roots, warn_duplicates=True):
    count, metadata, bodies, duplicates = inventory(roots)
    print(f'{label}: {count} skill files, {metadata} frontmatter bytes (~{(metadata + 3) // 4} tokens), {bodies} lazy file bytes')
    if duplicates and warn_duplicates:
        print(f'WARN {label}: repeated skill names ({len(duplicates)}): {", ".join(duplicates)}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--home', type=Path, default=Path.home())
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    for client in ('codex', 'claude'):
        report(f'Generated {client} catalog', [root / 'generated' / f'{client}-bash' / 'skills'])
        directories = [args.home / f'.{client}' / 'skills']
        if client == 'codex':
            directories.append(args.home / '.agents' / 'skills')
        report(f'Installed {client} user catalog', directories)
        report(f'Cached {client} plugins (all versions)', [args.home / f'.{client}' / 'plugins' / 'cache'], warn_duplicates=False)
    print('Coverage: prompt KPIs cover generated permanent instructions, skill metadata, the full rule catalog, and agent metadata. Rule catalog size does not represent rules loaded in a typical session. Counts are bytes/4 estimates, not runtime token telemetry. Installed prompts, tool schemas, dynamic hook output, and inactive plugin versions are excluded.')


if __name__ == '__main__':
    main()
