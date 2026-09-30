# Status: System's API and its adopters

Generated 2026-09-30 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage-3` @ `cddd4d20` (status.sh: section 4, the toolchain repositories' platform imports; swift-foundation on no-darwin), which contains `system-next` @ `6a9833fd` (Merge branch 'coverage-2' into system-next); 9 commit(s) of `coverage-3` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `cddd4d20`.
- **Adopters** (`../adopters`, branch `migrate-darwin`, against its merge base with `main`):
  - WasmKit @ `4917e060`, base `1e9c513d`
  - indexstore-db @ `cc966b89`, base `441ead77`
  - sourcekit-lsp @ `cb2881c5`, base `045c18e9`
  - swift-argument-parser @ `0fbda276`, base `1021ac8c`
  - swift-async-algorithms @ `bd5f6f44`, base `789dcf1f`
  - swift-build @ `56ad2d97`, base `f4685a11` (uncommitted changes in the checkout aren't counted)
  - swift-certificates @ `0df6bd14`, base `ff86b924`
  - swift-corelibs-xctest @ `80a3f954`, base `80a3f954` (no commits beyond the merge base yet)
  - swift-docc @ `ad021e35`, base `f37d9a7f`
  - swift-driver @ `ddb51ccd`, base `15cf6766`
  - swift-foundation @ `ef3c5667` (branch `no-darwin`), base `6669273a`
  - swift-llbuild @ `f7a0650b`, base `54a6aca5`
  - swift-log @ `4d6d77fe`, base `9c9acde6`
  - swift-nio @ `e1623fbf`, base `feaf4ac5`
  - swift-package-manager @ `dbe05ec1`, base `24a8a7b0`
  - swift-sdk-generator @ `5956672b`, base `73612f74`
  - swift-subprocess @ `d6b58669`, base `8f099c6e`
  - swift-syntax @ `961f0b72`, base `e9289aa4`
  - swift-tools-protocols @ `18e8a9f9`, base `07d2884f`
  - swift-tools-support-core @ `1ad4129f`, base `c574915f`

# 1. API

Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF=main`, `HEAD_REF=HEAD`); its links point into that run's API-DELTA.md.

## Summary

- **3186 added, 0 removed, 0 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2602 (448 → 3050 public symbols).
  - SystemSockets: +584 (0 → 584 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 3148
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 2
  - System 1.7.0: 2
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 410 compiled only on other platforms;
  - 237 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 5 declarations the scan couldn't classify; see the list below.
  - 29 added, removed or changed graph symbols the scan didn't find (enum case: 28, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2920 / -0 declarations, which is the graphs' +2602 plus 313 implicit ones; explicit declarations it has that the graphs don't: `_opaque_pthread_cond_t.initializer`, `_opaque_pthread_mutex_t.errorCheckingInitializer`, `_opaque_pthread_mutex_t.initializer`, `_opaque_pthread_mutex_t.recursiveInitializer`, `_opaque_pthread_rwlock_t.initializer`; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +657 / -0 declarations, which is the graphs' +584 plus 72 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- Nothing was removed or changed: no public declaration left the graphs or the source scan. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 46 | 0 | 0 | S199 ×46 |
| SystemPackage | [`CLocale`](#systempackage-clocale) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`CString`](#systempackage-cstring) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`CType`](#systempackage-ctype) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`CallStack`](#systempackage-callstack) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`ChildProcess`](#systempackage-childprocess) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`ClockID`](#systempackage-clockid) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`ControlCharacter`](#systempackage-controlcharacter) | 21 | 0 | 0 | S199 ×21 |
| SystemPackage | [`ControlCharacters`](#systempackage-controlcharacters) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ControlFlags`](#systempackage-controlflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`DirectoryStream`](#systempackage-directorystream) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`DirectoryWalk`](#systempackage-directorywalk) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`DiskQuota`](#systempackage-diskquota) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`DynamicLibrary`](#systempackage-dynamiclibrary) | 33 | 0 | 0 | S199 ×33 |
| SystemPackage | [`Entropy`](#systempackage-entropy) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`Errno`](#systempackage-errno) | 5 | 0 | 0 | S199 ×3, S0.0.1 ×2 |
| SystemPackage | [`ExitStatus`](#systempackage-exitstatus) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`ExtendedAttributeName`](#systempackage-extendedattributename) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`ExtendedAttributeOptions`](#systempackage-extendedattributeoptions) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 246 | 0 | 0 | S199 ×233, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 443 | 0 | 0 | S199 ×429, S199+OS ×14 |
| SystemPackage | [`FilePermissions`](#systempackage-filepermissions) | 1 | 0 | 0 | S199 ×1 |
| SystemPackage | [`FileStream`](#systempackage-filestream) | 35 | 0 | 0 | S199 ×35 |
| SystemPackage | [`FileSystemID`](#systempackage-filesystemid) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`FileSystemSubtype`](#systempackage-filesystemsubtype) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`FileSystemType`](#systempackage-filesystemtype) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`FileType`](#systempackage-filetype) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`GroupEntry`](#systempackage-groupentry) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`GroupID`](#systempackage-groupid) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`IOPolicy`](#systempackage-iopolicy) | 22 | 0 | 0 | S199 ×22 |
| SystemPackage | [`InputFlags`](#systempackage-inputflags) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`KernelEvent`](#systempackage-kernelevent) | 82 | 0 | 0 | S199 ×82 |
| SystemPackage | [`KernelQueue`](#systempackage-kernelqueue) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`LocalFlags`](#systempackage-localflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`Mach`](#systempackage-mach) | 70 | 0 | 0 | S199 ×70 |
| SystemPackage | [`Math`](#systempackage-math) | 55 | 0 | 0 | S199 ×55 |
| SystemPackage | [`Memory`](#systempackage-memory) | 91 | 0 | 0 | S199 ×91 |
| SystemPackage | [`MemoryMapping`](#systempackage-memorymapping) | 36 | 0 | 0 | S199 ×36 |
| SystemPackage | [`MountFlags`](#systempackage-mountflags) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`NamedSemaphore`](#systempackage-namedsemaphore) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`NetworkInterface`](#systempackage-networkinterface) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`OutputFlags`](#systempackage-outputflags) | 34 | 0 | 0 | S199 ×34 |
| SystemPackage | [`OwnedFD`](#systempackage-ownedfd) | 30 | 0 | 0 | S199 ×30 |
| SystemPackage | [`POSIXErrorCode (extends _DarwinFoundation1)`](#systempackage-posixerrorcode-extends-darwinfoundation1) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`PThread`](#systempackage-pthread) | 128 | 0 | 0 | S199 ×128 |
| SystemPackage | [`ProcessEnvironment`](#systempackage-processenvironment) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessID`](#systempackage-processid) | 218 | 0 | 0 | S199 ×218 |
| SystemPackage | [`ProcessPriority`](#systempackage-processpriority) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ProcessStateChange`](#systempackage-processstatechange) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessTimer`](#systempackage-processtimer) | 18 | 0 | 0 | S199 ×18 |
| SystemPackage | [`ResourceLimit`](#systempackage-resourcelimit) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`SearchPaths`](#systempackage-searchpaths) | 42 | 0 | 0 | S199 ×41, S199+OS ×1 |
| SystemPackage | [`Signal`](#systempackage-signal) | 74 | 0 | 0 | S199 ×74 |
| SystemPackage | [`SignalSet`](#systempackage-signalset) | 22 | 0 | 0 | S199 ×22 |
| SystemPackage | [`SpawnAttributes`](#systempackage-spawnattributes) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`SpawnCredentials`](#systempackage-spawncredentials) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`SpawnFileAction`](#systempackage-spawnfileaction) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`Stat`](#systempackage-stat) | 2 | 0 | 0 | S1.7.0 ×2 |
| SystemPackage | [`StatFS`](#systempackage-statfs) | 27 | 0 | 0 | S199 ×27 |
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 73 | 0 | 0 | S199 ×73 |
| SystemPackage | [`SystemControl`](#systempackage-systemcontrol) | 72 | 0 | 0 | S199 ×72 |
| SystemPackage | [`SystemIdentity`](#systempackage-systemidentity) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`TerminalAttributes`](#systempackage-terminalattributes) | 44 | 0 | 0 | S199 ×44 |
| SystemPackage | [`TerminalDescriptor`](#systempackage-terminaldescriptor) | 52 | 0 | 0 | S199 ×52 |
| SystemPackage | [`UnfairLock`](#systempackage-unfairlock) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`UserEntry`](#systempackage-userentry) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`UserID`](#systempackage-userid) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`dirent (extends Darwin)`](#systempackage-dirent-extends-darwin) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`iovec (extends Darwin)`](#systempackage-iovec-extends-darwin) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`kevent (extends Darwin)`](#systempackage-kevent-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`kinfo_proc (extends Darwin)`](#systempackage-kinfo-proc-extends-darwin) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`stat (extends Darwin)`](#systempackage-stat-extends-darwin) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`timespec (extends _DarwinFoundation2)`](#systempackage-timespec-extends-darwinfoundation2) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`timeval (extends _DarwinFoundation2)`](#systempackage-timeval-extends-darwinfoundation2) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`AddressResolutionError`](#systemsockets-addressresolutionerror) | 5 | 0 | 0 | S199 ×5 |
| SystemSockets | [`CInterop`](#systemsockets-cinterop) | 3 | 0 | 0 | S199 ×3 |
| SystemSockets | [`CInterop (extends SystemPackage)`](#systemsockets-cinterop-extends-systempackage) | 19 | 0 | 0 | S199 ×19 |
| SystemSockets | [`IPv4Address`](#systemsockets-ipv4address) | 32 | 0 | 0 | S199 ×32 |
| SystemSockets | [`IPv6Address`](#systemsockets-ipv6address) | 30 | 0 | 0 | S199 ×30 |
| SystemSockets | [`SocketAddress`](#systemsockets-socketaddress) | 67 | 0 | 0 | S199 ×67 |
| SystemSockets | [`SocketDescriptor`](#systemsockets-socketdescriptor) | 353 | 0 | 0 | S199 ×347, S199+OS ×6 |
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
| **Total** | | **3186** | **0** | **0** | |

# 2. Adoption

Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or `import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration (`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under `#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. *Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.

| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | Through a re-export (copied) | Markers (files) |
|---|---:|---:|---:|---:|---:|---:|---:|
| WasmKit | 333 | 14 → 0 | 0 | 0 → 1 | 0 | — | 0 (0) → 1 (1) |
| indexstore-db | 73 | 1 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| sourcekit-lsp | 444 | 8 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-argument-parser | 166 | 1 → 0 | 0 | 0 → 1 | 0 | 1 → 0 | 0 (0) → 1 (1) |
| swift-async-algorithms | 146 | 2 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-build | 1058 | 2 → 0 | 1 → 0 | 0 → 10 | 0 | — | 0 (0) → 17 (12) |
| swift-certificates | 133 | 2 → 0 | 0 | 0 → 1 | 0 | 3 → 0 | 0 (0) → 1 (1) |
| swift-corelibs-xctest | 34 | 1 | 0 | 0 | 0 | — | 0 (0) |
| swift-docc | 888 | 3 → 0 | 1 → 0 | 0 → 1 | 0 | — | 0 (0) → 1 (1) |
| swift-driver | 195 | 11 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| swift-foundation | 431 | 33 → 0 | 1 → 0 | 0 | 3 | 7 → 0 | 0 (0) → 3 (2) |
| swift-llbuild | 19 | 0 | 5 → 0 | 0 | 0 | — | 0 (0) |
| swift-log | 30 | 5 → 0 | 0 | 0 → 2 | 0 | 1 → 0 | 0 (0) → 3 (2) |
| swift-nio | 479 | 41 → 0 | 3 → 0 | 0 | 0 | — | 0 (0) |
| swift-package-manager | 883 | 3 → 0 | 2 → 0 | 0 | 0 | — | 0 (0) |
| swift-sdk-generator | 73 | 2 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-subprocess | 36 | 17 → 0 | 0 | 0 → 1 | 0 | — | 0 (0) → 2 (2) |
| swift-syntax | 586 | 2 → 0 | 0 | 0 → 2 | 0 | 3 → 0 | 0 (0) → 3 (2) |
| swift-tools-protocols | 232 | 2 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-tools-support-core | 124 | 0 | 1 → 0 | 0 → 2 | 0 | 14 → 5 | 0 (0) → 2 (2) |
| **All** | 6363 | 150 → 1 | 16 → 0 | 0 → 21 | 3 | | 0 (0) → 34 (26) |

Files whose imports aren't narrow yet: swift-corelibs-xctest: `Sources/XCTest/Public/XCTestMain.swift` (whole module).

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

**sourcekit-lsp**

- No MIGRATION.md or REPORT.md with test totals at this commit.

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

**swift-build**

- No MIGRATION.md or REPORT.md with test totals at this commit.

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

**swift-corelibs-xctest**

- No MIGRATION.md or REPORT.md with test totals at this commit.

**swift-docc**

- MIGRATION.md, tests (lines 64, 65, 66):

  ```text
  - XCTest: 1649 tests, 1 skipped, 23 failures. The failures are mixed Swift/Objective-C catalogs that throw
    `invalidObjectPointer`, before and after.
  - Swift Testing: 488 tests in 76 suites, 472 passed and 1 failed with 53 issues (52 known), before and after.
  ```

**swift-driver**

- MIGRATION.md, tests (lines 79, 80, 81, 82):

  ```text
  - XCTest: 3 tests (performance), passing before and after.
  - Swift Testing: 471 tests in 40 suites, with 18 issues (17 known) before and after. The one failure
    is the same both times: `MiscDriverTests.verifyEmittedInterfaceJob` (2 planned jobs, 3
    expected).
  ```

**swift-foundation**

- MIGRATION.md, tests (lines 139, 141, 177):

  ```text
  | Step | Result |
  | Baseline | 1701 tests in 128 suites passed (34 skipped) |
  | POSIXError deprecations (no-darwin) | 1701 tests in 128 suites passed |
  ```

- MIGRATION.md, re-exports (lines 65, 67, 98):

  ```text
  | | FoundationEssentials: whole module | scoped only (SYSTEM-GAP) | through a re-export | FoundationInternationalization | Tests |
  | At start (`21c6d01f`) | 25 | 0 | 7 | 1 | 8 |
  | After re-exports again (no-darwin: `os` imported by name in the package build; the shims' `export *` tried, not changed) | 0 | 0 | 0 | 0 | 0 |
  ```

- REPORT.md, tests (lines 14, 172):

  ```text
  - `migrate-darwin` baseline: builds with tests; 1701 tests in 128 suites pass, 34 skipped, 0 failed.
  - Tests: 1701 tests in 128 suites pass after every step.
  ```

**swift-llbuild**

- No MIGRATION.md or REPORT.md with test totals at this commit.

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

- MIGRATION.md, tests (lines 98, 99, 100, 101, 102, 103, 104, 105):

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

**swift-sdk-generator**

- MIGRATION.md, tests (lines 50, 51, 52, 54, 55, 56):

  ```text
  - XCTest: 202 tests, 88 skipped and 1 failure. The skips are `SwiftSDKGeneratorTests`' end-to-end SDK builds, and
    the failure is `RepeatedBuildTests.testRepeatedSDKBuilds` ("process exited non-zero"), which needs the network,
    before and after.
  - `AsyncProcessTests.IntegrationTests`, whose 57 tests all pass, exercise the migrated process code: signalled
    teardown (`kill`, `SIGKILL`), standard-input piping (`dup`), `FileContentStream` over pipes and files (`fstat`),
    and the descriptor-leak checks (`/dev/fd`, `F_DUPFD`).
  ```

**swift-subprocess**

- MIGRATION.md, tests (lines 29, 30, 31):

  ```text
  - Baseline (unmodified `main`, same flags): builds; 171 tests in 7 suites pass (161 passed, 11 skipped by design:
    root-only, linter, unsafe-close tests).
  - Now (after every step below): the same, 171 tests in 7 suites, 161 passed, 11 skipped, 0 failed.
  ```

- REPORT.md, tests (lines 106, 107):

  ```text
  as the baseline. A throwaway probe (41 cases, not committed; it, its diff script and its logs are in
  `adopters/logs-2/swift-subprocess/cvalues-probe/`, the suite's logs beside it) ran on `1dc7dbb`, `41a34c8` and
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

- MIGRATION.md, re-exports (lines 16, 19):

  ```text
  | | Library | Tests |
  | `import TSCLibc`, which re-exported `Darwin.C` | 14 (one, `misc.swift`, also had scoped `import func TSCLibc.strerror_r`, `import var TSCLibc.EINVAL`, `ERANGE`) | 5 |
  ```

# 3. Gaps

Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: 34 markers in 26 files, of which 0 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `cddd4d20`:

- **missing**: System documents none of it (or only some: *k of n*), and `mapping.ini` has no answer outside System for it.
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry speaks for it; read the marker.
- **standard library**: System doesn't name it, and its entry in `mapping.ini` gives the standard library's answer (`swift`), shown with the entry's name.
- **not System's**: System doesn't name it, and its entry in `mapping.ini` is marked `wrap = no`: another module's or library's interface, such as the MachO module's file format, which System doesn't wrap.

The last two are answers outside System, read from `mapping.ini` at System's commit as the Darwin queue of `ecosystem.sh report` reads them; they aren't in the work list below.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 47 covered, 7 standard library, 25 not System's, 79 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | `load_command` | not System's ([Mach-O file format]) | 3 | swift-build | Mach-O |
| 2 | `dlerror` | covered (doc comment) | 2 | swift-build, swift-tools-support-core | dynamic loader |
| 3 | `cpu_subtype_t` | covered (doc comment) | 2 | swift-build | mach/machine.h CPU types |
| 4 | `CPU_TYPE_ARM64` | covered (doc comment) | 2 | swift-build | mach/machine.h CPU types |
| 5 | `cpu_type_t` | covered (doc comment) | 2 | swift-build | mach/machine.h CPU types |
| 6 | `CPU_TYPE_X86_64` | covered (doc comment) | 2 | swift-build | mach/machine.h CPU types |
| 7 | `memcmp` | covered (doc comment) | 2 | swift-syntax | string.h |
| 8 | `OSStatus` | standard library ([MacTypes]: Int32 for OSStatus, UInt16 for UniChar, and Bool for DarwinBoolean and Boolean) | 2 | swift-build | MacTypes |
| 9 | `segment_command` | not System's ([Mach-O file format]) | 2 | swift-build | Mach-O file structures |
| 10 | `XATTR_FINDERINFO_NAME` | covered (doc comment) | 2 | swift-build | extended attributes |
| 11 | `XATTR_RESOURCEFORK_NAME` | covered (doc comment) | 2 | swift-build | extended attributes |
| 12 | `_dyld_image_count` | covered (doc comment) | 1 | swift-foundation | _dyld_image_count |
| 13 | `abort` | standard library ([termination]: fatalError(_:file:line:)) | 1 | swift-build | abort |
| 14 | adding a file action to C file actions | covered (doc comment) | 1 | swift-subprocess | posix_spawn |
| 15 | `AR_EFMT1` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 16 | `ar_hdr` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 17 | `ar_size` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 18 | `build_version_command` | not System's ([Mach-O file format]) | 1 | swift-build | build_version_command |
| 19 | C-string arguments for the C-values spawns | covered (by ProcessID.spawn's C-array forms with C values) | 1 | swift-subprocess | C-string arguments for the C-values spawns |
| 20 | `CPU_ARCH_ABI64` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 21 | `CPU_SUBTYPE_MASK` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 22 | `CPU_TYPE_ANY` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 23 | `CPU_TYPE_ARM` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 24 | `CPU_TYPE_I386` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 25 | `CPU_TYPE_X86` | covered (doc comment) | 1 | swift-build | mach/machine.h CPU types |
| 26 | `dirent` | covered (doc comment) | 1 | swift-tools-support-core | dirent |
| 27 | `Dl_info` | covered (doc comment) | 1 | swift-build | Dl_info |
| 28 | `dladdr` | covered (doc comment) | 1 | swift-build | dynamic loader |
| 29 | `dli_fname` | covered (doc comment) | 1 | swift-build | dli_fname |
| 30 | `dlopen` | covered (doc comment) | 1 | swift-build | dynamic loader |
| 31 | `dylib` | not System's ([Mach-O file format]) | 1 | swift-build | dylib |
| 32 | `dylib_command` | not System's ([Mach-O file format]) | 1 | swift-build | dylib_command |
| 33 | `DynamicLibrary` | covered (by DynamicLibrary) | 1 | swift-foundation | DynamicLibrary |
| 34 | `EX_USAGE` | covered (doc comment) | 1 | swift-argument-parser | sysexits |
| 35 | `fat_arch` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch |
| 36 | `fat_arch_64` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch_64 |
| 37 | `FAT_CIGAM` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 38 | `FAT_CIGAM_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 39 | `fat_header` | not System's ([Mach-O file format]) | 1 | swift-build | fat_header |
| 40 | `fdopen` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 41 | `fflush` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 42 | `FILE` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 43 | `flockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 44 | `funlockfile` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 45 | `fwrite` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 46 | `getiopolicy_np` | covered (doc comment) | 1 | swift-build | getiopolicy_np |
| 47 | `gmtime_r` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 48 | `IOPOL_SCOPE_PROCESS` | covered (doc comment) | 1 | swift-build | IOPOL_SCOPE_PROCESS |
| 49 | `LC_MAIN` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 50 | `LC_SEGMENT` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 51 | `LC_SEGMENT_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 52 | `LC_SYMTAB` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 53 | `localtime` | covered (as `localtime_r`) | 1 | swift-log | calendar time |
| 54 | `mach_header` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header |
| 55 | `mach_header_64` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header_64 |
| 56 | `macho_arch_name_for_cpu_type` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 57 | `macho_arch_name_for_mach_header` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 58 | `macho_cpu_type_for_arch_name` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 59 | `off_t` | covered (doc comment; not yet in `system-next`) | 1 | swift-build | off_t |
| 60 | `PIPE_BUF` | covered (doc comment; not yet in `system-next`) | 1 | swift-docc | limits.h |
| 61 | `POSIXErrorCode` | covered (doc comment) | 1 | swift-foundation | POSIXErrorCode |
| 62 | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro | covered (doc comment) | 1 | WasmKit | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro |
| 63 | `rpath_command` | not System's ([Mach-O file format]) | 1 | swift-build | rpath_command |
| 64 | `RTLD_FIRST` | covered (doc comment) | 1 | swift-build | dynamic loader |
| 65 | `RTLD_LAZY` | covered (doc comment) | 1 | swift-build | dynamic loader |
| 66 | `SARMAG` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 67 | `section` | not System's ([Mach-O file format]) | 1 | swift-build | section |
| 68 | `section_64` | not System's ([Mach-O file format]) | 1 | swift-build | section_64 |
| 69 | `segment_command_64` | not System's ([Mach-O file format]) | 1 | swift-build | segment_command_64 |
| 70 | `setvbuf` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 71 | `stdout` | covered (doc comment) | 1 | swift-log | C stdio streams |
| 72 | `strftime` | covered (doc comment) | 1 | swift-log | calendar time |
| 73 | `time` | covered (as `clock_gettime`) | 1 | swift-log | calendar time |
| 74 | `time_t` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 75 | `tm` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 76 | `tolower` | covered (doc comment) | 1 | swift-build | ctype.h |
| 77 | `uuid_command` | not System's ([Mach-O file format]) | 1 | swift-build | uuid_command |
| 78 | `version_min_command` | not System's ([Mach-O file format]) | 1 | swift-build | version_min_command |
| 79 | `vm_prot_t` | standard library ([C scalar types]: Int, UInt, Int64, UInt8 ... and Swift's C type aliases (CInt, CChar, CLong ...), and …) | 1 | swift-build | Mach virtual memory |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|

## Markers that name no C interface

- swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`: DynamicLibrary, in the framework build (not built here): dlopen with RTLD_NOLOAD \| RTLD_FIRST, dlsym and dlclose are system-next's DynamicLibrary(_:options: [.noLoad, .first]), address(of:), close() a
- swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:618`: C-string arguments for the C-values spawns. System's ProcessID.spawn with cFileActions: and cAttributes:, with or without credentials:, takes the arguments and environment only

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- `load_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`; swift-build: `Tests/SWBBuildSystemTests/MergeableLibrariesBuildOperationTests.swift:23`; swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `dlerror` (covered): swift-build: `Sources/SWBUtil/Library.swift:19`; swift-tools-support-core: `Sources/TSCUtility/dlopen.swift:20`
- `cpu_subtype_t` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`; swift-build: `Sources/SWBUtil/MachO.swift:69`
- `CPU_TYPE_ARM64` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`; swift-build: `Sources/SWBUtil/MachO.swift:69`
- `cpu_type_t` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`; swift-build: `Sources/SWBUtil/MachO.swift:69`
- `CPU_TYPE_X86_64` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`; swift-build: `Sources/SWBUtil/MachO.swift:69`
- `memcmp` (covered): swift-syntax: `Sources/SwiftCompilerPluginMessageHandling/JSON/JSONDecoding.swift:16`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:15`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:27`
- `OSStatus` (standard library): swift-build: `Sources/SWBUtil/Error.swift:21`; swift-build: `Sources/SWBUtil/PbxCp.swift:21`
- `segment_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`; swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `XATTR_FINDERINFO_NAME` (covered): swift-build: `Sources/SWBUtil/PbxCp.swift:23`; swift-build: `Tests/SWBUtilTests/PBXCpTests.swift:18`
- `XATTR_RESOURCEFORK_NAME` (covered): swift-build: `Sources/SWBUtil/PbxCp.swift:23`; swift-build: `Tests/SWBUtilTests/PBXCpTests.swift:18`
- `_dyld_image_count` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:69`
- `abort` (standard library): swift-build: `Sources/SwiftBuild/SWBBuildServiceConnection.swift:23`
- adding a file action to C file actions (covered): swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `AR_EFMT1` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:76`
- `ar_hdr` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:76`
- `ar_size` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:76`
- `build_version_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- C-string arguments for the C-values spawns (covered): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:618`
- `CPU_ARCH_ABI64` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`
- `CPU_SUBTYPE_MASK` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`
- `CPU_TYPE_ANY` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`
- `CPU_TYPE_ARM` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`
- `CPU_TYPE_I386` (covered): swift-build: `Sources/SWBUtil/Architecture.swift:18`
- `CPU_TYPE_X86` (covered): swift-build: `Sources/SWBUtil/MachO.swift:69`
- `dirent` (covered): swift-tools-support-core: `Sources/TSCBasic/FileSystem.swift:19`
- `Dl_info` (covered): swift-build: `Sources/SWBUtil/Library.swift:26`
- `dladdr` (covered): swift-build: `Sources/SWBUtil/Library.swift:26`
- `dli_fname` (covered): swift-build: `Sources/SWBUtil/Library.swift:26`
- `dlopen` (covered): swift-build: `Sources/SWBUtil/Library.swift:19`
- `dylib` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `dylib_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `DynamicLibrary` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`
- `EX_USAGE` (covered): swift-argument-parser: `Sources/ArgumentParser/Utilities/Platform.swift:25`
- `fat_arch` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fat_arch_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `FAT_CIGAM` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `FAT_CIGAM_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `fat_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fdopen` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fflush` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FILE` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `flockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `funlockfile` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fwrite` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `getiopolicy_np` (covered): swift-build: `Sources/SWBUtil/ProcessInfo.swift:24`
- `gmtime_r` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `IOPOL_SCOPE_PROCESS` (covered): swift-build: `Sources/SWBUtil/ProcessInfo.swift:24`
- `LC_MAIN` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SYMTAB` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `localtime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `mach_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `mach_header_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `macho_arch_name_for_cpu_type` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:29`
- `macho_arch_name_for_mach_header` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:29`
- `macho_cpu_type_for_arch_name` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:29`
- `off_t` (covered): swift-build: `Sources/SWBUtil/SWBDispatch.swift:22`
- `PIPE_BUF` (covered): swift-docc: `Sources/SwiftDocC/Infrastructure/External Data/OutOfProcessReferenceResolver.swift:16`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:20`
- readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:7`
- `rpath_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `RTLD_FIRST` (covered): swift-build: `Sources/SWBUtil/Library.swift:19`
- `RTLD_LAZY` (covered): swift-build: `Sources/SWBUtil/Library.swift:19`
- `SARMAG` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:76`
- `section` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `section_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `segment_command_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `setvbuf` (covered): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `stdout` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `strftime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `time` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `time_t` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `tm` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `tolower` (covered): swift-build: `Sources/SWBUtil/Headermap.swift:15`
- `uuid_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `version_min_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `vm_prot_t` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:69`

</details>

# 4. Platform imports

The goal: no library of the repositories that swift's update-checkout clones for the main scheme imports a platform C module (Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT, visualc) in any form, on any platform. Each repository is read at its migrated clone in `../adopters`, on its migration branch (as in *Adopters* above), else at its clone in `../ecosystem` as it is, else it's *not cloned*. Left out: swift (the compiler, the runtime, and the platform modules' own overlays); swift-system (System itself, whose imports are what it wraps). Each cell is the number of Swift files of that kind that import any of the modules, then how many import each; a file under `#if` branches for several platforms counts once per module. Kinds are by path (see [How this is computed](#how-this-is-computed)): *library* is under `Sources` (or `src`, `lib`, `products`), *tests* under a test directory, *other* the rest (benchmarks, examples, tools, plugins, docs, utilities), and a *nested package* is under a directory with its own `Package.swift`.

| Repository | Read at | Library | Tests | Other | Nested packages | Files |
|---|---|---|---|---|---|---:|
| boringssl | not cloned | | | | | |
| brotli | not cloned | | | | | |
| cmake | not cloned | | | | | |
| cmark | `../ecosystem/cmark` @ `0c8947bb` | — | — | — | — | 0 |
| curl | not cloned | | | | | |
| indexstore-db | `../adopters/indexstore-db` `migrate-darwin` @ `cc966b89` | 4 (Android 1, WinSDK 4, CRT 1) | — | — | — | 4 |
| libxml2 | not cloned | | | | | |
| llbuild | `../adopters/swift-llbuild` `migrate-darwin` @ `f7a0650b` | 5 (Glibc 5, Musl 5, Bionic 4, Android 1, ucrt 5, WinSDK 5) | 2 (WinSDK 2) | — | — | 7 |
| llvm-project | not cloned | | | | | |
| mimalloc | not cloned | | | | | |
| ninja | not cloned | | | | | |
| sourcekit-lsp | `../adopters/sourcekit-lsp` `migrate-darwin` @ `cb2881c5` | 16 (Glibc 9, Musl 9, Bionic 7, Android 4, WinSDK 7, CRT 8) | 3 (Android 2, WinSDK 2) | — | — | 19 |
| swift-argument-parser | `../adopters/swift-argument-parser` `migrate-darwin` @ `0fbda276` | 2 (Darwin 1, Glibc 2, Musl 2, Bionic 1, Android 1, WASILibc 1, WinSDK 2, CRT 1) | — | — | — | 2 |
| swift-asn1 | `../ecosystem/swift-asn1` @ `a54383ad` | — | — | — | — | 0 |
| swift-async-algorithms | `../adopters/swift-async-algorithms` `migrate-darwin` @ `bd5f6f44` | 2 (Glibc 2, Musl 2, Bionic 2, WinSDK 1) | — | — | — | 2 |
| swift-atomics | `../ecosystem/swift-atomics` @ `0442cb5a` | — | — | — | — | 0 |
| swift-build | `../adopters/swift-build` `migrate-darwin` @ `56ad2d97` | 18 (Darwin 9, Glibc 1, Musl 1, Android 1, ucrt 1, WinSDK 9, CRT 1) | 3 (Darwin 1, WinSDK 2) | — | — | 21 |
| swift-certificates | `../adopters/swift-certificates` `migrate-darwin` @ `0df6bd14` | 3 (Glibc 3, Musl 3, Bionic 1, Android 2, WASILibc 1, ucrt 1, WinSDK 3) | 2 (Darwin 1, Android 1) | — | — | 5 |
| swift-collections | `../ecosystem/swift-collections` @ `c11818f3` | — | — | — | — | 0 |
| swift-corelibs-blocksruntime | not cloned | | | | | |
| swift-corelibs-foundation | `../ecosystem/swift-corelibs-foundation` @ `6f21ccf1` | 25 (Darwin 9, Glibc 11, Musl 7, Bionic 7, Android 12, WASILibc 6, WinSDK 16, CRT 5) | 7 (Darwin 2, Glibc 2, Android 7, WinSDK 3, CRT 1) | — | — | 32 |
| swift-corelibs-libdispatch | not cloned | | | | | |
| swift-corelibs-xctest | `../adopters/swift-corelibs-xctest` `migrate-darwin` @ `80a3f954` | 1 (Darwin 1, Glibc 1) | — | — | — | 1 |
| swift-crypto | `../ecosystem/swift-crypto` @ `d79c573e` | 2 (Android 2, WinSDK 1) | — | — | — | 2 |
| swift-docc | `../adopters/swift-docc` `migrate-darwin` @ `ad021e35` | 5 (Darwin 1, Glibc 1, Musl 1, WinSDK 3, CRT 1) | 2 (Glibc 1, ucrt 1, WinSDK 1) | — | — | 7 |
| swift-docc-render-artifact | not cloned | | | | | |
| swift-docc-symbolkit | `../ecosystem/swift-docc-symbolkit` @ `e9a4c0f2` | — | — | — | — | 0 |
| swift-driver | `../adopters/swift-driver` `migrate-darwin` @ `ddb51ccd` | 8 (Glibc 6, Musl 6, Bionic 3, Android 3, ucrt 1, WinSDK 5, CRT 3) | 5 (Glibc 5, Musl 5, CRT 5) | — | — | 13 |
| swift-experimental-string-processing | `../ecosystem/swift-experimental-string-processing` @ `db4678c7` | 1 (Darwin 1, Glibc 1) | — | — | — | 1 |
| swift-format | `../ecosystem/swift-format` @ `b15dd59f` | 3 (Android 1, WinSDK 2) | — | — | — | 3 |
| swift-foundation | `../adopters/swift-foundation` `no-darwin` @ `ef3c5667` | 31 (Darwin 3, Glibc 23, Musl 23, Bionic 8, Android 14, WASILibc 21, ucrt 5, WinSDK 24, CRT 10) | 8 (Glibc 8, Musl 6, Bionic 2, Android 6, WASILibc 5, ucrt 1, WinSDK 1, CRT 6) | — | 2 (Darwin 2, Glibc 2) | 41 |
| swift-foundation-icu | `../ecosystem/swift-foundation-icu` @ `e8538d25` | — | — | — | 1 (Darwin 1) | 1 |
| swift-installer-scripts | not cloned | | | | | |
| swift-integration-tests | not cloned | | | | | |
| swift-llvm-bindings | `../ecosystem/swift-llvm-bindings` @ `c1fffb92` | — | — | — | — | 0 |
| swift-lmdb | `../ecosystem/swift-lmdb` @ `866bc256` | — | — | — | — | 0 |
| swift-log | `../adopters/swift-log` `migrate-darwin` @ `4d6d77fe` | 3 (Darwin 1, Glibc 3, Musl 3, Bionic 1, Android 3, WASILibc 3, ucrt 1, WinSDK 1, CRT 2) | 3 (Darwin 1, Glibc 2, Android 2, WinSDK 3) | — | — | 6 |
| swift-markdown | `../ecosystem/swift-markdown` @ `392b73b8` | — | — | — | — | 0 |
| swift-nio | `../adopters/swift-nio` `migrate-darwin` @ `e1623fbf` | 60 (Glibc 40, Musl 39, Bionic 18, Android 18, WASILibc 17, ucrt 16, WinSDK 30) | 21 (Glibc 5, Bionic 1, Android 7, ucrt 6, WinSDK 12) | — | 2 (Glibc 2, Musl 1) | 83 |
| swift-numerics | `../ecosystem/swift-numerics` @ `0a5bc040` | — | — | — | — | 0 |
| swift-sdk-generator | `../adopters/swift-sdk-generator` `migrate-darwin` @ `5956672b` | 1 (Glibc 1) | 1 (Glibc 1, Musl 1, Bionic 1, Android 1, WASILibc 1) | — | — | 2 |
| swift-stress-tester | not cloned | | | | | |
| swift-subprocess | `../adopters/swift-subprocess` `migrate-darwin` @ `d6b58669` | 16 (Glibc 12, Musl 10, Bionic 4, Android 6, WinSDK 10) | 10 (Darwin 1, Glibc 7, Musl 7, Bionic 3, Android 4, WinSDK 6) | — | — | 26 |
| swift-syntax | `../adopters/swift-syntax` `migrate-darwin` @ `961f0b72` | 3 (Darwin 2, Glibc 2, Musl 2, Bionic 1, Android 1) | — | 1 (Darwin 1) | 3 (Glibc 1, Musl 1, Android 1, WinSDK 2, CRT 1) | 7 |
| swift-testing | `../ecosystem/swift-testing` @ `ea850751` | 10 (WinSDK 10) | 1 (WinSDK 1) | — | — | 11 |
| swift-toolchain-sarif | `../ecosystem/swift-toolchain-sarif` @ `d611f23a` | — | — | — | — | 0 |
| swift-toolchain-sqlite | `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0` | — | — | — | — | 0 |
| swift-tools-protocols | `../adopters/swift-tools-protocols` `migrate-darwin` @ `18e8a9f9` | 3 (Glibc 1, Musl 1, Android 1, WinSDK 3) | 2 (Android 2, WinSDK 2) | — | — | 5 |
| swift-tools-support-core | `../adopters/swift-tools-support-core` `migrate-darwin` @ `1ad4129f` | 8 (Darwin 2, Glibc 1, Musl 1, Android 1, WinSDK 5, CRT 2) | — | — | — | 8 |
| swift-xcode-playground-support | not cloned | | | | | |
| swiftpm | `../adopters/swift-package-manager` `migrate-darwin` @ `dbe05ec1` | 15 (Glibc 4, Musl 3, Bionic 1, Android 9, ucrt 2, WinSDK 11, CRT 1) | — | — | 1 (Darwin 1, Glibc 1, Musl 1, Android 1, ucrt 1) | 16 |
| wasi-libc | not cloned | | | | | |
| wasmkit | `../adopters/WasmKit` `migrate-darwin` @ `4917e060` | 14 (Darwin 1, Glibc 12, Musl 12, Android 10, WASILibc 8, ucrt 6, WinSDK 5) | 3 (Glibc 3, Musl 2, ucrt 1) | — | 1 (Darwin 1, Glibc 1, WASILibc 1) | 18 |
| zlib | not cloned | | | | | |

37 repositories read; 25 import a platform module in library code: indexstore-db, llbuild, sourcekit-lsp, swift-argument-parser, swift-async-algorithms, swift-build, swift-certificates, swift-corelibs-foundation, swift-corelibs-xctest, swift-crypto, swift-docc, swift-driver, swift-experimental-string-processing, swift-format, swift-foundation, swift-log, swift-nio, swift-sdk-generator, swift-subprocess, swift-syntax, swift-testing, swift-tools-protocols, swift-tools-support-core, swiftpm, wasmkit.

All repositories, files by module and kind:

| Module | Library | Tests | Other | Nested packages | All |
|---|---:|---:|---:|---:|---:|
| Darwin | 31 | 6 | 1 | 5 | 43 |
| Glibc | 141 | 34 | 0 | 7 | 182 |
| Musl | 130 | 21 | 0 | 3 | 154 |
| Bionic | 58 | 7 | 0 | 0 | 65 |
| Android | 91 | 32 | 0 | 2 | 125 |
| WASILibc | 57 | 6 | 0 | 1 | 64 |
| ucrt | 38 | 9 | 0 | 1 | 48 |
| WinSDK | 157 | 35 | 0 | 2 | 194 |
| CRT | 35 | 12 | 0 | 1 | 48 |
| visualc | 0 | 0 | 0 | 0 | 0 |
| **Any** | 259 | 73 | 1 | 10 | 343 |

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
  credentials forms). The other way round, an interface that System's docs name counts as missing while the
  markers ask for more than the naming API gives, until a witness shows the ask is met (`STILL_NEEDED`: struct
  dirent needs a public name with accessors, dlerror a call that takes the pending error, and addchdir_np a way to
  add an action to C file actions that other code built). This sees what System documents, not whether the API
  fits the adopter's use: a partial wrapper counts as covered, and an API whose doc comments don't name the C
  interface counts as missing.
- **Answers outside System** come from `mapping.ini` at System's commit, and only for names System doesn't name at
  all (not for one it names while a marker asks for more): a name in an entry with a `swift` answer is *standard
  library*, and a name in an entry marked `wrap = no` is *not System's*, the `swift` answer first, as the Darwin
  queue of `ecosystem.sh report` decides them. `X members` takes X's entry. An interface whose uncovered names all
  have an answer takes the first kind among them, and the table gives the entries. Such interfaces aren't in the
  work list; *covered* is still only what System's sources document, and a `status` in mapping.ini changes nothing
  here. Rejected: counting them as covered, which would say System has what it doesn't; and leaving them missing,
  which kept the MachO module's file format and the standard library's answers in the work list for good.
- **Provisional families** (libm, C stdio, locale and xlocale, string.h and ctype.h, numeric conversion) are a
  fixed list in `scripts/status.py`, matched by name or by the name's SDK module in adopter-coverage's stored
  vocabulary when there is one. They're C-library layers above the OS that System wraps provisionally, in
  `Sources/System/Provisional/`, and they count as missing until covered, like everything else; the family
  only groups them in the work list.
- **Families** group the ranked interfaces for the work list: the provisional families, then a fixed map of
  name patterns to System's clusters, else the marker's phrase, else the name itself.
- **Platform imports** (section 4) are lexical, like ecosystem.py's survey: each Swift file, with comments and
  string literals blanked, is matched against the survey's import pattern (`import_of` in `scripts/ecosystem.py`),
  widened to Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT and visualc, in every form: the whole
  module, a submodule, one declaration, with `@_exported` or another attribute, and with an access modifier. It
  doesn't evaluate `#if`: an import under `#if os(Linux)` counts as Glibc's, since the goal is none on any
  platform. Each repository of `scheme-main.tsv` is read at a commit: its migrated clone's migration branch (the
  adopters' branch, or its `--branch-for` override: swift-foundation's `no-darwin`), else the ecosystem clone's
  HEAD. A file's kind is by its path: in a nested package if a directory above it, below the root, has a
  `Package.swift`; else tests if a directory in its path is a test directory (`Tests`, `IntegrationTests`,
  `Fixtures`, `unittests` and the like); else library under a top-level `Sources`, `Source`, `src`, `srcs`, `lib`
  or `products`, outside a `.docc` catalog; else other. Rejected: the manifests' targets, as the Adoption section
  uses them, which needs every clone's manifest evaluated (swift-foundation's needs a newer compiler than 6.2)
  and says nothing of nested packages; and platforms.py's `#if` evaluation, which answers what one platform's
  build compiles, not whether any does.
