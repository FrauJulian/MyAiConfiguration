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
    hash=$(printf '%s' "$hash" | tr '[:upper:]' '[:lower:]') # tolerate uppercase hashes from older manifests
    out_ref[$rel]=$hash
  done < "$path"
}

# write_managed_manifest <manifest-file> <assoc-array-name>
write_managed_manifest() {
  local path=$1
  local -n in_ref=$2
  mkdir -p "$(dirname -- "$path")"
  {
    printf 'path\tsha256\n'
    for rel in $(printf '%s\n' "${!in_ref[@]}" | sort); do
      printf '%s\t%s\n' "$rel" "${in_ref[$rel]}"
    done
  } > "$path"
}

# sync_managed_destination <source-dir> <destination-dir> <stamp> <ai-config-root> <shell-command> <powershell-command> <dry-run: true|false> [summary: true|false]
sync_managed_destination() {
  local source=$1 destination=$2 stamp=$3 ai_config_root=$4 shell_command=$5 powershell_command=$6 dry_run=$7 summary=${8:-false} flashbang_enabled=${9:-true}
  [ "$summary" = true ] || printf 'SOURCE %s -> %s\n' "$source" "$destination"
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
    if [ "$flashbang_enabled" = false ] && [[ "$relative" = settings.json || "$relative" = config.toml ]]; then
      content=$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/install-options.py" filter --path "$source_file" --flashbang false) || return
      needs_sub=true
    fi
    if [[ "$needs_sub" = true || "$content" == *'__AI_CONFIG_ROOT__'* || "$content" == *'__HOOK_COMMAND__'* || "$content" == *'__POWERSHELL_HOOK_COMMAND__'* || "$content" == *'__POWERSHELL_COMMAND__'* ]]; then
      needs_sub=true
      content=${content//__AI_CONFIG_ROOT__/$ai_config_root}
      content=${content//__HOOK_COMMAND__/$shell_command}
      content=${content//__POWERSHELL_HOOK_COMMAND__/$powershell_command}
      content=${content//__POWERSHELL_COMMAND__/$powershell_command}
      content=${content//__HOOK_SCRIPT__/flashbang.sh}
      content=${content//__POWERSHELL_HOOK_SCRIPT__/flashbang.sh}
      new_hash=$(sha256_of_string "$content")
    else
      new_hash=$(sha256_of_file "$source_file")
    fi
    if [ "$relative" = config.toml ] && [ -f "$target" ]; then
      local plugin_tables local_settings setting_name
      local_settings=$(awk '
        NR == 1 { sub(/^\357\273\277/, "") }
        /^[ \t]*\[/ { exit }
        /^[ \t]*(model|model_reasoning_effort)[ \t]*=/ { print }
      ' "$target")
      if [ -n "$local_settings" ]; then
        while IFS= read -r setting; do
          setting_name=${setting%%=*}
          setting_name=${setting_name//[[:space:]]/}
          content=$(printf '%s\n' "$content" | sed "/^[[:space:]]*$setting_name[[:space:]]*=/d")
        done <<< "$local_settings"
        if printf '%s\n' "$content" | grep -qE '^[[:blank:]]*\['; then
          content=$(printf '%s\n' "$content" | awk -v settings="$local_settings" '
            !inserted && /^[ \t]*\[/ { print settings; inserted = 1 }
            { print }
          ')
        else
          content="$content"$'\n'"$local_settings"
        fi
        needs_sub=true
        new_hash=$(sha256_of_string "$content")
      fi
      plugin_tables=$(awk '
        /^[ \t]*\[/ { preserve = ($0 ~ /^[ \t]*\[(plugins|marketplaces)(\.|\])/) }
        preserve { print }
      ' "$target")
      if [ -n "$plugin_tables" ]; then
        if printf '%s\n' "$content" | grep -Eq '^[[:blank:]]*\[(plugins|marketplaces)(\.|\])'; then
          printf 'Cannot overwrite local plugin configuration with generated plugin tables.\n' >&2
          return 1
        fi
        content="$content"$'\n\n'"$plugin_tables"$'\n'
        needs_sub=true
        new_hash=$(sha256_of_string "$content")
      fi
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
