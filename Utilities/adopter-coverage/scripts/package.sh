#!/bin/bash
# Builds one package, extracts its OS interfaces, checks them against the
# mapping and writes its report, into $STAGE/NAME. check.sh runs this once
# per package with the environment it exports; see check.sh.
#
#   package.sh SPEC        (NAME, NAME@REF, NAME=PATH or NAME=PATH@REF)
#
# The build's index dump is kept in the results store ($RESULTS/index),
# keyed by the package commit and everything else the build depends on,
# with the export it was built from, so a rerun needs neither the build nor
# the checkout. When the package doesn't build with the compiler at hand,
# the extraction is lexical (see scripts/method.md), and the report says so.
#
# Exit status: 0 or 2 as check.py's (2: the check found problems), 1 when
# something failed.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
. "$S/common.sh"

CHECKOUTS=()
resolve_package "$1"
name="$P_NAME"
N="$WORK/$name"
O="$STAGE/$name"
rm -rf "${O:?}" "${N:?}"
mkdir -p "$O/logs" "$N"
touch "$O/.adopter-coverage-out"

log "$PKG_TITLE: $P_REF @ $P_COMMIT ($P_PATH)"
if [ "$P_COMMIT" = "$(git -C "$P_PATH" rev-parse HEAD)" ] && ! git -C "$P_PATH" diff --quiet HEAD -- Sources Package.swift; then
  echo "note: the uncommitted changes in $P_PATH aren't part of the check"
fi

benv=(env)
for v in ${PKG_UNSET_ENV[@]+"${PKG_UNSET_ENV[@]}"}; do benv+=(-u "$v"); done
if [ -n "$P_SWIFT_EXEC" ]; then
  benv+=("SWIFT_EXEC=$P_SWIFT_EXEC" "SWIFT_EXEC_MANIFEST=$(xcrun --find swiftc)")
  compiler="$("$P_SWIFT_EXEC" --version 2>/dev/null | head -n 1)"
else
  compiler="$(swift --version 2>/dev/null | head -n 1)"
fi

# ------------------------------------------------------------ export
# The package's manifest may name a local package by a relative path. The
# export lives elsewhere, so each path is made absolute against the
# checkout, and a path to a swift-system checkout becomes an export of the
# System commit this run checks: the build then depends on commits only,
# and the key says which.
export_package() {
  mkdir -p "$N/src"
  git -C "$P_PATH" archive "$P_COMMIT" | tar -x -C "$N/src"
  python3 "$S/pathdeps.py" rewrite "$N/src/Package.swift" "$P_PATH" "$REPO" "$SYSTEM_COMMIT" "$WORK/system-package" \
    > "$N/pathdeps.json"
}
export_package
# Only the path dependencies the evaluated manifest uses key the build.
if [ -s "$N/pathdeps.json" ] && [ "$(cat "$N/pathdeps.json")" != "[]" ]; then
  if "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
      ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} dump-package > "$N/dump-early.json" 2> "$N/dump-early.log"; then
    python3 "$S/pathdeps.py" in-use "$N/pathdeps.json" "$N/dump-early.json" > "$N/pathdeps-used.json"
    mv "$N/pathdeps-used.json" "$N/pathdeps.json"
  fi
fi
pathdeps="$(python3 -c 'import json,sys; print(" ".join(r["key"] for r in json.load(open(sys.argv[1]))))' "$N/pathdeps.json")"
# The index reader is part of the key: a dump it wrote differently is stale.
reader="$(shasum "$S/indexstore.py" | cut -c1-12)"
key="$P_COMMIT | $compiler | ${P_SWIFT_EXEC} | ${PKG_BUILD_TARGETS[*]-} | ${PKG_BUILD_FLAGS[*]-} | ${PKG_UNSET_ENV[*]-} | $reader | $pathdeps"
C="$RESULTS/index/$name/$P_COMMIT/$(hash12 "$key")"

build_failed() {
  [ -z "$PKG_BUILD_HINT" ] || echo "hint: $PKG_BUILD_HINT" >&2
  echo "warning: $1; the extraction falls back to the lexical rules (see $2)" >&2
  cp "$2" "$C/build.log" 2>/dev/null || true
  # The first compiler error says why (a newer Swift's feature, a
  # platform the package doesn't build on).
  why="$(grep -m 1 -E 'error: ' "$2" | sed -E 's/^.*error: //' | cut -c1-160 || true)"
  echo "$1${why:+: $why}" > "$C/build-failed"
}

# <P>_REUSE_INDEX=1 reuses a dump of the same commit whatever made it: for
# a package whose compiler this machine no longer has. The report says which
# compiler and index reader made the dump. <P>_LEXICAL=1 skips the build.
var="${PKG_VAR}_REUSE_INDEX"
reuse="${!var:-}"
var="${PKG_VAR}_LEXICAL"
force_lexical="${!var:-}"
if [ -z "${ADOPTER_COVERAGE_REBUILD:-}" ] && [ -f "$C/index.json.gz" ] && [ "$(cat "$C/key")" = "$key" ]; then
  log "$name ${P_COMMIT:0:10}: reusing the index in the results store ($C)"
elif [ -n "$reuse" ] && other="$(ls -d "$RESULTS/index/$name/$P_COMMIT"/*/index.json.gz 2>/dev/null | head -n 1)" \
    && [ -n "$other" ]; then
  C="$(dirname "$other")"
  key="$(cat "$C/key")"
  compiler="$(printf '%s\n' "$key" | awk -F' [|] ' '{print $2}')"
  log "$name ${P_COMMIT:0:10}: reusing an index an earlier run made (${PKG_VAR}_REUSE_INDEX): $key"
elif [ -z "${ADOPTER_COVERAGE_REBUILD:-}" ] && [ -z "$force_lexical" ] && [ -f "$C/build-failed" ] \
    && [ "$(cat "$C/key")" = "$key" ]; then
  log "$name ${P_COMMIT:0:10}: this build failed before ($(cat "$C/build-failed")); lexical extraction"
else
  rm -rf "${C:?}"
  mkdir -p "$C"
  echo "$key" > "$C/key"
  cp "$N/pathdeps.json" "$C/pathdeps.json"
  log "exporting $name ${P_COMMIT:0:10}"
  if ! "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
      ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} dump-package > "$C/dump.json" 2> "$N/dump.log"; then
    # A manifest for newer tools than these (swift-tools-version 6.3 with
    # Swift 6.2) is read with the tools version lowered, in the export; if
    # it uses newer API, that fails too. The package then can't build here
    # either, so its extraction is lexical.
    have="$(swift --version 2>/dev/null | sed -n 's/.*Swift version \([0-9]*\.[0-9]*\).*/\1/p' | head -n 1)"
    if grep -q "is using Swift tools version" "$N/dump.log" && [ -n "$have" ]; then
      # The first line, or the first three: vapor's main opens with an import.
      sed -i '' "1,3s/swift-tools-version: *[0-9.]*/swift-tools-version:$have/" "$N/src/Package.swift"
      echo "the manifest's tools version, lowered to $have in the export" > "$C/tools-version-lowered"
      "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
        ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} dump-package > "$C/dump.json" 2> "$N/dump.log" \
        || { cp "$N/dump.log" "$C/"; fail "swift package dump-package failed for $name, even with tools version $have" "$N/dump.log"; }
    else
      cp "$N/dump.log" "$C/"
      fail "swift package dump-package failed for $name" "$N/dump.log"
    fi
  fi
  "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
    ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} describe --type json > "$C/describe.json" 2> "$N/describe.log" \
    || { cp "$N/describe.log" "$C/"; fail "swift package describe failed for $name" "$N/describe.log"; }
  targets=(${PKG_BUILD_TARGETS[@]+"${PKG_BUILD_TARGETS[@]}"})
  if [ "${targets[*]-}" = ":libraries" ]; then
    # shellcheck disable=SC2207
    targets=($(python3 "$S/package.py" roots "$PACKAGES" "$name" "$C/dump.json"))
  fi
  built=1
  if [ -n "$force_lexical" ]; then
    built=""
    echo "${PKG_VAR}_LEXICAL is set" > "$C/build-failed"
    "${benv[@]}" swift package "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" resolve \
      > "$N/build.log" 2>&1 || true
  else
    log "building $name (debug, with an index store)${P_SWIFT_EXEC:+ with $P_SWIFT_EXEC}"
    : > "$N/build.log"
    if [ ${#targets[@]} -eq 0 ]; then
      "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" \
        ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
        || { built=""; build_failed "swift build failed for $name" "$N/build.log"; }
    else
      for t in "${targets[@]}"; do
        echo "== swift build --target $t" >> "$N/build.log"
        "${benv[@]}" swift build "${SWIFTPM[@]}" --package-path "$N/src" --scratch-path "$N/build" --target "$t" \
          ${PKG_BUILD_FLAGS[@]+"${PKG_BUILD_FLAGS[@]}"} >> "$N/build.log" 2>&1 \
          || { built=""; build_failed "swift build --target $t failed for $name" "$N/build.log"; break; }
      done
    fi
  fi
  # What the dependencies re-export, for the Darwin metric: their sources
  # are in the build's checkouts until the build goes.
  python3 "$S/darwin.py" reexports "$N/build/checkouts" "$C/reexports.json"
  if [ -n "$built" ]; then
    store="$(find "$N/build" -maxdepth 4 -type d -path '*/index/store' -print -quit)"
    [ -n "$store" ] || fail "the $name build left no index store" "$N/build.log"
    libindexstore="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/libIndexStore.dylib"
    [ -f "$libindexstore" ] || fail "no libIndexStore.dylib next to $(xcrun --find swift)"
    log "reading the index store"
    python3 "$S/indexstore.py" "$libindexstore" "$store" "$(cd "$N/src" && pwd -P)" "$N/index.json" \
      "$(cd "$N/build" && pwd -P)/checkouts"
    gzip -c "$N/index.json" > "$C/index.json.gz"
    rm -f "$N/index.json"
    gzip -c "$N/build.log" > "$C/build.log.gz"
    # The SDK's and Swift libraries' names, for packages that don't build.
    sdkv="$(xcrun --sdk macosx --show-sdk-version)"
    vocab="$RESULTS/vocab/macosx$sdkv-$(hash12 "$compiler").json.gz"
    if [ ! -f "$vocab" ]; then
      mkdir -p "$RESULTS/vocab"
      python3 "$S/vocab.py" "$C/index.json.gz" "$vocab.tmp" --note "from $name $P_COMMIT, $compiler, macOS SDK $sdkv"
      mv "$vocab.tmp" "$vocab"
    fi
  fi
  # Everything later steps need is in the store, and a new commit is built
  # from a fresh export, so the build (6 GB for SwiftPM) goes now.
  rm -rf "${N:?}/build"
  git -C "$P_PATH" archive --format=tar.gz "$P_COMMIT" > "$C/src.tar.gz"
fi
# The export the index was made from, if the checkout is gone.
if [ ! -f "$N/src/Package.swift" ] && [ -f "$C/src.tar.gz" ]; then
  mkdir -p "$N/src"
  tar -xzf "$C/src.tar.gz" -C "$N/src"
fi

mode=index
extra=(--index "$C/index.json.gz")
if [ ! -f "$C/index.json.gz" ]; then
  mode=lexical
  sdkv="$(xcrun --sdk macosx --show-sdk-version)"
  vocab="$(ls -t "$RESULTS"/vocab/macosx"$sdkv"-*.json.gz 2>/dev/null | head -n 1 || true)"
  [ -n "$vocab" ] || vocab="$(ls -t "$RESULTS"/vocab/*.json.gz 2>/dev/null | head -n 1 || true)"
  [ -n "$vocab" ] || fail "$name needs a lexical extraction, and the results store has no SDK vocabulary yet; run check.sh for a package that builds first (nio)"
  extra=(--lexical --vocab "$vocab" --index /dev/null)
fi

log "extracting $name's OS interfaces ($mode)"
python3 "$S/extract.py" --package "$PKG_FILE" --swift-version "$compiler" \
  --sdk "$(xcrun --sdk macosx --show-sdk-path)" --root "$N/src" "${extra[@]}" \
  --dump "$C/dump.json" --describe "$C/describe.json" --dep-reexports "$C/reexports.json" \
  --sdk-probe-cache "$RESULTS/sdk-probe/macosx$(xcrun --sdk macosx --show-sdk-version).json" \
  --out "$O/interfaces.json"

python3 - "$O/meta.json" "$name" "$PKG_TITLE" "$P_PATH" "$P_REF" "$P_COMMIT" "$REPO" "$SYSTEM_REF" "$SYSTEM_COMMIT" \
  "$compiler" "$P_SWIFT_EXEC" "$key" "$mode" "$C" "$N/pathdeps.json" "$TOOL_ID" "$TOOL_COMMIT" <<'EOF'
import datetime, json, os, platform, subprocess, sys
(out, name, title, path, ref, commit, repo, sys_ref, sys_commit, compiler, swift_exec, key, mode, cache, pathdeps,
 tool_id, tool_commit) = sys.argv[1:]
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout.strip()
def subject(r, c): return sh("git", "-C", r, "log", "-1", "--no-show-signature", "--format=%s", c)
failed = os.path.join(cache, "build-failed")
json.dump({
  "package": name, "title": title,
  "path": path, "ref": ref, "commit": commit, "subject": subject(path, commit),
  "systemPath": repo, "systemRef": sys_ref, "systemCommit": sys_commit, "systemSubject": subject(repo, sys_commit),
  "date": datetime.date.today().isoformat(),
  "host": "macOS " + platform.mac_ver()[0] + " " + platform.machine(),
  "swift": compiler, "swiftExec": swift_exec,
  "indexKey": key, "extraction": mode,
  "buildFailed": open(failed).read().strip() if os.path.exists(failed) else None,
  "pathDependencies": json.load(open(pathdeps)),
  "tool": tool_id, "toolCommit": tool_commit,
}, open(out, "w"), indent=1)
EOF

log "checking the mapping"
status=0
strict=()
[ "$PKG_STRICT" = no ] || strict=(--strict)
python3 "$S/check.py" --package "$PKG_FILE" --interfaces "$O/interfaces.json" --system "$SYSTEM_API" \
  --derived "$SYSTEM_DERIVED" --mapping "$MAPPING" --meta "$O/meta.json" --out "$O/coverage.json" \
  ${strict[@]+"${strict[@]}"} || status=$?
[ "$status" -le 2 ] || fail "check.py failed for $name"

log "report"
python3 "$S/report.py" --coverage "$O/coverage.json" --method "$S/method.md" --out "$O/COVERAGE.md"

if [ -f "$N/build.log" ]; then
  cp "$N/build.log" "$O/logs/build.log"
elif [ -f "$C/build.log.gz" ]; then
  gunzip -c "$C/build.log.gz" > "$O/logs/build.log"
elif [ -f "$C/build.log" ]; then
  cp "$C/build.log" "$O/logs/build.log"
fi
cp "$C/describe.json" "$C/dump.json" "$O/logs/"
rm -rf "${N:?}"
exit "$status"
