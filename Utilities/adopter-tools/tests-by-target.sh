#!/bin/bash
# Run a package's tests one test target at a time, or one suite at a time,
# each under watchdog.py, for a test run that hangs or runs too long as a whole.
#
#   tests-by-target.sh [--idle S] [--limit S] [--suites] PACKAGE LOGDIR [TARGET...] [-- SWIFT ARGS...]
#
# Without TARGETs, every test target of PACKAGE's manifest. Each runs as
# `swift test --skip-build --filter '^TARGET\.' SWIFT ARGS` (build first, with
# the same SWIFT ARGS: step.sh --no-test), logged to LOGDIR/TARGET.log, and
# prints `TARGET exit N` with the Swift Testing and XCTest totals; the lines
# are also in LOGDIR/summary.txt. With --suites, each suite of the TARGETs
# (from `swift test list`) runs on its own instead, logged to
# LOGDIR/TARGET.SUITE.log. A run is stopped after --idle seconds without
# output (default 600) or --limit seconds in all (default 3600), and exits 124.
# Compare two runs' logs with outcomes.sh. SwiftPM runs with --disable-sandbox,
# as in step.sh (ADOPTER_TOOLS_SANDBOX=1 leaves it off).
set -uo pipefail

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd -P)"
idle=600; limit=3600; suites=0
while [ $# -gt 0 ]; do
  case "$1" in
    --idle) idle=$2; shift 2 ;;
    --limit) limit=$2; shift 2 ;;
    --suites) suites=1; shift ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done
[ $# -ge 2 ] || usage
pkg="$(cd "$1" && pwd -P)" || exit 1
mkdir -p "$2" && logs="$(cd "$2" && pwd -P)" || exit 1
shift 2
targets=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do targets+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
sandbox=(--disable-sandbox)
[ -n "${ADOPTER_TOOLS_SANDBOX:-}" ] && sandbox=()
cd "$pkg" || exit 1

if [ ${#targets[@]} -eq 0 ]; then
  list="$(swift package ${sandbox[@]+"${sandbox[@]}"} dump-package 2>/dev/null \
    | python3 -c 'import json, sys; print("\n".join(t["name"] for t in json.load(sys.stdin)["targets"] if t["type"] == "test"))')" \
    || { echo "tests-by-target.sh: can't read $pkg's manifest (swift package dump-package)" >&2; exit 1; }
  while IFS= read -r t; do [ -n "$t" ] && targets+=("$t"); done <<< "$list"
fi
[ ${#targets[@]} -gt 0 ] || { echo "tests-by-target.sh: no test targets" >&2; exit 1; }

runs=()        # "LABEL FILTER"
if [ $suites -eq 1 ]; then
  listing="$(swift test list --skip-build ${sandbox[@]+"${sandbox[@]}"} "$@" 2>/dev/null)" \
    || { echo "tests-by-target.sh: swift test list failed; build first" >&2; exit 1; }
  for t in "${targets[@]}"; do
    while IFS= read -r s; do
      [ -n "$s" ] && runs+=("$s ^${s//./\\.}/")
    done <<< "$(printf '%s\n' "$listing" | grep -E "^$t\." | sed -E 's|/.*||' | sort -u)"
  done
else
  for t in "${targets[@]}"; do runs+=("$t ^$t\\."); done
fi

: > "$logs/summary.txt"
for run in "${runs[@]}"; do
  label="${run%% *}"; filter="${run#* }"
  log="$logs/$label.log"
  rm -f "$log"
  python3 "$here/watchdog.py" "$log" "$idle" "$limit" \
    swift test --skip-build ${sandbox[@]+"${sandbox[@]}"} --filter "$filter" "$@"
  status=$?
  totals="$(LC_ALL=C grep -aE '^[^ ]+ Test run with [0-9]+ tests? ' "$log" | tail -1 | cut -c1-120)"
  xctest="$(LC_ALL=C grep -aE "Test Suite '(All tests|Selected tests)' (passed|failed)" -A1 "$log" | grep -aE 'Executed' | tail -1 | sed -E 's/^[[:space:]]+//')"
  line="$label exit $status  ${totals}${xctest:+  XCTest: $xctest}"
  echo "$line" | tee -a "$logs/summary.txt"
done
