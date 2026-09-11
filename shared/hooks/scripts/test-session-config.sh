#!/usr/bin/env bash
set -euo pipefail

root=${1:?Repository root is required}
for path in shared adapters scripts docs AGENTS.md; do
  [ -e "$root/$path" ] || { printf 'Missing repository input: %s\n' "$path" >&2; exit 1; }
done
printf 'PASS session configuration\n'
