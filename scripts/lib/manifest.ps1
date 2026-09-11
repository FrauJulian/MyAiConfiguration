function Get-ManagedManifestPath {
    param([Parameter(Mandatory=$true)][string]$Destination)
    return (Join-Path $Destination '.ai-config-manifest.tsv')
}

function Get-Sha256Hash {
    param([Parameter(Mandatory=$true)][string]$Path)
    # Lowercase to match sha256sum's output, since the manifest must be readable by
    # both this module and its Bash equivalent regardless of which one wrote it.
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Sha256HashOfBytes {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha256.Dispose() }
}

function Read-ManagedManifest {
    param([Parameter(Mandatory=$true)][string]$ManifestPath)
    $entries = @{}
    if (Test-Path -LiteralPath $ManifestPath) {
        # Lowercase to tolerate an older manifest written before hashes were normalized.
        Import-Csv -LiteralPath $ManifestPath -Delimiter ([char]9) | ForEach-Object { $entries[$_.path] = $_.sha256.ToLowerInvariant() }
    }
    return $entries
}

function Write-ManagedManifest {
    param([Parameter(Mandatory=$true)][string]$ManifestPath, [Parameter(Mandatory=$true)][hashtable]$Entries)
    $lines = @("path`tsha256")
    foreach ($path in ($Entries.Keys | Sort-Object)) { $lines += "$path`t$($Entries[$path])" }
    New-Item (Split-Path $ManifestPath -Parent) -ItemType Directory -Force | Out-Null
    # Windows PowerShell 5.1's -Encoding UTF8 always prepends a BOM, which Bash's plain
    # `read` would otherwise fold into the first field of the header line. Write UTF-8
    # without BOM and with LF line endings so either implementation can read the file
    # regardless of which one wrote it.
    $content = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($ManifestPath, $content, (New-Object System.Text.UTF8Encoding($false)))
}

function Sync-ManagedDestination {
    <#
    .SYNOPSIS
        Installs one generated source tree into a destination directory, tracking
        every installed file in a manifest so a later run can detect files this
        setup previously managed that were since removed from the source (stale)
        or changed on disk by the user (locally modified), without ever touching
        a file it never installed.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$Stamp,
        [string]$AiConfigRoot,
        [string]$ShellCommand,
        [string]$WindowsShellCommand,
        [switch]$DryRun
    )
    Write-Output "SOURCE $Source -> $Destination"
    $manifestPath = Get-ManagedManifestPath $Destination
    $oldManifest = Read-ManagedManifest $manifestPath
    $newManifest = @{}
    $backupRoot = Join-Path $Destination "backups/$Stamp"

    Get-ChildItem $Source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
        $target = Join-Path $Destination $relative
        $rawContent = Get-Content -LiteralPath $_.FullName -Raw
        $needsSubstitution = $rawContent.Contains('__AI_CONFIG_ROOT__') -or $rawContent.Contains('__HOOK_COMMAND__') -or $rawContent.Contains('__WINDOWS_HOOK_COMMAND__')
        if ($needsSubstitution) {
            $finalContent = $rawContent.Replace('__AI_CONFIG_ROOT__', $AiConfigRoot).Replace('__HOOK_COMMAND__', $ShellCommand).Replace('__WINDOWS_HOOK_COMMAND__', $WindowsShellCommand).Replace('__HOOK_SCRIPT__', 'flashbang.ps1').Replace('__WINDOWS_HOOK_SCRIPT__', 'flashbang.ps1')
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($finalContent)
        } else {
            $newBytes = [System.IO.File]::ReadAllBytes($_.FullName)
        }
        $newHash = Get-Sha256HashOfBytes $newBytes
        $newManifest[$relative] = $newHash

        $exists = Test-Path -LiteralPath $target
        if ($exists -and (Get-Sha256Hash $target) -eq $newHash) { Write-Output "UNCHANGED $target"; return }

        $action = if ($exists) { 'UPDATE' } else { 'CREATE' }
        if ($DryRun) { Write-Output "DRYRUN $action $target"; return }
        if ($exists) {
            $wasManaged = $oldManifest.ContainsKey($relative)
            $backup = Join-Path $backupRoot $relative
            New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath $target $backup -Force
            Write-Output "BACKUP $target -> $backup"
            if (-not $wasManaged) { Write-Output "WARN $target existed before this installation but was not tracked by a previous run; it was backed up before being overwritten." }
        }
        New-Item (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        [System.IO.File]::WriteAllBytes($target, $newBytes)
        Write-Output "$action $target"
    }

    foreach ($relative in @($oldManifest.Keys | Where-Object { -not $newManifest.ContainsKey($_) })) {
        $target = Join-Path $Destination $relative
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($DryRun) { Write-Output "DRYRUN REMOVE $target"; continue }
        $backup = Join-Path $backupRoot $relative
        New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $target $backup -Force
        Write-Output "BACKUP $target -> $backup"
        if ((Get-Sha256Hash $target) -eq $oldManifest[$relative]) {
            Remove-Item -LiteralPath $target -Force
            Write-Output "REMOVE $target"
        } else {
            Write-Output "WARN $target was managed by a previous installation and has changed locally; it was backed up but left in place instead of being removed."
        }
    }

    if (-not $DryRun) { Write-ManagedManifest $manifestPath $newManifest }
}
