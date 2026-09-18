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
. "$root/scripts/lib/manifest.sh"
home_path=${HOME:?HOME is required}
failed=false
check_count=0
pass_buffer=()

result() {
  check_count=$((check_count + 1))
  [ "$1" != FAIL ] || failed=true
  if [ "$summary" = true ] && [ "$1" = PASS ]; then
    pass_buffer+=("$1 $2")
  else
    printf '%s %s\n' "$1" "$2"
  fi
}

for tool in codex claude; do
  if command -v "$tool" >/dev/null; then result PASS "$tool available ($($tool --version 2>&1 | head -n 1))"; else result WARN "$tool unavailable"; fi
done
command -v jq >/dev/null && result PASS 'jq available for Claude Bash status line' || result WARN 'jq unavailable; Claude Bash status line is disabled'

source_agent_count=$(find "$root/shared/agents" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
source_skill_count=$(find "$root/shared/skills" -name SKILL.md 2>/dev/null | wc -l)
rule_skill_manifest="$root/adapters/rule-skills.tsv"
rule_skill_count=0
[ -f "$rule_skill_manifest" ] && rule_skill_count=$(($(wc -l < "$rule_skill_manifest") - 1))

for shell in powershell bash; do
  [ -f "$root/generated/codex-$shell/AGENTS.md" ] && result PASS "generated output present ($shell)" || result FAIL "generated output missing ($shell); run build"
  [ -f "$root/generated/codex-$shell/hooks/scripts/Validate-CommandSafety.ps1" ] && [ -f "$root/generated/codex-$shell/hooks/scripts/validate-command-safety.sh" ] && [ -f "$root/generated/claude-$shell/hooks/scripts/Validate-CommandSafety.ps1" ] && [ -f "$root/generated/claude-$shell/hooks/scripts/validate-command-safety.sh" ] && result PASS "generated hooks present ($shell)" || result FAIL "generated hooks missing ($shell); run build"
  for client in codex claude; do
    package="$root/generated/$client-$shell"
    [ -d "$package" ] || continue
    agent_count=$(find "$package/agents" -type f 2>/dev/null | wc -l)
    if [ "$agent_count" -eq "$source_agent_count" ]; then result PASS "$client-$shell agent count matches source ($agent_count)"; else result FAIL "$client-$shell agent count $agent_count does not match source ($source_agent_count)"; fi
    expected_skill_count=$source_skill_count
    [ "$client" != claude ] || expected_skill_count=$((source_skill_count + rule_skill_count))
    skill_count=$(find "$package/skills" -name SKILL.md 2>/dev/null | wc -l)
    if [ "$skill_count" -eq "$expected_skill_count" ]; then result PASS "$client-$shell skill count matches source ($skill_count)"; else result FAIL "$client-$shell skill count $skill_count does not match source ($expected_skill_count)"; fi
    leftover_tokens=$(grep -RohE '__[A-Z0-9_]+__' "$package" 2>/dev/null | sort -u | grep -Ev '^(__AI_CONFIG_ROOT__|__POWERSHELL_COMMAND__|__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__)$' || true)
    if [ -n "$leftover_tokens" ]; then result FAIL "$client-$shell has unresolved placeholders"; else result PASS "$client-$shell has no unresolved placeholders"; fi
  done
done

for path in .codex/AGENTS.md .codex/config.toml .claude/CLAUDE.md .claude/settings.json; do
  [ -f "$home_path/$path" ] && result PASS "installed $path" || result WARN "not installed $path"
done

if [ -f "$home_path/.claude/settings.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$home_path/.claude/settings.json" >/dev/null 2>&1; then result PASS 'installed .claude/settings.json is valid JSON'; else result FAIL 'installed .claude/settings.json is not valid JSON'; fi
  elif command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$home_path/.claude/settings.json" 2>/dev/null; then
      result PASS 'installed .claude/settings.json is valid JSON'
    else
      result FAIL 'installed .claude/settings.json is not valid JSON'
    fi
  fi
fi
if [ -f "$home_path/.codex/config.toml" ]; then
  if python3 -c 'import sys,tomllib,pathlib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))' "$home_path/.codex/config.toml"; then
    result PASS 'installed .codex/config.toml parses as TOML'
  else
    result FAIL 'installed .codex/config.toml is invalid TOML'
  fi
  if command -v codex >/dev/null; then
    if CODEX_HOME="$home_path/.codex" codex --strict-config --help >/dev/null 2>&1; then result PASS 'installed .codex/config.toml matches the installed Codex schema'; else result FAIL 'installed .codex/config.toml has unsupported Codex settings'; fi
  else result WARN 'Codex CLI unavailable; skipped installed Codex schema validation'; fi
fi

for destination in "$home_path/.codex" "$home_path/.agents/skills" "$home_path/.claude"; do
  manifest=$(manifest_path "$destination")
  [ -f "$manifest" ] || continue
  declare -A managed
  read_managed_manifest "$manifest" managed
  missing=()
  modified=()
  for relative in "${!managed[@]}"; do
    target="$destination/$relative"
    if [ ! -f "$target" ]; then missing+=("$relative"); continue; fi
    [ "$(sha256_of_file "$target")" = "${managed[$relative]}" ] || modified+=("$relative")
  done
  if [ "${#missing[@]}" -eq 0 ]; then result PASS "$destination has no missing managed files"; else result WARN "$destination is missing managed files: ${missing[*]}"; fi
  if [ "${#modified[@]}" -eq 0 ]; then result PASS "$destination has no locally modified managed files"; else result WARN "$destination has locally modified managed files: ${modified[*]}"; fi
done

for path in shared/rules shared/skills shared/agents shared/hooks/scripts; do
  [ -e "$root/$path" ] && result PASS "source $path" || result FAIL "missing $path"
done

if [ "$summary" = true ]; then
  if [ "$failed" = true ]; then
    for line in "${pass_buffer[@]}"; do printf '%s\n' "$line"; done
    printf 'Doctor: FAIL | %s checks\n' "$check_count"
    exit 1
  fi
  printf 'Doctor: PASS | %s checks\n' "$check_count"
else
  [ "$failed" = false ] || exit 1
  printf 'PASS doctor\n'
fi
