#!/bin/zsh
# Runs the package's PThread tests and thread samples with each deinit policy
# patched into a copy of Sources/System/Threads/PThread.swift, in
# PThread._destroy. Each test runs in its own process, so a trap ends only
# that test, and a test that runs longer than a minute is reported as a hang.
# Usage: ./Prototype/ThreadDeinit/run-package.sh [JOIN DETACH TRAP LEAK]
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
if (( $# )); then policies=("$@"); else policies=(JOIN DETACH TRAP LEAK); fi
for policy in $policies; do
  copy=${TMPDIR:-/tmp}/thread-deinit-package-$policy
  rsync -a --delete --exclude .build --exclude .git "$root/" "$copy/"
  python3 - "$copy/Sources/System/Threads/PThread.swift" "$policy" <<'PY'
import re, sys
path, policy = sys.argv[1], sys.argv[2]
bodies = {
  "JOIN": "_ = _join(id)",
  "DETACH": "_ = _detach(id)",
  "TRAP": 'fatalError("PThread destroyed without join() or detach()")',
  "LEAK": "_ = id",
}
s = open(path).read()
s, n = re.subn(r"(internal static func _destroy\(_ id: ID\) \{\n)    [^\n]*\n",
               lambda m: m.group(1) + "    " + bodies[policy] + "\n", s, count=1)
assert n == 1, "_destroy not found"
open(path, "w").write(s)
PY
  cd "$copy"
  if ! swift build --disable-sandbox --build-tests --scratch-path "$copy/.build" > build.log 2>&1; then
    echo "$policy: build failed; see $copy/build.log"; cd "$root"; continue
  fi
  tests=(${(f)"$(swift test list --disable-sandbox --skip-build --scratch-path "$copy/.build" 2>/dev/null \
    | grep -E '^SystemTests\.PThread')"})
  pass=0; failed=(); trapped=(); hung=(); unselected=()
  for t in $tests; do
    # swift-testing IDs end in "()" and don't match an anchored filter;
    # XCTest names need the anchor to exclude longer names they prefix.
    filter=$(printf '%s' "${t#SystemTests.}" | sed -e 's/[().]/\\&/g')
    [[ $t == *")" ]] || filter="$filter\$"
    code=0
    perl -e 'alarm shift; exec @ARGV' 60 \
      swift test --disable-sandbox --skip-build --scratch-path "$copy/.build" --filter "$filter" \
      > test.log 2>&1 || code=$?
    name=${t#SystemTests.}
    if (( code == 142 )); then
      hung+=("$name")
    elif ! grep -qE 'Executed 1 test|with 1 test|unexpected signal' test.log; then
      unselected+=("$name")
    elif grep -q 'unexpected signal' test.log; then
      trapped+=("$name")
    elif (( code != 0 )) || grep -q '✘' test.log; then
      failed+=("$name")
    else
      pass=$((pass + 1))
    fi
  done
  echo "$policy: ${#tests} tests, $pass pass"
  echo "  fail: ${failed[*]:-none}"
  echo "  trap: ${trapped[*]:-none}"
  echo "  hang: ${hung[*]:-none}"
  echo "  not selected: ${unselected[*]:-none}"
  bin=$copy/.build/debug/system-samples
  for sample in "threads-pool --workers 3 --jobs 12" "threads-local" "threads-info"; do
    code=0
    perl -e 'alarm shift; exec @ARGV' 30 ${=bin} ${=sample} > output.txt 2>&1 < /dev/null || code=$?
    if (( code == 0 )); then
      result=ok
    elif (( code == 142 )); then
      result=HANG
    elif grep -q "Fatal error" output.txt; then
      result=TRAP
    else
      result="error $code"
    fi
    echo "  $sample: $result"
  done
  cd "$root"
done
