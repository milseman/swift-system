#!/bin/bash
# Regenerates api-delta-out/: the public API delta between two refs for the
# SystemPackage and SystemSockets modules, plus DocC archives for both.
# See "How this was generated" in API-DELTA.md (scripts/method.md).
#
#   api-delta-out/regenerate.sh
#   BASE_REF=main HEAD_REF=HEAD WORK=/tmp/api-delta-work api-delta-out/regenerate.sh
#
# Writes only to $WORK (scratch) and to this directory. Tracked files are never
# modified: each ref is exported with `git archive`, and only the exported
# Package.swift is patched.
set -euo pipefail

OUT="$(cd "$(dirname "$0")" && pwd)"
S="$OUT/scripts"
REPO="$(git -C "$OUT" rev-parse --show-toplevel)"
BASE_REF="${BASE_REF:-main}"
HEAD_REF="${HEAD_REF:-system-next}"
WORK="${WORK:-/tmp/api-delta-work}"

# SwiftPM runs manifest compilation under sandbox-exec, which fails when this
# script itself runs in a sandbox ("sandbox_apply: Operation not permitted").
# The manifests are this repository's own.
SWIFTPM=(--disable-sandbox)

log() { printf '\n== %s\n' "$*"; }
label() { printf '%s' "$1" | tr '/' '-'; }

# Only ever delete a scratch directory this script created.
case "$WORK" in ""|"/"|"$HOME"|"$REPO"|"$OUT") echo "refusing WORK=$WORK" >&2; exit 1 ;; esac
if [ -e "$WORK" ]; then
  [ -f "$WORK/.api-delta-work" ] || { echo "$WORK exists and isn't an api-delta scratch dir" >&2; exit 1; }
  rm -rf "$WORK"
fi
mkdir -p "$WORK"
touch "$WORK/.api-delta-work"

for side in base head; do
  if [ "$side" = base ]; then ref="$BASE_REF"; else ref="$HEAD_REF"; fi
  d="$WORK/$side"
  mkdir -p "$d/src" "$d/docs"

  log "[$side] exporting $ref ($(git -C "$REPO" rev-parse --short "$ref^{commit}"))"
  git -C "$REPO" archive "$ref" | tar -x -C "$d/src"
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
    sg="$(find "$d/build" -maxdepth 2 -type d -name symbolgraph | head -1)"
    for m in "${modules[@]}"; do
      [ -f "$sg/$m.symbols.json" ] || { echo "missing $m.symbols.json; see $d/dump-$variant.log" >&2; exit 1; }
    done
    mkdir -p "$d/sg-$variant"
    for m in "${modules[@]}"; do cp "$sg/$m.symbols.json" "$sg"/"$m"@*.symbols.json "$d/sg-$variant/" 2>/dev/null || cp "$sg/$m.symbols.json" "$d/sg-$variant/"; done
  done

  log "[$side] explicit-availability check (${modules[${#modules[@]}-1]})"
  swift build "${SWIFTPM[@]}" --package-path "$d/src" --scratch-path "$d/build-reqavail" --target "${modules[${#modules[@]}-1]}" \
    -Xswiftc -Xfrontend -Xswiftc -require-explicit-availability=warn > "$d/reqavail.log" 2>&1

  log "[$side] source scan"
  python3 "$S/scan_sources.py" "$d/src" "$d/scan.json"

  log "[$side] DocC"
  archives=()
  for m in "${modules[@]}"; do
    python3 "$S/docs_graphs.py" "$d/sg-docs" "$d/docs/sg-$m" "$m"
    deps=()
    if [ "$m" != SystemPackage ]; then deps=(--dependency "$d/docs/SystemPackage.doccarchive"); fi
    xcrun docc convert \
      --additional-symbol-graph-dir "$d/docs/sg-$m" \
      --output-path "$d/docs/$m.doccarchive" \
      --fallback-display-name "$m" \
      --fallback-bundle-identifier "org.swift.system.$m" \
      --fallback-default-module-kind "Swift Package" \
      --platform name=System,version=199.0.0,beta=true \
      --enable-experimental-external-link-support \
      ${deps[@]+"${deps[@]}"} \
      --diagnostics-file "$d/docs/$m.diagnostics.json" > "$d/docs/$m.log" 2>&1
    archives+=("$d/docs/$m.doccarchive")
  done
  if [ "${#archives[@]}" -gt 1 ]; then
    xcrun docc merge "${archives[@]}" --output-path "$d/docs/merged.doccarchive" \
      --synthesized-landing-page-name "swift-system ($ref)" \
      --synthesized-landing-page-kind Package > "$d/docs/merge.log" 2>&1
    printf '%s' "$d/docs/merged.doccarchive" > "$d/docs/final"
  else
    # `docc merge` of a single archive fails in this toolchain; ship it as is.
    printf '%s' "${archives[0]}" > "$d/docs/final"
  fi
done

log "source diff"
git -C "$REPO" diff -U0 "$BASE_REF" "$HEAD_REF" -- Sources/System Sources/SystemSockets > "$WORK/src.diff"

spi_count() { git -C "$REPO" grep -c '@_spi' "$1" -- Sources/System Sources/SystemSockets 2>/dev/null \
  | awk -F: '{n += $NF} END {print n + 0}'; }

python3 - "$WORK/meta.json" <<EOF
import json, sys, subprocess, datetime, platform
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
json.dump({
  "baseRef": "$BASE_REF", "headRef": "$HEAD_REF",
  "baseCommit": sh("git", "-C", "$REPO", "rev-parse", "$BASE_REF^{commit}"),
  "headCommit": sh("git", "-C", "$REPO", "rev-parse", "$HEAD_REF^{commit}"),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": sh("swift", "--version").split("\n")[0].replace("swift-driver version: ", "swift-driver "),
  "sdk": sh("xcrun", "--sdk", "macosx", "--show-sdk-version"),
  "spiCountBase": int("$(spi_count "$BASE_REF")"),
  "spiCountHead": int("$(spi_count "$HEAD_REF")"),
}, open(sys.argv[1], "w"), indent=1)
EOF

log "symbol graph delta"
python3 "$S/symbolgraph_delta.py" \
  --base "$WORK/base/sg-delta" --base-root "$WORK/base/src" --base-docs "$WORK/base/sg-docs" \
  --head "$WORK/head/sg-delta" --head-root "$WORK/head/src" --head-docs "$WORK/head/sg-docs" \
  --out "$WORK/delta.json"

log "swift-api-digester cross-check"
python3 "$S/digester_check.py" "$WORK" "$WORK/delta.json" "$WORK/digester.json"

log "report"
docc_args=()
for side in base head; do
  for f in "$WORK/$side"/docs/*.diagnostics.json; do
    [ -f "$f" ] && docc_args+=(--docc "$side:$(basename "$f" .diagnostics.json)=$f")
  done
done
rm -rf "$OUT/docs" "$OUT/symbolgraphs" "$OUT/logs" "$OUT/API-DELTA.md" "$OUT/api-delta.json"
python3 "$S/report.py" \
  --delta "$WORK/delta.json" \
  --base-scan "$WORK/base/scan.json" --head-scan "$WORK/head/scan.json" \
  --diff "$WORK/src.diff" \
  --base-reqavail "$WORK/base/reqavail.log" --head-reqavail "$WORK/head/reqavail.log" \
  --base-root "$WORK/base/src" --head-root "$WORK/head/src" \
  ${docc_args[@]+"${docc_args[@]}"} \
  --meta "$WORK/meta.json" \
  --digester "$WORK/digester.json" \
  --out-md "$OUT/API-DELTA.md" --out-json "$OUT/api-delta.json"

log "copying outputs to $OUT"
bl="$(label "$BASE_REF")"; hl="$(label "$HEAD_REF")"
mkdir -p "$OUT/docs" "$OUT/symbolgraphs/$bl" "$OUT/symbolgraphs/$hl" "$OUT/logs/$bl" "$OUT/logs/$hl"
cp -R "$(cat "$WORK/base/docs/final")" "$OUT/docs/$bl.doccarchive"
cp -R "$(cat "$WORK/head/docs/final")" "$OUT/docs/$hl.doccarchive"
cp "$WORK/base/sg-delta"/*.json "$OUT/symbolgraphs/$bl/"
cp "$WORK/head/sg-delta"/*.json "$OUT/symbolgraphs/$hl/"
for side in base head; do
  if [ "$side" = base ]; then l="$bl"; else l="$hl"; fi
  cp "$WORK/$side"/dump-*.log "$WORK/$side/reqavail.log" "$OUT/logs/$l/"
  cp "$WORK/$side"/docs/*.log "$WORK/$side"/docs/*.diagnostics.json "$OUT/logs/$l/"
done
cp "$WORK/src.diff" "$WORK/meta.json" "$WORK/digester.json" "$OUT/logs/"
cp "$WORK"/digester-*.txt "$OUT/logs/" 2>/dev/null || true

log "done: $OUT/API-DELTA.md"
