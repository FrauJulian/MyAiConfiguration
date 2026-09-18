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
grep -Eq '\$HoldMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
grep -Eq '\$FadeMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
[ "$(grep -c 'default=250' "$root/shared/hooks/flashbang.sh")" -ge 2 ]
branch=$(git -C "$root" branch --show-current)
build_summary_output=$(bash "$root/scripts/commands/build.sh" --summary)
if ! printf '%s\n' "$build_summary_output" | grep -qx 'Build: PASS | 4 packages'; then
  printf 'build.sh --summary must still print the PASS line: %s\n' "$build_summary_output" >&2
  exit 1
fi
[ "$build_summary_output" = 'Build: PASS | 4 packages' ]
status_output=$(printf '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"%s","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}' "$root" | bash "$root/shared/statusline/statusline.sh")
plain_status_output=$(printf '%s' "$status_output" | sed -E $'s/\x1b\\[[0-9;]*m//g')
expected_status_output=$'Test Model \xc2\xb7 Review auto \xc2\xb7 Effort high \xc2\xb7 TestRepo @ '"$branch"$'\nCtx 200k \xc2\xb7 Used 9% \xc2\xb7 Tokens 16.7k'
[ "$plain_status_output" = "$expected_status_output" ]
source_agent_count=$(find "$root/shared/agents" -mindepth 1 -maxdepth 1 -type d | wc -l)
source_skill_count=$(find "$root/shared/skills" -name SKILL.md | wc -l)
rule_skill_count=$(($(wc -l < "$root/adapters/rule-skills.tsv") - 1))
for shell in powershell bash; do
  for client in codex claude; do
    package="$root/generated/$client-$shell"
    file=config.toml
    [ "$client" != claude ] || file=settings.json
    test -f "$package/$file"
    if [ "$client" = codex ]; then
      while IFS=$'\t' read -r rule_file _ trigger; do
        [ "$rule_file" = rule_file ] && continue
        [ -n "$rule_file" ] || continue
        rule_path=$rule_file
        [ -d "$root/shared/rules/$rule_file" ] && rule_path="$rule_file/index.md"
        grep -Fq -- "- rules/$rule_path for $trigger." "$package/AGENTS.md"
      done < "$root/adapters/rule-skills.tsv"
    fi
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
      python3 -c 'import json,sys; settings=json.load(open(sys.argv[1], encoding="utf-8-sig")); assert settings["sandbox"] == {"enabled": True, "allowUnsandboxedCommands": False, "failIfUnavailable": True}' "$package/$file"
      statusline_extension='sh'
      [ "$shell" != powershell ] || statusline_extension=ps1
      test -f "$package/statusline/statusline.$statusline_extension"
      grep -q "statusline.$statusline_extension" "$package/$file"
    fi
    if grep -Eq '__HOOK_|__POWERSHELL_HOOK_' "$package/$file"; then exit 1; fi
    doc_file=AGENTS.md
    [ "$client" != claude ] || doc_file=CLAUDE.md
    doc_content=$(cat "$package/$doc_file")
    printf '%s' "$doc_content" | grep -Fq 'Use MCP services only through the `mcporter` CLI.'
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
doctor_summary_output=$(bash "$root/scripts/commands/doctor.sh" --summary)
if printf '%s\n' "$doctor_summary_output" | grep -q '^PASS '; then
  printf 'Doctor summary mode must not print individual PASS lines.\n' >&2
  exit 1
fi
if ! printf '%s\n' "$doctor_summary_output" | grep -Eq '^Doctor: PASS \| [0-9]+ checks$'; then
  printf "Doctor summary mode must print one 'Doctor: PASS | N checks' line: %s\n" "$doctor_summary_output" >&2
  exit 1
fi
for entry_point in install update; do
  preview=$(bash "$root/scripts/commands/$entry_point.sh" --summary --dry-run --client both --shell bash)
  if printf '%s\n' "$preview" | grep -Eq '^(SOURCE|CREATE|UPDATE|UNCHANGED|BACKUP|DRYRUN|PASS) '; then
    printf '%s summary leaked per-item output.\n' "$entry_point" >&2
    exit 1
  fi
  printf '%s\n' "$preview" | grep -Eiq "^$entry_point: PASS"
done
printf '%s\n' "$doctor_summary_output" | grep '^WARN ' || true
if [ "$summary" = true ]; then printf 'Tests: PASS | shell packages\n'; else printf 'PASS four shell packages and six Bash selections\n'; fi
