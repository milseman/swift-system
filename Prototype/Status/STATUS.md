# Status: System's API and its adopters

Generated 2026-09-28 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage` @ `0e1defa7` (Add CInterop.TimeVal and CInterop.Linger, with Swift-named accessors for timeval and linger), which contains `system-next` @ `ebc1231f` (Merge branch 'posix-darwin' into system-next); 2 commit(s) of `coverage` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `0e1defa7`.
- **Adopters** (`../adopters`, branch `migrate-darwin`, against its merge base with `main`):
  - swift-argument-parser @ `0fbda276`, base `1021ac8c`
  - swift-async-algorithms @ `bd5f6f44`, base `789dcf1f`
  - swift-certificates @ `0df6bd14`, base `ff86b924`
  - swift-foundation @ `47fbcdee`, base `6669273a` (uncommitted changes in the checkout aren't counted)
  - swift-log @ `4d6d77fe`, base `9c9acde6`
  - swift-nio @ `e8ee9c89`, base `feaf4ac5` (uncommitted changes in the checkout aren't counted)
  - swift-package-manager @ `24a8a7b0`, base `24a8a7b0` (no commits beyond the merge base yet) (uncommitted changes in the checkout aren't counted)
  - swift-subprocess @ `1dc7dbb8`, base `8f099c6e`
  - swift-syntax @ `961f0b72`, base `e9289aa4`
  - swift-tools-support-core @ `530d4e50`, base `c574915f`

# 1. API

Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF=main`, `HEAD_REF=HEAD`); its links point into that run's API-DELTA.md.

## Summary

- **2736 added, 0 removed, 0 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2160 (448 → 2608 public symbols).
  - SystemSockets: +576 (0 → 576 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 2701
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 1
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 400 compiled only on other platforms;
  - 213 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 26 added, removed or changed graph symbols the scan didn't find (enum case: 25, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2423 / -0 declarations, which is the graphs' +2160 plus 263 implicit ones; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +648 / -0 declarations, which is the graphs' +576 plus 71 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- Nothing was removed or changed: no public declaration left the graphs or the source scan. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 35 | 0 | 0 | S199 ×35 |
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
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 237 | 0 | 0 | S199 ×224, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 398 | 0 | 0 | S199 ×384, S199+OS ×14 |
| SystemPackage | [`FilePermissions`](#systempackage-filepermissions) | 1 | 0 | 0 | S199 ×1 |
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
| SystemPackage | [`Memory`](#systempackage-memory) | 47 | 0 | 0 | S199 ×47 |
| SystemPackage | [`MemoryMapping`](#systempackage-memorymapping) | 34 | 0 | 0 | S199 ×34 |
| SystemPackage | [`MountFlags`](#systempackage-mountflags) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`NetworkInterface`](#systempackage-networkinterface) | 32 | 0 | 0 | S199 ×32 |
| SystemPackage | [`OutputFlags`](#systempackage-outputflags) | 34 | 0 | 0 | S199 ×34 |
| SystemPackage | [`OwnedFD`](#systempackage-ownedfd) | 30 | 0 | 0 | S199 ×30 |
| SystemPackage | [`PThread`](#systempackage-pthread) | 123 | 0 | 0 | S199 ×123 |
| SystemPackage | [`ProcessEnvironment`](#systempackage-processenvironment) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`ProcessID`](#systempackage-processid) | 185 | 0 | 0 | S199 ×185 |
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
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 67 | 0 | 0 | S199 ×67 |
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
| **Total** | | **2736** | **0** | **0** | |

# 2. Adoption

Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or `import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration (`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under `#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. *Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.

| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | Through a re-export (copied) | Markers (files) |
|---|---:|---:|---:|---:|---:|---:|---:|
| swift-argument-parser | 166 | 1 → 0 | 0 | 0 → 1 | 0 | 1 → 0 | 0 (0) → 1 (1) |
| swift-async-algorithms | 146 | 2 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-certificates | 133 | 2 → 0 | 0 | 0 → 1 | 0 | 3 → 0 | 0 (0) → 1 (1) |
| swift-foundation | 431 | 33 → 0 | 1 → 0 | 0 → 15 | 3 | 7 → 1 | 0 (0) → 23 (16) |
| swift-log | 30 | 5 → 0 | 0 | 0 → 2 | 0 | 1 → 0 | 0 (0) → 3 (2) |
| swift-nio | 479 | 41 → 0 | 3 → 1 | 0 → 52 | 0 | — | 0 (0) → 65 (53) |
| swift-package-manager | 883 | 3 | 2 | 0 | 0 | — | 0 (0) |
| swift-subprocess | 36 | 17 → 0 | 0 | 0 → 2 | 0 | — | 0 (0) → 3 (2) |
| swift-syntax | 586 | 2 → 0 | 0 | 0 → 2 | 0 | 3 → 0 | 0 (0) → 3 (2) |
| swift-tools-support-core | 124 | 0 | 1 → 0 | 0 → 5 | 0 | 14 → 5 | 0 (0) → 13 (5) |
| **All** | 3014 | 106 → 3 | 7 → 3 | 0 → 80 | 3 | | 0 (0) → 112 (82) |

2 more marker(s) are in files outside the targets (they're in the gaps below): swift-nio: `Benchmarks/`, swift-nio: `IntegrationTests/`.

Files whose imports aren't narrow yet: swift-nio: `Tests/NIOFSTests/FileInfoTests.swift` (submodule), swift-package-manager: `Sources/Commands/Utilities/TestingSupport.swift` (whole module), swift-package-manager: `Sources/CoreCommands/SwiftCommandState.swift` (whole module), swift-package-manager: `Tests/BasicsTests/SandboxTests.swift` (whole module), swift-package-manager: `Sources/Basics/Environment/Environment.swift` (submodule), swift-package-manager: `Sources/swiftpm-testing-helper/Entrypoint.swift` (submodule).

## Copied from the packages' reports

Verbatim, not rerun: each package's own test totals (at the start, and the latest it reports), and the rows behind the re-export column. Line numbers are 1-based, in the file at the package's commit above.

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

**swift-foundation**

- MIGRATION.md, tests (lines 107, 109, 126):

  ```text
  | Step | Result |
  | Baseline | 1701 tests in 128 suites passed (34 skipped) |
  | Memory | 1701 tests in 128 suites passed |
  ```

- MIGRATION.md, re-exports (lines 55, 57, 73):

  ```text
  | | FoundationEssentials: whole module | scoped only (SYSTEM-GAP) | through a re-export | FoundationInternationalization | Tests |
  | At start (`21c6d01f`) | 25 | 0 | 7 | 1 | 8 |
  | After Memory | 0 | 11 | 1 | 0 | 0 (4 scoped only) |
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

- MIGRATION.md, tests (lines 25, 33):

  ```text
  | | Start | Now |
  | `swift test` | 2454 run, 43 skipped, 0 failed; swift-testing 303 passed | 2439 run, 43 skipped, 0 failed; swift-testing 303 passed |
  ```

**swift-package-manager**

- No MIGRATION.md or REPORT.md with test totals at this commit.

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

**swift-tools-support-core**

- MIGRATION.md, re-exports (lines 14, 17):

  ```text
  | | Library | Tests |
  | `import TSCLibc`, which re-exported `Darwin.C` | 14 (one, `misc.swift`, also had scoped `import func TSCLibc.strerror_r`, `import var TSCLibc.EINVAL`, `ERANGE`) | 5 |
  ```

# 3. Gaps

Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: 114 markers in 84 files, of which 2 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `0e1defa7`:

- **missing**: System documents none of it (or only some: *k of n*).
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **not System's**: a C-library layer above the OS, or another module's type ([below](#not-systems)).
- **unread**: the marker names no C interface and nothing is imported under it; read the marker.

Interfaces: 65 missing, 76 covered, 23 not System's, 1 unread, 165 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | `usleep` | covered (as `nanosleep`) | 12 | swift-nio | sleep |
| 2 | `iovec members` | covered (Swift-named accessors) | 7 | swift-nio | C struct members (MemberImportVisibility) |
| 3 | `msghdr members` | covered (Swift-named accessors) | 6 | swift-nio | C struct members (MemberImportVisibility) |
| 4 | `sockaddr_in members` | covered (Swift-named accessors) | 6 | swift-nio | C struct members (MemberImportVisibility) |
| 5 | `free` | covered (doc comment) | 5 | swift-nio | the C heap |
| 6 | `in_addr members` | covered (Swift-named accessors) | 5 | swift-nio | C struct members (MemberImportVisibility) |
| 7 | `memcpy` | not System's (string.h and ctype.h) | 5 | swift-nio | string.h and ctype.h |
| 8 | `malloc` | covered (doc comment) | 4 | swift-nio | the C heap |
| 9 | `memset` | not System's (string.h and ctype.h) | 4 | swift-nio | string.h and ctype.h |
| 10 | `realloc` | covered (doc comment) | 4 | swift-nio | the C heap |
| 11 | `memcmp` | covered (doc comment) | 3 | swift-nio, swift-syntax | string.h |
| 12 | `in6_addr members` | covered (Swift-named accessors) | 3 | swift-nio | C struct members (MemberImportVisibility) |
| 13 | `IP_RECVTOS` | covered (doc comment) | 3 | swift-nio | IP-level socket options |
| 14 | `linger` | covered (doc comment) | 3 | swift-nio | socket options |
| 15 | `PATH_MAX` | missing | 3 | swift-foundation | compile-time limits |
| 16 | `POSIXErrorCode` | not System's (the Darwin overlay's Swift types) | 3 | swift-foundation | the Darwin overlay's Swift types |
| 17 | `sockaddr members` | covered (Swift-named accessors) | 3 | swift-nio | C struct members (MemberImportVisibility) |
| 18 | `sockaddr_in6 members` | covered (Swift-named accessors) | 3 | swift-nio | C struct members (MemberImportVisibility) |
| 19 | `stdout` | not System's (C stdio) | 2 | swift-log, swift-nio | C stdio |
| 20 | C stdio FILE streams | not System's (C stdio) | 2 | swift-tools-support-core | C stdio FILE streams |
| 21 | `cmsghdr members` | covered (Swift-named accessors) | 2 | swift-nio | C struct members (MemberImportVisibility) |
| 22 | `dlopen` | covered (doc comment) | 2 | swift-nio | dynamic loader |
| 23 | `dlsym` | covered (doc comment) | 2 | swift-nio | dynamic loader |
| 24 | `errno` | covered (doc comment) | 2 | swift-nio | errno |
| 25 | `FTS_D` | missing | 2 | swift-foundation | fts |
| 26 | `FTS_DEFAULT` | missing | 2 | swift-foundation | fts |
| 27 | `FTS_DNR` | missing | 2 | swift-foundation | fts |
| 28 | `FTS_DP` | missing | 2 | swift-foundation | fts |
| 29 | `FTS_ERR` | missing | 2 | swift-foundation | fts |
| 30 | `fts_errno` | missing | 2 | swift-foundation | fts |
| 31 | `FTS_F` | missing | 2 | swift-foundation | fts |
| 32 | `fts_info` | missing | 2 | swift-foundation | fts |
| 33 | `fts_level` | missing | 2 | swift-foundation | fts |
| 34 | `FTS_NOCHDIR` | missing | 2 | swift-foundation | fts |
| 35 | `FTS_NS` | missing | 2 | swift-foundation | fts |
| 36 | `fts_path` | missing | 2 | swift-foundation | fts |
| 37 | `FTS_PHYSICAL` | missing | 2 | swift-foundation | fts |
| 38 | `FTS_SL` | missing | 2 | swift-foundation | fts |
| 39 | `FTS_SLNONE` | missing | 2 | swift-foundation | fts |
| 40 | `FTSENT` | missing | 2 | swift-foundation | fts |
| 41 | `getenv` | covered (doc comment) | 2 | swift-nio | environment |
| 42 | `if_nametoindex` | covered (doc comment) | 2 | swift-nio | network interfaces |
| 43 | `IP_TTL` | covered (doc comment) | 2 | swift-nio | IP-level socket options |
| 44 | `mkdtemp` | covered (doc comment) | 2 | swift-nio | temporary files |
| 45 | `mkstemp` | covered (as `mkostemp`) | 2 | swift-nio | temporary files |
| 46 | `NAME_MAX` | missing | 2 | swift-foundation | compile-time limits |
| 47 | posix_spawn's raw attributes and file actions | missing (12 of 18 names covered) | 2 | swift-subprocess | posix_spawn's raw attributes and file actions |
| 48 | `pow` | not System's (libm) | 2 | swift-foundation | libm |
| 49 | `SO_LINGER` | covered (doc comment) | 2 | swift-nio | socket options |
| 50 | `sockaddr_storage members` | covered (Swift-named accessors) | 2 | swift-nio | C struct members (MemberImportVisibility) |
| 51 | `TZDIR` | missing | 2 | swift-foundation | tzfile.h |
| 52 | `UTIME_NOW` | covered (doc comment) | 2 | swift-nio | file times |
| 53 | `UTIME_OMIT` | missing | 2 | swift-nio | file times |
| 54 | `XATTR_MAXNAMELEN` | missing | 2 | swift-nio | extended attributes |
| 55 | `AF_VSOCK` | missing | 1 | swift-nio | vsock |
| 56 | `close` | covered (doc comment) | 1 | swift-nio | close |
| 57 | `cos` | not System's (libm) | 1 | swift-foundation | libm |
| 58 | `dirent` | covered (doc comment) | 1 | swift-tools-support-core | dirent |
| 59 | `dlerror` | missing | 1 | swift-tools-support-core | dynamic loader |
| 60 | `DT_BLK` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 61 | `DT_CHR` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 62 | `DT_DIR` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 63 | `DT_FIFO` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 64 | `DT_LNK` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 65 | `DT_REG` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 66 | `DT_SOCK` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 67 | `DT_WHT` | covered (doc comment) | 1 | swift-nio | directory entry types |
| 68 | `EX_USAGE` | missing | 1 | swift-argument-parser | sysexits |
| 69 | `exit` | covered (doc comment) | 1 | swift-nio | exit |
| 70 | `fdopen` | not System's (C stdio) | 1 | swift-log | C stdio |
| 71 | `fflush` | not System's (C stdio) | 1 | swift-log | C stdio |
| 72 | `FILE` | not System's (C stdio) | 1 | swift-log | C stdio |
| 73 | `flockfile` | not System's (C stdio) | 1 | swift-log | C stdio |
| 74 | `FTS` | missing | 1 | swift-foundation | fts |
| 75 | `fts_close` | missing | 1 | swift-foundation | fts |
| 76 | `fts_dev` | missing | 1 | swift-foundation | fts |
| 77 | `fts_ino` | missing | 1 | swift-foundation | fts |
| 78 | `fts_name` | missing | 1 | swift-foundation | fts |
| 79 | `fts_namelen` | missing | 1 | swift-foundation | fts |
| 80 | `FTS_NOSTAT` | missing | 1 | swift-foundation | fts |
| 81 | `FTS_NSOK` | missing | 1 | swift-foundation | fts |
| 82 | `fts_open` | missing | 1 | swift-foundation | fts |
| 83 | `fts_read` | missing | 1 | swift-foundation | fts |
| 84 | `fts_set` | missing | 1 | swift-foundation | fts |
| 85 | `FTS_SKIP` | missing | 1 | swift-foundation | fts |
| 86 | `funlockfile` | not System's (C stdio) | 1 | swift-log | C stdio |
| 87 | `fwrite` | not System's (C stdio) | 1 | swift-log | C stdio |
| 88 | `getsockopt` | covered (doc comment) | 1 | swift-nio | getsockopt |
| 89 | `gmtime_r` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 90 | `in6_pktinfo` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 91 | `in_pktinfo` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 92 | `INADDR_ANY` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 93 | `inet_pton` | covered (doc comment) | 1 | swift-nio | address text |
| 94 | `ioctl` | covered (doc comment) | 1 | swift-nio | ioctl |
| 95 | `ip_mreq` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 96 | `IP_PKTINFO` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 97 | `IP_RECVDSTADDR` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 98 | `IP_RECVPKTINFO` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 99 | `IP_TOS` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 100 | `ipv6_mreq` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 101 | `IPV6_RECVTCLASS` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 102 | `IPV6_TCLASS` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 103 | `LC_ALL` | not System's (locale) | 1 | swift-foundation | locale |
| 104 | `locale_t` | not System's (locale) | 1 | swift-foundation | locale |
| 105 | `localtime` | covered (as `localtime_r`) | 1 | swift-log | calendar time |
| 106 | `log` | not System's (libm) | 1 | swift-foundation | libm |
| 107 | `malloc_type_calloc` | missing | 1 | swift-foundation | libmalloc |
| 108 | `malloc_type_descriptor_v0_t` | missing | 1 | swift-foundation | libmalloc |
| 109 | `malloc_type_descriptor_v0_t members` | missing | 1 | swift-foundation | C struct members (MemberImportVisibility) |
| 110 | `malloc_type_malloc` | missing | 1 | swift-foundation | libmalloc |
| 111 | `malloc_type_realloc` | missing | 1 | swift-foundation | libmalloc |
| 112 | `MAXSYMLINKS` | missing | 1 | swift-foundation | compile-time limits |
| 113 | `mkstemps` | missing | 1 | swift-tools-support-core | mkstemps |
| 114 | `mktemp` | missing | 1 | swift-foundation | temporary files |
| 115 | `nfds_t` | missing | 1 | swift-nio | nfds_t |
| 116 | `O_SEARCH` | missing | 1 | swift-foundation | O_SEARCH |
| 117 | `O_WRONLY` | covered (doc comment) | 1 | swift-nio | O_WRONLY |
| 118 | `open` | covered (doc comment) | 1 | swift-nio | open |
| 119 | `PF_VSOCK` | covered (doc comment) | 1 | swift-nio | vsock |
| 120 | raw posix_spawn path | unread | 1 | swift-subprocess | raw posix_spawn path |
| 121 | `recvmsg` | covered (doc comment) | 1 | swift-nio | recvmsg |
| 122 | `remove` | covered (doc comment) | 1 | swift-nio | remove |
| 123 | `removefile` | missing | 1 | swift-foundation | removefile |
| 124 | `removefile_flags_t` | missing | 1 | swift-foundation | removefile |
| 125 | `REMOVEFILE_PROCEED` | missing | 1 | swift-foundation | removefile |
| 126 | `REMOVEFILE_RECURSIVE` | missing | 1 | swift-foundation | removefile |
| 127 | `REMOVEFILE_SKIP` | missing | 1 | swift-foundation | removefile |
| 128 | `removefile_state_alloc` | missing | 1 | swift-foundation | removefile |
| 129 | `REMOVEFILE_STATE_CONFIRM_CALLBACK` | missing | 1 | swift-foundation | removefile |
| 130 | `REMOVEFILE_STATE_CONFIRM_CONTEXT` | missing | 1 | swift-foundation | removefile |
| 131 | `REMOVEFILE_STATE_ERRNO` | missing | 1 | swift-foundation | removefile |
| 132 | `REMOVEFILE_STATE_ERROR_CALLBACK` | missing | 1 | swift-foundation | removefile |
| 133 | `REMOVEFILE_STATE_ERROR_CONTEXT` | missing | 1 | swift-foundation | removefile |
| 134 | `removefile_state_free` | missing | 1 | swift-foundation | removefile |
| 135 | `removefile_state_get` | missing | 1 | swift-foundation | removefile |
| 136 | `removefile_state_set` | missing | 1 | swift-foundation | removefile |
| 137 | `removefile_state_t` | missing | 1 | swift-foundation | removefile |
| 138 | `REMOVEFILE_STOP` | missing | 1 | swift-foundation | removefile |
| 139 | `RTLD_LAZY` | covered (doc comment) | 1 | swift-nio | dynamic loader |
| 140 | `RTLD_NOW` | covered (doc comment) | 1 | swift-nio | dynamic loader |
| 141 | `sendfile` | covered (doc comment) | 1 | swift-nio | sendfile |
| 142 | `sendmsg` | covered (doc comment) | 1 | swift-nio | sendmsg |
| 143 | `setbuf` | not System's (C stdio) | 1 | swift-nio | C stdio |
| 144 | `setenv` | covered (doc comment) | 1 | swift-nio | environment |
| 145 | `setlocale` | not System's (locale) | 1 | swift-foundation | locale |
| 146 | `setsockopt` | covered (doc comment) | 1 | swift-nio | setsockopt |
| 147 | `setvbuf` | not System's (C stdio) | 1 | swift-log | C stdio |
| 148 | `sin` | not System's (libm) | 1 | swift-foundation | libm |
| 149 | `sockaddr_storage` | covered (doc comment) | 1 | swift-nio | sockaddr_storage |
| 150 | `sockaddr_vm` | covered (doc comment) | 1 | swift-nio | vsock |
| 151 | `strftime` | covered (doc comment) | 1 | swift-log | calendar time |
| 152 | `strncasecmp_l` | not System's (locale) | 1 | swift-foundation | locale |
| 153 | `strtod_l` | not System's (locale) | 1 | swift-foundation | locale |
| 154 | `strtof_l` | not System's (locale) | 1 | swift-foundation | locale |
| 155 | `tcp_connection_info` | covered (doc comment) | 1 | swift-nio | socket options |
| 156 | `time` | covered (as `clock_gettime`) | 1 | swift-log | calendar time |
| 157 | `time_t` | missing | 1 | swift-certificates | calendar time |
| 158 | `timespec` | covered (doc comment) | 1 | swift-nio | timespec |
| 159 | `timespec members` | covered (Swift-named accessors) | 1 | swift-nio | C struct members (MemberImportVisibility) |
| 160 | `timeval` | covered (doc comment; not yet in `system-next`) | 1 | swift-nio | socket options |
| 161 | `tm` | covered (doc comment) | 1 | swift-certificates | calendar time |
| 162 | `TSI_S_ESTABLISHED` | covered (doc comment) | 1 | swift-nio | socket options |
| 163 | `TZDEFAULT` | missing | 1 | swift-foundation | tzfile.h |
| 164 | `write` | covered (doc comment) | 1 | swift-nio | write |
| 165 | `writev` | covered (doc comment) | 1 | swift-nio | writev |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|
| 1 | compile-time limits | 5 | swift-foundation | `PATH_MAX`, `NAME_MAX`, `MAXSYMLINKS` |
| 2 | fts | 3 | swift-foundation | `FTS_D`, `FTS_DEFAULT`, `FTS_DNR`, `FTS_DP`, `FTS_ERR`, `fts_errno`, `FTS_F`, `fts_info`, `fts_level`, `FTS_NOCHDIR`, `FTS_NS`, `fts_path`, `FTS_PHYSICAL`, `FTS_SL`, `FTS_SLNONE`, `FTSENT`, `FTS`, `fts_close`, `fts_dev`, `fts_ino`, `fts_name`, `fts_namelen`, `FTS_NOSTAT`, `FTS_NSOK`, `fts_open`, `fts_read`, `fts_set`, `FTS_SKIP` |
| 3 | extended attributes | 2 | swift-nio | `XATTR_MAXNAMELEN` |
| 4 | file times | 2 | swift-nio | `UTIME_OMIT` |
| 5 | posix_spawn's raw attributes and file actions | 2 | swift-subprocess | posix_spawn's raw attributes and file actions |
| 6 | tzfile.h | 2 | swift-foundation | `TZDIR`, `TZDEFAULT` |
| 7 | C struct members (MemberImportVisibility) | 1 | swift-foundation | `malloc_type_descriptor_v0_t members` |
| 8 | calendar time | 1 | swift-certificates | `time_t` |
| 9 | dynamic loader | 1 | swift-tools-support-core | `dlerror` |
| 10 | libmalloc | 1 | swift-foundation | `malloc_type_calloc`, `malloc_type_descriptor_v0_t`, `malloc_type_malloc`, `malloc_type_realloc` |
| 11 | mkstemps | 1 | swift-tools-support-core | `mkstemps` |
| 12 | nfds_t | 1 | swift-nio | `nfds_t` |
| 13 | O_SEARCH | 1 | swift-foundation | `O_SEARCH` |
| 14 | removefile | 1 | swift-foundation | `removefile`, `removefile_flags_t`, `REMOVEFILE_PROCEED`, `REMOVEFILE_RECURSIVE`, `REMOVEFILE_SKIP`, `removefile_state_alloc`, `REMOVEFILE_STATE_CONFIRM_CALLBACK`, `REMOVEFILE_STATE_CONFIRM_CONTEXT`, `REMOVEFILE_STATE_ERRNO`, `REMOVEFILE_STATE_ERROR_CALLBACK`, `REMOVEFILE_STATE_ERROR_CONTEXT`, `removefile_state_free`, `removefile_state_get`, `removefile_state_set`, `removefile_state_t`, `REMOVEFILE_STOP` |
| 15 | sysexits | 1 | swift-argument-parser | `EX_USAGE` |
| 16 | temporary files | 1 | swift-foundation | `mktemp` |
| 17 | vsock | 1 | swift-nio | `AF_VSOCK` |

## Not System's

Recorded, not to be implemented. A name is counted here when System doesn't already wrap it; the families:

- **libm** (4 interfaces, 2 files): Math functions are the C library's, and the standard library's or swift-numerics' to offer; they aren't operating-system interfaces. `pow`, `cos`, `log`, `sin`.
- **C stdio** (10 interfaces, 5 files): Buffered `FILE` streams are the C library's layer over the descriptors System wraps; print shares stdout's buffer, so a Swift replacement belongs with print. `stdout`, C stdio FILE streams, `fdopen`, `fflush`, `FILE`, `flockfile`, `funlockfile`, `fwrite`, `setbuf`, `setvbuf`.
- **locale** (6 interfaces, 2 files): The C library's locale machinery (locale.h, xlocale.h); locales are Foundation's. `LC_ALL`, `locale_t`, `setlocale`, `strncasecmp_l`, `strtod_l`, `strtof_l`.
- **string.h and ctype.h** (2 interfaces, 5 files): The C library's string and character utilities, and the memory calls the standard library has: copyMemory and initializeMemory are memcpy, memmove and memset. (System's Memory has memcmp and memchr, which it doesn't.) `memcpy`, `memset`.
- **C numeric conversion**: Parsing and formatting numbers is the standard library's. (No marker names one now.)
- **the Darwin overlay's Swift types** (1 interface, 3 files): POSIXErrorCode is the Darwin overlay's Swift enum, in Foundation's public API and ABI; System's Errno can't stand in for it there. `POSIXErrorCode`.

## Markers that name no C interface

- swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`: the raw posix_spawn path, for what System's spawn

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- `usleep` (covered): swift-nio: `IntegrationTests/allocation-counter-tests-framework/template/scaffolding.swift:19` (outside the targets); swift-nio: `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift:22`; swift-nio: `Tests/NIOCoreTests/XCTest+Extensions.swift:19`; swift-nio: `Tests/NIOEmbeddedTests/TestUtils.swift:21`; swift-nio: `Tests/NIOHTTP1Tests/HTTPServerUpgradeTests.swift:24`; swift-nio: `Tests/NIOHTTP1Tests/TestUtils.swift:32`; swift-nio: `Tests/NIOPosixTests/ChannelTests.swift:30`; swift-nio: `Tests/NIOPosixTests/NIOFileHandleTest.swift:27`; swift-nio: `Tests/NIOPosixTests/SelectorTest.swift:27`; swift-nio: `Tests/NIOPosixTests/StreamChannelsTest.swift:29`; swift-nio: `Tests/NIOPosixTests/TestUtils.swift:29`; swift-nio: `Tests/NIOTestUtilsTests/NIOHTTP1TestServerTest.swift:22`
- `iovec members` (covered): swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:23`; swift-nio: `Sources/NIOPosix/PendingDatagramWritesManager.swift:26`; swift-nio: `Sources/NIOPosix/PendingWritesManager.swift:23`; swift-nio: `Sources/NIOPosix/Socket.swift:23`; swift-nio: `Tests/NIOPosixTests/ChannelTests.swift:32`; swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:25`; swift-nio: `Tests/NIOPosixTests/SyscallAbstractionLayer.swift:60`
- `msghdr members` (covered): swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:21`; swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:23`; swift-nio: `Sources/NIOPosix/PendingDatagramWritesManager.swift:26`; swift-nio: `Sources/NIOPosix/Socket.swift:23`; swift-nio: `Tests/NIOPosixTests/ControlMessageTests.swift:21`; swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:25`
- `sockaddr_in members` (covered): swift-nio: `Sources/NIOMulticastChat/main.swift:20`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:29`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:26`; swift-nio: `Tests/NIOPosixTests/ChannelPipelineTest.swift:26`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:24`; swift-nio: `Tests/NIOPosixTests/MulticastTest.swift:20`
- `free` (covered): swift-nio: `IntegrationTests/allocation-counter-tests-framework/template/scaffolding.swift:19` (outside the targets); swift-nio: `Tests/NIOCoreTests/ByteBufferCrashTests.swift:20`; swift-nio: `Tests/NIOCoreTests/ByteBufferCustomAllocatorTest.swift:21`; swift-nio: `Tests/NIOCoreTests/ByteBufferTest.swift:24`; swift-nio: `Tests/NIOPosixTests/CodecTest.swift:23`
- `in_addr members` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:29`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:26`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:24`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:34`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:31`
- `memcpy` (not System's): swift-nio: `Tests/NIOCoreTests/ByteBufferCrashTests.swift:20`; swift-nio: `Tests/NIOCoreTests/ByteBufferCustomAllocatorTest.swift:21`; swift-nio: `Tests/NIOCoreTests/ByteBufferTest.swift:24`; swift-nio: `Tests/NIOPosixTests/CodecTest.swift:23`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:31`
- `malloc` (covered): swift-nio: `Tests/NIOCoreTests/ByteBufferCrashTests.swift:20`; swift-nio: `Tests/NIOCoreTests/ByteBufferCustomAllocatorTest.swift:21`; swift-nio: `Tests/NIOCoreTests/ByteBufferTest.swift:24`; swift-nio: `Tests/NIOPosixTests/CodecTest.swift:23`
- `memset` (not System's): swift-nio: `Tests/NIOCoreTests/ByteBufferCrashTests.swift:20`; swift-nio: `Tests/NIOCoreTests/ByteBufferCustomAllocatorTest.swift:21`; swift-nio: `Tests/NIOCoreTests/ByteBufferTest.swift:24`; swift-nio: `Tests/NIOPosixTests/CodecTest.swift:23`
- `realloc` (covered): swift-nio: `Tests/NIOCoreTests/ByteBufferCrashTests.swift:20`; swift-nio: `Tests/NIOCoreTests/ByteBufferCustomAllocatorTest.swift:21`; swift-nio: `Tests/NIOCoreTests/ByteBufferTest.swift:24`; swift-nio: `Tests/NIOPosixTests/CodecTest.swift:23`
- `memcmp` (covered): swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:31`; swift-syntax: `Sources/SwiftCompilerPluginMessageHandling/JSON/JSONDecoding.swift:16`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:15`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:27`
- `in6_addr members` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:29`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:24`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:34`
- `IP_RECVTOS` (covered): swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:22`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:22`; swift-nio: `Tests/NIOPosixTests/SystemTest.swift:23`
- `linger` (covered): swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:18`; swift-nio: `Tests/NIOPosixTests/SocketChannelTest.swift:25`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:26`
- `PATH_MAX` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:30`; swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:34`; swift-foundation: `Tests/FoundationEssentialsTests/StringTests.swift:17`
- `POSIXErrorCode` (not System's): swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:20`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:20`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:21`; swift-foundation: `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift:30`
- `sockaddr members` (covered): swift-nio: `Sources/NIOPosix/BaseSocket.swift:24`; swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:25`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:34`
- `sockaddr_in6 members` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:29`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:26`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:24`
- `stdout` (not System's): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`; swift-nio: `Sources/NIOPerformanceTester/main.swift:42`
- C stdio FILE streams (not System's): swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:15`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:16`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:17`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:18`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:19`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:20`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:21`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:22`; swift-tools-support-core: `Sources/TSCBasic/WritableByteStream.swift:23`; swift-tools-support-core: `Sources/TSCTestSupport/PseudoTerminal.swift:15`
- `cmsghdr members` (covered): swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:21`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:29`
- `dlopen` (covered): swift-nio: `Benchmarks/Benchmarks/NIOPosixBenchmarks/Util/GlobalExecutor.swift:16` (outside the targets); swift-nio: `Sources/NIOPosix/PosixSingletons+ConcurrencyTakeOver.swift:22`
- `dlsym` (covered): swift-nio: `Benchmarks/Benchmarks/NIOPosixBenchmarks/Util/GlobalExecutor.swift:16` (outside the targets); swift-nio: `Sources/NIOPosix/PosixSingletons+ConcurrencyTakeOver.swift:22`
- `errno` (covered): swift-nio: `Sources/NIOPosix/System.swift:42`; swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:23`
- `FTS_D` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_DEFAULT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_DNR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_DP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_ERR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_errno` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_F` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_info` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_level` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_NOCHDIR` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:23`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_NS` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `fts_path` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_PHYSICAL` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:23`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_SL` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTS_SLNONE` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `FTSENT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:18`
- `getenv` (covered): swift-nio: `Sources/NIOPosix/SelectableEventLoop.swift:27`; swift-nio: `Tests/NIOFSIntegrationTests/FileSystemTests.swift:21`
- `if_nametoindex` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:28`
- `IP_TTL` (covered): swift-nio: `Tests/NIOEmbeddedTests/AsyncTestingChannelTests.swift:26`; swift-nio: `Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift:27`
- `mkdtemp` (covered): swift-nio: `Tests/NIOHTTP1Tests/TestUtils.swift:29`; swift-nio: `Tests/NIOPosixTests/TestUtils.swift:26`
- `mkstemp` (covered): swift-nio: `Tests/NIOHTTP1Tests/TestUtils.swift:29`; swift-nio: `Tests/NIOPosixTests/TestUtils.swift:26`
- `NAME_MAX` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:30`; swift-foundation: `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift:28`
- posix_spawn's raw attributes and file actions (missing): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:14`; swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `pow` (not System's): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`; swift-foundation: `Tests/FoundationInternationalizationTests/Formatting/DiscreteFormatStyleTestUtilities.swift:23`
- `SO_LINGER` (covered): swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:18`; swift-nio: `Tests/NIOPosixTests/SocketChannelTest.swift:25`
- `sockaddr_storage members` (covered): swift-nio: `Sources/NIOPosix/BaseSocket.swift:24`; swift-nio: `Sources/NIOPosix/VsockAddress.swift:27`
- `TZDIR` (missing): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone.swift:405`; swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:36`
- `UTIME_NOW` (covered): swift-nio: `Sources/NIOFS/FileInfo.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:18`
- `UTIME_OMIT` (missing): swift-nio: `Sources/NIOFS/FileInfo.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:18`
- `XATTR_MAXNAMELEN` (missing): swift-nio: `Sources/NIOFS/FileSystemError+Syscall.swift:18`; swift-nio: `Sources/_NIOFileSystem/FileSystemError+Syscall.swift:18`
- `AF_VSOCK` (missing): swift-nio: `Sources/NIOPosix/VsockAddress.swift:23`
- `close` (covered): swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:23`
- `cos` (not System's): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`
- `dirent` (covered): swift-tools-support-core: `Sources/TSCBasic/FileSystem.swift:18`
- `dlerror` (missing): swift-tools-support-core: `Sources/TSCUtility/dlopen.swift:18`
- `DT_BLK` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_CHR` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_DIR` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_FIFO` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_LNK` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_REG` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_SOCK` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `DT_WHT` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:21`
- `EX_USAGE` (missing): swift-argument-parser: `Sources/ArgumentParser/Utilities/Platform.swift:25`
- `exit` (covered): swift-nio: `Tests/NIOPosixTests/EventLoopCrashTests.swift:23`
- `fdopen` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fflush` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FILE` (not System's): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:17`
- `flockfile` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `FTS` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_close` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_dev` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_ino` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_name` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_namelen` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `FTS_NOSTAT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:23`
- `FTS_NSOK` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_open` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_read` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `fts_set` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `FTS_SKIP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:119`
- `funlockfile` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `fwrite` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `getsockopt` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `gmtime_r` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `in6_pktinfo` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:22`
- `in_pktinfo` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:22`
- `INADDR_ANY` (covered): swift-nio: `Sources/NIOPosix/SocketChannel.swift:22`
- `inet_pton` (covered): swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:28`
- `ioctl` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `ip_mreq` (covered): swift-nio: `Sources/NIOPosix/SocketChannel.swift:22`
- `IP_PKTINFO` (covered): swift-nio: `Sources/NIOPosix/System.swift:36`
- `IP_RECVDSTADDR` (covered): swift-nio: `Tests/NIOPosixTests/SystemTest.swift:23`
- `IP_RECVPKTINFO` (covered): swift-nio: `Sources/NIOPosix/System.swift:36`
- `IP_TOS` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:22`
- `ipv6_mreq` (covered): swift-nio: `Sources/NIOPosix/SocketChannel.swift:22`
- `IPV6_RECVTCLASS` (covered): swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:22`
- `IPV6_TCLASS` (covered): swift-nio: `Sources/NIOPosix/ControlMessage.swift:22`
- `LC_ALL` (not System's): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `locale_t` (not System's): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `localtime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `log` (not System's): swift-foundation: `Tests/FoundationInternationalizationTests/Formatting/DiscreteFormatStyleTestUtilities.swift:23`
- `malloc_type_calloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_descriptor_v0_t` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_descriptor_v0_t members` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:17`
- `malloc_type_malloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `malloc_type_realloc` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:16`
- `MAXSYMLINKS` (missing): swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:17`
- `mkstemps` (missing): swift-tools-support-core: `Sources/TSCBasic/TemporaryFile.swift:15`
- `mktemp` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:28`
- `nfds_t` (missing): swift-nio: `Sources/NIOPosix/System.swift:56`
- `O_SEARCH` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:26`
- `O_WRONLY` (covered): swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:23`
- `open` (covered): swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:23`
- `PF_VSOCK` (covered): swift-nio: `Sources/NIOPosix/VsockAddress.swift:23`
- raw posix_spawn path (unread): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:306`
- `recvmsg` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `remove` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `removefile` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_flags_t` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_PROCEED` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_RECURSIVE` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_SKIP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_alloc` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_CONFIRM_CALLBACK` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_CONFIRM_CONTEXT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERRNO` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERROR_CALLBACK` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STATE_ERROR_CONTEXT` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_free` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_get` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_set` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `removefile_state_t` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `REMOVEFILE_STOP` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:33`
- `RTLD_LAZY` (covered): swift-nio: `Benchmarks/Benchmarks/NIOPosixBenchmarks/Util/GlobalExecutor.swift:16` (outside the targets)
- `RTLD_NOW` (covered): swift-nio: `Sources/NIOPosix/PosixSingletons+ConcurrencyTakeOver.swift:22`
- `sendfile` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `sendmsg` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `setbuf` (not System's): swift-nio: `Sources/NIOPerformanceTester/main.swift:42`
- `setenv` (covered): swift-nio: `Tests/NIOPosixTests/StrictCrashTests.swift:3`
- `setlocale` (not System's): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:17`
- `setsockopt` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`
- `setvbuf` (not System's): swift-log: `Tests/LoggingTests/StreamLogHandlerTest.swift:22`
- `sin` (not System's): swift-foundation: `Sources/FoundationEssentials/Calendar/Calendar_Astronomy.swift:17`
- `sockaddr_storage` (covered): swift-nio: `Sources/NIOPosix/System.swift:56`
- `sockaddr_vm` (covered): swift-nio: `Sources/NIOPosix/VsockAddress.swift:23`
- `strftime` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `strncasecmp_l` (not System's): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strtod_l` (not System's): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `strtof_l` (not System's): swift-foundation: `Sources/FoundationEssentials/Platform.swift:22`
- `tcp_connection_info` (covered): swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:26`
- `time` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:23`
- `time_t` (missing): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `timespec` (covered): swift-nio: `Sources/NIOPosix/System.swift:56`
- `timespec members` (covered): swift-nio: `Tests/NIOFSTests/FileInfoTests.swift:22`
- `timeval` (covered): swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:26`
- `tm` (covered): swift-certificates: `Tests/X509Tests/TimeTests.swift:19`
- `TSI_S_ESTABLISHED` (covered): swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:26`
- `TZDEFAULT` (missing): swift-foundation: `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift:36`
- `write` (covered): swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:23`
- `writev` (covered): swift-nio: `Sources/NIOPosix/System.swift:44`

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
- **Not System's** is a fixed list of families in `scripts/status.py` (libm, C stdio, locale and xlocale,
  string.h and ctype.h, numeric conversion, the Darwin overlay's POSIXErrorCode), matched by name or by the
  name's SDK module in adopter-coverage's stored vocabulary when there is one. It applies only to what System
  doesn't wrap already.
- **Families** group the ranked interfaces for the work list: a fixed map of name patterns to System's
  clusters, else the marker's phrase, else the name itself.
