#!/bin/bash
# Compiles SystemWinSocks (Sources/SystemWinSocks), the Windows-only Winsock
# module, which nothing on macOS compiles, and its Windows-only tests
# (Tests/SystemWinSocksTests), against WindowsModel with its Winsock part
# (WindowsModel/Winsock): the WinSDK overlay model built with
# WinSDK+Winsock.swift, which re-exports the Winsock model's Clang module,
# and SystemPackage built from SystemPackageStubs.swift and the real
# Sources/System/Win32, as check-windows.sh builds it, so that Win32.Error
# and the other Win32 types SystemWinSocks extends are the real ones.
#
# Everything is compiled to object code, so the move checker and IRGen run,
# with the files' `os(Windows)` conditions turned on. It catches Swift
# errors, not differences between the model and the real SDK, such as a
# macro that doesn't import. Before compiling, it checks the model:
# - each declaration in the Winsock headers names the SDK header it
#   mirrors (`// mirrors: winsock2.h`);
# - each numeric constant in them has the value that Rust's standard
#   library bindings give it, where they have it (WINDOWS_SYS_RS, by default
#   Homebrew's Rust source tree);
# - each stand-in in WinSDK+Winsock.swift marked `// mirrors: <file>` has
#   the real overlay's signature, read from a Swift checkout (SWIFT_SOURCE,
#   by default ../ecosystem/swift) if there is one;
# - each SystemWinSocks constant whose doc names its C constant
#   ("The corresponding C constant is `X`.") has the model's value of X.
#
# Prints each diagnostic from the SystemWinSocks and test files, and exits
# nonzero if anything fails. Needs no `swift build`.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
model="$root/Prototype/Win32/WindowsModel"
winsock="$model/Winsock"
work=${TMPDIR:-/tmp}
work=${work%/}/swift-system-winsock-check
rm -rf "$work"
mkdir -p "$work/modules" "$work/system" "$work/src" "$work/tests" "$work/module-cache"
status=0

# The model's Clang module is a stand-in for WinSDK's WinSock2 submodule;
# code that names it wouldn't compile on Windows.
if grep -rn 'WinSock2Model' "$root/Sources/SystemWinSocks" "$root/Tests/SystemWinSocksTests" 2>/dev/null; then
  echo "== the files above import the model's module, which Windows doesn't have"
  status=1
fi

python3 -I - "$root" "$winsock" "${WINDOWS_SYS_RS:-}" "${SWIFT_SOURCE:-$root/../ecosystem/swift}" <<'PYTHON' || status=1
import glob, os, re, subprocess, sys
root, winsock, rust, swift_source = sys.argv[1:5]
failures = 0

def fail(message):
    global failures
    print(message)
    failures += 1

def collapse(text):
    return re.sub(r"\s+", " ", text).strip()

# Every top-level declaration in the headers names the SDK header it mirrors.
headers = sorted(glob.glob(os.path.join(winsock, "*.h")))
values = {}
for header in headers:
    depth = 0
    name = os.path.basename(header)
    for number, line in enumerate(open(header).read().split("\n"), 1):
        code = line.split("//")[0]
        declaration = depth == 0 and re.match(r"(typedef |#define |[A-Za-z_])", code)
        if declaration and not code.startswith("#include"):
            if not re.search(r"//\s*mirrors:\s*\w+\.h\s*$", line):
                fail(f"{name}:{number}: no `// mirrors: <header>`: {line.strip()}")
        depth += code.count("{") - code.count("}")
        # Numeric constants: macros, and enumerators inside enums.
        m = re.match(r"#define (\w+) \(?(-?(?:0x[0-9A-Fa-f]+|\d+))\)?\s*(//.*)?$", line)
        if m:
            values[m.group(1)] = int(m.group(2), 0)
        m = re.match(r"\s+(\w+) = (-?(?:0x[0-9A-Fa-f]+|\d+)),", line)
        if m and depth > 0:
            values[m.group(1)] = int(m.group(2), 0)
        # A macro that names another macro.
        m = re.match(r"#define (\w+) ([A-Z_][A-Z0-9_]*)\s*(//.*)?$", line)
        if m:
            values.setdefault(m.group(1), m.group(2))
for _ in range(3):
    for key, value in list(values.items()):
        if isinstance(value, str) and isinstance(values.get(value), int):
            values[key] = values[value]
# WinSDK.h's network-adapter constants, which the Winsock headers use.
for line in open(os.path.join(winsock, "..", "WinSDK.h")).read().split("\n"):
    m = re.match(r"#define (AF_\w+) (\d+)\s*$", line)
    if m:
        values[m.group(1)] = int(m.group(2))
for key, value in list(values.items()):
    if isinstance(value, str) and isinstance(values.get(value), int):
        values[key] = values[value]

# The values, against Rust's bindings where they have them.
if not rust:
    found = glob.glob("/opt/homebrew/Cellar/rust/*/lib/rustlib/src/rust/library/std/src/sys/pal/windows/c/windows_sys.rs")
    rust = sorted(found)[-1] if found else ""
if rust and os.path.exists(rust):
    rust_values = {}
    for m in re.finditer(r"pub const (\w+): [\w:]+ = (-?\d+)[iu](?:8|16|32|64|size)", open(rust).read()):
        rust_values[m.group(1)] = int(m.group(2))
    checked = 0
    for key, value in sorted(values.items()):
        if isinstance(value, int) and key in rust_values:
            checked += 1
            if (value - rust_values[key]) % (1 << 32) != 0:
                fail(f"{key} is {value} in the model and {rust_values[key]} in {rust}")
    print(f"== {checked} of the model's {sum(isinstance(v, int) for v in values.values())} constants checked against Rust's bindings, which lack the rest")
else:
    print("== Rust's bindings not found (WINDOWS_SYS_RS); the model's constants are unchecked")

# The overlay stand-ins, against the real overlay.
overlay = os.path.join(winsock, "WinSDK+Winsock.swift")
marked = [(i, l) for i, l in enumerate(open(overlay).read().split("\n"), 1) if "// mirrors:" in l]
real = None
if os.path.isdir(swift_source):
    show = subprocess.run(["git", "-C", swift_source, "show", "HEAD:stdlib/public/Windows/WinSDK.swift"],
                          capture_output=True, text=True, env=dict(os.environ, GIT_NO_LAZY_FETCH="1"))
    if show.returncode == 0:
        real = collapse(show.stdout)
if real is None:
    print(f"== no Swift checkout at {swift_source}; the overlay's {len(marked)} stand-ins are unchecked")
else:
    for number, line in marked:
        signature = collapse(line.split("// mirrors:")[0].split("{")[0])
        if signature not in real:
            fail(f"WinSDK+Winsock.swift:{number}: differs from the overlay: {signature}")

# SystemWinSocks' constants, against the model.
sentence = re.compile(r"The corresponding C constant is `(\w+)`")
literal = re.compile(r"rawValue: (-?(?:0x[0-9A-Fa-f_]+|\d[\d_]*))\)")
checked = 0
for path in sorted(glob.glob(os.path.join(root, "Sources/SystemWinSocks/**/*.swift"), recursive=True)):
    lines = open(path).read().split("\n")
    for index, line in enumerate(lines):
        m = sentence.search(line)
        if not m:
            continue
        # The declaration the doc comment belongs to.
        following = index + 1
        while following < len(lines) and lines[following].strip().startswith(("///", "@")):
            following += 1
        if following >= len(lines):
            continue
        n = literal.search(lines[following])
        name = m.group(1)
        if not n or not isinstance(values.get(name), int):
            continue
        checked += 1
        value = int(n.group(1).replace("_", ""), 0)
        if (value - values[name]) % (1 << 32) != 0:
            fail(f"{os.path.relpath(path, root)}:{following + 1}: {value} isn't {name}, {values[name]}")
print(f"== {checked} SystemWinSocks constants checked against the model")
sys.exit(1 if failures else 0)
PYTHON

# The files, with their Windows conditions turned on.
for file in "$root"/Sources/System/Win32/*.swift; do
  sed 's|^#if os(Windows)$|#if true // os(Windows)|' "$file" > "$work/system/$(basename "$file")"
done
while IFS= read -r file; do
  sed 's|^#if os(Windows)$|#if true // os(Windows)|' "$file" > "$work/src/$(basename "$file")"
done < <(find "$root/Sources/SystemWinSocks" -name '*.swift' | sort)
for file in "$root"/Tests/SystemWinSocksTests/*.swift; do
  [ -e "$file" ] || continue
  sed 's|^#if os(Windows)$|#if true // os(Windows)|' "$file" > "$work/tests/$(basename "$file")"
done

# The target is recent so that the span types need no availability checks,
# as on Windows.
common=(-swift-version 6 -target arm64-apple-macosx26.0 -Onone
  -enable-experimental-feature Lifetimes -module-cache-path "$work/module-cache"
  -Xcc -fmodule-map-file="$model/module.modulemap" -Xcc -fmodule-map-file="$winsock/module.modulemap"
  -I "$model" -I "$work/modules")
for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  common+=(-enable-experimental-feature
    "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
done
platform="$(xcode-select -p)/Platforms/MacOSX.platform/Developer"
# swift-testing's macros, for the test files.
testing_macros="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"

report() {
  grep -E "(error|warning):" | grep -v "^ *|" \
    | sed "s|$work/src/|Sources/SystemWinSocks/|; s|$work/tests/|Tests/SystemWinSocksTests/|; s|$work/system/|Sources/System/Win32/|; s|$root/||" \
    | sort -u
}

overlay_output=$(swiftc -emit-module -parse-as-library -module-name WinSDK \
  -import-underlying-module -emit-module-path "$work/modules/WinSDK.swiftmodule" \
  "${common[@]}" "$model/WinSDK.swift" "$winsock/WinSDK+Winsock.swift" 2>&1)
if [ $? -ne 0 ]; then
  echo "== the WinSDK overlay model, with its Winsock part, fails"
  echo "$overlay_output"
  exit 1
fi

# SystemPackage, as check-windows.sh builds it. Only its module is needed:
# check-windows.sh reports on its files.
system=("$model/SystemPackageStubs.swift")
while IFS= read -r file; do system+=("$file"); done < <(find "$work/system" -name '*.swift' | sort)
system_output=$(swiftc -emit-module -wmo -parse-as-library -enable-testing \
  -module-name SystemPackage -package-name swift-system \
  -D SYSTEM_PACKAGE -D ENABLE_MOCKING -enable-upcoming-feature MemberImportVisibility \
  -emit-module-path "$work/modules/SystemPackage.swiftmodule" "${common[@]}" "${system[@]}" 2>&1)
if [ $? -ne 0 ]; then
  echo "== SystemPackage's Win32 files fail; run check-windows.sh"
  echo "$system_output" | report
  exit 1
fi

sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find "$work/src" -name '*.swift' | sort)
module_output=$(swiftc -c -wmo -parse-as-library -enable-testing \
  -module-name SystemWinSocks -package-name swift-system \
  -D SYSTEM_PACKAGE -D ENABLE_MOCKING \
  -enable-upcoming-feature MemberImportVisibility \
  -Xfrontend -require-explicit-availability=warn \
  -emit-module -emit-module-path "$work/modules/SystemWinSocks.swiftmodule" \
  -o "$work/SystemWinSocks.o" "${common[@]}" "${sources[@]}" 2>&1)
module_status=$?
if [ $module_status -eq 0 ]; then
  echo "== SystemWinSocks compiles (${#sources[@]} files)"
else
  echo "== SystemWinSocks fails"; status=1
fi
echo "$module_output" | report

tests=()
while IFS= read -r file; do tests+=("$file"); done < <(find "$work/tests" -name '*.swift' | sort)
if [ $module_status -eq 0 ] && [ ${#tests[@]} -gt 0 ]; then
  test_output=$(swiftc -c -wmo -module-name SystemWinSocksTests -D SYSTEM_PACKAGE -D ENABLE_MOCKING \
    -F "$platform/Library/Frameworks" -I "$platform/usr/lib" -plugin-path "$testing_macros" \
    -o "$work/SystemWinSocksTests.o" "${common[@]}" "${tests[@]}" 2>&1)
  if [ $? -eq 0 ]; then
    echo "== the Windows tests compile (${#tests[@]} files)"
  else
    echo "== the Windows tests fail"; status=1
  fi
  echo "$test_output" | report
fi
exit $status
