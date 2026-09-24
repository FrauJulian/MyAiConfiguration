#!/usr/bin/env bash
set -euo pipefail
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
for shell_selection in 1 2; do
  for client_selection in 1 2 3; do
    output=$(printf '%s\n%s\n' "$shell_selection" "$client_selection" | bash "$root/scripts/commands/install.sh" --dry-run 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    printf '%s\n' "$output" | grep -E 'WARN|FAIL|WARNING|ERROR' || true
    [[ "$output" == *'PASS install dry-run'* ]]
    shell=powershell
    [ "$shell_selection" != 2 ] || shell=bash
    [[ "$output" == *"-$shell"* ]]
  done
done
if [ "$summary" = true ]; then printf 'Tests: PASS | install selections\n'; else printf 'PASS six shell and client selections\n'; fi
