#!/bin/bash
# Checks that the burn-down page can be trusted, as a reviewer would by
# hand after each regenerate: freshness, sums, an independent recount, a
# sample of adopter sites, and C names to headers and code. No quota, no
# network. Writes .build/api-burndown/verify.md and exits non-zero on a
# fail. regenerate.sh runs it at its end. See README.md in this directory,
# "Verify".
#
#   Utilities/api-burndown/verify.sh                 # the last run's burndown.json and page
#   Utilities/api-burndown/verify.sh --sample all    # every site and declaration, not 25 of each
#   Utilities/api-burndown/verify.sh --seed 12345    # the sample of the run whose report gives that seed
#
# Options (scripts/verify.py --help): --sample N|all, --seed S, --max-misses K,
# --fetch-age DAYS.
#
# Environment, as regenerate.sh reads it:
#   API_BURNDOWN_OUT         burndown.json's directory, where verify.md goes
#                            (default .build/api-burndown)
#   API_BURNDOWN_PAGE        the page (default Prototype/Burndown/burndown.html)
#   API_BURNDOWN_DELTA       api-delta's output (default: the one burndown.json records)
#   API_BURNDOWN_SNAPSHOTS   the api-graph snapshot store (default ../api-graph-snapshots
#                            beside the repository), for the graph if burndown.json's
#                            has been replaced since
#   API_BURNDOWN_COVERAGE_RESULTS  the coverage tools' results store, for the SDK
#                            vocabulary if burndown.json's is gone (default ../coverage-results)
#   API_BURNDOWN_VOCAB       a vocabulary file
#   API_BURNDOWN_UPSTREAM    a ref the base should contain (default origin/main); empty
#                            skips it
#
# It reads git (never fetches), the SDK, and the adopters' clones that the
# graph names; it writes only verify.md.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"
SIBLINGS="$(dirname "$REPO")"

fail() { echo "error: $1" >&2; exit 1; }
abs() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$PWD/$1" ;; esac; }

for arg in "$@"; do
  case "$arg" in
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
  esac
done

OUT="$(abs "${API_BURNDOWN_OUT:-$REPO/.build/api-burndown}")"
PAGE="$(abs "${API_BURNDOWN_PAGE:-$REPO/Prototype/Burndown/burndown.html}")"
STORE="${API_BURNDOWN_SNAPSHOTS-$SIBLINGS/api-graph-snapshots}"
COVERAGE="${API_BURNDOWN_COVERAGE_RESULTS-$SIBLINGS/coverage-results}"
UPSTREAM="${API_BURNDOWN_UPSTREAM-origin/main}"

[ -f "$OUT/burndown.json" ] || fail "no $OUT/burndown.json; run Utilities/api-burndown/regenerate.sh first"
# As regenerate.sh: write only into a directory it made.
[ -f "$OUT/.api-burndown-out" ] || fail "refusing to write into $OUT: it isn't api-burndown output"

args=(--repo "$REPO" --burndown "$OUT/burndown.json" --page "$PAGE" --report "$OUT/verify.md"
  --upstream "$UPSTREAM" --siblings "$SIBLINGS")
if [ -n "${API_BURNDOWN_DELTA:-}" ]; then args+=(--delta "$(abs "$API_BURNDOWN_DELTA")"); fi
if [ -n "$STORE" ]; then args+=(--store "$STORE"); fi
if [ -n "$COVERAGE" ]; then args+=(--coverage-results "$COVERAGE"); fi
if [ -n "${API_BURNDOWN_VOCAB:-}" ]; then args+=(--vocab "$API_BURNDOWN_VOCAB"); fi
python3 "$TOOL/scripts/verify.py" "${args[@]}" "$@"
