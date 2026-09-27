#!/bin/bash
# Builds and tests this checkout on Linux, with the linux-build lane's
# changes that system-next doesn't have yet applied, in a copy under
# .build/linux-experiments. Without them, the MemberImportVisibility probes
# fail to compile on Linux at system-next 609feb0 (ProcessesProbe.swift,
# EventsProbe.swift), which stops every `swift test`.
#
#   Prototype/Syscalls4/linux-test.sh                 # swift test, Swift 6.2 on noble
#   Prototype/Syscalls4/linux-test.sh build           # swift build --build-tests
#   Prototype/Syscalls4/linux-test.sh test --filter Pseudoterminal
#   SWIFT_IMAGE=swift:6.3-noble Prototype/Syscalls4/linux-test.sh
#
# Runs Apple's `container` tool as Utilities/linux/build.sh does, and logs to
# .build/linux-experiments/syscalls4-<tag>-<action>.log.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
image="${SWIFT_IMAGE:-swift:6.2-noble}"
tag="$(printf '%s' "${image#swift:}" | sed 's|[/:]|-|g')"
action="${1:-test}"
[ $# -gt 0 ] && shift

copy=".build/linux-experiments/syscalls4"
mkdir -p "$ROOT/$copy"
rsync -a --delete --exclude .build --exclude .git "$ROOT/" "$ROOT/$copy/"
if git -C "$ROOT" rev-parse --verify -q linux-build >/dev/null; then
  git -C "$ROOT" diff system-next...linux-build \
    | (cd "$ROOT/$copy" && patch -p1 --forward --quiet --reject-file=- >/dev/null) \
    || echo "== some of linux-build's changes didn't apply; see the build"
fi

case "$action" in
  build) command=(swift build --build-tests) ;;
  test) command=(swift test) ;;
  *) echo "linux-test.sh: the action is build or test, not '$action'" >&2; exit 64 ;;
esac
command+=(--scratch-path "/code/.build/linux-experiments/scratch-$tag" "$@")

log="$ROOT/.build/linux-experiments/syscalls4-$tag-$action.log"
echo "== $image: ${command[*]}"
set +e
container run --rm -m 8G -v "$ROOT:/code" -w "/code/$copy" "$image" "${command[@]}" > "$log" 2>&1
status=$?
set -e
grep -E "^/code/[^ ]+: error:" "$log" | sort -u | head -40 || true
if [ "$action" = test ]; then
  grep -E "^[[:space:]]+Executed [0-9]+ tests?," "$log" | tail -1 | sed 's/^[[:space:]]*/== XCTest: /' || true
  grep -E "Test run with [0-9]+ tests?" "$log" | tail -1 | sed 's/^/== swift-testing: /' || true
  grep -E "✘|error: .*failed|XCTAssert.*failed" "$log" | head -20 || true
fi
echo "== exit status $status; log: ${log#$ROOT/}"
exit "$status"
