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
  printf 'Select target platform:\n1) Windows\n2) Linux\n' >&2
  local selection
  while :; do
    read -r -p 'Selection [1-2] ' selection
    case "$selection" in 1) printf 'windows\n'; return 0 ;; 2) printf 'linux\n'; return 0 ;; esac
  done
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
  printf 'Select installation target:\n1) Codex\n2) Claude\n3) Both\n' >&2
  local selection
  while :; do
    read -r -p 'Selection [1-3] ' selection
    case "$selection" in 1) printf 'codex\n'; return 0 ;; 2) printf 'claude\n'; return 0 ;; 3) printf 'both\n'; return 0 ;; esac
  done
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
