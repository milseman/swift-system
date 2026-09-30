#!/bin/bash
# Pins what the api-graph-speed measurements read from outside this
# repository, so that other lanes' work can't change it between runs:
#   - adopters/<dir>: a copy of each clone's git directory in ../adopters
#     (APFS clones of the files: refs, reflogs, shallow boundary and origin
#     URL included, no working tree), then checked against the original: the
#     same refs, HEAD, and migration merge base;
#   - ecosystem/ and coverage-results/: APFS clones of ../ecosystem and
#     ../coverage-results.
#
#   Prototype/ApiGraphSpeed/pin.sh [DEST]     # default ${TMPDIR}api-graph-speed
#
# Keep DEST the same for every run that shares a cache: the cache keys hold
# the absolute paths of the path dependencies that aren't clones.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
SRC="$(dirname "$ROOT")"
DEST="${1:-${TMPDIR:-/tmp/}api-graph-speed}"
DEST="${DEST%/}"
BRANCH="${API_GRAPH_ADOPTER_BRANCH:-migrate-darwin}"

[ ! -e "$DEST/adopters" ] || { echo "error: $DEST/adopters exists; delete it first" >&2; exit 1; }
mkdir -p "$DEST/adopters"

refs() { git -C "$1" for-each-ref --format='%(refname) %(objectname) %(symref)'; git -C "$1" rev-parse HEAD; \
  git -C "$1" symbolic-ref -q HEAD || true; }

# adopters.py's choice of main ref, and the migration's merge base with it.
base_of() {
  local r tip
  tip="$(git -C "$1" rev-parse --verify --quiet "$BRANCH^{commit}")" || { echo "no $BRANCH"; return; }
  for r in main master origin/main origin/master origin/HEAD; do
    if git -C "$1" rev-parse --verify --quiet "$r^{commit}" >/dev/null; then
      echo "$tip $r $(git -C "$1" merge-base "$tip" "$r")"
      return
    fi
  done
  echo "$tip no main ref"
}

for orig in "$SRC"/adopters/*/; do
  orig="${orig%/}"
  d="$(basename "$orig")"
  [ -d "$orig/.git" ] || { echo "skip $d: no .git directory"; continue; }
  mkdir "$DEST/adopters/$d"
  cp -cR "$orig/.git" "$DEST/adopters/$d/.git"
  # A lock another lane held at the moment of the copy isn't the copy's.
  find "$DEST/adopters/$d/.git" -name '*.lock' -delete
  if [ "$(refs "$orig")" != "$(refs "$DEST/adopters/$d")" ] || [ "$(base_of "$orig")" != "$(base_of "$DEST/adopters/$d")" ]; then
    echo "error: $d changed while it was copied; delete $DEST and rerun" >&2
    exit 1
  fi
  printf '%-28s %s\n' "$d" "$(base_of "$DEST/adopters/$d" | cut -c1-80)"
done

for dir in ecosystem coverage-results; do
  if [ -d "$SRC/$dir" ]; then
    cp -cR "$SRC/$dir" "$DEST/$dir"
    echo "$dir: $(find "$DEST/$dir" -maxdepth 1 -mindepth 1 | wc -l | tr -d ' ') entries"
  fi
done
echo "pinned into $DEST"
