function Get-ManagedManifestPath {
    param([Parameter(Mandatory=$true)][string]$Destination)
    return (Join-Path $Destination '.ai-config-manifest.tsv')
}

function Get-ManagedBackupRoot {
    param([Parameter(Mandatory=$true)][string]$Destination)
    if ((Split-Path $Destination -Leaf) -eq 'skills' -and (Split-Path (Split-Path $Destination -Parent) -Leaf) -eq '.agents') {
        return (Resolve-ManagedPath -Destination (Split-Path $Destination -Parent) -Relative '.ai-config-skill-backups')
    }
    return (Resolve-ManagedPath -Destination $Destination -Relative 'backups')
}

function Resolve-ManagedPath {
    param([Parameter(Mandatory=$true)][string]$Destination, [Parameter(Mandatory=$true)][string]$Relative)
    $parts = $Relative -split '/', 0, 'SimpleMatch'
    if ($Relative.StartsWith('/') -or $Relative.Contains('\') -or $Relative.Contains(':') -or $Relative.Contains("`t") -or $Relative.Contains("`r") -or $Relative.Contains("`n") -or @($parts | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        throw "Invalid managed path: $Relative"
    }
    $target = $Destination
    foreach ($part in $parts) { $target = Join-Path $target $part }
    $probe = $target
    while ($true) {
        $item = Get-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Managed path contains a link: $probe" }
        if ($probe -eq $Destination) { break }
        $probe = Split-Path $probe -Parent
    }
    return $target
}

function Get-Sha256Hash {
    param([Parameter(Mandatory=$true)][string]$Path)
    # Lowercase to match sha256sum's output, since the manifest must be readable by
    # both this module and its Bash equivalent regardless of which one wrote it.
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Sha256HashOfBytes {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha256.Dispose() }
}

function Write-ManagedSkillFile {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][byte[]]$Bytes)
    $temporary = Join-Path (Split-Path $Path -Parent) ('.ai-config-skill-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $backup = "$temporary.bak"
    try {
        [System.IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([System.IO.File]::Exists($Path)) {
            [System.IO.File]::Replace($temporary, $Path, $backup)
        } else {
            [System.IO.File]::Move($temporary, $Path)
        }
    } finally {
        if ([System.IO.File]::Exists($temporary)) { [System.IO.File]::Delete($temporary) }
        if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) }
    }
}

function Read-ManagedManifest {
    param([Parameter(Mandatory=$true)][string]$ManifestPath)
    $entries = @{}
    if (Test-Path -LiteralPath $ManifestPath) {
        # Lowercase to tolerate an older manifest written before hashes were normalized.
        Import-Csv -LiteralPath $ManifestPath -Delimiter ([char]9) | ForEach-Object {
            $null = Resolve-ManagedPath -Destination (Split-Path $ManifestPath -Parent) -Relative $_.path
            $entries[$_.path] = $_.sha256.ToLowerInvariant()
        }
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

function Invoke-InstallOptions {
    param([Parameter(Mandatory=$true)][string[]]$Arguments, [byte[]]$Managed, [Parameter(Mandatory=$true)][string]$ErrorMessage)
    # Exchange content through UTF-8 files: Windows PowerShell pipes re-encode text by console code page.
    $outputPath = [System.IO.Path]::GetTempFileName()
    $managedPath = $null
    try {
        if ($null -ne $Managed) {
            $managedPath = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($managedPath, $Managed)
            $Arguments += @('--managed', $managedPath)
        }
        & python (Join-Path $PSScriptRoot 'install-options.py') @Arguments --output $outputPath
        if ($LASTEXITCODE -ne 0) { throw $ErrorMessage }
        return [System.IO.File]::ReadAllText($outputPath, (New-Object System.Text.UTF8Encoding($false)))
    } finally {
        Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        if ($managedPath) { Remove-Item -LiteralPath $managedPath -Force -ErrorAction SilentlyContinue }
    }
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
        [string]$PowerShellCommand,
        [string]$ClaudeConcurrency = '5',
        [bool]$FlashbangEnabled = $true,
        [bool]$StatusLineEnabled = $true,
        [switch]$DryRun,
        [switch]$Summary
    )
    if (-not $Summary) { Write-Output "SOURCE $Source -> $Destination" }
    $manifestPath = Get-ManagedManifestPath $Destination
    $null = Resolve-ManagedPath -Destination $Destination -Relative '.ai-config-manifest.tsv'
    $oldManifest = Read-ManagedManifest $manifestPath
    $newManifest = @{}
    $backupRoot = Get-ManagedBackupRoot $Destination
    $oldBackupRoot = Resolve-ManagedPath -Destination $Destination -Relative 'backups'
    if ($backupRoot -ne $oldBackupRoot -and (Test-Path -LiteralPath $oldBackupRoot)) {
        if ($DryRun) {
            if (-not $Summary) { Write-Output "DRYRUN MOVE $oldBackupRoot -> $backupRoot" }
        } else {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            Move-Item -LiteralPath $oldBackupRoot -Destination (Join-Path $backupRoot ('legacy-' + [Guid]::NewGuid().ToString('N')))
        }
    }
    $tally = @{ Created = 0; Updated = 0; Unchanged = 0; Removed = 0; Warned = 0 }

    Get-ChildItem $Source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
        if ((Split-Path $Destination -Leaf) -eq '.codex' -and $relative.StartsWith('skills/')) { return }
        if ((Split-Path $Destination -Leaf) -eq '.claude' -and -not $StatusLineEnabled -and $relative.StartsWith('statusline/')) { return }
        $target = Resolve-ManagedPath -Destination $Destination -Relative $relative
        $rawContent = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
        $filterOptions = ((-not $FlashbangEnabled) -or (-not $StatusLineEnabled)) -and $relative -in @('settings.json', 'config.toml')
        if ($filterOptions) {
            $flashbangOption = if ($FlashbangEnabled) { 'true' } else { 'false' }
            $statusLineOption = if ($StatusLineEnabled) { 'true' } else { 'false' }
            $rawContent = Invoke-InstallOptions -Arguments @('filter', '--path', $_.FullName, '--flashbang', $flashbangOption, '--statusline', $statusLineOption) -ErrorMessage 'Could not configure install options.'
        }
        $needsSubstitution = $filterOptions -or $rawContent.Contains('__AI_CONFIG_ROOT__') -or $rawContent.Contains('__HOOK_COMMAND__') -or $rawContent.Contains('__POWERSHELL_HOOK_COMMAND__') -or $rawContent.Contains('__POWERSHELL_COMMAND__') -or $rawContent.Contains('__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__')
        if ($needsSubstitution) {
            $finalContent = $rawContent.Replace('__AI_CONFIG_ROOT__', $AiConfigRoot).Replace('__HOOK_COMMAND__', $ShellCommand).Replace('__POWERSHELL_HOOK_COMMAND__', $PowerShellCommand).Replace('__POWERSHELL_COMMAND__', $PowerShellCommand).Replace('__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__', $ClaudeConcurrency).Replace('__HOOK_SCRIPT__', 'flashbang.ps1').Replace('__POWERSHELL_HOOK_SCRIPT__', 'flashbang.ps1')
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($finalContent)
        } else {
            $newBytes = [System.IO.File]::ReadAllBytes($_.FullName)
        }
        if ($relative -eq 'config.toml' -and (Test-Path -LiteralPath $target)) {
            $statusLineFlag = if ($StatusLineEnabled) { 'true' } else { 'false' }
            $content = Invoke-InstallOptions -Arguments @('merge-toml', '--current', $target, '--statusline', $statusLineFlag) -Managed $newBytes -ErrorMessage 'Could not merge managed config.toml keys.'
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        }
        if ($relative -eq 'settings.json' -and (Test-Path -LiteralPath $target)) {
            $finalContent = Invoke-InstallOptions -Arguments @('merge-json', '--current', $target) -Managed $newBytes -ErrorMessage 'Could not merge managed settings.json keys.'
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($finalContent)
        }
        $newHash = Get-Sha256HashOfBytes $newBytes
        $newManifest[$relative] = $newHash

        $exists = Test-Path -LiteralPath $target
        if ($exists -and (Get-Sha256Hash $target) -eq $newHash) { $tally.Unchanged++; if (-not $Summary) { Write-Output "UNCHANGED $target" }; return }

        $action = if ($exists) { 'UPDATE' } else { 'CREATE' }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN $action $target" }; if ($action -eq 'CREATE') { $tally.Created++ } else { $tally.Updated++ }; return }
        if ($exists) {
            $wasManaged = $oldManifest.ContainsKey($relative)
            $backup = Resolve-ManagedPath -Destination $backupRoot -Relative "$Stamp/$relative"
            New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath $target $backup -Force
            if (-not $Summary) { Write-Output "BACKUP $target -> $backup" }
            if (-not $wasManaged) { Write-Output "WARN $target existed before this installation but was not tracked by a previous run; it was backed up before being overwritten."; $tally.Warned++ }
        }
        New-Item (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        if ($relative -eq 'SKILL.md' -or $relative.EndsWith('/SKILL.md', [StringComparison]::Ordinal)) {
            Write-ManagedSkillFile -Path $target -Bytes $newBytes
        } else {
            [System.IO.File]::WriteAllBytes($target, $newBytes)
        }
        if (-not $Summary) { Write-Output "$action $target" }
        if ($action -eq 'CREATE') { $tally.Created++ } else { $tally.Updated++ }
    }

    foreach ($relative in @($oldManifest.Keys | Where-Object { -not $newManifest.ContainsKey($_) })) {
        $target = Resolve-ManagedPath -Destination $Destination -Relative $relative
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN REMOVE $target" }; $tally.Removed++; continue }
        $backup = Resolve-ManagedPath -Destination $backupRoot -Relative "$Stamp/$relative"
        New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $target $backup -Force
        if (-not $Summary) { Write-Output "BACKUP $target -> $backup" }
        if ((Get-Sha256Hash $target) -eq $oldManifest[$relative]) {
            Remove-Item -LiteralPath $target -Force
            if (-not $Summary) { Write-Output "REMOVE $target" }
            $tally.Removed++
        } else {
            Write-Output "WARN $target was managed by a previous installation and has changed locally; it was backed up but left in place instead of being removed."
            $tally.Warned++
        }
    }

    if (-not $DryRun) { Write-ManagedManifest $manifestPath $newManifest }
    if ($Summary) { Write-Output ("SYNC {0}: {1} created, {2} updated, {3} unchanged, {4} removed, {5} warnings" -f $Destination, $tally.Created, $tally.Updated, $tally.Unchanged, $tally.Removed, $tally.Warned) }
}
