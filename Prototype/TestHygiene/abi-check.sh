#!/bin/bash
# Type-checks the test targets under SYSTEM_ABI_STABLE, in a scratch copy of a
# commit with SystemPackage's known ABI-stable failures patched out (see the
# abi-stable-test-targets recipe), and prints each target's diagnostics.
#
# usage: Prototype/TestHygiene/abi-check.sh <commit> <out-dir>
#
# The copy is $TMPDIR/test-hygiene-abi-<commit>; it's deleted afterwards.
set -u
commit=$1
out=$2
root=$(cd "$(dirname "$0")/../.." && pwd)
tmp=${TMPDIR:-/tmp}
copy="${tmp%/}/test-hygiene-abi-$commit"
rm -rf "$copy"
mkdir -p "$copy" "$out"
git -C "$root" archive "$commit" | tar -x -C "$copy"
python3 "$copy/Utilities/api-delta/scripts/patch_manifest.py" "$copy/Package.swift"
sed -i '' -e 's/-> CInterop.UserID {/-> uid_t {/' -e 's/-> CInterop.GroupID {/-> gid_t {/' \
  "$copy/Sources/System/Internals/Syscalls.swift"
flags=(--disable-sandbox --package-path "$copy" --scratch-path "$copy/.build"
  -Xbuild-tools-swiftc -DSYSTEM_CI -Xbuild-tools-swiftc -DSYSTEM_ABI_STABLE)

# Deletes each OS floor that the build reports as more available than its
# enclosing System 199 scope, bottom-up, until SystemPackage builds.
for pass in 1 2 3; do
  log="$out/SystemPackage-$pass.log"
  swift build --target SystemPackage "${flags[@]}" > "$log" 2>&1 && break
  grep -E "^/.*:[0-9]+:[0-9]+: error: .*more available than enclosing scope" "$log" \
    | sed -E 's/^([^:]+):([0-9]+):.*/\1 \2/' | sort -u | sort -k1,1 -k2,2nr \
    | while read -r file line; do sed -i '' "${line}d" "$file"; done
done
for target in SystemTests SystemSocketsTests; do
  swift build --target "$target" "${flags[@]}" > "$out/$target.log" 2>&1
  grep -E "^/.*: (error|warning): " "$out/$target.log" \
    | sed -e "s|/private$copy/||" -e "s|$copy/||" | sort -u > "$out/$target.diagnostics"
  echo "$target: $(grep -c ': error: ' "$out/$target.diagnostics") errors, $(grep -c ': warning: ' "$out/$target.diagnostics") warnings"
done
rm -rf "$copy"
