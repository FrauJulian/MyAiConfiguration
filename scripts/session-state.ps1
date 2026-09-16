[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path,
    [AllowEmptyString()][string]$Goal,
    [AllowEmptyCollection()][string[]]$Decisions,
    [AllowEmptyCollection()][string[]]$ChangedFiles,
    [AllowEmptyCollection()][string[]]$Verified,
    [AllowEmptyCollection()][string[]]$Pending,
    [AllowEmptyCollection()][string[]]$Risks,
    [AllowEmptyCollection()][string[]]$ImportantFindings,
    [switch]$Pointer,
    [switch]$Reset
)
$ErrorActionPreference = 'Stop'
$helper = Join-Path (Split-Path $PSScriptRoot -Parent) 'shared/hooks/scripts/session-state.py'
$values = @{ workspace = $Workspace }
$fields = @{ Goal = 'goal'; Decisions = 'decisions'; ChangedFiles = 'changed'; Verified = 'verified'; Pending = 'open'; Risks = 'risks' }
foreach ($parameter in $fields.Keys) {
    if ($PSBoundParameters.ContainsKey($parameter)) { $values[$fields[$parameter]] = $PSBoundParameters[$parameter] }
}
if ($PSBoundParameters.ContainsKey('ImportantFindings') -and -not $PSBoundParameters.ContainsKey('Decisions')) {
    $values.decisions = $ImportantFindings
}
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$arguments = @($helper, '--update-json')
if ($Pointer) { $arguments += '--pointer' }
if ($Reset) { $arguments += '--reset' }
$payload = $values | ConvertTo-Json -Depth 4 -Compress
$payload = [regex]::Replace($payload, '[^\x00-\x7F]', { param($match) '\u{0:x4}' -f [int][char]$match.Value })
$payload | & python @arguments
exit $LASTEXITCODE
