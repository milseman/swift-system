# Status: System's API and its adopters

Generated 2026-09-28 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage` @ `be36a44c` (Add FileDescriptor.openSharedMemory(named:_:options:permissions:) and removeSharedMemory(named:) for shm_open and shm_unlink, and NamedSemaphore for sem_open, sem_close, sem_unlink, sem_wait, sem_trywait and sem_post), which doesn't contain `system-next` @ `e8762dd1` (Merge branch 'coverage' into system-next); 0 commit(s) of `coverage` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `be36a44c`.
- **Adopters** (`../adopters`, branch `migrate-darwin`, against its merge base with `main`):
  - WasmKit @ `1e9c513d`, base `1e9c513d` (no commits beyond the merge base yet) (uncommitted changes in the checkout aren't counted)
  - indexstore-db @ `cc966b89`, base `441ead77`
  - swift-argument-parser @ `0fbda276`, base `1021ac8c`
  - swift-async-algorithms @ `bd5f6f44`, base `789dcf1f`
  - swift-certificates @ `0df6bd14`, base `ff86b924`
  - swift-driver @ `33d2c7b5`, base `15cf6766`
  - swift-foundation @ `8e0a70b5`, base `6669273a`
  - swift-log @ `4d6d77fe`, base `9c9acde6`
  - swift-nio @ `9ac12ff1`, base `feaf4ac5`
  - swift-package-manager @ `f7a4a9e1`, base `24a8a7b0`
  - swift-subprocess @ `1dc7dbb8`, base `8f099c6e`
  - swift-syntax @ `961f0b72`, base `e9289aa4`
  - swift-tools-protocols @ `07d2884f`, base `07d2884f` (no commits beyond the merge base yet) (uncommitted changes in the checkout aren't counted)
  - swift-tools-support-core @ `530d4e50`, base `c574915f`

# 1. API

Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF=main`, `HEAD_REF=HEAD`); its links point into that run's API-DELTA.md.

## Summary

- **2860 added, 0 removed, 0 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2284 (448 → 2732 public symbols).
  - SystemSockets: +576 (0 → 576 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 2825
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 1
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 408 compiled only on other platforms;
  - 233 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 26 added, removed or changed graph symbols the scan didn't find (enum case: 25, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2562 / -0 declarations, which is the graphs' +2284 plus 278 implicit ones; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +648 / -0 declarations, which is the graphs' +576 plus 71 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- Nothing was removed or changed: no public declaration left the graphs or the source scan. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 38 | 0 | 0 | S199 ×38 |
| SystemPackage | [`ChildProcess`](#systempackage-childprocess) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`ClockID`](#systempackage-clockid) | 13 | 0 | 0 | S199 ×13 |
| SystemPackage | [`ControlCharacter`](#systempackage-controlcharacter) | 21 | 0 | 0 | S199 ×21 |
| SystemPackage | [`ControlCharacters`](#systempackage-controlcharacters) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ControlFlags`](#systempackage-controlflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`DirectoryStream`](#systempackage-directorystream) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`DirectoryWalk`](#systempackage-directorywalk) | 16 | 0 | 0 | S199 ×16 |
| SystemPackage | [`DiskQuota`](#systempackage-diskquota) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`DynamicLibrary`](#systempackage-dynamiclibrary) | 24 | 0 | 0 | S199 ×24 |
| SystemPackage | [`Entropy`](#systempackage-entropy) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`Errno`](#systempackage-errno) | 4 | 0 | 0 | S199 ×3, S0.0.1 ×1 |
| SystemPackage | [`ExitStatus`](#systempackage-exitstatus) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`ExtendedAttributeOptions`](#systempackage-extendedattributeoptions) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 241 | 0 | 0 | S199 ×228, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 435 | 0 | 0 | S199 ×421, S199+OS ×14 |
| SystemPackage | [`FilePermissions`](#systempackage-filepermissions) | 1 | 0 | 0 | S199 ×1 |
| SystemPackage | [`FileStream`](#systempackage-filestream) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`FileSystemID`](#systempackage-filesystemid) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`FileSystemSubtype`](#systempackage-filesystemsubtype) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`FileSystemType`](#systempackage-filesystemtype) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`FileType`](#systempackage-filetype) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`GroupEntry`](#systempackage-groupentry) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`GroupID`](#systempackage-groupid) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`InputFlags`](#systempackage-inputflags) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`KernelEvent`](#systempackage-kernelevent) | 82 | 0 | 0 | S199 ×82 |
| SystemPackage | [`KernelQueue`](#systempackage-kernelqueue) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`LocalFlags`](#systempackage-localflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`Mach`](#systempackage-mach) | 53 | 0 | 0 | S199 ×53 |
| SystemPackage | [`Memory`](#systempackage-memory) | 49 | 0 | 0 | S199 ×49 |
| SystemPackage | [`MemoryMapping`](#systempackage-memorymapping) | 36 | 0 | 0 | S199 ×36 |
| SystemPackage | [`MountFlags`](#systempackage-mountflags) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`NamedSemaphore`](#systempackage-namedsemaphore) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`NetworkInterface`](#systempackage-networkinterface) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`OutputFlags`](#systempackage-outputflags) | 34 | 0 | 0 | S199 ×34 |
| SystemPackage | [`OwnedFD`](#systempackage-ownedfd) | 30 | 0 | 0 | S199 ×30 |
| SystemPackage | [`POSIXErrorCode (extends _DarwinFoundation1)`](#systempackage-posixerrorcode-extends-darwinfoundation1) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`PThread`](#systempackage-pthread) | 123 | 0 | 0 | S199 ×123 |
| SystemPackage | [`ProcessEnvironment`](#systempackage-processenvironment) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessID`](#systempackage-processid) | 209 | 0 | 0 | S199 ×209 |
| SystemPackage | [`ProcessPriority`](#systempackage-processpriority) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ProcessStateChange`](#systempackage-processstatechange) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessTimer`](#systempackage-processtimer) | 18 | 0 | 0 | S199 ×18 |
| SystemPackage | [`ResourceLimit`](#systempackage-resourcelimit) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`SearchPaths`](#systempackage-searchpaths) | 42 | 0 | 0 | S199 ×41, S199+OS ×1 |
| SystemPackage | [`Signal`](#systempackage-signal) | 73 | 0 | 0 | S199 ×73 |
| SystemPackage | [`SignalSet`](#systempackage-signalset) | 22 | 0 | 0 | S199 ×22 |
| SystemPackage | [`SpawnAttributes`](#systempackage-spawnattributes) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`SpawnFileAction`](#systempackage-spawnfileaction) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`StatFS`](#systempackage-statfs) | 27 | 0 | 0 | S199 ×27 |
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 70 | 0 | 0 | S199 ×70 |
| SystemPackage | [`SystemControl`](#systempackage-systemcontrol) | 72 | 0 | 0 | S199 ×72 |
| SystemPackage | [`SystemIdentity`](#systempackage-systemidentity) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`TerminalAttributes`](#systempackage-terminalattributes) | 44 | 0 | 0 | S199 ×44 |
| SystemPackage | [`TerminalDescriptor`](#systempackage-terminaldescriptor) | 41 | 0 | 0 | S199 ×41 |
| SystemPackage | [`UserEntry`](#systempackage-userentry) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`UserID`](#systempackage-userid) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`iovec (extends Darwin)`](#systempackage-iovec-extends-darwin) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`kevent (extends Darwin)`](#systempackage-kevent-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`stat (extends Darwin)`](#systempackage-stat-extends-darwin) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`timespec (extends _DarwinFoundation2)`](#systempackage-timespec-extends-darwinfoundation2) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`timeval (extends _DarwinFoundation2)`](#systempackage-timeval-extends-darwinfoundation2) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`AddressResolutionError`](#systemsockets-addressresolutionerror) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`CInterop`](#systemsockets-cinterop) | 3 | 0 | 0 | S199 ×3 |
| SystemSockets | [`CInterop (extends SystemPackage)`](#systemsockets-cinterop-extends-systempackage) | 19 | 0 | 0 | S199 ×19 |
| SystemSockets | [`IPv4Address`](#systemsockets-ipv4address) | 32 | 0 | 0 | S199 ×32 |
| SystemSockets | [`IPv6Address`](#systemsockets-ipv6address) | 30 | 0 | 0 | S199 ×30 |
| SystemSockets | [`SocketAddress`](#systemsockets-socketaddress) | 67 | 0 | 0 | S199 ×67 |
| SystemSockets | [`SocketDescriptor`](#systemsockets-socketdescriptor) | 345 | 0 | 0 | S199 ×339, S199+OS ×6 |
| SystemSockets | [`UnixAddress`](#systemsockets-unixaddress) | 8 | 0 | 0 | S199 ×8 |
| SystemSockets | [`VMSocketAddress`](#systemsockets-vmsocketaddress) | 20 | 0 | 0 | S199 ×20 |
| SystemSockets | [`cmsghdr (extends Darwin)`](#systemsockets-cmsghdr-extends-darwin) | 4 | 0 | 0 | S199 ×4 |
| SystemSockets | [`in6_addr (extends Darwin)`](#systemsockets-in6-addr-extends-darwin) | 2 | 0 | 0 | S199 ×2 |
| SystemSockets | [`in_addr (extends Darwin)`](#systemsockets-in-addr-extends-darwin) | 2 | 0 | 0 | S199 ×2 |
| SystemSockets | [`linger (extends Darwin)`](#systemsockets-linger-extends-darwin) | 3 | 0 | 0 | S199 ×3 |
| SystemSockets | [`msghdr (extends Darwin)`](#systemsockets-msghdr-extends-darwin) | 8 | 0 | 0 | S199 ×8 |
| SystemSockets | [`sockaddr (extends Darwin)`](#systemsockets-sockaddr-extends-darwin) | 3 | 0 | 0 | S199 ×3 |
| SystemSockets | [`sockaddr_in (extends Darwin)`](#systemsockets-sockaddr-in-extends-darwin) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`sockaddr_in6 (extends Darwin)`](#systemsockets-sockaddr-in6-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemSockets | [`sockaddr_storage (extends Darwin)`](#systemsockets-sockaddr-storage-extends-darwin) | 3 | 0 | 0 | S199 ×3 |
| SystemSockets | [`sockaddr_un (extends Darwin)`](#systemsockets-sockaddr-un-extends-darwin) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`sockaddr_vm (extends Darwin)`](#systemsockets-sockaddr-vm-extends-darwin) | 5 | 0 | 0 | S199 ×5 |
| **Total** | | **2860** | **0** | **0** | |

# 2. Adoption

Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or `import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration (`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under `#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. *Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.

| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | Through a re-export (copied) | Markers (files) |
|---|---:|---:|---:|---:|---:|---:|---:|
| WasmKit | 333 | 14 | 0 | 0 | 0 | — | 0 (0) |
| indexstore-db | 73 | 1 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| swift-argument-parser | 166 | 1 → 0 | 0 | 0 → 1 | 0 | 1 → 0 | 0 (0) → 1 (1) |
| swift-async-algorithms | 146 | 2 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-certificates | 133 | 2 → 0 | 0 | 0 → 1 | 0 | 3 → 0 | 0 (0) → 1 (1) |
| swift-driver | 195 | 11 → 0 | 1 → 0 | 0 → 2 | 0 | — | 0 (0) → 3 (2) |
| swift-foundation | 431 | 33 → 0 | 1 → 0 | 0 → 14 | 3 | 7 → 1 | 0 (0) → 22 (15) |
| swift-log | 30 | 5 → 0 | 0 | 0 → 2 | 0 | 1 → 0 | 0 (0) → 3 (2) |
| swift-nio | 479 | 41 → 0 | 3 → 0 | 0 → 8 | 0 | — | 0 (0) → 8 (8) |
| swift-package-manager | 883 | 3 → 0 | 2 → 0 | 0 → 3 | 0 | — | 0 (0) → 5 (3) |
| swift-subprocess | 36 | 17 → 0 | 0 | 0 → 2 | 0 | — | 0 (0) → 3 (2) |
| swift-syntax | 586 | 2 → 0 | 0 | 0 → 2 | 0 | 3 → 0 | 0 (0) → 3 (2) |
| swift-tools-protocols | 232 | 2 | 0 | 0 | 0 | — | 0 (0) |
| swift-tools-support-core | 124 | 0 | 1 → 0 | 0 → 5 | 0 | 14 → 5 | 0 (0) → 13 (5) |
| **All** | 3847 | 134 → 16 | 9 → 0 | 0 → 40 | 3 | | 0 (0) → 62 (41) |

Files whose imports aren't narrow yet: WasmKit: `Sources/CLICommands/Platform.swift` (whole module), WasmKit: `Sources/CLICommands/Run.swift` (whole module), WasmKit: `Sources/CLICommands/TCPListener.swift` (whole module), WasmKit: `Sources/WASI/Platform/PAL/PALClock.swift` (whole module), WasmKit: `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` (whole module), WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` (whole module), WasmKit: `Sources/WASI/Platform/PAL/PALPoll.swift` (whole module), WasmKit: `Sources/WasmKit/Execution/Profiler.swift` (whole module), WasmKit: `Sources/WasmKit/Execution/StatsCollector.swift` (whole module), WasmKit: `Sources/WasmKit/Platform/AtomicParkingLot.swift` (whole module), WasmKit: `Sources/WasmParser/Platform/FileIO.swift` (whole module), WasmKit: `Tests/WASITests/TestSupport.swift` (whole module), WasmKit: `Tests/WASITests/WASITests.swift` (whole module), WasmKit: `Tests/WasmKitTests/AtomicParkingLotTests.swift` (whole module), swift-tools-protocols: `Sources/LanguageServerProtocolTransport/DisableSigpipe.swift` (whole module), swift-tools-protocols: `Sources/LanguageServerProtocolTransport/JSONRPCConnection.swift` (whole module).

## Copied from the packages' reports

Verbatim, not rerun: each package's own test totals (at the start, and the latest it reports), and the rows behind the re-export column. Line numbers are 1-based, in the file at the package's commit above.

**WasmKit**

- No MIGRATION.md or REPORT.md with test totals at this commit.

**indexstore-db**

- MIGRATION.md, tests (lines 50, 51, 52, 53, 54, 55):

  ```text
  - XCTest: 48 tests; the same 5 fail before and after (`IndexTests.testBasic`, `testEditsSimple`,
    `testProperties`, `testSwiftModules`, `testWaitUntilDoneInitializing`: missing or unexpected
    symbol occurrences).
  - Swift Testing: 14 tests in 2 suites; the same 3 fail before and after (`recordDescription`,
    `swiftUnitDescription`, `swiftFileWithSingleSymbol`). For example, the Swift 6.2 compiler doesn't
    record the access-control symbol property (`swiftAccessControlInternal`) that main's tests expect.
  ```

**swift-argument-parser**

- MIGRATION.md, tests (lines 84, 86, 87):

  ```text
  | | Swift Testing | XCTest |
  | Before (unmodified clone) | 572 tests in 57 suites, all passed | 0 |
  | After | 572 tests in 57 suites, all passed | 0 |
  ```

- MIGRATION.md, re-exports (lines 10, 13):

  ```text
  | | At start | Now |
  | Darwin reached through a re-export | 1 (`Utilities/Mutex.swift`: `internal import os`, for `os_unfair_lock`, which the macOS 26 SDK puts in `Darwin.os.lock`) | 0 |
  ```

**swift-async-algorithms**

- MIGRATION.md, tests (lines 79, 81, 82):

  ```text
  | | XCTest | Swift Testing |
  | Before (unmodified clone) | 358 tests, 0 failures | 0 |
  | After | 358 tests, 0 failures | 0 |
  ```

- MIGRATION.md, re-exports (lines 12, 15):

  ```text
  | | At start | Now |
  | Darwin names reached through Foundation's or XCTest's re-export | 1: `Performance/ThroughputMeasurement.swift` (`usleep`, `USEC_PER_SEC`) | 0 |
  ```

**swift-certificates**

- MIGRATION.md, tests (lines 94, 96, 97):

  ```text
  | | XCTest | Swift Testing |
  | Before (unmodified clone) | 580 tests, 0 failures | 4 tests in 1 suite, all passed |
  | After | 580 tests, 0 failures | 4 tests in 1 suite, all passed |
  ```

- MIGRATION.md, re-exports (lines 12, 15):

  ```text
  | | At start | Now |
  | Darwin names reached through Foundation's or XCTest's re-export | 3: `X509/Verifier/ServerIdentityPolicy.swift` (`in_addr`, `in6_addr`, `inet_pton`, `AF_INET*`, `memcmp`); `X509Tests/IPAddressTests.swift` (`in_addr`, `in6_addr`, `inet_pton`, `AF_INET*`); `X509Tests/TimeTests.swift` (`gmtime_r`, `tm`, `time_t`) | 0 |
  ```

**swift-driver**

- MIGRATION.md, tests (lines 67, 68, 69, 70):

  ```text
  - XCTest: 3 tests (performance), passing before and after.
  - Swift Testing: 471 tests in 40 suites, with 18 issues (17 known) before and after. The one failure
    is the same both times: `MiscDriverTests.verifyEmittedInterfaceJob` (2 planned jobs, 3
    expected).
  ```

**swift-foundation**

- MIGRATION.md, tests (lines 108, 110, 128):

  ```text
  | Step | Result |
  | Baseline | 1701 tests in 128 suites passed (34 skipped) |
  | fts (subpaths on DirectoryWalk) | 1701 tests in 128 suites passed |
  ```

- MIGRATION.md, re-exports (lines 55, 57, 74):

  ```text
  | | FoundationEssentials: whole module | scoped only (SYSTEM-GAP) | through a re-export | FoundationInternationalization | Tests |
  | At start (`21c6d01f`) | 25 | 0 | 7 | 1 | 8 |
  | After fts (subpaths on DirectoryWalk) | 0 | 10 | 1 | 0 | 0 (4 scoped only) |
  ```

- REPORT.md, tests (lines 14, 172):

  ```text
  - `migrate-darwin` baseline: builds with tests; 1701 tests in 128 suites pass, 34 skipped, 0 failed.
  - Tests: 1701 tests in 128 suites pass after every step.
  ```

**swift-log**

- MIGRATION.md, tests (lines 88, 90, 91):

  ```text
  | | Swift Testing | XCTest |
  | Before (unmodified clone) | 170 tests in 16 suites, all passed | 0 |
  | After | 170 tests in 16 suites, all passed | 0 |
  ```

- MIGRATION.md, re-exports (lines 12, 15):

  ```text
  | | At start | Now |
  | Darwin names reached through Foundation's re-export | 1: `LoggingTests/TestLogger.swift` (`pthread_mach_thread_np`, `pthread_self`) | 0 |
  ```

**swift-nio**

- MIGRATION.md, tests (lines 30, 38):

  ```text
  | | Start (`feaf4ac5`) | First round (`1bc83af0`) | Now |
  | `swift test` | 2454 run, 43 skipped, 0 failed; swift-testing 303 passed | 2439 run, 43 skipped, 0 failed; 303 passed | 2432 run, 43 skipped, 0 failed; 303 passed |
  ```

- REPORT.md, tests (lines 58, 59):

  ```text
  43 skipped, 0 failed; swift-testing 303 passed. MIGRATION.md's result says so. `CInterop.Linger`
  and `CInterop.TimeVal` still weren't in `../swift-system` (`ebc1231`).
  ```

**swift-package-manager**

- MIGRATION.md, tests (lines 86, 87, 88, 89, 90, 91, 92, 93):

  ```text
  - Swift Testing: 1711 tests in 225 suites. Before: 318 tests failed, with 540 issues (26 known).
    After: 318 tests failed, with 563 issues (26 known). Nearly all failures, before and after, are
    the `.swiftbuild` cases, which can't start here: "Could not initialize build system: platform
    'linux' ... already registered from .../Linux.platform" (this Xcode's Linux platform).
  - The differences: 3 tests failed only after (`commandPluginPermissions`,
    `XCBuildTests.testExecutableProducts`, `testLibraryProductsAndTargets`), and 6 had extra issues
    (`initPackageLibraryWithXCTestOnly`, `movedBinaryResources`, `packageResolved`, `toolsVersion`,
    `transitiveDependency`, `testBuildToolWithoutOutputs`). The disk filled up during that run
  ```

**swift-subprocess**

- MIGRATION.md, tests (lines 27, 28, 29):

  ```text
  - Baseline (unmodified `main`, same flags): builds; 171 tests in 7 suites pass (161 passed, 11 skipped by design:
    root-only, linter, unsafe-close tests).
  - Now (after every step below): the same, 171 tests in 7 suites, 161 passed, 11 skipped, 0 failed.
  ```

- REPORT.md, tests (lines 25, 26):

  ```text
  **Tests.** 171 tests in 7 suites after every step: 161 passed, 11 skipped (root-only, linter, unsafe-close, as at
  baseline), 0 failed. Two more full runs after the last commit gave the same result.
  ```

**swift-syntax**

- MIGRATION.md, tests (lines 206, 208, 209):

  ```text
  | | XCTest | Swift Testing |
  | Before (unmodified clone) | 3512 tests, 0 failures | 2 tests in 1 suite passed, 1 known issue |
  | After | 3512 tests, 0 failures | 2 tests in 1 suite passed, 1 known issue |
  ```

- MIGRATION.md, re-exports (lines 14, 17, 18):

  ```text
  | | At start | Now |
  | Darwin reached through `_SwiftSyntaxCShims`' re-export | 3: `SwiftCompilerPluginMessageHandling/StandardIOMessageConnection.swift` (`dup`, `dup2`, `close`, `fileno`, `read`, `write`, `strerror_r`), `CompilerPluginMessageHandler.swift` (`fputs`, `exit`), `JSON/JSONDecoding.swift` (`strtod`, `strtof`, `memcmp`) | 0 |
  | Darwin reached through Foundation's or XCTest's re-export | 0 | 0 |
  ```

**swift-tools-protocols**

- No MIGRATION.md or REPORT.md with test totals at this commit.

**swift-tools-support-core**

- MIGRATION.md, re-exports (lines 14, 17):

  ```text
  | | Library | Tests |
  | `import TSCLibc`, which re-exported `Darwin.C` | 14 (one, `misc.swift`, also had scoped `import func TSCLibc.strerror_r`, `import var TSCLibc.EINVAL`, `ERANGE`) | 5 |
  ```

# 3. Gaps

Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: 62 markers in 41 files, of which 0 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `be36a44c`:

- **missing**: System documents none of it (or only some: *k of n*).
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **unread**: the marker names no C interface and nothing is imported under it; read the marker.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 54 missing, 41 covered, 1 unread, 96 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | C stdio FILE streams | covered (all 11 names) | 4 | swift-package-manager, swift-tools-support-core | C stdio FILE streams |
| 2 | `linger` | covered (doc comment) | 3 | swift-nio | socket options |
| 3 | `PATH_MAX` | covered (doc comment) | 3 | swift-foundation | compile-time limits |
| 4 | `POSIXErrorCode` | covered (doc comment) | 3 | swift-foundation | POSIXErrorCode |
| 5 | `stdout` | covered (doc comment) | 2 | swift-log, swift-nio | C stdio streams |
| 6 | `FTS_D` | missing | 2 | swift-foundation | fts |
| 7 | `FTS_DP` | missing | 2 | swift-foundation | fts |
| 8 | `fts_info` | missing | 2 | swift-foundation | fts |
| 9 | `fts_path` | missing | 2 | swift-foundation | fts |
| 10 | `FTSENT` | missing | 2 | swift-foundation | fts |
| 11 | `memcmp` | covered (doc comment) | 2 | swift-syntax | string.h |
| 12 | `NAME_MAX` | covered (doc comment) | 2 | swift-foundation | compile-time limits |
| 13 | posix_spawn's raw attributes and file actions | missing (12 of 18 names covered) | 2 | swift-subprocess | posix_spawn |
| 14 | `pow` | missing | 2 | swift-foundation | libm (provisional) |
| 15 | `TZDIR` | missing | 2 | swift-foundation | tzfile.h |
| 16 | `UTIME_NOW` | covered (doc comment) | 2 | swift-nio | file times |
| 17 | `UTIME_OMIT` | missing | 2 | swift-nio | file times |
| 18 | `XATTR_MAXNAMELEN` | missing | 2 | swift-nio | extended attributes |
| 19 | `cos` | missing | 1 | swift-foundation | libm (provisional) |
| 20 | `dirent` | covered (doc comment) | 1 | swift-tools-support-core | dirent |
| 21 | `dlerror` | missing | 1 | swift-tools-support-core | dynamic loader |
| 22 | `EX_USAGE` | covered (doc comment) | 1 | swift-argument-parser | sysexits |
| 23 | `fdopen` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 24 | `fflush` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 25 | `FILE` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 26 | `flockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 27 | `FTS` | missing | 1 | swift-foundation | fts |
| 28 | `fts_close` | missing | 1 | swift-foundation | fts |
| 29 | `FTS_DEFAULT` | missing | 1 | swift-foundation | fts |
| 30 | `fts_dev` | missing | 1 | swift-foundation | fts |
| 31 | `FTS_DNR` | missing | 1 | swift-foundation | fts |
| 32 | `FTS_ERR` | missing | 1 | swift-foundation | fts |
| 33 | `fts_errno` | missing | 1 | swift-foundation | fts |
| 34 | `FTS_F` | missing | 1 | swift-foundation | fts |
| 35 | `fts_ino` | missing | 1 | swift-foundation | fts |
| 36 | `fts_level` | missing | 1 | swift-foundation | fts |
| 37 | `fts_name` | missing | 1 | swift-foundation | fts |
| 38 | `fts_namelen` | missing | 1 | swift-foundation | fts |
| 39 | `FTS_NOCHDIR` | missing | 1 | swift-foundation | fts |
| 40 | `FTS_NS` | missing | 1 | swift-foundation | fts |
| 41 | `fts_open` | missing | 1 | swift-foundation | fts |
| 42 | `FTS_PHYSICAL` | missing | 1 | swift-foundation | fts |
| 43 | `fts_read` | missing | 1 | swift-foundation | fts |
| 44 | `fts_set` | missing | 1 | swift-foundation | fts |
| 45 | `FTS_SKIP` | missing | 1 | swift-foundation | fts |
| 46 | `FTS_SL` | missing | 1 | swift-foundation | fts |
| 47 | `FTS_SLNONE` | missing | 1 | swift-foundation | fts |
| 48 | `funlockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 49 | `fwrite` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 50 | gettimeofday before macOS 13 | missing (1 of 2 names covered) | 1 | swift-driver | gettimeofday before macOS 13 |
| 51 | `gmtime_r` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 52 | `LC_ALL` | missing | 1 | swift-foundation | locale (provisional) |
| 53 | `locale_t` | missing | 1 | swift-foundation | locale (provisional) |
| 54 | `localtime` | covered (as `localtime_r`) | 1 | swift-log | calendar time |
| 55 | `log` | missing | 1 | swift-foundation | libm (provisional) |
| 56 | `malloc_type_calloc` | missing | 1 | swift-foundation | libmalloc |
| 57 | `malloc_type_descriptor_v0_t` | missing | 1 | swift-foundation | libmalloc |
| 58 | `malloc_type_descriptor_v0_t members` | missing | 1 | swift-foundation | C struct members (MemberImportVisibility) |
| 59 | `malloc_type_malloc` | missing | 1 | swift-foundation | libmalloc |
| 60 | `malloc_type_realloc` | missing | 1 | swift-foundation | libmalloc |
| 61 | `MAXSYMLINKS` | covered (doc comment) | 1 | swift-foundation | compile-time limits |
| 62 | `mkstemps` | missing | 1 | swift-tools-support-core | mkstemps |
| 63 | `mktemp` | missing | 1 | swift-foundation | temporary files |
| 64 | `O_SEARCH` | covered (doc comment) | 1 | swift-foundation | O_SEARCH |
| 65 | raw posix_spawn path | unread | 1 | swift-subprocess | raw posix_spawn path |
| 66 | `readpassphrase` | missing | 1 | swift-package-manager | readpassphrase |
| 67 | `removefile` | covered (doc comment) | 1 | swift-foundation | removefile |
| 68 | `removefile_flags_t` | covered (doc comment) | 1 | swift-foundation | removefile |
| 69 | `REMOVEFILE_PROCEED` | covered (doc comment) | 1 | swift-foundation | removefile |
| 70 | `REMOVEFILE_RECURSIVE` | covered (doc comment) | 1 | swift-foundation | removefile |
| 71 | `REMOVEFILE_SKIP` | covered (doc comment) | 1 | swift-foundation | removefile |
| 72 | `removefile_state_alloc` | covered (doc comment) | 1 | swift-foundation | removefile |
| 73 | `REMOVEFILE_STATE_CONFIRM_CALLBACK` | covered (doc comment) | 1 | swift-foundation | removefile |
| 74 | `REMOVEFILE_STATE_CONFIRM_CONTEXT` | covered (doc comment) | 1 | swift-foundation | removefile |
| 75 | `REMOVEFILE_STATE_ERRNO` | covered (doc comment) | 1 | swift-foundation | removefile |
| 76 | `REMOVEFILE_STATE_ERROR_CALLBACK` | covered (doc comment) | 1 | swift-foundation | removefile |
| 77 | `REMOVEFILE_STATE_ERROR_CONTEXT` | covered (doc comment) | 1 | swift-foundation | removefile |
| 78 | `removefile_state_free` | covered (doc comment) | 1 | swift-foundation | removefile |
| 79 | `removefile_state_get` | covered (doc comment) | 1 | swift-foundation | removefile |
| 80 | `removefile_state_set` | covered (doc comment) | 1 | swift-foundation | removefile |
| 81 | `removefile_state_t` | covered (doc comment) | 1 | swift-foundation | removefile |
| 82 | `REMOVEFILE_STOP` | covered (doc comment) | 1 | swift-foundation | removefile |
| 83 | `setbuf` | missing | 1 | swift-nio | C stdio (provisional) |
| 84 | `setlocale` | missing | 1 | swift-foundation | locale (provisional) |
| 85 | `setvbuf` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 86 | `sin` | missing | 1 | swift-foundation | libm (provisional) |
| 87 | `strftime` | covered (doc comment) | 1 | swift-log | calendar time |
| 88 | `strncasecmp_l` | missing | 1 | swift-foundation | locale (provisional) |
| 89 | `strsignal` | missing | 1 | swift-driver | string.h and ctype.h (provisional) |
| 90 | `strtod_l` | missing | 1 | swift-foundation | locale (provisional) |
| 91 | `strtof_l` | missing | 1 | swift-foundation | locale (provisional) |
| 92 | `time` | covered (as `clock_gettime`) | 1 | swift-log | calendar time |
| 93 | `time_t` | missing | 1 | swift-certificates | calendar time |
| 94 | `timeval` | covered (doc comment) | 1 | swift-nio | socket options |
| 95 | `tm` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 96 | `TZDEFAULT` | missing | 1 | swift-foundation | tzfile.h |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|
| 1 | extended attributes | 2 | swift-nio | `XATTR_MAXNAMELEN` |
| 2 | file times | 2 | swift-nio | `UTIME_OMIT` |
| 3 | fts | 2 | swift-foundation | `FTS_D`, `FTS_DP`, `fts_info`, `fts_path`, `FTSENT`, `FTS`, `fts_close`, `FTS_DEFAULT`, `fts_dev`, `FTS_DNR`, `FTS_ERR`, `fts_errno`, `FTS_F`, `fts_ino`, `fts_level`, `fts_name`, `fts_namelen`, `FTS_NOCHDIR`, `FTS_NS`, `fts_open`, `FTS_PHYSICAL`, `fts_read`, `fts_set`, `FTS_SKIP`, `FTS_SL`, `FTS_SLNONE` |
| 4 | libm (provisional) | 2 | swift-foundation | `pow`, `cos`, `log`, `sin` |
| 5 | locale (provisional) | 2 | swift-foundation | `LC_ALL`, `locale_t`, `setlocale`, `strncasecmp_l`, `strtod_l`, `strtof_l` |
| 6 | posix_spawn | 2 | swift-subprocess | posix_spawn's raw attributes and file actions |
| 7 | tzfile.h | 2 | swift-foundation | `TZDIR`, `TZDEFAULT` |
| 8 | C stdio (provisional) | 1 | swift-nio | `setbuf` |
| 9 | C struct members (MemberImportVisibility) | 1 | swift-foundation | `malloc_type_descriptor_v0_t members` |
| 10 | calendar time | 1 | swift-certificates | `time_t` |
| 11 | dynamic loader | 1 | swift-tools-support-core | `dlerror` |
| 12 | gettimeofday before macOS 13 | 1 | swift-driver | gettimeofday before macOS 13 |
| 13 | libmalloc | 1 | swift-foundation | `malloc_type_calloc`, `malloc_type_descriptor_v0_t`, `malloc_type_malloc`, `malloc_type_realloc` |
| 14 | mkstemps | 1 | swift-tools-support-core | `mkstemps` |
| 15 | readpassphrase | 1 | swift-package-manager | `readpassphrase` |
| 16 | string.h and ctype.h (provisional) | 1 | swift-driver | `strsignal` |
| 17 | temporary files | 1 | swift-foundation | `mktemp` |

## Markers that name no C interface

- swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`: the raw posix_spawn path, for what System's spawn

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- C stdio FILE streams (covered): swift-package-manager: `Sources/Basics/Concurrency/AsyncProcess.swift:25`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:47`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:48`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:49`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:15`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:16`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:17`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:18`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:19`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:20`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:21`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:22`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:23`; swift-tools-support-core: `Sources/TSCTestSupport/PseudoTerminal.swift:15`
- `linger` (covered): swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:18`; swift-nio: `Tests/NIOPosixTests/SocketChannelTest.swift:25`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:28`
- `PATH_MAX` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:30`; swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:34`; swift-foundation: `Tests/FoundationEssentialsTests/StringTests.swift:17`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:20`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:20`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:21`; swift-foundation: `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift:30`
- `stdout` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`; swift-nio: `Sources/NIOPerformanceTester/main.swift:42`
- `FTS_D` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_DP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_info` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_path` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTSENT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `memcmp` (covered): swift-syntax: `Sources/SwiftCompilerPluginMessageHandling/JSON/JSONDecoding.swift:16`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:15`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:27`
- `NAME_MAX` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:30`; swift-foundation: `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift:28`
- posix_spawn's raw attributes and file actions (missing): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:14`; swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `pow` (missing): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`; swift-foundation: `Tests/FoundationInternationalizationTests/Formatting/DiscreteFormatStyleTestUtilities.swift:23`
- `TZDIR` (missing): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone.swift:405`; swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:36`
- `UTIME_NOW` (covered): swift-nio: `Sources/NIOFS/FileInfo.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:18`
- `UTIME_OMIT` (missing): swift-nio: `Sources/NIOFS/FileInfo.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:18`
- `XATTR_MAXNAMELEN` (missing): swift-nio: `Sources/NIOFS/FileSystemError+Syscall.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileSystemError+Syscall.swift:18`
- `cos` (missing): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`
- `dirent` (covered): swift-tools-support-core: `Sources/TSCBasic/FileSystem.swift:18`
- `dlerror` (missing): swift-tools-support-core: `Sources/TSCUtility/dlopen.swift:18`
- `EX_USAGE` (covered): swift-argument-parser: `Sources/ArgumentParser/Utilities/Platform.swift:25`
- `fdopen` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fflush` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FILE` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `flockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FTS` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_close` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_DEFAULT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_dev` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_DNR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_ERR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_errno` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_F` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_ino` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_level` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_name` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_namelen` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_NOCHDIR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_NS` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_open` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_PHYSICAL` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_read` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_set` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_SKIP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_SL` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_SLNONE` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `funlockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fwrite` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- gettimeofday before macOS 13 (missing): swift-driver: `Sources/SwiftDriver/Utilities/DateAdditions.swift:20`; swift-driver: `Sources/SwiftDriver/Utilities/DateAdditions.swift:21`
- `gmtime_r` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `LC_ALL` (missing): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `locale_t` (missing): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `localtime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `log` (missing): swift-foundation: `Tests/FoundationInternationalizationTests/Formatting/DiscreteFormatStyleTestUtilities.swift:23`
- `malloc_type_calloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_descriptor_v0_t` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_descriptor_v0_t members` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_malloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_realloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `MAXSYMLINKS` (covered): swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:17`
- `mkstemps` (missing): swift-tools-support-core: `Sources/TSCBasic/TemporaryFile.swift:15`
- `mktemp` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:28`
- `O_SEARCH` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:26`
- raw posix_spawn path (unread): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`
- `readpassphrase` (missing): swift-package-manager: `Sources/PackageRegistryCommand/PackageRegistryCommand+Auth.swift:27`
- `removefile` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_flags_t` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_PROCEED` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_RECURSIVE` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_SKIP` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_alloc` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_CONFIRM_CALLBACK` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_CONFIRM_CONTEXT` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERRNO` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERROR_CALLBACK` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERROR_CONTEXT` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_free` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_get` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_set` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_t` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STOP` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `setbuf` (missing): swift-nio: `Sources/NIOPerformanceTester/main.swift:42`
- `setlocale` (missing): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `setvbuf` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `sin` (missing): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`
- `strftime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `strncasecmp_l` (missing): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strsignal` (missing): swift-driver: `Sources/SwiftDriver/Driver/ToolExecutionDelegate.swift:17`
- `strtod_l` (missing): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strtof_l` (missing): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `time` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `time_t` (missing): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `timeval` (covered): swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:28`
- `tm` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `TZDEFAULT` (missing): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:36`

</details>

# How this is computed

`Utilities/adopter-coverage/status.sh` makes this file from commits, with git and the existing tools, and no
reading of reports for meaning. It takes about as long as api-delta when System's sources have changed since
api-delta's last run, and a few seconds when they haven't.

- **API** is api-delta's own report (`BASE_REF=main HEAD_REF=HEAD`), its Summary and *By area* table copied
  verbatim. api-delta reruns only when `Sources/`, `Package.swift` or the tool changed since its last run.
- **Package targets** come from `swift package dump-package` on the package's manifests at each commit, cached
  by the manifests' blob ids, with SwiftPM's default paths (`Sources/<target>`, `Tests/<target>`) where a
  target gives none, and its `sources` and `exclude`. A manifest that doesn't evaluate falls back to
  `Sources/` and `Tests/`, and the Adoption section says so. Rejected: counting every file in the repository,
  which mixes in nested packages (Benchmarks, SwiftParserCLI) and scaffolding the package doesn't build.
- **Darwin imports** are read from each file with comments and strings blanked (api-delta's blanker), and
  each `#if` evaluated for macOS by adopter-coverage's `platforms.py`, with FOUNDATION_FRAMEWORK false for the
  package's counts and true for the *framework only* count. An unknown flag counts as maybe, so a line it
  guards is counted. `import Darwin.POSIX.sys.stat` counts as whole: a submodule import isn't scoped to one
  declaration. Rejected: adopter-coverage's compiler-backed Darwin metric (`check.sh`), which needs a build
  of every package commit (a minute or more each, and only for the four audited packages), where this needs
  only git.
- **Copied figures** (test totals, files reaching Darwin through a re-export) are lines of the package's
  MIGRATION.md or REPORT.md at its commit, quoted with their line numbers: the table rows or bullets with a
  test count that are labeled as the start and as the latest, and the rows labeled as reaching Darwin through
  a re-export in a start/now table (or a column so labeled). A package whose reports don't match these
  patterns shows —, never a guess.
- **Markers** are `SYSTEM-GAP:` in a comment of a Swift or C source. Its text continues onto the next comment
  lines while a parenthesis is open or it ends mid-list. Its head is the text before the first sentence
  end, semicolon or dash, and before a colon unless a list follows the colon (`vsock: sockaddr_vm, AF_VSOCK`).
  The head is split into items at commas and *and*/*or*, and an item names:
  - itself, when it's one identifier (`getenv(3)`, `O_SEARCH`, `struct ifaddrs`), plus the names in an
    attached or following list (`confstr(_CS_DARWIN_USER_TEMP_DIR)`, `strftime (tm, time_t)`), except after
    a Swift type (`POSIXErrorCode (ENAMETOOLONG)` names POSIXErrorCode);
  - the names in its parenthesized list, for a phrase (`libm (sin, cos, pow)`, `the C heap (calloc,
    malloc, free)`); the phrase becomes their family;
  - `X members`, for `members of X`, `X members`, `X fields`, `X's field`, and every name in a *members of
    System-vended C structs* list: what's missing is the struct's fields, not its name, which CInterop has;
  - the name before generic nouns (`IPV6_* socket options`, `copyfile(3) flags`) or after a header
    (`string.h memcmp`), and the possessed name after a library (`libmalloc's malloc_good_size`).
  A marker can also trail the import it's for (`import func Darwin.fopen  // SYSTEM-GAP: C stdio`).
  A wildcard (`IP_*`, `DT_*`) becomes the names imported under the marker that match it. A marker whose head
  names nothing (`posix_spawn's raw attributes and file actions`) is counted under its phrase, and the scoped
  Darwin imports right under it (the file's own list of what the gap costs) decide its status; with none, it
  is *unread*. Rejected: recognizing names by an SDK vocabulary alone, since the explanations are English
  and `time`, `free`, `sleep` and `remove` are C functions; and taking the imports as the interfaces
  everywhere, since `import struct Darwin.msghdr` is there for msghdr's fields, not for the name CInterop
  already has.
- **Covered** means System's library modules (`Sources/System`, `Sources/SystemSockets`, not the samples) name
  the interface in a doc comment's *The corresponding C … is* sentence, or a public typealias targets it, or,
  for `X members`, an `extension CInterop.<alias of X>` exists. A few interfaces count as covered by the
  replacement System wraps instead (`EQUIVALENTS` in `scripts/status.py`: usleep and sleep by nanosleep,
  localtime and gmtime by their `_r` forms, mkstemp by mkostemp, time by clock_gettime), and the table says
  so. This sees what System documents, not whether the API fits the adopter's use: a partial wrapper counts
  as covered, and an API whose doc comments don't name the C interface (a `nil` that means `UTIME_OMIT`)
  counts as missing.
- **Provisional families** (libm, C stdio, locale and xlocale, string.h and ctype.h, numeric conversion) are a
  fixed list in `scripts/status.py`, matched by name or by the name's SDK module in adopter-coverage's stored
  vocabulary when there is one. They're C-library layers above the OS that System wraps provisionally, in
  `Sources/System/Provisional/`, and they count as missing until covered, like everything else; the family
  only groups them in the work list.
- **Families** group the ranked interfaces for the work list: the provisional families, then a fixed map of
  name patterns to System's clusters, else the marker's phrase, else the name itself.
