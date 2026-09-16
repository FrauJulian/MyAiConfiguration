#!/usr/bin/env bash
set -euo pipefail

plugin_installed() {
  local client=$1 plugin=$2
  if [ "$client" = claude ]; then
    claude plugin list --json 2>/dev/null | grep -Fq "\"id\": \"$plugin\""
  else
    codex plugin list --json 2>/dev/null | grep -Fq "\"pluginId\": \"$plugin\""
  fi
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
      return "$status"
    fi
  else
    "$@"
  fi
}

ensure_codex_marketplace() {
  local dry_run=$1 source=$2 marketplace_name=$3 output
  if [ "$dry_run" = true ]; then
    [ "${summary:-false}" = true ] || printf 'DRYRUN codex plugin marketplace add %s\n' "$source"
    return 0
  fi
  if output=$(codex plugin marketplace add "$source" 2>&1); then
    [ -z "$output" ] || printf '%s\n' "$output"
    return 0
  fi
  printf '%s\n' "$output" >&2
  if printf '%s\n' "$output" | grep -Eiq 'marketplace .* already added from a different source'; then
    printf "WARN Codex marketplace '%s' exists from another source; replacing it with: %s\n" "$marketplace_name" "$source"
    run_plugin_command false codex plugin marketplace remove "$marketplace_name"
    run_plugin_command false codex plugin marketplace add "$source"
    return 0
  fi
  return 1
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
  local name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill
  while IFS=$'\t' read -r name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill; do
    [ "$name" = "$target" ] || continue
    printf '%s\n' "${!field}"
    return 0
  done < "$root/adapters/plugins.tsv"
  return 1
}

plugin_toggleable() {
  local root=$1 name=$2 client=$3
  case "$client" in claude|both) return 0;; esac
  [ "$(plugin_field "$root" "$name" codex_method)" = plugin ]
}

# read_plugin_toggle_selection <names-array-name> <checked-array-name>
read_plugin_toggle_selection() {
  local -n names_ref=$1
  local -n checked_ref=$2
  local answer i mark
  while :; do
    printf 'Select plugins (enter a number to toggle, "done" to confirm):\n'
    for ((i = 0; i < ${#names_ref[@]}; i++)); do
      mark=' '
      [ "${checked_ref[$i]}" = true ] && mark=x
      printf '  %d) [%s] %s\n' "$((i + 1))" "$mark" "${names_ref[$i]}"
    done
    read -r -p 'Toggle number or "done" ' answer || { printf 'Plugin selection cancelled: input closed.\n' >&2; return 1; }
    { [ -z "$answer" ] || [ "$answer" = done ]; } && return 0
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

  if [ "$dry_run" = true ] || [ ${#toggle_names[@]} -eq 0 ]; then
    selected_ref=("${all_names[@]}")
    return 0
  fi

  local reference_client=claude
  [ "$client" = codex ] && reference_client=codex

  local checked=() selector
  for name in "${toggle_names[@]}"; do
    if [ "$mode" = Install ]; then
      checked+=(true)
      continue
    fi
    if [ "$reference_client" = claude ]; then selector=$(plugin_field "$root" "$name" claude_plugin); else selector=$(plugin_field "$root" "$name" codex_plugin); fi
    if plugin_installed "$reference_client" "$selector"; then checked+=(true); else checked+=(false); fi
  done

  read_plugin_toggle_selection toggle_names checked

  local i
  for ((i = 0; i < ${#toggle_names[@]}; i++)); do
    if [ "${checked[$i]}" = true ]; then selected_ref+=("${toggle_names[$i]}"); else deselected_ref+=("${toggle_names[$i]}"); fi
  done
  selected_ref+=("${fixed_names[@]}")
}

# uninstall_deselected_plugins <root> <client> <dry_run> <deselected-array-name> [summary]
uninstall_deselected_plugins() {
  local root=$1 client_selection=$2 dry_run=$3
  local -n names_ref=$4
  local summary=${5:-false}
  local clients=()
  case "$client_selection" in
    codex) clients=(codex);;
    claude) clients=(claude);;
    both) clients=(claude codex);;
  esac
  local client name plugin removed
  for client in "${clients[@]}"; do
    removed=0
    for name in "${names_ref[@]}"; do
      if [ "$client" = claude ]; then plugin=$(plugin_field "$root" "$name" claude_plugin); else plugin=$(plugin_field "$root" "$name" codex_plugin); fi
      [ -n "$plugin" ] || continue
      if [ "$dry_run" = false ] && plugin_installed "$client" "$plugin"; then
        if [ "$client" = claude ]; then
          run_plugin_command "$dry_run" claude plugin uninstall "$plugin" --scope user
        else
          run_plugin_command "$dry_run" codex plugin remove "$plugin"
        fi
        [ "$summary" = true ] || printf 'PASS %s plugin removed: %s\n' "$client" "$plugin"
        removed=$((removed + 1))
      fi
    done
    if [ "$summary" = true ] && [ "$removed" -gt 0 ]; then printf 'PLUGINS %s: %s removed\n' "$client" "$removed"; fi
  done
}

# install_configured_plugins <root> <client> <dry_run> <update> [selected-names-array-name] [summary]
install_configured_plugins() {
  local root=$1 client_selection=$2 dry_run=$3 update=$4 selected_name=${5:-} summary=${6:-false}
  local manifest="$root/adapters/plugins.tsv"
  [ -f "$manifest" ] || { printf 'Plugin manifest is missing: %s\n' "$manifest" >&2; return 1; }

  local -A selected_set=()
  if [ -n "$selected_name" ]; then
    local -n selected_names_ref=$selected_name
    local sn
    for sn in "${selected_names_ref[@]}"; do selected_set[$sn]=1; done
  fi
  local ensured=0 already_installed=0 updated_count=0

  local clients=()
  case "$client_selection" in
    codex) clients=(codex);;
    claude) clients=(claude);;
    both) clients=(claude codex);;
    *) printf 'Unknown plugin client selection: %s\n' "$client_selection" >&2; return 1;;
  esac

  local client name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill marketplace plugin
  for client in "${clients[@]}"; do
    ensured=0 already_installed=0 updated_count=0
    while IFS=$'\t' read -r name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill; do
      [ "$name" = name ] && continue
      [ -n "$name" ] || continue
      [ -n "$selected_name" ] && [ -z "${selected_set[$name]+x}" ] && continue
      [ "$claude_marketplace" = - ] && claude_marketplace=
      [ "$codex_marketplace" = - ] && codex_marketplace=
      if [ "$client" = claude ]; then marketplace=$claude_marketplace; plugin=$claude_plugin; else marketplace=$codex_marketplace; plugin=$codex_plugin; fi
      [ -n "$plugin" ] || { printf 'Plugin selector missing for %s: %s\n' "$client" "$name" >&2; return 1; }
      if [ "$client" = codex ] && [ "$codex_method" != plugin ]; then
        case "$codex_method" in
          skill)
            if [ "$codex_skill" = - ]; then
              run_plugin_command "$dry_run" npx -y skills add "$codex_source" --global --agent codex
            else
              run_plugin_command "$dry_run" npx -y skills add "$codex_source" --skill "$codex_skill" --global --agent codex
            fi
            ;;
          impeccable)
            run_plugin_command "$dry_run" npx -y impeccable install -y --providers=codex --scope=global
            ;;
          *) printf 'Unknown Codex install method for %s: %s\n' "$client" "$name" >&2; return 1;;
        esac
        [ "$summary" = true ] || printf 'PASS Codex skill ensured: %s\n' "$name"
        ensured=$((ensured + 1))
        continue
      fi
      if [ "$dry_run" = false ] && plugin_installed "$client" "$plugin"; then
        if [ "$update" = true ] && [ "$client" = claude ]; then
          run_plugin_command "$dry_run" claude plugin update "$plugin"
          run_plugin_command "$dry_run" claude plugin enable "$plugin"
          updated_count=$((updated_count + 1))
        elif [ "$update" = true ] && [ "$client" = codex ]; then
          run_plugin_command "$dry_run" codex plugin add "$plugin"
          updated_count=$((updated_count + 1))
        else
          [ "$summary" = true ] || printf 'PASS %s plugin already installed: %s\n' "$client" "$plugin"
          already_installed=$((already_installed + 1))
        fi
        continue
      fi
      if [ "$client" = claude ]; then
        [ -z "$marketplace" ] || run_plugin_command "$dry_run" claude plugin marketplace add "$marketplace"
        run_plugin_command "$dry_run" claude plugin install "$plugin" --scope user
      else
        if [ -n "$marketplace" ] && [ "$marketplace" != openai-curated-remote ]; then
          marketplace_name=${plugin##*@}
          ensure_codex_marketplace "$dry_run" "$marketplace" "$marketplace_name"
        fi
        run_plugin_command "$dry_run" codex plugin add "$plugin"
      fi
      [ "$summary" = true ] || printf 'PASS %s plugin ensured: %s\n' "$client" "$plugin"
      ensured=$((ensured + 1))
    done < "$manifest"
    if [ "$summary" = true ]; then
      printf 'PLUGINS %s: %s ensured, %s already installed, %s updated\n' "$client" "$ensured" "$already_installed" "$updated_count"
    fi
  done
}
