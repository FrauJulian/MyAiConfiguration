#!/usr/bin/env bash
set -euo pipefail

client=${1:?client is required}
key=${2:?credential key is required}
shift 2
[ $# -gt 0 ] || { printf 'Child command is required.\n' >&2; exit 1; }

case "$client" in codex|Codex) client=Codex ;; claude|Claude) client=Claude ;; *) printf 'Unknown client: %s\n' "$client" >&2; exit 1 ;; esac
case "$key" in [A-Za-z_][A-Za-z0-9_]* ) ;; *) printf 'Credential key must be an environment-variable-compatible name.\n' >&2; exit 1 ;; esac

powershell_command=$(command -v powershell.exe || command -v powershell || command -v pwsh || true)
[ -n "$powershell_command" ] || { printf 'PowerShell is required to read the Windows credential store.\n' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$powershell_command" -NoProfile -ExecutionPolicy Bypass -File "$script_dir/with-credential.ps1" -Client "$client" -Key "$key" -FilePath "$1" "${@:2}"
