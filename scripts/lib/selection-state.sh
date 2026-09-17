#!/usr/bin/env bash

read_update_selection() {
  local saved key value
  saved=$(python3 "$root/scripts/lib/selection-state.py" read --home "$home_path" --manifest "$root/adapters/plugins.tsv" --format tsv) || return
  selected_plugins=()
  deselected_plugins=()
  while IFS=$'\t' read -r key value; do
    value=${value%$'\r'}
    case "$key" in
      shell) [ -n "$shell" ] || shell=$value ;;
      client) [ -n "$client" ] || client=$value ;;
      update_agents) update_agents=$value ;;
      flashbang) flashbang=$value ;;
      semantic_retrieval) semantic_retrieval=$value ;;
      selected) selected_plugins+=("$value") ;;
      deselected) deselected_plugins+=("$value") ;;
    esac
  done <<< "$saved"
}

save_update_selection() {
  python3 "$root/scripts/lib/selection-state.py" write --home "$home_path" --manifest "$root/adapters/plugins.tsv" \
    --shell "$shell" --client "$client" --update-agents "$update_agents" --flashbang "$flashbang" --semantic-retrieval "${semantic_retrieval:-false}" \
    --selected "${selected_plugins[@]}" --deselected "${deselected_plugins[@]}"
}
