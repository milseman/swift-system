# linux-3: the adopters' Unix gaps on Linux, Musl and Android

Lane `linux-3` (worktree `../linux-3`, branch `linux-3`, base system-next `bb950db`, the 2026-10-01 convergence
merge). Goal: System covers on Linux (glibc), Musl and Android what the adopters' Unix code needs, so their sites
collapse to one System call. The gaps are `../adopters-unix/UNIX-REPORT.md` section 6 (and its section 3, the
System-wide ones) and `../adopters/PACKAGES-5-REPORT.md` "Gaps, across platforms".

Linux runs are swift:6.2-noble on arm64 (Swift 6.2.4, glibc 2.39, kernel 6.18), through `Utilities/linux/build.sh
--quiet`, with logs in `../linux-logs/linux-3-<commit>-<what>.log`. Musl, Android, FreeBSD and OpenBSD are checked
from headers: Musl 1.2.5's in the static SDK (`../linux-logs/cross/sdks/`), Bionic's, FreeBSD's and OpenBSD's
through the GitHub API (`aosp-mirror/platform_bionic`, `freebsd/freebsd-src`, `openbsd/src`).

## Resume here

- **Done** (step 1, every gap):
  - `ef379e6`, `7670d0c` `PThread.Condition.wait(on:timeout:)` off Darwin (section 1).
  - `42616ac` the time zone paths on Android (3); `9d00c35` `UserEntry.realName` on 32-bit Android (4);
    `83e956c` `CLocale` on Android (5).
  - `c72fe57` `OpenOptions.pathOnly` (`O_PATH`, 6.3); `948f91e` `readSymbolicLinkPlatformString` (6.4);
    `a6478fb` `FileStream.seek(offset:from:)` and `offset()` (6.5).
  - SystemSockets isn't this lane's: `TCPOption.info` on FreeBSD (2), vsock (6.1) and UDP offload (6.2) are
    patches, Appendix A and B, tested in a scratch copy on Linux and Darwin.
- **In progress**: step 2, swift-foundation's `migrate-unix` on Linux (section 7).
- **Next**: section 7's runs; then "For unix-adopt-2" from what fails.
- **Latest tests**, at `a6478fb`: Darwin, XCTest 575 tests, 5 skipped, 0 failures; swift-testing 503 tests in 82
  suites passed. Linux as root (`linux-3-a6478fb-root.log`), XCTest 486 tests, 6 skipped, 0 failures;
  swift-testing 473 tests in 79 suites passed; as 1000:1000 (`linux-3-a6478fb-user.log`), 486 tests, 4 skipped,
  0 failures, and 473 tests in 79 suites passed.
- **Scratch**: `.build/linux-3-patches` (the patches), `.build/linux-3-sockets` and `.build/linux-3-base` (the
  patched and unpatched copies), `.build/linux-3-sockets-darwin`; delete them once the patches are taken.
- **How to run**: `container system start >/dev/null 2>&1; Utilities/linux/build.sh --quiet --log
  ../linux-logs/linux-3-$(git rev-parse --short HEAD)-<what>.log test`, with `--user 1000:1000` and `--
  --filter <Suite>`; commit first. A patched copy: `--root .build/linux-3-sockets` and an absolute `--log`.

## For unix-adopt-2

What each gap's API lets collapse, per package and file (the sites are UNIX-REPORT's). None of these was built
here: they're the edits the new API allows.

**swift-nio**

- `Sources/NIOConcurrencyHelpers/lock.swift`, `ConditionLock` (6 sites: the condition's storage, init, wait,
  timed wait, broadcast and destroy): the `canImport(Darwin)` branches, over `PThread.Condition` and
  `wait(on:timeout:)`, widen to `os(Linux) || os(Android)`, where `NIOLock`'s mutex is System's already; the C
  branches stay for Windows and WASI. FreeBSD and OpenBSD have System's condition too (from headers), but
  `NIOLock`'s mutex there is C, so they widen only with it. On Linux the relative wait is measured on the
  condition's clock, realtime by default, as NIO's C wait (a `gettimeofday` deadline) is today; for Darwin's
  behavior, create the condition with `attributes.clock = .monotonic` off Darwin (section 1).
- After Appendix A: `NIOBSDSocket.Option.tcp_info` is `SocketDescriptor.TCPOption.info.rawValue`, and
  `getTCPInfo()` and `_getTCPInfo()` return `CInterop.TCPInfo`, on Linux, Android and FreeBSD (3 sites); the
  `import Glibc` kept for `tcp_info` goes.
- After Appendix B: `VsockAddress.swift`'s Linux branch is System's (`VMSocketAddress`, `SocketAddress(vsock:)`,
  `FileDescriptor.localContextID()` on `/dev/vsock`); `NIOBSDSocket.Option.udp_segment` and `.udp_gro` are
  `SocketDescriptor.UDPOption.segmentSize` and `.receiveOffload` rather than 103 and 104.

**swift-foundation**

- `TimeZone/TimeZone_Cache.swift`: the `canImport(Darwin) || os(Linux)` branches (the default file's link
  through `FilePath.defaultTimeZoneFile.readSymbolicLink`, and `FilePath.timeZoneDirectory`) widen to Android,
  and the `readlink(TZDEFAULT)` and `TZDIR` branch goes. Behavior on Android is the same: the file is missing
  there, as Foundation's own `TZDEFAULT` was, and the localtime fallback runs.
- `Platform.swift`, `fullName(forUID:)`: the 32-bit Android conditional goes; `realName` is empty for a null
  `pw_gecos` there, as it already is on 64-bit Android under System, where Foundation's C path returned `nil`.
- `Platform.swift`, `cLocale`, `strncasecmp_clocale`, `strtod_clocale`, `strtof_clocale`, and
  `JSONEncoderTests.swift`'s `localeDecimalPolicyIndependence`: the `canImport(Darwin) || os(Linux)` branches
  widen to Android (section 5).
- `Data/Data+Writing.swift`, `minimalOpenFlagsForDirectories`: the `#else` branch (Linux, Android, FreeBSD) is
  `FileDescriptor.OpenOptions([.directory, .pathOnly]).rawValue`, its last C names on Linux.
- `FileManager/FileOperations.swift`, the Linux copy of a symbolic link (`FTS_SL`, `FTS_SLNONE`): `readlink` and
  `symlink` become `FilePath.readSymbolicLinkPlatformString(fts_path)` and `FilePath.makeSymbolicLink(_:to:)`
  with its result, which keeps the target's redundant and trailing separators (section 6.4).

**WasmKit**

- `Platform/AtomicParkingLot.swift`, `BlockingSlot`: the `canImport(Darwin)` slot, over `PThread.Mutex`,
  `PThread.Condition` and `wait(on:timeout:)`, widens to Linux, Musl and Android; to keep the C branch's
  monotonic clock, `attributes.clock = .monotonic` off Darwin. WASI's stays C (System has no `PThread` there).
- `CLICommands/Platform.swift`, the non-Darwin `CLIFile`: `seekToStart`'s `fseek` is
  `FileStream.seek(offset: 0, from: .start)`, and its other stdio calls are `FileStream`'s; or the Darwin
  `CLIFile`, over `FileDescriptor`, widens to Linux, Musl and Android.

## For packages-6

- PACKAGES-5's open gaps ("Gaps, across platforms") are WASI's (`PThread`, `ClockID`, `BrokenDownTime`,
  `FileStream.withLock` there) and Windows': none is on this lane's platforms.
- New on every Unix platform for the next collapses: `PThread.Condition.wait(on:timeout:)` (relative timed waits,
  where a package now spells `pthread_cond_timedwait` with a computed deadline), `FileStream.seek(offset:from:)`
  and `offset()`, and `FilePath.readSymbolicLinkPlatformString`. On Linux, Android and FreeBSD,
  `OpenOptions.pathOnly`. On Android, `CLocale`, `UserEntry.realName` on 32 bits, and the time zone paths.

## Baseline

At `bb950db`:

- Darwin (`swift build && swift test`): XCTest 572 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82
  suites passed.
- Linux as root (`linux-3-bb950db-baseline-root.log`): XCTest 482 tests, 6 skipped, 0 failures; swift-testing
  463 tests in 78 suites passed. As 1000:1000 (`linux-3-bb950db-baseline-user.log`): 482 tests, 4 skipped,
  0 failures; 463 tests in 78 suites passed.

## 1. `PThread.Condition.wait(on:timeout:)` off Darwin: `ef379e6`, `7670d0c`

UNIX-REPORT's rank 2: Darwin had the relative wait (`pthread_cond_timedwait_relative_np`); Linux, Musl, Android,
FreeBSD and OpenBSD didn't. Now `wait(on:timeout:)` is on every platform `PThread.Condition` is (all but Windows
and WASI). Off Darwin it reads the condition variable's clock with `clock_gettime`, adds the timeout, and waits
with `pthread_cond_timedwait` until that deadline.

- The C condition variable doesn't report its clock, so `Condition` keeps it off Darwin (`_clock`, from
  `Attributes.clock`), and `withUnsafeCondition(at:clock:_:)` takes the clock of a C condition variable it
  borrows, `.realtime` by default (C's default).
- A timeout that isn't positive times out at once (the deadline is now); a deadline past `time_t`'s last time is
  that time. A part of a nanosecond rounds up.
- Docs: the timeout is measured on the condition's clock off Darwin. On the default, realtime, setting the
  clock during the wait shortens or lengthens it; on `.monotonic` it doesn't, as on Darwin. `Attributes.clock`
  says it's the relative wait's clock too.

Design calls:

- Default: the condition's own clock, one mechanism on every C library (`clock_gettime` and
  `pthread_cond_timedwait` are everywhere), with C's semantics, and NIO's Linux behavior today.
- Rejected: `pthread_cond_clockwait(CLOCK_MONOTONIC)` where the C library has it (glibc 2.30, Bionic API 30,
  FreeBSD only since 2026-07; not Musl 1.2.5 or OpenBSD), which makes the timeout independent of the clock on
  some platforms and not others, needs a version check in a shim, and needs the stored clock for the rest
  anyway. Open: it's the way to Darwin's behavior for a default condition, if that's worth the difference
  between C libraries.
- Rejected: a monotonic default `Attributes.clock` off Darwin, which would make `wait(on:until:)`'s realtime
  deadlines (from `clock_gettime(CLOCK_REALTIME)`, as on Darwin) decades away on the monotonic clock.
- Rejected: throwing for a borrowed condition, whose clock is unknown, rather than taking it as a parameter.

Tests: `timeout` and `timeoutThatIsNotPositive` run everywhere now; `signalEndsATimedWait` (everywhere: a waiter
with a timeout only a hang reaches wakes for a signal, with the waiter known to be waiting through the mutex);
off Darwin `timeoutOnTheMonotonicClock`, `timeoutOnABorrowedConditionsClock` (a C condition on
`CLOCK_MONOTONIC`, borrowed with `clock: .monotonic`), `deadlineAfterATimeout` (carry, rounding, negative,
saturation), and the mock test `testRelativeWaitReadsTheConditionsClock` (the clock read for a default, a
monotonic and a borrowed condition; the deadline; a clock error thrown with no wait). `7670d0c` marks that mock
test `throws`, for the `try` in `XCTAssertThrowsError`'s argument, which the first Linux build caught.

- Darwin: the suite's 11 tests passed. Linux (`linux-3-7670d0c-condition.log`): XCTest 11 tests (PThreadMockTests),
  0 failures; swift-testing 15 tests in 1 suite passed. FreeBSD and OpenBSD from headers:
  `pthread_condattr_setclock`, `clock_gettime` and `pthread_cond_timedwait` are in both; Musl's
  `pthread_cond_timedwait` is its time64 redirect, which the importer follows.
- Unblocks: NIO `ConditionLock` (6 sites), WasmKit's parking lot (1), as "For unix-adopt-2" says.

## 2. `TCPOption.info` and `CInterop.TCPInfo` on FreeBSD: Appendix A

UNIX-REPORT's rank 4 (NIO's `tcp_info` option, `getTCPInfo()`, `_getTCPInfo()`, whose branch is Linux's,
Android's and FreeBSD's). SystemSockets isn't this lane's, so this is a patch: the `CInterop.TCPInfo` alias and
`TCPOption.info` widen to FreeBSD; the Linux `SocketDescriptor.TCPInfo` wrapper, which reads the kernel's layout
by offsets, stays Linux's and Android's.

- From FreeBSD's `<netinet/tcp.h>`: `TCP_INFO` is 32 and `struct tcp_info` is declared under `__BSD_VISIBLE`
  (its default), with Linux's names and order for the fields it shares, padding for the rest, and its own; the
  header calls the layout unstable. Swift's FreeBSD module (named Glibc) includes `<netinet/tcp.h>`.
- Design: what NIO needs, the C type and the option, as NIO's public API returns `tcp_info`. Rejected: a
  FreeBSD `TCPInfo` wrapper with Swift accessors, for a layout its own header calls unstable, which nothing
  asks for.
- Tests: it applies to `a6478fb`; with Appendix B, in `.build/linux-3-sockets`, Linux
  (`linux-3-a6478fb-sockets-patches.log`) and Darwin pass (section 6.1). FreeBSD can't build here.

## 3. `FilePath.defaultTimeZoneFile` on Android: `42616ac`

UNIX-REPORT's rank 8 (Foundation's TimeZone_Cache reads `TZDEFAULT`'s link, in a branch that serves Android).
`timeZoneDirectory` and `defaultTimeZoneFile` widen to Android, as `/usr/share/zoneinfo` and `/etc/localtime`.

- Bionic has no public `<tzfile.h>`. Its tzcode's private one (`libc/tzcode/tzfile.h`) keeps those defaults,
  but `tzload` never reads them: it takes the zone's name from `TZ` or the `persist.sys.timezone` property and
  looks it up in the one `tzdata` file. So on Android both paths are missing, and the docs say why; code that
  reads the default file's link, as Foundation does, falls back as it does in a Linux container without time
  zone data.
- Rejected: leaving Android out (linux-api's call), which keeps Foundation's Android branch on `readlink` of its
  own `TZDEFAULT`, the same missing path; an API for the device's zone (the property), which is another API, not
  a file's path, and isn't asked for.
- Tests: `TimeZoneFilesLinuxTests` runs on Android too (built from headers only: no NDK here); on Linux it's
  unchanged and passes.

## 4. `UserEntry.realName` on 32-bit Android: `9d00c35`

UNIX-REPORT's rank 9. 32-bit Bionic's `struct passwd` has no `pw_gecos`: its header defines `pw_gecos` as
`pw_passwd`, which Swift can't import ("since they're both NULL"). `UserEntry` reads `pw_passwd` there, as C code
naming `pw_gecos` does, so `realName` is on every platform `UserEntry` is.

- Bionic leaves both null (`grp_pwd.cpp` zeroes the entry, `grp_pwd_file.cpp` sets them to `nullptr`), so
  `realName` is empty on Android, 64-bit included.
- `testUserEntry` compares `realName` with `pw_gecos` (`pw_passwd` on 32-bit Android), a null one as empty;
  before, a null `pw_gecos` would have failed it on 64-bit Android.
- Unblocks: Foundation `Platform.fullName` (its inner conditional).

## 5. `CLocale` on Android: `83e956c`

UNIX-REPORT's section 3 (Foundation's `Platform.swift` and `JSONEncoderTests.swift`; linux-api's batch 3 left
Android out because Bionic's `strtod_l` and `strtof_l` start at API level 26).

- Bionic has `newlocale`, `freelocale`, `setlocale` and `LC_GLOBAL_LOCALE` at every level. Its header calls
  `strtod_l` and `strtof_l` "equivalent to strtod()" (26), and `strings_l.cpp` makes `strncasecmp_l` (23)
  `strncasecmp`: they ignore the locale. So on Android `parseDouble`, `parseFloat` and `compareIgnoringCase`
  call `strtod`, `strtof` and `strncasecmp`, at any API level, with no shim.
- Bionic's `LC_ALL_MASK`, like glibc's, ORs twelve masks, which Swift can't import, so
  `_system_get_LC_ALL_MASK` moves from glibc and Musl to every Linux C library (`CSystemLinux.h`, `shims.c`);
  the `strtod_l` shims stay glibc's and Musl's, and their comment is back above them in `CSystemLinux.h`, where
  the spawn shim's had split it.
- Docs: Bionic has only the POSIX locale's rules; of the names it accepts, `C` and `POSIX` are the POSIX locale
  and `C.UTF-8` and `en_US.UTF-8` the same with UTF-8 characters, which `globalName(for:)` names `C.UTF-8`
  (`locale.cpp`); its `newlocale` ignores the base, which it doesn't free.
- Rejected: shims calling `strtod_l` from level 26 and `strtod` below it: the same functions, with more code.
- Tests: `ProvisionalLocaleLinuxTest` runs on Android too (built from headers only), with glibc's expectations
  where Bionic's are the same (the categories, the mask, `no_SUCH.locale` failing) and French skipped. On Linux
  it's unchanged: the full runs at `83e956c` (`linux-3-83e956c-root.log`) and later pass.

## 6. Section 3's System-wide gaps

### 6.1 vsock on Linux and Android: Appendix B

linux-api's patch (its Appendix A, against `6a9833f`) no longer applied: its `CSystemLinux.h` and `shims.c` hunks'
context had moved. Refreshed here, with its design unchanged (`CInterop.SockAddrVM` a Swift structure with the
kernel's layout, checked in `shims.c`; `FileDescriptor.localContextID()` on `/dev/vsock`), and one fix: in
`aSocketNeedsVMSockets`, the error is `any Error` (the `do` block's `close()` throws untyped), so it's compared
as `Errno`, which the first Linux build caught.

- Tests, with Appendices A and B in `.build/linux-3-sockets` (`git archive` of `a6478fb`): Linux as root
  (`linux-3-a6478fb-sockets-patches.log`), XCTest 486 tests, 6 skipped, 0 failures; swift-testing 481 tests in 81
  suites passed, the VM sockets suite's five tests among them (the container has no vsock transport, so the
  socket and device tests take their no-transport branches). Darwin (`--scratch-path
  .build/linux-3-sockets-darwin`), XCTest 575 tests, 5 skipped, 0 failures; swift-testing 503 tests in 82 suites
  passed.

### 6.2 UDP offload: Appendix B

NIO hardcodes `UDP_SEGMENT` (103) and `UDP_GRO` (104), at `IPPROTO_UDP`, in `<netinet/udp.h>`, which glibc's and
Bionic's Swift modules don't include (Musl's does). The patch adds `SocketDescriptor.UDPOption` (Linux and
Android) with `segmentSize` (`UDP_SEGMENT`) and `receiveOffload` (`UDP_GRO`), as the kernel's numbers, which
`shims.c` checks against the header where it defines them, and `getUDPOption(_:)` and `setUDPOption(_:to:)`, as
the IP levels have.

- Names: what the value is (`segmentSize`, after `TCPOption.maxSegmentSize`) and what it turns on
  (`receiveOffload`, NIO's name). Rejected: shims returning the header's values, for numbers that are the same
  on every architecture; no accessors, which NIO's raw-value use doesn't need but the IP levels have.
- Tests: `SocketUDPOptionsTests` (both values read back as set, or `ENOPROTOOPT` on an older kernel; not a TCP
  socket's), in the runs above.

### 6.3 `O_PATH`: `c72fe57`

`FileDescriptor.OpenOptions.pathOnly` on Linux, Android and FreeBSD: a descriptor for a file's location that
doesn't open the file, for `relativeTo` calls, `stat`, `close` and `duplicate`; reading and writing throw
`badFileDescriptor`, and opening needs no permission on the file.

- glibc declares `O_PATH` only with `_GNU_SOURCE`, so on Linux and Android it comes from a `shims.c` getter beside
  `O_TMPFILE`'s (its value differs by architecture); FreeBSD's `<fcntl.h>` has it (14 and later, under
  `__BSD_VISIBLE`); Musl's `bits/fcntl.h` has it unconditionally.
- Design: an option, as in C, since `O_PATH` makes the access mode irrelevant; named for what the descriptor is
  for, as `eventOnly` (`O_EVTONLY`) is; an unavailable `O_PATH` stub, as the other options have. Darwin has no
  `O_PATH`; its nearest, for a directory, is `AccessMode.search` (`O_SEARCH`), which Musl defines as `O_PATH`
  and FreeBSD as `O_EXEC`: a possible widening of `search`, not done here. Not in `OpenOptions.description`,
  whose Linux list has none of the newer options.
- Tests (`PathOnlyDescriptorTests`): the flag; a directory's descriptor resolves a relative `stat` and `open` but
  can't be read; a file with no permissions opens, stats and duplicates, but can't be read or written; with
  `noFollow` a dangling link's descriptor is the link's. Linux (`linux-3-c72fe57-pathonly.log`): 4 tests
  passed, and in the full runs as root and as 1000:1000.
- Unblocks: Foundation's `minimalOpenFlagsForDirectories` (Linux, Android, FreeBSD).

### 6.4 A byte-exact `readSymbolicLink`: `948f91e`

`FilePath.readSymbolicLinkPlatformString(retryOnInterrupt:)`, with C-string and `relativeTo` forms, as
`readSymbolicLink` has: the link's contents as a null-terminated `[CInterop.PlatformChar]`. A `FilePath` drops a
target's redundant separators and a trailing one (`a//b/` reads as `a/b`), and a trailing separator matters (the
link then resolves only to a directory), so a copy made from `readSymbolicLink` isn't always the same link. The
contents pass to `makeSymbolicLink(_:to:)` as they are (an array passes as the pointer), and
`FilePath(platformString:)` makes the same path from them as `readSymbolicLink` returns. The two share
`readSymbolicLink`'s loop, which now returns the `SystemString` it read.

- The `FilePath` forms of `makeSymbolicLink` now say a `FilePath` target has no redundant or trailing separators,
  and that a C string keeps them: the new test found that a link made from the `FilePath` `"a//b/"` stores `a/b`.
- Name: after `withPlatformString` and `init(platformString:)`, System's name for a path's C string. Rejected: a
  closure form (`withSymbolicLinkContents`), which saves one array but not the read buffer; `String`, which isn't
  byte-exact for contents that aren't UTF-8; a public `SystemString`.
- Tests: four mock cases; `testReadSymbolicLinkPlatformString` (exact contents, an exact copy, a target longer
  than the first buffer, the `relativeTo` forms, `EINVAL` and `ENOENT`). Darwin: the 17 `FilePathOperationsTest`
  tests passed; Linux (`linux-3-948f91e-readlink.log`): 16 (one is Darwin's), 0 failures.
- Unblocks: Foundation's Linux copy of a symbolic link. Every Unix platform.

### 6.5 `FileStream` seek and tell: `a6478fb`

`FileStream.seek(offset:from:)` (`fseeko`) and `offset()` (`ftello`), on every platform `FileStream` is (all but
Windows): the shapes of `FileDescriptor.seek(offset:from:)`, an `Int64` and a `SeekOrigin`. `offset()` counts the
stream's buffer: after unflushed writes, before what was read ahead.

- `fseeko` and `ftello`, not `fseek` and `ftell`, whose `long` is 32 bits on wasm32 and 32-bit Android; Musl
  declares them by default (`_BSD_SOURCE`), wasi-libc and Bionic always.
- `seek` returns nothing, as `fseeko` does, rather than the new offset as `FileDescriptor`'s does, which would add
  an `ftello` to each call. Rejected names: `position()`, `tell()`.
- Tests: mock cases for both; `testSeekingAndTheOffset` (each origin, buffered writes and reads counted, a write
  after a seek, a negative position's `EINVAL`); `testAPipeHasNoPosition` (`ESPIPE`). Darwin: the 10
  `ProvisionalStdioTest` tests passed; Linux: the full runs at `a6478fb`.
- Unblocks: WasmKit `CLICommands/Platform.swift`.

## 7. swift-foundation's `migrate-unix` on Linux

In progress.

## Findings

- **A `FilePath` symbolic link target is normalized too**: `makeSymbolicLink(to: FilePath("a//b/"))` stores `a/b`,
  so neither the read nor the write side of a `FilePath` copy of a link is byte-exact; the C-string forms are
  (section 6.4).
- **Bionic's `*_l` functions ignore the locale**, and its locales differ only in encoding, so `CLocale` needs no
  API level on Android (section 5).
- **Android has no time zone files**: the paths are tzcode's defaults, which Bionic doesn't read (section 3).

## Needs outside this lane's files

- SystemSockets (Sources/SystemSockets, Tests/SystemSocketsTests): Appendix A (FreeBSD `TCPInfo`) and Appendix B
  (vsock and UDP offload on Linux and Android, with their `CSystemLinux.h` and `shims.c` parts). Both apply to
  `a6478fb` with `git apply`; Appendix B's C part is in this lane's files, but goes with its Swift, so it's in the
  patch rather than committed alone.
- Tests/MemberImportVisibility: a probe for `CInterop.SockAddrVM` on Linux, once Appendix B lands (linux-api's
  note); none of this lane's API vends a new C type's members.
- Utilities/linux: nothing needed. A Musl build of SystemPackage (`Utilities/linux/cross.sh musl build --
  --target SystemPackage`) would check sections 1, 5, 6.3 and 6.5 on Musl; it isn't this lane's Linux command,
  so they're checked against the static SDK's headers.

## Appendix A: `TCPOption.info` and `CInterop.TCPInfo` on FreeBSD, the patch

Against `a6478fb`; apply with `git apply`.

<details>
<summary>Sources/SystemSockets/Sockets/SocketTCPInfo.swift (15 lines added)</summary>

```diff
--- a/Sources/SystemSockets/Sockets/SocketTCPInfo.swift
+++ b/Sources/SystemSockets/Sockets/SocketTCPInfo.swift
@@ -465,14 +465,18 @@
 
 #endif // SYSTEM_PACKAGE_DARWIN
 
-// MARK: - Linux: tcp_info
+// MARK: - Linux and FreeBSD: tcp_info
 
-#if os(Linux) || os(Android)
+#if os(Linux) || os(Android) || os(FreeBSD)
 
 @available(System 199, *)
 extension CInterop {
-  /// The C library's declaration of `struct tcp_info`,
-  /// which can be older, and shorter, than the kernel's.
+  /// The C library's declaration of `struct tcp_info`.
+  ///
+  /// On Linux it can be older, and shorter, than the kernel's.
+  /// FreeBSD's has Linux's names and order for the fields it shares,
+  /// padding for the ones it doesn't fill in, and fields of its own,
+  /// in a layout that its header calls unstable.
   ///
   /// The corresponding C type is `struct tcp_info`.
   public typealias TCPInfo = tcp_info
@@ -482,13 +486,19 @@
 extension SocketDescriptor.TCPOption {
   /// The state and statistics of a TCP connection, read-only.
   ///
+  /// On FreeBSD, read it into a ``CInterop/TCPInfo``.
+  ///
   /// The corresponding C constant is `TCP_INFO`.
   ///
-  /// - Note: Only available on Linux and Android.
+  /// - Note: Only available on Linux, Android and FreeBSD.
   @_alwaysEmitIntoClient
   public static var info: Self { Self(rawValue: TCP_INFO) }
 }
 
+#endif // os(Linux) || os(Android) || os(FreeBSD)
+
+#if os(Linux) || os(Android)
+
 // The kernel's struct tcp_info, which only grows. glibc declares its first
 // 104 bytes; System reads those through glibc's declaration, and the rest
 // by their offsets in <linux/tcp.h>, when the kernel supplies them.
```

</details>

## Appendix B: vsock and UDP offload on Linux and Android, the patch

Against `a6478fb`; apply with `git apply`.

<details>
<summary>SystemSockets, CSystem and SystemSocketsTests (465 lines added)</summary>

```diff
--- a/Sources/CSystem/include/CSystemLinux.h
+++ b/Sources/CSystem/include/CSystemLinux.h
@@ -243,6 +243,12 @@
 // timespec, untyped for the same reason as accept4's arguments.
 extern int csystem_sendmmsg(int fd, void *msgvec, unsigned int vlen, int flags);
 extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout);
+
+// IOCTL_VM_SOCKETS_GET_LOCAL_CID, from <linux/vm_sockets.h>, which no C
+// library's Swift module includes, and which this header doesn't include
+// either, so as not to declare struct sockaddr_vm here: SystemSockets'
+// CInterop.SockAddrVM mirrors it, and shims.c checks the two agree.
+unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void);
 #endif // __linux__
 
 #if defined(__linux__) && !defined(__ANDROID__)
--- a/Sources/CSystem/shims.c
+++ b/Sources/CSystem/shims.c
@@ -649,6 +649,59 @@
 extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout) {
   return recvmmsg(fd, (struct mmsghdr *)msgvec, vlen, flags, (struct timespec *)timeout);
 }
+
+// UDP_SEGMENT and UDP_GRO, which SystemSockets' UDPOption spells as the
+// kernel's numbers, since glibc's and Bionic's Swift modules don't include
+// <netinet/udp.h>; a C library older than the options doesn't define them.
+#include <netinet/udp.h>
+#ifdef UDP_SEGMENT
+_Static_assert(UDP_SEGMENT == 103, "SocketDescriptor.UDPOption.segmentSize");
+#endif
+#ifdef UDP_GRO
+_Static_assert(UDP_GRO == 104, "SocketDescriptor.UDPOption.receiveOffload");
+#endif
+
+// VM sockets. <linux/vm_sockets.h> needs struct sockaddr, from
+// <sys/socket.h>, first.
+#if __has_include(<linux/vm_sockets.h>)
+#include <linux/vm_sockets.h>
+
+// CInterop.SockAddrVM, in Swift, is these fields, laid out as C lays them
+// out; Linux 5.11 took svm_flags from the start of svm_zero. And the
+// context IDs that VMSocketAddress.ContextID spells as numbers.
+struct csystem_sockaddr_vm_layout {
+  sa_family_t svm_family;
+  unsigned short svm_reserved1;
+  unsigned int svm_port;
+  unsigned int svm_cid;
+  unsigned char svm_flags;
+  unsigned char svm_zero[3];
+};
+_Static_assert(sizeof(struct sockaddr_vm) == sizeof(struct csystem_sockaddr_vm_layout),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(offsetof(struct sockaddr_vm, svm_port) ==
+                   offsetof(struct csystem_sockaddr_vm_layout, svm_port),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(offsetof(struct sockaddr_vm, svm_cid) ==
+                   offsetof(struct csystem_sockaddr_vm_layout, svm_cid),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(VMADDR_CID_HYPERVISOR == 0, "VMADDR_CID_HYPERVISOR");
+_Static_assert(VMADDR_CID_HOST == 2, "VMADDR_CID_HOST");
+_Static_assert(VMADDR_CID_ANY == -1U, "VMADDR_CID_ANY");
+_Static_assert(VMADDR_PORT_ANY == -1U, "VMADDR_PORT_ANY");
+#ifdef VMADDR_CID_LOCAL
+_Static_assert(VMADDR_CID_LOCAL == 1, "VMADDR_CID_LOCAL");
+#endif
+#endif // __has_include(<linux/vm_sockets.h>)
+
+#ifndef IOCTL_VM_SOCKETS_GET_LOCAL_CID
+// The kernel's value, for a C library without the header.
+#define IOCTL_VM_SOCKETS_GET_LOCAL_CID _IO(7, 0xb9)
+#endif
+
+unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void) {
+  return IOCTL_VM_SOCKETS_GET_LOCAL_CID;
+}
 #endif // __linux__
 
 // MARK: - Locales
--- a/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift
+++ b/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift
@@ -559,7 +559,7 @@
 
 // MARK: - sockaddr_vm
 
-#if SYSTEM_PACKAGE_DARWIN
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 @available(System 199, *)
 extension CInterop.SockAddrVM {
   /// Creates a VM socket address from its fields, by default all zero.
@@ -580,14 +580,18 @@
     self.contextID = contextID
   }
 
+  #if SYSTEM_PACKAGE_DARWIN
   /// The address's length in bytes.
   ///
   /// The corresponding C field is `svm_len`.
+  ///
+  /// - Note: Only available on Darwin.
   @_alwaysEmitIntoClient
   public var length: UInt8 {
     get { svm_len }
     set { svm_len = newValue }
   }
+  #endif
 
   /// The address's family.
   ///
@@ -616,7 +620,7 @@
     set { svm_cid = newValue }
   }
 }
-#endif // SYSTEM_PACKAGE_DARWIN
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 
 // MARK: - linger
 
--- a/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift
+++ b/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift
@@ -11,6 +11,18 @@
 
 #if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif os(Linux) || os(Android)
+@_implementationOnly import CSystem
+#if canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
+#endif
+
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 import SystemPackage
 
 internal func system_ioctl(
@@ -21,10 +33,19 @@
 #endif
   return ioctl(fd, request, value)
 }
+#endif
 
+#if SYSTEM_PACKAGE_DARWIN
 // IOCTL_VM_SOCKETS_GET_LOCAL_CID, _IOR('s', 209, uint32_t), a macro that
 // Swift can't import: IOC_OUT, the argument's size, the group, the number.
 internal var _IOCTL_VM_SOCKETS_GET_LOCAL_CID: UInt {
   0x4000_0000 | UInt(MemoryLayout<UInt32>.size) << 16 | UInt(UInt8(ascii: "s")) << 8 | 209
 }
+#elseif os(Linux) || os(Android)
+// IOCTL_VM_SOCKETS_GET_LOCAL_CID, _IO(7, 0xb9), from <linux/vm_sockets.h>,
+// which no C library's Swift module includes. _IO's encoding differs by
+// architecture, so this is the header's own value, from shims.c.
+internal var _IOCTL_VM_SOCKETS_GET_LOCAL_CID: UInt {
+  UInt(_system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID())
+}
 #endif
--- a/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift
+++ b/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift
@@ -11,15 +11,31 @@
 
 #if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif os(Linux) || os(Android)
+#if canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
+#endif
 
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
+
 @available(System 199, *)
 extension SocketDescriptor.Domain {
   /// Communication between a virtual machine and its host,
   /// through VM sockets.
   ///
-  /// The transport is in a virtual machine, which it connects to its host:
+  /// On Darwin the transport is in a virtual machine,
+  /// which it connects to its host:
   /// on a Mac that isn't a virtual machine, creating such a socket fails
   /// with ``Errno/operationNotSupportedByDevice`` (`ENODEV`).
+  /// On Linux a guest's transport connects it to its host,
+  /// and a host's (`vhost_vsock`) to its guests;
+  /// without one, creating such a socket fails
+  /// with ``Errno/addressFamilyNotSupported`` (`EAFNOSUPPORT`).
   ///
   /// A socket address's ``SocketAddress/family`` is this domain
   /// for a VM socket address.
@@ -27,7 +43,7 @@
   /// The corresponding C constants are `PF_VSOCK` and `AF_VSOCK`,
   /// which have the same value.
   ///
-  /// - Note: Only available on Darwin.
+  /// - Note: Only available on Darwin, Linux, and Android.
   @_alwaysEmitIntoClient
   public static var vsock: Self { Self(rawValue: PF_VSOCK) }
 }
@@ -40,7 +56,7 @@
 ///
 /// The corresponding C type is `struct sockaddr_vm`.
 ///
-/// - Note: Only available on Darwin.
+/// - Note: Only available on Darwin, Linux, and Android.
 @frozen
 @available(System 199, *)
 public struct VMSocketAddress: Hashable, Sendable, CustomStringConvertible {
@@ -87,24 +103,47 @@
     @_alwaysEmitIntoClient
     public static var any: Self { Self(rawValue: UInt32(bitPattern: -1)) }
 
+    // Linux declares the context IDs in <linux/vm_sockets.h>, which no C
+    // library's Swift module includes; these are its values, which shims.c
+    // checks against it.
+
     /// The hypervisor.
     ///
     /// The corresponding C constant is `VMADDR_CID_HYPERVISOR`.
     @_alwaysEmitIntoClient
-    public static var hypervisor: Self { Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR)) }
+    public static var hypervisor: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR))
+      #else
+      Self(rawValue: 0)
+      #endif
+    }
 
     /// Context ID 1, which Darwin reserves, and Linux uses for local
-    /// communication (`VMADDR_CID_LOCAL`).
+    /// communication, from Linux 5.6.
     ///
-    /// The corresponding C constant is `VMADDR_CID_RESERVED`.
+    /// The corresponding C constant is `VMADDR_CID_RESERVED`,
+    /// or on Linux `VMADDR_CID_LOCAL`.
     @_alwaysEmitIntoClient
-    public static var local: Self { Self(rawValue: UInt32(VMADDR_CID_RESERVED)) }
+    public static var local: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_RESERVED))
+      #else
+      Self(rawValue: 1)
+      #endif
+    }
 
     /// The host of the virtual machine that the socket is in.
     ///
     /// The corresponding C constant is `VMADDR_CID_HOST`.
     @_alwaysEmitIntoClient
-    public static var host: Self { Self(rawValue: UInt32(VMADDR_CID_HOST)) }
+    public static var host: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_HOST))
+      #else
+      Self(rawValue: 2)
+      #endif
+    }
 
     public var description: String { self == .any ? "-1" : rawValue.description }
   }
@@ -133,18 +172,79 @@
   }
 }
 
+#if SYSTEM_PACKAGE_DARWIN
 @available(System 199, *)
 extension CInterop {
   /// The corresponding C type is `struct sockaddr_vm`.
   public typealias SockAddrVM = sockaddr_vm
 }
+#else
+@available(System 199, *)
+extension CInterop {
+  /// A VM socket address, as the system calls take it.
+  ///
+  /// This is a Swift structure with the C structure's layout,
+  /// since Linux declares `struct sockaddr_vm`
+  /// in `<linux/vm_sockets.h>`, which no C library's Swift module includes.
+  /// Its fields have the C names;
+  /// the accessors ``family``, ``port``, and ``contextID`` name them in Swift,
+  /// and ``VMSocketAddress`` is the Swift type for these addresses.
+  ///
+  /// The corresponding C type is `struct sockaddr_vm`.
+  @frozen
+  public struct SockAddrVM {
+    /// The address's family, ``SocketDescriptor/Domain/vsock``.
+    ///
+    /// The corresponding C field is `svm_family`.
+    public var svm_family: sa_family_t
 
+    /// Reserved, and zero.
+    ///
+    /// The corresponding C field is `svm_reserved1`.
+    public var svm_reserved1: UInt16
+
+    /// The port.
+    ///
+    /// The corresponding C field is `svm_port`.
+    public var svm_port: UInt32
+
+    /// The context ID.
+    ///
+    /// The corresponding C field is `svm_cid`.
+    public var svm_cid: UInt32
+
+    /// Flags for the address, from Linux 5.11; zero before it.
+    ///
+    /// The corresponding C field is `svm_flags`.
+    public var svm_flags: UInt8
+
+    /// Padding to the size of `struct sockaddr`, which must be zero.
+    ///
+    /// The corresponding C field is `svm_zero`.
+    public var svm_zero: (UInt8, UInt8, UInt8)
+
+    /// Creates an address whose fields are all zero.
+    @_alwaysEmitIntoClient
+    public init() {
+      svm_family = 0
+      svm_reserved1 = 0
+      svm_port = 0
+      svm_cid = 0
+      svm_flags = 0
+      svm_zero = (0, 0, 0)
+    }
+  }
+}
+#endif
+
 @available(System 199, *)
 extension SocketAddress {
   /// Creates a socket address from a VM socket address.
   public init(vsock address: VMSocketAddress) {
-    var vm = sockaddr_vm()
-    vm.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
+    var vm = CInterop.SockAddrVM()
+    #if SYSTEM_PACKAGE_DARWIN
+    vm.svm_len = UInt8(MemoryLayout<CInterop.SockAddrVM>.size)
+    #endif
     vm.svm_family = sa_family_t(AF_VSOCK)
     vm.svm_port = address.port.rawValue
     vm.svm_cid = address.contextID.rawValue
@@ -153,17 +253,21 @@
 
   /// The address as a VM socket address, if it's one.
   public var vsock: VMSocketAddress? {
-    guard family == .vsock, length >= MemoryLayout<sockaddr_vm>.size else { return nil }
-    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: sockaddr_vm.self) }
+    guard family == .vsock, length >= MemoryLayout<CInterop.SockAddrVM>.size else { return nil }
+    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: CInterop.SockAddrVM.self) }
     return VMSocketAddress(contextID: .init(rawValue: vm.svm_cid), port: .init(rawValue: vm.svm_port))
   }
 }
 
+#if SYSTEM_PACKAGE_DARWIN
 @available(System 199, *)
 extension SocketDescriptor {
   /// Returns the context ID of the machine that this VM socket is on:
   /// the virtual machine's, in a guest.
   ///
+  /// On Linux, the call takes a descriptor for `/dev/vsock` instead:
+  /// see `FileDescriptor.localContextID()`.
+  ///
   /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
   ///
   /// - Note: Only available on Darwin.
@@ -180,5 +284,41 @@
     }.map { VMSocketAddress.ContextID(rawValue: contextID) }
   }
 }
+#else
+@available(System 199, *)
+extension FileDescriptor {
+  /// Returns the context ID of this machine, through the VM sockets device:
+  /// the virtual machine's, in a guest, or the host's, on a host.
+  ///
+  /// Call it on a descriptor for `/dev/vsock`:
+  ///
+  ///     let device = try FileDescriptor.open(
+  ///       "/dev/vsock", .readOnly, options: .closeOnExec)
+  ///     defer { try? device.close() }
+  ///     let contextID = try device.localContextID()
+  ///
+  /// With no transport, the context ID is ``VMSocketAddress/ContextID/any``.
+  /// Another descriptor throws
+  /// ``Errno/inappropriateIOCTLForDevice`` (`ENOTTY`).
+  /// On Darwin, the call takes a VM socket instead:
+  /// see `SocketDescriptor.localContextID()`.
+  ///
+  /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
+  ///
+  /// - Note: Only available on Linux and Android.
+  @_alwaysEmitIntoClient
+  public func localContextID() throws(Errno) -> VMSocketAddress.ContextID {
+    try _localContextID().get()
+  }
 
-#endif // SYSTEM_PACKAGE_DARWIN
+  @usableFromInline
+  internal func _localContextID() -> Result<VMSocketAddress.ContextID, Errno> {
+    var contextID = VMSocketAddress.ContextID.any.rawValue
+    return nothingOrErrno(retryOnInterrupt: false) {
+      system_ioctl(self.rawValue, _IOCTL_VM_SOCKETS_GET_LOCAL_CID, &contextID)
+    }.map { VMSocketAddress.ContextID(rawValue: contextID) }
+  }
+}
+#endif
+
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
--- a/Sources/SystemSockets/Sockets/SocketDescriptor.swift
+++ b/Sources/SystemSockets/Sockets/SocketDescriptor.swift
@@ -170,6 +170,8 @@
       #if SYSTEM_PACKAGE_DARWIN
       case .system: return "system"
       case .networkDevice: return "networkDevice"
+      #endif
+      #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
       case .vsock: return "vsock"
       #endif
       default: return "Domain(\(rawValue))"
--- /dev/null
+++ b/Sources/SystemSockets/Sockets/SocketOptions+UDP.swift
@@ -0,0 +1,83 @@
+/*
+ This source file is part of the Swift System open source project
+
+ Copyright (c) 2026 Apple Inc. and the Swift System project authors
+ Licensed under Apache License v2.0 with Runtime Library Exception
+
+ See https://swift.org/LICENSE.txt for license information
+*/
+
+// Linux's UDP-level options: segmentation and receive offload, UDP_SEGMENT
+// and UDP_GRO. They're in <netinet/udp.h>, which glibc's and Bionic's Swift
+// modules don't include, so they're the kernel's numbers, which are the same
+// on every architecture; shims.c checks them against the header.
+
+import SystemPackage
+
+#if os(Linux) || os(Android)
+
+@available(System 199, *)
+extension SocketDescriptor {
+  /// UDP-level options, at the ``OptionLevel/udp`` level,
+  /// for use with `getOption` and `setOption`,
+  /// or ``getUDPOption(_:)`` and ``setUDPOption(_:to:)``.
+  ///
+  /// - Note: Only available on Linux and Android.
+  @frozen
+  public struct UDPOption: RawRepresentable, Hashable, Sendable {
+    @_alwaysEmitIntoClient
+    public var rawValue: CInt
+
+    @_alwaysEmitIntoClient
+    public init(rawValue: CInt) { self.rawValue = rawValue }
+
+    /// The size of the datagrams that the kernel splits each datagram
+    /// the socket sends into, which is segmentation offload,
+    /// or 0 to send each as it is.
+    ///
+    /// A message's own ancillary message of this type sets the size
+    /// for that message. Linux 4.18 added it; an older kernel throws
+    /// ``Errno/protocolNotAvailable``.
+    ///
+    /// The corresponding C constant is `UDP_SEGMENT`.
+    @_alwaysEmitIntoClient
+    public static var segmentSize: UDPOption { UDPOption(rawValue: 103) }
+
+    /// Whether the kernel coalesces the datagrams that the socket receives
+    /// from one flow into larger ones, which is receive offload.
+    ///
+    /// A coalesced datagram comes with an ancillary message of this type,
+    /// whose value is the size of the datagrams it joined.
+    /// Linux 5.0 added it; an older kernel throws
+    /// ``Errno/protocolNotAvailable``.
+    ///
+    /// The corresponding C constant is `UDP_GRO`.
+    @_alwaysEmitIntoClient
+    public static var receiveOffload: UDPOption { UDPOption(rawValue: 104) }
+  }
+}
+
+@available(System 199, *)
+extension SocketDescriptor {
+  /// Gets a UDP-level option whose value is an integer.
+  ///
+  /// The corresponding C function is `getsockopt`, at the `IPPROTO_UDP` level.
+  ///
+  /// - Note: Only available on Linux and Android.
+  @_alwaysEmitIntoClient
+  public func getUDPOption(_ option: UDPOption) throws(Errno) -> CInt {
+    try _value(OptionLevel.udp.rawValue, option.rawValue, CInt(0)).get()
+  }
+
+  /// Sets a UDP-level option whose value is an integer.
+  ///
+  /// The corresponding C function is `setsockopt`, at the `IPPROTO_UDP` level.
+  ///
+  /// - Note: Only available on Linux and Android.
+  @_alwaysEmitIntoClient
+  public func setUDPOption(_ option: UDPOption, to value: CInt) throws(Errno) {
+    try _setValue(OptionLevel.udp.rawValue, option.rawValue, value).get()
+  }
+}
+
+#endif // os(Linux) || os(Android)
--- a/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift
+++ b/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift
@@ -130,12 +130,25 @@
     #if SYSTEM_PACKAGE_DARWIN
     ipv4.length = 16
     #expect(ipv4.sin_len == 16)
+    #endif
+    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
     var vm = CInterop.SockAddrVM(family: .vsock, port: 1024, contextID: 2)
     #expect(vm.svm_family == sa_family_t(AF_VSOCK) && vm.svm_port == 1024 && vm.svm_cid == 2)
+    #if SYSTEM_PACKAGE_DARWIN
     vm.length = 12
     #expect(vm.svm_len == 12)
     #expect(sameBytes(CInterop.SockAddrVM(), sockaddr_vm()))
+    #else
+    // Linux's is System's structure, with the C layout: 16 bytes.
+    vm.contextID = 3
+    vm.port = 1025
+    #expect(vm.svm_cid == 3 && vm.svm_port == 1025 && vm.family == .vsock)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.size == 16)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.offset(of: \.svm_port) == 4)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.offset(of: \.svm_cid) == 8)
+    #expect(sameBytes(CInterop.SockAddrVM(), CInterop.SockAddrVM(family: .unspecified)))
     #endif
+    #endif
   }
 
   @available(System 199, *)
--- /dev/null
+++ b/Tests/SystemSocketsTests/SocketUDPOptionsTests.swift
@@ -0,0 +1,56 @@
+/*
+ This source file is part of the Swift System open source project
+
+ Copyright (c) 2026 Apple Inc. and the Swift System project authors
+ Licensed under Apache License v2.0 with Runtime Library Exception
+
+ See https://swift.org/LICENSE.txt for license information
+*/
+
+#if os(Linux) || os(Android)
+
+import Testing
+
+#if canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
+
+import SystemPackage
+import SystemSockets
+
+@Suite("UDP socket options")
+private struct SocketUDPOptionsTests {
+  /// Segmentation offload's size and receive offload's flag read back as
+  /// they were set, on a kernel that has them (4.18 and 5.0).
+  @available(System 199, *)
+  @Test func offloadOptions() throws {
+    let socket = try SocketDescriptor.open(.ipv4, .datagram, options: .closeOnExec)
+    defer { try? socket.close() }
+    for (option, value) in [(SocketDescriptor.UDPOption.segmentSize, CInt(1200)), (.receiveOffload, 1)] {
+      do throws(Errno) {
+        try socket.setUDPOption(option, to: value)
+      } catch {
+        // An older kernel.
+        #expect(error == .protocolNotAvailable)
+        continue
+      }
+      #expect(try socket.getUDPOption(option) == value)
+      let raw: CInt = try socket.getOption(.udp, option.rawValue)
+      #expect(raw == value)
+    }
+  }
+
+  /// Neither option is a TCP socket's.
+  @available(System 199, *)
+  @Test func notOnATCPSocket() throws {
+    let socket = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
+    defer { try? socket.close() }
+    #expect(throws: Errno.self) { try socket.setUDPOption(.segmentSize, to: 1200) }
+  }
+}
+
+#endif // os(Linux) || os(Android)
--- a/Tests/SystemSocketsTests/SocketVMSocketTests.swift
+++ b/Tests/SystemSocketsTests/SocketVMSocketTests.swift
@@ -7,10 +7,18 @@
  See https://swift.org/LICENSE.txt for license information
 */
 
-#if SYSTEM_PACKAGE_DARWIN
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 
 import Testing
+#if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
 
 import SystemPackage
 #if ENABLE_MOCKING
@@ -41,19 +49,26 @@
 
     let socketAddress = SocketAddress(vsock: address)
     #expect(socketAddress.family == .vsock)
-    #expect(socketAddress.length == MemoryLayout<sockaddr_vm>.size)
+    #expect(socketAddress.length == MemoryLayout<CInterop.SockAddrVM>.size)
     #expect(socketAddress.vsock == address)
     #expect(socketAddress.ipv4 == nil)
     #expect(SocketAddress(ipv4: .loopback(port: 1)).vsock == nil)
 
-    // The C structure's fields, as a client that imports Darwin reads them.
+    // The C structure's fields, as a client that imports the C library
+    // reads them.
     let vm = socketAddress.withUnsafePointer { pointer, _ in
       UnsafeRawPointer(pointer).loadUnaligned(as: CInterop.SockAddrVM.self)
     }
     #expect(vm.svm_cid == 2 && vm.svm_port == 1024)
+    #expect(vm.svm_family == sa_family_t(AF_VSOCK))
+    #if SYSTEM_PACKAGE_DARWIN
     #expect(Int(vm.svm_len) == MemoryLayout<sockaddr_vm>.size)
+    #else
+    #expect(MemoryLayout<CInterop.SockAddrVM>.size == 16)
+    #endif
   }
 
+  #if SYSTEM_PACKAGE_DARWIN
   /// A Mac that isn't a virtual machine has no VM socket transport.
   @available(System 199, *)
   @Test func aSocketNeedsATransport() throws {
@@ -66,20 +81,73 @@
       #expect(error == .operationNotSupportedByDevice)
     }
   }
+  #else
+  /// A socket needs the kernel's VM sockets, which a container may not
+  /// load, or a seccomp filter (such as Docker's default) may refuse.
+  @available(System 199, *)
+  @Test func aSocketNeedsVMSockets() throws {
+    do {
+      let socket = try SocketDescriptor.open(.vsock, .stream, options: .closeOnExec)
+      try socket.close()
+    } catch {
+      // close() throws untyped errors.
+      let errno = error as? Errno
+      #expect(errno == .addressFamilyNotSupported || errno == .notPermitted)
+    }
+  }
 
+  /// The VM sockets device reports this machine's context ID: a guest's,
+  /// the host's, or with no transport, any. Without the device, as in most
+  /// containers, there's nothing to ask.
+  @available(System 199, *)
+  @Test func theDeviceHasTheLocalContextID() throws {
+    let device: FileDescriptor
+    do {
+      device = try FileDescriptor.open("/dev/vsock", .readOnly, options: .closeOnExec)
+    } catch {
+      return
+    }
+    defer { try? device.close() }
+    let id = try device.localContextID()
+    #expect(id == .any || id == .host || id.rawValue >= 3)
+  }
+
+  /// Only the device answers the call.
+  @available(System 199, *)
+  @Test func anotherDescriptorIsNotTheDevice() throws {
+    let pipe = try FileDescriptor.pipe()
+    defer {
+      try? pipe.readEnd.close()
+      try? pipe.writeEnd.close()
+    }
+    #expect(throws: Errno.inappropriateIOCTLForDevice) {
+      try pipe.readEnd.localContextID()
+    }
+  }
+  #endif
+
   #if ENABLE_MOCKING
   @available(System 199, *)
   @Test func theLocalContextIDCall() throws {
     try MockingDriver.withMockingEnabled { mocking in
+      #if SYSTEM_PACKAGE_DARWIN
       let id = try SocketDescriptor(rawValue: 9).localContextID()
+      #else
+      let id = try FileDescriptor(rawValue: 9).localContextID()
+      #endif
       // A mocked ioctl writes nothing.
       #expect(id == .any)
       let entry = mocking.trace.dequeue()
       #expect(entry?.name == "ioctl")
+      #if SYSTEM_PACKAGE_DARWIN
       #expect(entry?.arguments == [CInt(9), UInt(0x4004_73D1)])
+      #elseif arch(x86_64) || arch(arm64)
+      // _IO(7, 0xb9), from the header, through shims.c.
+      #expect(entry?.arguments == [CInt(9), UInt(0x7B9)])
+      #endif
     }
   }
   #endif
 }
 
-#endif // SYSTEM_PACKAGE_DARWIN
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
```

</details>
