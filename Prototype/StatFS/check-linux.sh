#!/bin/bash
# Typechecks StatFS's Linux code, which nothing on macOS compiles: the statvfs
# side of StatFS and MountFlags, FileSystemType's statfs shims and magic
# numbers, the Linux parts of their tests, and the statfs sample. Run
# `swift build` first, for the sample's ArgumentParser.
#
# It copies SystemPackage's sources to a scratch directory and, in StatFS's
# files, turns the Darwin and BSD conditions off and the Linux ones on. So
# StatFS wraps Darwin's statvfs, which has the fields Linux's has, in widths
# that differ. The declarations Darwin lacks, the ST_* getters and the f_type
# shims, come from LinuxModel/StatFSLinuxModel.h. Then it builds the module
# for macOS, and compiles the tests and the sample against it through SIL. It
# catches Swift errors, not differences between Darwin's statvfs and a Linux
# C library's, such as constant values. Prints each diagnostic, and exits
# nonzero if anything fails.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
work=${TMPDIR:-/tmp}
work=${work%/}/swift-system-statfs-linux
rm -rf "$work"
mkdir -p "$work"

python3 - "$root" "$work" <<'PYTHON'
import os, shutil, sys
root, work = sys.argv[1], sys.argv[2]

# Longest first, so that no condition is replaced inside a longer one.
replacements = [
    ("SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(Linux) || os(Android)", "true"),
    ("SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)", "false"),
    ("SYSTEM_PACKAGE_DARWIN || os(FreeBSD)", "false"),
    ("SYSTEM_PACKAGE_DARWIN || os(OpenBSD)", "false"),
    ("!SYSTEM_PACKAGE_DARWIN && !os(FreeBSD)", "true"),
    ("!SYSTEM_PACKAGE_DARWIN", "true"),
    ("os(Linux) || os(Android) || os(FreeBSD)", "true"),
    ("os(Linux) || os(WASI) || os(Android)", "true"),
    ("os(Linux) || os(Android)", "true"),
    ("os(Linux) || os(WASI)", "true"),
    ("#if os(Linux)\n", "#if true\n"),
    ("#if SYSTEM_PACKAGE_DARWIN\n", "#if false\n"),
    # The files' own imports expect a Linux C library.
    ('#error("Unsupported Platform")', "import Darwin"),
]

def linuxify(text):
    for old, new in replacements:
        text = text.replace(old, new)
    return "import StatFSLinuxModel\n" + text

src = os.path.join(root, "Sources/System")
for directory, _, files in os.walk(src):
    if "/IORing" in directory:
        continue
    for name in files:
        if name.endswith(".swift"):
            path = os.path.join(directory, name)
            target = os.path.join(work, os.path.relpath(path, root))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copy(path, target)

for relative in [
    "Sources/System/FileSystem/FileSystemType+Linux.swift",
    "Sources/System/FileSystem/MountFlags.swift",
    "Sources/System/FileSystem/StatFS.swift",
    "Sources/System/Internals/Constants+StatFS.swift",
    "Sources/System/Internals/Syscalls+StatFS.swift",
    "Tests/SystemTests/StatFSMockTests.swift",
    "Tests/SystemTests/StatFSTests.swift",
    "Sources/Samples/StatFS.swift",
]:
    path = os.path.join(root, relative)
    if not os.path.exists(path):
        continue
    target = os.path.join(work, relative)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    open(target, "w").write(linuxify(open(path).read()))

# CInterop.swift's other extensions use the same conditions, so turn on the
# Linux side of StatFS's typealiases alone.
path = os.path.join(root, "Sources/System/Internals/CInterop.swift")
text = open(path).read()
start = text.index("  public typealias StatFS = statfs")
start = text.rindex("extension CInterop {", 0, start)
end = text.index("\n}\n", start) + 3
block = text[start:end]
for old, new in replacements[:4]:
    block = block.replace(old, new)
target = os.path.join(work, "Sources/System/Internals/CInterop.swift")
open(target, "w").write(text[:start] + block + text[end:])
PYTHON

# The target is recent so that Span and Duration need no availability checks
# in code that Linux compiles without them.
flags=(-swift-version 6 -target arm64-apple-macosx26.0
  -D SYSTEM_PACKAGE_DARWIN -D SYSTEM_PACKAGE -D ENABLE_MOCKING
  -enable-experimental-feature Lifetimes
  -Xcc -fmodule-map-file="$root/Sources/CSystem/include/module.modulemap"
  -Xcc -fmodule-map-file="$root/Prototype/StatFS/LinuxModel/module.modulemap"
  -I "$root/Prototype/StatFS/LinuxModel")
for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  flags+=(-enable-experimental-feature
    "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
done
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find "$work/Sources/System" -name '*.swift' | sort)
developer=$(xcode-select -p)
platform="$developer/Platforms/MacOSX.platform/Developer"
testing=(-F "$platform/Library/Frameworks" -I "$platform/usr/lib"
  -plugin-path "$developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")

status=0
mkdir -p "$work/module"
module_output=$(swiftc -emit-module -parse-as-library -enable-testing \
  -module-name SystemPackage -package-name swift-system \
  -enable-upcoming-feature MemberImportVisibility \
  -emit-module-path "$work/module/SystemPackage.swiftmodule" \
  "${flags[@]}" "${sources[@]}" 2>&1)
if [ $? -eq 0 ]; then
  echo "== the module compiles"
  test_output=$(swiftc -emit-sil -wmo -o /dev/null -module-name SystemTests \
    "${flags[@]}" "${testing[@]}" -I "$work/module" \
    "$work/Tests/SystemTests/StatFSTests.swift" \
    "$work/Tests/SystemTests/StatFSMockTests.swift" \
    "$root/Tests/SystemTests/TestingInfrastructure.swift" 2>&1)
  if [ $? -eq 0 ]; then echo "== the tests compile"; else echo "== the tests fail"; status=1; fi
  sample_output=""
  if [ -f "$work/Sources/Samples/StatFS.swift" ]; then
    # The model's SystemPackage comes first in the search path.
    sample_output=$(swiftc -emit-sil -o /dev/null -parse-as-library -module-name Samples \
      "${flags[@]}" -I "$work/module" -I "$root/.build/debug/Modules" \
      "$work/Sources/Samples/StatFS.swift" \
      "$root/Prototype/StatFS/SampleSupport.swift" 2>&1)
    if [ $? -eq 0 ]; then echo "== the sample compiles"; else echo "== the sample fails"; status=1; fi
  fi
else
  echo "== the module fails"; status=1
  test_output=""; sample_output=""
fi
printf '%s\n%s\n%s\n' "$module_output" "$test_output" "$sample_output" \
  | grep -E "(error|warning):" | grep -v "^ *|" | sed "s|$work/||; s|$root/||" | sort -u
exit $status
