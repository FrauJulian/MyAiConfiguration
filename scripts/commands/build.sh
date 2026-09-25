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
shared="$root/shared"
output="$root/generated"
capability_manifest="$root/adapters/claude/capabilities.tsv"

[ -f "$capability_manifest" ] || { printf 'Missing capability manifest: %s\n' "$capability_manifest" >&2; exit 1; }
declare -A agent_tools
while IFS=$'\t' read -r role tools; do
  [ "$role" != role ] || continue
  [ -n "$role" ] && [ -n "$tools" ] || { printf 'Invalid capability manifest row.\n' >&2; exit 1; }
  agent_tools[$role]="$tools"
done < "$capability_manifest"

copy_directory() {
  local source=$1 destination=$2
  mkdir -p "$destination"
  cp -R "$source"/. "$destination"/
}

read_field() {
  local path=$1 name=$2 value
  value=$(sed -n "s/^${name}:[[:space:]]*//p" "$path" | head -n 1)
  [ -n "$value" ] || { printf 'Missing %s in %s\n' "$name" "$path" >&2; exit 1; }
  printf '%s' "$value"
}

quote_toml() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\r'/}
  value=${value//$'\n'/\\n}
  printf '"%s"' "$value"
}

session_output=$(bash "$shared/hooks/scripts/test-session-config.sh" "$root") || { printf '%s\n' "$session_output" >&2; exit 1; }
if [ "$summary" = true ]; then
  printf '%s\n' "$session_output" | sed '/^PASS session configuration$/d'
else
  printf '%s\n' "$session_output"
fi
rm -rf -- "$output"

agent_dirs=("$shared"/agents/*/)
declare -A agent_seen
for agent_dir in "${agent_dirs[@]}"; do
  name=$(read_field "${agent_dir}agent.yml" name)
  [ -z "${agent_seen[$name]+x}" ] || { printf 'Duplicate agent name: %s\n' "$name" >&2; exit 1; }
  agent_seen[$name]=1
done

for shell in powershell bash; do
mkdir -p "$output/codex-$shell" "$output/claude-$shell"
copy_directory "$shared/skills" "$output/codex-$shell/skills"
copy_directory "$shared/skills" "$output/claude-$shell/skills"
copy_directory "$shared/rules" "$output/codex-$shell/rules"
copy_directory "$shared/hooks" "$output/codex-$shell/hooks"
copy_directory "$shared/hooks" "$output/claude-$shell/hooks"
copy_directory "$shared/statusline" "$output/claude-$shell/statusline"

declare -A rule_skill_names=()
while IFS= read -r rule_path; do
  case "$rule_path" in
    general.md) continue ;;
    */index.md) skill_name="rules-${rule_path%/index.md}"; rule_body="$shared/rules/$rule_path"; references_dir="${rule_body%/index.md}/references" ;;
    */*.md)
      rule_directory=${rule_path%%/*}
      rule_relative=${rule_path#*/}
      rule_relative=${rule_relative%.md}
      rule_relative=${rule_relative#references/}
      rule_relative=${rule_relative//\//-}
      skill_name="rules-$rule_directory-$rule_relative"
      rule_body="$shared/rules/$rule_path"
      references_dir=''
      ;;
    *.md) skill_name="rules-${rule_path%.md}"; rule_body="$shared/rules/$rule_path"; references_dir='' ;;
    *) continue ;;
  esac
  if [[ -n "${rule_skill_names[$skill_name]:-}" ]]; then
    printf 'Duplicate generated rule skill name: %s\n' "$skill_name" >&2
    exit 1
  fi
  rule_skill_names[$skill_name]=1
  skill_dir="$output/claude-$shell/skills/rules/$skill_name"
  mkdir -p "$skill_dir"
  rule_title=$(sed -n 's/^#\{1,6\} *//p' "$rule_body" | head -n 1)
  if [ -z "$rule_title" ]; then printf 'Missing rule title in %s\n' "$rule_body" >&2; exit 1; fi
  rule_description="Use when the task concerns $rule_title."
  { printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$skill_name" "$(quote_toml "$rule_description")"; cat "$rule_body"; } > "$skill_dir/SKILL.md"
  if [ -n "$references_dir" ] && [ -d "$references_dir" ]; then
    copy_directory "$references_dir" "$skill_dir/references"
  fi
done < <(find "$shared/rules" -mindepth 1 -type f -name '*.md' -printf '%P\n' | sort)

shared_template=$(<"$shared/global-instructions.md")
general_content=$(<"$shared/rules/general.md")
credential_helper_extension='sh'
[ "$shell" != powershell ] || credential_helper_extension='ps1'

agents_content=${shared_template//__CLIENT__/codex}
agents_content=${agents_content//__SHELL__/$credential_helper_extension}
printf '%s\n\n---\n\n%s\n' "${agents_content%$'\n'}" "$general_content" > "$output/codex-$shell/AGENTS.md"

claude_content=${shared_template//__CLIENT__/claude}
claude_content=${claude_content//__SHELL__/$credential_helper_extension}
printf '%s\n\n---\n\n%s\n' "${claude_content%$'\n'}" "$general_content" > "$output/claude-$shell/CLAUDE.md"

cp "$root/adapters/codex/config/config.toml" "$output/codex-$shell/config.toml"
cp "$root/adapters/claude/config/settings.json" "$output/claude-$shell/settings.json"

for client in codex claude; do
  agents_output="$output/$client-$shell/agents"
  mkdir -p "$agents_output"
  for agent_dir in "${agent_dirs[@]}"; do
    metadata="${agent_dir}agent.yml"
    name=$(read_field "$metadata" name)
    description=$(read_field "$metadata" description)
    instructions=$(<"$root/adapters/$client/orchestration-loader.txt")$'\n\n'$(<"${agent_dir}instructions.md")
    if [ "$client" = codex ]; then
      printf 'name = %s\ndescription = %s\ndeveloper_instructions = %s\n' "$(quote_toml "$name")" "$(quote_toml "$description")" "$(quote_toml "$instructions")" > "$agents_output/$name.toml"
    else
      tools=${agent_tools[$name]:-}
      shell_tool=Bash
      [ "$shell" != powershell ] || shell_tool=PowerShell
      tools=${tools//__SHELL__/$shell_tool}
      if [ -n "$tools" ]; then printf '%s\nname: %s\ndescription: %s\ntools: %s\n%s\n\n%s\n' '---' "$name" "$description" "$tools" '---' "$instructions" > "$agents_output/$name.md"; else printf '%s\nname: %s\ndescription: %s\n%s\n\n%s\n' '---' "$name" "$description" '---' "$instructions" > "$agents_output/$name.md"; fi
    fi
  done
done

for client in codex claude; do
  file=config.toml
  [ "$client" != claude ] || file=settings.json
  command=bash
  script=flashbang.sh
  statusline_script=statusline.sh
  compact_script=record-compact.sh
  pointer_script=show-session-state-pointer.sh
  if [ "$shell" = powershell ]; then
    command='__POWERSHELL_COMMAND__'
    script=flashbang.ps1
    statusline_script=statusline.ps1
    compact_script=Record-Compact.ps1
    pointer_script=Show-SessionStatePointer.ps1
  fi
  path="$output/$client-$shell/$file"
  content=$(<"$path")
  sandbox='{"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}'
  [ "$shell" != powershell ] || sandbox='{"enabled": false}'
  content=${content//__HOOK_COMMAND__/$command}
  content=${content//__POWERSHELL_HOOK_COMMAND__/$command}
  content=${content//__HOOK_SCRIPT__/$script}
  content=${content//__POWERSHELL_HOOK_SCRIPT__/$script}
  content=${content//__COMPACT_SCRIPT__/$compact_script}
  content=${content//__SESSION_POINTER_SCRIPT__/$pointer_script}
  content=${content//__STATUSLINE_COMMAND__/$command}
  content=${content//__STATUSLINE_SCRIPT__/$statusline_script}
  content=${content//__CLAUDE_SANDBOX__/$sandbox}
  printf '%s\n' "$content" > "$path"
done

toml_path="$output/codex-$shell/config.toml"
settings_path="$output/claude-$shell/settings.json"
python3 "$root/scripts/checks/validate-config.py" "$toml_path" "$settings_path"
if command -v codex >/dev/null; then
  schema_home=$(mktemp -d)
  cp "$toml_path" "$schema_home/config.toml"
  CODEX_HOME="$schema_home" codex --strict-config --help >/dev/null
  rm -rf -- "$schema_home"
elif [ "${REQUIRE_CODEX_SCHEMA:-false}" = true ]; then
  printf 'Codex CLI is required for schema validation.\n' >&2
  exit 1
else
  printf 'WARN Codex CLI unavailable; skipped Codex schema validation.\n' >&2
fi
done

# __AI_CONFIG_ROOT__ is resolved at install time, once the destination is known; it is
# expected to remain in generated output, so it is excluded from the leftover check. A
# single tree-wide grep (rather than one process per file) keeps this fast.
leftover_tokens=$(grep -RohE '__[A-Z0-9_]+__' "$output" 2>/dev/null | sort -u | grep -Ev '^(__AI_CONFIG_ROOT__|__POWERSHELL_COMMAND__|__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__)$' || true)
if [ -n "$leftover_tokens" ]; then
  offending_files=$(grep -RlE '__[A-Z0-9_]+__' "$output" 2>/dev/null | tr '\n' ' ')
  printf 'Unresolved template placeholders (%s) in: %s\n' "$(printf '%s' "$leftover_tokens" | tr '\n' ' ')" "$offending_files" >&2
  exit 1
fi

if [ "$summary" = true ]; then printf 'Build: PASS | 4 packages\n'; else printf 'PASS build: codex-powershell, claude-powershell, codex-bash, claude-bash\n'; fi
