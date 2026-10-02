#!/bin/bash
# Compiles System's Win32 namespace (Sources/System/Win32), which nothing on
# macOS compiles, against WindowsModel: a model of the Windows SDK and UCRT
# declarations it uses (WinSDK.h, ucrt.h), a model of Swift's WinSDK overlay
# (WinSDK.swift), and stand-ins for the SystemPackage declarations it uses
# (SystemPackageStubs.swift). Then it compiles the Windows-only tests,
# Tests/SystemTests/Win32*.swift, against the result.
#
# Everything is compiled to object code, so the move checker and IRGen run,
# with the Win32 files' `os(Windows)` conditions turned on. It catches Swift
# errors, not differences between the model and the real SDK, such as a
# macro that doesn't import. Before compiling, it checks that each stand-in
# marked `// mirrors: <file>` has the real declaration's signature.
#
# Prints each diagnostic from the Win32 and test files, and exits nonzero if
# anything fails. Needs no `swift build`.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
model="$root/Prototype/Win32/WindowsModel"
work=${TMPDIR:-/tmp}
work=${work%/}/swift-system-win32-check
rm -rf "$work"
mkdir -p "$work/modules" "$work/src" "$work/tests"
status=0

# The stand-ins must match the real declarations.
python3 - "$root" "$model/SystemPackageStubs.swift" <<'PYTHON' || status=1
import re, sys
root, stubs = sys.argv[1], sys.argv[2]
def collapse(text):
    return re.sub(r"\s+", " ", text).strip()
lines = open(stubs).read().split("\n")
failures = 0
for index, line in enumerate(lines):
    match = re.search(r"//\s*mirrors:\s*(\S+)\s*$", line)
    if not match:
        continue
    # The declaration runs to the end of its parameter list, which can
    # continue on the lines after this one, and stops at its body.
    signature = line[:match.start()]
    following = index + 1
    while signature.count("(") > signature.count(")") and following < len(lines):
        signature += " " + lines[following]
        following += 1
    signature = collapse(signature.split("{")[0])
    real = collapse(open(f"{root}/{match.group(1)}").read())
    if signature not in real:
        print(f"stand-in differs from {match.group(1)}: {signature}")
        failures += 1
sys.exit(1 if failures else 0)
PYTHON

# The files, with their Windows conditions turned on.
for file in "$root"/Sources/System/Win32/*.swift; do
  sed 's|^#if os(Windows)$|#if true // os(Windows)|' "$file" > "$work/src/$(basename "$file")"
done
for file in "$root"/Tests/SystemTests/Win32*.swift; do
  [ -e "$file" ] || continue
  sed 's|^#if os(Windows)$|#if true // os(Windows)|' "$file" > "$work/tests/$(basename "$file")"
done

# The target is recent so that the span types need no availability checks,
# as on Windows.
common=(-swift-version 6 -target arm64-apple-macosx26.0 -Onone
  -enable-experimental-feature Lifetimes
  -Xcc -fmodule-map-file="$model/module.modulemap" -I "$model" -I "$work/modules")
for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  common+=(-enable-experimental-feature
    "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
done
platform="$(xcode-select -p)/Platforms/MacOSX.platform/Developer"
# swift-testing's macros, for the test files that use it.
testing_macros="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"

report() {
  grep -E "(error|warning):" | grep -v "^ *|" \
    | sed "s|$work/src/|Sources/System/Win32/|; s|$work/tests/|Tests/SystemTests/|; s|$root/||" \
    | sort -u
}

overlay_output=$(swiftc -emit-module -parse-as-library -module-name WinSDK \
  -import-underlying-module -emit-module-path "$work/modules/WinSDK.swiftmodule" \
  "${common[@]}" "$model/WinSDK.swift" 2>&1)
if [ $? -ne 0 ]; then
  echo "== the WinSDK overlay model fails"
  echo "$overlay_output"
  exit 1
fi

sources=("$model/SystemPackageStubs.swift")
while IFS= read -r file; do sources+=("$file"); done < <(find "$work/src" -name '*.swift' | sort)
module_output=$(swiftc -c -wmo -parse-as-library -enable-testing \
  -module-name SystemPackage -package-name swift-system \
  -D SYSTEM_PACKAGE -D ENABLE_MOCKING \
  -enable-upcoming-feature MemberImportVisibility \
  -Xfrontend -require-explicit-availability=warn \
  -emit-module -emit-module-path "$work/modules/SystemPackage.swiftmodule" \
  -o "$work/SystemPackage.o" "${common[@]}" "${sources[@]}" 2>&1)
module_status=$?
# The stand-ins have no availability, so their warnings are dropped.
module_report=$(echo "$module_output" | grep -v "SystemPackageStubs.swift" | report)
if [ $module_status -eq 0 ]; then
  echo "== the Win32 files compile"
else
  echo "== the Win32 files fail"; status=1
fi
[ -n "$module_report" ] && echo "$module_report"

tests=()
while IFS= read -r file; do tests+=("$file"); done < <(find "$work/tests" -name '*.swift' | sort)
if [ $module_status -eq 0 ] && [ ${#tests[@]} -gt 0 ]; then
  test_output=$(swiftc -c -wmo -module-name SystemTests -D SYSTEM_PACKAGE -D ENABLE_MOCKING \
    -F "$platform/Library/Frameworks" -I "$platform/usr/lib" -plugin-path "$testing_macros" \
    -o "$work/SystemTests.o" "${common[@]}" "${tests[@]}" 2>&1)
  if [ $? -eq 0 ]; then
    echo "== the Windows tests compile (${#tests[@]} files)"
  else
    echo "== the Windows tests fail"; status=1
  fi
  echo "$test_output" | report
fi
exit $status
