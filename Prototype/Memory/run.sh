#!/bin/sh
# Builds the prototype as a client of SystemPackage and runs it:
#
#   checks    the prototype's checks (Checks/main.swift)
#   policies  the deinit-policy scenarios (Policies/main.swift), once per
#             policy, each in a process of its own; prints a Markdown table
#   verify    typechecks each Verify/ snippet with -emit-sil, where the move
#             checker runs, against the "Expected:" line in its header
#   bench     the growth benchmark (Bench/main.swift), with -O, against a
#             release build of SystemPackage
#
# With no arguments it runs checks, policies and verify. It builds
# everything in $TMPDIR/malloc-prototype, and only reads this checkout.
# Build the package first:
#
#   swift build                                  # checks, policies, verify
#   swift build -c release --target SystemPackage  # bench
#   Prototype/Memory/run.sh [checks] [policies] [verify] [bench]

set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out="${TMPDIR:-/tmp}/malloc-prototype"
modulemap="$repo/Sources/CSystem/include/module.modulemap"
availability="AvailabilityMacro=System 199:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"
modes=${*:-"checks policies verify"}

# build_module <build dir> <config dir> [swiftc flags...]: MemoryPrototype,
# as a static library, from Sources/.
build_module() {
  dir=$1 config=$2
  shift 2
  mkdir -p "$dir"
  swiftc -parse-as-library -emit-library -static -module-name MemoryPrototype \
    -emit-module -emit-module-path "$dir/MemoryPrototype.swiftmodule" \
    -o "$dir/libMemoryPrototype.a" -swift-version 6 \
    -I "$config/Modules" -Xcc -fmodule-map-file="$modulemap" \
    -enable-experimental-feature Lifetimes -enable-experimental-feature "$availability" \
    "$@" "$here"/Sources/*.swift
}

# build_program <build dir> <config dir> <output> <main.swift> [swiftc flags...]
build_program() {
  dir=$1 config=$2 output=$3 main=$4
  shift 4
  swiftc -o "$output" -swift-version 6 -I "$dir" -I "$config/Modules" \
    -Xcc -fmodule-map-file="$modulemap" \
    -enable-experimental-feature Lifetimes -enable-experimental-feature "$availability" \
    "$@" "$main" "$dir/libMemoryPrototype.a" \
    "$config"/SystemPackage.build/*.o "$config"/CSystem.build/*.o
}

# The reason a scenario trapped, from its standard error: Swift's message,
# or libmalloc's, which it writes only to a terminal unless
# MallocDebugReport says otherwise.
reason() {
  sed -n -e 's/.*Fatal error: \(.*\)/\1/p' -e 's/.*Precondition failed: \(.*\)/\1/p' \
    -e 's/.*malloc: \*\*\* error for object [^:]*: \(.*\)/libmalloc: \1/p' "$1" | head -1
}

need() {
  if [ ! -d "$1/SystemPackage.build" ]; then
    echo "error: no build in $1; see the top of $0" >&2
    exit 1
  fi
}

for mode in $modes; do
  case $mode in
  checks)
    need "$repo/.build/debug"
    echo "== Checks"
    build_module "$out/free" "$repo/.build/debug"
    build_program "$out/free" "$repo/.build/debug" "$out/checks" "$here/Checks/main.swift"
    "$out/checks"
    ;;
  policies)
    need "$repo/.build/debug"
    echo "== Deinit policies"
    policies="free must-free checked"
    for policy in $policies; do
      case $policy in
      free) flags="" ;;
      must-free) flags="-D MEMORY_POLICY_MUST_FREE" ;;
      checked) flags="-D MEMORY_POLICY_CHECKED" ;;
      esac
      # shellcheck disable=SC2086
      build_module "$out/$policy" "$repo/.build/debug" $flags
      build_program "$out/$policy" "$repo/.build/debug" "$out/$policy/policies" "$here/Policies/main.swift"
    done
    printf '| scenario | modeled on | free (default) | must-free | checked |\n'
    printf '|---|---|---|---|---|\n'
    "$out/free/policies" --list | while IFS="$(printf '\t')" read -r name source; do
      row="| $name | $source |"
      for policy in $policies; do
        if result=$(MallocDebugReport=stderr "$out/$policy/policies" "$name" 2>"$out/stderr"); then :; else
          result="TRAP: $(reason "$out/stderr")"
        fi
        row="$row $result |"
      done
      printf '%s\n' "$row"
    done
    ;;
  verify)
    need "$repo/.build/debug"
    echo "== Verify"
    build_module "$out/free" "$repo/.build/debug"
    for file in "$here"/Verify/*.swift; do
      if grep -q "Expected: compiles" "$file"; then expected=compiles; else expected=fails; fi
      if output=$(swiftc -emit-sil -o /dev/null -swift-version 6 -parse-as-library \
        -I "$out/free" -I "$repo/.build/debug/Modules" -Xcc -fmodule-map-file="$modulemap" \
        -enable-experimental-feature Lifetimes -enable-experimental-feature "$availability" \
        "$file" 2>&1); then status=compiles; else status=fails; fi
      if [ "$status" = "$expected" ]; then verdict="as expected"; else verdict="UNEXPECTED"; fi
      echo "$(basename "$file"): $status, $verdict"
      printf '%s\n' "$output" | grep -E "error:" | grep -v "^ *|" | sed "s|^.*/Verify/|  |" | head -2
    done
    ;;
  bench)
    need "$repo/.build/release"
    echo "== Benchmark"
    build_module "$out/release" "$repo/.build/release" -O
    build_program "$out/release" "$repo/.build/release" "$out/bench" "$here/Bench/main.swift" -O
    echo "Growing a buffer in use from 4 KiB by doubling, in µs (best of 5, a process each):"
    printf '| final size | Memory.Buffer (realloc) | allocate, copy, deallocate | Array |\n'
    printf '|---|---|---|---|\n'
    for size in 65536 1048576 16777216 268435456; do
      row="| $((size / 1024)) KiB |"
      for variant in realloc allocate-copy array; do
        row="$row $("$out/bench" "$variant" "$size") |"
      done
      printf '%s\n' "$row"
    done
    ;;
  *)
    echo "error: unknown mode $mode" >&2
    exit 2
    ;;
  esac
done
