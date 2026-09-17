#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in ''|--summary) ;; *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;; esac
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$root/scripts/test-quick-update.py"
printf 'Tests: PASS | quick update selection\n'
