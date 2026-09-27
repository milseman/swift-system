#!/bin/bash
# Checks how much of what swift-system's adopters use from the OS a
# swift-system commit covers, and writes a report for each adopter and a
# combined one. What System covers is derived from its sources at that
# commit; mapping.ini adds what can't be derived. Every result is stored by
# commit in the results store, so any run can be repeated and compared.
# See README.md in this directory.
#
#   Utilities/adopter-coverage/check.sh                   # every package in packages/ (in-all)
#   Utilities/adopter-coverage/check.sh nio swiftpm       # some of them
#   Utilities/adopter-coverage/check.sh nio@2.92.2        # a package at a ref of its checkout
#   Utilities/adopter-coverage/check.sh nio=../adopters/swift-nio@migrate-darwin
#   SYSTEM_REF=be8a64f Utilities/adopter-coverage/check.sh nio
#
# Environment:
#   SYSTEM_REF               the swift-system commit to check (default HEAD)
#   <P>_PATH, <P>_REF        a package's checkout and ref, when the spec doesn't give them
#   <P>_SWIFT_EXEC           a swiftc to build that package with (see the package's `build-hint`)
#   <P>_LEXICAL=1            skip the build; extract lexically
#   <P>_REUSE_INDEX=1        reuse any stored index of the package commit, whatever made it
#   ADOPTER_COVERAGE_RESULTS the results store (default: coverage-results next to this worktree)
#   ADOPTER_COVERAGE_OUT     a copy of the run's reports (default .build/adopter-coverage)
#   ADOPTER_COVERAGE_WORK    scratch (default .build/adopter-coverage-work)
#   ADOPTER_COVERAGE_MAPPING the mapping file (default mapping.ini next to this script)
#   ADOPTER_COVERAGE_REBUILD=1  rebuild packages even when the store has their index
#   ADOPTER_COVERAGE_VERIFY_DIR  write the packages' results there, and record no run (results.sh verify)
#
# Exit status: 0 when the mapping accounts for everything; 2 when a check
# found problems, with the reports written anyway; 1 when the tool itself
# failed, for any package.
#
# Tracked files are never modified, here or in any package's checkout:
# every commit is exported with `git archive`. The output, scratch and
# results directories mustn't be tracked, and this script deletes only
# directories it created.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
PACKAGES="$TOOL/packages"
. "$S/common.sh"

# The repository whose commits SYSTEM_REF names: the worktree this runs
# from, or ADOPTER_COVERAGE_REPO for a tool exported from an older commit
# (results.sh verify).
if [ -n "${ADOPTER_COVERAGE_REPO:-}" ]; then
  REPO="$(cd "$ADOPTER_COVERAGE_REPO" && pwd -P)"
else
  REPO="$(git -C "$TOOL" rev-parse --show-toplevel 2>/dev/null)" \
    || fail "run this from a checkout of swift-system, or set ADOPTER_COVERAGE_REPO"
  if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
      && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
        = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
    REPO="$here"
  fi
  REPO="$(cd "$REPO" && pwd -P)"
fi

# The tool's identity: the git trees of this directory and of api-delta's
# scanner, as committed. Uncommitted changes make it a dirty tool, whose
# runs are stored but can't be verified.
if [ -n "${ADOPTER_COVERAGE_TOOL_ID:-}" ]; then
  TOOL_ID="$ADOPTER_COVERAGE_TOOL_ID"
  TOOL_COMMIT="${ADOPTER_COVERAGE_TOOL_COMMIT:-}"
else
  toolrepo="$(git -C "$TOOL" rev-parse --show-toplevel)"
  rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$TOOL" "$toolrepo")"
  TOOL_COMMIT="$(git -C "$toolrepo" rev-parse HEAD)"
  trees="$(git -C "$toolrepo" rev-parse "HEAD:$rel" "HEAD:Utilities/api-delta/scripts/scan_sources.py")"
  TOOL_ID="$(hash12 "$trees")"
  dirty="$(git -C "$toolrepo" status --porcelain -- "$rel" Utilities/api-delta/scripts/scan_sources.py)"
  if [ -n "$dirty" ]; then
    TOOL_ID="$TOOL_ID-dirty-$(hash12 "$(git -C "$toolrepo" diff HEAD -- "$rel" Utilities/api-delta/scripts; \
      git -C "$toolrepo" ls-files --others --exclude-standard -- "$rel" | xargs -I{} shasum "$toolrepo/{}")")"
  fi
fi

# ------------------------------------------------------------ packages
if [ $# -eq 0 ] || [ "$*" = all ]; then
  # shellcheck disable=SC2046
  set -- $(python3 "$S/package.py" list "$PACKAGES")
fi

SYSTEM_REF="${SYSTEM_REF:-HEAD}"
SYSTEM_COMMIT="$(git -C "$REPO" rev-parse --verify --quiet "$SYSTEM_REF^{commit}")" \
  || fail "$SYSTEM_REF isn't a commit in $REPO"
OUT="$(abspath "${ADOPTER_COVERAGE_OUT:-$REPO/.build/adopter-coverage}")"
WORK="$(abspath "${ADOPTER_COVERAGE_WORK:-$REPO/.build/adopter-coverage-work}")"
RESULTS="$(abspath "${ADOPTER_COVERAGE_RESULTS:-$(dirname "$REPO")/coverage-results}")"
MAPPING="$(abspath "${ADOPTER_COVERAGE_MAPPING:-$TOOL/mapping.ini}")"
VERIFY="${ADOPTER_COVERAGE_VERIFY_DIR:-}"
[ -f "$MAPPING" ] || fail "no mapping file at $MAPPING"
STAGE="$WORK/stage"

# Every package's checkout and commit, resolved before anything is built.
CHECKOUTS=()
NAMES=()
for spec in "$@"; do
  resolve_package "$spec"
  CHECKOUTS+=("$P_PATH")
  NAMES+=("$P_NAME")
done

check_dir ADOPTER_COVERAGE_OUT "$OUT"
check_dir ADOPTER_COVERAGE_WORK "$WORK"
check_dir ADOPTER_COVERAGE_RESULTS "$RESULTS"
for a in "$OUT" "$WORK" "$RESULTS"; do
  for b in "$OUT" "$WORK" "$RESULTS"; do
    [ "$a" = "$b" ] && continue
    case "$a/" in "$b"/*) fail "refusing overlapping directories: $a is inside $b" ;; esac
  done
done
check_out "$OUT"

# The scratch directory holds one run's exports and builds. Only a
# directory this script created is ever deleted, and not while another run
# is using it.
if [ -e "$WORK" ]; then
  [ -f "$WORK/.adopter-coverage-work" ] \
    || fail "refusing ADOPTER_COVERAGE_WORK=$WORK: it exists and isn't an adopter-coverage scratch directory"
  pid="$(cat "$WORK/.adopter-coverage-work")"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    fail "refusing ADOPTER_COVERAGE_WORK=$WORK: another run (process $pid) is using it"
  fi
fi
mkdir -p "$WORK"
echo "$$" > "$WORK/.adopter-coverage-work"
rm -rf "${STAGE:?}" "${WORK:?}/system" "${WORK:?}/system-package"
mkdir -p "$STAGE"
touch "$STAGE/.adopter-coverage-out"
if [ ! -d "$RESULTS" ]; then
  mkdir -p "$RESULTS"
  cp "$TOOL/results-README.md" "$RESULTS/README.md"
fi
[ -f "$RESULTS/README.md" ] || fail "refusing ADOPTER_COVERAGE_RESULTS=$RESULTS: it exists and isn't a results store"

printf 'swift-system: %s @ %s (%s)\ntool: %s (%s)\nmapping: %s\nresults: %s\noutput: %s\nscratch: %s\n' \
  "$SYSTEM_REF" "$SYSTEM_COMMIT" "$REPO" "$TOOL_ID" "${TOOL_COMMIT:-?}" "$MAPPING" "$RESULTS" "$OUT" "$WORK"
if [ "$SYSTEM_COMMIT" = "$(git -C "$REPO" rev-parse HEAD)" ] && ! git -C "$REPO" diff --quiet HEAD -- Sources; then
  echo "note: the uncommitted changes in $REPO/Sources aren't part of the check"
fi
case "$TOOL_ID" in *-dirty-*) echo "note: the tool has uncommitted changes; its results are stored, but can't be verified" ;; esac

# --------------------------------------------------------------- System
# System's API and what it covers, derived from its sources at the commit:
# stored once per commit and tool.
SYS="$RESULTS/systems/$SYSTEM_COMMIT/$TOOL_ID"
SYSTEM_API="$SYS/system-api.json"
SYSTEM_DERIVED="$SYS/derived.json"
if [ -f "$SYSTEM_DERIVED" ] && [ -z "${ADOPTER_COVERAGE_REBUILD:-}" ]; then
  log "System ${SYSTEM_COMMIT:0:10}: reusing its scan and derivation ($SYS)"
else
  log "scanning System ${SYSTEM_COMMIT:0:10}"
  mkdir -p "$WORK/system/src" "$SYS"
  git -C "$REPO" archive "$SYSTEM_COMMIT" -- Sources | tar -x -C "$WORK/system/src"
  python3 "$TOOL/../api-delta/scripts/scan_sources.py" "$WORK/system/src" "$SYSTEM_API.tmp"
  mv "$SYSTEM_API.tmp" "$SYSTEM_API"
  log "deriving what System ${SYSTEM_COMMIT:0:10} covers"
  python3 "$S/derive.py" "$WORK/system/src" "$SYSTEM_API" "$SYSTEM_DERIVED.tmp"
  mv "$SYSTEM_DERIVED.tmp" "$SYSTEM_DERIVED"
fi

# ------------------------------------------------------------- packages
export TOOL S PACKAGES REPO WORK STAGE MAPPING SYSTEM_REF SYSTEM_COMMIT RESULTS SYSTEM_API SYSTEM_DERIVED \
  TOOL_ID TOOL_COMMIT
status=0
done_specs=()
failed_specs=()
for spec in "$@"; do
  pstatus=0
  "$S/package.sh" "$spec" || pstatus=$?
  case "$pstatus" in
    0|2) done_specs+=("$spec"); [ "$pstatus" -le "$status" ] || status="$pstatus" ;;
    *) failed_specs+=("$spec"); status=1 ;;
  esac
done

# ------------------------------------------------------------- results
# Each package's result goes to the store under its commit, System's and
# the tool's; one already there for the same three is compared first, which
# is a free check that the run reproduced it.
RUN_JSON="$STAGE/run.json"
python3 "$S/results.py" record --results "$RESULTS" --stage "$STAGE" --verify-dir "$VERIFY" \
  --system-ref "$SYSTEM_REF" --system-commit "$SYSTEM_COMMIT" --tool "$TOOL_ID" --tool-commit "${TOOL_COMMIT:-}" \
  --mapping "$MAPPING" --packages "$PACKAGES" --out "$RUN_JSON" \
  --specs ${done_specs[@]+"${done_specs[@]}"} --failed ${failed_specs[@]+"${failed_specs[@]}"}

if [ -z "$VERIFY" ]; then
  RUN_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$RUN_JSON")"
  RUN_DIR="$RESULTS/runs/$RUN_ID"
  log "combined report for run $RUN_ID"
  python3 "$S/combine.py" --run "$RUN_DIR" --results "$RESULTS" --mapping "$MAPPING" --packages "$PACKAGES"

  # A copy of the run's reports where they used to be.
  check_out "$OUT"
  rm -rf "${OUT:?}"
  mkdir -p "$OUT"
  touch "$OUT/.adopter-coverage-out"
  for spec in ${done_specs[@]+"${done_specs[@]}"}; do
    parse_spec "$spec"
    rm -rf "${OUT:?}/$SPEC_NAME"
    mv "$STAGE/$SPEC_NAME" "$OUT/$SPEC_NAME"
  done
  cp "$SYSTEM_API" "$SYSTEM_DERIVED" "$RUN_DIR/COVERAGE.md" "$RUN_DIR/coverage.json" "$RUN_DIR/run.json" "$OUT/"
fi

for spec in ${done_specs[@]+"${done_specs[@]}"}; do
  parse_spec "$spec"
  echo
  echo "$SPEC_NAME:"
  if [ -z "$VERIFY" ]; then
    python3 "$S/check.py" --summary "$OUT/$SPEC_NAME/coverage.json"
  else
    python3 "$S/check.py" --summary "$VERIFY/$SPEC_NAME/coverage.json"
  fi
done
for spec in ${failed_specs[@]+"${failed_specs[@]}"}; do
  echo
  echo "$spec: failed; see the messages above"
done
if [ -z "$VERIFY" ]; then
  log "done: run $RUN_ID, in $RUN_DIR (a copy in $OUT)"
fi
exit "$status"
