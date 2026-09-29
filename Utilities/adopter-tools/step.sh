#!/bin/bash
# Build a package with its tests, test it, and log both, after a migration step.
#
#   step.sh [--no-test] [--audit] PACKAGE LOGDIR LABEL [SWIFT ARGS...]
#
# Runs `swift build --build-tests SWIFT ARGS` into LOGDIR/LABEL-build.log and
# prints the exit status, the time, the free disk and the build's errors; then
# `swift test --skip-build SWIFT ARGS $TEST_ARGS` into LOGDIR/LABEL-test.log
# and prints test-summary.sh's summary. SWIFT ARGS go to both, so the test
# doesn't rebuild (`-Xswiftc -target -Xswiftc arm64-apple-macosx26.0`,
# `--build-system native`); TEST_ARGS only to the test (`--parallel`,
# `--filter X`). The package's own directory is where SwiftPM writes, as a
# plain `swift build` would: its .build and, if missing, Package.resolved.
#
#   --no-test   build only (or SKIP_TEST=1)
#   --audit     then run darwin_audit.py on the build, writing LOGDIR/LABEL-audit.json
#               (AUDIT_ARGS: more arguments for it, such as --reexporters TSCLibc)
#
# SwiftPM is run with --disable-sandbox: inside another sandbox, such as a
# coding agent's, the manifest sandbox fails ("sandbox_apply: Operation not
# permitted"). ADOPTER_TOOLS_SANDBOX=1 leaves the flag off. TOOLCHAINS picks
# the toolchain, as for swift. Exit status: the build's if it failed, else the
# test's (0 with --no-test).
set -uo pipefail

usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd -P)"
test=1; audit=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-test) test=0; shift ;;
    --audit) audit=1; shift ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done
[ $# -ge 3 ] || usage
pkg="$(cd "$1" && pwd -P)" || exit 1
mkdir -p "$2" && logs="$(cd "$2" && pwd -P)" || exit 1
label=$3
shift 3
[ -n "${SKIP_TEST:-}" ] && test=0
sandbox=(--disable-sandbox)
[ -n "${ADOPTER_TOOLS_SANDBOX:-}" ] && sandbox=()
name="$(basename "$pkg")"
cd "$pkg" || exit 1

start=$(date +%s)
swift build --build-tests ${sandbox[@]+"${sandbox[@]}"} "$@" > "$logs/$label-build.log" 2>&1
bstat=$?
echo "== $name $label: build exit $bstat ($(( $(date +%s) - start )) s; $(df -h . | tail -1 | awk '{print $4}') free)"
grep -aE '(error|fatal error): ' "$logs/$label-build.log" | sort -u | head -30
[ $bstat -eq 0 ] || exit $bstat

if [ $audit -eq 1 ]; then
  # shellcheck disable=SC2086
  python3 "$here/darwin_audit.py" "$pkg" --quiet --json "$logs/$label-audit.json" ${AUDIT_ARGS:-}
fi

[ $test -eq 1 ] || exit 0
start=$(date +%s)
# shellcheck disable=SC2086
swift test --skip-build ${sandbox[@]+"${sandbox[@]}"} "$@" ${TEST_ARGS:-} > "$logs/$label-test.log" 2>&1
tstat=$?
echo "== test exit $tstat ($(( $(date +%s) - start )) s)"
"$here/test-summary.sh" "$logs/$label-test.log"
exit $tstat
