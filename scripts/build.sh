#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shared="$root/shared"
output="$root/generated"
plugin_manifest="$root/adapters/plugins.tsv"
[ -f "$plugin_manifest" ] || { printf 'Missing plugin manifest: %s\n' "$plugin_manifest" >&2; exit 1; }
[ "$(awk 'NR > 1 && NF == 5 { count++ } END { print count + 0 }' "$plugin_manifest")" -eq 4 ] || { printf 'Plugin manifest must define exactly four plugins.\n' >&2; exit 1; }

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
for platform in windows linux; do
mkdir -p "$output/codex-$platform" "$output/claude-$platform"
copy_directory "$shared/skills" "$output/codex-$platform/skills"
copy_directory "$shared/skills" "$output/claude-$platform/skills"
copy_directory "$shared/rules" "$output/codex-$platform/rules"
copy_directory "$shared/rules" "$output/claude-$platform/rules"
copy_directory "$shared/hooks" "$output/codex-$platform/hooks"
copy_directory "$shared/hooks" "$output/claude-$platform/hooks"
copy_directory "$shared/statusline" "$output/claude-$platform/statusline"

cp "$shared/global-instructions.md" "$output/codex-$platform/AGENTS.md"
cp "$shared/global-instructions.md" "$output/claude-$platform/CLAUDE.md"
cp "$root/adapters/codex/config/config.toml" "$output/codex-$platform/config.toml"
cp "$root/adapters/claude/config/settings.json" "$output/claude-$platform/settings.json"

for client in codex claude; do
  agents_output="$output/$client-$platform/agents"
  mkdir -p "$agents_output"
  for agent in "$shared"/agents/*; do
    metadata="$agent/agent.yml"
    name=$(read_field "$metadata" name)
    description=$(read_field "$metadata" description)
    instructions=$(<"$agent/instructions.md")
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
done
printf 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux\n'

