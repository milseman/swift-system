#!/bin/bash
# Builds one package, extracts its OS interfaces, checks them against the
# mapping and writes its report, into $STAGE/NAME. check.sh runs this once
# per package with the environment it exports; see check.sh.
#
#   package.sh NAME
#
# Exit status: 0 or 2 as check.py's (2: the check found problems), 1 when
# something failed.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
. "$S/common.sh"

name="$1"
CHECKOUTS=()
resolve_package "$name"
N="$WORK/$name"
O="$STAGE/$name"
rm -rf "${O:?}"
mkdir -p "$O/logs"
touch "$O/.adopter-coverage-out"

log "$PKG_TITLE: $P_REF @ $P_COMMIT ($P_PATH)"
if [ "$P_COMMIT" = "$(git -C "$P_PATH" rev-parse HEAD)" ] && ! git -C "$P_PATH" diff --quiet HEAD -- Sources Package.swift; then
  echo "note: the uncommitted changes in $P_PATH aren't part of the check"
fi

# The build is reused when the commit, the compiler and the build settings
# are the ones it was made with.
benv=(env)
for v in ${PKG_UNSET_ENV[@]+"${PKG_UNSET_ENV[@]}"}; do benv+=(-u "$v"); done
if [ -n "$P_SWIFT_EXEC" ]; then
  benv+=("SWIFT_EXEC=$P_SWIFT_EXEC" "SWIFT_EXEC_MANIFEST=$(xcrun --find swiftc)")
  compiler="$("$P_SWIFT_EXEC" --version 2>/dev/null | head -n 1)"
else
  compiler="$(swift --version 2>/dev/null | head -n 1)"
fi
key="$P_COMMIT | $compiler | ${P_SWIFT_EXEC} | ${PKG_BUILD_TARGETS[*]-} | ${PKG_BUILD_FLAGS[*]-} | ${PKG_UNSET_ENV[*]-}"

build_failed() {
  [ -z "$PKG_BUILD_HINT" ] || echo "hint: $PKG_BUILD_HINT" >&2
  fail "$1" "$2"
}

if [ -f "$N/index.json" ] && [ "$(cat "$N/key" 2>/dev/null)" = "$key" ]; then
  log "$name ${P_COMMIT:0:10}: reusing the build and index from the last run"
else
  rm -rf "${N:?}"
  mkdir -p "$N/src"
  log "exporting $name ${P_COMMIT:0:10}"
  git -C "$P_PATH" archive "$P_COMMIT" | tar -x -C "$N/src"
  log "building $name (debug, with an index store)${P_SWIFT_EXEC:+ with $P_SWIFT_EXEC}"
  : > "$N/build.log"
  if [ ${#PKG_BUILD_TARGETS[@]} -eq 0 ]; then
    "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
      ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
      || build_failed "swift build failed for $name" "$N/build.log"
  else
    for t in "${PKG_BUILD_TARGETS[@]}"; do
      "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" --target "$t" \
        ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
        || build_failed "swift build --target $t failed for $name" "$N/build.log"
    done
  fi
  "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
    ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} dump-package > "$N/dump.json" 2> "$N/dump.log" \
    || fail "swift package dump-package failed for $name" "$N/dump.log"
  "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
    ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} describe --type json > "$N/describe.json" 2> "$N/describe.log" \
    || fail "swift package describe failed for $name" "$N/describe.log"
  store="$(find "$N/build" -maxdepth 4 -type d -path '*/index/store' -print -quit)"
  [ -n "$store" ] || fail "the $name build left no index store" "$N/build.log"
  libindexstore="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/libIndexStore.dylib"
  [ -f "$libindexstore" ] || fail "no libIndexStore.dylib next to $(xcrun --find swift)"
  log "reading the index store"
  python3 "$S/indexstore.py" "$libindexstore" "$store" "$(cd "$N/src" && pwd -P)" "$N/index.json"
  echo "$key" > "$N/key"
fi

log "extracting $name's OS interfaces"
python3 "$S/extract.py" --package "$PACKAGES/$name.ini" --swift-version "$compiler" --root "$N/src" \
  --index "$N/index.json" --dump "$N/dump.json" --describe "$N/describe.json" --out "$O/interfaces.json"

python3 - "$O/meta.json" "$name" "$PKG_TITLE" "$P_PATH" "$P_REF" "$P_COMMIT" "$REPO" "$SYSTEM_REF" "$SYSTEM_COMMIT" \
  "$compiler" "$P_SWIFT_EXEC" <<'EOF'
import datetime, json, platform, subprocess, sys
out, name, title, path, ref, commit, repo, sys_ref, sys_commit, compiler, swift_exec = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(r, c): return sh("git", "-C", r, "log", "-1", "--no-show-signature", "--format=%s", c)
json.dump({
  "package": name, "title": title,
  "path": path, "ref": ref, "commit": commit, "subject": subject(path, commit),
  "systemPath": repo, "systemRef": sys_ref, "systemCommit": sys_commit, "systemSubject": subject(repo, sys_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": compiler, "swiftExec": swift_exec,
}, open(out, "w"), indent=1)
EOF

log "checking the mapping"
status=0
python3 "$S/check.py" --package "$PACKAGES/$name.ini" --interfaces "$O/interfaces.json" --system "$STAGE/system-api.json" \
  --mapping "$MAPPING" --meta "$O/meta.json" --out "$O/coverage.json" || status=$?
[ "$status" -le 2 ] || fail "check.py failed for $name"

log "report"
python3 "$S/report.py" --coverage "$O/coverage.json" --method "$S/method.md" --out "$O/COVERAGE.md"

cp "$N/build.log" "$O/logs/build.log" 2>/dev/null || true
cp "$N/describe.json" "$N/dump.json" "$O/logs/"
exit "$status"
