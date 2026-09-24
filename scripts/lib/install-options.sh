#!/usr/bin/env bash
# shellcheck disable=SC2154

read_install_boolean() {
  local prompt=$1 default=$2 hint=y/N answer
  [ "$default" = false ] || hint=Y/n
  while :; do
    printf '%s [%s] ' "$prompt" "$hint" >&2
    IFS= read -r answer || { printf 'Input ended before install options were confirmed.\n' >&2; return 1; }
    answer=${answer%$'\r'}
    case "$answer" in
      '') printf '%s\n' "$default"; return ;;
      y|Y|yes|Yes|YES) printf 'true\n'; return ;;
      n|N|no|No|NO) printf 'false\n'; return ;;
    esac
  done
}

read_install_options() {
  flashbang=true
  statusline=true
  semantic_retrieval=false
  local saved key value
  if [ -f "$home_path/.my-ai-configuration/selection.json" ]; then
    if saved=$(python3 "$root/scripts/lib/selection-state.py" read --home "$home_path" --manifest "$root/adapters/plugins.tsv" --format tsv --allow-legacy); then
      while IFS=$'\t' read -r key value; do
        value=${value%$'\r'}
        case "$key" in flashbang) flashbang=$value ;; statusline) statusline=$value ;; semantic_retrieval) semantic_retrieval=$value ;; esac
      done <<< "$saved"
    else
      printf 'WARN Saved options could not be read; confirm new options below.\n' >&2
    fi
  fi
  [ "$dry_run" = false ] || return 0
  flashbang=$(read_install_boolean 'Enable the Flashbang notification hook?' "$flashbang") || return
  statusline=$(read_install_boolean 'Apply the custom status line?' "$statusline") || return
  semantic_retrieval=$(read_semantic_retrieval_option "$semantic_retrieval") || return
}

read_semantic_retrieval_option() {
  local default=$1 hint=y/N/a answer
  [ "$default" = false ] || hint=Y/n/a
  while :; do
    printf 'Enable Qwen3 embedding and reranking semantic retrieval? [%s] ' "$hint" >&2
    IFS= read -r answer || { printf 'Input ended before semantic retrieval was confirmed.\n' >&2; return 1; }
    answer=${answer%$'\r'}
    case "$answer" in
      '') printf '%s\n' "$default"; return ;;
      y|Y|yes|Yes|YES) printf 'true\n'; return ;;
      n|N|no|No|NO) printf 'false\n'; return ;;
      a|A|auto|Auto|AUTO)
        if test_semantic_retrieval_device "$root" "$home_path"; then printf 'true\n'; return; else status=$?; fi
        [ "$status" -eq 1 ] && { printf 'false\n'; return; }
        return "$status"
        ;;
    esac
  done
}
