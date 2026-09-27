#!/bin/bash
# Typechecks System's Linux event notification code, which nothing on macOS
# compiles, against LinuxModel/LinuxModel.h: EventPoll, EventCounter, and
# IntervalTimer, the Linux parts of the syscall and constant files, their
# tests, the events-loop sample, and ReadinessQueue.swift's epoll half. Run
# `swift build` first, for the sample's ArgumentParser.
#
# It copies SystemPackage's sources to a scratch directory, turns on the
# Linux conditions in those files, builds the module for macOS with the
# model, and compiles the tests, the sample, and the sketch against it,
# through SIL so that the move checker runs: once with glibc's
# declarations, and once with Bionic's nullability. It catches Swift
# errors, not differences between the model and a real C library. Prints
# each diagnostic, and exits nonzero if either pass fails.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
work=${TMPDIR:-/tmp}
work=${work%/}/swift-system-events-linux
rm -rf "$work"
mkdir -p "$work"

# Copy the sources, and turn on the Linux code in the event files. Their
# Darwin code stays on too, which is harmless: the model defines only
# names that Darwin doesn't.
python3 - "$root" "$work" <<'PYTHON'
import os, shutil, sys
root, work = sys.argv[1], sys.argv[2]
linux_files = [
    "Sources/System/Events/EventCounter.swift",
    "Sources/System/Events/EventPoll.swift",
    "Sources/System/Events/IntervalTimer.swift",
    "Sources/System/Events/Poll.swift",
    "Sources/System/Internals/Constants+Events.swift",
    "Sources/System/Internals/Syscalls+Events.swift",
    "Tests/SystemTests/EventPollTests.swift",
]
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
# The sample chooses kqueue first, so turn that branch off.
sample = "Sources/Samples/EventsLoop.swift"
text = open(os.path.join(root, sample)).read()
text = text.replace("#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)\n@available",
                    "#if false\n@available", 1)
text = text.replace("#elseif os(Linux) || os(Android)\n", "#elseif true\n", 1)
os.makedirs(os.path.join(work, "Samples"), exist_ok=True)
open(os.path.join(work, "Samples/EventsLoop.swift"), "w").write(
    text + "\n// Util.swift's, which needs SystemSockets.\nfunc complain(_ message: String) {}\n")
sketch = open(os.path.join(root, "Prototype/Events/ReadinessQueue.swift")).read()
sketch = sketch.replace("canImport(Darwin) || os(FreeBSD) || os(OpenBSD)", "false")
sketch = sketch.replace("os(Linux) || os(Android)", "true")
open(os.path.join(work, "Samples/ReadinessQueue.swift"), "w").write(sketch)
for relative in linux_files:
    text = open(os.path.join(root, relative)).read()
    text = text.replace("#if os(Linux) || os(Android)", "#if true // os(Linux) || os(Android)")
    # The files' own imports expect a Linux C library.
    text = text.replace('#else\n#error("Unsupported Platform")\n#endif',
                        "#else\nimport Darwin\n#endif", 1)
    text = "import LinuxModel\n" + text
    if relative.endswith("Constants+Events.swift"):
        # Constants+Threads.swift's, which SYSTEM_PACKAGE_DARWIN turns off.
        text += "\n@_alwaysEmitIntoClient\ninternal var _CLOCK_REALTIME: CInt { 0 }\n" \
                "\n@_alwaysEmitIntoClient\ninternal var _CLOCK_MONOTONIC: CInt { 1 }\n"
    target = os.path.join(work, relative)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    open(target, "w").write(text)
PYTHON

# The target is recent so that Span and Duration need no availability checks
# in code that Linux compiles without them.
common=(-swift-version 6 -target arm64-apple-macosx26.0
  -D SYSTEM_PACKAGE_DARWIN -D SYSTEM_PACKAGE -D ENABLE_MOCKING
  -enable-experimental-feature Lifetimes
  -Xcc -fmodule-map-file="$root/Sources/CSystem/include/module.modulemap"
  -Xcc -fmodule-map-file="$root/Prototype/Events/LinuxModel/module.modulemap"
  -I "$root/Prototype/Events/LinuxModel")
for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  common+=(-enable-experimental-feature
    "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
done
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find "$work/Sources" -name '*.swift' | sort)
platform="$(xcode-select -p)/Platforms/MacOSX.platform/Developer"

status=0
for libc in glibc bionic; do
  flags=("${common[@]}")
  [ "$libc" = bionic ] && flags+=(-Xcc -DMODEL_BIONIC)
  mkdir -p "$work/$libc"
  module_output=$(swiftc -emit-module -parse-as-library -enable-testing \
    -module-name SystemPackage -package-name swift-system \
    -enable-upcoming-feature MemberImportVisibility \
    -emit-module-path "$work/$libc/SystemPackage.swiftmodule" \
    "${flags[@]}" "${sources[@]}" 2>&1)
  module_status=$?
  test_output=""
  test_status=1
  if [ $module_status -eq 0 ]; then
    test_output=$(swiftc -emit-sil -wmo -o /dev/null -module-name SystemTests "${flags[@]}" \
      -I "$work/$libc" -F "$platform/Library/Frameworks" -I "$platform/usr/lib" \
      "$work/Tests/SystemTests/EventPollTests.swift" \
      "$root/Tests/SystemTests/EventTestSupport.swift" \
      "$root/Tests/SystemTests/TestingInfrastructure.swift" 2>&1)
    test_status=$?
    # The sample needs ArgumentParser, from `swift build`. The model's
    # SystemPackage comes first in the search path.
    sample_output=$(swiftc -emit-sil -o /dev/null -module-name Samples "${flags[@]}" \
      -I "$work/$libc" -I "$root/.build/debug/Modules" \
      "$work/Samples/EventsLoop.swift" 2>&1)
    [ $? -eq 0 ] || test_status=1
    sketch_output=$(swiftc -emit-sil -o /dev/null -parse-as-library -module-name Sketch \
      "${flags[@]}" -I "$work/$libc" "$work/Samples/ReadinessQueue.swift" 2>&1)
    [ $? -eq 0 ] || test_status=1
    test_output="$test_output
$sample_output
$sketch_output"
  fi
  if [ $module_status -eq 0 ] && [ $test_status -eq 0 ]; then
    echo "== $libc: the module, the tests, the sample, and the sketch compile"
  elif [ $module_status -ne 0 ]; then
    echo "== $libc: the module fails"; status=1
  else
    echo "== $libc: the tests, the sample, or the sketch fail"; status=1
  fi
  printf '%s\n%s\n' "$module_output" "$test_output" \
    | grep -E "(error|warning):" | grep -v "^ *|" | sed "s|$work/||; s|$root/||" | sort -u
done
exit $status
