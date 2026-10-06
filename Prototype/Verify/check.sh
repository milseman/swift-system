#!/bin/bash
# Compiles the V1 to V5 and V7 snippets with one compiler, runs the ones that
# print, and shows what the compiler said and what each run printed.
# RESULTS.md has the results for Xcode's Swift 6.2 and a main-branch snapshot.
#
#   Prototype/Verify/check.sh [name [swiftc [SystemPackage scratch path]]]
#
# The defaults are 6.2, Xcode's swiftc, and .build/verify/spm-<name>. V1e
# imports SystemPackage, so build it with the same compiler first:
#   swift build --target SystemPackage --disable-sandbox \
#     --scratch-path .build/verify/spm-6.2
#   $SNAPSHOT/usr/bin/swift build --build-system native --target SystemPackage \
#     --disable-sandbox --scratch-path .build/verify/spm-snapshot
#   Prototype/Verify/check.sh snapshot $SNAPSHOT/usr/bin/swiftc
#
# Every snippet is compiled in the Swift 6 language mode with -parse-as-library,
# and V1a once more without it: none has top-level code, the @main ones need
# it, and it makes the globals real globals, as in a library. The ones that
# don't run are compiled with -emit-sil, since the move checker runs in SIL.
# -sdk is passed because the snapshot's driver picks none by itself. Build
# products go in .build/verify/<name>.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NAME=${1:-6.2}
SWIFTC=${2:-$(xcrun -f swiftc)}
SPM=${3:-$ROOT/.build/verify/spm-$NAME}
OUT=$ROOT/.build/verify/$NAME
SDK=$(xcrun --sdk macosx --show-sdk-path)
mkdir -p "$OUT/V1d" "$OUT/V4c"
cd "$ROOT/Prototype/Verify" || exit 1

"$SWIFTC" --version 2>&1 | grep -v '^Target:'
echo "SDK: $SDK"

COMMON=(-swift-version 6 -sdk "$SDK" -diagnostic-style llvm -no-color-diagnostics)
SIL=(-emit-sil -o /dev/null -parse-as-library)
EXE=(-parse-as-library -o)

# check LABEL ARGS...: compile, and show the compiler's output and status.
check() {
  local label=$1
  shift
  echo "== $label"
  "$SWIFTC" "${COMMON[@]}" "$@" 2>&1
  local status=$?
  echo "-- exit $status"
  return $status
}

# run LABEL BINARY: run a binary check built, and show its output and status.
run() {
  echo "== $1, run"
  "$2" 2>&1
  echo "-- exit $?"
}

# V1: noncopyable values in static and global storage.
check V1a "${SIL[@]}" V1a_static_nonsendable.swift
check "V1a, script mode" -emit-sil -o /dev/null V1a_static_nonsendable.swift
check V1a2 "${SIL[@]}" V1a2_static_public_nonsendable.swift
check V1a3 "${SIL[@]}" -enable-library-evolution V1a3_static_frozen_nonsendable.swift
check V1a4 "${SIL[@]}" V1a4_static_nonisolated_unsafe.swift
check V1b "${EXE[@]}" "$OUT/V1b" V1b_static_sendable.swift && run V1b "$OUT/V1b"
check V1c "${EXE[@]}" "$OUT/V1c" V1c_computed_static.swift && run V1c "$OUT/V1c"
check "V1d Lib" -parse-as-library -enable-library-evolution -module-name Lib \
  -emit-library -o "$OUT/V1d/libLib.dylib" -Xlinker -install_name -Xlinker @rpath/libLib.dylib \
  -emit-module -emit-module-path "$OUT/V1d/Lib.swiftmodule" \
  -emit-module-interface-path "$OUT/V1d/Lib.swiftinterface" -verify-emitted-module-interface \
  V1d_crossmodule/Lib.swift
check "V1d Client" -I "$OUT/V1d" -L "$OUT/V1d" -lLib -Xlinker -rpath -Xlinker "$OUT/V1d" \
  "${EXE[@]}" "$OUT/V1d/Client" V1d_crossmodule/Client.swift && run "V1d Client" "$OUT/V1d/Client"
check "V1d ClientConsume" "${SIL[@]}" -I "$OUT/V1d" V1d_crossmodule/ClientConsume.swift
check "V1d ClientDiscard" "${SIL[@]}" -I "$OUT/V1d" V1d_crossmodule/ClientDiscard.swift
check V1e "${SIL[@]}" -I "$SPM/debug/Modules" \
  -Xcc -fmodule-map-file="$ROOT/Sources/CSystem/include/module.modulemap" \
  V1e_filedescriptor_sendable.swift
check V1f "${SIL[@]}" V1f_sendable_probe_control.swift

# V2: consuming a `let`.
check V2a "${EXE[@]}" "$OUT/V2a" V2a_consume_local_let.swift && run V2a "$OUT/V2a"
check V2b "${SIL[@]}" V2b_consume_static_let.swift
check V2c "${SIL[@]}" V2c_explicit_consume_static.swift
check V2d "${EXE[@]}" "$OUT/V2d" V2d_static_var_and_discard.swift && run V2d "$OUT/V2d"
check V2e "${SIL[@]}" V2e_consume_global_let.swift

# V3: a throwing consuming close() alongside a deinit.
check V3a "${EXE[@]}" "$OUT/V3a" V3a_close_and_deinit.swift && run V3a "$OUT/V3a"
check V3b "${SIL[@]}" V3b_throw_before_discard.swift
check V3c "${SIL[@]}" V3c_deinit_throwing.swift
check V3d "${SIL[@]}" V3d_deinit_throws_decl.swift
check V3e "${EXE[@]}" "$OUT/V3e" V3e_close_without_discard.swift && run V3e "$OUT/V3e"
check V3f "${EXE[@]}" "$OUT/V3f" V3f_consume_self_on_throw_path.swift && run V3f "$OUT/V3f"

# V4: `discard self` to release without closing.
check V4a "${EXE[@]}" "$OUT/V4a" V4a_release.swift && run V4a "$OUT/V4a"
check V4b "${SIL[@]}" -wmo -module-name V4b V4b_otherfile/Type.swift V4b_otherfile/Extension.swift
check "V4c Frozen" -parse-as-library -enable-library-evolution -module-name V4c \
  -emit-library -o "$OUT/V4c/libV4c.dylib" -Xlinker -install_name -Xlinker @rpath/libV4c.dylib \
  -emit-module -emit-module-path "$OUT/V4c/V4c.swiftmodule" \
  -emit-module-interface-path "$OUT/V4c/V4c.swiftinterface" -verify-emitted-module-interface \
  V4c_inlinable/Frozen.swift
check "V4c Client" -I "$OUT/V4c" -L "$OUT/V4c" -lV4c -Xlinker -rpath -Xlinker "$OUT/V4c" \
  "${EXE[@]}" "$OUT/V4c/Client" V4c_inlinable/Client.swift && run "V4c Client" "$OUT/V4c/Client"
check V4d "${SIL[@]}" V4d_nontrivial_field.swift
check V4e "${SIL[@]}" V4e_no_deinit.swift
check V4f "${SIL[@]}" V4f_nonconsuming.swift

# V5: nonescapable enums, with and without the Lifetimes feature.
for f in V5a_nonescapable_enum V5b_nonescapable_enum_nofeature V5c_enum_nofeature_local; do
  check "${f%%_*}" "${SIL[@]}" $f.swift
  check "${f%%_*}, Lifetimes" "${SIL[@]}" -enable-experimental-feature Lifetimes $f.swift
done

# V7: diagnostics for misused noncopyable values.
for f in V7a_borrowed_misuse_movechecker V7b_borrowed_misuse_escaping V7c_store_with_consume \
  V7d_typecheck_misuse V7e_owned_local_misuse V7f_borrowed_optional_switch V7g_store_optional; do
  check "${f%%_*}" "${SIL[@]}" $f.swift
done
