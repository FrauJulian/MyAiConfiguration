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
(
  codex() { printf 'fixture warning\n' >&2; printf 'fixture 1.0\n'; return "$DOCTOR_TEST_CODE"; }
  export -f codex
  for DOCTOR_TEST_CODE in 0 7; do
    export DOCTOR_TEST_CODE
    if probe_output=$(bash "$root/scripts/commands/doctor.sh" --summary); then probe_status=0; else probe_status=$?; fi
    if [ "$DOCTOR_TEST_CODE" -eq 0 ]; then
      test "$probe_status" -eq 0
      printf '%s\n' "$probe_output" | grep -Eq '^Doctor: PASS \| [0-9]+ checks$'
    else
      test "$probe_status" -eq 1
      printf '%s\n' "$probe_output" | grep -Fq 'FAIL codex --version failed (exit 7): fixture warning'
      printf '%s\n' "$probe_output" | grep -Eq '^Doctor: FAIL \| [0-9]+ checks$'
    fi
  done
)
doctor_summary_output=$(bash "$root/scripts/commands/doctor.sh" --summary)
if printf '%s\n' "$doctor_summary_output" | grep -q '^PASS '; then
  printf 'Doctor summary mode must not print individual PASS lines.\n' >&2
  exit 1
fi
if ! printf '%s\n' "$doctor_summary_output" | grep -Eq '^Doctor: PASS \| [0-9]+ checks$'; then
  printf "Doctor summary mode must print one 'Doctor: PASS | N checks' line: %s\n" "$doctor_summary_output" >&2
  exit 1
fi
for entry_point in install update; do
  preview=$(bash "$root/scripts/commands/$entry_point.sh" --summary --dry-run --client both --shell bash)
  if printf '%s\n' "$preview" | grep -Eq '^(SOURCE|CREATE|UPDATE|UNCHANGED|BACKUP|DRYRUN|PASS) '; then
    printf '%s summary leaked per-item output.\n' "$entry_point" >&2
    exit 1
  fi
  printf '%s\n' "$preview" | grep -Eiq "^$entry_point: PASS"
done
printf '%s\n' "$doctor_summary_output" | grep '^WARN ' || true
if [ "$summary" = true ]; then printf 'Tests: PASS | command summaries\n'; else printf 'PASS doctor, install, and update summaries\n'; fi
