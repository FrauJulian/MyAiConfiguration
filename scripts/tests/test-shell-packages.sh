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
source_agent_count=$(find "$root/shared/agents" -mindepth 1 -maxdepth 1 -type d | wc -l)
source_skill_count=$(find "$root/shared/skills" -name SKILL.md | wc -l)
mapfile -t rule_paths < <(find "$root/shared/rules" -mindepth 1 -type f -name '*.md' ! -name general.md -printf '%P\n' | sort)
rule_skill_count=${#rule_paths[@]}
global_instructions=$(<"$root/shared/global-instructions.md")
rule_skill_name() {
  local path=$1 directory relative
  if [[ "$path" != */* ]]; then printf 'rules-%s' "${path%.md}"; return; fi
  directory=${path%%/*}
  relative=${path#*/}
  if [[ "$relative" == index.md ]]; then printf 'rules-%s' "$directory"; return; fi
  relative=${relative#references/}
  relative=${relative%.md}
  relative=${relative//\//-}
  printf 'rules-%s-%s' "$directory" "$relative"
}
for rule_path in "${rule_paths[@]}"; do
  if [[ "$rule_path" != */* || "$rule_path" == */index.md ]]; then
    skill_name=$(rule_skill_name "$rule_path")
    expected_rule="\`rules/$rule_path\` / \`$skill_name\`"
    printf '%s' "$global_instructions" | grep -Fq -- "$expected_rule"
  fi
done
for shell in powershell bash; do
  for client in codex claude; do
    package="$root/generated/$client-$shell"
    file=config.toml
    [ "$client" != claude ] || file=settings.json
    test -f "$package/$file"
    test "$(find "$package/agents" -type f | wc -l)" -eq "$source_agent_count"
    expected_reviewer_shell_tool=Bash
    [ "$shell" != powershell ] || expected_reviewer_shell_tool=PowerShell
    if [ "$client" = claude ]; then grep -q "^tools: Read,Grep,Glob,$expected_reviewer_shell_tool\$" "$package/agents/reviewer.md"; fi
    expected_skill_count=$source_skill_count
    [ "$client" != claude ] || expected_skill_count=$((source_skill_count + rule_skill_count))
    test "$(find "$package/skills" -name SKILL.md | wc -l)" -eq "$expected_skill_count"
    if [ "$shell" = powershell ]; then
      grep -q '__POWERSHELL_COMMAND__ .*flashbang.ps1' "$package/$file"
      ! grep -Eq 'WindowStyle[[:space:]]+Hidden' "$package/$file"
    else
      grep -q 'bash .*flashbang.sh' "$package/$file"
    fi
    if [ "$client" = codex ]; then
      [ "$(sed -n 's/^\[\[hooks\.\([^].]*\)\]\]$/\1/p' "$package/$file")" = Stop ]
      ! grep -q 'flashbang-if-input' "$package/$file"
      ! grep -Eq '^async[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$package/$file"
      grep -q 'approvals_reviewer[[:space:]]*=[[:space:]]*"auto_review"' "$package/$file"
      grep -Eq '^max_depth[[:space:]]*=[[:space:]]*1[[:space:]]*$' "$package/$file"
      grep -Fq 'status_line = ["model", "reasoning", "approval-mode", "project-name", "git-branch", "context-window-size", "context-used", "used-tokens"]' "$package/$file"
    else
      python3 -c 'import json,sys; settings=json.load(open(sys.argv[1], encoding="utf-8-sig")); assert set(settings["hooks"]) == {"PreCompact", "SessionStart", "Stop"}' "$package/$file"
      ! grep -q 'flashbang-if-input' "$package/$file"
      ! grep -q '"async"[[:space:]]*:[[:space:]]*true' "$package/$file"
      grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"auto"' "$package/$file"
      python3 -c 'import json,sys; settings=json.load(open(sys.argv[1], encoding="utf-8-sig")); expected={"enabled": False} if sys.argv[2] == "powershell" else {"enabled": True, "allowUnsandboxedCommands": False, "failIfUnavailable": True}; assert settings["sandbox"] == expected' "$package/$file" "$shell"
      statusline_extension='sh'
      [ "$shell" != powershell ] || statusline_extension=ps1
      test -f "$package/statusline/statusline.$statusline_extension"
      grep -q "statusline.$statusline_extension" "$package/$file"
    fi
    if grep -Eq '__HOOK_|__POWERSHELL_HOOK_' "$package/$file"; then exit 1; fi
    doc_file=AGENTS.md
    [ "$client" != claude ] || doc_file=CLAUDE.md
    doc_content=$(cat "$package/$doc_file")
    printf '%s' "$doc_content" | grep -Fq 'rules/security/index.md'
    if [ "$client" = claude ]; then
      for rule_path in "${rule_paths[@]}"; do
        skill_name=$(rule_skill_name "$rule_path")
        test -f "$package/skills/rules/$skill_name/SKILL.md"
      done
    fi
    printf '%s' "$doc_content" | grep -Fq 'Use the `mcporter` CLI for MCP servers this configuration registers there'
    printf '%s' "$doc_content" | grep -Fq "Use a selected native plugin's MCP tools directly even when MCPorter is active"
    printf '%s' "$doc_content" | grep -Fq 'Keep MCPorter where it provides a concrete shared benefit'
    occurrences=$(printf '%s' "$doc_content" | grep -o 'Apply instructions in this order' | wc -l)
    [ "$occurrences" -eq 1 ] || { printf '%s-%s must embed the priority rule exactly once\n' "$client" "$shell" >&2; exit 1; }
    if [ "$client" = codex ] && printf '%s' "$doc_content" | grep -q 'Always load and apply `rules/general\.md`'; then
      printf '%s must not still instruct loading general.md by path\n' "$package" >&2
      exit 1
    fi
    if [ "$client" = claude ] && [ -f "$package/rules/general.md" ]; then
      printf 'Claude must not automatically load a second copy of general rules.\n' >&2
      exit 1
    fi
    for split_rule in angular wpf ui-ux; do
      if [ "$client" = codex ]; then
        references_dir="$package/rules/$split_rule/references"
      else
        references_dir="$package/skills/rules/rules-$split_rule/references"
      fi
      if [ ! -d "$references_dir" ] || [ -z "$(find "$references_dir" -maxdepth 1 -name '*.md' -print -quit)" ]; then
        printf '%s is missing reference files for %s\n' "$package" "$split_rule" >&2
        exit 1
      fi
    done
  done
done
if [ "$summary" = true ]; then printf 'Tests: PASS | generated packages\n'; else printf 'PASS four generated client and shell packages\n'; fi
