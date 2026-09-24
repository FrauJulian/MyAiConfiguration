#!/usr/bin/env bash

sync_semantic_retrieval() {
  local root=$1 client=$2 home_path=$3 enabled=$4 dry_run=$5 update=$6 summary=${7:-false}
  [ "$enabled" = true ] || [ -f "$home_path/.my-ai-configuration/semantic-retrieval.json" ] || return 0
  local arguments=("$root/scripts/lib/semantic-retrieval.py" sync --root "$root" --home "$home_path" --client "$client" --enabled "$enabled")
  [ "$dry_run" != true ] || arguments+=(--dry-run)
  [ "$update" != true ] || arguments+=(--update)
  [ "$summary" != true ] || arguments+=(--summary)
  python3 "${arguments[@]}"
}

test_semantic_retrieval_device() {
  local root=$1 home_path=$2 summary=${3:-false}
  local arguments=("$root/scripts/lib/semantic-retrieval.py" benchmark --root "$root" --home "$home_path")
  [ "$summary" != true ] || arguments+=(--summary)
  local status
  if python3 "${arguments[@]}" >&2; then return 0; else status=$?; fi
  [ "$status" -eq 2 ] && return 1
  return 2
}
