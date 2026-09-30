#!/usr/bin/env bash
set -euo pipefail

client=
key=
while [ $# -gt 0 ]; do
  case "$1" in
    --client) client=${2:?--client requires a value}; shift 2 ;;
    --key) key=${2:?--key requires a value}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -n "$client" ] || read -r -p 'Select client (codex, claude, or both) ' client
[ -n "$key" ] || read -r -p 'Credential key to remove ' key
case "$client" in codex|Codex|claude|Claude|both|Both) ;; *) printf 'Unknown --client value: %s\n' "$client" >&2; exit 1 ;; esac
[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]{0,127}$ ]] || { printf 'Credential key must be an environment-variable-compatible name.\n' >&2; exit 1; }

powershell_command=$(command -v powershell.exe || command -v powershell || command -v pwsh || true)
[ -n "$powershell_command" ] || { printf 'PowerShell is required to remove credentials from the Windows credential store.\n' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$powershell_command" -NoProfile -ExecutionPolicy Bypass -File "$script_dir/remove-credentials.ps1" -Client "$client" -Key "$key"
