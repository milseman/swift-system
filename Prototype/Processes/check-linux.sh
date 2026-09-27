#!/bin/bash
# Typechecks System's Linux-only process and signal code, which nothing on
# macOS compiles, against LinuxModel/ProcessesLinuxModel.h: the Linux
# branches of Internals/Constants+Processes.swift and
# Syscalls+Processes.swift, ProcessDescriptor, SignalDescriptor, the Linux
# resource limits and SIGPWR, close_range, and their tests. Adapted from
# Prototype/Events/check-linux.sh; run `swift build` first.
#
# It copies SystemPackage's sources to a scratch directory, turns on the
# `os(Linux) || os(Android)` conditions in the process files, builds the
# module for macOS with the model, and compiles the Linux tests against
# it, through SIL so that the move checker runs. Darwin's code in those
# files stays on too, so an `#elseif os(Linux)` after a Darwin branch isn't
# checked, and neither is anything Android-only. It catches Swift errors,
# not differences between the model and a real C library. Prints each
# diagnostic, and exits nonzero if either step fails.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
work=${TMPDIR:-/tmp}
work=${work%/}/swift-system-processes-linux
rm -rf "$work"
mkdir -p "$work"

python3 - "$root" "$work" <<'PYTHON'
import os, shutil, sys
root, work = sys.argv[1], sys.argv[2]
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
linux_files = [
    "Sources/System/Internals/Constants+Processes.swift",
    "Sources/System/Internals/Syscalls+Processes.swift",
    "Tests/SystemTests/LinuxProcessTests.swift",
] + [
    os.path.join("Sources/System/Processes", name)
    for name in sorted(os.listdir(os.path.join(root, "Sources/System/Processes")))
    if name.endswith(".swift")
]
for relative in linux_files:
    text = open(os.path.join(root, relative)).read()
    for condition in ["#if os(Linux) || os(Android) || os(FreeBSD)",
                      "#if os(Linux) || os(Android)",
                      "#if os(Linux) || os(FreeBSD)",
                      "#if os(Linux)\n"]:
        text = text.replace(condition, "#if true // " + condition[4:])
    # The files' own imports expect a Linux C library.
    text = text.replace('#else\n#error("Unsupported Platform")\n#endif',
                        "#else\nimport Darwin\n#endif")
    text = "import ProcessesLinuxModel\n" + text
    target = os.path.join(work, relative)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    open(target, "w").write(text)
PYTHON

common=(-swift-version 6 -target arm64-apple-macosx26.0
  -D SYSTEM_PACKAGE_DARWIN -D SYSTEM_PACKAGE -D ENABLE_MOCKING
  -enable-experimental-feature Lifetimes
  -Xcc -fmodule-map-file="$root/Sources/CSystem/include/module.modulemap"
  -Xcc -fmodule-map-file="$root/Prototype/Processes/LinuxModel/module.modulemap"
  -I "$root/Prototype/Processes/LinuxModel")
for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  common+=(-enable-experimental-feature
    "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
done
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find "$work/Sources" -name '*.swift' | sort)
platform="$(xcode-select -p)/Platforms/MacOSX.platform/Developer"

module_output=$(swiftc -emit-module -parse-as-library -enable-testing \
  -module-name SystemPackage -package-name swift-system \
  -enable-upcoming-feature MemberImportVisibility \
  -emit-module-path "$work/SystemPackage.swiftmodule" \
  "${common[@]}" "${sources[@]}" 2>&1)
module_status=$?
test_output=""
test_status=1
if [ $module_status -eq 0 ]; then
  test_output=$(swiftc -emit-sil -wmo -o /dev/null -module-name SystemTests "${common[@]}" \
    -I "$work" -F "$platform/Library/Frameworks" -I "$platform/usr/lib" \
    "$work/Tests/SystemTests/LinuxProcessTests.swift" \
    "$root/Tests/SystemTests/TestingInfrastructure.swift" 2>&1)
  test_status=$?
fi
status=0
if [ $module_status -eq 0 ] && [ $test_status -eq 0 ]; then
  echo "== the module and the Linux tests compile"
elif [ $module_status -ne 0 ]; then
  echo "== the module fails"; status=1
else
  echo "== the Linux tests fail"; status=1
fi
printf '%s\n%s\n' "$module_output" "$test_output" \
  | grep -E "(error|warning):" | grep -v "^ *|" | sed "s|$work/||; s|$root/||" | sort -u
exit $status
