#!/bin/zsh
# Builds the platform-enum samples in both configurations and runs each one
# as every platform it can simulate. See README.md.
#
#   ./Prototype/PlatformEnum/check.sh
#
# The real build is the package's default .build. The simulated one goes to
# a separate scratch path, since -Xswiftc reaches every target and would
# otherwise rebuild everything each time the flags change.
set -e
cd "$(dirname "$0")/../.."

simulated=/tmp/swift-system-platform-enum-sim
scratch=$(mktemp -d /tmp/platform-enum-check.XXXXXX)
trap 'rm -rf "$scratch"' EXIT

echo "== building the real configuration"
swift build 2>&1 | grep -E "error|Compiling|Build complete" | tail -1
echo "== building the simulated configuration (-DSIMULATE_PLATFORMS) into $simulated"
swift build --scratch-path "$simulated" -Xswiftc -DSIMULATE_PLATFORMS 2>&1 \
  | grep -E "error|Compiling|Build complete" | tail -1

real=.build/debug/system-samples
sim=$simulated/debug/system-samples
head -c 100000 /dev/urandom > "$scratch/source.bin"

run() {
  local binary=$1 platform=$2
  shift 2
  local label="$*"
  local args=(platform "$@")
  [[ -n $platform ]] && args=(platform "$1" --as "$platform" "${@:2}")
  echo "-- ${platform:-real}: $label"
  "$binary" "${args[@]}" </dev/null 2>&1 | sed 's/^/   /'
}

samples() {
  local binary=$1 platform=$2
  local dir="$scratch/${platform:-real}"
  mkdir -p "$dir"
  run $binary "$platform" copy "$scratch/source.bin" "$dir/copy.bin"
  cmp -s "$scratch/source.bin" "$dir/copy.bin" && echo "   (copy identical)"
  run $binary "$platform" lock --contend "$dir/shared.log"
  run $binary "$platform" library "$dir/journal.txt"
  run $binary "$platform" owned "$dir/owned.txt"
  run $binary "$platform" save "$dir/saved.txt" "saved"
  run $binary "$platform" socket
  run $binary "$platform" process
  run $binary "$platform" errors "$dir"
  run $binary "$platform" variants "$dir"
}

echo "== real build"
samples $real ""
run $real "" darwin-only "$scratch/darwin-journal.txt"
run $real "" windows-only "$scratch/windows-journal.txt" || true

for platform in darwin linux windows; do
  echo "== simulated build, --as $platform"
  samples $sim $platform
done
run $sim "" windows-only "$scratch/windows-journal.txt"
