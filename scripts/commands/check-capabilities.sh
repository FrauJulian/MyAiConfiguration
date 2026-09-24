#!/usr/bin/env bash
set -euo pipefail

failed=false
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failed=true; }
require_command() {
  if command -v "$1" >/dev/null 2>&1; then pass "$1 available"; else fail "$1 is required"; fi
}
version_at_least() {
  awk -F. -v required="$2" 'BEGIN { split(required,r) } { split($1,v); if (v[1]+0 > r[1]+0 || (v[1]+0 == r[1]+0 && v[2]+0 >= r[2]+0)) exit 0; exit 1 }' <<<"$1"
}
check_version() {
  local name=$1 version=$2 required=$3
  if version_at_least "$version" "$required"; then pass "$name $version (minimum $required)"; else fail "$name $version is below minimum $required"; fi
}

check_version Bash "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" 4.3
require_command awk; require_command sed; require_command sha256sum
if command -v jq >/dev/null 2>&1; then pass 'jq available for Claude Bash status line'; else printf 'WARN jq unavailable; Claude Bash status line is disabled\n' >&2; fi
require_command python3
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 11))' >/dev/null 2>&1; then
  pass "Python $(python3 --version 2>&1 | awk '{print $2}') (minimum 3.11)"
else
  fail 'Python 3.11 or newer is required'
fi

if [ "$failed" = true ]; then printf 'Capability check: FAIL\n' >&2; exit 1; fi
printf 'Capability check: PASS\n'
