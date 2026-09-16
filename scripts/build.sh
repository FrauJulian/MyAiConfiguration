#!/usr/bin/env bash
set -euo pipefail
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shared="$root/shared"
output="$root/generated"
plugin_manifest="$root/adapters/plugins.tsv"
rule_skill_manifest="$root/adapters/claude/rule-skills.tsv"

[ -f "$plugin_manifest" ] || { printf 'Missing plugin manifest: %s\n' "$plugin_manifest" >&2; exit 1; }
declare -A plugin_seen
plugin_count=0
while IFS=$'\t' read -r name claude_marketplace claude_plugin codex_marketplace codex_plugin; do
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
declare -A rule_skill_seen
rule_skill_files=()
rule_skill_names=()
rule_skill_triggers=()
while IFS=$'\t' read -r rule_file skill_name trigger; do
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
done < "$rule_skill_manifest"
[ "${#rule_skill_names[@]}" -gt 0 ] || { printf 'Rule-skill manifest must define at least one entry.\n' >&2; exit 1; }

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

bash "$shared/hooks/scripts/test-session-config.sh" "$root"
rm -rf -- "$output"

agent_dirs=("$shared"/agents/*/)
declare -A agent_seen
for agent_dir in "${agent_dirs[@]}"; do
  name=$(read_field "${agent_dir}agent.yml" name)
  [ -z "${agent_seen[$name]+x}" ] || { printf 'Duplicate agent name: %s\n' "$name" >&2; exit 1; }
  agent_seen[$name]=1
done

# Codex keeps the original rule-loading text unchanged: every rule ships as a plain
# file and AGENTS.md tells Codex to load the matching one by path.
read -r -d '' codex_rule_loading <<'BLOCK' || true
Always load and apply `rules/general.md` before starting any task.

When programming, always load and apply `rules/security.md`. This includes implementing, modifying, debugging, reviewing, testing, and configuring software, scripts, hooks, infrastructure, and integrations.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Load every applicable rule file before editing. Load all matching files when multiple technologies apply.

Load rule files when their subject applies:

- rules/security-auth.md for authentication, authorization, sessions, tokens, permissions, or tenant boundaries.
- rules/security-web.md for browser, frontend, cookie, redirect, XSS, or CSRF work.
- rules/security-api.md for HTTP APIs, request handling, serialization, or endpoints.
- rules/security-data.md for databases, persistence, sensitive data, or multi-tenancy.
- rules/security-files.md for files, uploads, archives, paths, processes, IPC, or deserialization.
- rules/security-network.md for network access, URLs, TLS, proxies, or SSRF.
- rules/security-crypto.md for cryptography, secrets, credentials, keys, or tokens.
- rules/security-supply-chain.md for dependencies, packages, plugins, builds, deployments, or CI.
- rules/angular/index.md for Angular work.
- rules/typescript.md for TypeScript work.
- rules/csharp.md for C# or .NET work.
- rules/wpf/index.md for WPF work.
- rules/ui-ux/index.md for UI or UX decisions.
- rules/microsoft.md for Microsoft 365, Azure DevOps, or Teams work.
- rules/git.md for Git operations.
- rules/refactoring.md for refactoring work.
- rules/definition-of-done.md when validating completion.
- rules/decision-rule.md when requirements, behavior, or technical choices need to be evaluated.
BLOCK

for platform in windows linux; do
mkdir -p "$output/codex-$platform" "$output/claude-$platform"
copy_directory "$shared/skills" "$output/codex-$platform/skills"
copy_directory "$shared/skills" "$output/claude-$platform/skills"
copy_directory "$shared/rules" "$output/codex-$platform/rules"
copy_directory "$shared/hooks" "$output/codex-$platform/hooks"
copy_directory "$shared/hooks" "$output/claude-$platform/hooks"
copy_directory "$shared/statusline" "$output/claude-$platform/statusline"

# Claude: general.md stays a plain, always-applied rule file. Every technology- or
# situation-specific rule becomes a skill instead, so only its name and description
# sit permanently in context; the full text loads only when the skill is invoked.
mkdir -p "$output/claude-$platform/rules"
cp "$shared/rules/general.md" "$output/claude-$platform/rules/general.md"

claude_rule_loading_list=""
for i in "${!rule_skill_names[@]}"; do
  rule_file=${rule_skill_files[$i]}
  skill_name=${rule_skill_names[$i]}
  trigger=${rule_skill_triggers[$i]}
  rule_source="$shared/rules/$rule_file"
  rule_body="$rule_source"
  [ -d "$rule_source" ] && rule_body="$rule_source/index.md"
  skill_dir="$output/claude-$platform/skills/rules/$skill_name"
  mkdir -p "$skill_dir"
  { printf -- '---\nname: %s\ndescription: Use for %s.\n---\n\n' "$skill_name" "$trigger"; cat "$rule_body"; } > "$skill_dir/SKILL.md"
  if [ -d "$rule_source/references" ]; then
    copy_directory "$rule_source/references" "$skill_dir/references"
  fi
  claude_rule_loading_list="${claude_rule_loading_list}- ${skill_name} for ${trigger}.
"
done
claude_rule_loading="Always apply \`rules/general.md\` before starting any task, embedded below.

Detect the languages, frameworks, tools, and change areas from the repository and the requested work. Invoke every matching rule skill before editing. Invoke all matching rule skills when multiple technologies apply.

Invoke rule skills when their subject applies:

${claude_rule_loading_list%$'\n'}"

shared_template=$(<"$shared/global-instructions.md")
agents_content=${shared_template//__RULE_LOADING__/$codex_rule_loading}
printf '%s\n' "$agents_content" > "$output/codex-$platform/AGENTS.md"

general_content=$(<"$shared/rules/general.md")
claude_content=${shared_template//__RULE_LOADING__/$claude_rule_loading}
printf '%s\n\n---\n\n%s\n' "${claude_content%$'\n'}" "$general_content" > "$output/claude-$platform/CLAUDE.md"

cp "$root/adapters/codex/config/config.toml" "$output/codex-$platform/config.toml"
cp "$root/adapters/claude/config/settings.json" "$output/claude-$platform/settings.json"

for client in codex claude; do
  agents_output="$output/$client-$platform/agents"
  mkdir -p "$agents_output"
  for agent_dir in "${agent_dirs[@]}"; do
    metadata="${agent_dir}agent.yml"
    name=$(read_field "$metadata" name)
    description=$(read_field "$metadata" description)
    instructions=$(<"${agent_dir}instructions.md")
    if [ "$client" = codex ]; then
      printf 'name = %s\ndescription = %s\ndeveloper_instructions = %s\n' "$(quote_toml "$name")" "$(quote_toml "$description")" "$(quote_toml "$instructions")" > "$agents_output/$name.toml"
    else
      printf '%s\nname: %s\ndescription: %s\n%s\n\n%s\n' '---' "$name" "$description" '---' "$instructions" > "$agents_output/$name.md"
    fi
  done
done

for client in codex claude; do
  file=config.toml
  [ "$client" != claude ] || file=settings.json
  command=bash
  script=flashbang.sh
  statusline_script=statusline.sh
  if [ "$platform" = windows ]; then
    command='powershell -NoProfile -ExecutionPolicy Bypass -File'
    script=flashbang.ps1
    statusline_script=statusline.ps1
  fi
  path="$output/$client-$platform/$file"
  content=$(<"$path")
  content=${content//__HOOK_COMMAND__/$command}
  content=${content//__WINDOWS_HOOK_COMMAND__/$command}
  content=${content//__HOOK_SCRIPT__/$script}
  content=${content//__WINDOWS_HOOK_SCRIPT__/$script}
  content=${content//__STATUSLINE_COMMAND__/$command}
  content=${content//__STATUSLINE_SCRIPT__/$statusline_script}
  printf '%s\n' "$content" > "$path"
done

toml_path="$output/codex-$platform/config.toml"
settings_path="$output/claude-$platform/settings.json"
python3 "$root/scripts/validate-config.py" "$toml_path" "$settings_path"
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
leftover_tokens=$(grep -RohE '__[A-Z0-9_]+__' "$output" 2>/dev/null | sort -u | grep -v '^__AI_CONFIG_ROOT__$' || true)
if [ -n "$leftover_tokens" ]; then
  offending_files=$(grep -RlE '__[A-Z0-9_]+__' "$output" 2>/dev/null | tr '\n' ' ')
  printf 'Unresolved template placeholders (%s) in: %s\n' "$(printf '%s' "$leftover_tokens" | tr '\n' ' ')" "$offending_files" >&2
  exit 1
fi

printf 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux\n'
