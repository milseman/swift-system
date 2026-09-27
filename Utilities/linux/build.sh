#!/bin/bash
# Builds or tests the package on Linux, in a container from Apple's
# `container` tool, and writes a log. See README.md in this directory.
#
#   Utilities/linux/build.sh                          # swift build, Swift 6.2 on Ubuntu noble
#   Utilities/linux/build.sh test                     # swift test
#   Utilities/linux/build.sh --distro jammy test      # swift:6.2-jammy
#   Utilities/linux/build.sh --swift 6.3 build-tests  # swift:6.3-noble
#   Utilities/linux/build.sh test -- --filter EventPollTests
#   Utilities/linux/build.sh run -- system-samples platform process
#   Utilities/linux/build.sh shell                    # an interactive shell
#
# Actions: build (the default), build-tests, test, run, and shell. The
# arguments after `--` go to the swift command, after its --scratch-path.
#
# Options:
#   --image <image>    the image (default swift:<swift>-<distro>)
#   --swift <version>  the Swift version for the default image (default 6.2)
#   --distro <name>    the distribution for the default image (default noble)
#   --arch <arch>      arm64 (the default), or amd64, which runs under Rosetta
#   --user <uid:gid>   run as this user rather than root, with HOME=/tmp
#   --memory <size>    the container's memory (default 8G)
#   --cpus <count>     the container's CPUs (default: the tool's)
#   --scratch <path>   SwiftPM's scratch path, relative to the package
#                      (default .build/linux-<tag>)
#   --log <path>       the log (default .build/linux-<tag>-<action>.log)
#
# <tag> is the image's tag, such as 6.2-noble, with -amd64 for amd64, so
# each image and architecture builds into its own scratch path. The package
# directory is mounted at /code, and the container is removed afterward.
#
# Exit status: the swift command's.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
swift=6.2
distro=noble
image=""
arch=arm64
user=""
memory=8G
cpus=""
scratch=""
log=""
action=build
extra=()

while [ $# -gt 0 ]; do
  case "$1" in
    --image) image="$2"; shift 2 ;;
    --swift) swift="$2"; shift 2 ;;
    --distro) distro="$2"; shift 2 ;;
    --arch) arch="$2"; shift 2 ;;
    --user) user="$2"; shift 2 ;;
    --memory) memory="$2"; shift 2 ;;
    --cpus) cpus="$2"; shift 2 ;;
    --scratch) scratch="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    build|build-tests|test|run|shell) action="$1"; shift ;;
    --) shift; extra=("$@"); break ;;
    *) echo "build.sh: unknown argument '$1'; see --help" >&2; exit 64 ;;
  esac
done

case "$arch" in
  arm64|amd64) ;;
  *) echo "build.sh: --arch is arm64 or amd64, not '$arch'" >&2; exit 64 ;;
esac

image="${image:-swift:$swift-$distro}"
# swift:6.2-noble is 6.2-noble; another image keeps its name, as in
# swiftlang-swift-nightly-main-noble.
tag="${image#swift:}"
tag="$(printf '%s' "$tag" | sed 's|[/:]|-|g')"
[ "$arch" = amd64 ] && tag="$tag-amd64"
scratch="${scratch:-.build/linux-$tag}"
log="${log:-.build/linux-$tag-$action.log}"

run=(container run --rm -m "$memory" -v "$ROOT:/code" -w /code)
[ -n "$cpus" ] && run+=(--cpus "$cpus")
[ "$arch" = amd64 ] && run+=(--arch amd64 --rosetta)
[ -n "$user" ] && run+=(--user "$user" -e HOME=/tmp)

case "$action" in
  build) command=(swift build --scratch-path "$scratch") ;;
  build-tests) command=(swift build --build-tests --scratch-path "$scratch") ;;
  test) command=(swift test --scratch-path "$scratch") ;;
  run) command=(swift run --scratch-path "$scratch") ;;
  shell)
    echo "== $image ($arch), scratch path $scratch"
    exec "${run[@]}" -it "$image" bash ;;
esac
# ${extra[@]+...} because bash 3.2 treats an empty array as unset.
command+=(${extra[@]+"${extra[@]}"})

mkdir -p "$ROOT/$(dirname "$log")"
echo "== $image ($arch): ${command[*]}"
echo "== log: $log"
set +e
{
  echo "== $(date '+%Y-%m-%d %H:%M:%S') $image ($arch): ${command[*]}"
  "${run[@]}" "$image" "${command[@]}" 2>&1
} | tee "$ROOT/$log"
status=${PIPESTATUS[0]}
set -e

if [ "$action" = test ]; then
  # XCTest's totals, then swift-testing's.
  grep -E "^[[:space:]]+Executed [0-9]+ tests?," "$ROOT/$log" | tail -1 | sed 's/^[[:space:]]*/== XCTest: /' || true
  grep -E "Test run with [0-9]+ tests?" "$ROOT/$log" | tail -1 | sed 's/^/== swift-testing: /' || true
fi
echo "== exit status $status; log: $log"
exit "$status"
