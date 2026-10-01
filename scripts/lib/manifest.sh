#!/usr/bin/env bash
# Managed-file manifest: tracks every file this setup previously installed into a
# destination so a later run can detect stale files (removed from the source) or
# locally modified files (changed on disk since the last install) without ever
# touching a file it never installed itself.

sha256_of_file() {
  sha256sum -- "$1" | cut -d' ' -f1
}

sha256_of_string() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

manifest_path() {
  printf '%s/.ai-config-manifest.tsv' "$1"
}

managed_backup_root() {
  local destination=$1
  if [ "${destination##*/}" = skills ] && [ "$(basename -- "$(dirname -- "$destination")")" = .agents ]; then
    managed_target "$(dirname -- "$destination")" '.ai-config-skill-backups'
  else
    managed_target "$destination" backups
  fi
}

managed_target() {
  local destination=$1 relative=$2 component target probe
  target=$destination
  [[ -n "$relative" && "$relative" != /* && "$relative" != */ && "$relative" != *//* && "$relative" != *\\* && "$relative" != *:* && "$relative" != *$'\t'* && "$relative" != *$'\r'* && "$relative" != *$'\n'* ]] || { printf 'Invalid managed path: %s\n' "$relative" >&2; return 1; }
  local -a parts
  IFS=/ read -r -a parts <<< "$relative"
  for component in "${parts[@]}"; do
    [[ -n "$component" && "$component" != . && "$component" != .. ]] || { printf 'Invalid managed path: %s\n' "$relative" >&2; return 1; }
    target+=/$component
  done
  probe=$target
  while :; do
    [ ! -L "$probe" ] || { printf 'Managed path contains a link: %s\n' "$probe" >&2; return 1; }
    [ "$probe" != "$destination" ] || break
    probe=$(dirname -- "$probe")
  done
  printf '%s' "$target"
}

# read_managed_manifest <manifest-file> <assoc-array-name>
read_managed_manifest() {
  local path=$1
  local -n out_ref=$2
  out_ref=()
  [ -f "$path" ] || return 0
  local rel hash first=1
  while IFS=$'\t' read -r rel hash; do
    hash=${hash%$'\r'} # tolerate a CRLF-terminated manifest (read only strips the trailing \n)
    if [ "$first" = 1 ]; then
      first=0
      rel=${rel#$'\xef\xbb\xbf'} # tolerate a UTF-8 BOM on the header line
      [ "$rel" = path ] && continue
    fi
    [ -n "$rel" ] || continue
    managed_target "$(dirname -- "$path")" "$rel" > /dev/null || return 1
    hash=$(printf '%s' "$hash" | tr '[:upper:]' '[:lower:]') # tolerate uppercase hashes from older manifests
    # shellcheck disable=SC2034
    out_ref[$rel]=$hash
  done < "$path"
}

# write_managed_file <target> <content-file> [source-file]
# Replace target atomically: write a sibling temporary file, then rename it over the target.
write_managed_file() {
  local target=$1 content_file=$2 source_file=${3:-} temporary mode
  temporary=$(mktemp "$(dirname -- "$target")/.ai-config-write.XXXXXX") || return 1
  mode=$(printf '%o' $((0666 & ~$(umask))))
  [ -z "$source_file" ] || [ ! -x "$source_file" ] || mode=$(printf '%o' $((0777 & ~$(umask))))
  { cat -- "$content_file" > "$temporary" && chmod "$mode" "$temporary" && mv -f -- "$temporary" "$target"; } || { rm -f -- "$temporary"; return 1; }
}

# write_managed_manifest <manifest-file> <assoc-array-name>
write_managed_manifest() {
  local path=$1 content
  local -n in_ref=$2
  mkdir -p "$(dirname -- "$path")"
  content=$(mktemp) || return 1
  {
    printf 'path\tsha256\n'
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      printf '%s\t%s\n' "$rel" "${in_ref[$rel]}"
    done < <(printf '%s\n' "${!in_ref[@]}" | sort)
  } > "$content" && write_managed_file "$path" "$content"
  local status=$?
  rm -f -- "$content"
  return "$status"
}

# acquire_managed_lock <destination>: create <destination>/.ai-config.lock exclusively.
acquire_managed_lock() {
  local lock="$1/.ai-config.lock" owner holder_shell holder_host holder_pid
  mkdir -p -- "$1"
  owner="bash $(uname -n) $$"
  if (set -o noclobber; printf '%s\n' "$owner" > "$lock") 2>/dev/null; then return 0; fi
  read -r holder_shell holder_host holder_pid < "$lock" 2>/dev/null || true
  # ponytail: only same-shell, same-host owners are checked for staleness; other stale locks need manual removal.
  if [ "$holder_shell" = bash ] && [ "$holder_host" = "$(uname -n)" ] && [[ "$holder_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
    rm -f -- "$lock"
    if (set -o noclobber; printf '%s\n' "$owner" > "$lock") 2>/dev/null; then return 0; fi
  fi
  printf 'Another installation or update holds %s; wait for it to finish, or remove the file if no update is running.\n' "$lock" >&2
  return 1
}

# sync_managed_destination: same arguments as run_managed_sync; holds the destination lock unless dry-running.
sync_managed_destination() {
  [ "$7" != true ] || { run_managed_sync "$@"; return; }
  acquire_managed_lock "$2" || return 1
  local status=0
  run_managed_sync "$@" || status=$?
  rm -f -- "$2/.ai-config.lock"
  return "$status"
}

# run_managed_sync <source-dir> <destination-dir> <stamp> <ai-config-root> <shell-command> <powershell-command> <dry-run: true|false> [summary: true|false] [flashbang] [claude-concurrency] [statusline]
run_managed_sync() {
  local source=$1 destination=$2 stamp=$3 ai_config_root=$4 shell_command=$5 powershell_command=$6 dry_run=$7 summary=${8:-false} flashbang_enabled=${9:-true} claude_concurrency=${10:-5} statusline_enabled=${11:-true}
  [ "$summary" = true ] || printf 'SOURCE %s -> %s\n' "$source" "$destination"
  local manifest
  manifest=$(manifest_path "$destination")
  managed_target "$destination" '.ai-config-manifest.tsv' > /dev/null || return 1
  declare -A old_manifest
  read_managed_manifest "$manifest" old_manifest || return 1
  declare -A new_manifest
  local created=0 updated=0 unchanged=0 removed=0 warned=0
  local backup_root old_backup_root
  backup_root=$(managed_backup_root "$destination") || return 1
  old_backup_root=$(managed_target "$destination" backups) || return 1
  if [ "$backup_root" != "$old_backup_root" ] && [ -e "$old_backup_root" ]; then
    if [ "$dry_run" = true ]; then
      [ "$summary" = true ] || printf 'DRYRUN MOVE %s -> %s\n' "$old_backup_root" "$backup_root"
    else
      mkdir -p -- "$backup_root"
      local legacy_target
      legacy_target="$backup_root/legacy-$RANDOM-$RANDOM"
      while [ -e "$legacy_target" ]; do legacy_target="$backup_root/legacy-$RANDOM-$RANDOM"; done
      mv -- "$old_backup_root" "$legacy_target" || return 1
    fi
  fi

  while IFS= read -r -d '' source_file; do
    local relative target content needs_sub new_hash exists current_hash action backup
    relative=${source_file#"$source/"}
    if [ "${destination##*/}" = .codex ] && [[ "$relative" = skills/* ]]; then continue; fi
    if [ "${destination##*/}" = .claude ] && [ "$statusline_enabled" = false ] && [[ "$relative" = statusline/* ]]; then continue; fi
    target=$(managed_target "$destination" "$relative") || return 1
    content=$(cat -- "$source_file" && printf '\034') || return
    content=${content%$'\034'}
    needs_sub=false
    if { [ "$flashbang_enabled" = false ] || [ "$statusline_enabled" = false ]; } && [[ "$relative" = settings.json || "$relative" = config.toml ]]; then
      content=$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" filter --path "$source_file" --flashbang "$flashbang_enabled" --statusline "$statusline_enabled" && printf '\034') || return
      content=${content%$'\034'}
      needs_sub=true
    fi
    if [[ "$needs_sub" = true || "$content" == *'__AI_CONFIG_ROOT__'* || "$content" == *'__HOOK_COMMAND__'* || "$content" == *'__POWERSHELL_HOOK_COMMAND__'* || "$content" == *'__POWERSHELL_COMMAND__'* || "$content" == *'__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__'* ]]; then
      needs_sub=true
      content=${content//__AI_CONFIG_ROOT__/$ai_config_root}
      content=${content//__HOOK_COMMAND__/$shell_command}
      content=${content//__POWERSHELL_HOOK_COMMAND__/$powershell_command}
      content=${content//__POWERSHELL_COMMAND__/$powershell_command}
      content=${content//__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__/$claude_concurrency}
      content=${content//__HOOK_SCRIPT__/flashbang.sh}
      content=${content//__POWERSHELL_HOOK_SCRIPT__/flashbang.sh}
      new_hash=$(sha256_of_string "$content")
    else
      new_hash=$(sha256_of_file "$source_file")
    fi
    if [ "$relative" = config.toml ] && [ -f "$target" ]; then
      content=$(printf '%s' "$content" | python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" merge-toml --current "$target" --statusline "$statusline_enabled") || return
      needs_sub=true
      new_hash=$(sha256_of_string "$content")
    fi
    if [ "$relative" = settings.json ] && [ -f "$target" ]; then
      content=$(printf '%s' "$content" | python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" merge-json --current "$target") || return
      needs_sub=true
      new_hash=$(sha256_of_string "$content")
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
      backup=$(managed_target "$backup_root" "$stamp/$relative") || return 1
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
      local rendered
      rendered=$(mktemp) || return 1
      printf '%s' "$content" > "$rendered" && write_managed_file "$target" "$rendered" "$source_file" || { rm -f -- "$rendered"; return 1; }
      rm -f -- "$rendered"
    else
      write_managed_file "$target" "$source_file" "$source_file" || return 1
    fi
    [ "$summary" = true ] || printf '%s %s\n' "$action" "$target"
    [ "$action" = CREATE ] && created=$((created + 1)) || updated=$((updated + 1))
  done < <(find "$source" -type f -print0)

  local relative target current_hash backup
  for relative in "${!old_manifest[@]}"; do
    [ -z "${new_manifest[$relative]+x}" ] || continue
    target=$(managed_target "$destination" "$relative") || return 1
    [ -f "$target" ] || continue
    if [ "$dry_run" = true ]; then
      [ "$summary" = true ] || printf 'DRYRUN REMOVE %s\n' "$target"
      removed=$((removed + 1))
      continue
    fi
    backup=$(managed_target "$backup_root" "$stamp/$relative") || return 1
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

  if [ "$dry_run" != true ]; then write_managed_manifest "$manifest" new_manifest || return 1; fi
  if [ "$summary" = true ]; then
    printf 'SYNC %s: %s created, %s updated, %s unchanged, %s removed, %s warnings\n' "$destination" "$created" "$updated" "$unchanged" "$removed" "$warned"
  fi
}
