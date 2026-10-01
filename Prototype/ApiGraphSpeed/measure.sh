#!/bin/bash
# One timed regenerate.sh run for the api-graph-speed measurements, reading
# the inputs pin.sh pinned. The tool is copied first, from a commit's
# Utilities or the working tree's, so the working tree can change while it
# runs. regenerate.sh's output goes to a log, each line prefixed with the
# seconds since the start; summarize.sh then writes summary.txt: the wall
# time, the load average (sampled each minute) and each step's start.
#
#   Prototype/ApiGraphSpeed/measure.sh NAME [COMMIT] [VAR=value ...]
#     COMMIT: the commit whose Utilities to run (default: the working tree's)
#     VAR=value: settings, as in the environment, so that every run's command
#     starts with this script (one permission rule covers them)
#
# Settings (VAR=value or the environment):
#   BASE_REF, HEAD_REF  default 1b452c2 and 3f9f9e1, the lane's measurements'
#   SPEED_PINNED        pin.sh's directory (default ${TMPDIR}api-graph-speed)
#   SPEED_DIR           default .build/speed; the run goes in runs/NAME
#   API_GRAPH_*         override this script's: the cache, the builds and the
#                       snapshot store in SPEED_DIR, and the pinned inputs
#
# The body is one block, so that bash has read all of it before it runs:
# editing this file during a run doesn't change the run.
{
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$HERE/../.." && pwd -P)"
NAME="${1:?usage: measure.sh NAME [COMMIT] [VAR=value ...]}"
shift
COMMIT=""
if [ $# -gt 0 ] && [[ "$1" != *=* ]]; then COMMIT="$1"; shift; fi
for setting in "$@"; do
  case "$setting" in
    BASE_REF=*|HEAD_REF=*|SPEED_*=*|API_GRAPH_*=*) export "$setting" ;;
    *) echo "error: not a setting: $setting" >&2; exit 1 ;;
  esac
done
PINNED="${SPEED_PINNED:-${TMPDIR:-/tmp/}api-graph-speed}"
PINNED="${PINNED%/}"
SPEED="${SPEED_DIR:-$ROOT/.build/speed}"
RUN="$SPEED/runs/$NAME"
[ -d "$PINNED/adopters" ] || { echo "error: no $PINNED/adopters; run pin.sh" >&2; exit 1; }

rm -rf "$RUN"
mkdir -p "$RUN/tool"
cp "$HERE/summarize.sh" "$RUN/summarize.sh"
if [ -n "$COMMIT" ]; then
  git -C "$ROOT" archive "$COMMIT" Utilities | tar -x -C "$RUN/tool"
  tool="$COMMIT"
else
  cp -R "$ROOT/Utilities" "$RUN/tool/"
  tool="working tree at $(git -C "$ROOT" rev-parse --short HEAD)"
fi

export BASE_REF="${BASE_REF:-1b452c2}" HEAD_REF="${HEAD_REF:-3f9f9e1}"
export API_GRAPH_ADOPTERS="${API_GRAPH_ADOPTERS-$PINNED/adopters}"
export API_GRAPH_ECOSYSTEM="${API_GRAPH_ECOSYSTEM-$PINNED/ecosystem}"
export API_GRAPH_COVERAGE_RESULTS="${API_GRAPH_COVERAGE_RESULTS-$PINNED/coverage-results}"
export API_GRAPH_CACHE="${API_GRAPH_CACHE:-$SPEED/cache}"
export API_GRAPH_BUILDS="${API_GRAPH_BUILDS-$SPEED/builds}"
export API_GRAPH_SNAPSHOTS="${API_GRAPH_SNAPSHOTS-$SPEED/snapshots}"
export API_GRAPH_OUT="$RUN/out" API_GRAPH_WORK="$SPEED/work"

loadavg() { sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1, $2, $3}'; }
freegb() { df -g "$ROOT" | awk 'NR == 2 {print $4}'; }
power() { pmset -g ps | head -n 1 | sed -E "s/^Now drawing from '(.*)'$/\1/"; }
(while sleep 60; do echo "$(date +%T) $(loadavg)"; done) > "$RUN/load.txt" &
sampler=$!
disown "$sampler"   # no "Terminated" line when it's stopped
trap 'kill $sampler 2>/dev/null || true' EXIT
{
  echo "run: $NAME ($(date '+%F %T')); tool: $tool; base $BASE_REF, head $HEAD_REF"
  env | grep -E '^API_GRAPH_(ADOPTER_|BUILDS|CACHE)' | sort | sed 's/^/env: /'
  echo "start: $(date '+%F %T')"
  echo "power before: $(power)"
  echo "load before: $(loadavg)"
  echo "free before: $(freegb) GiB"
} > "$RUN/meta.txt"
stamp() {
  python3 -u -c '
import sys, time
t0 = time.time()
for line in sys.stdin:
    sys.stdout.write(f"{time.time() - t0:7.1f} {line}")
    sys.stdout.flush()'
}
TIMEFORMAT="wall %R s, user %U s, sys %S s"
status=0
{ time (cd "$ROOT" && "$RUN/tool/Utilities/api-graph/regenerate.sh" 2>&1 | stamp > "$RUN/regenerate.log"); } \
  2> "$RUN/time.txt" || status=$?
kill "$sampler" 2>/dev/null || true
{
  echo "end: $(date '+%F %T')"
  echo "power after: $(power)"
  echo "load after: $(loadavg)"
  echo "free after: $(freegb) GiB"
  echo "exit: $status"
} >> "$RUN/meta.txt"
"$RUN/summarize.sh" "$RUN"
exit "$status"
}
