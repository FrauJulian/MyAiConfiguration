import argparse
import csv
import json
import math
import re
import tomllib
from pathlib import Path


METRICS = (
    'permanent_context_tokens',
    'skill_metadata_tokens',
    'rule_catalog_tokens',
    'agent_metadata_tokens',
)
CLIENTS = ('claude', 'codex')
TOKEN_BYTES = 4


def read_frontmatter(path):
    content = path.read_text(encoding='utf-8-sig')
    match = re.match(r'\A---\r?\n(.*?)^---\s*$', content, re.MULTILINE | re.DOTALL)
    return match.group(1).encode('utf-8') if match else b''


def tokens(byte_count):
    return math.ceil(byte_count / TOKEN_BYTES)


def measure_package(package, client):
    instruction_name = 'CLAUDE.md' if client == 'claude' else 'AGENTS.md'
    instruction_bytes = (package / instruction_name).stat().st_size

    skill_root = package / 'skills'
    skill_metadata_bytes = sum(
        len(read_frontmatter(path))
        for path in skill_root.rglob('SKILL.md')
        if path.relative_to(skill_root).parts[0] != 'rules'
    )

    if client == 'claude':
        rule_files = (package / 'skills' / 'rules').glob('rules-*/SKILL.md')
    else:
        rule_root = package / 'rules'
        rule_files = (
            path for path in rule_root.rglob('*.md')
            if 'references' not in path.relative_to(rule_root).parts
        )
    rule_catalog_bytes = sum(path.stat().st_size for path in rule_files)

    agent_root = package / 'agents'
    if client == 'claude':
        agent_metadata_bytes = sum(len(read_frontmatter(path)) for path in agent_root.glob('*.md'))
    else:
        agent_metadata_bytes = 0
        for path in agent_root.glob('*.toml'):
            agent = tomllib.loads(path.read_text(encoding='utf-8-sig'))
            agent_metadata_bytes += sum(len(agent.get(key, '').encode('utf-8')) for key in ('name', 'description'))

    return {
        'permanent_context_tokens': tokens(instruction_bytes),
        'skill_metadata_tokens': tokens(skill_metadata_bytes),
        'rule_catalog_tokens': tokens(rule_catalog_bytes),
        'agent_metadata_tokens': tokens(agent_metadata_bytes),
    }


def measure(root):
    result = {}
    for client in CLIENTS:
        packages = [root / 'generated' / f'{client}-{shell}' for shell in ('bash', 'powershell')]
        for package in packages:
            if not package.is_dir():
                raise FileNotFoundError(f'Generated package missing: {package}')
        measurements = [measure_package(package, client) for package in packages]
        result[client] = {
            metric: max(item[metric] for item in measurements)
            for metric in METRICS
        }
    return result


def load_baseline(root):
    path = root / 'adapters' / 'prompt-budget-baseline.json'
    baseline = json.loads(path.read_text(encoding='utf-8'))
    if baseline.get('regression_percent') != 10:
        raise ValueError('Prompt budget regression threshold must be 10%.')
    metric_values = baseline.get('metrics', {})
    expected = {(metric, client): metric_values.get(metric, {}).get(client) for metric in METRICS for client in CLIENTS}
    if any(not isinstance(value, int) or value <= 0 for value in expected.values()):
        raise ValueError('Prompt budget baseline is missing a positive integer metric.')
    for key in ('permanent_context_soft_target_tokens', 'permanent_context_hard_limit_tokens'):
        if not isinstance(baseline.get(key), int) or baseline[key] <= 0:
            raise ValueError(f'Prompt budget baseline is missing a positive {key}.')

    tsv_path = root / 'adapters' / 'prompt-budget-baseline.tsv'
    with tsv_path.open(encoding='utf-8', newline='') as stream:
        rows = list(csv.DictReader(stream, delimiter='\t'))
    actual = {(row['metric'], row['client']): int(row['baseline_tokens']) for row in rows}
    if actual != expected:
        raise ValueError('Prompt budget JSON and TSV baselines do not match.')
    return baseline


def evaluate(current, baseline):
    failures = []
    warnings = []
    limit_percent = 100 + baseline['regression_percent']
    for metric in METRICS:
        for client in CLIENTS:
            value = current[client][metric]
            previous = baseline['metrics'][metric][client]
            if value * 100 > previous * limit_percent:
                failures.append(f'{metric} {client}: {value} tokens (baseline {previous}, limit +{baseline["regression_percent"]}%).')

    hard_limit = baseline['permanent_context_hard_limit_tokens']
    soft_target = baseline['permanent_context_soft_target_tokens']
    for client in CLIENTS:
        value = current[client]['permanent_context_tokens']
        if value > soft_target:
            warnings.append(f'permanent_context_tokens {client}: {value} tokens exceeds the {soft_target}-token soft target.')
        if value > hard_limit:
            failures.append(f'permanent_context_tokens {client}: {value} tokens exceeds the {hard_limit}-token hard limit.')
    return failures, warnings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    baseline = load_baseline(root)
    current = measure(root)
    failures, warnings = evaluate(current, baseline)

    print('Prompt Budget')
    if args.summary:
        for metric in METRICS:
            for client in CLIENTS:
                value = current[client][metric]
                previous = baseline['metrics'][metric][client]
                print(f'{metric} {client}: {value} tokens (baseline {previous}, fail above +{baseline["regression_percent"]}%)')
    else:
        for metric in METRICS:
            print(f'{metric}: Claude {current["claude"][metric]}, Codex {current["codex"][metric]} tokens')
    for warning in warnings:
        print(f'WARN {warning}')
    for failure in failures:
        print(f'FAIL {failure}')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
