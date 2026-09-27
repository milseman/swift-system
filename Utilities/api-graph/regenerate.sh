#!/bin/bash
# Maps the public API that one commit adds over another into clusters that
# pitches can carve out: a declaration graph, clusters and their parts, the
# open design questions each depends on, a ranking, and a bundle per
# carve-out for a pitch-writing session. See README.md in this directory.
#
#   Utilities/api-graph/regenerate.sh                  # main vs system-next
#   BASE_REF=main HEAD_REF=HEAD Utilities/api-graph/regenerate.sh
#
# Environment:
#   BASE_REF, HEAD_REF   the commits to compare (default main and system-next)
#   API_GRAPH_OUT        output directory (default .build/api-graph)
#   API_GRAPH_WORK       scratch directory (default .build/api-graph-work)
#   API_GRAPH_DELTA      an existing api-delta output for the same commits, to
#                        use instead of running api-delta
#   API_GRAPH_DRAFTS     a directory of draft proposals to search for prior
#                        text (default ../win32-drafts beside the repository);
#                        set it empty to skip
#   API_GRAPH_PREVIOUS   an api-graph.json to compare with (default: the one
#                        in API_GRAPH_OUT, from the previous run)
#
# Refs resolve as in api-delta: in the git worktree of the current directory
# if it belongs to this repository, else in the worktree holding this script.
# Tracked files are never modified: each commit is exported with
# `git archive`. The output and scratch directories must be ignored by git or
# outside any worktree, and this script deletes only directories it created.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
DELTA_TOOL="$(cd "$TOOL/../api-delta" && pwd -P)"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"

# See api-delta's README: SwiftPM's manifest sandbox can fail inside another
# sandbox. The manifests are this repository's own.
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

resolve() {
  git -C "$REPO" rev-parse --verify --quiet "$1^{commit}" || fail "$1 isn't a commit in $REPO"
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

# The same rules as api-delta's: refuse a directory holding the repository,
# $HOME or this tool, one inside a git directory, and one in a worktree that
# git doesn't ignore.
check_dir() {
  local name="$1" dir="$2" keep probe
  [ "$dir" != / ] || fail "refusing $name=/"
  for keep in "$REPO" "$(cd "$HOME" && pwd -P)" "$TOOL"; do
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
  if [ -e "$OUT" ] && [ ! -f "$OUT/.api-graph-out" ]; then
    fail "refusing API_GRAPH_OUT=$OUT: it exists and isn't api-graph output"
  fi
}

BASE_REF="${BASE_REF:-main}"
HEAD_REF="${HEAD_REF:-system-next}"
BASE_COMMIT="$(resolve "$BASE_REF")"
HEAD_COMMIT="$(resolve "$HEAD_REF")"
OUT="$(abspath "${API_GRAPH_OUT:-$REPO/.build/api-graph}")"
WORK="$(abspath "${API_GRAPH_WORK:-$REPO/.build/api-graph-work}")"
STAGE="$WORK/out"

check_dir API_GRAPH_OUT "$OUT"
check_dir API_GRAPH_WORK "$WORK"
case "$OUT/" in "$WORK"/*) fail "refusing API_GRAPH_OUT=$OUT: it overlaps API_GRAPH_WORK=$WORK" ;; esac
case "$WORK/" in "$OUT"/*) fail "refusing API_GRAPH_OUT=$OUT: it overlaps API_GRAPH_WORK=$WORK" ;; esac
check_out

if [ -e "$WORK" ]; then
  [ -f "$WORK/.api-graph-work" ] || fail "refusing API_GRAPH_WORK=$WORK: it exists and isn't an api-graph scratch directory"
  pid="$(cat "$WORK/.api-graph-work")"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    fail "refusing API_GRAPH_WORK=$WORK: another run (process $pid) is using it"
  fi
  rm -rf "${WORK:?}"
fi
mkdir -p "$WORK/logs" "$STAGE"
echo "$$" > "$WORK/.api-graph-work"
touch "$STAGE/.api-graph-out"

DRAFTS="${API_GRAPH_DRAFTS-$(dirname "$REPO")/win32-drafts}"
if [ -n "$DRAFTS" ] && [ ! -d "$DRAFTS" ]; then DRAFTS=""; fi
PREVIOUS="${API_GRAPH_PREVIOUS:-$OUT/api-graph.json}"
if [ -f "$PREVIOUS" ]; then cp "$PREVIOUS" "$WORK/previous.json"; fi

printf 'base: %s @ %s\nhead: %s @ %s\nrepository: %s\noutput: %s\nscratch: %s\n' \
  "$BASE_REF" "$BASE_COMMIT" "$HEAD_REF" "$HEAD_COMMIT" "$REPO" "$OUT" "$WORK"
if [ "$HEAD_COMMIT" = "$(git -C "$REPO" rev-parse HEAD)" ] && ! git -C "$REPO" diff --quiet HEAD -- Sources Tests; then
  echo "note: the uncommitted changes in $REPO aren't part of the map"
fi

# 1. api-delta, in the background while the indexed build runs.
delta_pid=""
if [ -n "${API_GRAPH_DELTA:-}" ]; then
  DELTA="$(abspath "$API_GRAPH_DELTA")"
  [ -f "$DELTA/api-delta.json" ] || fail "API_GRAPH_DELTA=$DELTA has no api-delta.json"
  python3 - "$DELTA/logs/meta.json" "$BASE_COMMIT" "$HEAD_COMMIT" <<'EOF' || fail "API_GRAPH_DELTA=$DELTA is for other commits"
import json, sys
m = json.load(open(sys.argv[1]))
sys.exit(0 if (m["baseCommit"], m["headCommit"]) == (sys.argv[2], sys.argv[3]) else 1)
EOF
  log "api-delta: using $DELTA"
else
  DELTA="$WORK/api-delta"
  log "api-delta (in the background; log in $WORK/logs/api-delta.log)"
  (cd "$REPO" && API_DELTA_OUT="$DELTA" API_DELTA_WORK="$WORK/api-delta-work" \
    BASE_REF="$BASE_COMMIT" HEAD_REF="$HEAD_COMMIT" "$DELTA_TOOL/regenerate.sh") > "$WORK/logs/api-delta.log" 2>&1 &
  delta_pid=$!
fi

# 2. Exports.
for side in base head; do
  if [ "$side" = base ]; then commit="$BASE_COMMIT"; else commit="$HEAD_COMMIT"; fi
  mkdir -p "$WORK/$side/src"
  git -C "$REPO" archive "$commit" | tar -x -C "$WORK/$side/src"
done

# 3. The indexed build, tests and Samples included. --skip-update resolves
# swift-argument-parser from SwiftPM's local cache, without a fetch; if the
# cache doesn't have it, Samples are dropped, as api-delta drops them, and
# samples are matched by name.
SAMPLES=index
log "[head] resolving dependencies from SwiftPM's cache"
if ! swift package "${SWIFTPM[@]}" --package-path "$WORK/head/src" --scratch-path "$WORK/head/build" \
    --skip-update resolve > "$WORK/logs/resolve.log" 2>&1; then
  echo "note: swift-argument-parser isn't in SwiftPM's cache; building without Samples (see logs/resolve.log)"
  python3 "$DELTA_TOOL/scripts/patch_manifest.py" "$WORK/head/src/Package.swift"
  SAMPLES=lexical
fi
log "[head] indexed build, with tests"
logged "$WORK/logs/build.log" swift build "${SWIFTPM[@]}" --skip-update --package-path "$WORK/head/src" \
  --scratch-path "$WORK/head/build" --build-tests -Xswiftc -index-store-path -Xswiftc "$WORK/head/index"

# 4. Scans.
log "source scans"
for side in base head; do
  logged "$WORK/logs/scan-$side.log" python3 "$DELTA_TOOL/scripts/scan_sources.py" "$WORK/$side/src" "$WORK/$side/scan.json"
done
logged "$WORK/logs/source-index.log" python3 "$S/source_index.py" "$WORK/head/src" "$WORK/head/source-index.json" \
  Sources/System Sources/SystemSockets Sources/Samples Sources/CSystem Tests

# 5. References.
log "index store"
logged "$WORK/logs/index-refs.log" python3 "$S/index_refs.py" "$WORK/head/index" "$WORK/head/src" "$WORK/head/refs.json"

# 6. The diff, with fixed options so that git configuration can't change it.
git -C "$REPO" -c core.quotePath=false diff --no-ext-diff --no-textconv --no-color \
  --src-prefix=a/ --dst-prefix=b/ --find-renames -U0 "$BASE_COMMIT" "$HEAD_COMMIT" -- Sources Tests > "$WORK/src.diff"

if [ -n "$delta_pid" ]; then
  log "waiting for api-delta"
  wait "$delta_pid" || fail "api-delta failed" "$WORK/logs/api-delta.log"
fi

python3 - "$WORK/meta.json" "$REPO" "$BASE_REF" "$BASE_COMMIT" "$HEAD_REF" "$HEAD_COMMIT" "$SAMPLES" "$DRAFTS" <<'EOF'
import datetime, json, platform, subprocess, sys
out, repo, base_ref, base_commit, head_ref, head_commit, samples, drafts = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(c): return sh("git", "-C", repo, "log", "-1", "--no-show-signature", "--format=%s", c)
json.dump({
  "baseRef": base_ref, "headRef": head_ref, "baseCommit": base_commit, "headCommit": head_commit,
  "baseSubject": subject(base_commit), "headSubject": subject(head_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": sh("swift", "--version").split("\n")[0].replace("swift-driver version: ", "swift-driver "),
  "samples": samples, "drafts": drafts or None,
}, open(out, "w"), indent=1)
EOF

# 7-9. Graph, clusters, bundles, report.
log "graph"
graph=(--delta-dir "$DELTA" --head-scan "$WORK/head/scan.json" --base-scan "$WORK/base/scan.json"
  --source-index "$WORK/head/source-index.json" --refs "$WORK/head/refs.json" --diff "$WORK/src.diff"
  --root "$WORK/head/src" --out "$WORK/graph.json")
if [ "$SAMPLES" = lexical ]; then graph+=(--lexical-samples); fi
python3 "$S/build_graph.py" "${graph[@]}"
log "clusters"
clusters=(--graph "$WORK/graph.json" --config "$TOOL/config.json" --contingencies "$TOOL/contingencies.json"
  --evidence "$TOOL/evidence.json" --root "$WORK/head/src" --out "$WORK/clusters.json")
if [ -n "$DRAFTS" ]; then clusters+=(--drafts "$DRAFTS"); fi
python3 "$S/cluster.py" "${clusters[@]}"
log "bundles"
python3 "$S/bundles.py" --graph "$WORK/graph.json" --clusters "$WORK/clusters.json" --root "$WORK/head/src" \
  --repo "$REPO" --base "$BASE_COMMIT" --head "$HEAD_COMMIT" --out "$STAGE/bundles"
log "report"
report=(--graph "$WORK/graph.json" --clusters "$WORK/clusters.json" --meta "$WORK/meta.json" --out "$STAGE")
if [ -f "$WORK/previous.json" ]; then report+=(--previous "$WORK/previous.json"); fi
python3 "$S/report.py" "${report[@]}"

cp "$WORK/graph.json" "$STAGE/"
mkdir -p "$STAGE/api-delta" "$STAGE/logs"
cp "$DELTA/API-DELTA.md" "$DELTA/api-delta.json" "$STAGE/api-delta/"
cp "$WORK/meta.json" "$WORK/logs/"*.log "$STAGE/logs/"

log "replacing $OUT"
check_out
rm -rf "${OUT:?}"
mkdir -p "$(dirname "$OUT")"
mv "$STAGE" "$OUT"

log "done: $OUT/API-GRAPH.md"
