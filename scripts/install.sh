#!/usr/bin/env bash
set -euo pipefail

dry_run=false
client=""
platform=""
update_plugins=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --update-plugins) update_plugins=true; shift ;;
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --platform) platform=${2:?--platform requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/plugins.sh"
. "$root/scripts/lib/manifest.sh"
bash "$root/scripts/build.sh"
generated="$root/generated"
[ -d "$generated" ] || { printf 'Generated output is missing after a successful build.\n' >&2; exit 1; }

if [ -z "$platform" ]; then
  printf 'Select target platform:\n1) Windows\n2) Linux\n'
  while :; do
    read -r -p 'Selection [1-2] ' platform_selection
    case "$platform_selection" in 1) platform=windows; break;; 2) platform=linux; break;; esac
  done
else
  case "$platform" in
    windows|Windows) platform=windows ;;
    linux|Linux) platform=linux ;;
    *) printf 'Unknown --platform value: %s (expected windows or linux)\n' "$platform" >&2; exit 1 ;;
  esac
fi

if [ -z "$client" ]; then
  printf 'Select installation target:\n1) Codex\n2) Claude\n3) Both\n'
  while :; do
    read -r -p 'Selection [1-3] ' selection
    case "$selection" in 1) client=codex; break;; 2) client=claude; break;; 3) client=both; break;; esac
  done
else
  case "$client" in
    codex|Codex) client=codex ;;
    claude|Claude) client=claude ;;
    both|Both) client=both ;;
    *) printf 'Unknown --client value: %s (expected codex, claude, or both)\n' "$client" >&2; exit 1 ;;
  esac
fi

stamp=$(date +%Y%m%d-%H%M%S)
home_path=${HOME:?HOME is required}
shell_command=bash
windows_shell_command='powershell -NoProfile -ExecutionPolicy Bypass -File'

targets=()
case "$client" in
  codex|both) targets+=("$generated/codex-$platform|$home_path/.codex" "$generated/codex-$platform/skills|$home_path/.agents/skills");;
esac
case "$client" in
  claude|both) targets+=("$generated/claude-$platform|$home_path/.claude");;
esac

for target_pair in "${targets[@]}"; do
  source=${target_pair%%|*}
  destination=${target_pair#*|}
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$windows_shell_command" "$dry_run"
done

install_configured_plugins "$root" "$client" "$dry_run" "$update_plugins"

if "$dry_run"; then printf 'PASS install dry-run\n'; else printf 'PASS install\n'; fi
