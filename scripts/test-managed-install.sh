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

plugin_state='  [marketplaces.ponytail]
    source_type = "git"
    source = "https://github.com/DietrichGebert/ponytail.git"
  [plugins."ponytail@ponytail"]
    enabled = true
  [plugins."disabled@market"]
    enabled = false'
printf "approvals_reviewer = 'auto_review'\n\n[tui]\n" > "$source_dir/config.toml"
printf "\357\273\277model = 'old'\nmodel_reasoning_effort = 'high'\napprovals_reviewer = 'user'\n%s\n[other]\nvalue = true\n" "$plugin_state" > "$destination/config.toml"
original_config=$(cat "$destination/config.toml")
sync_managed_destination "$source_dir" "$destination" plugins-dry "" "" "" true > /dev/null
[ "$(cat "$destination/config.toml")" = "$original_config" ] || { printf 'Dry run changed plugin configuration.\n' >&2; exit 1; }
sync_managed_destination "$source_dir" "$destination" plugins "" "" "" false > /dev/null
merged_config=$(cat "$destination/config.toml")
merged_config_normalized=${merged_config//$'\r'/}
plugin_state_normalized=${plugin_state//$'\r'/}
[[ "$merged_config_normalized" == *"$plugin_state_normalized"* ]] || { printf 'Updating config.toml must preserve local marketplace and plugin tables, including disabled plugins.\n' >&2; exit 1; }
[[ "$merged_config" == *"model = 'old'"* && "$merged_config" == *"model_reasoning_effort = 'high'"* && "$merged_config" == *"approvals_reviewer = 'auto_review'"* && "$merged_config" != *"approvals_reviewer = 'user'"* && "$merged_config" != *'[other]'* ]] || { printf 'Updating config.toml must preserve local model settings and enforce automatic review.\n' >&2; exit 1; }
[ "$(printf '%s\n' "$merged_config" | grep -n "model = 'old'" | cut -d: -f1)" -lt "$(printf '%s\n' "$merged_config" | grep -n '^\[tui\]$' | cut -d: -f1)" ] || { printf 'Model must remain in TOML root table.\n' >&2; exit 1; }
[ "$(printf '%s\n' "$merged_config" | grep -n "model_reasoning_effort = 'high'" | cut -d: -f1)" -lt "$(printf '%s\n' "$merged_config" | grep -n '^\[tui\]$' | cut -d: -f1)" ] || { printf 'Model effort must remain in TOML root table.\n' >&2; exit 1; }
[ "$(cat "$destination/backups/plugins/config.toml")" = "$original_config" ] || { printf 'Original plugin configuration must be backed up.\n' >&2; exit 1; }
sync_managed_destination "$source_dir" "$destination" plugins-repeat "" "" "" false > /dev/null
[ "$(cat "$destination/config.toml")" = "$merged_config" ] && [ ! -d "$destination/backups/plugins-repeat" ] || { printf 'Preserving plugin configuration must be idempotent.\n' >&2; exit 1; }

out_summary=$(sync_managed_destination "$source_dir" "$destination" "summary" "" "" "" false true)
if printf '%s\n' "$out_summary" | grep -Eq '^(CREATE|UPDATE|UNCHANGED|BACKUP) '; then
  printf 'Summary mode must not print per-file lines: %s\n' "$out_summary" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$out_summary" | grep -c '^SYNC .* unchanged')" -ne 1 ]; then
  printf 'Summary mode must print exactly one SYNC tally line: %s\n' "$out_summary" >&2
  exit 1
fi

generated="$work/generated"
package="$generated/codex-bash"
test_home="$work/home"
legacy="$test_home/.codex"
mkdir -p "$package/skills/example" "$legacy/skills/example"
printf 'managed skill' > "$package/skills/example/SKILL.md"
cp "$package/skills/example/SKILL.md" "$legacy/skills/example/SKILL.md"
printf 'customized' > "$legacy/skills/example/custom.md"
printf 'foreign' > "$legacy/skills/example/foreign.md"
declare -A legacy_manifest
legacy_manifest[skills/example/SKILL.md]=$(sha256_of_file "$legacy/skills/example/SKILL.md")
legacy_manifest[skills/example/custom.md]=$(printf '0%.0s' {1..64})
write_managed_manifest "$(manifest_path "$legacy")" legacy_manifest
mapfile -t targets < <(get_install_targets "$generated" "$test_home" bash codex)
[[ "${targets[0]}" = *"|$test_home/.agents/skills" ]] || { printf 'Canonical skills must be installed first.\n' >&2; exit 1; }
for target_pair in "${targets[@]}"; do
  sync_managed_destination "${target_pair%%|*}" "${target_pair#*|}" migrate "" "" "" false > /dev/null
done
[ -f "$test_home/.agents/skills/example/SKILL.md" ] && [ ! -f "$legacy/skills/example/SKILL.md" ] && [ -f "$legacy/backups/migrate/skills/example/SKILL.md" ] || { printf 'Skill migration must remove and back up the managed duplicate.\n' >&2; exit 1; }
[ -f "$legacy/skills/example/custom.md" ] && [ -f "$legacy/skills/example/foreign.md" ] || { printf 'Skill migration must preserve modified and foreign files.\n' >&2; exit 1; }
for target_pair in "${targets[@]}"; do
  sync_managed_destination "${target_pair%%|*}" "${target_pair#*|}" migrate-repeat "" "" "" false > /dev/null
done
[ ! -d "$legacy/backups/migrate-repeat" ] || { printf 'Skill migration must be idempotent.\n' >&2; exit 1; }
printf '__CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY__' > "$source_dir/concurrency.txt"
sync_managed_destination "$source_dir" "$destination" concurrency "" "" "" false false true 7 > /dev/null
[ "$(cat "$destination/concurrency.txt")" = 7 ] || { printf 'Standalone concurrency placeholder must be resolved.\n' >&2; exit 1; }

if [ "$summary" = true ]; then printf 'Tests: PASS | managed install\n'; else printf 'PASS managed manifest: idempotent, stale removal, modified-file protection, foreign files preserved, dry run side-effect free, skill migration\n'; fi
