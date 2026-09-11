#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
home_path=${HOME:?HOME is required}
failed=false

result() {
  printf '%s %s\n' "$1" "$2"
  [ "$1" != FAIL ] || failed=true
}

for tool in codex claude; do
  if command -v "$tool" >/dev/null; then result PASS "$tool available ($($tool --version 2>&1 | head -n 1))"; else result WARN "$tool unavailable"; fi
done
command -v jq >/dev/null && result PASS 'jq available for Claude status line' || result WARN 'jq unavailable; Claude status line is disabled'
for platform in windows linux; do
[ -f "$root/generated/codex-$platform/AGENTS.md" ] && result PASS 'generated output present' || result FAIL 'generated output missing; run build'
[ -f "$root/generated/codex-$platform/hooks/scripts/Validate-CommandSafety.ps1" ] && [ -f "$root/generated/codex-$platform/hooks/scripts/validate-command-safety.sh" ] && [ -f "$root/generated/claude-$platform/hooks/scripts/Validate-CommandSafety.ps1" ] && [ -f "$root/generated/claude-$platform/hooks/scripts/validate-command-safety.sh" ] && result PASS 'generated hooks present' || result FAIL 'generated hooks missing; run build'
done
for path in .codex/AGENTS.md .codex/config.toml .claude/CLAUDE.md .claude/settings.json; do
  [ -f "$home_path/$path" ] && result PASS "installed $path" || result WARN "not installed $path"
done
for path in shared/rules shared/skills shared/agents shared/hooks/scripts; do
  [ -e "$root/$path" ] && result PASS "source $path" || result FAIL "missing $path"
done
"$failed" && exit 1
printf 'PASS doctor\n'
