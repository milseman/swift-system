# other-platforms: System on Musl, Android, WASI, FreeBSD and OpenBSD

Lane `other-platforms` (worktree `../other-platforms`, branch `other-platforms`,
base system-next `4365f83`). Goal: System builds on each of these platforms,
and has what the adopters' Musl, Bionic and WASILibc branches need, so that no
library has to import a platform C module. Darwin, glibc Linux and Windows are
other lanes'.

## Resume here

Stopped at Michael's request (2026-10-01), at the end of step 3's WASI part.

- **Done** (commits): `144b9ae` `Utilities/linux/cross.sh`, and SystemPackage
  building for Musl and WASI (1, 2.1, 2.2); `3dce05e` the terminal API's
  storage and flags for Android, FreeBSD and OpenBSD, from their headers
  (2.3); `fb0fecb` poll, `ClockID`, `ProcessEnvironment`, `SystemConfig`,
  `BrokenDownTime` and `DirectoryStream`/`DirectoryWalk` on WASI (3.1).
- **In progress**: nothing uncommitted.
- **Next**: the rest of step 3 (3.2): `DirectoryStreamTests` and
  `DirectoryEntryTypeTests` on WASI; on Android, `CLocale` and `Spawn` from
  Bionic's headers. Then Android's build, once an NDK is in
  `../linux-logs/cross/ndk/` (1.3): `Utilities/linux/cross.sh android install`,
  then `cross.sh android`.
- **For other lanes**: section 5 (SystemSockets on Musl, Android and WASI;
  the samples' imports; Package.swift for WASI; `BrokenDownTime`'s `Int`
  seconds on 32-bit platforms; linux-2's README).
- **Latest tests** (at `fb0fecb`): Darwin `swift build && swift test`: XCTest
  572 tests, 5 skipped, 0 failures; swift-testing 502 tests passed.
  `cross.sh wasi build -- --target SystemTests` and
  `cross.sh musl build -- --target SystemPackage`: 0 errors. WASI tests under
  WasmKit: no usable run (4). The whole package doesn't build for Musl or WASI
  without section 5's changes.
- **Checks**: `swift build && swift test` on Darwin; `Utilities/linux/cross.sh
  musl build -- --target SystemPackage` (and `--triple x86_64-swift-linux-musl`);
  `cross.sh wasi build -- --target SystemTests`. After a `--target` build of
  another target in the same scratch path, delete its
  `<triple>/debug/description.json` first (4).

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
| WASI | yes; the tests build, and run under WasmKit only in part (4) | the WebAssembly SDK for 6.2.4, `wasm32-unknown-wasip1` |
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
`source.properties` from it, and runs the setup script. Asked to retry, the
classifier also denied adding an opt-in `--fetch-ndk` to the script, so the
NDK has to come from outside the lane: `android-ndk-r27d-linux.zip` from
developer.android.com in `../linux-logs/cross/ndk/`, then
`Utilities/linux/cross.sh android install` and `cross.sh android`. Until
then, Android is handled as the BSDs are: fixes only where headers make them
certain.

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

### 2.3 Android, FreeBSD and OpenBSD: the terminal API

The terminal API compiled only on Darwin and Linux: `ControlCharacters`'
storage, a tuple that `TerminalAttributes` rebinds `termios`'s `c_cc` to, was
written out for those two. From the headers (FreeBSD's `sys/_termios.h`,
OpenBSD's `sys/termios.h`, both read through the GitHub API; the kernel's
`asm-generic/termbits.h`, which Bionic's `<termios.h>` includes):

- **Storage**: NCCS is 20 on FreeBSD and OpenBSD, as on Darwin, and 19 in the
  kernel's `termios`, which Bionic's is (glibc's and Musl's have 32).
  `testControlCharactersMatchTheCArray` checks the tuple against `c_cc` on
  every platform, so a wrong count fails a test rather than corrupting memory.
- **Flags**: the `os(Linux)` ones are on Android too, since the kernel defines
  them all; the `canImport(Darwin)` ones (now `SYSTEM_PACKAGE_DARWIN`) are on
  FreeBSD and OpenBSD, which define the same BSD names, but for OpenBSD's
  missing `CDTR_IFLOW`, `CDSR_OFLOW` and `CCAR_OFLOW`. The BSDs have no fill
  characters or delays but the tab's, so `OFILL`, `OFDEL`, the NL, CR, BS, VT
  and FF delays, `TAB1` and `TAB2` are off there, and OpenBSD has no `IUTF8`.
- **Window size**: FreeBSD and OpenBSD get the `TIOCGWINSZ` and `TIOCSWINSZ`
  shims, declared in `CSystemShared.h` with untyped pointers.
- `_POSIX_VDISABLE` was already right everywhere (`Constants.swift`).

Left for the BSDs, unverified without a compiler: the rest of System. Each
header-checked name above compiles only if everything around it does.
Possible widenings: FreeBSD defines most of the Linux-only high baud rates
(`B460800` and up, but `B576000` and `B1152000`), and OpenBSD has `OLCUC`.

## 3. The adopters' needs

From `../adopters-unix/INVENTORY.md`, the names on the adopters' Musl, Bionic
and WASILibc lines that System had only on other platforms. The inventory
classed them against system-next before linux-api merged; since then
linux-api's names (`POSIXErrorCode`, `maxSymbolicLinks`, `makeUniqueFile`,
`dataSync`, `CLocale`, `FileWatcher`, `readPassphrase`) cover Musl, and all
but `CLocale` cover Android. No name was missing on Musl alone.

By sites on WASI lines (the inventory's (W: b)): sockets 86, the allocator
37, pthreads 17, poll 10, directory streams 9, `mmap` 7, clocks 7,
`gmtime_r`/`strftime`/`tm` 6, `getenv` 4, `sysconf` 4, `sched_yield` 1,
`getuid` 1.

### 3.1 Done on WASI

`Memory` and `FileStream` (2.2), and in `fb0fecb`:

- **poll** (WasmKit's `PALPoll.swift`): WASI has no priority data, so no
  `POLLPRI`, `POLLRDBAND` or `POLLWRBAND`.
- **`ClockID`** (WasmKit's `PALClock.swift`, Foundation's `Date.swift`,
  `UUID.swift`, `ProcessInfo.swift`): only `realtime` and `monotonic`; WASI's
  `clockid_t` is a pointer to a constant, so `ClockID` is `@unchecked Sendable`
  there, and CSystemWASI.h returns the clocks.
- **`ProcessEnvironment`** (Foundation, NIOCore, NIOEmbedded):
  `csystem_environ` is wasi-libc's `__wasilibc_get_environ()`.
- **`SystemConfig`** (NIOCore's `_SC_NPROCESSORS_ONLN`): every name.
- **`BrokenDownTime`** (Foundation's `Date.swift`): local time is UTC, and
  there's no `tzset`.
- **`DirectoryStream`, `DirectoryWalk`, `FileType(directoryEntryType:)`**
  (WasmKit's `PALFileDescriptor.swift`, Foundation's
  `FileOperations+Enumeration.swift`): over CSystemWASI.h's copies of the
  entries, with its `DT_` values.

### 3.2 Left

- **WASI, buildable here**: `DirectoryStreamTests` and
  `DirectoryEntryTypeTests` still skip WASI, not yet widened;
  `DirectoryEntryTypeTests` also reads `CInterop.DirectoryEntry`, which stays
  off WASI (its `d_name` is a flexible array).
- **WASI, not System's to fix here**: pthreads (none: wasm32-wasip1's
  `libpthread.a` is empty, and `libc.a` has no `pthread_` symbol, so
  `PThread`, `sched_yield`'s `PThread.yield()`, NIOLock's and WasmKit's
  mutexes stay the C library's); `getuid` (wasi-libc has none); `mmap`
  (wasi-libc's is `wasi-emulated-mman`, which needs `-D_WASI_EMULATED_MMAN`
  and the library: section 5); sockets (SystemSockets: section 5).
- **Android, from headers until an NDK is here**: `CLocale` (Foundation's
  `Platform.swift` and `JSONEncoderTests.swift`: `newlocale`, `strtod_l`,
  `strtof_l`, `strncasecmp_l`, `setlocale`); `Spawn`, `RawSpawn` and
  `ChildProcess` (TSC's `Process.swift`: `posix_spawn_file_actions_t`), which
  need `posix_spawn` and friends from API 28, through CSystem shims that
  return `ENOSYS` below it, as `csystem_pthread_getname_np` does;
  `SO_REUSEPORT` is SystemSockets' (section 5).
- **BSDs**: section 2.3's possible widenings.

## 4. Findings

- **WASI tests under WasmKit** (in a scratch copy without the socket targets,
  which don't build for WASI): XCTest traps (`unreachable`) in `Bundle.main`'s
  initializer, called from `XCTMain`, before any test runs. swift-testing runs
  until WasmKit itself exits with "Error: Bad file descriptor", which ends the
  run: at `144b9ae` after 18 tests passed (`statAccessors()` failed with
  `ENOENT`, `permissions()` with `ENOSYS`, wasi-libc's `fchmod`), and at
  `fb0fecb` before any passed. The host's WASI call seems to throw for a bad
  descriptor rather than return `EBADF`, as the tests that use descriptor -1
  expect. So nothing on WASI has run beyond those 18 tests.
- **wasm32-wasip1 has no pthreads**: its `libpthread.a` is 8 bytes, and
  `libc.a` defines no `pthread_` function (wasip1-threads would have them).
- **32-bit `Int`**: `BrokenDownTime(secondsSinceEpoch:in:)` and
  `secondsSinceEpoch(in:)` use `Int`, so on wasm32 and 32-bit ARM Android they
  reach only 1901 to 2038, though `time_t` there is 64 bits on WASI.
- **A stale build description**: after `swift build --target A` on a scratch
  path, `--target B` can fail with "No target named
  'B-<triple>-debug.module' in build description"; deleting
  `<triple>/debug/description.json` there makes SwiftPM plan again.
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
- **SystemSockets on Android**: `SocketOption.reusePort` (`SO_REUSEPORT`),
  which Bionic has; NIO's `BSDSocketAPI.swift` keeps `import Android` for it.
- **WASI's sockets** (NIOCore's `BSDSocketAPI.swift`, `SocketAddresses.swift`,
  86 sites): SystemSockets would need a WASI branch; wasip1 has only
  `accept`, `recv`, `send` and `shutdown` on preopened sockets.
- **Package.swift for WASI**: `MemoryMapping` needs `-D_WASI_EMULATED_MMAN` in
  CSystem's and SystemPackage's C settings and linking `wasi-emulated-mman`
  (Foundation's `Data+Reading.swift` maps files on WASI); and SystemSockets
  excluded, or empty, there (above).
- **`BrokenDownTime`'s owner**: whether its seconds should be `Int64` or
  `time_t`, for 32-bit platforms (4).
- **`Utilities/linux/README.md`** (linux-2's): a line pointing to `cross.sh`.
