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
plugin_manifest="$root/adapters/plugins.tsv"
rule_skill_manifest="$root/adapters/rule-skills.tsv"
capability_manifest="$root/adapters/claude/capabilities.tsv"

[ -f "$plugin_manifest" ] || { printf 'Missing plugin manifest: %s\n' "$plugin_manifest" >&2; exit 1; }
declare -A plugin_seen
plugin_count=0
while IFS=$'\t' read -r name _ claude_plugin _ codex_plugin; do
  [ "$name" != name ] || continue
  [ -n "$name" ] || continue
  plugin_count=$((plugin_count + 1))
  [ -n "$claude_plugin" ] || { printf 'Missing claude_plugin for plugin %s.\n' "$name" >&2; exit 1; }
  [ -n "$codex_plugin" ] || { printf 'Missing codex_plugin for plugin %s.\n' "$name" >&2; exit 1; }
  [ -z "${plugin_seen[$name]+x}" ] || { printf 'Duplicate plugin name in manifest: %s\n' "$name" >&2; exit 1; }
  plugin_seen[$name]=1
done < "$plugin_manifest"
[ "$plugin_count" -gt 0 ] || { printf 'Plugin manifest must define at least one plugin.\n' >&2; exit 1; }

[ -f "$rule_skill_manifest" ] || { printf 'Missing rule-skill manifest: %s\n' "$rule_skill_manifest" >&2; exit 1; }
[ -f "$capability_manifest" ] || { printf 'Missing capability manifest: %s\n' "$capability_manifest" >&2; exit 1; }
declare -A rule_skill_seen
rule_skill_files=()
rule_skill_names=()
rule_skill_triggers=()
while IFS=$'\t' read -r rule_file skill_name trigger; do
  trigger=${trigger%$'\r'}
  [ "$rule_file" != rule_file ] || continue
  [ -n "$rule_file" ] || continue
  [ -n "$skill_name" ] || { printf 'Missing skill_name in rule-skill manifest row for %s.\n' "$rule_file" >&2; exit 1; }
  [ -n "$trigger" ] || { printf 'Missing trigger in rule-skill manifest row for %s.\n' "$rule_file" >&2; exit 1; }
  [ -f "$shared/rules/$rule_file" ] || [ -d "$shared/rules/$rule_file" ] || { printf 'Rule-skill manifest references a missing rule file: %s\n' "$rule_file" >&2; exit 1; }
  [ -z "${rule_skill_seen[$skill_name]+x}" ] || { printf 'Duplicate rule-skill name in manifest: %s\n' "$skill_name" >&2; exit 1; }
  rule_skill_seen[$skill_name]=1
  rule_skill_files+=("$rule_file")
  rule_skill_names+=("$skill_name")
  rule_skill_triggers+=("$trigger")
done < <(tail -n +2 "$rule_skill_manifest" | sort -t$'\t' -k2,2)
[ "${#rule_skill_names[@]}" -gt 0 ] || { printf 'Rule-skill manifest must define at least one entry.\n' >&2; exit 1; }
codex_rule_loading_list=""
for i in "${!rule_skill_names[@]}"; do
  rule_file=${rule_skill_files[$i]}
  rule_path="$rule_file"
  [ -d "$shared/rules/$rule_file" ] && rule_path="$rule_file/index.md"
  codex_rule_loading_list="${codex_rule_loading_list}- rules/${rule_path} for ${rule_skill_triggers[$i]}."$'\n'
done
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

# Codex: general.md is embedded directly into AGENTS.md, the same way Claude embeds
# it into CLAUDE.md, instead of only being referenced by path — guaranteed present
# either way, and safe even if a subagent's AGENTS.md inheritance is not guaranteed.
read -r -d '' codex_rule_loading <<'BLOCK' || true
General rules are embedded below.

When programming, always load and apply `rules/security.md`. This includes implementing, modifying, debugging, reviewing, testing, and configuring software, scripts, hooks, infrastructure, and integrations.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Load every applicable rule file before editing. Load all matching files when multiple technologies apply.

Load rule files when their subject applies:
BLOCK
codex_rule_loading="${codex_rule_loading}"$'\n\n'"${codex_rule_loading_list%$'\n'}"

for shell in powershell bash; do
mkdir -p "$output/codex-$shell" "$output/claude-$shell"
copy_directory "$shared/skills" "$output/codex-$shell/skills"
copy_directory "$shared/skills" "$output/claude-$shell/skills"
copy_directory "$shared/rules" "$output/codex-$shell/rules"
copy_directory "$shared/hooks" "$output/codex-$shell/hooks"
copy_directory "$shared/hooks" "$output/claude-$shell/hooks"
copy_directory "$shared/statusline" "$output/claude-$shell/statusline"

mkdir -p "$output/claude-$shell/rules"

claude_rule_loading_list=""
for i in "${!rule_skill_names[@]}"; do
  rule_file=${rule_skill_files[$i]}
  skill_name=${rule_skill_names[$i]}
  trigger=${rule_skill_triggers[$i]}
  rule_source="$shared/rules/$rule_file"
  rule_body="$rule_source"
  [ -d "$rule_source" ] && rule_body="$rule_source/index.md"
  skill_dir="$output/claude-$shell/skills/rules/$skill_name"
  mkdir -p "$skill_dir"
  { printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$skill_name" "$(quote_toml "Use for $trigger.")"; cat "$rule_body"; } > "$skill_dir/SKILL.md"
  if [ -d "$rule_source/references" ]; then
    copy_directory "$rule_source/references" "$skill_dir/references"
  fi
  claude_rule_loading_list="${claude_rule_loading_list}- ${skill_name} for ${trigger}.
"
done
claude_rule_loading="General rules are embedded below.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Invoke every matching rule skill before editing. Invoke all matching rule skills when multiple technologies apply.

Invoke rule skills when their subject applies:

${claude_rule_loading_list%$'\n'}"

shared_template=$(<"$shared/global-instructions.md")
general_content=$(<"$shared/rules/general.md")

agents_content=${shared_template//__RULE_LOADING__/$codex_rule_loading}
printf '%s\n\n---\n\n%s\n' "${agents_content%$'\n'}" "$general_content" > "$output/codex-$shell/AGENTS.md"

claude_content=${shared_template//__RULE_LOADING__/$claude_rule_loading}
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
  content=${content//__HOOK_COMMAND__/$command}
  content=${content//__POWERSHELL_HOOK_COMMAND__/$command}
  content=${content//__HOOK_SCRIPT__/$script}
  content=${content//__POWERSHELL_HOOK_SCRIPT__/$script}
  content=${content//__COMPACT_SCRIPT__/$compact_script}
  content=${content//__SESSION_POINTER_SCRIPT__/$pointer_script}
  content=${content//__STATUSLINE_COMMAND__/$command}
  content=${content//__STATUSLINE_SCRIPT__/$statusline_script}
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
