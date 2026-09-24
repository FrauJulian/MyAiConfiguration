#!/usr/bin/env bash
set -euo pipefail

plugin_installed() {
  local client=$1 plugin=$2
  local inventory
  inventory=$("$client" plugin list --json) || return 2
  printf '%s' "$inventory" | python3 -c '
import json, sys
try:
    client, plugin = sys.argv[1:]
    data = json.load(sys.stdin)
    if client == "codex":
        data = data["installed"]
    if not isinstance(data, list) or any(not isinstance(item, dict) for item in data):
        raise ValueError("Invalid plugin inventory")
    sys.exit(0 if any(item.get("id" if client == "claude" else "pluginId") == plugin for item in data) else 1)
except (ValueError, KeyError, TypeError) as error:
    print("Invalid plugin inventory: " + str(error), file=sys.stderr)
    sys.exit(2)
' "$client" "$plugin"
}

run_plugin_command() {
  local dry_run=$1
  shift
  if [ "$dry_run" = true ]; then
    [ "${summary:-false}" = true ] || printf 'DRYRUN %s\n' "$*"
    return 0
  elif [ "${summary:-false}" = true ]; then
    local output status
    if output=$("$@"); then
      printf '%s\n' "$output" | grep -Ei 'warn|error|fail|deprecat' || true
    else
      status=$?
      printf '%s\n' "$output" >&2
      printf 'Plugin command failed: %s\n' "$*" >&2
      return "$status"
    fi
  else
    "$@"
  fi
}

get_plugin_names() {
  local root=$1 name rest
  while IFS=$'\t' read -r name rest; do
    [ "$name" = name ] && continue
    [ -n "$name" ] || continue
    printf '%s\n' "$name"
  done < "$root/adapters/plugins.tsv"
}

# plugin_field <root> <name> <field> -- field is one of the plugins.tsv column names
plugin_field() {
  local root=$1 target=$2 field=$3
  # shellcheck disable=SC2034
  local name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill
  # shellcheck disable=SC2034
  while IFS=$'\t' read -r name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill; do
    [ "$name" = "$target" ] || continue
    printf '%s\n' "${!field}"
    return 0
  done < "$root/adapters/plugins.tsv"
  return 1
}

plugin_toggleable() {
  return 0
}

# read_plugin_toggle_selection <names-array-name> <checked-array-name>
read_plugin_toggle_selection() {
  local -n names_ref=$1
  local -n checked_ref=$2
  local answer i mark index=0 key
  if [ -t 0 ] && [ "${CI:-}" != true ] && [ "${AI_CONFIG_NO_INTERACTIVE:-}" != 1 ]; then
    while :; do clear_interactive; printf 'Select plugins\n'; for ((i=0;i<${#names_ref[@]};i++)); do mark=' '; [ "${checked_ref[$i]}" = true ] && mark=x; [ "$i" -eq "$index" ] && printf '> [%s] %s\n' "$mark" "${names_ref[$i]}" || printf '  [%s] %s\n' "$mark" "${names_ref[$i]}"; done; printf 'Up/Down Navigate   Space Toggle   Enter Confirm\n'; IFS= read -rsn1 key || return 1; case "$key" in $'\x1b') read -rsn2 key; case "$key" in '[A') index=$(( (index+${#names_ref[@]}-1)%${#names_ref[@]} ));; '[B') index=$(( (index+1)%${#names_ref[@]} ));; esac;; ' ') [ "${checked_ref[$index]}" = true ] && checked_ref[$index]=false || checked_ref[$index]=true;; '') clear_interactive; return 0;; esac; done
  fi
  while :; do
    printf 'Select plugins (enter a number to toggle, "done" to confirm):\n'
    for ((i = 0; i < ${#names_ref[@]}; i++)); do
      mark=' '
      [ "${checked_ref[$i]}" = true ] && mark=x
      printf '  %d) [%s] %s\n' "$((i + 1))" "$mark" "${names_ref[$i]}"
    done
    read -r -p 'Toggle number or "done" ' answer || { printf 'Plugin selection cancelled: input closed.\n' >&2; return 1; }
    { [ -z "$answer" ] || [ "$answer" = "done" ]; } && return 0
    if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le "${#names_ref[@]}" ]; then
      i=$((10#$answer - 1))
      if [ "${checked_ref[$i]}" = true ]; then checked_ref[$i]=false; else checked_ref[$i]=true; fi
    fi
  done
}

# select_configured_plugins <root> <client> <mode: Install|Update> <dry_run> <selected-array-name> <deselected-array-name>
select_configured_plugins() {
  local root=$1 client=$2 mode=$3 dry_run=$4
  local -n selected_ref=$5
  local -n deselected_ref=$6
  selected_ref=()
  deselected_ref=()

  local name all_names=() toggle_names=() fixed_names=()
  while IFS= read -r name; do
    all_names+=("$name")
    if plugin_toggleable "$root" "$name" "$client"; then toggle_names+=("$name"); else fixed_names+=("$name"); fi
  done < <(get_plugin_names "$root")

  if [ ${#toggle_names[@]} -eq 0 ] || { [ "$dry_run" = true ] && [ "$mode" = Install ]; }; then
    selected_ref=("${all_names[@]}")
    return 0
  fi

  local reference_clients=(claude)
  [ "$client" = codex ] && reference_clients=(codex)
  [ "$client" = both ] && reference_clients=(claude codex)

  local checked=() selector reference_client found
  for name in "${toggle_names[@]}"; do
    if [ "$mode" = Install ]; then
      checked+=(true)
      continue
    fi
    if [ "$(plugin_field "$root" "$name" codex_method)" = cli ]; then
      if command -v "$(plugin_field "$root" "$name" codex_source)" >/dev/null 2>&1; then checked+=(true); else checked+=(false); fi
      continue
    fi
    found=false
    for reference_client in "${reference_clients[@]}"; do
      if [ "$reference_client" = claude ]; then selector=$(plugin_field "$root" "$name" claude_plugin); else selector=$(plugin_field "$root" "$name" codex_plugin); fi
      if [ "$reference_client" = codex ] && [ "$(plugin_field "$root" "$name" codex_method)" = qmd ]; then
        command -v qmd >/dev/null 2>&1 && found=true
      elif [ "$reference_client" = codex ] && [ "$(plugin_field "$root" "$name" codex_method)" != plugin ]; then
        local skill_name
        skill_name=$(plugin_field "$root" "$name" codex_skill)
        { [ -d "$HOME/.agents/skills/$skill_name" ] || [ -d "$HOME/.codex/skills/$skill_name" ]; } && found=true
      elif plugin_installed "$reference_client" "$selector"; then found=true
      else
        local status=$?
        [ "$status" -eq 1 ] || return "$status"
      fi
    done
    checked+=("$found")
  done

  if [ "$dry_run" != true ]; then read_plugin_toggle_selection toggle_names checked; fi

  local i
  for ((i = 0; i < ${#toggle_names[@]}; i++)); do
    if [ "${checked[$i]}" = true ]; then selected_ref+=("${toggle_names[$i]}"); else deselected_ref+=("${toggle_names[$i]}"); fi
  done
  selected_ref+=("${fixed_names[@]}")
}

managed_extensions() {
  local action=$1 root=$2 client=$3 home_path=$4 dry_run=$5 update=$6 selected_name=${7:-} summary=${8:-false}
  local arguments=("$root/scripts/lib/managed-extensions.py" "$action" --home "$home_path" --manifest "$root/adapters/plugins.tsv" --client "$client")
  [ "$dry_run" != true ] || arguments+=(--dry-run)
  [ "$update" != true ] || arguments+=(--update)
  [ "$summary" != true ] || arguments+=(--summary)
  if [ -n "$selected_name" ]; then
    local -n extension_names_ref=$selected_name
    arguments+=(--selected "${extension_names_ref[@]}")
  fi
  python3 "${arguments[@]}"
}

sync_configured_plugins() {
  managed_extensions sync "$@"
}

install_configured_plugins() {
  local root=$1 client=$2 dry_run=$3 update=$4 selected_name=${5:-} summary=${6:-false} home_path=${7:-$HOME}
  if [ -n "$selected_name" ]; then
    local -n install_names_ref=$selected_name
    [ "${#install_names_ref[@]}" -gt 0 ] || return 0
  fi
  managed_extensions install "$root" "$client" "$home_path" "$dry_run" "$update" "$selected_name" "$summary"
}

uninstall_deselected_plugins() {
  local root=$1 client=$2 dry_run=$3 selected_name=$4 summary=${5:-false} home_path=${6:-$HOME}
  local -n removal_names_ref=$selected_name
  [ "${#removal_names_ref[@]}" -gt 0 ] || return 0
  managed_extensions remove "$root" "$client" "$home_path" "$dry_run" false "$selected_name" "$summary"
}
