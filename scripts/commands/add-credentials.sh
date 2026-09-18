#!/usr/bin/env bash
set -euo pipefail

client=
key=
home_path=${HOME:?HOME is required}
while [ $# -gt 0 ]; do
  case "$1" in
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --key) key=${2:?--key requires a value}; shift 2 ;;
    --home) home_path=${2:?--home requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -n "$client" ] || read -r -p 'Select client (codex, claude, or both) ' client
[ -n "$key" ] || read -r -p 'Credential key ' key
case "$client" in codex|Codex|claude|Claude|both|Both) ;; *) printf 'Unknown --client value: %s\n' "$client" >&2; exit 1 ;; esac
case "$key" in [A-Za-z_][A-Za-z0-9_]* ) ;; *) printf 'Credential key must be an environment-variable-compatible name.\n' >&2; exit 1 ;; esac
case "$home_path" in /*|[A-Za-z]:[\\/]*) ;; *) printf 'Home path must be absolute.\n' >&2; exit 1 ;; esac

IFS= read -r -s -p 'Credential value ' value
printf '\n'
powershell_command=$(command -v powershell.exe || command -v powershell || command -v pwsh || true)
[ -n "$powershell_command" ] || { printf 'PowerShell is required to store credentials in the Windows credential store.\n' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
printf '%s' "$value" | "$powershell_command" -NoProfile -ExecutionPolicy Bypass -File "$script_dir/add-credentials.ps1" -Client "$client" -Key "$key" -ValueFromStdin -HomePath "$home_path"
unset value
