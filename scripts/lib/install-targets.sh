#!/usr/bin/env bash

read_install_platform() {
  local platform=$1
  if [ -n "$platform" ]; then
    case "$platform" in
      windows|Windows) printf 'windows\n'; return 0 ;;
      linux|Linux) printf 'linux\n'; return 0 ;;
      *) printf 'Unknown --platform value: %s (expected windows or linux)\n' "$platform" >&2; return 1 ;;
    esac
  fi
  read_single_selection 'Select shell' 'PowerShell' 'windows' 'Bash' 'linux'
}

read_install_client() {
  local client=$1
  if [ -n "$client" ]; then
    case "$client" in
      codex|Codex) printf 'codex\n'; return 0 ;;
      claude|Claude) printf 'claude\n'; return 0 ;;
      both|Both) printf 'both\n'; return 0 ;;
      *) printf 'Unknown --client value: %s (expected codex, claude, or both)\n' "$client" >&2; return 1 ;;
    esac
  fi
  read_single_selection 'Select client' 'Codex' 'codex' 'Claude' 'claude' 'Both' 'both'
}

clear_interactive() { [ -t 0 ] && [ "${CI:-}" != true ] && [ "${AI_CONFIG_NO_INTERACTIVE:-}" != 1 ] && printf '\033[2J\033[H'; }
read_single_selection() {
  local title=$1; shift; local labels=() values=() label value index=0 key
  while [ $# -gt 0 ]; do labels+=("$1"); values+=("$2"); shift 2; done
  if [ ! -t 0 ] || [ "${CI:-}" = true ] || [ "${AI_CONFIG_NO_INTERACTIVE:-}" = 1 ]; then printf '%s\n' "$title" >&2; for ((index=0;index<${#labels[@]};index++)); do printf '%d) %s\n' "$((index+1))" "${labels[$index]}" >&2; done; while read -r -p 'Selection ' value; do [[ "$value" =~ ^[1-9][0-9]*$ ]] && [ "$value" -le "${#labels[@]}" ] && { printf '%s\n' "${values[$((value-1))]}"; return; }; done; return 1; fi
  local selected=0; while :; do clear_interactive; printf '%s\n' "$title"; for ((index=0;index<${#labels[@]};index++)); do [ "$index" -eq "$selected" ] && printf '> %s\n' "${labels[$index]}" || printf '  %s\n' "${labels[$index]}"; done; printf '↑/↓ Navigate   Enter Confirm\n'; IFS= read -rsn1 key || return 1; case "$key" in $'\x1b') read -rsn2 key; case "$key" in '[A') selected=$(( (selected+${#labels[@]}-1)%${#labels[@]} ));; '[B') selected=$(( (selected+1)%${#labels[@]} ));; esac;; '') clear_interactive; printf '%s\n' "${values[$selected]}"; return;; esac; done
}

# get_install_destinations <home> <client> -- prints one destination per line
get_install_destinations() {
  local home_path=$1 client=$2
  case "$client" in codex|both) printf '%s/.codex\n' "$home_path" ;; esac
  case "$client" in claude|both) printf '%s/.claude\n' "$home_path" ;; esac
}

# get_install_targets <generated> <home> <platform> <client> -- prints "source|dest" per line
get_install_targets() {
  local generated=$1 home_path=$2 platform=$3 client=$4
  case "$client" in
    codex|both)
      printf '%s/codex-%s|%s/.codex\n' "$generated" "$platform" "$home_path"
      printf '%s/codex-%s/skills|%s/.agents/skills\n' "$generated" "$platform" "$home_path"
      ;;
  esac
  case "$client" in claude|both) printf '%s/claude-%s|%s/.claude\n' "$generated" "$platform" "$home_path" ;; esac
}

# any_manifest_present <destination>... -- true (0) if at least one has a manifest
any_manifest_present() {
  local destination
  for destination in "$@"; do
    [ -f "$(manifest_path "$destination")" ] && return 0
  done
  return 1
}

# all_manifests_present <destination>... -- true (0) only if every destination has a manifest
all_manifests_present() {
  local destination
  for destination in "$@"; do
    [ -f "$(manifest_path "$destination")" ] || return 1
  done
  return 0
}
