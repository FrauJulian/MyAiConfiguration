# Token-Efficiency Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut low-value tokens agents pay for in both Claude Code and Codex — chatty script output, always-loaded rule content that's rarely needed in full, duplicated instructions, and low-value delegation — without weakening correctness, security, or verification quality.

**Architecture:** `shared/` definitions stay the single source of truth; `scripts/build.ps1`/`build.sh` render them into `generated/<client>-<platform>/`; installation copies that into the user's home directory. This plan only changes what the build renders and how the maintenance scripts report their own output — the `shared definitions -> adapters -> generated -> install` pipeline itself is unchanged.

**Tech Stack:** PowerShell 5.1+ (Windows), Bash (Linux) — every change ships an equivalent pair. Python `tomllib` validates generated Codex config; `codex --strict-config` validates against the installed CLI when available.

**Spec:** `docs/superpowers/specs/2026-09-16-token-efficiency-design.md`

## Global Constraints

- Every `.ps1` change must stay compatible with Windows PowerShell 5.1 (no `` `e ``/`` `u{} `` escapes, no PS6+-only syntax) — this repo targets 5.1+ on Windows, `pwsh` on Linux.
- Every script change ships both a `.ps1` and a `.sh` equivalent with the same observable behavior.
- `WARN` and `FAIL`/error output is never suppressed by `-Summary`/`--summary`, in any script.
- `general.md`'s Documentation/Comments rule ("never modify existing documentation automatically", "no new documentation/comments without explicit approval") stays intact in content — items 3/4 relocate and de-duplicate wording, they do not weaken it.
- Split rule files must preserve every existing bullet — relocated verbatim, not reworded, not dropped.
- `scripts/build.ps1` and `scripts/build.sh` must produce equivalent `generated/` output (same file set modulo path separators, same content) — this is already asserted by `scripts/test-platform-packages.*`.
- Run `scripts/build.ps1`/`scripts/build.sh` after every semantic change and before every commit in this plan (per `AI-Instructions.md`).
- Do not commit unless the user asks (per this repo's git rules) — each task below still gets a `git add`+local commit step per the plan-writing convention, but hold final `git push`/multi-commit squashing decisions for the user.

---

## Task Group A — Quiet output mode (`-Summary` / `--summary`)

### Task 1: `-Summary` in `manifest.ps1` / `manifest.sh`

**Files:**
- Modify: `scripts/lib/manifest.ps1`
- Modify: `scripts/lib/manifest.sh`
- Test: `scripts/test-managed-install.ps1`, `scripts/test-managed-install.sh` (extend)

**Interfaces:**
- Produces: `Sync-ManagedDestination` gains `[switch]$Summary` (PS) / `sync_managed_destination` gains a trailing `summary` positional arg, `true`/`false` (Bash) — 8th positional argument, after today's 7th (`dry_run`).
- Consumes: nothing new.

Today `Sync-ManagedDestination`/`sync_managed_destination` prints one line per file (`SOURCE`, `UNCHANGED`, `CREATE`/`UPDATE`, `BACKUP`, `WARN`, `REMOVE`) plus per-file `DRYRUN` lines. In summary mode, keep the one `SOURCE ... -> ...` header line, suppress every per-file line except `WARN`, and print one tally line at the end instead.

- [ ] **Step 1: Add the `Summary` switch and per-file suppression to `manifest.ps1`**

Replace the whole `Sync-ManagedDestination` function in `scripts/lib/manifest.ps1` with:

```powershell
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
        [switch]$DryRun,
        [switch]$Summary
    )
    Write-Output "SOURCE $Source -> $Destination"
    $manifestPath = Get-ManagedManifestPath $Destination
    $oldManifest = Read-ManagedManifest $manifestPath
    $newManifest = @{}
    $backupRoot = Join-Path $Destination "backups/$Stamp"
    $tally = @{ Created = 0; Updated = 0; Unchanged = 0; Removed = 0; Warned = 0 }

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
        if ($exists -and (Get-Sha256Hash $target) -eq $newHash) { $tally.Unchanged++; if (-not $Summary) { Write-Output "UNCHANGED $target" }; return }

        $action = if ($exists) { 'UPDATE' } else { 'CREATE' }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN $action $target" }; if ($action -eq 'CREATE') { $tally.Created++ } else { $tally.Updated++ }; return }
        if ($exists) {
            $wasManaged = $oldManifest.ContainsKey($relative)
            $backup = Join-Path $backupRoot $relative
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
        $target = Join-Path $Destination $relative
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($DryRun) { if (-not $Summary) { Write-Output "DRYRUN REMOVE $target" }; $tally.Removed++; continue }
        $backup = Join-Path $backupRoot $relative
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
```

- [ ] **Step 2: Mirror the same change in `manifest.sh`**

Replace the whole `sync_managed_destination` function in `scripts/lib/manifest.sh` with:

```bash
# sync_managed_destination <source-dir> <destination-dir> <stamp> <ai-config-root> <shell-command> <windows-shell-command> <dry-run: true|false> [summary: true|false]
sync_managed_destination() {
  local source=$1 destination=$2 stamp=$3 ai_config_root=$4 shell_command=$5 windows_shell_command=$6 dry_run=$7 summary=${8:-false}
  printf 'SOURCE %s -> %s\n' "$source" "$destination"
  local manifest
  manifest=$(manifest_path "$destination")
  declare -A old_manifest
  read_managed_manifest "$manifest" old_manifest
  declare -A new_manifest
  local backup_root="$destination/backups/$stamp"
  local created=0 updated=0 unchanged=0 removed=0 warned=0

  while IFS= read -r -d '' source_file; do
    local relative target content needs_sub new_hash exists current_hash action backup
    relative=${source_file#"$source/"}
    target="$destination/$relative"
    content=$(<"$source_file")
    needs_sub=false
    if [[ "$content" == *'__AI_CONFIG_ROOT__'* || "$content" == *'__HOOK_COMMAND__'* || "$content" == *'__WINDOWS_HOOK_COMMAND__'* ]]; then
      needs_sub=true
      content=${content//__AI_CONFIG_ROOT__/$ai_config_root}
      content=${content//__HOOK_COMMAND__/$shell_command}
      content=${content//__WINDOWS_HOOK_COMMAND__/$windows_shell_command}
      content=${content//__HOOK_SCRIPT__/flashbang.sh}
      content=${content//__WINDOWS_HOOK_SCRIPT__/flashbang.sh}
      new_hash=$(sha256_of_string "$content")
    else
      new_hash=$(sha256_of_file "$source_file")
    fi
    new_manifest[$relative]=$new_hash

    exists=false
    [ -f "$target" ] && exists=true
    if [ "$exists" = true ]; then
      current_hash=$(sha256_of_file "$target")
      if [ "$current_hash" = "$new_hash" ]; then
        unchanged=$((unchanged + 1))
        [ "$summary" = true ] || printf 'UNCHANGED %s\n' "$target"
        continue
      fi
      action=UPDATE
    else
      action=CREATE
    fi

    if [ "$dry_run" = true ]; then
      [ "$summary" = true ] || printf 'DRYRUN %s %s\n' "$action" "$target"
      [ "$action" = CREATE ] && created=$((created + 1)) || updated=$((updated + 1))
      continue
    fi

    if [ "$exists" = true ]; then
      backup="$backup_root/$relative"
      mkdir -p "$(dirname -- "$backup")"
      cp -- "$target" "$backup"
      [ "$summary" = true ] || printf 'BACKUP %s -> %s\n' "$target" "$backup"
      if [ -z "${old_manifest[$relative]+x}" ]; then
        printf 'WARN %s existed before this installation but was not tracked by a previous run; it was backed up before being overwritten.\n' "$target"
        warned=$((warned + 1))
      fi
    fi
    mkdir -p "$(dirname -- "$target")"
    if [ "$needs_sub" = true ]; then
      printf '%s' "$content" > "$target"
    else
      cp -- "$source_file" "$target"
    fi
    [ "$summary" = true ] || printf '%s %s\n' "$action" "$target"
    [ "$action" = CREATE ] && created=$((created + 1)) || updated=$((updated + 1))
  done < <(find "$source" -type f -print0)

  local relative target current_hash backup
  for relative in "${!old_manifest[@]}"; do
    [ -z "${new_manifest[$relative]+x}" ] || continue
    target="$destination/$relative"
    [ -f "$target" ] || continue
    if [ "$dry_run" = true ]; then
      [ "$summary" = true ] || printf 'DRYRUN REMOVE %s\n' "$target"
      removed=$((removed + 1))
      continue
    fi
    backup="$backup_root/$relative"
    mkdir -p "$(dirname -- "$backup")"
    cp -- "$target" "$backup"
    [ "$summary" = true ] || printf 'BACKUP %s -> %s\n' "$target" "$backup"
    current_hash=$(sha256_of_file "$target")
    if [ "$current_hash" = "${old_manifest[$relative]}" ]; then
      rm -f -- "$target"
      [ "$summary" = true ] || printf 'REMOVE %s\n' "$target"
      removed=$((removed + 1))
    else
      printf 'WARN %s was managed by a previous installation and has changed locally; it was backed up but left in place instead of being removed.\n' "$target"
      warned=$((warned + 1))
    fi
  done

  if [ "$dry_run" != true ]; then write_managed_manifest "$manifest" new_manifest; fi
  if [ "$summary" = true ]; then
    printf 'SYNC %s: %s created, %s updated, %s unchanged, %s removed, %s warnings\n' "$destination" "$created" "$updated" "$unchanged" "$removed" "$warned"
  fi
}
```

- [ ] **Step 3: Extend `test-managed-install.ps1` to cover summary mode**

Add before the final `Write-Output 'PASS ...'` line in `scripts/test-managed-install.ps1` (right after the existing dry-run block, still inside the `try`):

```powershell
    $outSummary = @(Sync-ManagedDestination -Source $source -Destination $destination -Stamp 'summary' -Summary)
    if (@($outSummary | Where-Object { $_ -like 'CREATE*' -or $_ -like 'UPDATE*' -or $_ -like 'UNCHANGED*' -or $_ -like 'BACKUP*' }).Count -ne 0) { throw "Summary mode must not print per-file lines: $($outSummary -join '; ')" }
    if (@($outSummary | Where-Object { $_ -match '^SYNC .* unchanged' }).Count -ne 1) { throw "Summary mode must print exactly one SYNC tally line: $($outSummary -join '; ')" }
```

- [ ] **Step 4: Mirror step 3 in `test-managed-install.sh`**

Add the equivalent block before the final `printf 'PASS ...'` in `scripts/test-managed-install.sh`:

```bash
    out_summary=$(sync_managed_destination "$source" "$destination" "summary" "" "" "" false true)
    if printf '%s\n' "$out_summary" | grep -Eq '^(CREATE|UPDATE|UNCHANGED|BACKUP) '; then
      printf 'Summary mode must not print per-file lines: %s\n' "$out_summary" >&2
      exit 1
    fi
    if [ "$(printf '%s\n' "$out_summary" | grep -c '^SYNC .* unchanged')" -ne 1 ]; then
      printf 'Summary mode must print exactly one SYNC tally line: %s\n' "$out_summary" >&2
      exit 1
    fi
```

- [ ] **Step 5: Run both test scripts**

Run: `bash scripts/test-managed-install.sh` and `powershell -NoProfile -File scripts/test-managed-install.ps1` (or `pwsh` on Linux).
Expected: both print `PASS managed manifest: ...` with no thrown error.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/manifest.ps1 scripts/lib/manifest.sh scripts/test-managed-install.ps1 scripts/test-managed-install.sh
git commit -m "feat(scripts): add summary mode to managed-file sync"
```

---

### Task 2: `-Summary` in `plugins.ps1` / `plugins.sh`

**Files:**
- Modify: `scripts/lib/plugins.ps1`
- Modify: `scripts/lib/plugins.sh`

**Interfaces:**
- Consumes: `Invoke-PluginCommand -DryRun` (unchanged), nothing from Task 1.
- Produces: `Install-ConfiguredPlugins` and `Uninstall-DeselectedPlugins` gain `[switch]$Summary` (PS); `install_configured_plugins` gains a new 6th positional `summary` arg, after today's 5th positional `selected_name`; `uninstall_deselected_plugins` gains a new 5th positional `summary` arg, after today's 4th positional `deselected-array-name`.

- [ ] **Step 1: Add `-Summary` to `Install-ConfiguredPlugins` and `Uninstall-DeselectedPlugins` in `plugins.ps1`**

In `scripts/lib/plugins.ps1`, change the `Install-ConfiguredPlugins` signature to add `[switch]$Summary` alongside the existing `[switch]$DryRun, [switch]$Update, [object[]]$Entries`. Wrap every `Write-Output "PASS ..."` and `Write-Output "DRYRUN ..."` line already inside its loop body with `if (-not $Summary) { ... }`, and add a per-client tally that prints once after each client's `foreach ($entry in $entries)` loop:

```powershell
function Install-ConfiguredPlugins {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [switch]$DryRun,
        [switch]$Update,
        [switch]$Summary,
        [object[]]$Entries
    )
    $entries = if ($Entries) { $Entries } else { @(Get-ConfiguredPluginEntries -RepositoryRoot $RepositoryRoot) }
    $clients = if ($Client -eq 'Both') { @('Claude','Codex') } else { @($Client) }

    foreach ($selectedClient in $clients) {
        $installed = if ($DryRun) { @() } else { @(Get-InstalledPlugins -Client $selectedClient) }
        $tally = @{ Ensured = 0; AlreadyInstalled = 0; Updated = 0 }
        foreach ($entry in $entries) {
            $marketplace = if ($selectedClient -eq 'Claude') { $entry.claude_marketplace.Trim() } else { $entry.codex_marketplace.Trim() }
            if ($marketplace -eq '-') { $marketplace = '' }
            $plugin = if ($selectedClient -eq 'Claude') { $entry.claude_plugin } else { $entry.codex_plugin }
            if ([string]::IsNullOrWhiteSpace($plugin)) { throw ('Plugin selector missing for {0}: {1}' -f $selectedClient, $entry.name) }

            if ($selectedClient -eq 'Codex' -and $entry.codex_method -ne 'plugin') {
                if ($entry.codex_method -eq 'skill') {
                    $arguments = @('-y','skills','add',$entry.codex_source,'--global','--agent','codex')
                    if ($entry.codex_skill -ne '-') { $arguments = @('-y','skills','add',$entry.codex_source,'--skill',$entry.codex_skill,'--global','--agent','codex') }
                } elseif ($entry.codex_method -eq 'impeccable') {
                    $arguments = @('-y','impeccable','install','-y','--providers=codex','--scope=global')
                } else {
                    throw "Unknown Codex install method '$($entry.codex_method)' for $($entry.name)."
                }
                Invoke-PluginCommand -Command 'npx' -Arguments $arguments -DryRun:$DryRun
                if (-not $Summary) { Write-Output "PASS Codex skill ensured: $($entry.name)" }
                $tally.Ensured++
                continue
            }

            $installedItem = if ($selectedClient -eq 'Claude') { $installed | Where-Object { $_.id -eq $plugin } | Select-Object -First 1 } else { $installed | Where-Object { $_.pluginId -eq $plugin } | Select-Object -First 1 }
            if ($Update -and $selectedClient -eq 'Claude' -and $null -ne $installedItem) {
                Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','update',$plugin) -DryRun:$DryRun
                if (-not $installedItem.enabled) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','enable',$plugin) -DryRun:$DryRun
                }
                $tally.Updated++
                continue
            }
            if (-not $Update -and $null -ne $installedItem) {
                if ($selectedClient -eq 'Claude' -and -not $installedItem.enabled) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','enable',$plugin) -DryRun:$DryRun
                }
                if (-not $Summary) { Write-Output "PASS $selectedClient plugin already installed: $plugin" }
                $tally.AlreadyInstalled++
                continue
            }

            if ($selectedClient -eq 'Claude') {
                if (-not [string]::IsNullOrWhiteSpace($marketplace)) {
                    Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','marketplace','add',$marketplace) -DryRun:$DryRun
                }
                Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','install',$plugin,'--scope','user') -DryRun:$DryRun
            } else {
                if (-not [string]::IsNullOrWhiteSpace($marketplace) -and $marketplace -ne 'openai-curated-remote') {
                    $marketplaceName = ($plugin -split '@')[-1]
                    Ensure-CodexMarketplace -Source $marketplace -MarketplaceName $marketplaceName -DryRun:$DryRun
                }
                Invoke-PluginCommand -Command 'codex' -Arguments @('plugin','add',$plugin) -DryRun:$DryRun
            }
            if (-not $Summary) { Write-Output "PASS $selectedClient plugin ensured: $plugin" }
            $tally.Ensured++
        }
        if ($Summary) { Write-Output ("PLUGINS {0}: {1} ensured, {2} already installed, {3} updated" -f $selectedClient, $tally.Ensured, $tally.AlreadyInstalled, $tally.Updated) }
    }
}
```

Then update `Uninstall-DeselectedPlugins` the same way — add `[switch]$Summary`, guard its `Write-Output "PASS $selectedClient plugin removed: $plugin"` line, and print a tally after each client's inner loop:

```powershell
function Uninstall-DeselectedPlugins {
    param(
        [Parameter(Mandatory=$true)][object[]]$Entries,
        [ValidateSet('Codex','Claude','Both')][Parameter(Mandatory=$true)][string]$Client,
        [switch]$DryRun,
        [switch]$Summary
    )
    $clients = if ($Client -eq 'Both') { @('Claude','Codex') } else { @($Client) }
    foreach ($selectedClient in $clients) {
        $installed = if ($DryRun) { @() } else { @(Get-InstalledPlugins -Client $selectedClient) }
        $idField = if ($selectedClient -eq 'Claude') { 'id' } else { 'pluginId' }
        $removedCount = 0
        foreach ($entry in $Entries) {
            $plugin = if ($selectedClient -eq 'Claude') { $entry.claude_plugin } else { $entry.codex_plugin }
            if ([string]::IsNullOrWhiteSpace($plugin)) { continue }
            $isInstalled = [bool](@($installed | Where-Object { $_.$idField -eq $plugin }).Count)
            if (-not $isInstalled) { continue }
            if ($selectedClient -eq 'Claude') {
                Invoke-PluginCommand -Command 'claude' -Arguments @('plugin','uninstall',$plugin,'--scope','user') -DryRun:$DryRun
            } else {
                Invoke-PluginCommand -Command 'codex' -Arguments @('plugin','remove',$plugin) -DryRun:$DryRun
            }
            if (-not $Summary) { Write-Output "PASS $selectedClient plugin removed: $plugin" }
            $removedCount++
        }
        if ($Summary -and $removedCount -gt 0) { Write-Output "PLUGINS $selectedClient: $removedCount removed" }
    }
}
```

- [ ] **Step 2: Mirror both functions in `plugins.sh`**

In `scripts/lib/plugins.sh`, change the `install_configured_plugins` signature line to:

```bash
# install_configured_plugins <root> <client> <dry_run> <update> [selected-names-array-name] [summary]
install_configured_plugins() {
  local root=$1 client_selection=$2 dry_run=$3 update=$4 selected_name=${5:-} summary=${6:-false}
```

Then wrap its two `printf 'PASS Codex skill ensured: %s\n' "$name"` and `printf 'PASS %s plugin ensured: %s\n' "$client" "$plugin"` lines (and the existing `printf 'PASS %s plugin already installed: %s\n' "$client" "$plugin"` line) with a `[ "$summary" = true ] ||` guard, and add a per-client tally. Add `local ensured=0 already_installed=0 updated_count=0` right after the `local -A selected_set=()` block, reset it to `0 0 0` at the top of each `for client in "${clients[@]}"` iteration, increment the right counter at each of the three `PASS`/update sites, and print `printf 'PLUGINS %s: %s ensured, %s already installed, %s updated\n' "$client" "$ensured" "$already_installed" "$updated_count"` once per client after its `for name ...` loop — mirroring exactly the PowerShell tally fields above. Apply the corresponding `[ "$summary" = true ] ||` guard to the two `DRYRUN`/skill-ensure lines inside `run_plugin_command` calls is not needed (that function has its own `dry_run` gate and stays unchanged); only the `printf 'PASS ...'` lines and the new tally line are affected by `summary`.

Do the same to `uninstall_deselected_plugins`: add a trailing `summary` argument, guard its `printf 'PASS %s plugin removed: %s\n' "$client" "$plugin"` line, tally a `removed` counter per client, and print `printf 'PLUGINS %s: %s removed\n' "$client" "$removed"` once per client when `removed -gt 0` and `summary = true`.

```bash
# uninstall_deselected_plugins <root> <client> <dry_run> <deselected-array-name> [summary]
uninstall_deselected_plugins() {
  local root=$1 client_selection=$2 dry_run=$3
  local -n names_ref=$4
  local summary=${5:-false}
  local clients=()
  case "$client_selection" in
    codex) clients=(codex);;
    claude) clients=(claude);;
    both) clients=(claude codex);;
  esac
  local client name plugin removed
  for client in "${clients[@]}"; do
    removed=0
    for name in "${names_ref[@]}"; do
      if [ "$client" = claude ]; then plugin=$(plugin_field "$root" "$name" claude_plugin); else plugin=$(plugin_field "$root" "$name" codex_plugin); fi
      [ -n "$plugin" ] || continue
      if [ "$dry_run" = false ] && plugin_installed "$client" "$plugin"; then
        if [ "$client" = claude ]; then
          run_plugin_command "$dry_run" claude plugin uninstall "$plugin" --scope user
        else
          run_plugin_command "$dry_run" codex plugin remove "$plugin"
        fi
        [ "$summary" = true ] || printf 'PASS %s plugin removed: %s\n' "$client" "$plugin"
        removed=$((removed + 1))
      fi
    done
    if [ "$summary" = true ] && [ "$removed" -gt 0 ]; then printf 'PLUGINS %s: %s removed\n' "$client" "$removed"; fi
  done
}
```

- [ ] **Step 3: Run the existing plugin-selection test to confirm nothing broke**

Run: `bash scripts/test-plugin-selection.sh` and `powershell -NoProfile -File scripts/test-plugin-selection.ps1`.
Expected: both still print `PASS plugin toggle selection: toggle and confirm` (this test exercises `Read-PluginToggleSelection`/`read_plugin_toggle_selection`, unaffected by this task, but confirms the file still parses/loads cleanly after the edit).

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/plugins.ps1 scripts/lib/plugins.sh
git commit -m "feat(scripts): add summary mode to plugin install/uninstall"
```

---

### Task 3: `-Summary` in `build.ps1` / `build.sh`

**Files:**
- Modify: `scripts/build.ps1`
- Modify: `scripts/build.sh`

**Interfaces:**
- Consumes: nothing from Tasks 1-2 (build doesn't call `Sync-ManagedDestination`/`Install-ConfiguredPlugins`).
- Produces: `build.ps1 -Summary` / `build.sh --summary`. `build.ps1` already ends with a single `PASS build: ...` line and has no other `Write-Output` in the success path, so this task only needs to suppress `Write-Warning` calls' informational noise is out of scope (warnings must stay) and align `build.sh`, which currently has no equivalent per-step chatter to hide either — re-verify with `grep` before assuming there's nothing to change.

- [ ] **Step 1: Re-check `build.ps1` and `build.sh` for any status output beyond the final PASS line**

Run: `grep -n "Write-Output\|Write-Warning" scripts/build.ps1` and `grep -n "printf '" scripts/build.sh`.
Expected: `build.ps1` shows only the final `Write-Output 'PASS build: ...'` (plus `Write-Warning` inside `Test-CodexSchema`, which must stay — it only fires when the Codex CLI is unavailable, i.e. a warning). `build.sh` shows the final `printf 'PASS build: ...'` plus the `printf 'WARN Codex CLI unavailable; ...'` line inside the per-platform loop (must stay) — confirm there is no other chatter; if the grep turns up additional lines not covered by this plan, stop and flag them rather than silently deleting them.

- [ ] **Step 2: Add `-Summary` param to `build.ps1` (no behavior change beyond accepting the flag)**

In `scripts/build.ps1`, change line 2 (`param()`) to:

```powershell
param([switch]$Summary)
```

Build already prints exactly one line on success (`PASS build: codex-windows, claude-windows, codex-linux, claude-linux`) and only ever adds `Write-Warning` (not suppressible — warnings) or `throw` (fatal) beyond that, so no further change is needed inside the function bodies; `$Summary` is accepted for interface parity with the other scripts and for forward compatibility, and is intentionally unused today.

- [ ] **Step 3: Add `--summary` flag parsing to `build.sh`**

`build.sh` currently takes no arguments at all. Add minimal parsing at the top, right after `set -euo pipefail` (line 2):

```bash
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
```

Same rationale as Step 2: `build.sh` already prints one `PASS build: ...` line on success and only ever adds the Codex-unavailable `WARN` line beyond that, so `$summary` is accepted (for parity and forward use) but not otherwise consumed yet.

- [ ] **Step 4: Run both builds with and without the new flag**

Run: `bash scripts/build.sh`, `bash scripts/build.sh --summary`, `powershell -NoProfile -File scripts/build.ps1`, `powershell -NoProfile -File scripts/build.ps1 -Summary`.
Expected: all four print `PASS build: codex-windows, claude-windows, codex-linux, claude-linux` and exit 0; `--summary`/`-Summary` must not change output (build has nothing left to summarize) or fail argument parsing.

- [ ] **Step 5: Commit**

```bash
git add scripts/build.ps1 scripts/build.sh
git commit -m "feat(build): accept --summary/-Summary for interface parity"
```

---

### Task 4: `-Summary` in `doctor.ps1` / `doctor.sh`

**Files:**
- Modify: `scripts/doctor.ps1`
- Modify: `scripts/doctor.sh`
- Test: `scripts/test-platform-packages.ps1`, `scripts/test-platform-packages.sh` (add a targeted doctor-summary assertion — doctor isn't otherwise covered by these files today, so add a small dedicated block rather than folding into an unrelated assertion)

**Interfaces:**
- Produces: `doctor.ps1 -Summary` / `doctor.sh --summary` — on success (`$fail`/`failed` stays false), suppress every `PASS` line and print `Doctor: PASS | <n> checks` instead, where `<n>` is the total number of `Result`/`result` calls made (of any state). `WARN` and `FAIL` lines always print, regardless of `-Summary`. On failure, print everything as today (no suppression) plus the tally line, so the agent sees both the count and every actionable line.

- [ ] **Step 1: Add `-Summary` to `doctor.ps1`**

Change `scripts/doctor.ps1` lines 1-8 from:

```powershell
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
$homePath = [Environment]::GetFolderPath('UserProfile')
$fail = $false
function Result($state, $message) { Write-Output ("$state $message"); if ($state -eq 'FAIL') { $script:fail = $true } }
```

to:

```powershell
[CmdletBinding()]
param([switch]$Summary)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/manifest.ps1')
$homePath = [Environment]::GetFolderPath('UserProfile')
$fail = $false
$script:checkCount = 0
function Result($state, $message) {
    $script:checkCount++
    if ($state -eq 'FAIL') { $script:fail = $true }
    if (-not $Summary -or $state -ne 'PASS') { Write-Output ("$state $message") }
}
```

Then change the two lines at the very end of the file from:

```powershell
if ($fail) { exit 1 }
Write-Output 'PASS doctor'
exit 0
```

to:

```powershell
if ($fail) { exit 1 }
if ($Summary) { Write-Output "Doctor: PASS | $checkCount checks" } else { Write-Output 'PASS doctor' }
exit 0
```

- [ ] **Step 2: Mirror the change in `doctor.sh`**

Change `scripts/doctor.sh` lines 1-12 from:

```bash
#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/manifest.sh"
home_path=${HOME:?HOME is required}
failed=false

result() {
  printf '%s %s\n' "$1" "$2"
  [ "$1" != FAIL ] || failed=true
}
```

to:

```bash
#!/usr/bin/env bash
set -euo pipefail

summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/manifest.sh"
home_path=${HOME:?HOME is required}
failed=false
check_count=0

result() {
  check_count=$((check_count + 1))
  [ "$1" != FAIL ] || failed=true
  if [ "$summary" = false ] || [ "$1" != PASS ]; then printf '%s %s\n' "$1" "$2"; fi
}
```

Then change the final two lines from:

```bash
"$failed" && exit 1
printf 'PASS doctor\n'
```

to:

```bash
"$failed" && exit 1
if [ "$summary" = true ]; then printf 'Doctor: PASS | %s checks\n' "$check_count"; else printf 'PASS doctor\n'; fi
```

- [ ] **Step 3: Add a doctor-summary assertion to `test-platform-packages.ps1`**

Add near the end of `scripts/test-platform-packages.ps1`, right before the final `Write-Output 'PASS four platform packages and six PowerShell selections'` line:

```powershell
$doctorSummaryOutput = & (Join-Path $root 'scripts/doctor.ps1') -Summary
if (@($doctorSummaryOutput | Where-Object { $_ -match '^PASS ' }).Count -ne 0) { throw 'Doctor summary mode must not print individual PASS lines.' }
if (@($doctorSummaryOutput | Where-Object { $_ -match '^Doctor: PASS \| \d+ checks$' }).Count -ne 1) { throw "Doctor summary mode must print one 'Doctor: PASS | N checks' line: $($doctorSummaryOutput -join '; ')" }
```

- [ ] **Step 4: Mirror step 3 in `test-platform-packages.sh`**

Add the equivalent block before the final `printf 'PASS four platform packages and six Bash selections\n'` line in `scripts/test-platform-packages.sh`:

```bash
doctor_summary_output=$(bash "$root/scripts/doctor.sh" --summary)
if printf '%s\n' "$doctor_summary_output" | grep -q '^PASS '; then
  printf 'Doctor summary mode must not print individual PASS lines.\n' >&2
  exit 1
fi
if ! printf '%s\n' "$doctor_summary_output" | grep -Eq '^Doctor: PASS \| [0-9]+ checks$'; then
  printf "Doctor summary mode must print one 'Doctor: PASS | N checks' line: %s\n" "$doctor_summary_output" >&2
  exit 1
fi
```

- [ ] **Step 5: Run both test suites**

Run: `bash scripts/test-platform-packages.sh` and `powershell -NoProfile -File scripts/test-platform-packages.ps1`.
Expected: both pass (this also exercises `doctor.ps1 -Summary`/`doctor.sh --summary` directly against the real installed state on this machine — a real install must already exist, which it does here).

- [ ] **Step 6: Commit**

```bash
git add scripts/doctor.ps1 scripts/doctor.sh scripts/test-platform-packages.ps1 scripts/test-platform-packages.sh
git commit -m "feat(doctor): add --summary/-Summary output mode"
```

---

### Task 5: `-Summary` in `install.ps1`/`install.sh`/`update.ps1`/`update.sh`

**Files:**
- Modify: `scripts/install.ps1`, `scripts/install.sh`, `scripts/update.ps1`, `scripts/update.sh`

**Interfaces:**
- Consumes: `Sync-ManagedDestination -Summary` / `sync_managed_destination ... true` (Task 1), `Install-ConfiguredPlugins -Summary` / `install_configured_plugins ... true` and `Uninstall-DeselectedPlugins -Summary` / `uninstall_deselected_plugins ... true` (Task 2).
- Produces: `install.ps1 -Summary` / `install.sh --summary` / `update.ps1 -Summary` / `update.sh --summary`. Purely an output-verbosity switch — does not change `-Client`/`-Platform` interactivity, does not change `-DryRun`'s existing defaults (a summary dry run just previews more compactly), and does not change the already-installed/not-installed guard behavior.

- [ ] **Step 1: Thread `-Summary` through `install.ps1`**

In `scripts/install.ps1`, add `[switch]$Summary` to the `param(...)` block (alongside the existing `$DryRun`, `$Client`, `$Platform`), then change the sync loop and the final two calls from:

```powershell
foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Platform $platform -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -WindowsShellCommand $windowsShellCommand -DryRun:$DryRun
}

$plugins = Select-ConfiguredPlugins -RepositoryRoot $root -Client $Client -Mode 'Install' -DryRun:$DryRun
Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Entries $plugins.Selected
Write-Output ($(if ($DryRun) { 'PASS install dry-run' } else { 'PASS install' }))
exit 0
```

to:

```powershell
foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Platform $platform -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -WindowsShellCommand $windowsShellCommand -DryRun:$DryRun -Summary:$Summary
}

$plugins = Select-ConfiguredPlugins -RepositoryRoot $root -Client $Client -Mode 'Install' -DryRun:$DryRun
Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Summary:$Summary -Entries $plugins.Selected
Write-Output ($(if ($DryRun) { 'PASS install dry-run' } else { 'PASS install' }))
exit 0
```

- [ ] **Step 2: Thread `--summary` through `install.sh`**

In `scripts/install.sh`, add `summary=false` to the variable block and a `--summary) summary=true; shift ;;` case to the argument-parsing loop (alongside the existing `--dry-run`, `--client`, `--platform`). Then change the sync loop and plugin calls from:

```bash
while IFS='|' read -r source destination; do
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$windows_shell_command" "$dry_run"
done < <(get_install_targets "$generated" "$home_path" "$platform" "$client")

selected_plugins=()
deselected_plugins=()
select_configured_plugins "$root" "$client" Install "$dry_run" selected_plugins deselected_plugins
install_configured_plugins "$root" "$client" "$dry_run" false selected_plugins
```

to:

```bash
while IFS='|' read -r source destination; do
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$windows_shell_command" "$dry_run" "$summary"
done < <(get_install_targets "$generated" "$home_path" "$platform" "$client")

selected_plugins=()
deselected_plugins=()
select_configured_plugins "$root" "$client" Install "$dry_run" selected_plugins deselected_plugins
install_configured_plugins "$root" "$client" "$dry_run" false selected_plugins "$summary"
```

- [ ] **Step 3: Mirror steps 1-2 in `update.ps1`/`update.sh`**

In `scripts/update.ps1`, add `[switch]$Summary` to `param(...)`, then apply the same `-Summary:$Summary` addition to its `Sync-ManagedDestination`, `Install-ConfiguredPlugins`, and `Uninstall-DeselectedPlugins` calls:

```powershell
foreach ($item in (Get-InstallTargets -Generated $generated -HomePath $homePath -Platform $platform -Client $Client)) {
    Sync-ManagedDestination -Source $item.Source -Destination $item.Destination -Stamp $stamp `
        -AiConfigRoot $item.Destination.Replace('\','/') -ShellCommand $shellCommand -WindowsShellCommand $windowsShellCommand -DryRun:$DryRun -Summary:$Summary
}

$plugins = Select-ConfiguredPlugins -RepositoryRoot $root -Client $Client -Mode 'Update' -DryRun:$DryRun
Install-ConfiguredPlugins -RepositoryRoot $root -Client $Client -DryRun:$DryRun -Update -Summary:$Summary -Entries $plugins.Selected
Uninstall-DeselectedPlugins -Entries $plugins.Deselected -Client $Client -DryRun:$DryRun -Summary:$Summary
Write-Output ($(if ($DryRun) { 'PASS update dry-run' } else { 'PASS update' }))
exit 0
```

In `scripts/update.sh`, add the same `--summary` parsing block as `install.sh`, then:

```bash
while IFS='|' read -r source destination; do
  ai_config_root=$destination
  command -v cygpath >/dev/null && ai_config_root=$(cygpath -m "$destination")
  sync_managed_destination "$source" "$destination" "$stamp" "$ai_config_root" "$shell_command" "$windows_shell_command" "$dry_run" "$summary"
done < <(get_install_targets "$generated" "$home_path" "$platform" "$client")

selected_plugins=()
deselected_plugins=()
select_configured_plugins "$root" "$client" Update "$dry_run" selected_plugins deselected_plugins
install_configured_plugins "$root" "$client" "$dry_run" true selected_plugins "$summary"
uninstall_deselected_plugins "$root" "$client" "$dry_run" deselected_plugins "$summary"
```

- [ ] **Step 4: Run dry-run smoke checks for all four scripts, with and without `-Summary`**

Run, from the repo root:
```bash
bash scripts/install.sh --dry-run --client both --platform linux
bash scripts/install.sh --dry-run --summary --client both --platform linux
bash scripts/update.sh --dry-run --client both --platform linux
bash scripts/update.sh --dry-run --summary --client both --platform linux
```
and the PowerShell equivalents (`.\scripts\install.ps1 -DryRun -Client Both -Platform Windows`, add `-Summary`, same for `update.ps1`).
Expected: all exit 0 and end with `PASS install dry-run` / `PASS update dry-run`; the `--summary` runs must print visibly fewer lines than the non-summary runs (spot-check: no `SOURCE`/`CREATE`/`UPDATE`/`UNCHANGED` lines) and any `WARN` lines (there should be none in a clean dry run) would still show if present.

- [ ] **Step 5: Commit**

```bash
git add scripts/install.ps1 scripts/install.sh scripts/update.ps1 scripts/update.sh
git commit -m "feat(install,update): thread --summary/-Summary through sync and plugin steps"
```

---

## Task Group B — Progressive disclosure for `angular.md` / `wpf.md` / `ui-ux.md`

Each of the three files splits into `shared/rules/<name>/index.md` (universal rules + a table pointing to the right reference file) plus `shared/rules/<name>/references/*.md`. Every existing bullet is relocated verbatim — headings become `#`-level in the reference file (drop one level, since the reference file has no need for its old `##` nesting under a now-absent top-level title — keep the bullets themselves untouched) or can stay `##`; pick whichever avoids an empty top-of-file title and keep it consistent across the three files (this plan uses: reference file starts directly with the original `## Heading` unchanged, no new top-level `#` title, since the file already lives at a path that names its topic).

### Task 6: Split `angular.md`

**Files:**
- Create: `shared/rules/angular/index.md`
- Create: `shared/rules/angular/references/components-and-state.md`
- Create: `shared/rules/angular/references/templates-and-styling.md`
- Create: `shared/rules/angular/references/rxjs.md`
- Create: `shared/rules/angular/references/services-and-http.md`
- Create: `shared/rules/angular/references/forms-and-routing.md`
- Create: `shared/rules/angular/references/security-and-accessibility.md`
- Create: `shared/rules/angular/references/performance.md`
- Create: `shared/rules/angular/references/testing-and-architecture.md`
- Delete: `shared/rules/angular.md`

**Interfaces:** none (content-only; Task 9 makes the build understand the new directory shape).

- [ ] **Step 1: Create `shared/rules/angular/index.md`**

Move `shared/rules/angular.md`'s un-headed intro bullets (the 14 bullets between the `# Angular Code Guidelines` title and the first `## Components` heading) and its closing `## Safety Rule` section verbatim into the new file, and add a reference table. Content:

```markdown
# Angular Code Guidelines

* Use modern Angular patterns and current framework conventions.
* Prefer standalone components, directives and pipes for new code.
* Avoid introducing `NgModule` unless the existing project architecture requires it.
* Keep components small and focused.
* Keep templates simple.
* Move complex logic out of templates.
* Keep business logic out of components where practical.
* Prefer services, facades or dedicated domain logic for non-trivial behavior.
* Avoid god components and god services.
* Keep dependencies explicit.
* Prefer composition over inheritance.
* Avoid unnecessary abstractions.
* Avoid unnecessary wrapper components.
* Follow the existing project architecture unless there is a strong reason to change it.

## Safety Rule

* Angular frontend code is never a security boundary.
* Client-side validation, guards, hidden controls and disabled UI elements do not replace backend enforcement.
* Do not bypass Angular's built-in security mechanisms without a verified and explicit reason.
* Prefer safe framework defaults over custom low-level behavior.

## Detailed guidance

Read the matching reference file before working in that area:

| Read this reference for... | ...this kind of work |
| --- | --- |
| `references/components-and-state.md` | Component structure, signal-based state |
| `references/templates-and-styling.md` | Template markup, CSS/styling |
| `references/rxjs.md` | RxJS observables and subscriptions |
| `references/services-and-http.md` | Dependency injection, services, HTTP/API access |
| `references/forms-and-routing.md` | Reactive forms, routing |
| `references/security-and-accessibility.md` | Security, DOM/browser APIs, accessibility |
| `references/performance.md` | Performance work and its priority order |
| `references/testing-and-architecture.md` | Testing, architecture, code quality, dependency rules |
```

- [ ] **Step 2: Create the 8 reference files**

Move each named `##` section from `shared/rules/angular.md` verbatim (heading plus its bullets, unchanged) into the matching new file:

- `references/components-and-state.md`: `## Components` + `## Signals and State`
- `references/templates-and-styling.md`: `## Templates` + `## Styling`
- `references/rxjs.md`: `## RxJS`
- `references/services-and-http.md`: `## Dependency Injection` + `## Services` + `## HTTP and APIs`
- `references/forms-and-routing.md`: `## Forms` + `## Routing`
- `references/security-and-accessibility.md`: `## Security` + `## DOM and Browser APIs` + `## Accessibility`
- `references/performance.md`: `## Performance` + `## Performance Priority`
- `references/testing-and-architecture.md`: `## Testing` + `## Architecture` + `## Code Quality` + `## Dependency Rules`

Every bullet from the original file must appear in exactly one of: `index.md`'s intro/Safety Rule, or one of the 8 reference files above. Do not reword or drop anything.

- [ ] **Step 3: Delete the old flat file**

```bash
rm shared/rules/angular.md
```

- [ ] **Step 4: Verify nothing was dropped**

Run: `wc -l shared/rules/angular/index.md shared/rules/angular/references/*.md` and compare the sum of bullet lines (lines starting with `*`) against the original 297-line file's bullet count. This is a manual spot-check, not an automated test — Task 9's build-script change will fail loudly if a reference file is malformed, but only a read-through catches silently dropped bullets.

- [ ] **Step 5: Commit**

```bash
git add shared/rules/angular
git rm shared/rules/angular.md
git commit -m "refactor(rules): split angular.md into index + references"
```

---

### Task 7: Split `wpf.md`

**Files:**
- Create: `shared/rules/wpf/index.md`
- Create: `shared/rules/wpf/references/mvvm-and-binding.md`
- Create: `shared/rules/wpf/references/commands-and-async.md`
- Create: `shared/rules/wpf/references/collections-and-xaml.md`
- Create: `shared/rules/wpf/references/resources-and-lifecycle.md`
- Create: `shared/rules/wpf/references/security-and-errors.md`
- Create: `shared/rules/wpf/references/architecture-and-quality.md`
- Delete: `shared/rules/wpf.md`

Same mechanics as Task 6.

- [ ] **Step 1: Create `shared/rules/wpf/index.md`**

Move the intro bullets (between `# WPF Code Guidelines` and the first `## MVVM`) and the closing `## Safety Rule` section verbatim, plus a reference table:

```markdown
# WPF Code Guidelines

* Use modern C# and current .NET/WPF conventions.
* Keep UI, application logic and domain logic clearly separated.
* Prefer MVVM for non-trivial views.
* Keep code-behind minimal.
* Use code-behind only for view-specific behavior that does not belong in the ViewModel.
* Avoid business logic in views.
* Avoid direct service access from controls.
* Keep dependencies explicit and testable.
* Prefer composition over inheritance.
* Avoid unnecessary abstractions and framework wrappers.
* Follow the existing project architecture unless there is a strong reason to change it.

## Safety Rule

* The UI must remain responsive.
* Do not block the UI thread with I/O or expensive CPU work.
* Do not bypass validation or security controls for convenience.
* Do not introduce hidden cross-thread access.
* Prefer predictable, explicit and testable UI behavior.

## Detailed guidance

Read the matching reference file before working in that area:

| Read this reference for... | ...this kind of work |
| --- | --- |
| `references/mvvm-and-binding.md` | MVVM, data binding, property change notifications, dependency/attached properties |
| `references/commands-and-async.md` | Commands, async/threading, UI-thread work, events |
| `references/collections-and-xaml.md` | Collections, virtualization, layout, XAML |
| `references/resources-and-lifecycle.md` | Resources/styles, windows/dialogs, navigation, memory, images/media |
| `references/security-and-errors.md` | Security, file/process access, error handling, logging, validation |
| `references/architecture-and-quality.md` | Architecture, DI, testing, code quality, performance |
```

- [ ] **Step 2: Create the 6 reference files**

- `references/mvvm-and-binding.md`: `## MVVM` + `## Data Binding` + `## Property Change Notifications` + `## Dependency Properties` + `## Attached Properties and Behaviors`
- `references/commands-and-async.md`: `## Commands` + `## Async and Threading` + `## UI Thread` + `## Events`
- `references/collections-and-xaml.md`: `## Collections` + `## XAML` + `## Layout` + `## Virtualization`
- `references/resources-and-lifecycle.md`: `## Resources and Styles` + `## Windows and Dialogs` + `## Navigation` + `## Memory Management` + `## Images and Media`
- `references/security-and-errors.md`: `## Security` + `## File and Process Access` + `## Error Handling` + `## Logging` + `## Validation`
- `references/architecture-and-quality.md`: `## Architecture` + `## Dependency Injection` + `## Testing` + `## Code Quality` + `## Performance` + `## Performance Priority`

Move each section verbatim, heading and bullets unchanged. Every bullet from the original 375-line file must land in exactly one place.

- [ ] **Step 3: Delete the old flat file**

```bash
rm shared/rules/wpf.md
```

- [ ] **Step 4: Verify nothing was dropped**

Run: `wc -l shared/rules/wpf/index.md shared/rules/wpf/references/*.md` and spot-check bullet coverage against the original.

- [ ] **Step 5: Commit**

```bash
git add shared/rules/wpf
git rm shared/rules/wpf.md
git commit -m "refactor(rules): split wpf.md into index + references"
```

---

### Task 8: Split `ui-ux.md`

**Files:**
- Create: `shared/rules/ui-ux/index.md`
- Create: `shared/rules/ui-ux/references/navigation-and-actions.md`
- Create: `shared/rules/ui-ux/references/forms.md`
- Create: `shared/rules/ui-ux/references/content-and-feedback.md`
- Create: `shared/rules/ui-ux/references/visual-and-accessibility.md`
- Create: `shared/rules/ui-ux/references/tables-search-dialogs.md`
- Create: `shared/rules/ui-ux/references/destructive-and-error-prevention.md`
- Delete: `shared/rules/ui-ux.md`

Same mechanics as Task 6.

- [ ] **Step 1: Create `shared/rules/ui-ux/index.md`**

Move the intro bullets (between `# UI & UX Guidelines` and the first `## Navigation`) and the closing `## Design Decision Rule` + `## Priority Order` sections verbatim (these are the short, universal decision framework — keep both, like `angular`/`wpf`'s Safety Rule), plus a reference table:

```markdown
# UI & UX Guidelines

* Design for clarity first.
* Prefer simple, modern and predictable interfaces.
* Optimize for fast understanding and low cognitive load.
* Every screen should have a clear primary purpose.
* Every important action should be easy to discover.
* Prefer familiar interaction patterns over novel ones.
* Do not require users to learn unnecessary custom behavior.
* Keep layouts visually calm and structured.
* Use consistent spacing, typography, colors and interaction patterns.
* Avoid visual noise.
* Avoid decorative elements that do not improve usability.
* Avoid unnecessary complexity in navigation and workflows.
* Minimize the number of steps required to complete common tasks.
* Keep related information and actions close together.
* Group content logically.
* Use clear visual hierarchy.
* Make primary actions visually distinct from secondary actions.
* Avoid giving multiple actions equal visual priority when one is clearly more important.
* Use whitespace intentionally.
* Prefer readable line lengths and sufficient spacing.
* Avoid dense walls of content.
* Avoid oversized empty areas that reduce information efficiency.
* Keep important information visible without unnecessary scrolling where practical.

## Design Decision Rule

* Every UI element should have a clear purpose.
* Every additional interaction adds cognitive cost.
* Prefer removing complexity over explaining unnecessary complexity.
* Prefer familiar patterns over clever ones.
* Prefer fewer clear choices over many ambiguous choices.
* Prefer predictable behavior over surprising automation.
* If a design decision introduces ambiguity, unnecessary complexity, or multiple equally valid UX directions, ask the user instead of deciding autonomously.

## Priority Order

Prioritize UI/UX decisions in this order:

* Correctness
* Clarity
* Safety
* Accessibility
* User control
* Task efficiency
* Consistency
* Responsiveness
* Visual polish

Visual polish must never reduce usability.

## Detailed guidance

Read the matching reference file before working in that area:

| Read this reference for... | ...this kind of work |
| --- | --- |
| `references/navigation-and-actions.md` | Navigation structure, action labeling and placement |
| `references/forms.md` | Form design and validation UX |
| `references/content-and-feedback.md` | Copy, loading/empty/error states, responsiveness |
| `references/visual-and-accessibility.md` | Visual design, accessibility, responsive layout |
| `references/tables-search-dialogs.md` | Data-dense views, search/filtering, dialogs/modals |
| `references/destructive-and-error-prevention.md` | Destructive actions, error prevention, consistency, user control, progressive disclosure, perceived performance, defaults |
```

- [ ] **Step 2: Create the 6 reference files**

- `references/navigation-and-actions.md`: `## Navigation` + `## Actions`
- `references/forms.md`: `## Forms`
- `references/content-and-feedback.md`: `## Content and Language` + `## Feedback and System State` + `## Responsiveness`
- `references/visual-and-accessibility.md`: `## Visual Design` + `## Accessibility` + `## Responsive Design`
- `references/tables-search-dialogs.md`: `## Tables and Data-Dense Views` + `## Search and Filtering` + `## Dialogs and Modals`
- `references/destructive-and-error-prevention.md`: `## Destructive Actions` + `## Error Prevention` + `## Consistency` + `## User Control` + `## Progressive Disclosure` + `## Performance Perception` + `## Defaults`

Move each section verbatim. Every bullet from the original 306-line file must land in exactly one place.

- [ ] **Step 3: Delete the old flat file**

```bash
rm shared/rules/ui-ux.md
```

- [ ] **Step 4: Verify nothing was dropped**

Run: `wc -l shared/rules/ui-ux/index.md shared/rules/ui-ux/references/*.md` and spot-check bullet coverage against the original.

- [ ] **Step 5: Commit**

```bash
git add shared/rules/ui-ux
git rm shared/rules/ui-ux.md
git commit -m "refactor(rules): split ui-ux.md into index + references"
```

---

### Task 9: Teach the build about directory-shaped rules

**Files:**
- Modify: `scripts/build.ps1`
- Modify: `scripts/build.sh`
- Modify: `adapters/claude/rule-skills.tsv` (no schema change — `rule_file` column now holds `angular`, `wpf`, `ui-ux` instead of `angular.md`, `wpf.md`, `ui-ux.md` for those three rows; every other row is untouched)

**Interfaces:**
- Consumes: Tasks 6-8's `shared/rules/<name>/index.md` + `references/` layout.
- Produces: `generated/claude-<platform>/skills/rules/<skill_name>/SKILL.md` + `.../references/*.md`; `generated/codex-<platform>/rules/<name>/index.md` + `.../references/*.md`; Codex's `AGENTS.md` rule-loading text points at `rules/<name>/index.md` for the three split rules and stays `rules/<name>.md` for every other rule.

- [ ] **Step 1: Update `adapters/claude/rule-skills.tsv`**

Change the three rows so `rule_file` no longer has a `.md` extension for the split rules — this signals "directory" to the build script (a value with no `.md` suffix). Open `adapters/claude/rule-skills.tsv` and change:

```
angular.md	rules-angular	Angular component, template, or RxJS/signal work
```
to
```
angular	rules-angular	Angular component, template, or RxJS/signal work
```

and similarly `wpf.md` → `wpf`, `ui-ux.md` → `ui-ux`. Leave every other row's `rule_file` value (`csharp.md`, `git.md`, etc.) untouched.

- [ ] **Step 2: Update `build.ps1`'s validation, Claude skill generation, and Codex rule-loading text**

The validation loop (around line 30) checks `Test-Path -LiteralPath (Join-Path $shared "rules/$($entry.rule_file)")` — a bare `angular` now needs to resolve to the directory `shared/rules/angular/` (which exists), so this check already works unchanged as long as `Test-Path` is given the right path; no change needed there.

Change the Claude skill-generation loop (originally lines 141-149) from:

```powershell
    $claudeRuleSkillLines = @()
    foreach ($entry in $ruleSkillEntries) {
        $skillDir = Join-Path $output "claude-$platform/skills/rules/$($entry.skill_name)"
        New-Item $skillDir -ItemType Directory -Force | Out-Null
        $ruleContent = Get-Content (Join-Path $shared "rules/$($entry.rule_file)") -Raw
        $skillBody = "---`r`nname: $($entry.skill_name)`r`ndescription: Use for $($entry.trigger).`r`n---`r`n`r`n$ruleContent"
        Set-Content (Join-Path $skillDir 'SKILL.md') $skillBody -Encoding UTF8
        $claudeRuleSkillLines += "- $($entry.skill_name) for $($entry.trigger)."
    }
```

to:

```powershell
    $claudeRuleSkillLines = @()
    foreach ($entry in $ruleSkillEntries) {
        $ruleSourcePath = Join-Path $shared "rules/$($entry.rule_file)"
        $isDirectory = Test-Path -LiteralPath $ruleSourcePath -PathType Container
        $ruleBodyPath = if ($isDirectory) { Join-Path $ruleSourcePath 'index.md' } else { $ruleSourcePath }
        $skillDir = Join-Path $output "claude-$platform/skills/rules/$($entry.skill_name)"
        New-Item $skillDir -ItemType Directory -Force | Out-Null
        $ruleContent = Get-Content $ruleBodyPath -Raw
        $skillBody = "---`r`nname: $($entry.skill_name)`r`ndescription: Use for $($entry.trigger).`r`n---`r`n`r`n$ruleContent"
        Set-Content (Join-Path $skillDir 'SKILL.md') $skillBody -Encoding UTF8
        if ($isDirectory) {
            $referencesSource = Join-Path $ruleSourcePath 'references'
            if (Test-Path -LiteralPath $referencesSource) { Copy-Directory $referencesSource (Join-Path $skillDir 'references') }
        }
        $claudeRuleSkillLines += "- $($entry.skill_name) for $($entry.trigger)."
    }
```

(`Copy-Directory` is already defined earlier in the same file and used elsewhere, so no new helper is needed.)

Change the Codex rule-loading heredoc: the three lines

```
- rules/angular.md for Angular work.
```
```
- rules/wpf.md for WPF work.
```
```
- rules/ui-ux.md for UI or UX decisions.
```

become

```
- rules/angular/index.md for Angular work.
```
```
- rules/wpf/index.md for WPF work.
```
```
- rules/ui-ux/index.md for UI or UX decisions.
```

(every other line in the heredoc stays exactly as-is).

Note: `Copy-Directory (Join-Path $shared 'rules') (Join-Path $output "codex-$platform/rules")` (unchanged, already present) already copies the whole `shared/rules/` tree recursively — since `angular/`, `wpf/`, `ui-ux/` are now subdirectories of `shared/rules/`, this one line already ships `rules/angular/index.md` and `rules/angular/references/*.md` (and the same for `wpf`, `ui-ux`) into the Codex package with no further change.

- [ ] **Step 3: Mirror step 2 in `build.sh`**

Change the Claude skill-generation loop (originally lines 122-132) from:

```bash
claude_rule_loading_list=""
for i in "${!rule_skill_names[@]}"; do
  rule_file=${rule_skill_files[$i]}
  skill_name=${rule_skill_names[$i]}
  trigger=${rule_skill_triggers[$i]}
  skill_dir="$output/claude-$platform/skills/rules/$skill_name"
  mkdir -p "$skill_dir"
  { printf -- '---\nname: %s\ndescription: Use for %s.\n---\n\n' "$skill_name" "$trigger"; cat "$shared/rules/$rule_file"; } > "$skill_dir/SKILL.md"
  claude_rule_loading_list="${claude_rule_loading_list}- ${skill_name} for ${trigger}.
"
done
```

to:

```bash
claude_rule_loading_list=""
for i in "${!rule_skill_names[@]}"; do
  rule_file=${rule_skill_files[$i]}
  skill_name=${rule_skill_names[$i]}
  trigger=${rule_skill_triggers[$i]}
  rule_source="$shared/rules/$rule_file"
  rule_body="$rule_source"
  [ -d "$rule_source" ] && rule_body="$rule_source/index.md"
  skill_dir="$output/claude-$platform/skills/rules/$skill_name"
  mkdir -p "$skill_dir"
  { printf -- '---\nname: %s\ndescription: Use for %s.\n---\n\n' "$skill_name" "$trigger"; cat "$rule_body"; } > "$skill_dir/SKILL.md"
  if [ -d "$rule_source/references" ]; then
    copy_directory "$rule_source/references" "$skill_dir/references"
  fi
  claude_rule_loading_list="${claude_rule_loading_list}- ${skill_name} for ${trigger}.
"
done
```

Change the three Codex rule-loading heredoc lines (`- rules/angular.md for Angular work.`, `- rules/wpf.md for WPF work.`, `- rules/ui-ux.md for UI or UX decisions.`) to `- rules/angular/index.md for Angular work.`, `- rules/wpf/index.md for WPF work.`, `- rules/ui-ux/index.md for UI or UX decisions.` — same as the PowerShell change. `copy_directory "$shared/rules" "$output/codex-$platform/rules"` (already present, unchanged) already ships the new subdirectories.

Also, the validation loop's existing check `[ -f "$shared/rules/$rule_file" ]` (line 34) tests for a *file*, which now fails for the three directory-shaped entries. Change it to:

```bash
[ -f "$shared/rules/$rule_file" ] || [ -d "$shared/rules/$rule_file" ] || { printf 'Rule-skill manifest references a missing rule file: %s\n' "$rule_file" >&2; exit 1; }
```

- [ ] **Step 4: Rebuild and inspect the generated output**

Run: `bash scripts/build.sh` (or `powershell -NoProfile -File scripts/build.ps1`).
Expected: `PASS build: ...`. Then run `find generated/claude-linux/skills/rules/rules-angular -type f` and `find generated/codex-linux/rules/angular -type f`.
Expected: both show `index.md`/`SKILL.md` plus 8 files under `references/`, matching Task 6's file list; same shape for `wpf`/`ui-ux` with their own reference counts.

- [ ] **Step 5: Commit**

```bash
git add scripts/build.ps1 scripts/build.sh adapters/claude/rule-skills.tsv
git commit -m "feat(build): support directory-shaped rules with references/"
```

---

## Task Group C — Canonical rule locations and orchestration guidance

### Task 10: Embed `general.md` into `AGENTS.md` for Codex

**Files:**
- Modify: `scripts/build.ps1`
- Modify: `scripts/build.sh`

**Interfaces:** none new.

- [ ] **Step 1: Reorder and update `build.ps1`'s AGENTS.md/CLAUDE.md generation**

Change lines 93-94 (the comment above `$codexRuleLoading`) from:

```powershell
# Codex keeps the original rule-loading text unchanged: every rule ships as a plain
# file and AGENTS.md tells Codex to load the matching one by path.
```

to:

```powershell
# Codex: general.md is embedded directly into AGENTS.md, the same way Claude embeds
# it into CLAUDE.md, instead of only being referenced by path — guaranteed present
# either way, and safe even if a subagent's AGENTS.md inheritance is not guaranteed.
```

Change the first line of the `$codexRuleLoading` heredoc (line 96) from:

```
Always load and apply `rules/general.md` before starting any task.
```

to:

```
General rules are embedded below.
```

Change the AGENTS.md/CLAUDE.md generation block (originally lines 152-158) from:

```powershell
    $sharedTemplate = Get-Content (Join-Path $shared 'global-instructions.md') -Raw
    Set-Content (Join-Path $output "codex-$platform/AGENTS.md") ($sharedTemplate.Replace('__RULE_LOADING__', $codexRuleLoading)) -Encoding UTF8

    $generalContent = Get-Content (Join-Path $shared 'rules/general.md') -Raw
    $claudeContent = $sharedTemplate.Replace('__RULE_LOADING__', $claudeRuleLoading)
    $claudeContent = $claudeContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "claude-$platform/CLAUDE.md") $claudeContent -Encoding UTF8
```

to:

```powershell
    $sharedTemplate = Get-Content (Join-Path $shared 'global-instructions.md') -Raw
    $generalContent = Get-Content (Join-Path $shared 'rules/general.md') -Raw

    $agentsContent = $sharedTemplate.Replace('__RULE_LOADING__', $codexRuleLoading)
    $agentsContent = $agentsContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "codex-$platform/AGENTS.md") $agentsContent -Encoding UTF8

    $claudeContent = $sharedTemplate.Replace('__RULE_LOADING__', $claudeRuleLoading)
    $claudeContent = $claudeContent.TrimEnd() + "`r`n`r`n---`r`n`r`n$generalContent"
    Set-Content (Join-Path $output "claude-$platform/CLAUDE.md") $claudeContent -Encoding UTF8
```

- [ ] **Step 2: Mirror step 1 in `build.sh`**

Change the comment above `codex_rule_loading` (lines 76-77) the same way as the PowerShell comment above, and change the heredoc's first line (`Always load and apply \`rules/general.md\` before starting any task.`) to `General rules are embedded below.`.

Change the generation block (originally lines 141-147) from:

```bash
shared_template=$(<"$shared/global-instructions.md")
agents_content=${shared_template//__RULE_LOADING__/$codex_rule_loading}
printf '%s\n' "$agents_content" > "$output/codex-$platform/AGENTS.md"

general_content=$(<"$shared/rules/general.md")
claude_content=${shared_template//__RULE_LOADING__/$claude_rule_loading}
printf '%s\n\n---\n\n%s\n' "${claude_content%$'\n'}" "$general_content" > "$output/claude-$platform/CLAUDE.md"
```

to:

```bash
shared_template=$(<"$shared/global-instructions.md")
general_content=$(<"$shared/rules/general.md")

agents_content=${shared_template//__RULE_LOADING__/$codex_rule_loading}
printf '%s\n\n---\n\n%s\n' "${agents_content%$'\n'}" "$general_content" > "$output/codex-$platform/AGENTS.md"

claude_content=${shared_template//__RULE_LOADING__/$claude_rule_loading}
printf '%s\n\n---\n\n%s\n' "${claude_content%$'\n'}" "$general_content" > "$output/claude-$platform/CLAUDE.md"
```

- [ ] **Step 3: Rebuild and spot-check**

Run: `bash scripts/build.sh`.
Expected: `PASS build: ...`. Then `grep -c "## Documentation" generated/codex-linux/AGENTS.md` and `grep -c "Always load and apply" generated/codex-linux/AGENTS.md`.
Expected: the first shows `1` (general.md's Documentation section is now embedded), the second shows `0` (the old always-load instruction line is gone — the remaining `rules/security.md` "always load" sentence is still present and is a different, still-correct string; confirm with `grep "Always load and apply" generated/codex-linux/AGENTS.md` that only the `rules/security.md` line remains, not a `rules/general.md` one).

- [ ] **Step 4: Commit**

```bash
git add scripts/build.ps1 scripts/build.sh
git commit -m "feat(build): embed general.md into AGENTS.md, not just CLAUDE.md"
```

---

### Task 11: Trim `global-instructions.md`, add a decisions pointer to `general.md`, rewrite orchestration guidance

**Files:**
- Modify: `shared/global-instructions.md`
- Modify: `shared/rules/general.md`

**Interfaces:** none new (consumed by Task 10's already-updated build, which embeds `general.md` for both clients — this task just changes the two files' content, no build-script change needed here).

- [ ] **Step 1: Rewrite `shared/global-instructions.md`**

Replace its entire content with:

```markdown
# Personal global instructions

This instruction set is generated into the client-specific `AGENTS.md` and `CLAUDE.md` files. Do not edit generated copies.

__RULE_LOADING__

Delegate only when the expected improvement in correctness, independence, specialization, or parallelism outweighs the duplicated context and tool cost. Do not delegate simple repository exploration the main agent can do directly. Do not create a researcher for information the main agent can obtain cheaply itself. Use one implementer for small and medium contained tasks. Run reviewer and verifier together only when their responsibilities are materially different for the current task. Avoid multiple agents independently reading the same large set of files. Use parallel agents only for genuinely independent work. Do not let subagents create further subagents.
```

This drops the previous Priority, Decision, and Documentation/Comments paragraphs and replaces the old "Use one implementer..." orchestration paragraph with the rewritten one shown above — `general.md` (embedded for both clients as of Task 10) is now the single canonical source for Priority/Decisions/Documentation/Comments/Language, and this file keeps only the rule-loading placeholder plus the orchestration paragraph.

- [ ] **Step 2: Add a Decisions section to `shared/rules/general.md`**

Insert a new `## Decisions` section right after the existing `## Priority` section and before `## Documentation` (so the file reads: Priority, Decisions, Documentation, Comments, Language). Change:

```markdown
Project instructions may specialize global defaults, but must not weaken security or data-loss protections without explicit user approval.

## Documentation
```

to:

```markdown
Project instructions may specialize global defaults, but must not weaken security or data-loss protections without explicit user approval.

## Decisions

* Make evidence-based, reversible technical decisions independently; ask only when material uncertainty, multiple meaningful options, or high-impact/hard-to-reverse effects remain.
* Ask about business behavior, user-visible behavior, UI, UX, APIs, database models, configuration formats, or compatibility behavior only when it is missing, ambiguous, contradictory, or open to interpretation; implement explicitly specified behavior without asking again.
* For deeper guidance on ambiguous requirements or a meaningful technical choice, consult `decision-rule.md` (Codex: read `rules/decision-rule.md`; Claude: invoke the `rules-decision-rule` skill).

## Documentation
```

- [ ] **Step 3: Rebuild and verify de-duplication**

Run: `bash scripts/build.sh`.
Expected: `PASS build: ...`. Then run:
```bash
grep -c "Apply instructions in this order" generated/claude-linux/CLAUDE.md
grep -c "Apply instructions in this order" generated/codex-linux/AGENTS.md
grep -c "Never modify existing documentation automatically" generated/claude-linux/CLAUDE.md
```
Expected: every count is `1` (previously `2` for the first two, since the Priority sentence was paraphrased in `global-instructions.md` and restated in full in `general.md`; the third was already `1` for the substance but is now unambiguously the sole copy since the `global-instructions.md` paraphrase is gone).

- [ ] **Step 4: Commit**

```bash
git add shared/global-instructions.md shared/rules/general.md
git commit -m "refactor(rules): de-duplicate priority/decision/documentation guidance into general.md"
```

---

### Task 12: Trim `definition-of-done.md`'s restated documentation rule

**Files:**
- Modify: `shared/rules/definition-of-done.md`

**Interfaces:** none.

- [ ] **Step 1: Collapse the two restated bullets into one reference**

Change:

```markdown
* Existing documentation was not changed automatically. If the code makes it inaccurate, that was noted afterward instead of blocking the change.
* No new documentation, repository comments, pull request text, or work-item text was created without explicit user instruction.
```

to:

```markdown
* Documentation and comments follow `general.md`'s Documentation and Comments rules (not changed automatically, none created without explicit instruction).
```

- [ ] **Step 2: Rebuild**

Run: `bash scripts/build.sh`.
Expected: `PASS build: ...`.

- [ ] **Step 3: Commit**

```bash
git add shared/rules/definition-of-done.md
git commit -m "refactor(rules): point definition-of-done at general.md instead of restating it"
```

---

## Task Group D — Regression coverage and final validation

### Task 13: Update `test-platform-packages.*` for the new AGENTS.md/CLAUDE.md shape and split rules

**Files:**
- Modify: `scripts/test-platform-packages.ps1`
- Modify: `scripts/test-platform-packages.sh`

**Interfaces:**
- Consumes: Task 9's split-rule output shape, Task 10's embedded `general.md` in `AGENTS.md`, Task 11's de-duplicated wording.

- [ ] **Step 1: Add a `build.ps1 -Summary` regression check to `test-platform-packages.ps1`**

Add near the top of `scripts/test-platform-packages.ps1`, right after the existing `$branch = & git -C $root branch --show-current` line:

```powershell
$buildSummaryOutput = & (Join-Path $root 'scripts/build.ps1') -Summary
if (@($buildSummaryOutput | Where-Object { $_ -eq 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux' }).Count -ne 1) { throw "build.ps1 -Summary must still print the PASS line: $($buildSummaryOutput -join '; ')" }
```

- [ ] **Step 2: Add de-duplication and split-rule assertions to `test-platform-packages.ps1`**

Add inside the existing `foreach ($platform in @('windows','linux')) { foreach ($client in @('codex','claude')) { ... } }` block in `scripts/test-platform-packages.ps1`, right after the existing `if (grep -Eq '__HOOK_|__WINDOWS_HOOK_') ...` placeholder check (i.e., right before the loop's closing braces) — add these client-specific checks using the already-in-scope `$content`/`$package` variables:

```powershell
        if (([regex]::Matches($content, [regex]::Escape('Apply instructions in this order'))).Count -ne 1) { throw "$client-$platform must embed the priority rule exactly once" }
        if ($client -eq 'codex' -and $content -match 'Always load and apply `rules/general\.md`') { throw "$package must not still instruct loading general.md by path" }
        foreach ($splitRule in @('angular','wpf','ui-ux')) {
            $referencesDir = if ($client -eq 'codex') { Join-Path $package "rules/$splitRule/references" } else { Join-Path $package "skills/rules/rules-$splitRule/references" }
            if (-not (Test-Path $referencesDir) -or (Get-ChildItem $referencesDir -Filter '*.md').Count -eq 0) { throw "$package is missing reference files for $splitRule" }
        }
```

- [ ] **Step 3: Mirror step 1 in `test-platform-packages.sh`**

Add near the top of `scripts/test-platform-packages.sh`, right after the existing `branch=$(git -C "$root" branch --show-current)` line:

```bash
build_summary_output=$(bash "$root/scripts/build.sh" --summary)
if ! printf '%s\n' "$build_summary_output" | grep -qx 'PASS build: codex-windows, claude-windows, codex-linux, claude-linux'; then
  printf 'build.sh --summary must still print the PASS line: %s\n' "$build_summary_output" >&2
  exit 1
fi
```

- [ ] **Step 4: Mirror step 2 in `test-platform-packages.sh`**

Add the equivalent checks inside the existing `for platform in windows linux; do for client in codex claude; do ... done; done` loop in `scripts/test-platform-packages.sh`, right after the existing `if grep -Eq '__HOOK_|__WINDOWS_HOOK_' "$package/$file"; then exit 1; fi` line:

```bash
    if [ "$(grep -o 'Apply instructions in this order' "$content_file" 2>/dev/null | wc -l)" != 1 ]; then :; fi
```

`test-platform-packages.sh` reads `$content` via a shell variable (`content=$(cat ...)`), not a file, in the existing script — reuse that variable instead of a temp file:

```bash
    occurrences=$(printf '%s' "$content" | grep -o 'Apply instructions in this order' | wc -l)
    [ "$occurrences" -eq 1 ] || { printf '%s-%s must embed the priority rule exactly once\n' "$client" "$platform" >&2; exit 1; }
    if [ "$client" = codex ] && printf '%s' "$content" | grep -q 'Always load and apply `rules/general\.md`'; then
      printf '%s must not still instruct loading general.md by path\n' "$package" >&2
      exit 1
    fi
    for split_rule in angular wpf ui-ux; do
      if [ "$client" = codex ]; then
        references_dir="$package/rules/$split_rule/references"
      else
        references_dir="$package/skills/rules/rules-$split_rule/references"
      fi
      if [ ! -d "$references_dir" ] || [ -z "$(find "$references_dir" -maxdepth 1 -name '*.md' -print -quit)" ]; then
        printf '%s is missing reference files for %s\n' "$package" "$split_rule" >&2
        exit 1
      fi
    done
```

- [ ] **Step 5: Run both**

Run: `bash scripts/test-platform-packages.sh` and `powershell -NoProfile -File scripts/test-platform-packages.ps1`.
Expected: both print `PASS four platform packages and six ... selections`.

- [ ] **Step 6: Commit**

```bash
git add scripts/test-platform-packages.ps1 scripts/test-platform-packages.sh
git commit -m "test: cover embedded general.md dedup and split-rule reference files"
```

---

### Task 14: Full-suite validation

**Files:** none (validation only).

- [ ] **Step 1: Rebuild from a clean state**

Run: `bash scripts/build.sh` (and `powershell -NoProfile -File scripts/build.ps1` if PowerShell is available in this environment).
Expected: `PASS build: codex-windows, claude-windows, codex-linux, claude-linux` on both.

- [ ] **Step 2: Run every test script and the doctor**

Run, in order: `scripts/test-managed-install.*`, `scripts/test-build-validation.*`, `scripts/test-install-guards.*`, `scripts/test-plugin-selection.*`, `scripts/test-platform-packages.*`, `scripts/doctor.*` — both the `.sh` and (where a PowerShell runtime is available) `.ps1` variant of each.
Expected: every one prints its `PASS ...` line and exits 0; `doctor` may print `WARN` lines about locally modified managed files (pre-existing, unrelated to this plan) but must not print `FAIL`.

- [ ] **Step 3: Dry-run install and update once more, with and without `-Summary`**

Run: `bash scripts/install.sh --dry-run --client both --platform linux`, `bash scripts/install.sh --dry-run --summary --client both --platform linux`, `bash scripts/update.sh --dry-run --client both --platform linux`, `bash scripts/update.sh --dry-run --summary --client both --platform linux` (plus PowerShell equivalents where available).
Expected: all four exit 0 with `PASS install dry-run`/`PASS update dry-run`; `--summary` output is visibly shorter.

- [ ] **Step 4: Read through the three split rule files once more, end to end**

Read `shared/rules/angular/index.md` + every file under `shared/rules/angular/references/`, then the same for `wpf` and `ui-ux`. Confirm every bullet from the pre-split files is present exactly once and unchanged in wording (this is the final check against silent content loss from Tasks 6-8; the build/tests can only catch structural problems, not a dropped bullet).

- [ ] **Step 5: Report to the user**

Summarize: what changed (the 5 spec areas), what's now stale but intentionally not auto-edited (check `README.md`/`docs/*.md` for any mention of `-UpdatePlugins`-style flags or the old rule/skill file layout that this plan makes inaccurate — e.g. `docs/configuration.md`'s "Codex keeps rules as files and loads only applicable focused rules" and "general.md ships as an always-applied rule file (its content is also embedded directly in CLAUDE.md)" sentences are now incomplete for Codex — flag `docs/configuration.md`, `docs/skills.md`, and `README.md`'s "Configuration" section as needing a human-approved doc update, do not edit them automatically), and ask whether to commit (this plan's per-task commits are local; nothing is pushed, and whether to squash/push is the user's call per this repo's git rules).
