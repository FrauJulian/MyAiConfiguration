#!/usr/bin/env bash
set -euo pipefail
summary=false
for arg in "$@"; do case "$arg" in --summary) summary=true;; *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1;; esac; done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
budget_args=()
[ "$summary" = false ] || budget_args+=(--summary)
budget_status=0
python3 "$root/scripts/lib/prompt-budget.py" "${budget_args[@]}" || budget_status=$?
python3 "$root/scripts/lib/prompt-inventory.py" --home "${HOME:?HOME is required}"
exit "$budget_status"
