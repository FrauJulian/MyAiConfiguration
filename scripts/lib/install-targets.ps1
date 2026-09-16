function Read-InstallPlatform {
    param([string]$Platform)
    if ($Platform) { return $Platform }
    return Read-InteractiveSingle -Title 'Select shell' -Names @('PowerShell','Bash') -Values @('Windows','Linux')
}
function Read-InstallClient {
    param([string]$Client)
    if ($Client) { return $Client }
    return Read-InteractiveSingle -Title 'Select client' -Names @('Codex','Claude','Both') -Values @('Codex','Claude','Both')
}
function Clear-InteractiveScreen { if (-not [Console]::IsInputRedirected -and $env:CI -ne 'true' -and $env:AI_CONFIG_NO_INTERACTIVE -ne '1') { Clear-Host } }
function Read-InteractiveSingle {
    param([string]$Title,[string[]]$Names,[string[]]$Values)
    if ([Console]::IsInputRedirected -or $env:CI -eq 'true' -or $env:AI_CONFIG_NO_INTERACTIVE -eq '1') {
        Write-Host $Title; for($i=0;$i -lt $Names.Count;$i++){ Write-Host ('{0}) {1}' -f ($i+1),$Names[$i]) }
        do { $answer=Read-Host 'Selection' } while($answer -notmatch ('^[1-{0}]$' -f $Names.Count)); return $Values[[int]$answer-1]
    }
    $index=0
    while($true) {
        Clear-InteractiveScreen; Write-Host $Title
        for($i=0;$i -lt $Names.Count;$i++){ $prefix=if($i -eq $index){'>'}else{' '}; if($i -eq $index -and $env:NO_COLOR -ne '1'){Write-Host ('{0} {1}' -f $prefix,$Names[$i]) -ForegroundColor Cyan}else{Write-Host ('{0} {1}' -f $prefix,$Names[$i])} }
        Write-Host 'Up/Down Navigate   Enter Confirm'; $key=[Console]::ReadKey($true)
        if($key.Key -eq 'Up'){ $index=($index+$Names.Count-1)%$Names.Count } elseif($key.Key -eq 'Down'){ $index=($index+1)%$Names.Count } elseif($key.Key -eq 'Enter'){ Clear-InteractiveScreen; return $Values[$index] }
    }
}
function Get-InstallDestinations {
    param([Parameter(Mandatory=$true)][string]$HomePath,[ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client)
    $destinations=@(); if($Client -in @('Codex','Both')){$destinations+=Join-Path $HomePath '.codex'}; if($Client -in @('Claude','Both')){$destinations+=Join-Path $HomePath '.claude'}; return $destinations
}
function Get-InstallTargets {
    param([Parameter(Mandatory=$true)][string]$Generated,[Parameter(Mandatory=$true)][string]$HomePath,[Parameter(Mandatory=$true)][string]$Platform,[ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client)
    $targets=@(); if($Client -in @('Codex','Both')){$targets+=@{Source=(Join-Path $Generated "codex-$Platform");Destination=(Join-Path $HomePath '.codex')};$targets+=@{Source=(Join-Path $Generated "codex-$Platform/skills");Destination=(Join-Path $HomePath '.agents/skills')}}; if($Client -in @('Claude','Both')){$targets+=@{Source=(Join-Path $Generated "claude-$Platform");Destination=(Join-Path $HomePath '.claude')};}; return $targets
}
function Test-AnyManifestPresent { param([Parameter(Mandatory=$true)][string[]]$Destinations); return [bool](@($Destinations|Where-Object{Test-Path(Get-ManagedManifestPath $_)}).Count) }
function Test-AllManifestsPresent { param([Parameter(Mandatory=$true)][string[]]$Destinations); return [bool](@($Destinations|Where-Object{-not(Test-Path(Get-ManagedManifestPath $_))}).Count -eq 0) }
