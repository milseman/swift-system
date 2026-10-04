# coverage-5 report

Lane `coverage-5`, worktree `../coverage-5`, branch `coverage-5`, from `system-next` at `4bf3afd` (2026-10-04),
which didn't move during the lane.

## Resume here

- Stopped with every row of the ranked list (below) done, skipped for a reason, or under "Needs design". Nothing
  is uncommitted.
- Next, if wanted: the rows' "left" parts, in section 18: SocketDescriptor's socket types, flags and calls on
  WASI (with `_getConst_` shims), `CLocale.information(_:)` on Android, OpenBSD and WASI, `RUSAGE_THREAD`,
  `setCloseOnExecForAll`'s `EPERM` case, and the 1-site rows in `../adopters-unix/gaps/*.md` that 6.1's table
  doesn't show (section 18).
- Then the Decisions session's questions ("Needs design").

## The ranked list

Merged from `../adopters-unix/UNIX-REPORT.md` section 6.1 (U, its rank; per-site detail in
`../adopters-unix/gaps/<pkg>.md`) and its unix-adopt-3 bullet (U3), `../adopters/PACKAGES-6-REPORT.md`'s Unix
table (P6), and `../swift-system-examples/GAPS.md` and its `REPORT.md` "Outside this repo" (E). Ranked by sites
unblocked, ties by more platforms. Platforms are System's gaps: D Darwin, L Linux, M Musl, A Android, W WASI,
F FreeBSD, O OpenBSD, Win Windows. A site whose line also compiles for Windows ("W, Win") collapses only once
Windows has the API too; those Windows halves are out of scope (later). Families are one row; counts are the
reports' (6.1's are lexical, a C name on a line).

| # | Gap (family) | Lacks | Sites | From | State |
|---|---|---|---|---|---|
| 1 | SystemSockets' address types and constants on WASI: `CInterop.SockAddr` 14, `SockAddrIn` 11, `SockAddrIn6` 11, `InPort` 8, `SAFamily` 7, `SockAddrUn` 6, `InAddr` 5, `IPv4Address.Host.descriptionCapacity` 3, `IPv6Address.Host.descriptionCapacity` 3, `SocketAddress.Family.ipv4` 3, `.ipv6` 3, `InAddrT` 2, `Linger` 2 | W (Win) | 78: swift-nio | U 1-6, 8, 11-16 | done, `0626ba6` (section 2) |
| 2 | fts: `FTSENT` 4, `FTS`, `fts_open`/`read`/`set`/`close`, the `FTS_*` constants | L M A W F O | 27: swift-foundation | U 9 | Needs design (N1) |
| 3 | VM sockets on Linux: `VMSocketAddress` 6, `SocketDescriptor.Domain.vsock` 2 | L M A | 8: swift-nio | U 7 | done, `bec2d20` (section 3) |
| 4 | `CLocale` on WASI: `Category.all` 2, `globalName` 2, `CInterop.Locale` 1, `parseFloat` 1, `parseDouble` 1, `compareIgnoringCase` 1 | W (Win) | 8: swift-foundation | U 20, 21 | done, `644798c` (section 4) |
| 5 | TCP info on FreeBSD: `CInterop.TCPInfo` 2, `TCPOption.info` 1, `TCPConnectionInfo.state` 1, `TCPState.established` 1 | F | 5: swift-nio | U 19 | done for 3, `a33f8c4` (section 5); the 2 test sites left (why there) |
| 6 | The thread API on WASI without threads: `PThread`, `PThread.Mutex` 2; `FileStream.withLock` 1 | W | 3: swift-async-algorithms 2, swift-log 1 | P6 (U 17, 18, 23-25 are gone from `gaps/WasmKit.md`) | Needs design (N2) |
| 7 | `FileStream` on Android and OpenBSD, whose `FILE` is opaque | A O | 2: TSC `PseudoTerminal`, SwiftPM `AsyncProcess` (and TSC's 8 C-stream sites, which also need Windows) | U3 | done, `bc53f6f` (section 6) |
| 8 | `FileDescriptor.OpenOptions.dataSync` (`O_DSYNC`) | F O | 2: WasmKit | U 22 | done, `b5dfab7` (section 7) |
| 9 | `TerminalDescriptor.openPseudoterminal()` on OpenBSD | O | 2: swift-subprocess's tests, swift-build's console tests | U3, P6 | Needs design (N3) |
| 10 | `FileDescriptor.close()` with typed throws | all | 1: examples' `cat` | E | done, `4be3f65` (section 8) |
| 11 | A byte view on `FilePath.Component` | all | 1: examples' `ls` | E | Needs design (N4) |
| 12 | `abort` | all | 1: swift-build `SWBBuildServiceConnection` | P6 | done, `0af385e` (section 9) |
| 13 | `getrusage` | all (F O for the site) | 1: swift-docc `PeakMemory` | P6 | done, `2ef3836` (section 10) |
| 14 | `strcoll` | all | 1: examples' `ls` | E | Needs design (N5) |
| 15 | `mbrtowc`, `iswprint`, `iswcntrl` | all | 1: examples' `cat -v` | E | Needs design (N6) |
| 16 | System's `ExitStatus` against swift-testing's | all | 1: examples' tests | E | Needs design (N7) |
| 17 | A `dlopen` that runs in the caller's image | D L M A F O | 1: swift-build `Library.open` | P6 | Needs design (N8) |
| 18 | ACLs (`acl_get_link_np`, `acl_get_entry`, `acl_free`) | D F L | 1: examples' `ls -l` | E | Needs design (N9) |
| 19 | `setCloseOnExecForAll(from:)`'s fallback before Linux 5.11 | L A | 1: SwiftPM `safeExec` | U3 | done, `636f5f3` (section 11) |
| 20 | `extendedAttribute` size only (`getxattr` with no buffer) | D L | 1: examples' `ls -@` | E | done, `53f588b` (section 12) |
| 21 | `nl_langinfo(D_MD_ORDER)` | D F | 1: examples' `ls -l` | E | done, `1afadf7`, `68bb779` (section 16) |
| 22 | `DynamicLibrary.symbolInfo(containing:)` (`dladdr`) | F O | 1: swift-build `Library.locate` | P6 | done, `51e02e8` (section 13) |
| 23 | `TerminalDescriptor.readPassphrase` (`readpassphrase`) | F O | 1: SwiftPM's registry login | U3 | done, `b13958d` (section 14) |
| 24 | `pthread_suspend_all_np` | F | 1: SwiftPM `TestingSupport` | U3 | done, `9bcdf5b` (section 15) |
| 25 | A `CInterop` alias for `off_t` | (none) | 1: swift-build `SWBDispatch` | P6 | done before this lane: `CInterop.Offset` (`12c5ac9`, every platform); swift-build's `SYSTEM-GAP` marker is stale |
| 26 | `fd_set` | L M A | 0 now: gone from `gaps/swift-tools-support-core.md` (TSC's `FSWatch` moved to `poll`) | U 10 | nothing to do |

## Needs design

For the Decisions session. Each is a question with this lane's default (nothing built) and the options.

- **N1. fts on Linux (rank 2, 27 sites, swift-foundation).** System's answer so far is `DirectoryWalk`
  (`mapping.ini` since `3e4e890`), which Foundation's Darwin branch walks with; on Linux Foundation keeps fts
  (UNIX-REPORT 2.2: no comparison run there like Darwin's 382, and removal needs `FTS_XDEV`'s same-device check,
  which `DirectoryWalk` doesn't have). Question: is `DirectoryWalk` the answer, with a same-device option for
  removal and Foundation's comparison run on Linux; or does System wrap fts too (an owner over `FTS *`, `FTSENT`
  accessors, the `FTS_*` options and `info` kinds)? Facts: glibc and Bionic have fts, Swift's static Linux SDK
  bundles musl-fts, WASI has none.
- **N2. The thread API on WASI without threads (rank 6).** wasip1's `libc.a` in the Swift 6.2.4 SDK defines no
  pthread symbols at all (checked with `llvm-nm`: no `pthread_mutex_lock`, `pthread_create` or `flockfile`), so
  `PThread` there can't link; platforms-2's sections 6.1 and 6.5 left it and `FileStream.withLock` out. Question:
  locks that do nothing without threads (no other thread can come between a stream's calls, or take a mutex),
  so that swift-async-algorithms' `Lock` and swift-log's stdout lock need no condition; or leave them out, as
  wasi-libc does (the adopters test `_runtime(_multithreaded)`). `PThread.yield()` and `sleep(for:)`, whose C
  calls wasip1 has, are the same question (platforms-2 6.10).
- **N3. Pseudoterminals on OpenBSD (rank 9).** System's form is `posix_openpt`, `grantpt`, `unlockpt` and
  `ptsname_r`, and OpenBSD has no `ptsname_r`, only `ptsname`, whose static buffer another thread's call can
  overwrite (platforms-2 8.4). Options: `ptsname` (racy with other callers); `openpty` from libutil (`<util.h>`
  and `-lutil`, neither checked in OpenBSD's Swift module); or `/dev/ptm`'s `PTMGET` ioctl, which returns both
  descriptors and their names (a struct and an `_IOR` number for CSystem to shim).
- **N4. A byte view on `FilePath.Component` (rank 11).** `ls` scans the C string from `withPlatformString` to
  write a name byte for byte. The view's shape is the question: a `Span<CInterop.PlatformChar>` property
  (lifetime-dependent; code units, so UTF-16 on Windows), a closure over an `UnsafeBufferPointer` without the
  null, or a `Collection`; and whether `FilePath` and `FilePath.Root` get the same.
- **N5. Collation (rank 14).** `strcoll_l` and `strxfrm_l` would sit on `CLocale` (provisional), but what a
  Swift caller compares is `String`s, and the C call needs NUL-terminated bytes in the locale's encoding.
  Question: a `CLocale.compare(_:_:)` over C strings, or Foundation's collation as the answer.
- **N6. Wide characters (rank 15).** `mbrtowc` with its `mbstate_t`, and `iswprint`/`iswcntrl` over `wchar_t`
  (32 bits but on Windows): a decoder type, or `Unicode.Scalar` properties (the standard library's
  `isPrintable`-like answers don't match a C locale's), or none.
- **N7. `ExitStatus` against swift-testing's (rank 16).** A test file that imports both writes
  `SystemPackage.ExitStatus`. Renaming System's (it's a prototype, `Processes/ExitStatus.swift`) is the
  processes lane's question; options: `ProcessExitStatus`, nesting it (`ChildProcess.ExitStatus`), or keeping it.
- **N8. A `dlopen` that runs in the caller's image (rank 17).** `@rpath`, `@loader_path` and `$ORIGIN` resolve
  against the image that calls `dlopen`, which is SystemPackage's when it's a library of its own. A form whose
  `dlopen` call is emitted into the client (`@_alwaysEmitIntoClient` all the way down) breaks System's layering
  (`system_dlopen` the only caller, with the mock hook). Question: allow that for `DynamicLibrary.init`, or leave
  `Library.open`'s `dlopen` C.
- **N9. ACLs (rank 18).** Darwin's and FreeBSD's `acl_*` (in libc) and Linux's libacl (a separate library) have
  the same POSIX.1e draft API, with owners (`acl_t`) and entry iteration: a type of its own, beyond a wrapper.
- **The rest of the older API's untyped throws** (from section 8): convert it to `throws(Errno)` as
  `close()` now is, all at once or as adopters ask.

## 1. `Sources/System/CMakeLists.txt` (`9075397`)

The Win32 `target_sources` block named 26 of `Sources/System/Win32`'s 45 files; SwiftPM builds all 45. It's now
`git ls-files Sources/System/Win32` in C-locale order, which is windows-3's "P3, continued" block
(`Prototype/Win32/REPORT.md` section 45) exactly. Checked against `git ls-files`:

- `Sources/System/CMakeLists.txt`: every Swift file under `Sources/System` is listed, and nothing else (the one
  other `.swift` match is the comment naming `Package.swift`). Section 10's `Processes/ResourceUsage.swift` went
  in with it, in place.
- `Sources/CSystem/CMakeLists.txt`: builds `shims.c` and installs all eight headers in `include/`. Its list keeps
  main's order (`CSystemFreeBSD.h` after `CSystemWindows.h`), as do the older blocks in System's list that aren't
  in C order (`Util.swift` before `Util+StringArray.swift`, `IORing.swift` before `IORing+Util.swift`, and a few
  case-insensitive ones): CI's check compares sets, and reordering main's lines would only make merges conflict.
- `Sources/CMakeLists.txt`: adds `CSystem` and `System`. SystemSockets isn't built by CMake, by design.

## 2. SystemSockets on WASI (`0626ba6`)

The coordinator's default: the `CInterop` aliases and constants where wasi-libc's headers declare them, and no
functions WASI lacks. SystemSockets now builds on WASI with:

- `CInterop`'s `SockAddr`, `SockLen`, `SAFamily`, `SockAddrIn`, `InAddr`, `InAddrT`, `In6Addr`, `InPort`,
  `SockAddrIn6`, `SockAddrUn`, `SockAddrStorage`, `IOVec`, `MsgHdr` and `Linger`; not `CMsgHdr` (wasi-libc
  declares `cmsghdr` only for unmodified musl) or `AddrInfo` (no `<netdb.h>`).
- `SocketAddress`, `SocketAddress.Family` (unspecified, local, ipv4, ipv6), `IPv4Address` and `IPv6Address` with
  their `Host`s, text conversions and `descriptionCapacity`, over wasi-libc's `inet_pton` and `inet_ntop`.
- `SocketDescriptor`: the type, its conversions (the checked one is `getsockopt` with `SO_TYPE`, which wasip1
  has), `Domain`, `ProtocolID`, and the `writeAll` and `closeAfter` helpers.
- The accessors for `sockaddr`, `sockaddr_in`, `sockaddr_in6`, `sockaddr_storage`, `in_addr`, `in6_addr` and
  `linger`, and `sockaddr_un`'s family alone (wasi-libc's has no `sun_path`).

Design calls: wasi-libc has neither `AF_LOCAL` nor `PF_LOCAL`, so `local` is `AF_UNIX` there (3; `AF_INET` is
1 and `AF_INET6` 2, not Linux's numbers). Off WASI, each with "Not available on WASI." where its type stays:
`Domain.routing` and `.keyManagement`, `Family.routing`, `ProtocolID.ipv4`, `UnixAddress`, `ConnectionType`
(wasi-libc's `SOCK_STREAM` and `SOCK_DGRAM` are `UINT8_C()` macros from `wasi/api.h`, which Swift can't import;
a `_getConst_` shim in `CSystemWASI.h` would do), `MessageFlags`, `ShutdownKind`, `Option`, and every socket
call. Excluded files are wrapped in `#if !os(WASI)`, so their `#error` still catches an unknown platform. The
mocking driver's copy gets SystemPackage's WASI thread-specific storage. Rejected (the alternative, platforms-2's
section 5): an empty SystemSockets on WASI, or excluding it in `Package.swift`.

Not built for WASI: written from the 6.2.4 SDK's wasi-libc headers, with its `libc.a`'s symbols checked
(`inet_pton`, `inet_ntop`, `in6addr_any`, `in6addr_loopback`, `getsockopt`). SystemSocketsTests' files are off
WASI too; the address tests could run there. The NIO rows are "W, Win" (but `InAddrT`), so those sites collapse
once Windows has the types too.

## 3. VM sockets and UDP offload on Linux (`bec2d20`)

linux-3's Appendix B (`Prototype/Linux3/REPORT.md`, against `a6478fb`) applied unchanged, offsets only:
`CInterop.SockAddrVM` as a Swift structure with `struct sockaddr_vm`'s layout (Linux declares it in
`<linux/vm_sockets.h>`, which no C library's module includes; `shims.c` checks the layout and the context IDs),
`VMSocketAddress` and `Domain.vsock` on Linux and Android, `FileDescriptor.localContextID()` over `/dev/vsock`
(Linux's form; Darwin's takes the socket), and `SocketDescriptor.UDPOption` (`segmentSize`, `UDP_SEGMENT` 103;
`receiveOffload`, `UDP_GRO` 104), which NIO hardcodes. `os(Linux)` covers Musl, whose overlay's `ioctl` is
Glibc's and Android's (checked in the static SDK's and the Android SDK's interfaces). The Linux run (Tests,
below) passes the VM sockets and UDP options suites.

## 4. `CLocale` on WASI (`644798c`)

wasi-libc's `<locale.h>` is Musl's: categories 0-6, masks `1 << category`, `LC_ALL_MASK` 0x7fffffff,
`newlocale`, `freelocale` and `uselocale`, all defined in wasip1's `libc.a`. Its `*_l` calls ignore the locale
(Musl's numbers are always the POSIX locale's) and `strtod_l` is declared only with `_GNU_SOURCE`, so
`parseDouble`, `parseFloat` and `compareIgnoringCase` call `strtod`, `strtof` and `strncasecmp` there, as on
Android and OpenBSD: no shim. `ProvisionalLocaleLinuxTests` (Musl's expectations) widens to WASI, where XCTest
doesn't run yet. Not built for WASI.

## 5. TCP info on FreeBSD (`a33f8c4`)

linux-3's Appendix A applied unchanged: `CInterop.TCPInfo` and `TCPOption.info` on FreeBSD, whose
`<netinet/tcp.h>` (in its Glibc-named module) has `TCP_INFO` and a `struct tcp_info` with Linux's names for the
fields they share; Linux's `TCPInfo` wrapper stays Linux's. Left: NIO's FreeBSD test reads `tcpi_state` against
`TCP_ESTABLISHED`, a C field and a constant FreeBSD doesn't define (its `tcpi_state` is a `TCPS_` state), and a
state accessor over FreeBSD's layout is what linux-3 rejected (its header calls the layout unstable).

## 6. `FileStream` on Android and OpenBSD (`bc53f6f`)

Bionic's `FILE` is incomplete from API level 24 (the Swift SDK for Android targets 28 and up; checked in its
`swift-sdk.json`), and OpenBSD's is too, so `FILE *` imports as `OpaquePointer`: `CInterop.File = FILE` and the
`UnsafeMutablePointer` raw value couldn't compile. They now take WASI's branch: no `CInterop.File`, an
`OpaquePointer` raw value, which is TSC's and SwiftPM's `FILEPointer` there. OpenBSD's standard streams are
spelled without the force-unwrap, so they convert whether its overlay declares them optional or not. Not built.

## 7. `O_SYNC` and `O_DSYNC` on the BSDs (`b5dfab7`)

`OpenOptions.dataSync` and `StatusFlags.sync` and `.dataSync` on FreeBSD (whose `O_DSYNC`, from 13.0, is a flag
of its own) and OpenBSD (whose `O_DSYNC` is `O_SYNC`, which the docs say), and `OpenOptions.sync` on OpenBSD;
FreeBSD's `OpenOptions.sync` was already its own. Tests: `SmallBSDGapsTests`. Not built.

## 8. `FileDescriptor.close()` throws `Errno` (`4be3f65`)

It's `@_alwaysEmitIntoClient`, so the ABI doesn't change, and every caller form compiles as before but a catch
block's error type. The Win32 harness's stand-in still says `throws`, which its mirror check accepts as a
prefix; `check-windows.sh` passes. Left open: the rest of the older API (Needs design).

## 9. `ProcessID.abort()` (`0af385e`)

Beside `exit(_:)` and `exitImmediately(_:)`, with no mock hook (it never returns). The doc says what POSIX
does: `SIGABRT` overriding a block, an ignore or a returning handler, no exit handlers, streams up to the C
library, and a trap's different signal. Tests: an exit test sees `SIGABRT` and no handler run.

## 10. `ProcessID.resourceUsage(of:)` (`2ef3836`)

`getrusage`, returning `CInterop.ResourceUsage` with read-only accessors (times as `CInterop.TimeVal`, counts as
`Int`), and `ResourceUsageScope` (`current`, `children`; the kernel's numbers on Linux and Android, since glibc's
are an enum, as `RLIMIT_` values are spelled). Design calls: `maxResidentSetSize` is bytes everywhere (rejected:
the raw field, kilobytes but on Darwin), as `Int64`; a static on `ProcessID` (rejected: a top-level type like
`ResourceLimit`); `RUSAGE_THREAD` left out (glibc declares it only with `_GNU_SOURCE`). Every platform but Windows
and WASI (wasi-libc's `<sys/resource.h>` `#error`s without its process-clocks emulation). Tests:
`ProcessResourceUsageTests`, and the MemberImportVisibility probe reads every accessor without the C module.

## 11. `setCloseOnExecForAll`'s fallback on Linux before 5.11 (`636f5f3`)

`close_range`'s `CLOSE_RANGE_CLOEXEC` is 5.11's: 5.9 and 5.10 return `EINVAL`, older kernels `ENOSYS`. Either
(the range check before the call rules out the caller's `EINVAL`) now lists `/proc/self/fd` and sets
`FD_CLOEXEC` on each descriptor in the range, as glibc's `closefrom` falls back to closing what it lists.
`closeAll` keeps throwing `noFunction` before 5.9 (closing while listing closes the listing). `EPERM`, which old
seccomp profiles return, isn't a fallback case. The Linux run passes `testMarkingARangeFromTheListing`, which
calls the fallback directly (the container's kernel never takes it).

## 12. `extendedAttributeSize` (`53f588b`)

`getxattr`/`fgetxattr` with no buffer, as `FilePath`, C-string and `FileDescriptor` forms beside
`extendedAttribute`; a missing attribute is `nil`. Tests: real sizes (none, 3, 0, 3000; through a descriptor, a C
string, a link and the link itself) and mock cases.

## 13. `DynamicLibrary.symbolInfo(containing:)` on the BSDs (`51e02e8`)

Their `<dlfcn.h>` declares `dladdr` and Darwin's `Dl_info` by default, so they take Darwin's wrapper.
`SynchronizedIOBSDTests` became `SmallBSDGapsTests` with the Darwin and Linux files' `testSymbolInfo`. Not built.

## 14. `readPassphrase` on the BSDs (`b13958d`)

Their C libraries have `readpassphrase`, but whether their modules include `<readpassphrase.h>` is unchecked,
so it's a CSystem shim (`csystem_readpassphrase`, declared without the header, defined with it), and the BSDs
take Darwin's path, with its signal handling. `shims.c` checks the flag values that `Constants+Passphrase.swift`
spells. The passphrase tests widen to the BSDs. Not built.

## 15. `PThread.suspendAll()` and `resumeAll()` on FreeBSD (`9bcdf5b`)

`pthread_suspend_all_np` and `pthread_resume_all_np`, which can't fail. The doc warns that a suspended thread can
hold a lock the caller then needs. Test: a thread started before the suspension finishes after it. Not built.

## 16. `CLocale.information(_:)` (`1afadf7`, `68bb779`)

`nl_langinfo_l`, with `CLocale.Item`'s Swift names (`characterEncoding`, the four `strftime` formats, `amSymbol`,
`pmSymbol`, `dayName(_:)` and the abbreviated and month forms from 1, `decimalSeparator`, `thousandsSeparator`,
`yesPattern`, `noPattern`, `currencySymbol`, and on Darwin and FreeBSD `monthDayOrder`, `D_MD_ORDER`), and
`CInterop.LocaleItem` (`nl_item`). Darwin through `CSystemDarwin.h` (now with `<langinfo.h>` and
`<xlocale/_langinfo.h>`), FreeBSD through a shim, Linux through the module, with nl_langinfo for the global locale
and `_posixLocale` for the POSIX one, as `strtod_l` does. Not on Android (its `nl_langinfo` is API 26's), OpenBSD
(its null locale isn't the POSIX locale), or WASI, yet. The first Linux build failed on glibc's `YESEXPR`,
`NOEXPR` and `CRNCYSTR`, macros that name enum constants of other names, which Swift doesn't import; `68bb779`
spells the constants.

## Tests

- **Darwin** (`swift build --build-tests`, `swift test`): before (`9075397`), XCTest 575 tests, 5 skipped, 0
  failures; swift-testing 504 tests in 82 suites passed. After (`1afadf7`; `68bb779` changes Linux code only),
  XCTest 579 tests, 5 skipped, 0 failures; swift-testing 506 tests in 82 suites passed. The skips are the
  baseline's.
- **Linux** (`Utilities/linux/build.sh --quiet --root .build/cov5-linux-src … test`, swift:6.2-noble arm64, on
  `git archive` copies so the worktree could change meanwhile):
  - `636f5f3`: XCTest 490 tests, 6 skipped, 0 failures; swift-testing 483 tests in 81 suites passed
    (`../linux-logs/coverage-5-636f5f3-test.log`).
  - `1afadf7`: the build failed (section 16; `../linux-logs/coverage-5-1afadf7-test.log`).
  - `68bb779`: XCTest 491 tests, 6 skipped, 0 failures; swift-testing 484 tests in 81 suites passed
    (`../linux-logs/coverage-5-68bb779-test.log`), with sections 3, 11 and 16's Linux tests among them.
- **Win32 harness**: `Prototype/Win32/check-windows.sh` compiles the Win32 files and the Windows tests after
  section 8.
- Not built: WASI, Musl, Android, FreeBSD, OpenBSD (coordinator's rule; written from the headers in
  `../linux-logs/cross/sdks` where they exist).

## Findings

- **Swift doesn't import a macro that names an enum constant of another name** (glibc's `#define YESEXPR
  __YESEXPR`); a self-named one (`#define CODESET CODESET`) is fine. Spell the constant.
- **wasip1's `libc.a` (6.2.4 SDK) has no pthread functions**, stubs included, so anything threads-only on WASI
  must stay under `_runtime(_multithreaded)` or do without (N2).
- **wasi-libc's sockets**: `AF_INET` 1, `AF_INET6` 2, `AF_UNIX` 3; `sockaddr_un` has only `sun_family`;
  `SOCK_*`, `SHUT_*` and `MSG_*` come from `wasi/api.h`, and `SOCK_STREAM`'s `UINT8_C()` form doesn't import;
  `socket`, `bind`, `connect`, `listen`, `setsockopt`, `getsockname` and `sendto` are declared only for wasip2.
- **Bionic's `FILE`** is defined (`<bits/struct_file.h>`) only below API level 24; the Swift SDK for Android's
  targets start at 28.
- **The UNIX-REPORT's section 6.1 table is older than `gaps/<pkg>.md`**: `fd_set` (TSC) and WasmKit's pthread
  rows are gone from the per-package files, and the table omits 1-site rows.
- **swift-build's `SWBDispatch` marker for `off_t` is stale**: `CInterop.Offset` exists (`12c5ac9`).

## Needs outside this lane's files

- `CLAUDE.md`'s SystemSockets bullet ("its files `#error` outside Darwin, Glibc, Musl, and Android"): on WASI it
  now builds its address subset (section 2).
- `Sources/Samples` (the demos lane's): the socket samples need `#if !os(WASI)` for a WASI build of the whole
  package, which now gets past SystemSockets.
- `Prototype/Win32/WindowsModel/SystemPackageStubs.swift` (windows lanes): `close() throws` →
  `throws(Errno)`, to match section 8.
- platforms-2's `cross.sh` WASI copy can keep SystemSockets now.
- The adopter lanes: rerun `scripts/inventory.py` (UNIX-REPORT) and `tools-p6` (PACKAGES-6) to close this lane's
  rows; swift-build's `off_t` marker (Findings).
