#!/usr/bin/env bash
set -euo pipefail

dry_run=false
client=""
force=false
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --force) force=true; shift ;;
    --summary) summary=true; shift ;;
    --client) client=${2:?--client requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/plugins.sh"
. "$root/scripts/lib/manifest.sh"
. "$root/scripts/lib/install-targets.sh"
. "$root/scripts/lib/semantic-retrieval.sh"

client=$(read_install_client "$client")
home_path=${HOME:?HOME is required}
generated="$root/generated"

mapfile -t targets < <(get_install_targets "$generated" "$home_path" bash "$client")
installed_count=0
for target_pair in "${targets[@]}"; do
  [ -f "$(manifest_path "${target_pair#*|}")" ] && installed_count=$((installed_count + 1))
done
if [ "$dry_run" = false ] && [ "$installed_count" -eq 0 ]; then
  printf 'Not installed, nothing to uninstall.\n' >&2
  exit 1
fi

if [ "$dry_run" = false ] && [ "$force" = false ]; then
  if [ ! -t 0 ] || [ "${CI:-}" = true ] || [ "${AI_CONFIG_NO_INTERACTIVE:-}" = 1 ]; then
    printf 'Refusing to uninstall without confirmation in a non-interactive session. Pass --force to proceed.\n' >&2
    exit 1
  fi
  printf 'This removes the managed configuration, extensions, and semantic retrieval setup for %s under %s.\n' "$client" "$home_path"
  printf 'Backups already on disk are kept; anything this setup never installed is left untouched.\n'
  read -r -p "Type 'yes' to continue: " confirm || confirm=""
  if [ "$confirm" != yes ]; then
    printf 'Cancelled, nothing was removed.\n'
    exit 1
  fi
fi

stamp=$(date +%Y%m%d-%H%M%S)
empty_source=$(mktemp -d)
cleanup() { rm -rf -- "$empty_source"; }
trap cleanup EXIT

for target_pair in "${targets[@]}"; do
  destination=${target_pair#*|}
  if [ ! -f "$(manifest_path "$destination")" ]; then
    [ "$summary" = true ] || printf 'SKIP %s (not installed)\n' "$destination"
    continue
  fi
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$empty_source" "$destination" "$stamp" "$ai_config_root" '' '' "$dry_run" "$summary"
  if [ "$dry_run" = false ]; then
    rm -f -- "$(manifest_path "$destination")"
    [ -n "$(find "$destination" -mindepth 1 -maxdepth 1 2>/dev/null)" ] || rmdir -- "$destination" 2>/dev/null || true
  fi
done

selected_plugins=()
sync_configured_plugins "$root" "$client" "$home_path" "$dry_run" false selected_plugins "$summary"
sync_semantic_retrieval "$root" "$client" "$home_path" false "$dry_run" false "$summary"

if [ "$dry_run" = false ]; then
  remaining=0
  for target_pair in "${targets[@]}"; do
    [ -f "$(manifest_path "${target_pair#*|}")" ] && remaining=$((remaining + 1))
  done
  if [ "$remaining" -eq 0 ]; then
    config_root="$home_path/.my-ai-configuration"
    rm -f -- "$config_root/selection.json"
    [ -n "$(find "$config_root" -mindepth 1 -maxdepth 1 2>/dev/null)" ] || rmdir -- "$config_root" 2>/dev/null || true
  fi
fi

if [ "$summary" = true ]; then
  suffix=
  [ "$dry_run" = false ] || suffix=', dry-run'
  printf 'Uninstall: PASS | %s%s\n' "$client" "$suffix"
elif "$dry_run"; then printf 'PASS uninstall dry-run\n'; else printf 'PASS uninstall\n'; fi
