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
. "$root/scripts/lib/plugins.sh"

# shellcheck disable=SC2034
names=(A B C)
checked=(true false true)
toggle_log=$(mktemp "$root/.plugin-toggle.XXXXXX")
test_home=$(mktemp -d "$root/.context7-test.XXXXXX")
trap 'rm -f -- "$toggle_log" "$test_home/.mcporter/mcporter.json"; rmdir -- "$test_home/.mcporter" "$test_home" 2>/dev/null || true' EXIT
read_plugin_toggle_selection names checked <<< $'1\n2\ndone' > "$toggle_log"
[ "$summary" = true ] || cat "$toggle_log"

[ "${checked[0]}" = false ] || { printf 'Toggling checked entry 1 must uncheck it.\n' >&2; exit 1; }
[ "${checked[1]}" = true ] || { printf 'Toggling unchecked entry 2 must check it.\n' >&2; exit 1; }
[ "${checked[2]}" = true ] || { printf 'Entry 3 was never toggled and must stay unchanged.\n' >&2; exit 1; }

read_plugin_toggle_selection names checked <<< '' > "$toggle_log"
[ "${checked[0]}" = false ] && [ "${checked[1]}" = true ]
test_plugin_output() {
  printf 'download progress\nWARN test warning\n'
  [ "$1" != fail ]
}
compact=$(summary=true run_plugin_command false test_plugin_output success)
[ "$compact" = 'WARN test warning' ] || { printf 'Plugin summary lost warnings or leaked progress.\n' >&2; exit 1; }
if diagnostics=$(summary=true run_plugin_command false test_plugin_output fail 2>&1); then
  printf 'Plugin failure must fail.\n' >&2
  exit 1
fi
[[ "$diagnostics" == *'download progress'* ]] && [[ "$diagnostics" == *'WARN test warning'* ]]
mkdir -p "$test_home/.mcporter"
printf '%s\n' '{"mcpServers":{"context7":{"baseUrl":"https://mcp.context7.com/mcp"}}}' > "$test_home/.mcporter/mcporter.json"
home_path=$test_home
plugin_installed() { return 1; }
selected=()
deselected=()
select_configured_plugins "$root" codex Update true selected deselected
[[ " ${selected[*]} " == *' Context7 '* ]] || { printf 'MCPorter Context7 must start checked when updating.\n' >&2; exit 1; }
printf '%s\n' '{"mcpServers":{"context7":{"baseUrl":"https://example.invalid/mcp"}}}' > "$test_home/.mcporter/mcporter.json"
select_configured_plugins "$root" codex Update true selected deselected
[[ " ${deselected[*]} " == *' Context7 '* ]] || { printf 'A different MCPorter server must not select Context7.\n' >&2; exit 1; }
# shellcheck disable=SC2034
selected=()
plugin_installed() { printf 'Empty selection must not query installed plugins.\n' >&2; exit 1; }
run_plugin_command() { printf 'Empty selection must not run commands.\n' >&2; exit 1; }
install_configured_plugins "$root" both false false selected false
uninstall_deselected_plugins "$root" both false selected false
if read_plugin_toggle_selection names checked </dev/null > "$toggle_log" 2>&1; then
  printf 'Closed input must fail instead of looping.\n' >&2
  exit 1
fi

if [ "$summary" = true ]; then printf 'Tests: PASS | plugin selection\n'; else printf 'PASS plugin toggle selection: toggle and confirm\n'; fi
