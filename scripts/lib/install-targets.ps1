function Read-InstallPlatform {
    param([string]$Platform)
    if ($Platform) { return $Platform }
    Write-Host 'Select target platform:'
    Write-Host '1) Windows'
    Write-Host '2) Linux'
    do { $selection = Read-Host 'Selection [1-2]' } while ($selection -notin @('1','2'))
    return @{'1'='Windows'; '2'='Linux'}[$selection]
}

function Read-InstallClient {
    param([string]$Client)
    if ($Client) { return $Client }
    Write-Host 'Select installation target:'
    Write-Host '1) Codex'
    Write-Host '2) Claude'
    Write-Host '3) Both'
    do { $selection = Read-Host 'Selection [1-3]' } while ($selection -notin @('1','2','3'))
    return @{'1'='Codex'; '2'='Claude'; '3'='Both'}[$selection]
}

function Get-InstallDestinations {
    param(
        [Parameter(Mandatory=$true)][string]$HomePath,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client
    )
    $destinations = @()
    if ($Client -in @('Codex','Both')) { $destinations += Join-Path $HomePath '.codex' }
    if ($Client -in @('Claude','Both')) { $destinations += Join-Path $HomePath '.claude' }
    return $destinations
}

function Get-InstallTargets {
    param(
        [Parameter(Mandatory=$true)][string]$Generated,
        [Parameter(Mandatory=$true)][string]$HomePath,
        [Parameter(Mandatory=$true)][string]$Platform,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client
    )
    $targets = @()
    if ($Client -in @('Codex','Both')) {
        $targets += @{ Source=(Join-Path $Generated "codex-$Platform"); Destination=(Join-Path $HomePath '.codex') }
        $targets += @{ Source=(Join-Path $Generated "codex-$Platform/skills"); Destination=(Join-Path $HomePath '.agents/skills') }
    }
    if ($Client -in @('Claude','Both')) {
        $targets += @{ Source=(Join-Path $Generated "claude-$Platform"); Destination=(Join-Path $HomePath '.claude') }
    }
    return $targets
}

function Test-AnyManifestPresent {
    param([Parameter(Mandatory=$true)][string[]]$Destinations)
    return [bool](@($Destinations | Where-Object { Test-Path (Get-ManagedManifestPath $_) }).Count)
}

function Test-AllManifestsPresent {
    param([Parameter(Mandatory=$true)][string[]]$Destinations)
    return [bool](@($Destinations | Where-Object { -not (Test-Path (Get-ManagedManifestPath $_)) }).Count -eq 0)
}
