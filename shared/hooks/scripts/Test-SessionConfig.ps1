param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent))
$required = @('shared','adapters','scripts','docs','AGENTS.md')
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepositoryRoot $_)) })
if ($missing.Count) { Write-Error ('Missing repository inputs: ' + ($missing -join ', ')); exit 1 }
Write-Output 'PASS session configuration'
