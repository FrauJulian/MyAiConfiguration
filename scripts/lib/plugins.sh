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
    printf 'DRYRUN %s\n' "$*"
  else
    "$@"
  fi
}

ensure_codex_marketplace() {
  local dry_run=$1 source=$2 marketplace_name=$3 output
  if [ "$dry_run" = true ]; then
    printf 'DRYRUN codex plugin marketplace add %s\n' "$source"
    return 0
  fi
  if output=$(codex plugin marketplace add "$source" 2>&1); then
    [ -z "$output" ] || printf '%s\n' "$output"
    return 0
  fi
  printf '%s\n' "$output" >&2
  if printf '%s\n' "$output" | grep -Eiq 'marketplace .* already added from a different source'; then
    printf "WARN Codex marketplace '%s' exists from another source; replacing it with: %s\n" "$marketplace_name" "$source"
    codex plugin marketplace remove "$marketplace_name"
    codex plugin marketplace add "$source"
    return 0
  fi
  return 1
}

install_configured_plugins() {
  local root=$1 client_selection=$2 dry_run=$3 update=$4
  local manifest="$root/adapters/plugins.tsv"
  [ -f "$manifest" ] || { printf 'Plugin manifest is missing: %s\n' "$manifest" >&2; return 1; }

  local clients=()
  case "$client_selection" in
    codex) clients=(codex);;
    claude) clients=(claude);;
    both) clients=(claude codex);;
    *) printf 'Unknown plugin client selection: %s\n' "$client_selection" >&2; return 1;;
  esac

  local client name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill marketplace plugin
  while IFS=$'\t' read -r name claude_marketplace claude_plugin codex_marketplace codex_plugin codex_method codex_source codex_skill; do
    [ "$name" = name ] && continue
    [ -n "$name" ] || continue
    [ "$claude_marketplace" = - ] && claude_marketplace=
    [ "$codex_marketplace" = - ] && codex_marketplace=
    for client in "${clients[@]}"; do
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
        printf 'PASS Codex skill ensured: %s\n' "$name"
        continue
      fi
      if [ "$dry_run" = false ] && plugin_installed "$client" "$plugin"; then
        if [ "$update" = true ] && [ "$client" = claude ]; then
          run_plugin_command "$dry_run" claude plugin update "$plugin"
          run_plugin_command "$dry_run" claude plugin enable "$plugin"
        elif [ "$update" = true ] && [ "$client" = codex ]; then
          run_plugin_command "$dry_run" codex plugin add "$plugin"
        else
          printf 'PASS %s plugin already installed: %s\n' "$client" "$plugin"
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
      printf 'PASS %s plugin ensured: %s\n' "$client" "$plugin"
    done
  done < "$manifest"
}
