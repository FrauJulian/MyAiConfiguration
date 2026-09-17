#!/usr/bin/env bash
set -euo pipefail

dry_run=false
client=""
shell=""
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --summary) summary=true; shift ;;
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --shell) shell=${2:?--shell requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/plugins.sh"
. "$root/scripts/lib/manifest.sh"
. "$root/scripts/lib/install-targets.sh"
. "$root/scripts/lib/selection-state.sh"
. "$root/scripts/lib/install-options.sh"
. "$root/scripts/lib/semantic-retrieval.sh"

shell=$(read_install_shell "$shell")
client=$(read_install_client "$client")

home_path=${HOME:?HOME is required}
if [ "$dry_run" = false ]; then
  mapfile -t destinations < <(get_install_destinations "$home_path" "$client")
  if any_manifest_present "${destinations[@]}"; then
    printf 'Already installed, use the update script.\n' >&2
    exit 1
  fi
fi

read_install_options

build_args=()
[ "$summary" = false ] || build_args+=(--summary)
bash "$root/scripts/build.sh" "${build_args[@]}"
generated="$root/generated"
[ -d "$generated" ] || { printf 'Generated output is missing after a successful build.\n' >&2; exit 1; }

stamp=$(date +%Y%m%d-%H%M%S)
powershell_command='pwsh -NoProfile -ExecutionPolicy Bypass -File'
if command -v powershell >/dev/null; then powershell_command='powershell -NoProfile -ExecutionPolicy Bypass -File'; fi
shell_command=bash
[ "$shell" != powershell ] || shell_command=$powershell_command

selected_plugins=()
deselected_plugins=()
select_configured_plugins "$root" "$client" Install "$dry_run" selected_plugins deselected_plugins
[ "$update_agents" = false ] || update_selected_agent_clis

while IFS='|' read -r source destination; do
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$powershell_command" "$dry_run" "$summary" "$flashbang"
done < <(get_install_targets "$generated" "$home_path" "$shell" "$client")

sync_configured_plugins "$root" "$client" "$home_path" "$dry_run" false selected_plugins "$summary"
sync_semantic_retrieval "$root" "$client" "$home_path" "$semantic_retrieval" "$dry_run" false
if [ "$dry_run" = false ]; then save_update_selection; fi

if [ "$summary" = true ]; then
  suffix=
  [ "$dry_run" = false ] || suffix=', dry-run'
  printf 'Install: PASS | %s, %s%s\n' "$client" "$shell" "$suffix"
elif "$dry_run"; then printf 'PASS install dry-run\n'; else printf 'PASS install\n'; fi
