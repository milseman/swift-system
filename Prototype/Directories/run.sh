#!/bin/sh
# Reproduces the measurements in README.md, on macOS.
#
# It builds and runs everything in $TMPDIR/directories-evidence, and only
# reads this checkout. bench.swift links against a release build of
# SystemPackage, so build that first:
#
#   swift build -c release --target SystemPackage
#   Prototype/Directories/run.sh
#
# The timings vary with the machine and its load; compare modes within one
# run.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
release="$repo/.build/release"
work="${TMPDIR:-/tmp}/directories-evidence"
sdk=$(xcrun --show-sdk-path)

if [ ! -d "$release/SystemPackage.build" ]; then
  echo "error: no release build; run: swift build -c release --target SystemPackage" >&2
  exit 1
fi

mkdir -p "$work/bin" "$work/trees"
bin="$work/bin"

echo "== Building in $work"
for tool in walk swap deep; do
  clang -O2 -o "$bin/$tool" "$here/$tool.c"
done
clang -O2 -dynamiclib -o "$bin/count.dylib" "$here/count.c"
clang -O2 -dynamiclib -o "$bin/mallocs.dylib" "$here/mallocs.c"
swiftc -O -o "$bin/entrycost" "$here/entrycost.swift"
swiftc -O -swift-version 6 -I "$release/Modules" \
  -Xcc -fmodule-map-file="$repo/Sources/CSystem/include/module.modulemap" \
  "$here/bench.swift" "$release"/SystemPackage.build/*.o "$release"/CSystem.build/*.o \
  -o "$bin/bench" 2>/dev/null

echo
echo "== Speed: walking $sdk"
echo "(C walkers: one run per line. bench: the best of 5 runs.)"
for run in 1 2 3 4 5; do
  for mode in native fts-nostat fts-stat fts-chdir native-stat; do
    "$bin/walk" "$mode" "$sdk"
  done
done | sort
"$bin/bench" walk "$sdk"
"$bin/bench" walk-stat "$sdk"

echo
echo "== System calls: walking $sdk"
for mode in fts-nostat fts-stat native native-stat; do
  echo "$mode:"
  DYLD_INSERT_LIBRARIES="$bin/count.dylib" "$bin/walk" "$mode" "$sdk" >/dev/null
done

echo
echo "== A directory replaced by a symbolic link while the walk is paused on it"
cd "$work"
for mode in fts-nochdir fts-chdir native; do
  "$bin/swap" "$mode"
done
rm -rf "$work/scratch"

echo
echo "== Paths longer than PATH_MAX ($(getconf PATH_MAX /) bytes)"
cd "$work/trees"
rm -rf deep
"$bin/deep" 60 twenty-character-name
for mode in fts-nostat fts-chdir native; do
  "$bin/walk" "$mode" deep
done
rm -rf deep

echo
echo "== A tree 300 deep, with at most 256 open descriptors"
"$bin/deep" 300 d
(
  ulimit -n 256
  for mode in fts-nostat fts-chdir native; do
    "$bin/walk" "$mode" deep
  done
)
rm -rf deep

echo
echo "== Entry costs: a directory of 100,000 files"
flat="$work/trees/flat"
if [ ! -d "$flat" ]; then
  mkdir "$flat"
  python3 -c "
import os
for i in range(100000):
    open(os.path.join('$flat', 'file-with-a-typical-name-%06d.txt' % i), 'w').close()
"
fi
"$bin/entrycost" "$flat"

echo
echo "== Allocations"
DYLD_INSERT_LIBRARIES="$bin/mallocs.dylib" "$bin/bench" stream-count "$flat"
DYLD_INSERT_LIBRARIES="$bin/mallocs.dylib" "$bin/bench" stream-keep "$flat"
DYLD_INSERT_LIBRARIES="$bin/mallocs.dylib" "$bin/bench" walk "$sdk"
