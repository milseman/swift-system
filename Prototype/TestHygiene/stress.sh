#!/bin/bash
# Runs the package's tests repeatedly under CPU load that this script creates,
# and lists what failed in each run. See REPORT.md.
#
# usage: Prototype/TestHygiene/stress.sh [-n runs] [-l loaders] [-m modes] [-o dir]
#          [-- extra swift test arguments]
#
#   -n runs     runs of each mode (default 5)
#   -l loaders  `yes > /dev/null` processes to run meanwhile (default: the
#               number of CPUs; 0 for none)
#   -m modes    which runs to make, of "serial" (`swift test`) and "parallel"
#               (`swift test --parallel`), comma-separated (default both)
#   -o dir      where the logs go (default .build/hygiene-logs/stress-<time>)
#
# It builds first, then starts the loaders, and kills them when it ends, however
# it ends. Their process IDs are in <dir>/loaders.pids, in case it's killed with
# SIGKILL. Each run's log is <dir>/<mode>-<n>.log, and <dir>/summary.txt lists
# the failures of every run.

set -u
cd "$(dirname "$0")/../.."

runs=5
loaders=$(sysctl -n hw.ncpu 2>/dev/null || nproc)
modes=serial,parallel
dir=.build/hygiene-logs/stress-$(date +%Y%m%d-%H%M%S)
while getopts "n:l:m:o:" option; do
  case $option in
    n) runs=$OPTARG ;;
    l) loaders=$OPTARG ;;
    m) modes=$OPTARG ;;
    o) dir=$OPTARG ;;
    *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ "${1-}" = "--" ] && shift
mkdir -p "$dir"

echo "Building..."
if ! swift build --build-tests --disable-sandbox > "$dir/build.log" 2>&1; then
  tail -20 "$dir/build.log"
  exit 1
fi

pids=()
stop_loaders() {
  if [ ${#pids[@]} -gt 0 ]; then kill "${pids[@]}" 2>/dev/null; fi
  pids=()
}
trap stop_loaders EXIT
trap 'stop_loaders; exit 130' INT TERM
for ((i = 0; i < loaders; i++)); do
  yes > /dev/null &
  pids+=($!)
done
echo ${pids[@]+"${pids[@]}"} > "$dir/loaders.pids"
echo "Started $loaders loaders; logs in $dir"

# The lines that name a failure: XCTest's assertions and failed cases,
# swift-testing's issues and failed tests, and crashes.
failures() {
  grep -a -E "error: |: failed|' failed|✘|[Ff]atal error|Exited with|signal code|Test crashed" "$1" \
    | grep -v -E "^✘ Test run with|with [0-9]+ failures? \(0 unexpected\)" | sort -u
}

summary="$dir/summary.txt"
: > "$summary"
for ((n = 1; n <= runs; n++)); do
  for mode in ${modes//,/ }; do
    log="$dir/$mode-$n.log"
    flags=()
    [ "$mode" = parallel ] && flags=(--parallel)
    start=$(date +%s)
    swift test --skip-build --disable-sandbox ${flags[@]+"${flags[@]}"} "$@" > "$log" 2>&1
    status=$?
    elapsed=$(($(date +%s) - start))
    load=$(sysctl -n vm.loadavg 2>/dev/null)
    {
      echo "== $mode run $n: exit $status, ${elapsed}s, load $load"
      # XCTest's totals (with --parallel, how many tests it ran), then
      # swift-testing's.
      grep -a -E "Executed [0-9]+ tests?, with" "$log" | tail -1
      grep -a -o -E "^\[[0-9]+/[0-9]+\] Testing" "$log" | tail -1
      grep -a -E "Test run with [0-9]+ tests?" "$log" | tail -1
      failures "$log"
    } | tee -a "$summary"
  done
done
