#!/bin/bash
# Checks how much of what swift-system's adopters use from the OS the
# checked-out swift-system covers, against the hand-kept mapping in
# mapping.ini, and writes a report for each adopter and a combined one.
# See README.md in this directory.
#
#   Utilities/adopter-coverage/check.sh               # every package in packages/
#   Utilities/adopter-coverage/check.sh nio swiftpm   # some of them
#   NIO_REF=origin/main Utilities/adopter-coverage/check.sh nio
#
# Environment:
#   <P>_PATH, <P>_REF  a package's checkout (default: the `checkout` in its
#                      packages/*.ini) and commit (default HEAD of it). P is
#                      the package's `variable`: NIO, FOUNDATION, SWIFTPM, ...
#   <P>_SWIFT_EXEC     a swiftc to build that package with, when the default
#                      toolchain can't (see the package's `build-hint`)
#   SYSTEM_REF         the swift-system commit to check (default HEAD)
#   ADOPTER_COVERAGE_OUT     output directory (default .build/adopter-coverage)
#   ADOPTER_COVERAGE_WORK    scratch directory (default .build/adopter-coverage-work)
#   ADOPTER_COVERAGE_MAPPING the mapping file (default mapping.ini next to this script)
#
# Exit status: 0 when the mapping accounts for everything; 2 when a check
# found problems (unmapped interfaces, System API that a mapping names but
# the tip lacks, or a malformed mapping), with the reports written anyway;
# 1 when the tool itself failed, for any package.
#
# Tracked files are never modified, here or in any package's checkout:
# every commit is exported with `git archive`. The output and scratch
# directories must be ignored by git or outside any worktree, and this
# script deletes only directories it created.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
PACKAGES="$TOOL/packages"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"

. "$S/common.sh"

# ------------------------------------------------------------ packages
if [ $# -eq 0 ] || [ "$*" = all ]; then
  # shellcheck disable=SC2046
  set -- $(python3 "$S/package.py" list "$PACKAGES")
fi
for name in "$@"; do
  [ -f "$PACKAGES/$name.ini" ] || fail "no package named $name; the packages are in $PACKAGES"
done

SYSTEM_REF="${SYSTEM_REF:-HEAD}"
SYSTEM_COMMIT="$(git -C "$REPO" rev-parse --verify --quiet "$SYSTEM_REF^{commit}")" \
  || fail "$SYSTEM_REF isn't a commit in $REPO"
OUT="$(abspath "${ADOPTER_COVERAGE_OUT:-$REPO/.build/adopter-coverage}")"
WORK="$(abspath "${ADOPTER_COVERAGE_WORK:-$REPO/.build/adopter-coverage-work}")"
MAPPING="$(abspath "${ADOPTER_COVERAGE_MAPPING:-$TOOL/mapping.ini}")"
[ -f "$MAPPING" ] || fail "no mapping file at $MAPPING"
STAGE="$WORK/stage"

# Every package's checkout and commit, resolved before anything is built.
CHECKOUTS=()
for name in "$@"; do
  resolve_package "$name"
  CHECKOUTS+=("$P_PATH")
done

check_dir ADOPTER_COVERAGE_OUT "$OUT"
check_dir ADOPTER_COVERAGE_WORK "$WORK"
case "$OUT/" in "$WORK"/*) fail "refusing ADOPTER_COVERAGE_OUT=$OUT: it overlaps ADOPTER_COVERAGE_WORK=$WORK" ;; esac
case "$WORK/" in "$OUT"/*) fail "refusing ADOPTER_COVERAGE_OUT=$OUT: it overlaps ADOPTER_COVERAGE_WORK=$WORK" ;; esac
check_out "$OUT"

# The scratch directory keeps each package's build from the last run, keyed
# by commit and compiler, so a rerun against a new System tip doesn't
# rebuild. Only a directory this script created is ever deleted, and not
# while another run is using it.
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
rm -rf "${STAGE:?}" "${WORK:?}/system"
mkdir -p "$STAGE"
touch "$STAGE/.adopter-coverage-out"

printf 'swift-system: %s @ %s (%s)\nmapping: %s\noutput: %s\nscratch: %s\n' \
  "$SYSTEM_REF" "$SYSTEM_COMMIT" "$REPO" "$MAPPING" "$OUT" "$WORK"
if [ "$SYSTEM_COMMIT" = "$(git -C "$REPO" rev-parse HEAD)" ] && ! git -C "$REPO" diff --quiet HEAD -- Sources; then
  echo "note: the uncommitted changes in $REPO/Sources aren't part of the check"
fi

# --------------------------------------------------------------- System
log "scanning System ${SYSTEM_COMMIT:0:10}"
mkdir -p "$WORK/system/src"
git -C "$REPO" archive "$SYSTEM_COMMIT" -- Sources | tar -x -C "$WORK/system/src"
python3 "$TOOL/../api-delta/scripts/scan_sources.py" "$WORK/system/src" "$STAGE/system-api.json"

# ------------------------------------------------------------- packages
export TOOL S PACKAGES REPO WORK STAGE MAPPING SYSTEM_REF SYSTEM_COMMIT
status=0
done_packages=()
failed_packages=()
for name in "$@"; do
  pstatus=0
  "$S/package.sh" "$name" || pstatus=$?
  case "$pstatus" in
    0|2) done_packages+=("$name"); [ "$pstatus" -le "$status" ] || status="$pstatus" ;;
    *) failed_packages+=("$name"); status=1 ;;
  esac
done

# ---------------------------------------------------------------- output
log "replacing the reports in $OUT"
check_out "$OUT"
mkdir -p "$OUT"
touch "$OUT/.adopter-coverage-out"
for name in ${done_packages[@]+"${done_packages[@]}"}; do
  check_out "$OUT/$name"
  rm -rf "${OUT:?}/$name"
  mv "$STAGE/$name" "$OUT/$name"
done
cp "$STAGE/system-api.json" "$OUT/system-api.json"

for name in ${done_packages[@]+"${done_packages[@]}"}; do
  echo
  echo "$name:"
  python3 "$S/check.py" --summary "$OUT/$name/coverage.json"
done
for name in ${failed_packages[@]+"${failed_packages[@]}"}; do
  echo
  echo "$name: failed; see the messages above"
done
log "done: $OUT"
exit "$status"
