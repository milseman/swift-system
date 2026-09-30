# other-platforms: System on Musl, Android, WASI, FreeBSD and OpenBSD

Lane `other-platforms` (worktree `../other-platforms`, branch `other-platforms`,
base system-next `4365f83`). Goal: System builds on each of these platforms,
and has what the adopters' Musl, Bionic and WASILibc branches need, so that no
library has to import a platform C module. Darwin, glibc Linux and Windows are
other lanes'.

## Resume here

- State: step 1 (builds) done: `Utilities/linux/cross.sh` builds for Musl and
  WASI (section 1). Step 2: SystemPackage builds for Musl (aarch64 and x86_64)
  and WASI, and SystemTests for WASI (section 2); the rest of the package
  needs other lanes' files (section 5).
- Blocked: Android needs an NDK, which this lane can't fetch (section 1.3).
- Next: step 2 for FreeBSD and OpenBSD from their headers, then step 3, the
  adopters' Musl, Bionic and WASILibc names (section 3).
- Checks: `swift build && swift test` on Darwin; `Utilities/linux/cross.sh musl`,
  `cross.sh musl build -- --target SystemPackage`, and
  `cross.sh wasi build -- --target SystemTests`.

## 1. Builds

`Utilities/linux/cross.sh <platform> [action] [-- swift args]` runs
`swift build --swift-sdk <sdk>` in the container that `build.sh` uses, with
the SDK cached in `../linux-logs/cross/` (bundles, installed SDKs, and an
Android NDK), mounted at `/cache`. It prints only a summary: the distinct
`error:` lines (the first 40), a test run's totals and failing tests, and the
exit status. Its `--help` has the options.

| Platform | Builds here | How |
|---|---|---|
| Musl | yes | the Static Linux SDK 0.1.0 for Swift 6.2.4, `aarch64-swift-linux-musl` (default) or `x86_64-swift-linux-musl` |
| WASI | yes, and tests run under WasmKit | the WebAssembly SDK for 6.2.4, `wasm32-unknown-wasip1` |
| Android | not yet: needs an NDK (1.3) | the Android SDK for Swift 6.3.3, in `swift:6.3-noble` |
| FreeBSD | no | swift.org publishes no FreeBSD Swift SDK |
| OpenBSD | no | no Swift SDK at all |

### 1.1 Musl and WASI

- The bundles come from download.swift.org, which the sandbox reaches; the
  script downloads them on the host with their `.sig`, and checks the
  signature in the container against the key the image names
  (`SWIFT_SIGNING_KEY`), fetched from keyserver.ubuntu.com, which the host
  can't reach. Both checked out ("Good signature", key since expired).
- The static SDK's name has its own version, `static-linux-0.1.0` for 6.2.4
  (`-0.0.1` for older releases; that name 404s for 6.2.4).
- The wasm bundle holds two SDKs, `swift-6.2.4-RELEASE_wasm` and
  `..._wasm-embedded`, with the same triple, and `--swift-sdk <triple>` picked
  either from one run to the next (the embedded one fails on `Codable`), so
  the script selects the wasm SDK by name.
- Tests: the static SDK has neither XCTest nor swift-testing, so no test target
  builds for Musl. The wasm SDK has both, and the 6.2 image has
  `/usr/bin/wasmkit`, so `cross.sh wasi test` runs the tests under WasmKit, with
  `/tmp` preopened (section 4).

### 1.2 Android for Swift 6.2

- swift.org has no Android SDK for any 6.2 release (`android-sdk/` 404s for
  6.2 through 6.2.4); its Android SDKs start with 6.3.
- The community SDK (finagolfin/swift-android-sdk) has one for 6.2-RELEASE
  only, which needs the 6.2.0 toolchain; the image here is 6.2.4, and a
  module from another compiler version doesn't load.
- So Android builds use `swift:6.3-noble` (6.3.3, already pulled) with the
  official 6.3.3 SDK, whose triples are `aarch64`, `x86_64` and
  `armv7-unknown-linux-android28` through `android36`. The default is
  `aarch64-unknown-linux-android28`, its lowest API level.

### 1.3 Android's NDK (blocked)

The Android SDK has no sysroot: its `setup-android-sdk.sh` links one from an
Android NDK (r27 or later), from dl.google.com, which the sandbox's proxy
blocks on the host. Fetching it in the container instead was denied by the
auto mode classifier, so `cross.sh` doesn't download an NDK: it takes
`android-ndk-r27d-linux.zip`, or the directory it unzips to, from
`../linux-logs/cross/ndk/`, unzips the sysroot, the clang resources and
`source.properties` from it, and runs the setup script. Until an NDK is
there, Android is handled as the BSDs are: fixes only where headers make
them certain.

### 1.4 FreeBSD and OpenBSD

No Swift SDK targets either from Linux (download.swift.org has no
`freebsd-sdk/` for 6.2.4 or 6.3.3), so neither builds here. Their headers,
read from freebsd/freebsd-src and openbsd/src through the GitHub API, are the
check.

## 2. Making System build

### 2.1 Musl

SystemPackage builds for both triples without source changes. Linking an
executable against it failed: musl declares `pthread_mutexattr_setprioceiling`
but its `libc.a` doesn't define it (nor `pthread_mutexattr_getprioceiling`;
`nm` on the SDK's `libc.a` shows only the `pthread_mutex_` pair and
`pthread_mutexattr_setprotocol`). `system_pthread_mutexattr_setprioceiling`
now returns `ENOTSUP` on Musl without calling it, so a mutex with a ceiling
fails to initialize there. Open: musl's `pthread_mutex_setprioceiling` fails
with `EINVAL`, which could serve instead, or `priorityCeiling` could go on
Musl, as it has on Android.

With the needs in section 5 applied in a scratch copy, the whole package
builds for Musl and `system-samples` links statically.

### 2.2 WASI

- **`FILE`**: wasi-libc's `FILE` is an incomplete type (its `stdio.h` defines
  `struct _IO_FILE` only in unmodified upstream musl), which Swift doesn't
  import, so the provisional stdio layer didn't compile. `FileStream.rawValue`
  is an `OpaquePointer` on WASI, as Swift imports `FILE *` there, and WASI has
  no `CInterop.File`. The wrappers in `Syscalls+Provisional.swift` and the
  standard streams in `Constants+Provisional.swift` take `_CFilePointer`,
  `UnsafeMutablePointer<FILE>` elsewhere.
- **`Memory`** is on WASI: wasi-libc defines `malloc`, `calloc`, `realloc`,
  `free`, `posix_memalign`, `memcmp`, `memchr` and `explicit_bzero` (checked
  with `nm` on its `libc.a`). `usableSize(of:)` isn't: wasi-libc declares
  `malloc_usable_size` only in `<malloc.h>`, which its Swift module omits.
  (`valloc` is declared there but not defined.)
- **Tests**: `FileLockTests.swift` imported Dispatch, which WASI lacks;
  the tests that call `duplicate`, `FileDescriptor.pipe()` or `clock_gettime`
  with `CLOCK_REALTIME` (a pointer macro Swift can't import on WASI) are
  gated off WASI.

## 3. The adopters' needs

Not started. From `../adopters-unix/INVENTORY.md`, the names whose class is
(b) on Musl, Android or WASI: on Android, `SO_REUSEPORT` (SystemSockets) and
`posix_spawn_file_actions_t`; on WASI, sockets, `mmap`, `poll`, `sysconf`,
the allocator (done, 2.2), clocks, directory streams, `getenv`, `getuid`,
`gmtime_r` and `strftime`, and pthreads.

## 4. Findings

- **WASI tests under WasmKit** (in a scratch copy without the socket targets,
  which don't build for WASI): XCTest traps (`unreachable`) in `Bundle.main`'s
  initializer, called from `XCTMain`, before any test runs. swift-testing runs;
  `statAccessors()` fails with `ENOENT` and `permissions()` with `ENOSYS`
  (wasi-libc's `fchmod`), and then WasmKit itself exits with "Error: Bad file
  descriptor" during the `Stat` suite, ending the run.
- **Declared but not defined**: musl and wasi-libc both declare functions
  their libraries lack, so a wrapper compiles and fails only at an
  executable's link. `nm` on the SDKs' `libc.a` in the cache checks a name.

## 5. Needs outside this lane's files

- **SystemSockets on Musl** (`Sources/SystemSockets/Sockets/SocketTCPInfo.swift`):
  musl defines the `TCP_*` states as macros, which import as `Int32`, where
  glibc's anonymous enum imports as `Int`; `TCPState`'s non-Darwin
  `init(_ value: Int)` should take any `BinaryInteger`.
- **Samples on Musl and Android** (`Sources/Samples/Platforms/Enums/PlatformProcess.swift`,
  `Sources/Samples/Platforms/Samples/Processes.swift`): import `Musl` and
  `Android` beside `Glibc`; `Processes.swift` reads `environ`, so
  `@preconcurrency import Musl`.
- **SystemSockets on WASI**: its files `#error` off Darwin, Glibc, Musl and
  Android, and Package.swift builds it everywhere, so neither `swift build` nor
  `swift test` finishes for WASI. Gating its files off WASI (an empty module),
  or excluding it there, would let the tests build.
- **`Utilities/linux/README.md`** (linux-2's): a line pointing to `cross.sh`.
