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

[ -n "$client" ] || read -r -p 'Select client (codex, claude, or both) ' client
[ -n "$instruction" ] || read -r -p 'Instruction to remove ' instruction
case "$client" in codex|Codex|claude|Claude|both|Both) ;; *) printf 'Unknown --client value: %s\n' "$client" >&2; exit 1 ;; esac
case "$home_path" in /*|[A-Za-z]:[\\/]*) ;; *) printf 'Home path must be absolute.\n' >&2; exit 1 ;; esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python_command=$(command -v python || command -v python3 || true)
[ -n "$python_command" ] || { printf 'Python is required to remove instructions.\n' >&2; exit 1; }
"$python_command" "$script_dir/../lib/remove-instruction.py" --client "${client,,}" --instruction "$instruction" --home "$home_path"
