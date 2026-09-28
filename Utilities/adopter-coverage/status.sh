#!/bin/bash
# Regenerates Prototype/Status/STATUS.md: System's public API against main
# (api-delta's Summary and By-area table, copied verbatim), how far the
# adopters in ../adopters have moved off the Darwin module on their
# migrate-darwin branches (against each branch's merge base with main), and
# every SYSTEM-GAP marker they have, by interface, with what System covers
# now. It's cheap enough to rerun after every merge: api-delta runs again
# only when System's sources changed since its last run, and each package
# manifest is evaluated once. See README.md in this directory.
#
#   Utilities/adopter-coverage/status.sh
#
# Environment:
#   STATUS_ADOPTERS     the adopters' checkouts (default: adopters next to this worktree)
#   STATUS_BRANCH       each package's migration branch (default migrate-darwin)
#   STATUS_BASE         the branch it's compared with, at their merge base (default main)
#   STATUS_SYSTEM_NEXT  System's integration branch (default system-next)
#   STATUS_OUT          the report (default Prototype/Status/STATUS.md in this worktree)
#   STATUS_WORK         scratch and caches (default .build/status)
#   STATUS_API_DELTA=1  rerun api-delta even when its last run is current
#   STATUS_SWIFT        more `swift` executables to evaluate manifests with, colon-separated
#                       (installed toolchains are tried anyway, after the default one)
#   ADOPTER_COVERAGE_RESULTS  the results store, for its SDK vocabulary (optional)
#
# Only commits are read, here and in the packages' checkouts; the one file
# written outside STATUS_WORK is the report.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
. "$S/common.sh"

# The worktree this runs from, as with check.sh and api-delta.
REPO="$(git -C "$TOOL" rev-parse --show-toplevel 2>/dev/null)" || fail "run this from a checkout of swift-system"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"

ADOPTERS="$(abspath "${STATUS_ADOPTERS:-$REPO/../adopters}")"
[ -d "$ADOPTERS" ] || fail "no adopters at $ADOPTERS; set STATUS_ADOPTERS"
BRANCH="${STATUS_BRANCH:-migrate-darwin}"
BASE="${STATUS_BASE:-main}"
NEXT="${STATUS_SYSTEM_NEXT:-system-next}"
OUT="$(abspath "${STATUS_OUT:-$REPO/Prototype/Status/STATUS.md}")"
WORK="$(abspath "${STATUS_WORK:-$REPO/.build/status}")"
RESULTS="$(abspath "${ADOPTER_COVERAGE_RESULTS:-$REPO/../coverage-results}")"
CHECKOUTS=()
check_dir STATUS_WORK "$WORK"
mkdir -p "$WORK"

# api-delta, main against HEAD, into its own directory, so that a run with
# other refs elsewhere isn't replaced. Its last run stands when nothing it
# reads has changed since: the base commit is the same, and Sources/,
# Package.swift and the tool are as they were at the commit it reported on.
API="$WORK/api-delta"
base_commit="$(git -C "$REPO" rev-parse --verify "$BASE^{commit}")"
head_commit="$(git -C "$REPO" rev-parse --verify HEAD)"
current=""
if [ -z "${STATUS_API_DELTA:-}" ] && [ -f "$API/api-delta.json" ]; then
  read -r was_base was_head < <(python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))["meta"]
print(m["baseCommit"], m["headCommit"])' "$API/api-delta.json")
  if [ "$was_base" = "$base_commit" ] && git -C "$REPO" cat-file -e "$was_head^{commit}" 2>/dev/null \
      && git -C "$REPO" diff --quiet "$was_head" "$head_commit" -- Sources Package.swift Utilities/api-delta; then
    current=1
  fi
fi
if [ -n "$current" ]; then
  log "api-delta: its last run ($(git -C "$REPO" rev-parse --short "$was_head")) is current"
else
  log "api-delta: $BASE -> HEAD (about a minute)"
  (cd "$REPO" && BASE_REF="$BASE" HEAD_REF=HEAD API_DELTA_OUT="$API" API_DELTA_WORK="$WORK/api-delta-work" \
    "$REPO/Utilities/api-delta/regenerate.sh") > "$WORK/api-delta.log" 2>&1 \
    || fail "api-delta failed" "$WORK/api-delta.log"
fi

# adopter-coverage's SDK vocabulary, if a check.sh run has stored one.
VOCAB="$(ls -t "$RESULTS"/vocab/*.json.gz 2>/dev/null | head -1 || true)"

log "status: $ADOPTERS ($BRANCH against $BASE)"
python3 "$S/status.py" --repo "$REPO" --adopters "$ADOPTERS" --api-delta "$API" --out "$OUT" \
  --branch "$BRANCH" --base "$BASE" --system-next "$NEXT" --cache "$WORK/manifests" ${VOCAB:+--vocab "$VOCAB"}
