#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT

new_repo_copy() {
  local copy
  copy=$(mktemp -d "$work/case-XXXXXX")
  (cd "$root" && tar -cf - --exclude='.git' --exclude='generated' .) | (cd "$copy" && tar -xf -)
  printf '%s' "$copy"
}

test_build_fails() {
  local label=$1 mutate_fn=$2 copy
  copy=$(new_repo_copy)
  "$mutate_fn" "$copy"
  if bash "$copy/scripts/build.sh" >/dev/null 2>&1; then
    printf 'Expected build to fail for case "%s" but it succeeded.\n' "$label" >&2
    exit 1
  fi
  rm -rf -- "$copy"
}

mutate_invalid_json() {
  printf '} this is not json {' >> "$1/adapters/claude/config/settings.json"
}
test_build_fails 'invalid Claude settings.json' mutate_invalid_json

mutate_duplicate_agent() {
  sed -i 's/^name:.*/name: implementer/' "$1/shared/agents/architect/agent.yml"
}
test_build_fails 'duplicate agent name' mutate_duplicate_agent

mutate_duplicate_plugin() {
  local manifest="$1/adapters/plugins.tsv"
  sed -n '2p' "$manifest" >> "$manifest"
}
test_build_fails 'duplicate plugin name' mutate_duplicate_plugin

mutate_leftover_placeholder() {
  printf '\n__NOT_A_REAL_PLACEHOLDER__\n' >> "$1/shared/global-instructions.md"
}
test_build_fails 'leftover template placeholder' mutate_leftover_placeholder

printf 'PASS build validation: invalid JSON, duplicate agent, duplicate plugin, and leftover placeholders are all rejected\n'
