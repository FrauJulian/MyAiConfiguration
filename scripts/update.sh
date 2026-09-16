#!/usr/bin/env bash
set -euo pipefail

dry_run=false
client=""
platform=""
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --summary) summary=true; shift ;;
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --platform) platform=${2:?--platform requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/plugins.sh"
. "$root/scripts/lib/manifest.sh"
. "$root/scripts/lib/install-targets.sh"

platform=$(read_install_platform "$platform")
client=$(read_install_client "$client")

home_path=${HOME:?HOME is required}
if [ "$dry_run" = false ]; then
  mapfile -t destinations < <(get_install_destinations "$home_path" "$client")
  if ! all_manifests_present "${destinations[@]}"; then
    printf 'Not installed, use the install script.\n' >&2
    exit 1
  fi
fi

bash "$root/scripts/build.sh"
generated="$root/generated"
[ -d "$generated" ] || { printf 'Generated output is missing after a successful build.\n' >&2; exit 1; }

stamp=$(date +%Y%m%d-%H%M%S)
shell_command=bash
windows_shell_command='powershell -NoProfile -ExecutionPolicy Bypass -File'

while IFS='|' read -r source destination; do
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$windows_shell_command" "$dry_run" "$summary"
done < <(get_install_targets "$generated" "$home_path" "$platform" "$client")

selected_plugins=()
deselected_plugins=()
select_configured_plugins "$root" "$client" Update "$dry_run" selected_plugins deselected_plugins
install_configured_plugins "$root" "$client" "$dry_run" true selected_plugins "$summary"
uninstall_deselected_plugins "$root" "$client" "$dry_run" deselected_plugins "$summary"

if "$dry_run"; then printf 'PASS update dry-run\n'; else printf 'PASS update\n'; fi
