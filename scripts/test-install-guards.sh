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

if [ "$summary" = true ]; then printf 'Tests: PASS | install guards\n'; else printf 'PASS install guards: already-installed and not-installed detection\n'; fi
