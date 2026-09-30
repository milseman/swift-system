#!/bin/bash
# The summary of one measure.sh run: summary.txt in its directory, printed
# without the per-migration lines.
#
#   Prototype/ApiGraphSpeed/summarize.sh RUN_DIR
set -euo pipefail
RUN="${1:?usage: summarize.sh RUN_DIR}"
{
  grep -E '^(run|env|exit):' "$RUN/meta.txt" || true
  echo "time: $(tail -n 1 "$RUN/time.txt")"
  echo "load (1, 5, 15 min): $(grep '^load before' "$RUN/meta.txt" | cut -d: -f2-);" \
    "after$(grep '^load after' "$RUN/meta.txt" | cut -d: -f2-); each minute's 1-min average:" \
    "$(awk '{print $2}' "$RUN/load.txt" | sort -n | awk '{v[NR] = $1; s += $1} END {if (NR) printf "min %s, median %s, max %s, mean %.1f (%d samples)", v[1], v[int((NR + 1) / 2)], v[NR], s / NR, NR}')"
  echo "free disk: $(grep '^free before' "$RUN/meta.txt" | cut -d: -f2- | tr -d ' ') before," \
    "$(grep '^free after' "$RUN/meta.txt" | cut -d: -f2- | tr -d ' ') after"
  echo "steps (seconds since the start):"
  grep -E '^ *[0-9.]+ == ' "$RUN/regenerate.log" | sed 's/^/  /' | cut -c1-120
  echo "adopters:"
  grep -E '^ *[0-9.]+ adopters: ' "$RUN/regenerate.log" | grep -vE 'would benefit at|: migrate-darwin @' \
    | sed 's/^/  /' || true
  if ! grep -q '^exit: 0$' "$RUN/meta.txt"; then
    echo "errors:"
    grep -E 'error:|Traceback|Error' "$RUN/regenerate.log" | tail -n 20 | sed 's/^/  /'
  fi
} > "$RUN/summary.txt"
grep -vE '^  +[0-9.]+ adopters: [^:0-9]+: ' "$RUN/summary.txt"
