#!/usr/bin/env bash
set -euo pipefail

skip_external=false
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-external) skip_external=true; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
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
require_command awk; require_command sed; require_command sha256sum; require_command git; require_command jq
require_command python3
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 11))' >/dev/null 2>&1; then
  pass "Python $(python3 --version 2>&1 | awk '{print $2}') (minimum 3.11)"
else
  fail 'Python 3.11 or newer is required'
fi

for path in AI-Instructions.md shared/rules shared/skills shared/agents adapters scripts/build.sh scripts/build.ps1 scripts/install.sh scripts/install.ps1 scripts/update.sh scripts/update.ps1 scripts/validate-config.py; do
  [ -e "$root/$path" ] && pass "repository path $path" || fail "repository path is missing: $path"
done

if [ "$skip_external" = false ]; then
  for client in codex claude; do
    if command -v "$client" >/dev/null 2>&1 && "$client" --version >/dev/null 2>&1; then pass "$client CLI available"; else fail "$client CLI is required for the default setup"; fi
  done
  remote=$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)
  if [ -z "$remote" ]; then
    fail 'Git origin remote is required for network capability checks'
  elif git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 -C "$root" ls-remote --heads "$remote" >/dev/null 2>&1; then
    pass 'network access to the Git origin'
  else
    fail 'network access to Git origin failed'
  fi
fi

if [ "$failed" = true ]; then printf 'Capability check: FAIL\n' >&2; exit 1; fi
printf 'Capability check: PASS\n'
