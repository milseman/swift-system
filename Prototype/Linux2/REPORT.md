# linux-2: a clean Linux run, O1, and the adopters on Linux

Lane `linux-2` (worktree `../linux-2`, branch `linux-2`, base system-next `4365f83`). Linux runs are
swift:6.2-noble on arm64 (Swift 6.2.4, glibc 2.39, kernel 6.18), through `Utilities/linux/build.sh --quiet`,
with logs in `../linux-logs/linux-2-<commit>-<what>.log`.

## Resume here

- Done (converging, 2026-10-01):
  - Step 1, the Linux run clean as root and as 1000:1000: `1173838` (section 1).
  - Step 2, O1 on Linux: no change needed (section 2).
  - Step 3, `build.sh --root/--dir/--mount`: `cf4ef08` (section 3).
  - Step 4, unix-adopt on Linux: swift-nio's `migrate-unix` `cc819b01` built and tested in a scratch copy with
    six fixes (section 4.1, "For unix-adopt", Appendix A); `CInterop.EPollEvent`'s doc `67a8a8d`; README's
    Linux pitfalls and the report `3ac2c29`. The CSystem module-import experiment, `440eac5`, `5ea8bef` and
    `54f5258`, is reverted by `c259458`, `9f95920` and `9f41cfd` (section 4.3).
  - system-next `70e1766` (with this lane's `3ac2c29`, other-platforms and windows-2) merged: `1ce85c1`.
- In progress: nothing; nothing is uncommitted.
- Next step: swift-foundation's `bde165fd` on Linux (section 4.2), which needs a toolchain newer than the 6.3
  image; pulling `swiftlang/swift:nightly-main-noble` was refused by the permission classifier, so it waits for
  Michael (an allow rule such as `Bash(Utilities/linux/build.sh --quiet --image swiftlang/swift:nightly-main-noble:*)`).
  Then: a scratch copy (`git -C ../adopters-unix/swift-foundation archive bde165fd` into
  `.build/foundation-scratch/adopters-unix/swift-foundation`, and an empty `.build/foundation-scratch/swift-system`),
  `Utilities/linux/build.sh --quiet --image <image> --root .build/foundation-scratch --dir
  adopters-unix/swift-foundation --mount .:swift-system --log <absolute path> build-tests`, then unix-adopt's
  section 2.2 tests; then WasmKit and the others as unix-adopt commits them (none had commits on 2026-10-01).
- Notes for other lanes: "For unix-adopt" (swift-nio's six fixes, Appendix A's patch) and "Needs outside this
  lane's files" (demos' `TerminalSize.swift` reading `winsize`'s fields; a MemberImportVisibility probe with a
  C module of its own).
- Latest tests, at `1ce85c1`: Darwin, XCTest 572 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82
  suites passed. Linux as root (`linux-2-1ce85c1-root.log`), XCTest 482 tests, 6 skipped, 0 failures;
  swift-testing 463 tests in 78 suites passed; as 1000:1000 (`linux-2-1ce85c1-user.log`), 482 tests, 4 skipped,
  0 failures, and 463 tests in 78 suites passed.
- Scratch: this lane's `.build` (and with it the NIO and Foundation copies and the probe package) is deleted;
  the logs stay in `../linux-logs/linux-2-*`.
- How to run: System's Linux run is `container system start >/dev/null 2>&1; Utilities/linux/build.sh --quiet
  --log ../linux-logs/linux-2-$(git rev-parse --short HEAD)-<what>.log test`, with `--user 1000:1000` and `--
  --filter <Suite>`; commit first, since the log is named for HEAD. An adopter's run is `--root .. --dir
  adopters-unix/<pkg>`, with `--scratch` and `--log` outside its worktree and `--mount .:swift-system`.

## For unix-adopt

What fails on Linux in `../adopters-unix`, per package and file. Each fix was tried in a scratch copy, not in the
worktrees, and the whole patch is Appendix A; section 4.1 has the runs and causes.

**swift-nio, `migrate-unix` `cc819b01`** (and `bc853b38` before it): `swift build --build-tests` fails in NIOPosix
(52 errors in 10 files) and NIOEmbeddedTests (2); with the six fixes below, everything builds and the whole suite
passes on Linux but one test that fails on upstream NIO too in the container (section 4.1).

1. **System's accessors on C types aren't found** where CNIOLinux declares the types too (cause 1 in section
   4.1): `iovec(base:length:)` in `PendingWritesManager.swift:80`, `PendingDatagramWritesManager.swift:161`,
   `Socket.swift:211`, `:277` and `DatagramVectorReadManager.swift:132`; `.family` on `sockaddr_storage` and
   `sockaddr` in `BaseSocket.swift:66`, `:80`, `:94`, `:106`, `:131`; `.address` on `sockaddr_in` and
   `sockaddr_in6` in `SocketChannel.swift:1289` to `:1345`; `.control` and `.controlLength` on `msghdr` in
   `BSDSocketAPIPosix.swift:451` to `:455`; `sockaddr_in6(family:port:flowInfo:address:scopeID:)` in
   `ControlMessage.swift:311`; and the errors that follow from these (`Socket.swift:223`, `:285`, `:286`,
   `ControlMessage.swift:270`, `DatagramVectorReadManager.swift:226`). Fix: `CNIOLinux.h` imports glibc's
   Swift module before its includes, under Swift (`#include <features.h>`, then `#pragma clang module import
   SwiftGlibc` if `__swift__` and `__GLIBC__`), so that CNIOLinux declares none of glibc's types. Without it,
   with the other fixes, these 27 errors come back. Musl and Bionic need their own module's name there
   (unchecked).
2. **epoll_event's C fields and initializer** need CSystem, which NIO can't import (`property 'events' is
   not available due to missing import of defining module 'CSystem'`): `SelectorEpoll.swift` (24 errors:
   `init(epollEvent:)`, each register call, and `whenReady`'s `ev.data.u64`), `SelectorGeneric.swift:280`
   (`EventType()`), `Tests/NIOPosixTests/StreamChannelsTest.swift:1258`. Fix: `Epoll.epoll_event` is System's
   `EventPoll.Event` (the alternative step 4 rejected), whose `events` and `data` are a `Mask` and a `Data`;
   `Linux.swift` gains an empty `EventPoll.Event()` for the selector's buffer, and `epoll_wait` no longer
   rebinds the buffer.
3. **`ChannelOptions.socket(_:_:)` takes an `Int` level on Linux** (`SocketOptionLevel`), where Darwin's is
   `CInt`: `Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift:835` and `AsyncTestingChannelTests.swift:761`,
   from the Darwin round's `NIOBSDSocket.OptionLevel.ip.rawValue` (upstream passes `IPPROTO_IP`, an `Int` on
   glibc). Fix: `SocketOptionLevel(NIOBSDSocket.OptionLevel.ip.rawValue)`.
4. **`FileType.whiteout` is Darwin's** in System: `Tests/NIOFSTests/FileTypeTests.swift:30` and `:40` (`S_IFWHT`,
   `DT_WHT`). Fix: those two lines under `#if canImport(Darwin)`, as their uses already are.
5. **The received IPv4 TOS byte's type** (a run-time failure): `ControlMessage.swift:232` compares Linux's
   control messages with `IP_RECVTOS`, Darwin's type for it, but Linux sends it as `IP_TOS`, so ECN states
   read as not ECN-capable: 6 `DatagramChannelTests` failed (`testEcnSendReceiveIPV4` and its vector variants,
   `testReceiveEcnAndPacketInfoIPV4` and its vector variants). Fix: `IP_RECVTOS` on Darwin, `IP_TOS`
   (`SocketDescriptor.IPOption.typeOfService`) on Linux and Android, as the C branch had it; SystemSockets'
   `AncillaryMessageBuffer.Message.typeOfService` decodes either, if the parser moves to it.
6. **The tests' `memcmp` helper is ambiguous** with glibc's, which NIOPosix re-exports:
   `Tests/NIOPosixTests/SocketAddressTest.swift:472`, `:479`, `:486`. Fix: the helper is Darwin's only.

Also stale after fix 2: `SelectorEpoll.swift`'s import comment (fixed in the patch).

## Baseline

At `4365f83`:

- Darwin (`swift build && swift test`): XCTest 571 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82
  suites passed.
- Linux, as root (`linux-2-4365f83-baseline.log`): XCTest 481 tests, 6 skipped, 5 failures; swift-testing 463
  tests in 78 suites, 7 issues.

## 1. The Linux run, clean: `1173838`

Each failure, what caused it, and the fix. Only one expectation was a root assumption as the brief had it; the
others are Linux's or glibc's behavior, where System's code is right, so the tests changed, and where a doc would
have misled a reader on Linux, it says what Linux does.

| Test | Cause | Fix |
|---|---|---|
| DirectoryWalk: `anUnreadableDirectoryOnce`, `anUnreadableDirectoryWhenEntered`, `anUnreadableDirectory` (bounded), `entriesWhoseStatusCantBeRead` | `try #require(getuid() != 0)` records an issue as root rather than skipping | `@Test(.enabled(if: geteuid() != 0, "root can read any directory"))`, as `DirectoryWalkTests.anUnreadableDirectoryIsReportedAndSkipped` has it |
| `ProcessCredentialsTests.aUsersGroups` | glibc's `getgrouplist` lists the group it's given and the groups whose member lists name the user. Darwin's list also has the user's primary group. With another group included, root's group 0 isn't in glibc's list, since `/etc/group` doesn't list root as a member of group 0 | off Darwin, the check adds the primary group back; `GroupID.supplementary(forUser:including:)`'s doc says how the lists differ |
| `ProcessPriorityTests.adjustingTheCallersPriority` | Not root: Linux's nice values are per thread (nice(2), setpriority(2) BUGS). `nice` changes the calling thread's, and `PRIO_PROCESS` with the process's ID reads its main thread's, while the exit test's body runs on another thread; so the read-back after `adjust(by: 3)` found the main thread's 0, and the first guard failed. The root branch was right | off Darwin, the test reads `.process(ProcessID(rawValue: 0))`, the calling thread; `ProcessPriority`'s doc says what a nice value belongs to on Linux, and `adjust(by:)`'s says the calling thread's |
| `ProcessTimerTests.testSettingAndReadingEachTimer` | Linux adds a scheduler tick (`TICK_NSEC`: 4 ms at 250 Hz) to `ITIMER_VIRTUAL`'s and `ITIMER_PROF`'s expiration (`set_cpu_itimer`), so a timer set to 100,000 s reads back 100,000.004 s | the upper bound allows 10 ms (100 Hz's tick) for those two on Linux and Android; `setSchedule(_:)`'s doc says it |
| `IORingTests.testPollAddMultiShotRearmsAcrossEvents` | A test bug from `a83fffe` (test-hygiene, unbuilt on Linux): the wait for the cancelled poll's last completion used `blockingConsumeCompletion()`, which throws a failed completion's result, so the poll's `-ECANCELED` came as a thrown error, which ended the wait with nothing recorded (only the cancel's own completion, context 0, result 1) | the wait polls the ring's descriptor, readable while a completion waits (up to the hang guard), and takes completions with `tryConsumeCompletion()`, which returns them as they are |
| `ProvisionalStdioTests.testBuffering` | glibc's `fwrite` sends a stream's first write straight to the descriptor when the buffer is smaller than 128 bytes (`_IO_new_file_xsputn` writes whole blocks, and a block under 128 bytes is written through). The test's line-buffered stream had a 64-byte buffer, so `part` arrived before the newline. Not `setvbuf` failing, as linux-api's section 3 had it: the call that didn't throw was the read that expected `EAGAIN` | a 256-byte buffer; `setBuffering(_:buffer:)`'s doc says it |
| `ProvisionalMathTests.knownValues` | glibc 2.39's `cbrt` isn't correctly rounded: `cbrt(-27.0)` isn't -3 (`cbrt(-8.0)` is -2) | within 1e-15; `Math`'s doc says its results are the C library's |

Design calls:

- Skipping as root is a trait (`.enabled(if:)`), not `#require`, so a root run reports a skip with the reason.
  `geteuid`, since permission checks use the effective user.
- The per-thread nice value is documented, not worked around: `ProcessPriority` wraps `getpriority`, `setpriority`
  and `nice` as they are, and System isn't a cross-platform abstraction. Rejected: a `Target` case for the caller
  (who 0), new API that the doc's `ProcessID(rawValue: 0)` already spells; making `.process(.current)` pass 0 on
  Linux, which would change what a process's ID means there.
- The IORing wait: rejected, catching the thrown `ECANCELED` as the poll's completion, which loses its flags, and
  the check that the poll isn't still armed is what the test is for; and registering an eventfd with the ring,
  which works too but adds a descriptor and a read the ring's own readability already gives.

Left, noted: the same test's `first.result == -EINVAL` skip (kernels before 5.13 reject multishot polls) can't
happen, since `blockingConsumeCompletion()` would throw `EINVAL` instead; on such a kernel the test fails rather
than skips. It's unreachable on 6.18, so it's unchanged here.

Linux at `1173838`:

- As root (`linux-2-1173838-root.log`): XCTest 481 tests, 6 skipped, 0 failures; swift-testing 463 tests in 78
  suites passed (5 skipped as root: the four above and `anUnreadableDirectoryIsReportedAndSkipped`). The XCTest
  skips: `testChangesToAnotherUsersFileAreNotPermitted`, `testChangingTheRootNeedsPrivileges` and
  `testCredentialsThatNeedRoot` (root), `testControllingTerminal` (no controlling terminal), and
  `ProvisionalLocaleLinuxTest`'s two named-locale tests (no `fr_FR.UTF-8` in the image).
- As 1000:1000 (`linux-2-1173838-user.log`): XCTest 481 tests, 4 skipped, 0 failures; swift-testing 463 tests in
  78 suites passed. The skips: `testAnotherUsersChild` (needs root), `testControllingTerminal`, and the two locale
  tests.

Darwin at `1173838`: XCTest 571 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82 suites passed.

## 2. O1: coverage-3's new API on Linux

Coverage-3's O1 (Prototype/Status/REPORT.md, sections 42 and 43), for Linux: `CInterop.Offset`,
`SystemConfig.maxAtomicPipeWriteBytes` and PThread cancellation build on glibc, and their tests pass, in both of
section 1's runs, with no change here:

- `OffsetAndPipeLimitTest` (3 XCTest tests): `CInterop.Offset` is `off_t` and `Int` on Linux;
  `maxAtomicPipeWriteBytes` is glibc's `PIPE_BUF`, 4096; a pipe's `fpathconf` limit is the same.
- `PThread cancellation` (4 swift-testing tests) and `PThreadCancellationMockTests` (2 XCTest tests): on glibc too,
  a cancelled thread ends at its next cancellation point, a pipe read that blocks included, and the disabled scope
  holds it off and restores the state it found; the thread-specific value's destructor, which the tests wait for,
  runs as the thread ends.

Not here: O1's Windows and WASI halves (the windows-2 and other-platforms lanes), and Musl (no static SDK run).
No code changed for this step, so section 1's Darwin and Linux summaries are its own.

## 3. build.sh: another package, with the packages beside it: `cf4ef08`

`Utilities/linux/build.sh` mounted only this package at `/code`, so an adopter's `.package(path:
"../../swift-system")` didn't resolve in the container (unix-adopt's section 4 asked for this).

- `--root <dir>` mounts `<dir>` at `/code` instead of this package, and `--dir <path>` names the package under it,
  where the swift command runs (`-w /code/<path>`); it must be inside the root and have a `Package.swift`.
- `--mount <dir>:<path>` (repeatable) mounts another directory over one under the root. With `.:swift-system`, an
  adopter builds against this worktree rather than the checkout its manifest names, so a System fix can be tried
  on it before it's merged.
- `--scratch` and `--log` stay relative to the package, now `<root>/<dir>`; a log can also be absolute.
- The `==` lines and the log's first line name the package's container path and the root when they aren't this
  package. `--quiet`'s summary makes paths relative to the package: its own lose `/code/<dir>/`, the root's others
  get `../` up to the root (`../../swift-system/Sources/...`); XCTest's failures are the `error:` lines under the
  package's `Tests/`.
- README.md: the options' table, and a section with both examples.

Design calls: the paths stay relative to the package, as the scratch path already was, rather than to the
current directory or this checkout, so the default mode's rule doesn't change. Rejected: mounting the root
read-only, with a writable scratch mount elsewhere, which would make SwiftPM fail when it has to update
`Package.resolved`; a pass-through for any `container` argument, which the one needed mount doesn't justify.

Checks:

- Without the new options, nothing changed: with a stand-in `container` that records its arguments and replays a
  recorded log, the old and new scripts pass the same arguments, print the same lines, and write the same log but
  for its date. With it, root mode's arguments, header and summary (a package error, a root error, an XCTest
  failure under the package's Tests), and each argument check.
- On Linux: `--root .. --dir linux-2 ... test -- --filter ProcessTimerTests` (`linux-2-cf4ef08-rootmode.log`)
  and `--root .. --dir swift-system --mount .:swift-system` (`linux-2-cf4ef08-overlay.log`), 5 XCTest tests each,
  passing. The second passes only with this lane's timer fix, which the swift-system checkout (system-next
  `4365f83`) doesn't have, so the overlay is what the container built; that checkout's status stayed clean, and
  SwiftPM rewrote no `Package.resolved`.
- No Swift changed, so section 1's Darwin and Linux summaries stand for this step.

## 4. unix-adopt's rewrites on Linux

Each adopter is built from `--root ..`, with `--mount .:swift-system` so its `../../swift-system` is this
worktree (system-next `4365f83` and this lane's changes), and with the scratch path and log outside its
worktree. A worktree is built only as it is; fixes are tried in a scratch copy (`git archive` of its commit,
in this worktree's `.build`, at the same container paths). After each run, the worktree's status and its
`Package.resolved` were unchanged.

### 4.1 swift-nio

At `bc853b38`, then `cc819b01` (unix-adopt's step 7), as root unless said:

| Run | Log (`../linux-logs/linux-2-…`) | Result |
|---|---|---|
| the worktree, `build-tests` | `9420f17-nio-bc853b38-build-tests.log` | 17 errors in NIOPosix and NIOEmbeddedTests |
| the worktree, `build-tests` | `9f41cfd-nio-cc819b01-build-tests.log` | 54 errors (52 in NIOPosix), under "For unix-adopt" |
| scratch at `bc853b38`, fixes 1 to 4, 6 | `9420f17-nioscratch-3.log` | builds |
| the same, section 2.1's suites | `9420f17-nioscratch-test-listed.log` | XCTest 381 tests, 1 skipped, 6 failures (fix 5's); swift-testing 78 tests in 1 suite passed |
| the same with fix 5, `DatagramChannelTests` | `9420f17-nioscratch-test-datagram.log` | 78 tests, 1 skipped, 0 failures |
| scratch at `bc853b38`, all fixes, `test` | `9420f17-nioscratch-test-all.log` | XCTest 2394 tests, 19 skipped, 2 failures; swift-testing 303 tests in 19 suites passed |
| upstream `feaf4ac5`, the failing test | `9420f17-nio-upstream-feaf4ac5-bootstrap.log` | the same 2 failures |
| scratch at `cc819b01`, all fixes but 1 | `9f41cfd-nioscratch-cc819b01-nopragma.log` | 27 errors, fix 1's |
| scratch at `cc819b01`, all fixes, `test` | `9f41cfd-nioscratch-cc819b01-test-all.log` | XCTest 2394 tests, 19 skipped, 2 failures; swift-testing 303 tests in 19 suites passed |
| the same, as 1000:1000 | `9f41cfd-nioscratch-cc819b01-test-all-user.log` | XCTest 2394 tests, 24 skipped, 2 failures; swift-testing 303 tests in 19 suites passed |

The 2 failures are one test, `BootstrapTest.testClientBindWorksOnSocketsBoundToEitherIPv4OrIPv6Only`, which
resolves `ip6-localhost`: the container's hosts file has no such name (`EAI_NONAME`), and upstream NIO fails it
the same way there. The first run listed fewer errors than the second because a failed emit-module job ends the
build before the compile jobs report errors in code that isn't inlinable; so a first failing build shows only
the first layer.

The causes, by fix (the list under "For unix-adopt"):

1. **Two copies of one C type.** glibc's Swift module map lists only `SwiftGlibc.h`, so a C module that
   includes a glibc header itself, as CNIOLinux does, gets a textual copy of the header's types: `iovec`,
   `msghdr`, `sockaddr`, `sockaddr_storage`, `sockaddr_in`, `sockaddr_in6` here. Clang merges the copies, and
   Swift attributes the type to the module whose copy a compile loads first. System's accessors are
   extensions declared against glibc's copy, and Swift finds a C type's extensions in another module by the
   type's module name, so where CNIOLinux's copy is loaded first they aren't there: `has no member`, or
   `incorrect argument labels` with only C's initializer offered, rather than a MemberImportVisibility error.
   Which copy loads first depends on what each frontend job's files touch first, so the set changes from
   build to build: in a throwaway client package (`.build/linux-2-probe`, a C module that includes
   `<sys/uio.h>` and `<netinet/in.h>`, and one file per case), `sockaddr_in.address` through that module
   failed in two of three builds and passed in the other, as `iovec(base:length:)` did the other way; with the
   module import in the C module's header, both passed. The import makes the C module's includes find glibc's
   headers already included (their guards are glibc's module's macros), so it declares no copies. It must come
   after something that defines `__GLIBC__`, which glibc's headers do: `<features.h>`, which declares no types.
2. **A type only CSystem declares.** glibc's module has no `<sys/epoll.h>` (a client of Glibc can't call
   `epoll_create1`), so `epoll_event` comes from CSystem's header, and under MemberImportVisibility its fields
   and zero initializer need CSystem, in inlinable code and the rest alike. CNIOLinux has a copy too, so its
   members could also go either way. `EventPoll.Event` is a Swift structure, whose accessors are System's
   own members, so they're always found. System's alias now says so (`67a8a8d`).
3. **The Darwin round's change** to `IPPROTO_IP`, which unix-adopt's widening carried to Linux.
4. **A Darwin-only System name** in a widened branch, which the scratch typecheck can't see: `whiteout`.
5. **Behavior**: Linux and Darwin send the received TOS byte under different control message types.
6. **glibc's `nonnull`**: glibc's `memcmp` takes non-optional pointers, and with `UnsafePointer<sockaddr>`
   arguments neither candidate wins, where step 5 expected the C function to.

Design calls:

- Fix 1 in the C module, not at the call sites. Rejected: spelling the types `CInterop.…` in the files, which
  doesn't decide which copy loads first; not importing CNIOLinux where System's accessors are used, which any
  other file in the same frontend job can undo. The module import is the one change that removes the copies.
- Fix 2 by the Swift wrapper, which step 4 rejected for its size; it's a 40-line change. Rejected: Swift-named
  accessors on `CInterop.EPollEvent`, which as extensions of a C type would vanish just as fix 1's do whenever
  CNIOLinux's copy of `epoll_event` loads first.
- No System change was needed beyond the doc: everything NIO's Linux branches call is built on Linux.

System's changes in this step: `CInterop.EPollEvent`'s doc (`67a8a8d`), and README.md's two Linux pitfalls
(`3ac2c29`). Darwin and Linux after are the summaries in "Resume here", at `3ac2c29`.

### 4.2 swift-foundation

Not built past its own first module. `bde165fd` is unix-adopt's commit (the worktree also has uncommitted
changes, which a build of it would include, so the run is of a scratch copy of the commit). unix-adopt builds it
on Darwin with a 6.5 development snapshot.

- swift:6.3-noble (`linux-2-67a8a8d-foundation-bde165fd-6.3-build-tests.log`): ICU, swift-syntax and this
  worktree's SystemPackage build; FoundationEssentials fails in upstream code that needs a newer standard
  library (`ConvertibleToBytes` and `ConvertibleFromBytes`, `RawSpan`'s `load` and subscripts, in
  `Span+Utils.swift`, `String+IO.swift` and `UUID.swift`'s span code, which unix-adopt didn't change), so none
  of unix-adopt's 30 files is checked.
- A main-branch nightly image (`--image swiftlang/swift:nightly-main-noble`, a first pull) was refused by the
  permission classifier, so Foundation waits for Michael's call (below).

### 4.3 The same module import in CSystem: tried, reverted

linux-api's section 3 suggested importing glibc's module in `CSystemLinux.h`, so that CSystem declares none of
glibc's types (it declares `timespec`, `timeval`, `sigset_t` and `fd_set` through `<sys/types.h>` and
`<sys/epoll.h>`). Tried in `440eac5`, with `5ea8bef` (`Constants+Provisional.swift` imports CSystem
`@preconcurrency`, since CSystem then re-exports glibc's module and its mutable `stdin`) and `54f5258`
(`CInterop.WinSize = Glibc.winsize`), and reverted in `c259458`, `9f95920` and `9f41cfd`: with it, Samples'
`TerminalSize.swift`, which reads `winsize`'s `ws_xpixel`, failed with `not available due to missing import of
defining module 'SwiftOverlayShims'` (the Swift runtime's shim module includes `<sys/ioctl.h>` too), and
qualifying System's alias didn't change it (`linux-2-54f5258-root.log`). The import changes which copies each
compile loads first in ways System's files can't steer, and nothing failing needed it.

## Findings

- System's code was right on Linux in each of the failures: they were tests written for Darwin's behavior, or
  rewritten without a Linux build (section 1). Three docs now say what Linux does differently: per-thread nice
  values, the processor-time timers' tick, and glibc's writes through a small stdio buffer.
- **A client's own C module can hide System's accessors** (section 4.1, cause 1). Any adopter whose C shim
  module includes glibc headers itself (NIO's CNIOLinux; by their headers likely `_FoundationCShims`,
  `_SubprocessCShims`, TSC's `TSCclibc`) can lose `CInterop` accessors on Linux, from build to build. The
  durable fix is in the shim's header, as fix 1 has it; the scratch typecheck on Darwin can't see this, since
  Darwin's headers are modular.
- **The same can happen through modules nobody controls**: the Swift runtime's `SwiftOverlayShims` includes
  `<sys/ioctl.h>`, `<semaphore.h>`, `<sys/types.h>` and `<unistd.h>` (section 4.3). Reading a C type's fields
  directly, as Samples' `TerminalSize.swift` does for `winsize`, works today by load order.
- **A failing build shows one layer of errors** when emit-module fails first (section 4.1): judge a Linux
  build's breakage by a run that gets past it.

## Needs outside this lane's files

- unix-adopt: the fixes under "For unix-adopt" (Appendix A), in `../adopters-unix/swift-nio`.
- demos (Sources/Samples): `TerminalSize.swift:75` reads `winsize`'s `ws_xpixel` and `ws_ypixel` directly, which
  depends on which copy of `winsize` the compile loads first (section 4.3); System's
  `TerminalDescriptor.WindowSize` has no pixel accessors, so either it gains them or the sample keeps the C
  fields, knowing why.
- Tests/MemberImportVisibility: its probes import no C module of their own, so they can't catch section 4.1's
  cause 1. A probe target with one (as `.build/linux-2-probe` had) would, though only in the builds where that
  module's copy loads first.

## Appendix A: swift-nio's Linux fixes, the patch

On `migrate-unix` `cc819b01`, from the scratch copy (`git apply` in `../adopters-unix/swift-nio`):

```diff
diff --git a/Sources/CNIOLinux/include/CNIOLinux.h b/Sources/CNIOLinux/include/CNIOLinux.h
index c5cf388..95fb2a8 100644
--- a/Sources/CNIOLinux/include/CNIOLinux.h
+++ b/Sources/CNIOLinux/include/CNIOLinux.h
@@ -15,6 +15,16 @@
 #define C_NIO_LINUX_H
 
 #ifdef __linux__
+// Under Swift, glibc's Swift module first: its headers are then already
+// included, so this module doesn't declare their types again. A C type
+// that two modules declare belongs to whichever copy a compile loads
+// first, and then System's accessors, extensions of the C library's
+// copy, can't be found.
+// <features.h> declares no types, and says whether this is glibc.
+#include <features.h>
+#if defined(__swift__) && defined(__GLIBC__)
+#pragma clang module import SwiftGlibc
+#endif
 #include <poll.h>
 #include <sys/epoll.h>
 #include <sys/eventfd.h>
diff --git a/Sources/NIOPosix/ControlMessage.swift b/Sources/NIOPosix/ControlMessage.swift
index 53c2b74..c8eb054 100644
--- a/Sources/NIOPosix/ControlMessage.swift
+++ b/Sources/NIOPosix/ControlMessage.swift
@@ -229,8 +229,11 @@ struct ControlMessageParser {
         }
     }
 
-    #if canImport(Darwin) || os(Linux) || os(Android)
+    #if canImport(Darwin)
+    // Darwin reports the received TOS byte as IP_RECVTOS, Linux as IP_TOS.
     private static let ipv4TosType = SocketDescriptor.IPOption.receiveTypeOfService.rawValue
+    #elseif os(Linux) || os(Android)
+    private static let ipv4TosType = SocketDescriptor.IPOption.typeOfService.rawValue
     #else
     private static let ipv4TosType = IP_TOS  // Linux
     #endif
diff --git a/Sources/NIOPosix/Linux.swift b/Sources/NIOPosix/Linux.swift
index 6b20a70..278ed14 100644
--- a/Sources/NIOPosix/Linux.swift
+++ b/Sources/NIOPosix/Linux.swift
@@ -130,12 +130,21 @@ internal enum EventFd {
     }
 }
 
+extension EventPoll.Event {
+    /// An empty event, for the selector's buffer.
+    @usableFromInline
+    internal init() {
+        self.init(events: [], data: EventPoll.Event.Data(rawValue: 0))
+    }
+}
+
 @usableFromInline
 internal enum Epoll {
-    /// The C struct, which System's `EventPoll.Event` wraps (a frozen struct with it as its one
-    /// stored property, so a buffer of one is a buffer of the other).
+    /// System's `EventPoll.Event`, a frozen struct around the C struct, through which the
+    /// selector reads and writes the fields: the C struct's own belong to CSystem's copy of
+    /// `<sys/epoll.h>` (glibc's Swift module has none), which NIO can't import.
     @usableFromInline
-    internal typealias epoll_event = CInterop.EPollEvent
+    internal typealias epoll_event = EventPoll.Event
 
     /// `epoll_ctl`'s operations, which System spells as `EventPoll`'s `add`, `modify` and `remove`.
     @usableFromInline
@@ -185,7 +194,7 @@ internal enum Epoll {
         fd: CInt,
         event: UnsafeMutablePointer<epoll_event>
     ) throws -> CInt {
-        let event = EventPoll.Event(rawValue: event.pointee)
+        let event = event.pointee
         let descriptor = SystemPackage.FileDescriptor(rawValue: fd)
         return try systemCall(blocking: false) {
             try withEventPoll(epfd) { poll throws(Errno) in
@@ -213,17 +222,15 @@ internal enum Epoll {
         // epoll_wait's -1 waits until an event arrives, which System spells nil.
         let wait: Duration? = timeout < 0 ? nil : .milliseconds(timeout)
         return try systemCall(blocking: false) {
-            try events.withMemoryRebound(to: EventPoll.Event.self, capacity: Int(maxevents)) { events in
-                let buffer = UnsafeMutableBufferPointer(start: events, count: Int(maxevents))
-                let count = try withEventPoll(epfd) { poll throws(Errno) in
-                    // System's wait appends to an OutputSpan; this one covers the caller's buffer.
-                    var span = OutputSpan<EventPoll.Event>(buffer: buffer, initializedCount: 0)
-                    let count = try poll.wait(into: &span, timeout: wait)
-                    _ = span.finalize(for: buffer)
-                    return count
-                }
-                return CInt(count)
+            let buffer = UnsafeMutableBufferPointer(start: events, count: Int(maxevents))
+            let count = try withEventPoll(epfd) { poll throws(Errno) in
+                // System's wait appends to an OutputSpan; this one covers the caller's buffer.
+                var span = OutputSpan<EventPoll.Event>(buffer: buffer, initializedCount: 0)
+                let count = try poll.wait(into: &span, timeout: wait)
+                _ = span.finalize(for: buffer)
+                return count
             }
+            return CInt(count)
         }.result
     }
 
diff --git a/Sources/NIOPosix/SelectorEpoll.swift b/Sources/NIOPosix/SelectorEpoll.swift
index 4d11a62..57725e5 100644
--- a/Sources/NIOPosix/SelectorEpoll.swift
+++ b/Sources/NIOPosix/SelectorEpoll.swift
@@ -20,7 +20,8 @@ import NIOCore
 #if !SWIFTNIO_USE_IO_URING
 
 #if os(Linux) || os(Android)
-// epoll_event's fields and itimerspec, the C structs (System's CInterop.EPollEvent and ITimerSpec).
+// Events as System's EventPoll.Event (Linux.swift's Epoll.epoll_event), and itimerspec, the C struct
+// (System's CInterop.ITimerSpec).
 import CNIOLinux
 import SystemPackage
 
@@ -87,20 +88,21 @@ extension SelectorEventSet {
 
     @inlinable
     internal init(epollEvent: Epoll.epoll_event) {
+        let events = epollEvent.events.rawValue
         var selectorEventSet: SelectorEventSet = ._none
-        if epollEvent.events & Epoll.EPOLLIN != 0 {
+        if events & Epoll.EPOLLIN != 0 {
             selectorEventSet.formUnion(.read)
         }
-        if epollEvent.events & Epoll.EPOLLOUT != 0 {
+        if events & Epoll.EPOLLOUT != 0 {
             selectorEventSet.formUnion(.write)
         }
-        if epollEvent.events & Epoll.EPOLLRDHUP != 0 {
+        if events & Epoll.EPOLLRDHUP != 0 {
             selectorEventSet.formUnion(.readEOF)
         }
-        if epollEvent.events & Epoll.EPOLLERR != 0 {
+        if events & Epoll.EPOLLERR != 0 {
             selectorEventSet.formUnion(.error)
         }
-        if epollEvent.events & Epoll.EPOLLHUP != 0 {
+        if events & Epoll.EPOLLHUP != 0 {
             selectorEventSet.formUnion(.reset)
         }
         self = selectorEventSet
@@ -146,24 +148,24 @@ extension Selector: _SelectorBackendProtocol {
         self.lifecycleState = .open
 
         var ev = Epoll.epoll_event()
-        ev.events = SelectorEventSet.read.epollEventSet
-        ev.data.u64 = UInt64(
+        ev.events = EventPoll.Event.Mask(rawValue: SelectorEventSet.read.epollEventSet)
+        ev.data = EventPoll.Event.Data(rawValue: UInt64(
             EPollUserData(
                 registrationID: .initialRegistrationID,
                 fileDescriptor: self.eventFD
             )
-        )
+        ))
 
         try Epoll.epoll_ctl(epfd: self.selectorFD, op: Epoll.EPOLL_CTL_ADD, fd: self.eventFD, event: &ev)
 
         var timerev = Epoll.epoll_event()
-        timerev.events = Epoll.EPOLLIN | Epoll.EPOLLERR | Epoll.EPOLLRDHUP
-        timerev.data.u64 = UInt64(
+        timerev.events = EventPoll.Event.Mask(rawValue: Epoll.EPOLLIN | Epoll.EPOLLERR | Epoll.EPOLLRDHUP)
+        timerev.data = EventPoll.Event.Data(rawValue: UInt64(
             EPollUserData(
                 registrationID: .initialRegistrationID,
                 fileDescriptor: self.timerFD
             )
-        )
+        ))
         try Epoll.epoll_ctl(epfd: self.selectorFD, op: Epoll.EPOLL_CTL_ADD, fd: self.timerFD, event: &timerev)
     }
 
@@ -179,8 +181,8 @@ extension Selector: _SelectorBackendProtocol {
         registrationID: SelectorRegistrationID
     ) throws {
         var ev = Epoll.epoll_event()
-        ev.events = interested.epollEventSet
-        ev.data.u64 = UInt64(EPollUserData(registrationID: registrationID, fileDescriptor: fileDescriptor))
+        ev.events = EventPoll.Event.Mask(rawValue: interested.epollEventSet)
+        ev.data = EventPoll.Event.Data(rawValue: UInt64(EPollUserData(registrationID: registrationID, fileDescriptor: fileDescriptor)))
 
         try Epoll.epoll_ctl(epfd: self.selectorFD, op: Epoll.EPOLL_CTL_ADD, fd: fileDescriptor, event: &ev)
     }
@@ -193,8 +195,8 @@ extension Selector: _SelectorBackendProtocol {
         registrationID: SelectorRegistrationID
     ) throws {
         var ev = Epoll.epoll_event()
-        ev.events = newInterested.epollEventSet
-        ev.data.u64 = UInt64(EPollUserData(registrationID: registrationID, fileDescriptor: fileDescriptor))
+        ev.events = EventPoll.Event.Mask(rawValue: newInterested.epollEventSet)
+        ev.data = EventPoll.Event.Data(rawValue: UInt64(EPollUserData(registrationID: registrationID, fileDescriptor: fileDescriptor)))
 
         _ = try Epoll.epoll_ctl(epfd: self.selectorFD, op: Epoll.EPOLL_CTL_MOD, fd: fileDescriptor, event: &ev)
     }
@@ -267,7 +269,7 @@ extension Selector: _SelectorBackendProtocol {
 
         for i in 0..<ready {
             let ev = events[i]
-            let epollUserData = EPollUserData(rawValue: ev.data.u64)
+            let epollUserData = EPollUserData(rawValue: ev.data.rawValue)
             let fd = epollUserData.fileDescriptor
             let eventRegistrationID = epollUserData.registrationID
             switch fd {
diff --git a/Tests/NIOEmbeddedTests/AsyncTestingChannelTests.swift b/Tests/NIOEmbeddedTests/AsyncTestingChannelTests.swift
index 70e6190..c2e7419 100644
--- a/Tests/NIOEmbeddedTests/AsyncTestingChannelTests.swift
+++ b/Tests/NIOEmbeddedTests/AsyncTestingChannelTests.swift
@@ -758,7 +758,7 @@ class AsyncTestingChannelTests: XCTestCase {
         // are not available on Windows.
         #if !os(Windows)
         let channel = NIOAsyncTestingChannel()
-        let option = ChannelOptions.socket(NIOBSDSocket.OptionLevel.ip.rawValue, IP_TTL)
+        let option = ChannelOptions.socket(SocketOptionLevel(NIOBSDSocket.OptionLevel.ip.rawValue), IP_TTL)
         let _ = try await channel.setOption(option, value: 1).get()
 
         let optionValue1 = try await channel.getOption(option).get()
diff --git a/Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift b/Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift
index 37e7fd8..552c724 100644
--- a/Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift
+++ b/Tests/NIOEmbeddedTests/EmbeddedChannelTest.swift
@@ -832,7 +832,7 @@ class EmbeddedChannelTest: XCTestCase {
         // are not available on Windows.
         #if !os(Windows)
         let channel = EmbeddedChannel()
-        let option = ChannelOptions.socket(NIOBSDSocket.OptionLevel.ip.rawValue, IP_TTL)
+        let option = ChannelOptions.socket(SocketOptionLevel(NIOBSDSocket.OptionLevel.ip.rawValue), IP_TTL)
         let _ = channel.setOption(option, value: 1)
 
         let optionValue1 = try channel.getOption(option).wait()
diff --git a/Tests/NIOFSTests/FileTypeTests.swift b/Tests/NIOFSTests/FileTypeTests.swift
index f3e76a0..43e1d47 100644
--- a/Tests/NIOFSTests/FileTypeTests.swift
+++ b/Tests/NIOFSTests/FileTypeTests.swift
@@ -27,7 +27,10 @@ private let S_IFBLK = FileMode(type: .blockSpecial, permissions: []).rawValue
 private let S_IFREG = FileMode(type: .regular, permissions: []).rawValue
 private let S_IFLNK = FileMode(type: .symbolicLink, permissions: []).rawValue
 private let S_IFSOCK = FileMode(type: .socket, permissions: []).rawValue
+#if canImport(Darwin)
+// Whiteouts are Darwin's (System's FileType.whiteout).
 private let S_IFWHT = FileMode(type: .whiteout, permissions: []).rawValue
+#endif
 
 // System's d_type values (its FileType.directoryEntryType), under the C names the test uses.
 private let DT_FIFO = FileMode(type: .fifo, permissions: []).type.directoryEntryType
@@ -37,7 +40,10 @@ private let DT_BLK = FileMode(type: .blockSpecial, permissions: []).type.directo
 private let DT_REG = FileMode(type: .regular, permissions: []).type.directoryEntryType
 private let DT_LNK = FileMode(type: .symbolicLink, permissions: []).type.directoryEntryType
 private let DT_SOCK = FileMode(type: .socket, permissions: []).type.directoryEntryType
+#if canImport(Darwin)
+// Whiteouts are Darwin's (System's FileType.whiteout).
 private let DT_WHT = FileMode(type: .whiteout, permissions: []).type.directoryEntryType
+#endif
 #elseif canImport(Glibc)
 import Glibc
 #endif
diff --git a/Tests/NIOPosixTests/SocketAddressTest.swift b/Tests/NIOPosixTests/SocketAddressTest.swift
index 2ea9b26..b967b85 100644
--- a/Tests/NIOPosixTests/SocketAddressTest.swift
+++ b/Tests/NIOPosixTests/SocketAddressTest.swift
@@ -35,6 +35,8 @@ import struct SystemSockets.IPv4Address
 fileprivate func if_nametoindex(_ name: String) -> CUnsignedInt {
     ((try? NetworkInterface.Index(name: name)) ?? nil)?.rawValue ?? 0
 }
+#if canImport(Darwin)
+// On Linux, NIOPosix's re-exported Glibc has memcmp, and the two are ambiguous.
 /// memcmp(3) in the C call's shape, through System's Memory.compare.
 fileprivate func memcmp(_ lhs: UnsafeRawPointer?, _ rhs: UnsafeRawPointer?, _ count: Int) -> CInt {
     CInt(
@@ -44,6 +46,7 @@ fileprivate func memcmp(_ lhs: UnsafeRawPointer?, _ rhs: UnsafeRawPointer?, _ co
         )
     )
 }
+#endif
 /// memcpy(3) in the C call's shape, by the standard library's raw-memory copy.
 @discardableResult
 fileprivate func memcpy(
diff --git a/Tests/NIOPosixTests/StreamChannelsTest.swift b/Tests/NIOPosixTests/StreamChannelsTest.swift
index 1fb133e..12c7be9 100644
--- a/Tests/NIOPosixTests/StreamChannelsTest.swift
+++ b/Tests/NIOPosixTests/StreamChannelsTest.swift
@@ -1258,7 +1258,7 @@ private func assertNoSelectorChanges(
     var ev = Epoll.epoll_event()
     let numberOfEvents = try Epoll.epoll_wait(epfd: fd, events: &ev, maxevents: 1, timeout: 0)
     guard numberOfEvents == 0 else {
-        throw UnexpectedSelectorChanges(description: "\(ev) [userdata: \(EPollUserData(rawValue: ev.data.u64))]")
+        throw UnexpectedSelectorChanges(description: "\(ev) [userdata: \(EPollUserData(rawValue: ev.data.rawValue))]")
     }
     #else
     let events: UnsafeMutablePointer<URingEvent> = UnsafeMutablePointer.allocate(capacity: 1)
```
