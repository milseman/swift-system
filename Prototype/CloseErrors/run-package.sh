#!/bin/zsh
# Runs the package's OwnedFD tests and Owned samples with each deinit policy
# patched into a copy of Sources/System/OwnedFD.swift. Each test method runs
# in its own process, so a trap ends only that test.
# Usage: ./Prototype/CloseErrors/run-package.sh [DROP TRAP MUST_CLOSE EBADF]
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
if (( $# )); then policies=("$@"); else policies=(DROP TRAP MUST_CLOSE EBADF); fi
for policy in $policies; do
  copy=${TMPDIR:-/tmp}/close-errors-package-$policy
  rsync -a --delete --exclude .build --exclude .git "$root/" "$copy/"
  python3 - "$copy/Sources/System/OwnedFD.swift" "$policy" <<'PY'
import re, sys
path, policy = sys.argv[1], sys.argv[2]
bodies = {
  "DROP": "_ = _descriptor._close()",
  "TRAP": "if case .failure(let error) = _descriptor._close() {\n"
          "      fatalError(\"close failed in deinit: \\(error)\")\n    }",
  "MUST_CLOSE": "_ = _descriptor._close()\n"
                "    fatalError(\"OwnedFD destroyed without close() or relinquish()\")",
  "EBADF": "if case .failure(.badFileDescriptor) = _descriptor._close() {\n"
           "      fatalError(\"OwnedFD: already closed\")\n    }",
}
s = open(path).read()
s, n = re.subn(r"\n  deinit \{\n.*?\n  \}\n", "\n  deinit {\n    " + bodies[policy] + "\n  }\n", s,
               count=1, flags=re.S)
assert n == 1, "deinit not found"
open(path, "w").write(s)
PY
  cd "$copy"
  if ! swift build --disable-sandbox --build-tests --scratch-path "$copy/.build" > build.log 2>&1; then
    echo "$policy: build failed; see $copy/build.log"; continue
  fi
  bundle=$copy/.build/debug/swift-systemPackageTests.xctest
  tests=()
  for f in Tests/SystemTests/OwnedFDTests.swift Tests/SystemTests/OwnedFDOwnershipTests.swift \
           Tests/SystemTests/WriteAllInterruptTests.swift; do
    class=$(grep -o "final class [A-Za-z]*" $f | head -1 | awk '{print $3}')
    for method in $(grep -o "func test[A-Za-z]*" $f | awk '{print $2}'); do
      tests+=("$class/$method")
    done
  done
  pass=0; trapped=()
  for t in $tests; do
    if xcrun xctest -XCTest "SystemTests.$t" "$bundle" > /dev/null 2>&1; then
      pass=$((pass + 1))
    else
      trapped+=("${t#*/}")
    fi
  done
  echo "$policy: ${#tests} tests, $pass pass, ${#trapped} fail or trap: ${trapped[*]:-none}"
  bin=$copy/.build/debug/system-samples
  scratch=$(mktemp -d)
  printf 'one\ntwo\n' > "$scratch/in.txt"
  for sample in "owned-cat in.txt" "owned-copy in.txt copy.txt" "owned-lines in.txt" \
                "owned-poll" "owned-redirect redirect.txt"; do
    if (cd "$scratch" && eval "$bin $sample" > output.txt 2>&1 < /dev/null); then
      result=ok
    elif grep -q "Fatal error" "$scratch/output.txt"; then
      result=TRAP
    else
      result=error
    fi
    echo "  $sample: $result"
  done
  rm -rf "$scratch"
  cd "$root"
done
