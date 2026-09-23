#!/bin/zsh
# Builds a copy of the package in which OwnedFD forwards every FileDescriptor
# instance member: forwarding.py's output replaces the hand-written forwards
# in OwnedFD.swift. Prints the compiler's errors, if any, and line counts.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
copy=${TMPDIR:-/tmp}/forwarding-generated
rsync -a --delete --exclude .build --exclude .git "$root/" "$copy/"
python3 - "$copy/Sources/System/OwnedFD.swift" <<'PY'
import re, sys
path = sys.argv[1]
s = open(path).read()
start = s.index("// Forwarded I/O.")
open(path, "w").write(s[:start].rstrip() + "\n")
PY
python3 "$root/Prototype/Forwarding/forwarding.py" generate "$root" > "$copy/Sources/System/OwnedFD+Forwarding.swift"
echo "generated: $(wc -l < "$copy/Sources/System/OwnedFD+Forwarding.swift") lines, $(grep -c '^  public ' "$copy/Sources/System/OwnedFD+Forwarding.swift") members"
cd "$copy"
swift build --disable-sandbox --build-tests --scratch-path "$copy/.build" 2>&1 \
  | grep -E "error:" | sed -E "s|$copy/||" | sort | uniq -c | sort -rn | head -${1:-40}
echo "exit: ${pipestatus[1]}"
