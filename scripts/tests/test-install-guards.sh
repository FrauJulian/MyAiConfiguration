#!/usr/bin/env bash
set -euo pipefail
summary=false
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) summary=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
. "$root/scripts/lib/manifest.sh"
. "$root/scripts/lib/install-targets.sh"

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

installed="$work/installed"
missing="$work/missing"
mkdir -p "$installed"
: > "$(manifest_path "$installed")"

any_manifest_present "$installed" "$missing" || { printf 'Expected an installed destination to be detected.\n' >&2; exit 1; }
! any_manifest_present "$missing" || { printf 'A destination without a manifest must not count as installed.\n' >&2; exit 1; }
! all_manifests_present "$installed" "$missing" || { printf 'Update guard must fail when any selected destination is not installed.\n' >&2; exit 1; }
all_manifests_present "$installed" || { printf 'Update guard must pass when every selected destination is installed.\n' >&2; exit 1; }

# QMD prompt: Auto maps benchmark exit codes; No never calls the benchmark.
(
  home_path=$(mktemp -d)
  . "$root/scripts/lib/install-options.sh"
  test_qmd_device() { return 1; }
  [ "$(printf 'a\n' | read_semantic_retrieval_option false 2>/dev/null)" = false ] || { echo 'Auto unsuitable must yield false' >&2; exit 1; }
  test_qmd_device() { return 0; }
  [ "$(printf 'a\n' | read_semantic_retrieval_option false 2>/dev/null)" = true ] || { echo 'Auto suitable must yield true' >&2; exit 1; }
  test_qmd_device() { echo 'must not run' >&2; exit 9; }
  [ "$(printf 'n\n' | read_semantic_retrieval_option true 2>/dev/null)" = false ] || { echo 'No must yield false' >&2; exit 1; }
  printf 'n\n' | read_semantic_retrieval_option true 2>&1 >/dev/null | grep -q 'Enable local QMD search models' || { echo 'prompt text changed' >&2; exit 1; }
  rm -rf -- "$home_path"
)

if [ "$summary" = true ]; then printf 'Tests: PASS | install guards\n'; else printf 'PASS install guards: already-installed and not-installed detection\n'; fi
