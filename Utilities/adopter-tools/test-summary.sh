#!/bin/bash
# Summarize a `swift test` log: the Swift Testing and XCTest totals, the count
# of each outcome (outcomes.sh), and the first failure lines.
#
#   test-summary.sh LOG [LINES]
#
# LINES (default 20) caps the failure lines: failed tests, `error:` lines,
# fatal errors, signals and crashed test processes, cut to 200 columns; not
# Swift Testing's detail lines (`↳ ...`).
set -euo pipefail
[ $# -ge 1 ] && [ -f "$1" ] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
log=$1
lines=${2:-20}
here="$(cd "$(dirname "$0")" && pwd -P)"
export LC_ALL=C
grep -aE '^[^ ]+ Test run with [0-9]+ tests? ' "$log" | tail -1 || true
grep -aE "Test Suite 'All tests' (passed|failed)" -A1 "$log" | grep -aE 'Executed' | tail -1 || true
if grep -aqE '^\[[0-9]+/[0-9]+\] Testing ' "$log"; then
  echo "XCTest in parallel: $(grep -aE '^\[[0-9]+/[0-9]+\] Testing ' "$log" | tail -1 | sed -E 's/^\[[0-9]+\/([0-9]+)\].*/\1/') tests listed"
fi
counts="$("$here/outcomes.sh" "$log" | cut -d' ' -f1 | sort | uniq -c | awk '{printf "%s %s, ", $2, $1}' | sed 's/, $//')"
echo "outcomes: ${counts:-none}"
{ grep -aE '^[^ ]+ Test .* failed after|error: |: error -|Fatal error|signal code|Exited with|unexpected signal' "$log" \
    | grep -avE '^[^ ]+ Test run with|^↳' || true; } | cut -c1-200 | head -"$lines"
