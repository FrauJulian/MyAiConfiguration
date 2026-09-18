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
  if bash "$copy/scripts/commands/build.sh" >/dev/null 2>&1; then
    printf 'Expected build to fail for case "%s" but it succeeded.\n' "$label" >&2
    exit 1
  fi
  rm -rf -- "$copy"
}

baseline=$(new_repo_copy)
bash "$baseline/scripts/commands/build.sh" --summary >/dev/null

mutate_invalid_json() {
  printf '} this is not json {' >> "$1/adapters/claude/config/settings.json"
}
test_build_fails 'invalid Claude settings.json' mutate_invalid_json

mutate_duplicate_agent() {
  sed -i 's/^name:.*/name: implementer/' "$1/shared/agents/architect/agent.yml"
}
test_build_fails 'duplicate agent name' mutate_duplicate_agent

mutate_invalid_tool_name() {
  sed -i 's/^architect\t.*/architect\tShell/' "$1/adapters/claude/capabilities.tsv"
}
test_build_fails 'unknown Claude tool name in capability manifest' mutate_invalid_tool_name

mutate_duplicate_plugin() {
  local manifest="$1/adapters/plugins.tsv"
  sed -n '2p' "$manifest" >> "$manifest"
}
test_build_fails 'duplicate plugin name' mutate_duplicate_plugin

mutate_leftover_placeholder() {
  printf '\n__NOT_A_REAL_PLACEHOLDER__\n' >> "$1/shared/global-instructions.md"
}
test_build_fails 'leftover template placeholder' mutate_leftover_placeholder

mutate_mixed_placeholders() {
  sed -i 's/__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__/__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__ __UNKNOWN_PLACEHOLDER__/' "$1/adapters/claude/config/settings.json"
}
test_build_fails 'unknown placeholder beside an allowed installer placeholder' mutate_mixed_placeholders

if [ "$summary" = true ]; then printf 'Tests: PASS | build validation\n'; else printf 'PASS build validation: invalid JSON, duplicate agent, unknown Claude tool name, duplicate plugin, and leftover placeholders are all rejected\n'; fi
