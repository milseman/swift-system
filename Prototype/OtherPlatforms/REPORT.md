# other-platforms: System on Musl, Android, WASI, FreeBSD and OpenBSD

Lanes `other-platforms` (worktree `../other-platforms`, base system-next
`4365f83`; sections 1 to 5), then `platforms-2` (worktree `../platforms-2`,
branch `platforms-2`, from system-next `bb950db`, the 2026-10-01 convergence
merge; sections 6 to 10). Goal: System builds on each of these platforms,
and has what the adopters' Musl, Bionic and WASILibc branches need, so that no
library has to import a platform C module. Darwin, glibc Linux and Windows are
other lanes'.

## Resume here

platforms-2, 2026-10-01: steps 1 (WASI) and 3 (the BSDs) done but what
waits on linux-3; step 2 (Android) done from headers, its build still blocked.

- **Done** (platforms-2 commits): `99eea7f` WASI's swift-testing suites run
  (6.11); `92984f5` the PThread family on WASI with threads (6.1); `66a4862`
  `ClockID.currentTimeSpec()` on WASI (6.2); `1d5bb6c` `FileStream`'s locks on
  WASI with threads (6.5); `86e396f` `Memory.usableSize(of:)` on WASI (6.4);
  `7bcde7e` the directory tests on WASI (6.11); `75cf417` `Spawn`, `RawSpawn`
  and `ChildProcess.spawn` on Android (7.2); `a70ce05` `maxSymbolicLinks` on
  FreeBSD and OpenBSD, and the pseudoterminal API on FreeBSD (8.2); `fee12f0`
  cross.sh after coverage-4's plugin product. system-next `d53a655` merged.
- **In progress**: nothing uncommitted.
- **Next**:
  1. When system-next has linux-3 (its `ef379e6`, `42616ac`, `9d00c35` and
     `83e956c` widen `PThread.Condition.wait(on:timeout:)` beyond Darwin, and
     the time zone paths, `UserEntry.realName` and `CLocale` to Android): merge
     (`git merge-tree` finds no conflict with linux-3 at `a181aff`), rerun
     `cross.sh wasi --assume-threads build -- --target SystemPackage` (its
     relative wait stores a `clockid_t`, a pointer on WASI), then widen
     `CLocale` to FreeBSD and OpenBSD and the time zone paths to both (8.3).
  2. Android's build, once an NDK is in `../linux-logs/cross/ndk/` (1.3):
     `Utilities/linux/cross.sh android install`, then `cross.sh android`;
     then the spawn tests with `/system/bin/sh` (7.2).
  3. `MemoryMapping` on WASI, after Package.swift's define (6.4, section 5).
- **For other lanes**: section 5; for the adopter lanes, sections 9 and 10.
- **Latest tests** (at `fee12f0`): Darwin `swift build --build-tests && swift
  test --skip-build`: XCTest 572 tests, 5 skipped, 0 failures; swift-testing
  503 tests passed. WASI, `cross.sh wasi test -- --disable-xctest`: 93 tests in
  20 suites passed (XCTest doesn't start there: 4). Builds with 0 errors:
  `Utilities/linux/build.sh --quiet` (the whole package), `cross.sh musl build
  -- --target SystemPackage`, `cross.sh wasi --assume-threads build --
  --target SystemPackage`. Before platforms-2's changes (at `bb950db`): the
  same Darwin totals but 502; WASI's tests didn't build (6.11).
- **Checks**: the commands above; `Prototype/OtherPlatforms/bsd-arms.py` for
  the API the adopters' widened branches leave on C on the BSDs (8.1).

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
| WASI | yes, and its swift-testing tests run under WasmKit (6.11) | the WebAssembly SDK for 6.2.4, `wasm32-unknown-wasip1`; `--assume-threads` typechecks for `wasm32-wasip1-threads` (1.5) |
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
  `/tmp` preopened, in a copy of the package without sockets (1.4).

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
certain. (Still empty on 2026-10-01, for platforms-2.)

### 1.4 FreeBSD and OpenBSD

No Swift SDK targets either from Linux (download.swift.org has no
`freebsd-sdk/` for 6.2.4 or 6.3.3), so neither builds here. Their headers,
read from freebsd/freebsd-src and openbsd/src through the GitHub API, are the
check, and Bionic's from aosp-mirror/platform_bionic. The API allows 60
unauthenticated requests an hour; raw.githubusercontent.com isn't reachable.

### 1.5 WASI's test runs and the threads typecheck (platforms-2)

- **A package without sockets.** SystemSockets `#error`s on WASI and SwiftPM
  builds the tests only with every target, so `cross.sh wasi build-tests` and
  `wasi test` run in `.build/cross-<tag>-wasi-package`: Sources, Tests and
  Package.swift copied again each run, with lines appended to the manifest
  that drop SystemSockets, its tests, the samples, the MemberImportVisibility
  canary and `_SystemPackageForPlugin`, and the package dependencies; scratch
  path `.build/cross-<tag>-wasi-tests`. `--whole` builds the package itself.
- **Filtering.** `-- --disable-xctest --filter ClockTests` works: swift-testing
  filters by type name (`ClockTests`, not its display name "Clocks"). With
  XCTest on, SwiftPM spawns the wasm bundle itself (`--dump-tests-json`) to
  list XCTest's tests, which fails with "Exec format error".
- **`--assume-threads`.** swift.org has no SDK for `wasm32-wasip1-threads`
  (`_wasm-threads` and `_wasm32-unknown-wasip1-threads` bundles 404 for
  6.2.4). Its headers are wasip1's, so cross.sh builds a copy of the package
  in which `_runtime(_multithreaded)` is `true`
  (`.build/cross-<tag>-wasi-threads-package`), with `-Xcc -D_REENTRANT`, which
  a threads SDK's `-pthread` defines. wasip1's libc defines no pthread
  function, so only a library target builds: `cross.sh wasi --assume-threads
  build -- --target SystemPackage`. The link check is against wasi-libc's
  `expected/wasm32-wasip1-threads/defined-symbols.txt` at `wasi-sdk-24`: the
  SDK's wasip1 `libc.a` defines exactly that tag's (and wasi-sdk-23's)
  `wasm32-wasip1` list, but for the symbols of the emulation libraries and
  crt1. `nm -u` on
  the threads build's objects, minus that list, leaves only linker,
  compiler-rt and CSystem symbols.

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
  with `nm` on its `libc.a`). `usableSize(of:)` is too since `86e396f` (6.4).
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
but `CLocale` cover Android (linux-3's `83e956c` adds it). No name was
missing on Musl alone.

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

platforms-2's WASI work is section 6.

### 3.2 Left

- **WASI**: sockets (SystemSockets: section 5); `getuid` and `UserEntry`
  (6.8); `mmap` (6.4, section 5); without threads, pthreads and the stream
  locks (6.1, 6.5).
- **Android**: the build (1.3); `SO_REUSEPORT` is SystemSockets' (section 5).
- **BSDs**: 8.3 and 8.4; section 2.3's possible baud rate widenings.

## 4. Findings

- **WASI tests under WasmKit**: XCTest traps (`unreachable`) in `Bundle.main`'s
  initializer, called from `XCTMain`, before any test runs, so only
  swift-testing runs (`--disable-xctest`). Its run used to end at the first
  test that made a temporary directory, with WasmKit's own "Error: Bad file
  descriptor": see 6.11 for why, and the WasmKit behaviors that the WASI
  tests now allow for.
- **wasm32-wasip1 has no pthreads**: its `libpthread.a` is 8 bytes, and
  `libc.a` defines no `pthread_` function, though `<pthread.h>` declares them
  all; `wasm32-wasip1-threads` defines most (6.1).
- **32-bit `Int`**: `BrokenDownTime(secondsSinceEpoch:in:)` and
  `secondsSinceEpoch(in:)` use `Int`, so on wasm32 and 32-bit ARM Android they
  reach only 1901 to 2038, though `time_t` there is 64 bits on WASI. So does
  `CInterop.TimeSpec.seconds`, which `currentTimeSpec()` returns there (6.2).
  And tests that assume `Int.max` bytes can't be allocated fail on wasm32,
  whose allocator can provide 2 GiB (6.11).
- **A stale build description**: after `swift build --target A` on a scratch
  path, `--target B` can fail with "No target named
  'B-<triple>-debug.module' in build description"; deleting
  `<triple>/debug/description.json` there makes SwiftPM plan again.
- **Declared but not defined**: musl and wasi-libc both declare functions
  their libraries lack, so a wrapper compiles and fails only at an
  executable's link. `nm` on the SDKs' `libc.a` in the cache checks a name;
  for wasip1-threads, wasi-libc's defined-symbols list (1.5).
- **WASILibc doesn't re-export `wasi_pthread`**: the module of `<pthread.h>`
  is separate in `wasi-libc.modulemap`, and Swift's `WASILibc.swift.gyb`
  exports only `SwiftWASILibc` (release/6.2). So `Exports.swift`'s mocking
  driver, whose thread-specific storage on WASI with threads is the real
  `pthread_key_create`, didn't typecheck there; it imports `wasi_pthread` now.
- **wasi-libc's opt-in emulations**: `<sys/mman.h>`, `<signal.h>` and
  `<sys/times.h>` `#error` without `-D_WASI_EMULATED_MMAN` (and the like), and
  Swift's clang importer defines none of them (ClangImporter.cpp at
  release/6.2 has no WASI defines), so a Swift file can't `import
  wasi_emulated_mman` without a build setting (6.4).

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
  or excluding it there, would let the tests build without cross.sh's copy.
- **SystemSockets on Android and OpenBSD**: `SocketOption.reusePort`
  (`SO_REUSEPORT`), which Bionic and OpenBSD have; NIO's `BSDSocketAPI.swift`
  keeps `import Android` for it, and its OpenBSD arm is C's (8.1).
- **WASI's sockets** (NIOCore's `BSDSocketAPI.swift`, `SocketAddresses.swift`,
  86 sites): SystemSockets would need a WASI branch; wasip1 has only
  `accept`, `recv`, `send` and `shutdown` on preopened sockets.
- **Package.swift for WASI**: `MemoryMapping` needs `_WASI_EMULATED_MMAN`
  defined for SystemPackage's clang importer and a Swift condition to build
  its WASI branch: `.define("_WASI_EMULATED_MMAN", .when(platforms: [.wasi]))`
  in `cSettings`, as Foundation's manifest has it, and a define such as
  `SYSTEM_WASI_EMULATED_MMAN` in `swiftSettings`; a Swift file's `import
  wasi_emulated_mman` then autolinks `-lwasi-emulated-mman` (its module map's
  `link`). See 6.4 for the API that wasi-libc's emulation can back. And
  SystemSockets excluded, or empty, there (above).
- **`BrokenDownTime`'s and `CInterop.TimeSpec`'s owner**: whether their
  seconds should be `Int64` or `time_t`, for 32-bit platforms (4).
- **`Utilities/linux/README.md`** (linux-2's): a line pointing to `cross.sh`.
- **For windows-3**: `99eea7f` moved `Tests/SystemTests/Win32SynchronizationTests.swift`'s
  `import Dispatch` into its `#if os(Windows)` block: imported everywhere, it
  stopped SystemTests from building for WASI, which has no Dispatch. No other
  change to the file.
- **For linux-3 and the integrator**: platforms-2 holds the BSD widenings of
  `CLocale` and `TimeZoneFiles` (8.3) until linux-3's Android widenings of the
  same gate lines are in system-next, to keep the merges apart.

## 6. platforms-2: WASI

In the gap lists' order (`../adopters-unix/UNIX-REPORT.md` section 6, rank 1;
`../adopters/PACKAGES-5-REPORT.md`, "Gaps, across platforms"). Several were
already on WASI (3.1), from before those lists were made.

### 6.1 PThread, its Mutex, ReadWriteLock, Condition and Key (`92984f5`)

- **What**: the thread API's files are on WASI under
  `_runtime(_multithreaded)`, that is `wasm32-wasip1-threads`, and import
  `wasi_pthread` (4). PThread's `init(attributes:_:)` and `join()`, `detach()`,
  `PThread.ID`, `yield()`; `Mutex` (lock, try, timed lock, `withLock`,
  attributes' kind and sharing); `Condition` (wait, timed wait, signal,
  broadcast, the realtime or monotonic clock); `ReadWriteLock`; `Key`.
- **Left out on WASI**, which wasi-libc (wasi-sdk 24) doesn't define, though
  `<pthread.h>` declares some: `PThread.exit()` (no `pthread_exit`);
  `Attributes.guardSize` and `.scheduling`, PThreadScheduling.swift (no
  scheduling at all: `<sched.h>` hides the policies); the mutex's priority
  protocols and ceilings, as on Android. Robust mutexes stay Linux's and
  FreeBSD's; cancellation, names and CPU sets were never on WASI.
- **Design calls**: the condition is `_runtime(_multithreaded)`, NIO's and
  swift-log's test for threads on WASI; rejected: PThread on wasip1 without
  threads, whose calls couldn't link, or whose locks could do nothing (the
  same open question as 6.5's). `PThread.Condition.Clock`'s raw value is WASI's
  `clockid_t`, a pointer, so its `Sendable` conformance moved to an
  extension, `@unchecked` on WASI, as `ClockID`'s is. `pthread_create` writes
  a `pthread_t`, a pointer there, through an optional, as on Musl.
- **Builds and tests**: typechecked with `--assume-threads` (1.5); every C
  function its objects reference is in the threads symbol list. The thread
  tests stay off WASI: on wasip1-threads they'd need gates for shared memory
  (`mmap`), the `CLOCK_` macros, scheduling and priorities, `exit()`, and
  `PThreadTestSupport`'s nanosecond helpers, which overflow a 32-bit `Int`
  (and do on 32-bit Android too: `monotonicNanoseconds()` multiplies
  `tv_sec` by 10^9 in `Int`).
- **Sites unblocked** (on WASI with threads): swift-log's `Lock`
  (`Locks.swift:49`) and `ReadWriteLock` (`:190`); swift-certificates'
  `LockPrimitive` (`Lock.swift:35`); swift-async-algorithms' `Lock`
  (`Locking.swift:33`, as `PThread.Mutex` beside Darwin's `UnfairLock`) and
  `TaskDriver` (`TaskDriver.swift:37`, PThread's init and join); NIO's
  `NIOLock`, `lock.swift` and `NIOThreadPoolWorkAvailable`'s untimed waits;
  Foundation's `_ThreadLocal`.

### 6.2 `ClockID.currentTimeSpec()` (`66a4862`)

- **What**: ClockTime.swift was off WASI, which has `clock_gettime` and
  `time_t`; `currentTimeSpec()` and `CInterop.Time` are on WASI now, for its
  two clocks. `CInterop.TimeSpec.seconds` is an `Int`, 32 bits on wasm32 (4).
- **Tests**: `ClockTests.everyClockReadsAsATimeSpec()`, new, on every
  platform but Windows; 4 tests passed on WASI.
- **Sites unblocked**: swift-log's `StreamLogHandler.timestamp()`
  (`StreamLogHandler.swift:209`), with `BrokenDownTime` (3.1): its
  `!os(WASI)` can go. Foundation's `Date.swift`, `UUID.swift` and
  `ProcessInfo.swift` `clock_gettime` arms (UNIX gap rank 3), through
  `currentTimeSpec()` or `currentTime()`.

### 6.3 `BrokenDownTime`

On WASI since `fb0fecb` (3.1); nothing to do. Its tests stay off wasm32 (4).

### 6.4 `Memory` and `MemoryMapping` (`86e396f`)

- **`Memory`**: all of it that wasi-libc has was on WASI (`reallocate` too,
  so UNIX gap rank 5's DataStorage and Data+Reading sites have it) but
  `usableSize(of:)`: wasi-libc defines `malloc_usable_size` but declares it in
  `<malloc.h>`, which its Swift module omits, so it's a CSystem shim, as on
  glibc. MemoryTests' two `usableSize` tests run on WASI.
- **`MemoryMapping`**: left off WASI, which has no `mmap`; wasi-libc's opt-in
  emulation (`-D_WASI_EMULATED_MMAN`, `-lwasi-emulated-mman`) needs build
  settings outside this lane (4, section 5). What the emulation could back:
  `mmap` mallocs and, for a file, reads it in with `pread`; `MAP_SHARED`
  doesn't write back (its `munmap` only frees); `munmap` frees only a whole
  mapping; `mprotect` needs a page-aligned address, which the emulation's
  aren't; no `msync`, `madvise` or `mincore`. So a WASI `MemoryMapping` could
  honestly have file and anonymous mappings with `.private` and `.read` or
  `.write`, `unmap()`, `relinquish()` and the spans, and not `.shared`,
  `setProtection`, `synchronize`, `advise` or `residentPages`. Open: whether
  System should vend an emulation at all. For Foundation's `Data+Reading.swift`
  (7 `mmap` sites), which maps files read-only and private.

### 6.5 `FileStream.withLock` (`1d5bb6c`)

- **What**: `lock()`, `unlock()`, `tryLock()` and `withLock(_:)` on WASI with
  threads: wasi-libc declares `flockfile` and its companions under
  `_REENTRANT` and defines them only with threads.
- **Open question**, noted in the source: without threads, where no other
  thread can come between a stream's calls, the locks could do nothing, so
  that callers needn't test for threads. Left out instead, as wasi-libc
  leaves them out.
- **Sites unblocked**: swift-log's `StdioOutputStream.stdout`
  (`StreamLogHandler.swift:328`) with threads; without them, its WASI branch
  can write through `FileStream`, the lock alone conditional.

### 6.6 `ProcessEnvironment.set`

On WASI since `fb0fecb` (3.1), over wasi-libc's `setenv`. For Foundation's
FileManagerTests' XDG test (UNIX gap rank 6).

### 6.7 `StatFS`

On WASI already (`statvfs`, through CSystemWASI.h), with `fragmentSize`
(`f_frsize`) and `fileSystemID` (`f_fsid`, an integer there); its suite passes
on WASI. Foundation's `attributesOfFileSystem` returns `[:]` on WASI by
choice. UNIX gap rank 7's other half, one accessor for the file system's
number on Darwin (whose `fsid_t` is two `Int32`s, of which Foundation reads
`val.0`) and elsewhere, is an API question for StatFS's owner, not WASI's.

### 6.8 `UserEntry`

WASI has no interface: wasi-libc has no `<pwd.h>` or `<grp.h>`, and its
`<unistd.h>` declares `getuid` and the like only for unmodified upstream
musl. So `UserEntry`, `UserID.current` and the like stay off WASI, and the
inventory's WASI `getuid` site (Foundation's FileManagerTests) has no System
API to move to.

### 6.9 `SystemConfig`

On WASI since `fb0fecb` (3.1), every name.

### 6.10 What else WASI's adopters call

Sockets (section 5) and, without threads, the thread API. `sched_yield`
(NIO's `atomics.swift`) is `PThread.yield()`, on WASI only with threads,
though wasi-libc's wasip1 defines `sched_yield`; and `PThread.sleep(for:)`,
over `nanosleep`, which WASI has, stays off WASI with Sleep.swift. Both could
move to a type that exists without threads. Open.

### 6.11 WASI's tests (`99eea7f`, `7bcde7e`)

- **Why runs ended**: under WasmKit (the Swift 6.2.4 toolchain's), a directory
  opened as `.` relative to a descriptor gets that descriptor's host
  descriptor, so closing it closes both. `withTemporaryFilePath`'s removal
  enumerated each directory that way, then failed with `EBADF`, and a later
  close made WasmKit exit. On WASI, `_recursiveRemove` opens each directory
  by its path; the descriptor-relative removal is unchanged elsewhere.
- **The build**: `Win32SynchronizationTests.swift` imported Dispatch outside its
  `os(Windows)` block (section 5); and the manifest copy (1.5).
- **Fixed tests**: StatTests (WASI's files have no permissions: `fchmod`
  fails), `statAccessors()` (WASI sees only the preopened `/tmp`),
  MemoryTests (on 32-bit, `Int.max` bytes are half the address space, which
  wasm32's allocator provides, and `1 << 40` is 0 in a 32-bit `Int`; the
  overflowing `calloc` total now overflows on 32-bit too).
- **New on WASI**: DirectoryStreamTests, DirectoryEntryTypeTests and the four
  DirectoryWalk suites (33 tests). WASI's differences: its `DT_` values are
  its file types (`DT_FIFO` is its stream socket's, `DT_SOCK` wasi-libc's 20),
  so `DTTOIF` isn't a shift; `dirent` ends in a flexible array, so the
  readdir test reads CSystem's copies; no FIFOs, no descriptor flags, no
  permissions. And WasmKit's: `rename` fails with `ENOTSUP` (the walk tests
  that move a directory stay off WASI), readdir's `d_ino` isn't stat's
  `st_ino`, and `fdopendir` of a file fails with `EBADF`, not `ENOTDIR`.
- **Result**: `cross.sh wasi test -- --disable-xctest`, 93 tests in 20 suites
  passed. XCTest's tests, most of SystemTests', still don't run (4).

## 7. platforms-2: Android

### 7.1 `CLocale`

Done by linux-3 (`83e956c`, not yet in system-next): Bionic's `newlocale`,
`freelocale` and `setlocale`, with `strtod`, `strtof` and `strncasecmp`
standing in for the `_l` forms, which Bionic has only from API levels 26 and
23 and which ignore the locale. Nothing left here.

### 7.2 `Spawn`, `RawSpawn` and `ChildProcess.spawn` (`75cf417`)

- **What**: on Android, each `posix_spawn` call System makes goes through a
  CSystem shim (declared in CSystemShared.h with untyped pointers, defined in
  shims.c): from API level 28, Bionic's call; below it, `ENOSYS`, which
  `spawn` throws as `Errno.noFunction`. `CInterop.SpawnAttributes` and
  `SpawnFileActions` are optional pointers there, as on Darwin and the BSDs.
  `Flags.createSession` too: Bionic's `POSIX_SPAWN_SETSID` is glibc's 0x80,
  under `_GNU_SOURCE`. `setWorkingDirectory` uses the existing
  `addchdir_np` shim (API level 34); `closeAll(from:)` stays Linux's and
  FreeBSD's (no `addclosefrom_np` in Bionic); `SpawnCredentials` stays
  Darwin's and Linux's.
- **Design calls**: shims rather than direct calls, which don't compile below
  API level 28 (`__BIONIC_AVAILABILITY_GUARD(28)` hides the declarations),
  and which pick up each NDK's nullability; the official 6.3 SDK's lowest
  triple is `android28`, but other SDKs and Swift's own default (21) go lower.
  Rejected: `__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__` with
  `__builtin_available`, which needs a define for all of CSystem.
- **Builds and tests**: from Bionic's `spawn.h` (AOSP's); nothing Android
  compiles here (1.3). Darwin, Linux and Musl build as before. The spawn
  tests stay off Android: they run `/bin/sh`, which is `/system/bin/sh`
  there, and nothing here runs them.
- **Sites unblocked**: TSC's `Process.swift` (`posix_spawn_file_actions_t`),
  whose Android branch is C's.

## 8. platforms-2: FreeBSD and OpenBSD

### 8.1 What the widened branches leave on C there

`Prototype/OtherPlatforms/bsd-arms.py` lists, for the adopters-unix packages,
the System names that a widened branch (`canImport(Darwin) || os(Linux) ||
...`) uses where its C arm still serves FreeBSD or OpenBSD, and that System
doesn't build there (from api-delta's scan of this checkout; it reads
`../adopters-unix` without writing). Its matching is lexical, as arms.py's
is, so local names such as `errno`, `buffer` and `options` show up; the real
ones, with the BSD headers' verdict:

| System API | Sites (F, O) | Same interface on the BSDs? |
|---|---|---|
| `SystemConfig.maxSymbolicLinks` | Foundation `String+Path.swift:669` (F, O) | yes, `MAXSYMLINKS` 32 on both: widened (8.2) |
| `TerminalDescriptor.openPseudoterminal`, `pseudoterminalPath()` | Subprocess `UnixTests.swift:1510` (F, O) | FreeBSD yes: widened (8.2); OpenBSD has no `ptsname_r` |
| `CLocale` and its members | Foundation `Platform.swift:449`, `:472`, `:486`, `:501`; `JSONEncoderTests.swift:1507` (F, O) | FreeBSD yes (xlocale, as Darwin's); OpenBSD has no `strtod_l`, `strtof_l`: pending (8.3) |
| `FilePath.timeZoneDirectory`, `defaultTimeZoneFile` | Foundation `TimeZone_Cache.swift:160`, `:177` (F, O) | yes, tzcode's paths: pending (8.3) |
| `FileDescriptor.sendFile` | NIO `System.swift:1117` (F, O) | no (8.4) |
| `extendedAttribute` and the other xattr API | Foundation `FileManager+Files.swift:495`, `:537`, `FileManager+Utilities.swift:184` (F; O 1) | no (8.4) |
| `CInterop.POSIXErrorCode` | Foundation `ErrorCodes+POSIX.swift:79`, `:99` (F, O) | each system's own errno set (8.4) |
| `PThread.setCurrentName` | NIO `ThreadPosix.swift:17` (O) | no (8.4) |
| `SocketOption.reusePort` | NIO `BSDSocketAPI.swift:699` (O) | yes, but SystemSockets' (section 5) |

### 8.2 Widened (`a70ce05`)

- **`SystemConfig.maxSymbolicLinks`**: `MAXSYMLINKS` is 32 in both systems'
  `<sys/param.h>` (OpenBSD's is its `SYMLOOP_MAX`), which CSystem returns, as
  on Linux (`_system_get_MAXSYMLINKS`, in CSystemShared.h's and shims.c's BSD
  sections). `maxExtendedAttributeNameBytes` stays where it was.
- **The pseudoterminal API on FreeBSD**: `<stdlib.h>` declares
  `posix_openpt`, `grantpt`, `unlockpt` and `ptsname_r` by default
  (`__BSD_VISIBLE`); FreeBSD's `ptsname_r` returns -1 and sets errno, as
  Darwin's does (`lib/libc/stdlib/ptsname.c`), so Darwin's conversion serves
  it. Its tests aren't widened: nothing here runs them.

### 8.3 Pending linux-3

Both edit the gate lines that linux-3's Android commits change, so they wait
for those in system-next (section 5):

- **`CLocale`** on FreeBSD: `newlocale`, `freelocale`, `uselocale` and the
  `LC_*_MASK`s (`xlocale/_locale.h`, `LC_ALL_MASK` an OR of six), `strtod_l`
  and `strtof_l` (`xlocale/_stdlib.h`), `strncasecmp_l`
  (`xlocale/_strings.h`): Darwin's interface, from the same code. On OpenBSD,
  `newlocale`, `freelocale`, `uselocale`, the masks (`LC_ALL_MASK` is `(1 <<
  _LC_LAST) - 2`) and `strncasecmp_l`, but no `strtod_l` or `strtof_l`;
  OpenBSD's `LC_NUMERIC` is always C's, so `strtod` and `strtof` would stand
  in, as linux-3 does on Android.
- **`FilePath.timeZoneDirectory` and `defaultTimeZoneFile`**:
  `/usr/share/zoneinfo` and `/etc/localtime` on both, tzcode's `TZDIR` and
  `TZDEFAULT` (FreeBSD's `contrib/tzcode/tzfile.h` no longer defines them;
  check the build's `-D`s, or spell the paths, as linux-3 does for Android).

### 8.4 Not the same interface

- **`sendFile`**: FreeBSD's `sendfile(fd, s, offset, nbytes, hdtr, &sbytes,
  flags)` isn't Linux's, which System's `FileDescriptor.sendFile` wraps, nor
  Darwin's `SocketDescriptor` one; OpenBSD has none.
- **Extended attributes**: FreeBSD's are `extattr_get_fd` and the like, with
  namespaces; OpenBSD has none.
- **`POSIXErrorCode`**: an enum of each C library's errno names; FreeBSD and
  OpenBSD lack the STREAMS ones (`ENODATA`, `ENOSR`, `ENOSTR`, `ETIME`) that
  Foundation's widened branch names, and OpenBSD `EMULTIHOP` and `ENOLINK`.
  Two more enums from their `<errno.h>`s, and Foundation's own conditionals
  for the missing names. Open.
- **`PThread.setCurrentName` on OpenBSD**: `pthread_set_name_np`, which
  returns nothing; FreeBSD has `pthread_setname_np` (on already).

## 9. For unix-adopt-2

Each item: what System now builds, and the adopters-unix sites whose WASI,
Android or BSD arm can take it (rule: one System call where System covers
every platform the site compiles for).

- **WASI** (platforms the WASI arms compile for: wasip1, and wasip1-threads
  where they test `_runtime(_multithreaded)`):
  - `PThread`, `Mutex`, `Condition`, `ReadWriteLock`, `Key` with threads (6.1):
    NIOConcurrencyHelpers' `NIOLock.swift`, `lock.swift` and
    `NIOThreadPoolWorkAvailable.swift` (their `_runtime(_multithreaded)` arms);
    Foundation's `_ThreadLocal`.
    Without threads those arms do nothing, so a collapse keeps
    `!os(WASI) || _runtime(_multithreaded)`.
  - `ClockID.currentTimeSpec()` (6.2): Foundation `Date.swift:270`,
    `UUID.swift:505`, `ProcessInfo.swift:190`, `:606` (`clock_gettime`).
  - `Memory.usableSize(of:)` (6.4): none listed.
  - Not available on WASI (say so in the gap list): `UserEntry`/`getuid`
    (6.8), `MemoryMapping` (6.4), sockets.
- **Android**: `ProcessID.spawn`, `ChildProcess.spawn` and `RawSpawn` (7.2):
  TSC `Process.swift`'s Android branch. From API level 28; below it they throw
  `noFunction`, where the C branch didn't compile.
- **FreeBSD and OpenBSD**: `SystemConfig.maxSymbolicLinks` (both);
  `openPseudoterminal` and `pseudoterminalPath()` (FreeBSD): Subprocess's
  `UnixTests.swift:1510`. Neither builds here; from headers.
- **Unchanged**: the UNIX gap list's rank 2 (`wait(on:timeout:)`) is
  linux-3's (`ef379e6`, for L, M, A, F, O).

## 10. For packages-6

From PACKAGES-5's "Gaps, across platforms" (all WASI):

| Rank | Gap | Now |
|---|---|---|
| 1 | `PThread.Mutex` on WASI with threads: swift-log `Lock` (`Locks.swift:49`), swift-certificates `LockPrimitive` (`Lock.swift:35`), swift-async-algorithms `Lock` (`Locking.swift:33`) | built (6.1); the sites' threads arm, `_runtime(_multithreaded)`, can call it |
| 2 | `PThread` `init(_:)`, `join()` on WASI: swift-async-algorithms `TaskDriver` (`TaskDriver.swift:37`) | built with threads (6.1) |
| 2 | `PThread.ReadWriteLock` on WASI: swift-log `ReadWriteLock` (`Locks.swift:190`) | built with threads (6.1) |
| 2 | `ClockID.currentTimeSpec()` and `BrokenDownTime` on WASI: swift-log `StreamLogHandler.timestamp()` (`StreamLogHandler.swift:209`) | both built (6.2, 3.1); the `!os(WASI)` can go |
| 2 | `FileStream.withLock` on WASI: swift-log `StdioOutputStream.stdout` (`StreamLogHandler.swift:328`) | built with threads (6.5); without, still no lock (open question in 6.5) |

The Windows rows are other lanes'.
