#!/bin/bash
# Checks how much of what swift-nio uses from the OS the checked-out
# swift-system covers, against the hand-kept mapping in mapping.ini, and
# writes a report. See README.md in this directory.
#
#   Utilities/nio-coverage/check.sh
#   NIO_REF=origin/main Utilities/nio-coverage/check.sh
#
# Environment:
#   NIO_PATH          the swift-nio checkout (default: ../swift-nio next to this repository)
#   NIO_REF           the NIO commit to extract from (default HEAD of NIO_PATH)
#   SYSTEM_REF        the swift-system commit to check (default HEAD)
#   NIO_COVERAGE_OUT  output directory (default .build/nio-coverage)
#   NIO_COVERAGE_WORK scratch directory (default .build/nio-coverage-work)
#   NIO_COVERAGE_MAPPING the mapping file (default mapping.ini next to this script)
#
# Exit status: 0 when the mapping accounts for everything; 2 when the check
# found problems (unmapped NIO interfaces, System API that a mapping names
# but the tip lacks, or a malformed mapping), with the report written
# anyway; 1 when the tool itself failed.
#
# Tracked files are never modified, here or in NIO_PATH: both commits are
# exported with `git archive`. The output and scratch directories must be
# ignored by git or outside any worktree, and this script deletes only
# directories it created.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"

# SwiftPM runs each manifest under sandbox-exec, which can fail when this
# script itself runs in a sandbox ("sandbox_apply: Operation not permitted").
# See README.md.
SWIFTPM=(--disable-sandbox)

log() { printf '\n== %s\n' "$*"; }

fail() {
  echo "error: $1" >&2
  if [ -n "${2:-}" ]; then
    echo "-- last lines of $2:" >&2
    tail -n 20 "$2" >&2
  fi
  exit 1
}

logged() {
  local logfile="$1"
  shift
  "$@" > "$logfile" 2>&1 || fail "command failed: $*" "$logfile"
}

# Absolute physical path of $1, which needn't exist yet.
abspath() {
  local dir="$1" rest="" base
  while [ ! -d "$dir" ]; do
    base="$(basename "$dir")"
    case "$base" in .|..) fail "$1: use a path without . or .. components" ;; esac
    rest="/$base$rest"
    dir="$(dirname "$dir")"
  done
  base="$(cd "$dir" && pwd -P)"
  base="${base%/}$rest"
  printf '%s\n' "${base:-/}"
}

# check_dir NAME DIR: refuses a directory that this script mustn't create or
# delete: one holding a repository, $HOME or this script, or one inside a
# git directory, or inside a worktree but not ignored by it.
check_dir() {
  local name="$1" dir="$2" keep probe
  [ "$dir" != / ] || fail "refusing $name=/"
  for keep in "$REPO" "$NIO" "$(cd "$HOME" && pwd -P)" "$TOOL"; do
    case "$keep/" in "$dir"/*) fail "refusing $name=$dir: it holds $keep" ;; esac
  done
  probe="$dir"
  while [ ! -d "$probe" ]; do probe="$(dirname "$probe")"; done
  if [ "$(git -C "$probe" rev-parse --is-inside-git-dir 2>/dev/null)" = true ]; then
    fail "refusing $name=$dir: it's inside a git directory"
  fi
  if [ "$(git -C "$probe" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
    git -C "$probe" check-ignore -q "$dir" || fail "refusing $name=$dir: it's in a git worktree and not ignored"
    [ -z "$(git -C "$probe" ls-files -- "$dir")" ] || fail "refusing $name=$dir: it holds tracked files"
  fi
}

check_out() {
  if [ -e "$OUT" ] && [ ! -f "$OUT/.nio-coverage-out" ]; then
    fail "refusing NIO_COVERAGE_OUT=$OUT: it exists and isn't nio-coverage output"
  fi
}

NIO="$(abspath "${NIO_PATH:-$REPO/../swift-nio}")"
[ -d "$NIO" ] || fail "no swift-nio checkout at $NIO; set NIO_PATH"
NIO="$(git -C "$NIO" rev-parse --show-toplevel 2>/dev/null)" || fail "$NIO isn't a git checkout; set NIO_PATH"
NIO="$(cd "$NIO" && pwd -P)"
NIO_REF="${NIO_REF:-HEAD}"
SYSTEM_REF="${SYSTEM_REF:-HEAD}"
NIO_COMMIT="$(git -C "$NIO" rev-parse --verify --quiet "$NIO_REF^{commit}")" || fail "$NIO_REF isn't a commit in $NIO"
SYSTEM_COMMIT="$(git -C "$REPO" rev-parse --verify --quiet "$SYSTEM_REF^{commit}")" \
  || fail "$SYSTEM_REF isn't a commit in $REPO"
OUT="$(abspath "${NIO_COVERAGE_OUT:-$REPO/.build/nio-coverage}")"
WORK="$(abspath "${NIO_COVERAGE_WORK:-$REPO/.build/nio-coverage-work}")"
MAPPING="$(abspath "${NIO_COVERAGE_MAPPING:-$TOOL/mapping.ini}")"
[ -f "$MAPPING" ] || fail "no mapping file at $MAPPING"
STAGE="$WORK/out"

check_dir NIO_COVERAGE_OUT "$OUT"
check_dir NIO_COVERAGE_WORK "$WORK"
case "$OUT/" in "$WORK"/*) fail "refusing NIO_COVERAGE_OUT=$OUT: it overlaps NIO_COVERAGE_WORK=$WORK" ;; esac
case "$WORK/" in "$OUT"/*) fail "refusing NIO_COVERAGE_OUT=$OUT: it overlaps NIO_COVERAGE_WORK=$WORK" ;; esac
check_out

# The scratch directory keeps the NIO build from the last run, keyed by NIO
# commit, so a rerun against a new System tip doesn't rebuild NIO. Only a
# directory this script created is ever deleted, and not while another run
# is using it.
if [ -e "$WORK" ]; then
  [ -f "$WORK/.nio-coverage-work" ] || fail "refusing NIO_COVERAGE_WORK=$WORK: it exists and isn't a nio-coverage scratch directory"
  pid="$(cat "$WORK/.nio-coverage-work")"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    fail "refusing NIO_COVERAGE_WORK=$WORK: another run (process $pid) is using it"
  fi
fi
mkdir -p "$WORK"
echo "$$" > "$WORK/.nio-coverage-work"
rm -rf "${STAGE:?}" "${WORK:?}/system"
mkdir -p "$STAGE/logs"
touch "$STAGE/.nio-coverage-out"

printf 'swift-nio: %s @ %s (%s)\nswift-system: %s @ %s (%s)\nmapping: %s\noutput: %s\nscratch: %s\n' \
  "$NIO_REF" "$NIO_COMMIT" "$NIO" "$SYSTEM_REF" "$SYSTEM_COMMIT" "$REPO" "$MAPPING" "$OUT" "$WORK"
if [ "$SYSTEM_COMMIT" = "$(git -C "$REPO" rev-parse HEAD)" ] && ! git -C "$REPO" diff --quiet HEAD -- Sources; then
  echo "note: the uncommitted changes in $REPO/Sources aren't part of the check"
fi
if [ "$NIO_COMMIT" = "$(git -C "$NIO" rev-parse HEAD)" ] && ! git -C "$NIO" diff --quiet HEAD -- Sources Package.swift; then
  echo "note: the uncommitted changes in $NIO aren't part of the check"
fi

# ------------------------------------------------------------------ NIO
N="$WORK/nio"
if [ -f "$N/index.json" ] && [ "$(cat "$N/commit" 2>/dev/null)" = "$NIO_COMMIT" ]; then
  log "NIO ${NIO_COMMIT:0:10}: reusing the build and index from the last run"
else
  rm -rf "${N:?}"
  mkdir -p "$N/src"
  log "exporting NIO ${NIO_COMMIT:0:10}"
  git -C "$NIO" archive "$NIO_COMMIT" | tar -x -C "$N/src"
  log "building NIO (debug, with an index store)"
  logged "$N/build.log" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build"
  swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" dump-package \
    > "$N/dump.json" 2> "$N/dump.log" || fail "swift package dump-package failed" "$N/dump.log"
  swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" describe --type json \
    > "$N/describe.json" 2> "$N/describe.log" || fail "swift package describe failed" "$N/describe.log"
  store="$(find "$N/build" -maxdepth 4 -type d -path '*/index/store' -print -quit)"
  [ -n "$store" ] || fail "the NIO build left no index store" "$N/build.log"
  libindexstore="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/libIndexStore.dylib"
  [ -f "$libindexstore" ] || fail "no libIndexStore.dylib next to $(xcrun --find swift)"
  log "reading the index store"
  python3 "$S/indexstore.py" "$libindexstore" "$store" "$(cd "$N/src" && pwd -P)" "$N/index.json"
  echo "$NIO_COMMIT" > "$N/commit"
fi

log "extracting NIO's OS interfaces"
python3 "$S/extract.py" --root "$N/src" --index "$N/index.json" --dump "$N/dump.json" \
  --describe "$N/describe.json" --out "$STAGE/nio-interfaces.json"

# --------------------------------------------------------------- System
log "scanning System ${SYSTEM_COMMIT:0:10}"
mkdir -p "$WORK/system/src"
git -C "$REPO" archive "$SYSTEM_COMMIT" -- Sources | tar -x -C "$WORK/system/src"
python3 "$TOOL/../api-delta/scripts/scan_sources.py" "$WORK/system/src" "$STAGE/system-api.json"

# ------------------------------------------------------ check and report
python3 - "$STAGE/meta.json" "$NIO" "$NIO_REF" "$NIO_COMMIT" "$REPO" "$SYSTEM_REF" "$SYSTEM_COMMIT" <<'EOF'
import datetime, json, platform, subprocess, sys
out, nio, nio_ref, nio_commit, repo, sys_ref, sys_commit = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(r, c): return sh("git", "-C", r, "log", "-1", "--no-show-signature", "--format=%s", c)
json.dump({
  "nioPath": nio, "nioRef": nio_ref, "nioCommit": nio_commit, "nioSubject": subject(nio, nio_commit),
  "systemPath": repo, "systemRef": sys_ref, "systemCommit": sys_commit, "systemSubject": subject(repo, sys_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": sh("swift", "--version").split("\n")[0].replace("swift-driver version: ", "swift-driver "),
}, open(out, "w"), indent=1)
EOF

log "checking the mapping"
status=0
python3 "$S/check.py" --interfaces "$STAGE/nio-interfaces.json" --system "$STAGE/system-api.json" \
  --mapping "$MAPPING" --meta "$STAGE/meta.json" --out "$STAGE/coverage.json" || status=$?
[ "$status" -le 2 ] || fail "check.py failed"

log "report"
python3 "$S/report.py" --coverage "$STAGE/coverage.json" --method "$S/method.md" --out "$STAGE/COVERAGE.md"

cp "$N/build.log" "$STAGE/logs/nio-build.log" 2>/dev/null || true
cp "$N/describe.json" "$N/dump.json" "$STAGE/logs/"

log "replacing $OUT"
check_out
rm -rf "${OUT:?}"
mkdir -p "$(dirname "$OUT")"
mv "$STAGE" "$OUT"

python3 "$S/check.py" --summary "$OUT/coverage.json"
log "done: $OUT/COVERAGE.md"
exit "$status"
