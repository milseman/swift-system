#!/bin/sh
# Typechecks the sketches as clients of SystemPackage and SystemSockets, and
# prints each compiler diagnostic. Run `swift build` first. Client code can't
# use the package's `System x.y` availability macros unless it defines them,
# as the -enable-experimental-feature flag here does.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
files=${*:-"$root/Prototype/Subtypes/Sketch.swift $root/Prototype/Subtypes/GenericOwner.swift"}
for file in $files; do
  if output=$(swiftc -emit-sil -o /dev/null -swift-version 6 -parse-as-library \
    -I "$root/.build/debug/Modules" \
    -Xcc -fmodule-map-file="$root/Sources/CSystem/include/module.modulemap" \
    -enable-experimental-feature \
      "AvailabilityMacro=System 199:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0" \
    "$file" 2>&1); then status=compiles; else status=fails; fi
  echo "== $(basename "$file"): $status"
  printf '%s\n' "$output" | grep -E "(error|warning):" | grep -v "^ *|" | sed "s|$root/||"
done
