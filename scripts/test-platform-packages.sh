#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Eq '\$HoldMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
grep -Eq '\$FadeMs[[:space:]]*=[[:space:]]*250' "$root/shared/hooks/flashbang.ps1"
[ "$(grep -c 'default=250' "$root/shared/hooks/flashbang.sh")" -ge 2 ]
branch=$(git -C "$root" branch --show-current)
status_output=$(printf '{"model":{"display_name":"Test Model"},"effort":{"level":"high"},"workspace":{"current_dir":"%s","repo":{"name":"TestRepo"}},"context_window":{"context_window_size":200000,"used_percentage":8.5,"total_input_tokens":15500,"total_output_tokens":1200}}' "$root" | bash "$root/shared/statusline/statusline.sh")
[ "$status_output" = "Model: Test Model | Effort: high | Repo: TestRepo | Branch: $branch | Max Context: 200000 | Used Context: 9% | Used Tokens: 16700" ]
source_agent_count=$(find "$root/shared/agents" -mindepth 1 -maxdepth 1 -type d | wc -l)
source_skill_count=$(find "$root/shared/skills" -name SKILL.md | wc -l)
rule_skill_count=$(($(wc -l < "$root/adapters/claude/rule-skills.tsv") - 1))
for platform in windows linux; do
  for client in codex claude; do
    package="$root/generated/$client-$platform"
    file=config.toml
    [ "$client" != claude ] || file=settings.json
    test -f "$package/$file"
    test "$(find "$package/agents" -type f | wc -l)" -eq "$source_agent_count"
    expected_skill_count=$source_skill_count
    [ "$client" != claude ] || expected_skill_count=$((source_skill_count + rule_skill_count))
    test "$(find "$package/skills" -name SKILL.md | wc -l)" -eq "$expected_skill_count"
    if [ "$platform" = windows ]; then
      grep -q 'powershell .*flashbang.ps1' "$package/$file"
      ! grep -Eq 'WindowStyle[[:space:]]+Hidden' "$package/$file"
    else
      grep -q 'bash .*flashbang.sh' "$package/$file"
    fi
    if [ "$client" = codex ]; then
      [ "$(sed -n 's/^\[\[hooks\.\([^].]*\)\]\]$/\1/p' "$package/$file")" = Stop ]
      ! grep -q 'flashbang-if-input' "$package/$file"
      ! grep -Eq '^async[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$package/$file"
      grep -q 'approvals_reviewer[[:space:]]*=[[:space:]]*"auto_review"' "$package/$file"
      grep -Fq 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-window-size", "context-used", "used-tokens"]' "$package/$file"
    else
      [ "$(awk '/^  "hooks": \{/{inside=1; next} inside && /^  \}/{inside=0} inside && /^    "[^"]+": \[$/{gsub(/^    "|": \[$/, ""); print}' "$package/$file")" = Stop ]
      ! grep -q 'flashbang-if-input' "$package/$file"
      ! grep -q '"async"[[:space:]]*:[[:space:]]*true' "$package/$file"
      grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"auto"' "$package/$file"
      statusline_extension=sh
      [ "$platform" != windows ] || statusline_extension=ps1
      test -f "$package/statusline/statusline.$statusline_extension"
      grep -q "statusline.$statusline_extension" "$package/$file"
    fi
    if grep -Eq '__HOOK_|__WINDOWS_HOOK_' "$package/$file"; then exit 1; fi
  done
done
for platform_selection in 1 2; do
  for client_selection in 1 2 3; do
    output=$(printf '%s\n%s\n' "$platform_selection" "$client_selection" | bash "$root/scripts/install.sh" --dry-run)
    [[ "$output" == *'PASS install dry-run'* ]]
    platform=windows
    [ "$platform_selection" != 2 ] || platform=linux
    [[ "$output" == *"-$platform"* ]]
  done
done
printf 'PASS four platform packages and six Bash selections\n'

