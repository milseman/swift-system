#!/bin/bash
# Regenerates Prototype/Status/STATUS.md: System's public API against main
# (api-delta's Summary and By-area table, copied verbatim) and the symbols
# its release builds export (scripts/abi.py), how far the
# adopters in ../adopters have moved off the Darwin module on their
# migration branches (migrate-darwin, and swift-foundation's no-darwin;
# against each branch's merge base with main), every SYSTEM-GAP marker they
# have, by interface, with what System covers now (or, for what it
# doesn't, the standard library's answer or another module's, from
# mapping.ini), and which of update-checkout's repositories still import a
# platform C module in library code, per platform, with each adopter at its
# newest migration branch. It's cheap enough to rerun after every merge:
# api-delta and the release builds run again only when System's sources
# changed since their last runs, and each package manifest is evaluated
# once. See README.md in this directory.
#
#   Utilities/adopter-coverage/status.sh
#
# Environment:
#   STATUS_ADOPTERS     the adopters' checkouts (default: adopters next to this worktree)
#   STATUS_BRANCH       each package's migration branch (default migrate-darwin)
#   STATUS_BRANCHES     packages whose migration branch is another, as NAME=BRANCH,
#                       space-separated (default swift-foundation=no-darwin)
#   STATUS_ECOSYSTEM    the ecosystem's clones and scheme-main.tsv, for section 4's
#                       platform imports (default: ecosystem next to this worktree)
#   STATUS_PLATFORM_BRANCHES      section 4's branches, newest first: each adopter is read at
#                       the first one it has (default migrate-all migrate-unix migrate-darwin)
#   STATUS_PLATFORM_BRANCHES_FOR  packages with their own list, as NAME=BRANCH,BRANCH...,
#                       space-separated (default swift-foundation=migrate-unix,no-darwin)
#   STATUS_BASE         the branch it's compared with, at their merge base (default main)
#   STATUS_SYSTEM_NEXT  System's integration branch (default system-next)
#   STATUS_OUT          the report (default Prototype/Status/STATUS.md in this worktree)
#   STATUS_WORK         scratch and caches, the release builds' in abi/ (default .build/status)
#   STATUS_API_DELTA=1  rerun api-delta even when its last run is current
#   STATUS_SWIFT        more `swift` executables to evaluate manifests with, colon-separated
#                       (installed toolchains are tried anyway, after the default one)
#   ADOPTER_COVERAGE_RESULTS  the results store, for its SDK vocabulary (optional)
#
# Only commits are read, here, in the packages' checkouts, and in the
# ecosystem's clones (their HEADs); the one file written outside
# STATUS_WORK is the report.
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
BRANCHES="${STATUS_BRANCHES-swift-foundation=no-darwin}"
ECO="$(abspath "${STATUS_ECOSYSTEM:-$REPO/../ecosystem}")"
PLATFORM_BRANCHES="${STATUS_PLATFORM_BRANCHES:-migrate-all migrate-unix migrate-darwin}"
PLATFORM_BRANCHES_FOR="${STATUS_PLATFORM_BRANCHES_FOR-swift-foundation=migrate-unix,no-darwin}"
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
branch_for=()
for b in $BRANCHES; do branch_for+=(--branch-for "$b"); done
for b in $PLATFORM_BRANCHES_FOR; do branch_for+=(--platform-branches-for "$b"); done
python3 "$S/status.py" --repo "$REPO" --adopters "$ADOPTERS" --api-delta "$API" --out "$OUT" \
  --branch "$BRANCH" ${branch_for[@]+"${branch_for[@]}"} --base "$BASE" --system-next "$NEXT" \
  --cache "$WORK/manifests" --abi-work "$WORK/abi" ${VOCAB:+--vocab "$VOCAB"} --ecosystem "$ECO" \
  --platform-branches "$(echo $PLATFORM_BRANCHES | tr ' ' ',')"
