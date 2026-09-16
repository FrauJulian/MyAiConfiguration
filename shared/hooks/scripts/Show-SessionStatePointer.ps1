[CmdletBinding()]
param()
& python (Join-Path $PSScriptRoot 'session-state.py') --hook
exit $LASTEXITCODE
