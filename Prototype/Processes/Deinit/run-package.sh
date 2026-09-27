#!/bin/zsh
# Runs the package's process tests and samples with each deinit policy
# patched into a copy of Sources/System/Processes/ChildProcess.swift, in
# ChildProcess._destroy. Each test runs in its own process, so a trap ends
# only that test, and a test that runs longer than a minute is reported as a
# hang. The copies are under $TMPDIR.
# Usage: ./Prototype/Processes/Deinit/run-package.sh [KILL WAIT TERMINATE REAP LEAK TRAP]
set -u
root=$(cd "$(dirname "$0")/../../.." && pwd)
if (( $# )); then policies=("$@"); else policies=(KILL WAIT TERMINATE REAP LEAK TRAP); fi
for policy in $policies; do
  copy=${TMPDIR:-/tmp}/child-deinit-package-$policy
  rsync -a --delete --exclude .build --exclude .git "$root/" "$copy/"
  python3 - "$copy/Sources/System/Processes/ChildProcess.swift" "$policy" <<'PY'
import re, sys
path, policy = sys.argv[1], sys.argv[2]
peek = ("ProcessID._waitID(_P_PID, id_t(truncatingIfNeeded: id.rawValue), "
        "options: [.exited, .noHang, .keepWaitable], retryOnInterrupt: true)")
bodies = {
  "KILL": None,
  "WAIT": "    _ = id._wait(retryOnInterrupt: true)",
  "TERMINATE": "\n".join([
    f"    if case .success(nil) = {peek} {{",
    "      _ = id._sendSignal(.terminate)",
    "      var waited = 0",
    f"      while waited < 1_000, case .success(nil) = {peek} {{ usleep(5_000); waited += 5 }}",
    f"      if case .success(nil) = {peek} {{ _ = id._sendSignal(.kill) }}",
    "    }",
    "    _ = id._wait(retryOnInterrupt: true)",
  ]),
  "REAP": "    _ = id._tryWait()",
  "LEAK": "    _ = id",
  "TRAP": '    fatalError("ChildProcess destroyed without wait() or relinquish()")',
}
s = open(path).read()
if bodies[policy] is not None:
  s, n = re.subn(r"(internal static func _destroy\(_ id: ProcessID\) \{\n).*?(\n  \}\n)",
                 lambda m: m.group(1) + bodies[policy] + m.group(2), s, count=1, flags=re.S)
  assert n == 1, "_destroy not found"
open(path, "w").write(s)
PY
  cd "$copy"
  if ! swift build --disable-sandbox --build-tests --scratch-path "$copy/.build" > build.log 2>&1; then
    echo "$policy: build failed; see $copy/build.log"; cd "$root"; continue
  fi
  tests=(${(f)"$(swift test list --disable-sandbox --skip-build --scratch-path "$copy/.build" 2>/dev/null \
    | grep -E '^SystemTests\.(ChildProcessTests|SpawnTests|ProcessWaitTests|LinuxProcessTests)/')"})
  pass=0; failed=(); trapped=(); hung=(); unselected=()
  for t in $tests; do
    filter="${t#SystemTests.}\$"
    code=0
    perl -e 'alarm shift; exec @ARGV' 60 \
      swift test --disable-sandbox --skip-build --scratch-path "$copy/.build" --filter "$filter" \
      > test.log 2>&1 || code=$?
    name=${t#SystemTests.}
    if (( code == 142 )); then
      hung+=("$name")
    elif ! grep -qE 'Executed 1 test|unexpected signal' test.log; then
      unselected+=("$name")
    elif grep -q 'unexpected signal' test.log; then
      trapped+=("$name")
    elif (( code != 0 )) || grep -q ' failed ' test.log; then
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
  for sample in "process-run --timeout 1 --grace 1 sh -c 'sleep 5'" \
    "process-run sh -c 'exit 0'" \
    "process-pipeline 'ls /usr/bin' 'grep swift' 'wc -l'"; do
    code=0
    perl -e 'alarm shift; exec @ARGV' 30 zsh -c "$bin $sample" > output.txt 2>&1 < /dev/null || code=$?
    if (( code == 0 )) || grep -qE '^(ended by|exited with)' output.txt; then
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
