[CmdletBinding()]
param()
try {
    $ErrorActionPreference = 'Stop'
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $stateDir = Join-Path $root '.ai-session'
    if ($env:AI_CONFIG_TELEMETRY -ne '0') {
        New-Item $stateDir -ItemType Directory -Force | Out-Null
        $path = Join-Path $stateDir 'telemetry.jsonl'
        ('{"event":"compact","timestamp":"' + (Get-Date).ToUniversalTime().ToString('o') + '"}') | Add-Content $path
        if ((Get-Item $path).Length -gt 1048576) { Move-Item $path ($path + '.1') -Force }
    }
    & python (Join-Path $PSScriptRoot 'session-state.py') --hook 2>$null
} catch {}
exit 0
