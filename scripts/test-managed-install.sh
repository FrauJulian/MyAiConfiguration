#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. "$root/scripts/lib/manifest.sh"

work=$(mktemp -d)
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT

source_dir="$work/source"
destination="$work/destination"
mkdir -p "$source_dir"
printf 'A' > "$source_dir/a.md"
printf 'B' > "$source_dir/b.md"
printf 'C' > "$source_dir/c.md"

out1=$(sync_managed_destination "$source_dir" "$destination" run1 "$destination" bash bash false)
[ "$(printf '%s\n' "$out1" | grep -c '^CREATE')" -eq 3 ] || { printf 'Expected three CREATE lines on first install:\n%s\n' "$out1" >&2; exit 1; }

out2=$(sync_managed_destination "$source_dir" "$destination" run2 "$destination" bash bash false)
[ -z "$(printf '%s\n' "$out2" | grep -v '^UNCHANGED' | grep -v '^SOURCE ')" ] || { printf 'Second identical install was not a no-op:\n%s\n' "$out2" >&2; exit 1; }
[ ! -d "$destination/backups/run2" ] || { printf 'Idempotent install must not create a backup.\n' >&2; exit 1; }

printf 'mine' > "$destination/foreign.md"

rm -f "$source_dir/b.md" "$source_dir/c.md"
printf 'locally changed' > "$destination/c.md"

out3=$(sync_managed_destination "$source_dir" "$destination" run3 "$destination" bash bash false)
printf '%s\n' "$out3" | grep -q '^REMOVE .*b\.md$' || { printf 'Expected b.md to be removed:\n%s\n' "$out3" >&2; exit 1; }
[ ! -f "$destination/b.md" ] || { printf 'b.md should have been removed.\n' >&2; exit 1; }
printf '%s\n' "$out3" | grep -q 'WARN .*c\.md.*changed locally' || { printf 'Expected c.md to be flagged as locally modified:\n%s\n' "$out3" >&2; exit 1; }
[ -f "$destination/c.md" ] || { printf 'A locally modified stale file must not be removed.\n' >&2; exit 1; }
[ "$(cat "$destination/c.md")" = 'locally changed' ] || { printf 'c.md content must be preserved exactly.\n' >&2; exit 1; }
[ "$(cat "$destination/foreign.md")" = 'mine' ] || { printf 'A file this setup never installed must never be touched.\n' >&2; exit 1; }
[ -f "$destination/backups/run3/b.md" ] || { printf 'b.md should have been backed up before removal.\n' >&2; exit 1; }
[ -f "$destination/backups/run3/c.md" ] || { printf 'c.md should have been backed up even though it was left in place.\n' >&2; exit 1; }

rm -f "$source_dir/a.md"
before_dry=$(find "$destination" -type f | sort)
out_dry=$(sync_managed_destination "$source_dir" "$destination" dry "$destination" bash bash true)
after_dry=$(find "$destination" -type f | sort)
[ "$before_dry" = "$after_dry" ] || { printf 'A dry run must not change the destination at all.\n' >&2; exit 1; }
printf '%s\n' "$out_dry" | grep -q '^DRYRUN REMOVE .*a\.md$' || { printf 'Dry run should report the planned removal without performing it:\n%s\n' "$out_dry" >&2; exit 1; }

out_summary=$(sync_managed_destination "$source_dir" "$destination" "summary" "" "" "" false true)
if printf '%s\n' "$out_summary" | grep -Eq '^(CREATE|UPDATE|UNCHANGED|BACKUP) '; then
  printf 'Summary mode must not print per-file lines: %s\n' "$out_summary" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$out_summary" | grep -c '^SYNC .* unchanged')" -ne 1 ]; then
  printf 'Summary mode must print exactly one SYNC tally line: %s\n' "$out_summary" >&2
  exit 1
fi

printf 'PASS managed manifest: idempotent, stale removal, modified-file protection, foreign files preserved, dry run side-effect free\n'
