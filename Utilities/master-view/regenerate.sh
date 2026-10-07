#!/bin/bash
# Regenerates the master view: Prototype/MasterView/master.html, one
# self-contained page of what system-next adds over main, by API and by
# package, with three burn-down charts; Utilities/master-view/universe.tsv,
# the packages it covers; and Prototype/MasterView/history.tsv, the charts'
# points, which each run adds today's to. See README.md in this directory.
#
#   Utilities/master-view/regenerate.sh            # everything, then the check
#   Utilities/master-view/regenerate.sh --check    # reconcile the last run's page; non-zero on a mismatch
#   Utilities/master-view/regenerate.sh --shots    # also the report's three screenshots
#   Utilities/master-view/regenerate.sh MASTER_VIEW_STATUS=.build/status   # settings as arguments, too
#
# Environment (or NAME=value arguments):
#   BASE_REF, HEAD_REF           the commits api-burndown compares (default main, system-next)
#   MASTER_VIEW_OUT              scratch and the inputs' runs (default .build/master-view)
#   MASTER_VIEW_PAGE             the page (default Prototype/MasterView/master.html)
#   MASTER_VIEW_UNIVERSE         the packages (default Utilities/master-view/universe.tsv)
#   MASTER_VIEW_HISTORY          the charts' points (default Prototype/MasterView/history.tsv)
#   MASTER_VIEW_BURNDOWN         an api-burndown output directory to use instead of running
#                                api-burndown into MASTER_VIEW_OUT/api-burndown
#   MASTER_VIEW_STATUS           a directory with status.sh's ledger.json and STATUS.md to use
#                                instead of running status.sh into MASTER_VIEW_OUT/status
#   MASTER_VIEW_GRAPH_CACHE      api-graph's adopter cache (default: this worktree's
#                                .build/api-graph-cache, else ../swift-system/.build/api-graph-cache)
#   MASTER_VIEW_ADOPTERS, MASTER_VIEW_ECOSYSTEM, MASTER_VIEW_EXAMPLES, MASTER_VIEW_COVERAGE_RESULTS
#                                the sibling directories (default ../adopters, ../ecosystem,
#                                ../swift-system-examples, ../coverage-results)
#   MASTER_VIEW_TODAY            the day the run counts as (default today), YYYY-MM-DD
#
# Nothing is fetched, and the only tracked files written are the page,
# universe.tsv and history.tsv. api-burndown and status.sh write only under
# MASTER_VIEW_OUT: their own pages and STATUS.md are left alone.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1

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
  if [ -n "${2:-}" ] && [ -f "$2" ]; then echo "-- last lines of $2:" >&2; tail -n 20 "$2" >&2; fi
  exit 1
}

CHECK_ONLY="" SHOTS=""
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --shots) SHOTS=1 ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    BASE_REF=*|HEAD_REF=*|MASTER_VIEW_*=*) export "${arg?}" ;;
    *) fail "unknown argument $arg (see --help)" ;;
  esac
done

# Absolute path of $1, which needn't exist yet (relative to the repository).
abspath() {
  case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$REPO/$1" ;; esac
}

OUT="$(abspath "${MASTER_VIEW_OUT:-.build/master-view}")"
PAGE="$(abspath "${MASTER_VIEW_PAGE:-Prototype/MasterView/master.html}")"
UNIVERSE="$(abspath "${MASTER_VIEW_UNIVERSE:-Utilities/master-view/universe.tsv}")"
HISTORY="$(abspath "${MASTER_VIEW_HISTORY:-Prototype/MasterView/history.tsv}")"
ADOPTERS="$(abspath "${MASTER_VIEW_ADOPTERS:-$SIBLINGS/adopters}")"
ECOSYSTEM="$(abspath "${MASTER_VIEW_ECOSYSTEM:-$SIBLINGS/ecosystem}")"
EXAMPLES="$(abspath "${MASTER_VIEW_EXAMPLES:-$SIBLINGS/swift-system-examples}")"
COVERAGE="$(abspath "${MASTER_VIEW_COVERAGE_RESULTS:-$SIBLINGS/coverage-results}")"
if [ -n "${MASTER_VIEW_GRAPH_CACHE:-}" ]; then CACHE="$(abspath "$MASTER_VIEW_GRAPH_CACHE")"
elif [ -d "$REPO/.build/api-graph-cache" ]; then CACHE="$REPO/.build/api-graph-cache"
else CACHE="$SIBLINGS/swift-system/.build/api-graph-cache"
fi
BURNDOWN="$(abspath "${MASTER_VIEW_BURNDOWN:-$OUT/api-burndown}")"
STATUS_DIR="$(abspath "${MASTER_VIEW_STATUS:-$OUT/status}")"
TODAY="${MASTER_VIEW_TODAY:-$(date +%Y-%m-%d)}"

# The scratch directory must be one git ignores, and this script's own.
case "$OUT/" in "$REPO/"*) git -C "$REPO" check-ignore -q "$OUT" || fail "refusing MASTER_VIEW_OUT=$OUT: git doesn't ignore it" ;; esac
[ "$OUT" != / ] && [ "$OUT" != "$REPO" ] && [ "$OUT" != "$HOME" ] || fail "refusing MASTER_VIEW_OUT=$OUT"
if [ -e "$OUT" ] && [ ! -f "$OUT/.master-view-out" ]; then
  fail "refusing MASTER_VIEW_OUT=$OUT: it exists and isn't this script's"
fi

check() {
  local graph
  graph="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["meta"]["graph"]["path"])' "$OUT/master.json")"
  python3 "$S/check.py" --master "$OUT/master.json" --page "$PAGE" --delta "$BURNDOWN/api-delta/api-delta.json" \
    --ledger-json "$STATUS_DIR/ledger.json" --status-md "$STATUS_DIR/STATUS.md" --universe "$UNIVERSE" \
    --history "$HISTORY" --graph "$graph"
}

if [ -n "$CHECK_ONLY" ]; then
  [ -f "$OUT/master.json" ] || fail "no $OUT/master.json: run this script without --check first"
  check
  exit $?
fi

START=$SECONDS
mkdir -p "$OUT/logs"
touch "$OUT/.master-view-out"
printf 'repository: %s\npage: %s\nscratch: %s\n' "$REPO" "$PAGE" "$OUT"

# 1. api-burndown: the added declarations, their pitch states, the days.
if [ -n "${MASTER_VIEW_BURNDOWN:-}" ]; then
  [ -f "$BURNDOWN/burndown.json" ] || fail "MASTER_VIEW_BURNDOWN=$BURNDOWN has no burndown.json"
  log "api-burndown: using $BURNDOWN"
else
  log "api-burndown (log in $OUT/logs/api-burndown.log)"
  (cd "$REPO" && API_BURNDOWN_OUT="$BURNDOWN" API_BURNDOWN_WORK="$OUT/api-burndown-work" \
    API_BURNDOWN_PAGE="$BURNDOWN/burndown.html" API_BURNDOWN_TODAY="$TODAY" "$UTIL/api-burndown/regenerate.sh") \
    > "$OUT/logs/api-burndown.log" 2>&1 || fail "api-burndown failed" "$OUT/logs/api-burndown.log"
fi

# 2. status.sh: the ledger, with its STATUS.md, written here; the tracked
# STATUS.md is left alone (and restored if a run rewrote it anyway).
if [ -n "${MASTER_VIEW_STATUS:-}" ]; then
  [ -f "$STATUS_DIR/ledger.json" ] && [ -f "$STATUS_DIR/STATUS.md" ] || fail "MASTER_VIEW_STATUS=$STATUS_DIR needs ledger.json and STATUS.md"
  log "the ledger: using $STATUS_DIR"
else
  log "the ledger: status.sh (log in $OUT/logs/status.log)"
  tracked="$REPO/Prototype/Status/STATUS.md"
  before="$(git -C "$REPO" status --porcelain -- "$tracked")"
  (cd "$REPO" && STATUS_OUT="$STATUS_DIR/STATUS.md" STATUS_WORK="$OUT/status-work" \
    STATUS_LEDGER_JSON="$STATUS_DIR/ledger.json" "$UTIL/adopter-coverage/status.sh") \
    > "$OUT/logs/status.log" 2>&1 || fail "status.sh failed" "$OUT/logs/status.log"
  if [ -z "$before" ] && [ -n "$(git -C "$REPO" status --porcelain -- "$tracked")" ]; then
    git -C "$REPO" checkout -- "$tracked"
    echo "note: status.sh rewrote $tracked; restored it"
  fi
fi

# 3. The packages.
log "the universe"
python3 "$S/universe.py" --repo "$REPO" --ecosystem "$ECOSYSTEM" --adopters "$ADOPTERS" --examples "$EXAMPLES" \
  --non-swift "$TOOL/non-swift.tsv" --out "$UNIVERSE"

# 4. The data, the page and the check.
log "the data (log in $OUT/logs/assemble.log)"
mkdir -p "$(dirname "$HISTORY")" "$(dirname "$PAGE")"
python3 "$S/assemble.py" --repo "$REPO" --universe "$UNIVERSE" --burndown "$BURNDOWN" --graph-cache "$CACHE" \
  --ledger-json "$STATUS_DIR/ledger.json" --status-md "$STATUS_DIR/STATUS.md" --adopters "$ADOPTERS" \
  --ecosystem "$ECOSYSTEM" --examples "$EXAMPLES" --coverage-results "$COVERAGE" --history "$HISTORY" \
  --today "$TODAY" --out "$OUT/master.json" 2>&1 | tee "$OUT/logs/assemble.log"
[ "${PIPESTATUS[0]}" = 0 ] || fail "assemble.py failed" "$OUT/logs/assemble.log"
python3 "$S/page.py" "$OUT/master.json" "$PAGE"
log "check"
check

# 5. The report's screenshots, with the page rendered in a WKWebView.
if [ -n "$SHOTS" ]; then
  log "screenshots"
  swiftc -O -o "$OUT/snapshot" "$S/snapshot.swift" > "$OUT/logs/snapshot-build.log" 2>&1 \
    || fail "couldn't build the snapshot tool" "$OUT/logs/snapshot-build.log"
  dir="$(dirname "$PAGE")"
  decl="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))["declarations"]
types = {"swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.actor"}
i = max(range(len(d)), key=lambda i: (len(d[i]["usedBy"]) if d[i]["kind"] not in types else -1, d[i]["state"] == 2, -i))
n = sum(1 for x in d[:i + 1] if (x["module"], x["path"]) == (d[i]["module"], d[i]["path"]))
print(d[i]["module"] + ":" + d[i]["path"] + ("~%d" % n if n > 1 else ""))' "$OUT/master.json")"
  "$OUT/snapshot" "$PAGE" "$dir/shot-charts.png" --width 1440 --height 700
  "$OUT/snapshot" "$PAGE" "$dir/shot-used-by.png" --width 1440 --height 1300 --js "location.hash='decl=$decl'"
  "$OUT/snapshot" "$PAGE" "$dir/shot-package.png" --width 1440 --height 1500 --js "location.hash='pkg=swift-nio'"
  "$OUT/snapshot" "$PAGE" "$OUT/shot-dark.png" --width 1440 --height 1500 --dark
fi
log "done in $((SECONDS - START)) s: $PAGE"
