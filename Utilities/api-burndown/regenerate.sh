#!/bin/bash
# Writes the burn-down of the public API that one commit adds over another,
# by default what system-next adds over main: .build/api-burndown/burndown.json
# and the self-contained page Prototype/Burndown/burndown.html. See README.md
# in this directory.
#
#   Utilities/api-burndown/regenerate.sh            # main vs system-next
#   Utilities/api-burndown/regenerate.sh --check    # reconcile the last run with api-delta
#   Utilities/api-burndown/regenerate.sh --no-verify  # without verify.sh at the end
#   BASE_REF=main HEAD_REF=HEAD Utilities/api-burndown/regenerate.sh
#
# Environment:
#   BASE_REF, HEAD_REF       the commits to compare (default main and system-next)
#   API_BURNDOWN_OUT         output directory (default .build/api-burndown): burndown.json,
#                            history/ (the scans, by commit, kept between runs), cache/,
#                            api-delta/ (api-delta's run), logs/
#   API_BURNDOWN_WORK        scratch directory (default .build/api-burndown-work)
#   API_BURNDOWN_PAGE        the page (default Prototype/Burndown/burndown.html)
#   API_BURNDOWN_DELTA       an existing api-delta output for the same commits, instead
#                            of running api-delta (without it, the last run's is reused
#                            when its commits, api-delta's committed tree and the compiler
#                            are the same)
#   API_BURNDOWN_GRAPH       auto (default): the newest API graph there is, this
#                            worktree's .build/api-graph or the snapshot store's, the
#                            head commit's if there's one; run: run api-graph first;
#                            or a graph.json.gz, an api-graph output directory, or a
#                            commit the store has
#   API_BURNDOWN_SNAPSHOTS   the api-graph snapshot store (default ../api-graph-snapshots
#                            beside the repository), read only
#   API_BURNDOWN_PITCHES     the pitch files (default Prototype/Pitches, from the working
#                            tree, as api-graph reads them)
#   API_BURNDOWN_STATES      pitched and PR-open dates (default Prototype/Burndown/states.json)
#   API_BURNDOWN_COVERAGE_RESULTS  the coverage tools' results store, for the SDK
#                            vocabulary (default ../coverage-results)
#   API_BURNDOWN_VOCAB       a vocabulary file, instead of the store's newest macosx one
#   API_BURNDOWN_UPSTREAM    a ref the base should contain (default origin/main); when
#                            it doesn't, the page says so and flags what the ref has;
#                            set it empty to skip
#   API_BURNDOWN_TODAY       the last day, YYYY-MM-DD (default today)
#
# Refs resolve as in api-delta: in the git worktree of the current directory
# if it belongs to this repository, and otherwise in the one holding this
# script. The only tracked file written is the page.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
UTIL="$(cd "$TOOL/.." && pwd -P)"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
if here="$(git rev-parse --show-toplevel 2>/dev/null)" \
    && [ "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)" \
      = "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" ]; then
  REPO="$here"
fi
REPO="$(cd "$REPO" && pwd -P)"
SIBLINGS="$(dirname "$REPO")"

log() { printf '\n== %s\n' "$*"; }

fail() {
  echo "error: $1" >&2
  if [ -n "${2:-}" ]; then
    echo "-- last lines of $2:" >&2
    tail -n 20 "$2" >&2
  fi
  exit 1
}

resolve() {
  git -C "$REPO" rev-parse --verify --quiet "$1^{commit}" || fail "$1 isn't a commit in $REPO"
}

# Absolute physical path of $1, which needn't exist yet.
abspath() {
  local dir="$1" rest="" base
  case "$dir" in /*) ;; *) dir="$PWD/$dir" ;; esac
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

# check_dir NAME DIR: as api-delta's: refuse a directory holding the
# repository, $HOME or this tool, one inside a git directory, and one in a
# worktree that git doesn't ignore.
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

CHECK_ONLY=""
NO_VERIFY=""
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --no-verify) NO_VERIFY=1 ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    *) fail "unknown argument $arg (see --help)" ;;
  esac
done

BASE_REF="${BASE_REF:-main}"
HEAD_REF="${HEAD_REF:-system-next}"
OUT="$(abspath "${API_BURNDOWN_OUT:-$REPO/.build/api-burndown}")"
WORK="$(abspath "${API_BURNDOWN_WORK:-$REPO/.build/api-burndown-work}")"
PAGE="$(abspath "${API_BURNDOWN_PAGE:-$REPO/Prototype/Burndown/burndown.html}")"
PITCHES="$(abspath "${API_BURNDOWN_PITCHES:-$REPO/Prototype/Pitches}")"
STATES="$(abspath "${API_BURNDOWN_STATES:-$REPO/Prototype/Burndown/states.json}")"
STORE="${API_BURNDOWN_SNAPSHOTS-$SIBLINGS/api-graph-snapshots}"
COVERAGE="${API_BURNDOWN_COVERAGE_RESULTS-$SIBLINGS/coverage-results}"
UPSTREAM="${API_BURNDOWN_UPSTREAM-origin/main}"
GRAPH="${API_BURNDOWN_GRAPH:-auto}"
TODAY="${API_BURNDOWN_TODAY:-$(date +%Y-%m-%d)}"

check_dir API_BURNDOWN_OUT "$OUT"
check_dir API_BURNDOWN_WORK "$WORK"
case "$OUT/" in "$WORK"/*) fail "refusing API_BURNDOWN_OUT=$OUT: it overlaps API_BURNDOWN_WORK=$WORK" ;; esac
case "$WORK/" in "$OUT"/*) fail "refusing API_BURNDOWN_OUT=$OUT: it overlaps API_BURNDOWN_WORK=$WORK" ;; esac
if [ -e "$OUT" ] && [ ! -f "$OUT/.api-burndown-out" ]; then
  fail "refusing API_BURNDOWN_OUT=$OUT: it exists and isn't api-burndown output"
fi
DELTA="${API_BURNDOWN_DELTA:-$OUT/api-delta}"
DELTA="$(abspath "$DELTA")"

if [ -n "$CHECK_ONLY" ]; then
  [ -f "$OUT/burndown.json" ] || fail "no $OUT/burndown.json; run this script without --check first"
  python3 "$S/burndown.py" --check --out-json "$OUT/burndown.json" --delta "$DELTA" --page "$PAGE"
  exit $?
fi

BASE_COMMIT="$(resolve "$BASE_REF")"
HEAD_COMMIT="$(resolve "$HEAD_REF")"
START=$SECONDS
mkdir -p "$OUT/logs" "$OUT/history" "$OUT/cache"
touch "$OUT/.api-burndown-out"

# Only ever delete a scratch directory this script created, and not while
# another run is using it.
if [ -e "$WORK" ]; then
  [ -f "$WORK/.api-burndown-work" ] || fail "refusing API_BURNDOWN_WORK=$WORK: it exists and isn't an api-burndown scratch directory"
  pid="$(cat "$WORK/.api-burndown-work")"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    fail "refusing API_BURNDOWN_WORK=$WORK: another run (process $pid) is using it"
  fi
  rm -rf "${WORK:?}"
fi
mkdir -p "$WORK"
echo "$$" > "$WORK/.api-burndown-work"

printf 'base: %s @ %s\nhead: %s @ %s\nrepository: %s\noutput: %s\npage: %s\n' \
  "$BASE_REF" "$BASE_COMMIT" "$HEAD_REF" "$HEAD_COMMIT" "$REPO" "$OUT" "$PAGE"

# 1. api-delta, unless a run for the same commits is given.
delta_matches() {
  python3 - "$1/logs/meta.json" "$BASE_COMMIT" "$HEAD_COMMIT" <<'EOF'
import json, sys
try:
    m = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if (m["baseCommit"], m["headCommit"]) == (sys.argv[2], sys.argv[3]) else 1)
EOF
}
# The last run is reused when nothing it depends on changed: the two
# commits, api-delta's committed tree (not with uncommitted changes) and
# the compiler.
delta_stamp() {
  local tree
  tree="$(git -C "$REPO" rev-parse HEAD:Utilities/api-delta 2>/dev/null || echo none)"
  if [ -n "$(git -C "$REPO" status --porcelain -- Utilities/api-delta)" ]; then tree="$tree-dirty-$$"; fi
  printf '%s %s %s %s\n' "$BASE_COMMIT" "$HEAD_COMMIT" "$tree" "$(swift --version 2>/dev/null | head -n 1)"
}
if [ -n "${API_BURNDOWN_DELTA:-}" ]; then
  [ -f "$DELTA/api-delta.json" ] || fail "API_BURNDOWN_DELTA=$DELTA has no api-delta.json"
  delta_matches "$DELTA" || fail "API_BURNDOWN_DELTA=$DELTA is for other commits"
  log "api-delta: using $DELTA"
elif [ -f "$DELTA/api-delta.json" ] && [ -f "$OUT/api-delta.stamp" ] \
    && [ "$(cat "$OUT/api-delta.stamp")" = "$(delta_stamp)" ] && delta_matches "$DELTA"; then
  log "api-delta: reusing the last run, for the same commits, tool and compiler"
else
  log "api-delta (log in $OUT/logs/api-delta.log)"
  rm -f "$OUT/api-delta.stamp"
  (cd "$REPO" && API_DELTA_OUT="$DELTA" API_DELTA_WORK="$WORK/api-delta-work" \
    BASE_REF="$BASE_COMMIT" HEAD_REF="$HEAD_COMMIT" "$UTIL/api-delta/regenerate.sh") \
    > "$OUT/logs/api-delta.log" 2>&1 || fail "api-delta failed" "$OUT/logs/api-delta.log"
  delta_stamp > "$OUT/api-delta.stamp"
fi

# 2. The graph.
case "$GRAPH" in
  run)
    log "api-graph (log in $OUT/logs/api-graph.log)"
    (cd "$REPO" && API_GRAPH_DELTA="$DELTA" BASE_REF="$BASE_COMMIT" HEAD_REF="$HEAD_COMMIT" \
      "$UTIL/api-graph/regenerate.sh") > "$OUT/logs/api-graph.log" 2>&1 \
      || fail "api-graph failed" "$OUT/logs/api-graph.log"
    GRAPH_FILE="${API_GRAPH_OUT:-$REPO/.build/api-graph}/graph.json.gz"
    GRAPH_SOURCE="api-graph, run by this script"
    ;;
  auto)
    GRAPH_FILE="" GRAPH_SOURCE=""
    ;;
  *)
    if [ -d "$GRAPH" ]; then GRAPH_FILE="$GRAPH/graph.json.gz"
    elif [ -f "$GRAPH" ]; then GRAPH_FILE="$GRAPH"
    elif [ -n "$STORE" ] && c="$(git -C "$REPO" rev-parse --verify --quiet "$GRAPH^{commit}")" \
        && [ -f "$STORE/$c.json.gz" ]; then GRAPH_FILE="$STORE/$c.json.gz"
    else fail "API_BURNDOWN_GRAPH=$GRAPH isn't a graph file, an api-graph output or a commit the store has"
    fi
    GRAPH_SOURCE="API_BURNDOWN_GRAPH"
    ;;
esac
if [ -z "$GRAPH_FILE" ]; then
  choice="$(python3 "$S/choose_graph.py" --repo "$REPO" --head "$HEAD_COMMIT" \
    --candidate "$REPO/.build/api-graph/graph.json.gz" ${STORE:+--store "$STORE"})" \
    || fail "no API graph: run Utilities/api-graph/regenerate.sh, or set API_BURNDOWN_GRAPH=run"
  GRAPH_FILE="${choice%%	*}"
  GRAPH_SOURCE="${choice#*	}"
fi
[ -f "$GRAPH_FILE" ] || fail "no graph at $GRAPH_FILE"
log "graph: $GRAPH_FILE ($GRAPH_SOURCE)"

# 3. The burn-down, the page, and the check.
log "burn-down (log in $OUT/logs/burndown.log)"
args=(--repo "$REPO" --delta "$DELTA" --graph "$GRAPH_FILE" --graph-source "$GRAPH_SOURCE"
  --pitches "$PITCHES" --pitches-rel "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$PITCHES" "$REPO")"
  --states "$STATES" --cache "$OUT/history" --sdk-cache "$OUT/cache" --work "$WORK"
  --base-ref "$BASE_REF" --head-ref "$HEAD_REF" --today "$TODAY" --out-json "$OUT/burndown.json")
if [ -n "${API_BURNDOWN_VOCAB:-}" ]; then args+=(--vocab "$API_BURNDOWN_VOCAB"); fi
if [ -n "$COVERAGE" ]; then args+=(--coverage-results "$COVERAGE"); fi
if [ -n "$STORE" ]; then args+=(--store "$STORE"); fi
if [ -n "$UPSTREAM" ]; then args+=(--upstream "$UPSTREAM"); fi
python3 "$S/burndown.py" "${args[@]}" 2>&1 | tee "$OUT/logs/burndown.log"
[ "${PIPESTATUS[0]}" = 0 ] || fail "burndown.py failed" "$OUT/logs/burndown.log"
mkdir -p "$(dirname "$PAGE")"
python3 "$S/page.py" "$OUT/burndown.json" "$PAGE"
log "check"
python3 "$S/burndown.py" --check --out-json "$OUT/burndown.json" --delta "$DELTA" --page "$PAGE"

rm -rf "${WORK:?}"
# 4. verify.sh: the checks a reviewer would do by hand (README.md, "Verify").
if [ -z "$NO_VERIFY" ]; then
  log "verify (report in $OUT/verify.md)"
  API_BURNDOWN_OUT="$OUT" API_BURNDOWN_PAGE="$PAGE" API_BURNDOWN_DELTA="$DELTA" API_BURNDOWN_SNAPSHOTS="$STORE" \
    API_BURNDOWN_COVERAGE_RESULTS="$COVERAGE" API_BURNDOWN_UPSTREAM="$UPSTREAM" "$TOOL/verify.sh" \
    || fail "verify.sh failed: see $OUT/verify.md (--no-verify skips it)"
fi
log "done in $((SECONDS - START)) s: $PAGE and $OUT/burndown.json"
