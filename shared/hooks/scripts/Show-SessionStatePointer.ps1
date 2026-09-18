[CmdletBinding()]
param()
try {
    $ErrorActionPreference = 'Stop'
    & python (Join-Path $PSScriptRoot 'session-state.py') --hook 2>$null
} catch {}
exit 0
