#!/bin/bash
# Cross-builds the package for another platform with a Swift SDK, in a
# container from Apple's `container` tool, and prints a summary. Each SDK is
# downloaded and installed once, into a cache directory that every run
# mounts. See build.sh, whose --quiet summary this prints.
#
#   Utilities/linux/cross.sh musl                     # the Static Linux SDK, Swift 6.2
#   Utilities/linux/cross.sh wasi                     # the WebAssembly SDK, Swift 6.2
#   Utilities/linux/cross.sh android                  # the Android SDK, Swift 6.3
#   Utilities/linux/cross.sh musl build -- --target SystemPackage
#   Utilities/linux/cross.sh --triple x86_64-swift-linux-musl musl
#   Utilities/linux/cross.sh wasi build-tests
#   Utilities/linux/cross.sh wasi test                # runs the tests under WasmKit
#   Utilities/linux/cross.sh wasi test -- --disable-xctest --filter StatFS
#   Utilities/linux/cross.sh wasi --assume-threads build -- --target SystemPackage
#   Utilities/linux/cross.sh android install          # only installs the SDK
#
# Platforms, and their default triples:
#   musl      aarch64-swift-linux-musl, the Static Linux SDK
#   wasi      wasm32-unknown-wasip1, the WebAssembly SDK (not its embedded one)
#   android   aarch64-unknown-linux-android28, the Android SDK; swift.org
#             has none for Swift 6.2, so the default is 6.3. It also needs
#             an Android NDK (r27 or later), which this doesn't download:
#             put android-ndk-r27d-linux.zip, or the directory it unzips
#             to, in the cache's ndk/ directory
#
# Actions: build (the default), build-tests, test (wasi only), install, and
# list (the cache's SDKs). The arguments after `--` go to the swift
# command, after its --scratch-path.
#
# WASI has no sockets: SystemSockets, its tests and the samples don't build
# for it, and SwiftPM builds the tests only with every target. So wasi's
# build-tests and test run in a copy of the package whose manifest drops
# those and the MemberImportVisibility canary, which depends on
# SystemSockets elsewhere: .build/cross-<tag>-wasi-package, its Sources,
# Tests and Package.swift copied again each run, with the scratch path
# .build/cross-<tag>-wasi-tests. --whole builds the package itself.
#
# swift.org has no SDK for wasm32-wasip1-threads, where WASI has pthreads.
# --assume-threads typechecks the code for it with the wasip1 SDK, whose
# headers are the same: the build is of a copy of the package in which
# `_runtime(_multithreaded)` is `true`, .build/cross-<tag>-wasi-threads-package
# (scratch path .build/cross-<tag>-wasi-threads). wasip1's C library
# defines no pthread function, so build a library target only: an
# executable wouldn't link.
#
# Options:
#   --swift <version>  the Swift version of the image swift:<version>-noble
#                      (default 6.2, or 6.3 for android)
#   --image <image>    another image; its SWIFT_VERSION picks the SDK
#   --triple <triple>  the target triple (default above)
#   --cache <dir>      the cache (default linux-logs/cross beside the
#                      package's directory), mounted at /cache
#   --scratch <path>   SwiftPM's scratch path, relative to the package
#                      (default .build/cross-<tag>-<platform>)
#   --log <path>       the log (default .build/cross-<tag>-<platform>-<action>.log)
#   --memory <size>    the container's memory (default 8G)
#   --cpus <count>     the container's CPUs (default: the tool's)
#   --whole            for wasi's build-tests and test, the package itself,
#                      not the copy without sockets
#   --assume-threads   for wasi, build as if for wasm32-wasip1-threads
#                      (above)
#
# <tag> is the image's, as in build.sh. The cache has bundles/ (downloaded
# on the host, from download.swift.org, with their signatures), sdks/<swift
# version>/ (installed in the container, where the signature is checked if
# the key server answers), and ndk/ (yours, for android: the NDK's
# source.properties, sysroot and clang resources are unzipped from it).
#
# The output goes only to the log. The summary is the number of distinct
# error lines and the first 40, as build.sh --quiet prints them, a test
# run's totals and failing tests, and the exit status: the swift command's.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
swift=""
image=""
triple=""
cache=""
scratch=""
log=""
memory=8G
cpus=""
platform=""
action=build
whole=0
threads=0
extra=()

while [ $# -gt 0 ]; do
  case "$1" in
    --swift) swift="$2"; shift 2 ;;
    --image) image="$2"; shift 2 ;;
    --triple) triple="$2"; shift 2 ;;
    --cache) cache="$2"; shift 2 ;;
    --scratch) scratch="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --memory) memory="$2"; shift 2 ;;
    --cpus) cpus="$2"; shift 2 ;;
    --whole) whole=1; shift ;;
    --assume-threads) threads=1; shift ;;
    -h|--help) usage; exit 0 ;;
    musl|wasi|android) platform="$1"; shift ;;
    build|build-tests|test|install|list) action="$1"; shift ;;
    --) shift; extra=("$@"); break ;;
    *) echo "cross.sh: unknown argument '$1'; see --help" >&2; exit 64 ;;
  esac
done

[ -n "$platform" ] || { echo "cross.sh: name a platform: musl, wasi, or android" >&2; exit 64; }
[ "$action" = test ] && [ "$platform" != wasi ] && {
  echo "cross.sh: only wasi's tests run here" >&2; exit 64; }
[ "$threads" = 1 ] && [ "$platform" != wasi ] && {
  echo "cross.sh: --assume-threads is for wasi" >&2; exit 64; }
[ "$threads" = 1 ] && [ "$action" = test ] && {
  echo "cross.sh: --assume-threads builds can't run: wasip1 has no pthreads to link" >&2; exit 64; }

case "$platform" in
  musl) kind=static; default_triple=aarch64-swift-linux-musl ;;
  wasi) kind=wasm; default_triple=wasm32-unknown-wasip1 ;;
  android) kind=android; default_triple=aarch64-unknown-linux-android28 ;;
esac
[ -z "$swift" ] && { [ "$platform" = android ] && swift=6.3 || swift=6.2; }
triple="${triple:-$default_triple}"
image="${image:-swift:$swift-noble}"
tag="${image#swift:}"
tag="$(printf '%s' "$tag" | sed 's|[/:]|-|g')"
log="${log:-.build/cross-$tag-$platform-$action.log}"

# The package to build, as the container sees it: this one, or for wasi's
# tests and --assume-threads a copy (see above). The scratch path is
# relative to this package's directory either way.
package=/code
copy=""
if [ "$threads" = 1 ]; then
  copy=".build/cross-$tag-wasi-threads-package"
  scratch="${scratch:-.build/cross-$tag-wasi-threads}"
elif [ "$platform" = wasi ] && [ "$whole" = 0 ] && { [ "$action" = build-tests ] || [ "$action" = test ]; }; then
  copy=".build/cross-$tag-wasi-package"
  scratch="${scratch:-.build/cross-$tag-wasi-tests}"
fi
if [ -n "$copy" ]; then
  mkdir -p "$ROOT/$copy"
  rsync -a --delete "$ROOT/Sources" "$ROOT/Tests" "$ROOT/$copy/"
  cp "$ROOT/Package.swift" "$ROOT/$copy/Package.swift"
  cat >> "$ROOT/$copy/Package.swift" <<'MANIFEST'

// Added by Utilities/linux/cross.sh, for WASI, which has no sockets.
let crossDropped: Set<String> = [
  "SystemSockets", "SystemSocketsTests", "Samples", "MemberImportVisibility",
]
package.targets.removeAll { crossDropped.contains($0.name) }
package.products.removeAll { $0.name == "SystemSockets" || $0.name == "system-samples" }
package.dependencies.removeAll()
MANIFEST
  if [ "$threads" = 1 ]; then
    grep -rl --include='*.swift' '_runtime(_multithreaded)' "$ROOT/$copy/Sources" "$ROOT/$copy/Tests" \
      | xargs perl -pi -e 's/_runtime\(_multithreaded\)/true/g'
  fi
  package="/code/$copy"
fi
scratch="${scratch:-.build/cross-$tag-$platform}"
if [ -z "$cache" ]; then
  mkdir -p "$ROOT/../linux-logs/cross"
  cache="$ROOT/../linux-logs/cross"
fi
mkdir -p "$cache/bundles" "$cache/sdks" "$cache/ndk"
cache="$(cd "$cache" && pwd -P)"

# The image's toolchain, from its environment, names the SDK to fetch.
image_env() {
  container image inspect "$image" 2>/dev/null | grep -o "\"$1=[^\"]*\"" | head -1 \
    | sed "s/^\"$1=//; s/\"\$//; s|\\\\/|/|g"
}
if [ -z "$(image_env SWIFT_VERSION)" ]; then
  container image pull "$image" > /dev/null
fi
version="$(image_env SWIFT_VERSION)"      # swift-6.2.4-RELEASE
branch="$(image_env SWIFT_BRANCH)"        # swift-6.2.4-release
webroot="$(image_env SWIFT_WEBROOT)"
key="$(image_env SWIFT_SIGNING_KEY)"
[ -n "$version" ] && [ -n "$branch" ] || {
  echo "cross.sh: $image has no SWIFT_VERSION or SWIFT_BRANCH" >&2; exit 1; }

# The bundle's name: the static SDK's has its own version, which differs
# between releases, so take the first that exists.
case "$kind" in
  static) names=("${version}_static-linux-0.1.0" "${version}_static-linux-0.0.1") ;;
  wasm) names=("${version}_wasm") ;;
  android) names=("${version}_android") ;;
esac
bundle=""
for name in "${names[@]}"; do
  if [ -f "$cache/bundles/$name.artifactbundle.tar.gz" ]; then bundle="$name"; break; fi
done
if [ -z "$bundle" ]; then
  for name in "${names[@]}"; do
    url="${webroot:-https://download.swift.org}/$branch/$kind-sdk/$version/$name.artifactbundle.tar.gz"
    if curl -fsSI --max-time 30 "$url" > /dev/null 2>&1; then
      echo "== downloading $url"
      curl -fsSL -o "$cache/bundles/$name.artifactbundle.tar.gz.sig" "$url.sig" \
        || rm -f "$cache/bundles/$name.artifactbundle.tar.gz.sig"
      curl -fsSL -o "$cache/bundles/$name.artifactbundle.tar.gz.part" "$url"
      mv "$cache/bundles/$name.artifactbundle.tar.gz.part" "$cache/bundles/$name.artifactbundle.tar.gz"
      bundle="$name"
      break
    fi
  done
fi
[ -n "$bundle" ] || {
  echo "cross.sh: download.swift.org has no $kind SDK for $version" >&2; exit 1; }

run=(container run --rm -m "$memory" -v "$ROOT:/code" -v "$cache:/cache" -w "$package")
[ -n "$cpus" ] && run+=(--cpus "$cpus")

case "$action" in
  build|install|list) command=(swift build) ;;
  build-tests) command=(swift build --build-tests) ;;
  test) command=(swift test) ;;
esac
# The wasm bundle's two SDKs, the embedded one too, share a triple, so it
# picks its SDK by name.
selector="$triple"
[ "$platform" = wasi ] && selector="$bundle"
command+=(--swift-sdks-path "/cache/sdks/$version" --swift-sdk "$selector" --scratch-path "/code/$scratch")
[ "$action" = test ] && command+=(--toolset /cache/sdks/wasmkit-toolset.json)
command+=(${extra[@]+"${extra[@]}"})

# What runs in the container: install the SDK if the cache lacks it (and,
# for android, link it to the NDK), then the swift command. Its arguments:
# the action, the bundle's name, the signing key, then the command.
inner='
set -euo pipefail
action="$1" bundle="$2" key="$3"; shift 3
sdks="/cache/sdks/$SWIFT_VERSION"
installed="$sdks/$bundle.artifactbundle"
if [ ! -d "$installed" ]; then
  file="/cache/bundles/$bundle.artifactbundle.tar.gz"
  if [ -f "$file.sig" ]; then
    export GNUPGHOME="$(mktemp -d)"
    if gpg --batch --quiet --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" 2>/dev/null; then
      gpg --batch --verify "$file.sig" "$file" || { echo "cross.sh: error: bad signature on $file"; exit 1; }
    else
      echo "cross.sh: warning: the key server did not answer; $file is unverified"
    fi
    rm -rf "$GNUPGHOME"
  else
    echo "cross.sh: warning: no signature for $file; unverified"
  fi
  mkdir -p "$sdks"
  swift sdk install "$file" --swift-sdks-path "$sdks"
fi
if [ -f "$installed/swift-android/scripts/setup-android-sdk.sh" ] && [ ! -e "$installed/swift-android/ndk-sysroot" ]; then
  ndk="$(cd /cache/ndk && ls -d android-ndk-r* 2>/dev/null | sed "s/-linux\.zip\$//" | sort -V | tail -1 || true)"
  [ -n "$ndk" ] || { echo "cross.sh: error: no Android NDK in the cache: put android-ndk-r27d-linux.zip in its ndk/"; exit 1; }
  if [ ! -f "/cache/ndk/$ndk/source.properties" ]; then
    prebuilt="$ndk/toolchains/llvm/prebuilt/linux-x86_64"
    unzip -q -o "/cache/ndk/$ndk-linux.zip" "$ndk/source.properties" "$prebuilt/sysroot/*" "$prebuilt/lib/clang/*" -d /cache/ndk
  fi
  ANDROID_NDK_HOME="/cache/ndk/$ndk" "$installed/swift-android/scripts/setup-android-sdk.sh"
fi
if [ "$action" = test ]; then
  # The tests run under WasmKit, from the toolchain, with /tmp, where they
  # make their scratch files, as their only directory. (No apostrophes in
  # this string: it is in single quotes.)
  runner="$(command -v wasmkit || true)"
  [ -n "$runner" ] || { echo "cross.sh: error: the toolchain has no wasmkit to run tests"; exit 1; }
  printf "{\"schemaVersion\": \"1.0\", \"testRunner\": {\"path\": \"%s\", \"extraCLIOptions\": [\"run\", \"--dir\", \"/tmp\"]}}\n" \
    "$runner" > /cache/sdks/wasmkit-toolset.json
fi
case "$action" in
  install) swift sdk list --swift-sdks-path "$sdks" ;;
  list) swift sdk list --swift-sdks-path "$sdks"; command -v wasmkit || echo "no wasmkit" ;;
  *) "$@" ;;
esac
'

# A test run's totals in a log: XCTest's, then swift-testing's.
totals() {
  grep -E "^[[:space:]]+Executed [0-9]+ tests?," "$1" | tail -1 | sed 's/^[[:space:]]*/== XCTest: /' || true
  grep -E "Test run with [0-9]+ tests?" "$1" | tail -1 | sed 's/^/== swift-testing: /' || true
}

# build.sh's --quiet summary: the distinct error lines, not the `| `- error:`
# annotations of source excerpts, and for a test run its totals and the
# failing tests' lines, with the mounts' /code/, and the copy's directory,
# taken out of paths.
summarize() {
  local file="$1" action="$2" errors failing count
  local strip="s|/code/${copy:+$copy/}||g; s|/code/||g"
  errors="$(grep -a 'error:' "$file" | grep -a -v -E '^[[:space:]]*\|' | sed "$strip" \
    | awk '!seen[$0]++' || true)"
  count=0
  [ -n "$errors" ] && count="$(printf '%s\n' "$errors" | wc -l | tr -d ' ')"
  echo "== $count distinct error lines$([ "$count" -gt 40 ] && echo ', the first 40:')"
  # sed, not head, reads its whole input, so printf never gets a SIGPIPE.
  [ -n "$errors" ] && printf '%s\n' "$errors" | sed -n '1,40p'
  case "$action" in
    list|install) grep -a -E '^swift-|^/usr/bin/wasmkit|^no wasmkit|warning: (the key|no sig)' "$file" | sed 's/^/== /' || true ;;
  esac
  [ "$action" = test ] || return 0
  totals "$file"
  failing="$(grep -a -E '✘|^/code/(\.build/[^/]*/)?Tests/[^:]*:[0-9]+: error:' "$file" \
    | grep -a -v '✘ Test run with' | sed "$strip" | awk '!seen[$0]++' || true)"
  count=0
  [ -n "$failing" ] && count="$(printf '%s\n' "$failing" | wc -l | tr -d ' ')"
  echo "== $count failing-test lines"
  [ -n "$failing" ] && printf '%s\n' "$failing"
  return 0
}

mkdir -p "$ROOT/$(dirname "$log")"
echo "== $image, $bundle ($triple): ${command[*]}"
if [ "$threads" = 1 ]; then
  echo "== in $copy, with _runtime(_multithreaded) as true"
elif [ -n "$copy" ]; then
  echo "== in $copy, the package without sockets"
fi
echo "== log: $log"
set +e
{
  echo "== $(date '+%Y-%m-%d %H:%M:%S') $image, $bundle ($triple): ${command[*]}"
  "${run[@]}" "$image" bash -c "$inner" cross "$action" "$bundle" "$key" "${command[@]}" 2>&1
} > "$ROOT/$log"
status=$?
set -e

summarize "$ROOT/$log" "$action"
echo "== exit status $status; log: $log"
exit "$status"
