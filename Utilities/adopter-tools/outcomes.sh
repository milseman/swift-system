#!/bin/bash
# The outcome of each test in a `swift test` log, one per line, sorted, so two
# runs' logs can be compared test for test:
#
#   outcomes.sh LOG            (- reads standard input)
#   diff <(outcomes.sh before.log) <(outcomes.sh after.log)
#
# Lines are `OUTCOME NAME`:
#   passed, failed, skipped    Swift Testing tests (`✔ Test foo() passed after ...`,
#                              whatever the glyph); a parameterized test's name
#                              keeps its "with N test cases"
#   suite-skipped              Swift Testing suites skipped as a whole
#   xctest-passed, xctest-failed, xctest-skipped
#                              XCTest tests, as Module.Class/test (macOS) or
#                              Class/test (Linux). With `swift test --parallel`,
#                              which prints only the failures' output, a test
#                              listed as `[n/m] Testing Module.Class/test` passed
#                              unless it failed
#   unfinished                 tests that started but never finished: the run
#                              crashed, hung, or was stopped
#
# Swift Testing prints a test's name without its suite, so two suites' `test()`
# are two lines `passed test()`; compare counts, as diff does.
set -euo pipefail
[ $# -eq 1 ] && { [ "$1" = - ] || [ -f "$1" ]; } || { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
export LC_ALL=C
awk '
  function xname(s) {                   # -[Module.Class test] or Class.test -> Module.Class/test
    if (s ~ /^-\[/) { s = substr(s, 3, length(s) - 3); sub(/ /, "/", s); return s }
    n = split(s, parts, "."); if (n < 2) return s
    t = parts[n]; c = substr(s, 1, length(s) - length(t) - 1); return c "/" t
  }
  function strip_cases(s) { sub(/ with [0-9]+ test cases?$/, "", s); return s }
  /^[^ ]+ Test run with [0-9]+ tests? / { next }
  /^[^ ]+ Test .* passed after / {
    s = $0; sub(/^[^ ]+ Test /, "", s); sub(/ passed after .*/, "", s)
    print "passed " s; done[strip_cases(s)]++; next }
  /^[^ ]+ Test .* failed after / {
    s = $0; sub(/^[^ ]+ Test /, "", s); sub(/ failed after .*/, "", s)
    print "failed " s; done[strip_cases(s)]++; next }
  /^[^ ]+ Test .* skipped/ {
    s = $0; sub(/^[^ ]+ Test /, "", s); sub(/ skipped.*/, "", s)
    print "skipped " s; done[s]++; next }
  /^[^ ]+ Suite .* skipped/ {
    s = $0; sub(/^[^ ]+ Suite /, "", s); sub(/ skipped.*/, "", s); print "suite-skipped " s; next }
  /^[^ ]+ Test .* started\.$/ {
    s = $0; sub(/^[^ ]+ Test /, "", s); sub(/ started\.$/, "", s)
    if (s != "run" && s !~ /^case passing /) started[s]++
    next }
  /^Test Case .* started/ {
    s = $0; sub(/^Test Case \047/, "", s); sub(/\047 started.*/, "", s); xstarted[xname(s)]++; next }
  /^Test Case .* (passed|failed|skipped) \(/ {
    s = $0; sub(/^Test Case \047/, "", s); o = s; sub(/\047 (passed|failed|skipped) \(.*/, "", s)
    sub(/^.*\047 /, "", o); sub(/ \(.*/, "", o)
    n = xname(s); xdone[n]++; if (o == "failed") xfailed[n]++
    if (!parallel) print "xctest-" o " " n
    next }
  /^\[[0-9]+\/[0-9]+\] Testing / { s = $0; sub(/^\[[0-9]+\/[0-9]+\] Testing /, "", s); parallel = 1; ran[s]++; next }
  END {
    for (s in started) for (k = done[s]; k < started[s]; k++) print "unfinished " s
    if (parallel) {
      for (s in ran) print (s in xfailed ? "xctest-failed " : "xctest-passed ") s
    } else {
      for (s in xstarted) for (k = xdone[s]; k < xstarted[s]; k++) print "unfinished " s
    }
  }
' "$1" | sort
