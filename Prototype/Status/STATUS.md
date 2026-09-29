# Status: System's API and its adopters

Generated 2026-09-29 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage` @ `f29fa086` (Add CString (strlen, strnlen, strdup, strndup, strcmp, strncmp, strlcpy) and CType (ctype.h's classes, tolower, toupper), provisionally), which doesn't contain `system-next` @ `3d1e67d7` (Merge branch 'coverage' into system-next); 4 commit(s) of `coverage` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `f29fa086`.
- **Adopters** (`../adopters`, branch `migrate-darwin`, against its merge base with `main`):
  - WasmKit @ `f5219fbf`, base `1e9c513d`
  - indexstore-db @ `cc966b89`, base `441ead77`
  - swift-argument-parser @ `0fbda276`, base `1021ac8c`
  - swift-async-algorithms @ `bd5f6f44`, base `789dcf1f`
  - swift-certificates @ `0df6bd14`, base `ff86b924`
  - swift-driver @ `33d2c7b5`, base `15cf6766`
  - swift-foundation @ `423070e7`, base `6669273a` (uncommitted changes in the checkout aren't counted)
  - swift-log @ `4d6d77fe`, base `9c9acde6`
  - swift-nio @ `e1623fbf`, base `feaf4ac5`
  - swift-package-manager @ `f7a4a9e1`, base `24a8a7b0`
  - swift-subprocess @ `1dc7dbb8`, base `8f099c6e`
  - swift-syntax @ `961f0b72`, base `e9289aa4`
  - swift-tools-protocols @ `9422bf90`, base `07d2884f`
  - swift-tools-support-core @ `530d4e50`, base `c574915f` (uncommitted changes in the checkout aren't counted)

# 1. API

Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF=main`, `HEAD_REF=HEAD`); its links point into that run's API-DELTA.md.

## Summary

- **3080 added, 0 removed, 0 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2504 (448 → 2952 public symbols).
  - SystemSockets: +576 (0 → 576 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 3045
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 1
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 410 compiled only on other platforms;
  - 237 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 27 added, removed or changed graph symbols the scan didn't find (enum case: 26, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2804 / -0 declarations, which is the graphs' +2504 plus 300 implicit ones; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +648 / -0 declarations, which is the graphs' +576 plus 71 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- Nothing was removed or changed: no public declaration left the graphs or the source scan. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 43 | 0 | 0 | S199 ×43 |
| SystemPackage | [`CLocale`](#systempackage-clocale) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`CString`](#systempackage-cstring) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`CType`](#systempackage-ctype) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`ChildProcess`](#systempackage-childprocess) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`ClockID`](#systempackage-clockid) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`ControlCharacter`](#systempackage-controlcharacter) | 21 | 0 | 0 | S199 ×21 |
| SystemPackage | [`ControlCharacters`](#systempackage-controlcharacters) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ControlFlags`](#systempackage-controlflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`DirectoryStream`](#systempackage-directorystream) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`DirectoryWalk`](#systempackage-directorywalk) | 18 | 0 | 0 | S199 ×18 |
| SystemPackage | [`DiskQuota`](#systempackage-diskquota) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`DynamicLibrary`](#systempackage-dynamiclibrary) | 24 | 0 | 0 | S199 ×24 |
| SystemPackage | [`Entropy`](#systempackage-entropy) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`Errno`](#systempackage-errno) | 4 | 0 | 0 | S199 ×3, S0.0.1 ×1 |
| SystemPackage | [`ExitStatus`](#systempackage-exitstatus) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`ExtendedAttributeOptions`](#systempackage-extendedattributeoptions) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 246 | 0 | 0 | S199 ×233, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 443 | 0 | 0 | S199 ×429, S199+OS ×14 |
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
| SystemPackage | [`Math`](#systempackage-math) | 55 | 0 | 0 | S199 ×55 |
| SystemPackage | [`Memory`](#systempackage-memory) | 91 | 0 | 0 | S199 ×91 |
| SystemPackage | [`MemoryMapping`](#systempackage-memorymapping) | 36 | 0 | 0 | S199 ×36 |
| SystemPackage | [`MountFlags`](#systempackage-mountflags) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`NamedSemaphore`](#systempackage-namedsemaphore) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`NetworkInterface`](#systempackage-networkinterface) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`OutputFlags`](#systempackage-outputflags) | 34 | 0 | 0 | S199 ×34 |
| SystemPackage | [`OwnedFD`](#systempackage-ownedfd) | 30 | 0 | 0 | S199 ×30 |
| SystemPackage | [`POSIXErrorCode (extends _DarwinFoundation1)`](#systempackage-posixerrorcode-extends-darwinfoundation1) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`PThread`](#systempackage-pthread) | 123 | 0 | 0 | S199 ×123 |
| SystemPackage | [`ProcessEnvironment`](#systempackage-processenvironment) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessID`](#systempackage-processid) | 215 | 0 | 0 | S199 ×215 |
| SystemPackage | [`ProcessPriority`](#systempackage-processpriority) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ProcessStateChange`](#systempackage-processstatechange) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessTimer`](#systempackage-processtimer) | 18 | 0 | 0 | S199 ×18 |
| SystemPackage | [`ResourceLimit`](#systempackage-resourcelimit) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`SearchPaths`](#systempackage-searchpaths) | 42 | 0 | 0 | S199 ×41, S199+OS ×1 |
| SystemPackage | [`Signal`](#systempackage-signal) | 74 | 0 | 0 | S199 ×74 |
| SystemPackage | [`SignalSet`](#systempackage-signalset) | 22 | 0 | 0 | S199 ×22 |
| SystemPackage | [`SpawnAttributes`](#systempackage-spawnattributes) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`SpawnCredentials`](#systempackage-spawncredentials) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`SpawnFileAction`](#systempackage-spawnfileaction) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`StatFS`](#systempackage-statfs) | 27 | 0 | 0 | S199 ×27 |
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 71 | 0 | 0 | S199 ×71 |
| SystemPackage | [`SystemControl`](#systempackage-systemcontrol) | 72 | 0 | 0 | S199 ×72 |
| SystemPackage | [`SystemIdentity`](#systempackage-systemidentity) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`TerminalAttributes`](#systempackage-terminalattributes) | 44 | 0 | 0 | S199 ×44 |
| SystemPackage | [`TerminalDescriptor`](#systempackage-terminaldescriptor) | 52 | 0 | 0 | S199 ×52 |
| SystemPackage | [`UnfairLock`](#systempackage-unfairlock) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`UserEntry`](#systempackage-userentry) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`UserID`](#systempackage-userid) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`iovec (extends Darwin)`](#systempackage-iovec-extends-darwin) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`kevent (extends Darwin)`](#systempackage-kevent-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`stat (extends Darwin)`](#systempackage-stat-extends-darwin) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`timespec (extends _DarwinFoundation2)`](#systempackage-timespec-extends-darwinfoundation2) | 7 | 0 | 0 | S199 ×7 |
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
| **Total** | | **3080** | **0** | **0** | |

# 2. Adoption

Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or `import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration (`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under `#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. *Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.

| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | Through a re-export (copied) | Markers (files) |
|---|---:|---:|---:|---:|---:|---:|---:|
| WasmKit | 333 | 14 → 9 | 0 | 0 → 1 | 0 | — | 0 (0) → 2 (1) |
| indexstore-db | 73 | 1 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| swift-argument-parser | 166 | 1 → 0 | 0 | 0 → 1 | 0 | 1 → 0 | 0 (0) → 1 (1) |
| swift-async-algorithms | 146 | 2 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-certificates | 133 | 2 → 0 | 0 | 0 → 1 | 0 | 3 → 0 | 0 (0) → 1 (1) |
| swift-driver | 195 | 11 → 0 | 1 → 0 | 0 → 2 | 0 | — | 0 (0) → 3 (2) |
| swift-foundation | 431 | 33 → 0 | 1 → 0 | 0 → 7 | 3 | 7 → 2 | 0 (0) → 11 (9) |
| swift-log | 30 | 5 → 0 | 0 | 0 → 2 | 0 | 1 → 0 | 0 (0) → 3 (2) |
| swift-nio | 479 | 41 → 0 | 3 → 0 | 0 | 0 | — | 0 (0) |
| swift-package-manager | 883 | 3 → 0 | 2 → 0 | 0 → 3 | 0 | — | 0 (0) → 5 (3) |
| swift-subprocess | 36 | 17 → 0 | 0 | 0 → 2 | 0 | — | 0 (0) → 3 (2) |
| swift-syntax | 586 | 2 → 0 | 0 | 0 → 2 | 0 | 3 → 0 | 0 (0) → 3 (2) |
| swift-tools-protocols | 232 | 2 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-tools-support-core | 124 | 0 | 1 → 0 | 0 → 5 | 0 | 14 → 5 | 0 (0) → 13 (5) |
| **All** | 3847 | 134 → 9 | 9 → 0 | 0 → 26 | 3 | | 0 (0) → 45 (28) |

Files whose imports aren't narrow yet: WasmKit: `Sources/CLICommands/Platform.swift` (whole module), WasmKit: `Sources/CLICommands/Run.swift` (whole module), WasmKit: `Sources/CLICommands/TCPListener.swift` (whole module), WasmKit: `Sources/WasmKit/Execution/Profiler.swift` (whole module), WasmKit: `Sources/WasmKit/Execution/StatsCollector.swift` (whole module), WasmKit: `Sources/WasmKit/Platform/AtomicParkingLot.swift` (whole module), WasmKit: `Tests/WASITests/TestSupport.swift` (whole module), WasmKit: `Tests/WASITests/WASITests.swift` (whole module), WasmKit: `Tests/WasmKitTests/AtomicParkingLotTests.swift` (whole module).

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

- MIGRATION.md, tests (lines 123, 125, 150):

  ```text
  | Step | Result |
  | Baseline | 1701 tests in 128 suites passed (34 skipped) |
  | libm (`Math`) | 1701 tests in 128 suites passed |
  ```

- MIGRATION.md, re-exports (lines 59, 61, 83):

  ```text
  | | FoundationEssentials: whole module | scoped only (SYSTEM-GAP) | through a re-export | FoundationInternationalization | Tests |
  | At start (`21c6d01f`) | 25 | 0 | 7 | 1 | 8 |
  | After libm (`Math`) | 0 | 6 | 2 | 0 | 0 (1 scoped only) |
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

- MIGRATION.md, tests (lines 31, 39):

  ```text
  | | Start (`feaf4ac5`) | First round (`1bc83af0`) | Now |
  | `swift test` | 2454 run, 43 skipped, 0 failed; swift-testing 303 passed | 2439 run, 43 skipped, 0 failed; 303 passed | 2432 run, 43 skipped, 0 failed; 303 passed |
  ```

- REPORT.md, tests (lines 70, 71):

  ```text
  and prints its banner. Its first socket benchmark then fails with EPERM from `bind` here, as it
  did in the first round.
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

Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: 45 markers in 28 files, of which 0 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `f29fa086`:

- **missing**: System documents none of it (or only some: *k of n*).
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry speaks for it; read the marker.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 69 covered, 69 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | C stdio FILE streams | covered (all 11 names) | 4 | swift-package-manager, swift-tools-support-core | C stdio FILE streams |
| 2 | `FTS_D` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 3 | `FTS_DP` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 4 | `fts_info` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 5 | `fts_path` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 6 | `FTSENT` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 7 | `memcmp` | covered (doc comment) | 2 | swift-syntax | string.h |
| 8 | posix_spawn's raw attributes and file actions | covered (all 18 names) | 2 | swift-subprocess | posix_spawn |
| 9 | `TZDIR` | covered (doc comment) | 2 | swift-foundation | tzfile.h |
| 10 | `dirent` | covered (doc comment) | 1 | swift-tools-support-core | dirent |
| 11 | `dlerror` | covered (doc comment) | 1 | swift-tools-support-core | dynamic loader |
| 12 | `EX_USAGE` | covered (doc comment) | 1 | swift-argument-parser | sysexits |
| 13 | `fdopen` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 14 | `fflush` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 15 | `FILE` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 16 | `flockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 17 | `FTS` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 18 | `fts_close` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 19 | `FTS_DEFAULT` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 20 | `fts_dev` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 21 | `FTS_DNR` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 22 | `FTS_ERR` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 23 | `fts_errno` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 24 | `FTS_F` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 25 | `fts_ino` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 26 | `fts_level` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 27 | `fts_name` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 28 | `fts_namelen` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 29 | `FTS_NOCHDIR` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 30 | `FTS_NS` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 31 | `fts_open` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 32 | `FTS_PHYSICAL` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 33 | `fts_read` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 34 | `fts_set` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 35 | `FTS_SKIP` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 36 | `FTS_SL` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 37 | `FTS_SLNONE` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 38 | `funlockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 39 | `fwrite` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 40 | gettimeofday before macOS 13 | covered (all 2 names) | 1 | swift-driver | gettimeofday before macOS 13 |
| 41 | `gmtime_r` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 42 | `LC_ALL` | covered (doc comment) | 1 | swift-foundation | LC_ALL |
| 43 | `locale_t` | covered (doc comment) | 1 | swift-foundation | xlocale |
| 44 | `localtime` | covered (as `localtime_r`) | 1 | swift-log | calendar time |
| 45 | `malloc_type_calloc` | covered (doc comment) | 1 | swift-foundation | libmalloc |
| 46 | `malloc_type_descriptor_v0_t` | covered (doc comment) | 1 | swift-foundation | libmalloc |
| 47 | `malloc_type_descriptor_v0_t members` | covered (by Memory.TypeDescriptor) | 1 | swift-foundation | C struct members (MemberImportVisibility) |
| 48 | `malloc_type_malloc` | covered (doc comment) | 1 | swift-foundation | libmalloc |
| 49 | `malloc_type_realloc` | covered (doc comment) | 1 | swift-foundation | libmalloc |
| 50 | `mkstemps` | covered (as `mkostemps`) | 1 | swift-tools-support-core | mkstemps |
| 51 | `mktemp` | covered (doc comment) | 1 | swift-foundation | temporary files |
| 52 | `O_DSYNC` | covered (doc comment) | 1 | WasmKit | O_DSYNC |
| 53 | `O_SYNC` | covered (doc comment) | 1 | WasmKit | fcntl.h |
| 54 | `POSIXErrorCode` | covered (doc comment) | 1 | swift-foundation | POSIXErrorCode |
| 55 | raw posix_spawn path | covered (by ProcessID.spawn's C-values and credentials forms) | 1 | swift-subprocess | raw posix_spawn path |
| 56 | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro | covered (doc comment) | 1 | WasmKit | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro |
| 57 | `readpassphrase` | covered (doc comment) | 1 | swift-package-manager | readpassphrase |
| 58 | `setlocale` | covered (doc comment) | 1 | swift-foundation | setlocale |
| 59 | `setvbuf` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 60 | `stdout` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 61 | `strftime` | covered (doc comment) | 1 | swift-log | calendar time |
| 62 | `strncasecmp_l` | covered (doc comment) | 1 | swift-foundation | xlocale |
| 63 | `strsignal` | covered (doc comment) | 1 | swift-driver | strsignal |
| 64 | `strtod_l` | covered (doc comment) | 1 | swift-foundation | xlocale |
| 65 | `strtof_l` | covered (doc comment) | 1 | swift-foundation | xlocale |
| 66 | `time` | covered (as `clock_gettime`) | 1 | swift-log | calendar time |
| 67 | `time_t` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 68 | `tm` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 69 | `TZDEFAULT` | covered (doc comment) | 1 | swift-foundation | tzfile.h |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|

## Markers that name no C interface

- swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`: the raw posix_spawn path, for what System's spawn

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- C stdio FILE streams (covered): swift-package-manager: `Sources/Basics/Concurrency/AsyncProcess.swift:25`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:47`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:48`; swift-package-manager: `Sources/Runtimes/PackagePlugin/Plugin.swift:49`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:15`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:16`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:17`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:18`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:19`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:20`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:21`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:22`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:23`; swift-tools-support-core: `Sources/TSCTestSupport/PseudoTerminal.swift:15`
- `FTS_D` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_DP` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_info` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_path` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTSENT` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `memcmp` (covered): swift-syntax: `Sources/SwiftCompilerPluginMessageHandling/JSON/JSONDecoding.swift:16`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:15`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:27`
- posix_spawn's raw attributes and file actions (covered): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:14`; swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `TZDIR` (covered): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone.swift:405`; swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:34`
- `dirent` (covered): swift-tools-support-core: `Sources/TSCBasic/FileSystem.swift:18`
- `dlerror` (covered): swift-tools-support-core: `Sources/TSCUtility/dlopen.swift:18`
- `EX_USAGE` (covered): swift-argument-parser: `Sources/ArgumentParser/Utilities/Platform.swift:25`
- `fdopen` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fflush` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FILE` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `flockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FTS` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_close` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_DEFAULT` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_dev` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_DNR` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_ERR` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_errno` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_F` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_ino` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_level` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_name` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_namelen` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_NOCHDIR` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_NS` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_open` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_PHYSICAL` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_read` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `fts_set` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_SKIP` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:120`
- `FTS_SL` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_SLNONE` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `funlockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fwrite` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- gettimeofday before macOS 13 (covered): swift-driver: `Sources/SwiftDriver/Utilities/DateAdditions.swift:20`; swift-driver: `Sources/SwiftDriver/Utilities/DateAdditions.swift:21`
- `gmtime_r` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `LC_ALL` (covered): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `locale_t` (covered): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `localtime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `malloc_type_calloc` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_descriptor_v0_t` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_descriptor_v0_t members` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_malloc` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_realloc` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `mkstemps` (covered): swift-tools-support-core: `Sources/TSCBasic/TemporaryFile.swift:15`
- `mktemp` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:26`
- `O_DSYNC` (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:7`
- `O_SYNC` (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:7`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:20`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:21`
- raw posix_spawn path (covered): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`
- readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:10`
- `readpassphrase` (covered): swift-package-manager: `Sources/PackageRegistryCommand/PackageRegistryCommand+Auth.swift:27`
- `setlocale` (covered): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `setvbuf` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `stdout` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `strftime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `strncasecmp_l` (covered): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strsignal` (covered): swift-driver: `Sources/SwiftDriver/Driver/ToolExecutionDelegate.swift:17`
- `strtod_l` (covered): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strtof_l` (covered): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `time` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `time_t` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `tm` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `TZDEFAULT` (covered): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:34`

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
  is *unread*, unless an `ANSWERED` entry matches its phrase. Rejected: recognizing names by an SDK vocabulary alone, since the explanations are English
  and `time`, `free`, `sleep` and `remove` are C functions; and taking the imports as the interfaces
  everywhere, since `import struct Darwin.msghdr` is there for msghdr's fields, not for the name CInterop
  already has.
- **Covered** means System's library modules (`Sources/System`, `Sources/SystemSockets`, not the samples) name
  the interface in a doc comment's *The corresponding C … is* sentence, or a public typealias targets it, or, for
  `X members`, an `extension CInterop.<alias of X>` exists. A few interfaces count as covered by the replacement
  System wraps instead (`EQUIVALENTS` in `scripts/status.py`: usleep and sleep by nanosleep, localtime and gmtime
  by their `_r` forms, mkstemp and mkstemps by mkostemp(s), time and gettimeofday by clock_gettime), and the table
  says so. A family that System answers with a design of its own, rather than a wrapper, counts as covered once a
  witness in System's sources shows the answer has what the markers ask for (`ANSWERED`: fts is DirectoryWalk, with
  its two-visit order, `malloc_type_descriptor_v0_t`'s members are `Memory.TypeDescriptor`'s properties, and
  Subprocess's raw posix_spawn path, a marker that names no C interface, is `ProcessID.spawn`'s C-values and
  credentials forms). This sees what System documents, not whether the API fits the adopter's use: a partial
  wrapper counts as covered, and an API whose doc comments don't name the C interface counts as missing.
- **Provisional families** (libm, C stdio, locale and xlocale, string.h and ctype.h, numeric conversion) are a
  fixed list in `scripts/status.py`, matched by name or by the name's SDK module in adopter-coverage's stored
  vocabulary when there is one. They're C-library layers above the OS that System wraps provisionally, in
  `Sources/System/Provisional/`, and they count as missing until covered, like everything else; the family
  only groups them in the work list.
- **Families** group the ranked interfaces for the work list: the provisional families, then a fixed map of
  name patterns to System's clusters, else the marker's phrase, else the name itself.
