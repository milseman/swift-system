#!/bin/bash
# Generates a report of the public API delta between two commits for the
# SystemPackage and SystemSockets modules, plus DocC archives for both. See
# README.md in this directory.
#
#   Utilities/api-delta/regenerate.sh                  # main vs system-next
#   BASE_REF=main HEAD_REF=HEAD Utilities/api-delta/regenerate.sh
#
# Environment:
#   BASE_REF, HEAD_REF  the commits to compare (default main and system-next)
#   API_DELTA_OUT       output directory (default .build/api-delta)
#   API_DELTA_WORK      scratch directory (default .build/api-delta-work)
#
# Refs resolve in the git worktree of the current directory if it belongs to
# this repository, and otherwise in the worktree holding this script. So HEAD
# is the HEAD of the worktree you run this from, and the default directories
# are in its .build.
#
# Tracked files are never modified: each commit is exported with `git archive`,
# and only the exported Package.swift is patched. The output and scratch
# directories must be ignored by git or outside any worktree, and this script
# deletes only directories it created.
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

# SwiftPM runs manifest compilation under sandbox-exec, which fails when this
# script itself runs in a sandbox ("sandbox_apply: Operation not permitted").
# The manifests are this repository's own.
SWIFTPM=(--disable-sandbox)

log() { printf '\n== %s\n' "$*"; }

# fail MESSAGE [LOG]: prints MESSAGE and the end of LOG, then exits.
fail() {
  echo "error: $1" >&2
  if [ -n "${2:-}" ]; then
    echo "-- last lines of $2:" >&2
    tail -n 20 "$2" >&2
  fi
  exit 1
}

# logged LOG COMMAND...: runs COMMAND with its output in LOG.
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

# check_dir NAME DIR: refuses a directory that this script mustn't create or
# delete. That's one holding the repository, $HOME or this script, and one
# inside a git directory, or inside a worktree but not ignored by it.
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

# The output directory is replaced only at the end of a successful run.
check_out() {
  if [ -e "$OUT" ] && [ ! -f "$OUT/.api-delta-out" ]; then
    fail "refusing API_DELTA_OUT=$OUT: it exists and isn't api-delta output"
  fi
}

BASE_REF="${BASE_REF:-main}"
HEAD_REF="${HEAD_REF:-system-next}"
BASE_COMMIT="$(resolve "$BASE_REF")"
HEAD_COMMIT="$(resolve "$HEAD_REF")"
OUT="$(abspath "${API_DELTA_OUT:-$REPO/.build/api-delta}")"
WORK="$(abspath "${API_DELTA_WORK:-$REPO/.build/api-delta-work}")"
STAGE="$WORK/out"

check_dir API_DELTA_OUT "$OUT"
check_dir API_DELTA_WORK "$WORK"
case "$OUT/" in "$WORK"/*) fail "refusing API_DELTA_OUT=$OUT: it overlaps API_DELTA_WORK=$WORK" ;; esac
case "$WORK/" in "$OUT"/*) fail "refusing API_DELTA_OUT=$OUT: it overlaps API_DELTA_WORK=$WORK" ;; esac
check_out

# Only ever delete a scratch directory this script created, and not while
# another run is using it. The marker holds the process ID of the last run.
if [ -e "$WORK" ]; then
  [ -f "$WORK/.api-delta-work" ] || fail "refusing API_DELTA_WORK=$WORK: it exists and isn't an api-delta scratch directory"
  pid="$(cat "$WORK/.api-delta-work")"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    fail "refusing API_DELTA_WORK=$WORK: another run (process $pid) is using it"
  fi
  rm -rf "${WORK:?}"
fi
mkdir -p "$WORK" "$STAGE/docs"
echo "$$" > "$WORK/.api-delta-work"
touch "$STAGE/.api-delta-out"

printf 'base: %s @ %s\nhead: %s @ %s\nrepository: %s\noutput: %s\nscratch: %s\n' \
  "$BASE_REF" "$BASE_COMMIT" "$HEAD_REF" "$HEAD_COMMIT" "$REPO" "$OUT" "$WORK"
if [ "$HEAD_COMMIT" = "$(git -C "$REPO" rev-parse HEAD)" ] && ! git -C "$REPO" diff --quiet HEAD -- Sources; then
  echo "note: the uncommitted changes in $REPO/Sources aren't part of the report"
fi

for side in base head; do
  if [ "$side" = base ]; then ref="$BASE_REF" commit="$BASE_COMMIT"; else ref="$HEAD_REF" commit="$HEAD_COMMIT"; fi
  d="$WORK/$side"
  mkdir -p "$d/src" "$d/docs"

  log "[$side] exporting $ref (${commit:0:7})"
  git -C "$REPO" archive "$commit" | tar -x -C "$d/src"
  python3 "$S/patch_manifest.py" "$d/src/Package.swift"

  modules=(SystemPackage)
  if grep -q 'name: "SystemSockets"' "$d/src/Package.swift"; then modules+=(SystemSockets); fi

  # dump-symbol-graph exits 1 because it can't load SwiftPM's synthesized test
  # module ("swift_systemPackageTests"); check for the graphs instead.
  for variant in delta docs; do
    log "[$side] symbol graphs ($variant)"
    flags=(--minimum-access-level public --emit-extension-block-symbols --pretty-print)
    if [ "$variant" = delta ]; then flags+=(--skip-synthesized-members --skip-inherited-docs); fi
    swift package "${SWIFTPM[@]}" --package-path "$d/src" --scratch-path "$d/build" dump-symbol-graph "${flags[@]}" \
      > "$d/dump-$variant.log" 2>&1 || true
    sg="$(find "$d/build" -maxdepth 2 -type d -name symbolgraph -print -quit)"
    mkdir -p "$d/sg-$variant"
    for m in "${modules[@]}"; do
      [ -f "$sg/$m.symbols.json" ] || fail "no $m.symbols.json from dump-symbol-graph" "$d/dump-$variant.log"
      for f in "$sg/$m.symbols.json" "$sg/$m"@*.symbols.json; do
        if [ -f "$f" ]; then cp "$f" "$d/sg-$variant/"; fi
      done
    done
  done

  # -Xswiftc reaches every Swift target, so building SystemSockets checks
  # SystemPackage too.
  check_module="${modules[${#modules[@]}-1]}"
  log "[$side] explicit-availability check ($check_module)"
  logged "$d/reqavail.log" swift build "${SWIFTPM[@]}" --package-path "$d/src" --scratch-path "$d/build-reqavail" \
    --target "$check_module" -Xswiftc -Xfrontend -Xswiftc -require-explicit-availability=warn

  log "[$side] source scan"
  python3 "$S/scan_sources.py" "$d/src" "$d/scan.json"

  log "[$side] DocC"
  archives=()
  for m in "${modules[@]}"; do
    python3 "$S/docs_graphs.py" "$d/sg-docs" "$d/docs/sg-$m" "$m"
    convert=(convert
      --additional-symbol-graph-dir "$d/docs/sg-$m"
      --output-path "$d/docs/$m.doccarchive"
      --fallback-display-name "$m"
      --fallback-bundle-identifier "org.swift.system.$m"
      --fallback-default-module-kind "Swift Package"
      --platform name=System,version=199.0.0,beta=true
      --enable-experimental-external-link-support
      --diagnostics-file "$d/docs/$m.diagnostics.json")
    if [ "$m" != SystemPackage ]; then convert+=(--dependency "$d/docs/SystemPackage.doccarchive"); fi
    logged "$d/docs/$m.log" xcrun docc "${convert[@]}"
    archives+=("$d/docs/$m.doccarchive")
  done
  if [ "${#archives[@]}" -gt 1 ]; then
    logged "$d/docs/merge.log" xcrun docc merge "${archives[@]}" --output-path "$d/docs/merged.doccarchive" \
      --synthesized-landing-page-name "swift-system ($ref)" \
      --synthesized-landing-page-kind Package
    cp -R "$d/docs/merged.doccarchive" "$STAGE/docs/$side.doccarchive"
  else
    # `docc merge` of a single archive fails in this toolchain; ship it as is.
    cp -R "${archives[0]}" "$STAGE/docs/$side.doccarchive"
  fi
done

# Fixed diff options, so that git configuration can't change the line map.
log "source diff"
git -C "$REPO" -c core.quotePath=false diff --no-ext-diff --no-textconv --no-color \
  --src-prefix=a/ --dst-prefix=b/ --find-renames -U0 "$BASE_COMMIT" "$HEAD_COMMIT" \
  -- Sources/System Sources/SystemSockets > "$WORK/src.diff"

spi_count() {
  { git -C "$REPO" grep --no-color -F -c '@_spi' "$1" -- Sources/System Sources/SystemSockets || true; } \
    | awk -F: '{n += $NF} END {print n + 0}'
}
SPI_BASE="$(spi_count "$BASE_COMMIT")"
SPI_HEAD="$(spi_count "$HEAD_COMMIT")"

python3 - "$WORK/meta.json" "$REPO" "$BASE_REF" "$BASE_COMMIT" "$HEAD_REF" "$HEAD_COMMIT" "$SPI_BASE" "$SPI_HEAD" <<'EOF'
import datetime, json, platform, subprocess, sys
out, repo, base_ref, base_commit, head_ref, head_commit, spi_base, spi_head = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(c): return sh("git", "-C", repo, "log", "-1", "--no-show-signature", "--format=%s", c)
json.dump({
  "baseRef": base_ref, "headRef": head_ref,
  "baseCommit": base_commit, "headCommit": head_commit,
  "baseSubject": subject(base_commit), "headSubject": subject(head_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": sh("swift", "--version").split("\n")[0].replace("swift-driver version: ", "swift-driver "),
  "sdk": sh("xcrun", "--sdk", "macosx", "--show-sdk-version"),
  "spiCountBase": int(spi_base),
  "spiCountHead": int(spi_head),
}, open(out, "w"), indent=1)
EOF

log "symbol graph delta"
python3 "$S/symbolgraph_delta.py" \
  --base "$WORK/base/sg-delta" --base-root "$WORK/base/src" --base-docs "$WORK/base/sg-docs" \
  --head "$WORK/head/sg-delta" --head-root "$WORK/head/src" --head-docs "$WORK/head/sg-docs" \
  --out "$WORK/delta.json"

log "swift-api-digester cross-check"
python3 "$S/digester_check.py" "$WORK" "$WORK/delta.json" "$WORK/digester.json"

log "report"
report=(
  --delta "$WORK/delta.json"
  --base-scan "$WORK/base/scan.json" --head-scan "$WORK/head/scan.json"
  --diff "$WORK/src.diff"
  --base-reqavail "$WORK/base/reqavail.log" --head-reqavail "$WORK/head/reqavail.log"
  --base-root "$WORK/base/src" --head-root "$WORK/head/src"
  --meta "$WORK/meta.json"
  --digester "$WORK/digester.json"
  --out-md "$STAGE/API-DELTA.md" --out-json "$STAGE/api-delta.json")
for side in base head; do
  for f in "$WORK/$side"/docs/*.diagnostics.json; do
    if [ -f "$f" ]; then report+=(--docc "$side:$(basename "$f" .diagnostics.json)=$f"); fi
  done
done
python3 "$S/report.py" "${report[@]}"

for side in base head; do
  mkdir -p "$STAGE/symbolgraphs/$side" "$STAGE/logs/$side"
  cp "$WORK/$side"/sg-delta/*.json "$STAGE/symbolgraphs/$side/"
  cp "$WORK/$side"/dump-*.log "$WORK/$side/reqavail.log" "$WORK/$side"/docs/*.log \
    "$WORK/$side"/docs/*.diagnostics.json "$STAGE/logs/$side/"
done
cp "$WORK/src.diff" "$WORK/meta.json" "$WORK/digester.json" "$STAGE/logs/"
for f in "$WORK"/digester-*.txt; do
  if [ -f "$f" ]; then cp "$f" "$STAGE/logs/"; fi
done

log "replacing $OUT"
check_out
rm -rf "${OUT:?}"
mkdir -p "$(dirname "$OUT")"
mv "$STAGE" "$OUT"

log "done: $OUT/API-DELTA.md"
