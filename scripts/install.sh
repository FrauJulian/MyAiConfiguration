#!/usr/bin/env bash
set -euo pipefail

dry_run=false
for argument in "$@"; do
  [ "$argument" != "--dry-run" ] || dry_run=true
done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/plugins.sh"
bash "$root/scripts/build.sh"
generated="$root/generated"
[ -d "$generated" ] || { printf 'Generated output is missing after a successful build.\n' >&2; exit 1; }

printf 'Select target platform:\n1) Windows\n2) Linux\n'
while :; do
  read -r -p 'Selection [1-2] ' platform_selection
  case "$platform_selection" in 1) platform=windows; break;; 2) platform=linux; break;; esac
done
printf 'Select installation target:\n1) Codex\n2) Claude\n3) Both\n'
while :; do
  read -r -p 'Selection [1-3] ' selection
  case "$selection" in 1|2|3) break;; esac
done

stamp=$(date +%Y%m%d-%H%M%S)
home_path=${HOME:?HOME is required}
targets=()
case "$selection" in
  1|3) targets+=("$generated/codex-$platform|$home_path/.codex" "$generated/codex-$platform/skills|$home_path/.agents/skills");;
esac
case "$selection" in
  2|3) targets+=("$generated/claude-$platform|$home_path/.claude");;
esac

for target_pair in "${targets[@]}"; do
  source=${target_pair%%|*}
  destination=${target_pair#*|}
  while IFS= read -r -d '' source_file; do
    relative=${source_file#"$source/"}
    target="$destination/$relative"
    if "$dry_run"; then printf 'DRYRUN %s -> %s\n' "$source_file" "$target"; continue; fi
    if [ -f "$target" ]; then
      backup="$destination/backups/$relative.$stamp"
      mkdir -p "$(dirname -- "$backup")"
      cp "$target" "$backup"
    fi
    mkdir -p "$(dirname -- "$target")"
    content=$(<"$source_file")
    if [[ "$content" == *'__AI_CONFIG_ROOT__'* || "$content" == *'__HOOK_COMMAND__'* || "$content" == *'__WINDOWS_HOOK_COMMAND__'* ]]; then
      replacement=$destination
      if command -v cygpath >/dev/null; then replacement=$(cygpath -m "$destination"); fi
      content=${content//__AI_CONFIG_ROOT__/$replacement}
      content=${content//__HOOK_COMMAND__/bash}
      content=${content//__WINDOWS_HOOK_COMMAND__/bash}
      content=${content//__HOOK_SCRIPT__/flashbang.sh}
      content=${content//__WINDOWS_HOOK_SCRIPT__/flashbang.sh}
      printf '%s' "$content" > "$target"
    else
      cp "$source_file" "$target"
    fi
    printf 'INSTALL %s\n' "$target"
  done < <(find "$source" -type f -print0)
done

client_selection=both
case "$selection" in
  1) client_selection=codex;;
  2) client_selection=claude;;
esac
install_configured_plugins "$root" "$client_selection" "$dry_run" true

if "$dry_run"; then printf 'PASS install dry-run\n'; else printf 'PASS install\n'; fi
