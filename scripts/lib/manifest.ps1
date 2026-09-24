function Get-ManagedManifestPath {
    param([Parameter(Mandatory=$true)][string]$Destination)
    return (Join-Path $Destination '.ai-config-manifest.tsv')
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
        [switch]$DryRun,
        [switch]$Summary
    )
    if (-not $Summary) { Write-Output "SOURCE $Source -> $Destination" }
    $manifestPath = Get-ManagedManifestPath $Destination
    $null = Resolve-ManagedPath -Destination $Destination -Relative '.ai-config-manifest.tsv'
    $oldManifest = Read-ManagedManifest $manifestPath
    $newManifest = @{}
    $backupRoot = Join-Path $Destination "backups/$Stamp"
    $tally = @{ Created = 0; Updated = 0; Unchanged = 0; Removed = 0; Warned = 0 }

    Get-ChildItem $Source -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
        if ((Split-Path $Destination -Leaf) -eq '.codex' -and $relative.StartsWith('skills/')) { return }
        $target = Resolve-ManagedPath -Destination $Destination -Relative $relative
        $rawContent = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
        $filterFlashbang = -not $FlashbangEnabled -and $relative -in @('settings.json', 'config.toml')
        if ($filterFlashbang) {
            $rawContent = (& python (Join-Path $PSScriptRoot 'install-options.py') filter --path $_.FullName --flashbang false | Out-String)
            if ($LASTEXITCODE -ne 0) { throw 'Could not configure Flashbang.' }
        }
        $needsSubstitution = $filterFlashbang -or $rawContent.Contains('__AI_CONFIG_ROOT__') -or $rawContent.Contains('__HOOK_COMMAND__') -or $rawContent.Contains('__POWERSHELL_HOOK_COMMAND__') -or $rawContent.Contains('__POWERSHELL_COMMAND__') -or $rawContent.Contains('__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__')
        if ($needsSubstitution) {
            $finalContent = $rawContent.Replace('__AI_CONFIG_ROOT__', $AiConfigRoot).Replace('__HOOK_COMMAND__', $ShellCommand).Replace('__POWERSHELL_HOOK_COMMAND__', $PowerShellCommand).Replace('__POWERSHELL_COMMAND__', $PowerShellCommand).Replace('__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__', $ClaudeConcurrency).Replace('__HOOK_SCRIPT__', 'flashbang.ps1').Replace('__POWERSHELL_HOOK_SCRIPT__', 'flashbang.ps1')
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($finalContent)
        } else {
            $newBytes = [System.IO.File]::ReadAllBytes($_.FullName)
        }
        if ($relative -eq 'config.toml' -and (Test-Path -LiteralPath $target)) {
            $localConfig = [System.IO.File]::ReadAllText($target)
            $pluginTables = [regex]::Matches($localConfig, '(?m)^[ \t]*\[(?:plugins|marketplaces)(?:\.|\])[\s\S]*?(?=^[ \t]*\[|\z)')
            $rootConfig = ([regex]::Split($localConfig, '(?m)^[ \t]*\[', 2)[0]).TrimStart([char]0xFEFF)
            $localSettings = [regex]::Matches($rootConfig, '(?m)^[ \t]*(?:model|model_reasoning_effort)[ \t]*=.*$')
            if ($localSettings.Count -gt 0) {
                $content = [System.Text.Encoding]::UTF8.GetString($newBytes).TrimEnd([char[]]"`r`n")
                foreach ($setting in $localSettings) {
                    $name = ([regex]::Match($setting.Value, '^[ \t]*([^ \t=]+)')).Groups[1].Value
                    $content = [regex]::Replace($content, "(?m)^[ \t]*$([regex]::Escape($name))[ \t]*=.*(?:\r?\n|$)", '')
                }
                $preservedSettings = ($localSettings | ForEach-Object { $_.Value.TrimEnd([char[]]"`r`n") }) -join "`n"
                $firstTable = [regex]::Match($content, '(?m)^[ \t]*\[')
                if ($firstTable.Success) { $content = $content.Insert($firstTable.Index, "$preservedSettings`n") }
                else { $content = "$content`n$preservedSettings" }
                $newBytes = [System.Text.Encoding]::UTF8.GetBytes("$content`n")
            }
            if ($pluginTables.Count -gt 0) {
                $content = [System.Text.Encoding]::UTF8.GetString($newBytes).TrimEnd([char[]]"`r`n")
                if ($content -match '(?m)^[ \t]*\[(?:plugins|marketplaces)(?:\.|\])') {
                    throw 'Cannot overwrite local plugin configuration with generated plugin tables.'
                }
                $preserved = ($pluginTables | ForEach-Object { $_.Value.TrimEnd([char[]]"`r`n") }) -join "`n"
                $newBytes = [System.Text.Encoding]::UTF8.GetBytes("$content`n`n$preserved`n")
            }
        }
        $newHash = Get-Sha256HashOfBytes $newBytes
        $newManifest[$relative] = $newHash

        $exists = Test-Path -LiteralPath $target
        if ($exists -and (Get-Sha256Hash $target) -eq $newHash) { $tally.Unchanged++; if (-not $Summary) { Write-Output "UNCHANGED $target" }; return }

        $action = if ($exists) { 'UPDATE' } else { 'CREATE' }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN $action $target" }; if ($action -eq 'CREATE') { $tally.Created++ } else { $tally.Updated++ }; return }
        if ($exists) {
            $wasManaged = $oldManifest.ContainsKey($relative)
            $backup = Resolve-ManagedPath -Destination $Destination -Relative "backups/$Stamp/$relative"
            New-Item (Split-Path $backup -Parent) -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath $target $backup -Force
            if (-not $Summary) { Write-Output "BACKUP $target -> $backup" }
            if (-not $wasManaged) { Write-Output "WARN $target existed before this installation but was not tracked by a previous run; it was backed up before being overwritten."; $tally.Warned++ }
        }
        New-Item (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        [System.IO.File]::WriteAllBytes($target, $newBytes)
        if (-not $Summary) { Write-Output "$action $target" }
        if ($action -eq 'CREATE') { $tally.Created++ } else { $tally.Updated++ }
    }

    foreach ($relative in @($oldManifest.Keys | Where-Object { -not $newManifest.ContainsKey($_) })) {
        $target = Resolve-ManagedPath -Destination $Destination -Relative $relative
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN REMOVE $target" }; $tally.Removed++; continue }
        $backup = Resolve-ManagedPath -Destination $Destination -Relative "backups/$Stamp/$relative"
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
