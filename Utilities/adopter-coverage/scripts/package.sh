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

# The index dump is reused when the commit, the compiler, the build settings
# and the index reader are the ones it was made with.
benv=(env)
for v in ${PKG_UNSET_ENV[@]+"${PKG_UNSET_ENV[@]}"}; do benv+=(-u "$v"); done
if [ -n "$P_SWIFT_EXEC" ]; then
  benv+=("SWIFT_EXEC=$P_SWIFT_EXEC" "SWIFT_EXEC_MANIFEST=$(xcrun --find swiftc)")
  compiler="$("$P_SWIFT_EXEC" --version 2>/dev/null | head -n 1)"
else
  compiler="$(swift --version 2>/dev/null | head -n 1)"
fi
# The index reader is part of the key: a dump it wrote differently is stale.
reader="$(shasum "$S/indexstore.py" | cut -c1-12)"
key="$P_COMMIT | $compiler | ${P_SWIFT_EXEC} | ${PKG_BUILD_TARGETS[*]-} | ${PKG_BUILD_FLAGS[*]-} | ${PKG_UNSET_ENV[*]-} | $reader"

build_failed() {
  [ -z "$PKG_BUILD_HINT" ] || echo "hint: $PKG_BUILD_HINT" >&2
  fail "$1" "$2"
}

# <P>_REUSE_INDEX=1 reuses the dump of the same commit whatever made it: for
# a package whose compiler this machine no longer has. The report says which
# compiler and index reader made the dump.
var="${PKG_VAR}_REUSE_INDEX"
reuse="${!var:-}"
stored="$(cat "$N/key" 2>/dev/null || true)"
if [ -f "$N/index.json" ] && [ "$stored" = "$key" ]; then
  log "$name ${P_COMMIT:0:10}: reusing the index from the last run"
elif [ -f "$N/index.json" ] && [ -n "$reuse" ] && [ "${stored%% *}" = "$P_COMMIT" ]; then
  log "$name ${P_COMMIT:0:10}: reusing the index an earlier run made (${PKG_VAR}_REUSE_INDEX): $stored"
  compiler="$(printf '%s\n' "$stored" | awk -F' [|] ' '{print $2}')"
  key="$stored"
else
  rm -rf "${N:?}"
  mkdir -p "$N/src"
  log "exporting $name ${P_COMMIT:0:10}"
  git -C "$P_PATH" archive "$P_COMMIT" | tar -x -C "$N/src"
  "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
    ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} dump-package > "$N/dump.json" 2> "$N/dump.log" \
    || fail "swift package dump-package failed for $name" "$N/dump.log"
  if [ "${PKG_BUILD_TARGETS[*]-}" = ":libraries" ]; then
    # shellcheck disable=SC2207
    PKG_BUILD_TARGETS=($(python3 "$S/package.py" roots "$PACKAGES" "$name" "$N/dump.json"))
  fi
  log "building $name (debug, with an index store)${P_SWIFT_EXEC:+ with $P_SWIFT_EXEC}"
  : > "$N/build.log"
  if [ ${#PKG_BUILD_TARGETS[@]} -eq 0 ]; then
    "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
      ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
      || build_failed "swift build failed for $name" "$N/build.log"
  else
    for t in "${PKG_BUILD_TARGETS[@]}"; do
      echo "== swift build --target $t" >> "$N/build.log"
      "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" --target "$t" \
        ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
        || build_failed "swift build --target $t failed for $name" "$N/build.log"
    done
  fi
  "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
    ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} describe --type json > "$N/describe.json" 2> "$N/describe.log" \
    || fail "swift package describe failed for $name" "$N/describe.log"
  store="$(find "$N/build" -maxdepth 4 -type d -path '*/index/store' -print -quit)"
  [ -n "$store" ] || fail "the $name build left no index store" "$N/build.log"
  libindexstore="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/libIndexStore.dylib"
  [ -f "$libindexstore" ] || fail "no libIndexStore.dylib next to $(xcrun --find swift)"
  log "reading the index store"
  python3 "$S/indexstore.py" "$libindexstore" "$store" "$(cd "$N/src" && pwd -P)" "$N/index.json" \
    "$(cd "$N/build" && pwd -P)/checkouts"
  # Everything later steps need is in the index dump, and a new commit is
  # built from a fresh export, so the build (6 GB for SwiftPM) goes now.
  rm -rf "${N:?}/build"
  echo "$key" > "$N/key"
fi

log "extracting $name's OS interfaces"
python3 "$S/extract.py" --package "$PACKAGES/$name.ini" --swift-version "$compiler" \
  --sdk "$(xcrun --sdk macosx --show-sdk-path)" --root "$N/src" \
  --index "$N/index.json" --dump "$N/dump.json" --describe "$N/describe.json" --out "$O/interfaces.json"

python3 - "$O/meta.json" "$name" "$PKG_TITLE" "$P_PATH" "$P_REF" "$P_COMMIT" "$REPO" "$SYSTEM_REF" "$SYSTEM_COMMIT" \
  "$compiler" "$P_SWIFT_EXEC" "$key" <<'EOF'
import datetime, json, platform, subprocess, sys
out, name, title, path, ref, commit, repo, sys_ref, sys_commit, compiler, swift_exec, key = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(r, c): return sh("git", "-C", r, "log", "-1", "--no-show-signature", "--format=%s", c)
json.dump({
  "package": name, "title": title,
  "path": path, "ref": ref, "commit": commit, "subject": subject(path, commit),
  "systemPath": repo, "systemRef": sys_ref, "systemCommit": sys_commit, "systemSubject": subject(repo, sys_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": compiler, "swiftExec": swift_exec,
  "indexKey": key,
}, open(out, "w"), indent=1)
EOF

log "checking the mapping"
status=0
strict=()
[ "$PKG_STRICT" = no ] || strict=(--strict)
python3 "$S/check.py" --package "$PACKAGES/$name.ini" --interfaces "$O/interfaces.json" --system "$STAGE/system-api.json" \
  --derived "$STAGE/derived.json" --mapping "$MAPPING" --meta "$O/meta.json" --out "$O/coverage.json" \
  ${strict[@]+"${strict[@]}"} || status=$?
[ "$status" -le 2 ] || fail "check.py failed for $name"

log "report"
python3 "$S/report.py" --coverage "$O/coverage.json" --method "$S/method.md" --out "$O/COVERAGE.md"

cp "$N/build.log" "$O/logs/build.log" 2>/dev/null || true
cp "$N/describe.json" "$N/dump.json" "$O/logs/"
exit "$status"
