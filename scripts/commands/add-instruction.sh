#!/usr/bin/env bash
set -euo pipefail

client=
instruction=
home_path=${HOME:?HOME is required}
while [ $# -gt 0 ]; do
  case "$1" in
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --instruction) instruction=${2:?--instruction requires a value}; shift 2 ;;
    --home) home_path=${2:?--home requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

case "$client" in
  codex|Codex) targets=(codex) ;;
  claude|Claude) targets=(claude) ;;
  both|Both) targets=(codex claude) ;;
  '')
    read -r -p 'Select client (codex, claude, or both) ' client
    case "$client" in
      codex|Codex) targets=(codex) ;;
      claude|Claude) targets=(claude) ;;
      both|Both) targets=(codex claude) ;;
      *) printf 'Unknown --client value: %s\n' "$client" >&2; exit 1 ;;
    esac
    ;;
  *) printf 'Unknown --client value: %s\n' "$client" >&2; exit 1 ;;
esac
if [ -z "$instruction" ]; then read -r -p 'Instruction ' instruction; fi
if [ -z "${instruction//[[:space:]]/}" ] || [ ${#instruction} -gt 65536 ]; then printf 'Instruction must contain between 1 and 65536 characters.\n' >&2; exit 1; fi
case "$home_path" in /*|[A-Za-z]:[\\/]*) ;; *) printf 'Home path must be absolute.\n' >&2; exit 1 ;; esac

directory="$home_path/.my-ai-configuration/instructions"
mkdir -p -- "$directory"
for target in "${targets[@]}"; do
  path="$directory/$target.md"
  [ ! -s "$path" ] || [ "$(tail -c 1 -- "$path" | wc -l)" -eq 1 ] || printf '\n' >> "$path"
  printf '%s\n' "$instruction" >> "$path"
  printf 'Instruction added for %s.\n' "$target"
done
