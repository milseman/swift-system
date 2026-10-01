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
#   Utilities/linux/build.sh --root ~/development/base_dir/system-next \
#     --dir adopters-unix/swift-nio build             # another package, with
#                                                     # its ../../swift-system
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
#   --root <dir>       the directory to mount at /code (default: this
#                      package), for a package whose manifest names
#                      packages beside it, such as ../../swift-system
#   --dir <path>       the package, relative to the root (default: the root);
#                      the swift command runs there
#   --mount <dir>:<path>
#                      also mount <dir> at <path>, relative to the root, over
#                      what's there, such as this worktree where a package's
#                      manifest names another swift-system checkout
#   --scratch <path>   SwiftPM's scratch path, relative to the package
#                      (default .build/linux-<tag>)
#   --log <path>       the log, relative to the package unless it's absolute
#                      (default .build/linux-<tag>-<action>.log)
#   --quiet            write the output only to the log, and print a summary:
#                      the distinct error lines (the first 40), a test run's
#                      totals and failing tests, and the exit status
#
# <tag> is the image's tag, such as 6.2-noble, with -amd64 for amd64, so
# each image and architecture builds into its own scratch path. The package
# directory, or the root, is mounted at /code, and the container is removed
# afterward.
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
root=""
dir=""
mounts=()
scratch=""
log=""
quiet=""
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
    --root) root="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --mount) mounts+=("$2"); shift 2 ;;
    --scratch) scratch="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --quiet) quiet=1; shift ;;
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

# The mount's root, the package (a directory under it, where the swift
# command runs), and the package's path in the container. By default the
# root and the package are this package, at /code.
fail() { echo "build.sh: $*" >&2; exit 64; }
mount="$ROOT"
if [ -n "$root" ]; then
  mount="$(cd "$root" 2>/dev/null && pwd -P)" || fail "--root: no directory '$root'"
fi
case "${dir:-.}" in /*) fail "--dir is relative to the root, not '$dir'" ;; esac
package="$(cd "$mount/${dir:-.}" 2>/dev/null && pwd -P)" || fail "--dir: no directory '$dir' in $mount"
case "$package/" in "$mount"/*) ;; *) fail "--dir: '$dir' isn't in $mount" ;; esac
[ -f "$package/Package.swift" ] || fail "no Package.swift in $package"
subpath="${package#"$mount"}"
workdir="/code$subpath"
# From the package up to the root, such as ../../ for adopters-unix/swift-nio.
up=""
rest="${subpath#/}"
while [ -n "$rest" ]; do
  up="../$up"
  case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
done

image="${image:-swift:$swift-$distro}"
# swift:6.2-noble is 6.2-noble; another image keeps its name, as in
# swiftlang-swift-nightly-main-noble.
tag="${image#swift:}"
tag="$(printf '%s' "$tag" | sed 's|[/:]|-|g')"
[ "$arch" = amd64 ] && tag="$tag-amd64"
scratch="${scratch:-.build/linux-$tag}"
log="${log:-.build/linux-$tag-$action.log}"

run=(container run --rm -m "$memory" -v "$mount:/code" -w "$workdir")
for m in ${mounts[@]+"${mounts[@]}"}; do
  case "$m" in *:*) ;; *) fail "--mount is <dir>:<path>, not '$m'" ;; esac
  from="$(cd "${m%%:*}" 2>/dev/null && pwd -P)" || fail "--mount: no directory '${m%%:*}'"
  target="${m#*:}"
  case "$target" in /*|"") fail "--mount: '$target' is relative to the root" ;; esac
  [ -d "$mount/$target" ] || fail "--mount: no directory '$target' in $mount"
  run+=(-v "$from:/code/$target")
done
[ -n "$cpus" ] && run+=(--cpus "$cpus")
[ "$arch" = amd64 ] && run+=(--arch amd64 --rosetta)
[ -n "$user" ] && run+=(--user "$user" -e HOME=/tmp)
# The first line of the output and of the log names the root and the
# package when they aren't this package.
where=""
if [ "$mount" != "$ROOT" ] || [ "$package" != "$ROOT" ]; then
  where=", in $workdir ($mount at /code)"
fi

case "$action" in
  build) command=(swift build --scratch-path "$scratch") ;;
  build-tests) command=(swift build --build-tests --scratch-path "$scratch") ;;
  test) command=(swift test --scratch-path "$scratch") ;;
  run) command=(swift run --scratch-path "$scratch") ;;
  shell)
    echo "== $image ($arch), scratch path $scratch$where"
    exec "${run[@]}" -it "$image" bash ;;
esac
# ${extra[@]+...} because bash 3.2 treats an empty array as unset.
command+=(${extra[@]+"${extra[@]}"})

# A test run's totals in a log: XCTest's, then swift-testing's.
totals() {
  grep -E "^[[:space:]]+Executed [0-9]+ tests?," "$1" | tail -1 | sed 's/^[[:space:]]*/== XCTest: /' || true
  grep -E "Test run with [0-9]+ tests?" "$1" | tail -1 | sed 's/^/== swift-testing: /' || true
}

# A path in the container, relative to the package: the package's own
# paths lose their /code/<dir>/, and the root's other paths start with
# ../ up to it instead of /code/.
workdir_bre="$(printf '%s' "$workdir" | sed 's/[][\.*^$|]/\\&/g')"
workdir_ere="$(printf '%s' "$workdir" | sed 's/[][\.*^$|+?(){}]/\\&/g')"
relative() { sed "s|$workdir_bre/||g; s|/code/|$up|g"; }

# --quiet's summary of a log. Error lines are the diagnostics' own lines,
# not the `| `- error:` annotations of their source excerpts, and failing
# tests are swift-testing's lines with a cross, but its total, and XCTest's
# error lines under the package's Tests/, which have no column. Each list is
# in the log's order, with repeats dropped and paths made relative to the
# package.
summarize() {
  local file="$1" action="$2" errors failing count
  errors="$(grep -a 'error:' "$file" | grep -a -v -E '^[[:space:]]*\|' | relative \
    | awk '!seen[$0]++' || true)"
  count=0
  [ -n "$errors" ] && count="$(printf '%s\n' "$errors" | wc -l | tr -d ' ')"
  echo "== $count distinct error lines$([ "$count" -gt 40 ] && echo ', the first 40:')"
  # sed, not head, reads its whole input, so printf never gets a SIGPIPE.
  [ -n "$errors" ] && printf '%s\n' "$errors" | sed -n '1,40p'
  [ "$action" = test ] || return 0
  totals "$file"
  failing="$(grep -a -E "✘|^$workdir_ere/Tests/[^:]*:[0-9]+: error:" "$file" \
    | grep -a -v '✘ Test run with' | relative | awk '!seen[$0]++' || true)"
  count=0
  [ -n "$failing" ] && count="$(printf '%s\n' "$failing" | wc -l | tr -d ' ')"
  echo "== $count failing-test lines"
  [ -n "$failing" ] && printf '%s\n' "$failing"
  return 0
}

case "$log" in /*) logfile="$log" ;; *) logfile="$package/$log" ;; esac
mkdir -p "$(dirname "$logfile")"
echo "== $image ($arch)$where: ${command[*]}"
echo "== log: $log"
set +e
if [ -n "$quiet" ]; then
  {
    echo "== $(date '+%Y-%m-%d %H:%M:%S') $image ($arch)$where: ${command[*]}"
    "${run[@]}" "$image" "${command[@]}" 2>&1
  } > "$logfile"
  status=$?
else
  {
    echo "== $(date '+%Y-%m-%d %H:%M:%S') $image ($arch)$where: ${command[*]}"
    "${run[@]}" "$image" "${command[@]}" 2>&1
  } | tee "$logfile"
  status=${PIPESTATUS[0]}
fi
set -e

if [ -n "$quiet" ]; then
  summarize "$logfile" "$action"
elif [ "$action" = test ]; then
  totals "$logfile"
fi
echo "== exit status $status; log: $log"
exit "$status"
