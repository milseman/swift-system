# syscalls-4: system calls the adopters still make through the C library

The `syscalls-4` lane adds System API for the system calls that swift-nio,
SwiftPM, swift-foundation, swift-subprocess and the toolchain's other packages
still call through Darwin or Glibc, from the adopters' `SYSTEM-GAP` lists
(`../adopters/*/MIGRATION.md`) and the coverage tool's ecosystem report
(`../coverage-results/runs/5e5e16671a29-2d5ca14b/ECOSYSTEM.md`). Breadth over
polish: a correct, tested, documented wrapper per call, in the package's
patterns. One section per cluster, appended as each lands, in the queue's order.

All new API is `@available(System 199, *)`, throws `Errno` (typed), and has a
"The corresponding C function is `x`." sentence. Socket API is in
SystemSockets.

## Testing on Linux

At system-next `609feb0`, `swift test` on Linux stops at the
`MemberImportVisibility` probe target (`ProcessesProbe.swift`,
`EventsProbe.swift`), which the linux-build lane's unmerged commits fix. So
`linux-test.sh` copies this checkout to `.build/linux-experiments/syscalls4`,
applies `git diff system-next...linux-build` there, and runs `swift test` in
`swift:6.2-noble` through Apple's `container`, as `Utilities/linux/build.sh`
does. When linux-build merges into system-next, `Utilities/linux/build.sh test`
does the same job.

```sh
Prototype/Syscalls4/linux-test.sh                       # swift test
Prototype/Syscalls4/linux-test.sh test --filter Pseudoterminal
SWIFT_IMAGE=swift:6.3-noble Prototype/Syscalls4/linux-test.sh
```

## Baseline

System-next `609feb0` on macOS 26.3, Swift 6.2 (swiftlang-6.2.0.19.9):
swift-testing 265 tests in 34 suites pass.

## 1. Process exit and pseudoterminals

### Commits and API

`5297e94`: exit.

| API | C |
|---|---|
| `ProcessID.exit(_ status: CInt) -> Never` | `exit` |
| `ProcessID.exitImmediately(_ status: CInt) -> Never` | `_exit` |
| `ProcessID.addExitHandler(_: @convention(c) () -> Void) throws(Errno)` | `atexit` |

`7119764`: pseudoterminals.

| API | C |
|---|---|
| `TerminalDescriptor.openPseudoterminal(attributes:windowSize:closeOnExec:) throws(Errno) -> (controller: FileDescriptor, terminal: TerminalDescriptor)` | `openpty`, done with `posix_openpt`, `grantpt`, `unlockpt`, `ptsname_r`, `open`, `tcsetattr`, `ioctl(TIOCSWINSZ)` |
| `FileDescriptor.pseudoterminalPath() throws(Errno) -> FilePath` | `ptsname_r` |

Files: `Sources/System/ProcessExit/ProcessExit.swift`,
`Sources/System/Pseudoterminals/Pseudoterminal.swift`,
`Internals/Syscalls+ProcessExit.swift`, `Internals/Syscalls+Pseudoterminals.swift`;
the `pty-run` sample, in a new "More system call samples" group in `main.swift`.

### Design calls

- **Exit goes on `ProcessID`, as statics**, beside the processes lane's
  `execute`, `spawn` and `createSession`, which also act on the calling
  process. Rejected: top-level `exit`, which would make every `exit(…)`
  ambiguous in a file that also imports the C library (and Foundation
  re-exports it); a namespace type (`Process` is Foundation's).
- **`_exit` is `exitImmediately(_:)`**, a method of its own rather than a
  flag on `exit`, since the two belong to different places: `_exit` is the
  async-signal-safe one, for signal handlers and forked children. Rejected:
  `exit(_:runningHandlers:)`, and the C name.
- **The status is a `CInt`**, as every adopter passes (`exit(main(…))`,
  `exit(code.rawValue)`). Rejected: `EXIT_SUCCESS`/`EXIT_FAILURE` constants
  or a status type: they're 0 and 1 on every platform System builds, and
  ArgumentParser's `ExitCode` already fills that role in the packages that
  want one.
- **`addExitHandler` takes a C function**, which a closure that captures
  nothing converts to: every adopter's handler (Subprocess's five, SwiftPM's
  `atexit(dump)`) captures nothing. Rejected: a registry of Swift closures
  behind one C trampoline. It would work (exit handlers run in ordinary
  context, unlike signal handlers) but adds a global, a lock, and
  allocation, for no adopter.
- **A failed `atexit` throws `.noMemory`.** atexit returns nonzero and POSIX
  doesn't say it sets `errno`; the only way it can fail is running out of
  room. Rejected: reading `errno` (Darwin documents `ENOMEM`, Linux doesn't
  promise it), and a `Bool` result.
- **No mock hooks for `exit` and `_exit`**, which never return; exit tests
  check them for real.
- **Pseudoterminals use POSIX's functions, not `openpty`**: `openpty` needs
  libutil on glibc before 2.34 and on FreeBSD and OpenBSD (swift-build links
  `util` for OpenBSD), and its name argument is a buffer with no length. The
  POSIX functions reuse the `csystem_` shims that the tests'
  `withPseudoterminal` already uses on Linux.
- **Close-on-exec by default** (`closeOnExec: true`). C's `openpty` doesn't
  set it, and swift-build sets it with `fcntl` right after, which races any
  other thread's spawn. A spawn file action hands a child the terminal all
  the same. Rejected: C's default.
- **No `forkpty`** (fork is deliberately unwrapped: `Prototype/Processes`)
  **and no `login_tty`**, whose job is to make the pty the child's
  controlling terminal after a fork. With `posix_spawn`, that's a child in a
  new session (`SpawnAttributes.Flags.createSession`) that opens
  `pseudoterminalPath()` with a spawn file action; the docs say so, and
  `PseudoterminalSpawnTests` and `pty-run` check it on Darwin and Linux.
- **The ends are a `FileDescriptor` controller and a `TerminalDescriptor`
  terminal**, returned as raw descriptors, as `FileDescriptor.pipe()` returns
  them. Both ends are terminals on Darwin and Linux, so
  `TerminalDescriptor(unchecked: controller)` reaches the shared window size.
  Rejected: a new top-level pair type, which TSC's test support would sit
  beside with a `PseudoTerminal` class of its own, and which a tuple of the
  two descriptors doesn't need; an owned pair, which waits on `OwnedFD`
  leaving the prototype stage.
- **`attributes` and `windowSize` apply with `TCSANOW` and `TIOCSWINSZ`**, as
  `openpty`'s `termp` and `winp` do. `TCSANOW` rather than glibc's
  `TCSAFLUSH`, since flushing a new terminal has nothing to flush and can
  block on Darwin.
- **`ptsname_r`, never `ptsname`**, whose static buffer races; so the pty API
  carries `ptsname_r`'s floor, macOS 10.13.4 (iOS 11.3, watchOS 4.3, tvOS
  11.3), on the same extensions as `System 199`. `pty-run` needed an
  `#available` check for it. `system_ptsname_r` returns an error number on
  every platform (Darwin's returns -1 and sets `errno`), and the path grows its
  buffer on `ERANGE`.

### Findings

- **Darwin's `waitid` reports an exit status's full value**: 0x105 for
  `exit(0x105)`, and 24 bits of `exit(-1)` (16777215), where `waitpid`'s
  `WEXITSTATUS` gives the low 8 bits, as Linux's `waitid` does. The
  processes lane's `ProcessID.wait(for:)` (`waitid`) and `wait()`
  (`waitpid`) therefore report different `ExitStatus.exited` values on
  Darwin for a status above 255; that's theirs to decide (mask to 8 bits, or
  document).
- **On Darwin, a process that writes to a pseudoterminal and exits blocks in
  its last close until the controller reads the output**: a probe that
  waited for its child before reading hung for 15 minutes. The docs, the
  spawn test and the sample read first.
- **On Darwin, a session leader that opens the terminal gets it as its
  controlling terminal even with `O_NOCTTY`**; Linux honors `O_NOCTTY`
  (both checked with a C probe, on macOS 26.3 and in swift:6.2-noble). The
  docs and the spawn action don't pass it, so they rely on neither.
- **swift-testing 6.2's exit tests capture 32 bytes of their own** (the same
  bytes each run, likely the exit test's ID) on both standard output and
  error from a child that ends with `_exit`, and none from one that calls
  `exit`. The `_exit` test looks for what shouldn't be there instead of
  expecting no output.
- Swift 6.2 infers a closure's `throws` from the `try`s it can see, and a
  `try` inside `#expect(…)` is in a macro argument, so a test closure whose
  only `try`s are in `#expect` needs an explicit `throws`.

### What it replaces in the adopters

- **exit** (the ecosystem's top gap: 14 packages, 74 sites):
  - NIO `Tests/NIOPosixTests/EventLoopCrashTests.swift` (`exit(1)` … `exit(4)`),
    clearing `// SYSTEM-GAP: exit(3) (the crash tests end child processes with it)`.
  - SwiftPM `Sources/Runtimes/PackagePlugin/Plugin.swift` (six `exit(0)` and
    `exit(1)`), `Sources/swiftpm-testing-helper/Entrypoint.swift`
    (`exit(main(…))`).
  - Also in the report's list: llbuild, swift-argument-parser, swift-build,
    swift-corelibs-foundation, swift-corelibs-xctest, swift-docc, swift-driver,
    swift-sdk-generator, swift-syntax, swift-tools-support-core, wasmkit.
- **_exit**: SwiftPM `Sources/Commands/Utilities/TestingSupport.swift`
  (`_exit(EXIT_FAILURE)` in `safeExec`).
- **atexit**: Subprocess `Thread.swift`, `IO/AsyncIO+KQueue.swift`,
  `Platforms/Subprocess+BSD.swift` (each `import func Darwin.atexit  //
  SYSTEM-GAP: atexit`), and `IO/AsyncIO+Linux.swift`,
  `Platforms/Subprocess+Linux.swift` on Linux; SwiftPM
  `Sources/Runtimes/PackageDescription/PackageDescription.swift` (`atexit(dump)`,
  twice).
- **openpty**: Subprocess `Tests/SubprocessTests/UnixTests.swift`, clearing
  `// SYSTEM-GAP: openpty, for a pseudoterminal to hand to the child` (its
  `tcgetattr`/`cfmakeraw`/`tcsetattr` were already System's); also TSC
  `Sources/TSCTestSupport/PseudoTerminal.swift`, swift-testing
  `Tests/TestingTests/Support/FileHandleTests.swift`, and swift-build
  `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` (whose
  `fcntl(FD_CLOEXEC)` calls the default makes unnecessary).
- The processes lane's README lists `[exit]` as missing in
  `Utilities/adopter-coverage/mapping.ini`; it's covered now, for the coverage
  lane to update.

### Platforms

- Built and tested: macOS 26.3 (arm64); Linux, swift:6.2-noble (arm64), with
  linux-build's probe fixes applied, every new test passing, the spawned
  child's controlling terminal included.
- Unverified: exit on WASI (wasi-libc has `exit`, `_exit`, `atexit`);
  pseudoterminals on Android (the existing shims' platforms), Musl, and iOS,
  tvOS, watchOS and visionOS (declared in their SDKs; the spawn test and
  sample skip watchOS and tvOS, where `posix_spawn` isn't wrapped).
  Not added for FreeBSD and OpenBSD.

### Tests

- New: `ProcessExitTests` (5 swift-testing exit tests), `ProcessExitMockTests`
  (2), `PseudoterminalTests` (6 swift-testing), `PseudoterminalSpawnTests` (1),
  `PseudoterminalMockTests` (5).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 276 tests in 36
  suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 277 tests in 37 suites pass.

## 2. Socket creation and accept flags

### Commits and API

`1428285`, in SystemSockets (`Sockets/SocketOpenOptions.swift`,
`Internals/SocketSyscalls+OpenOptions.swift`, and `csystem_accept4`).

| API | C |
|---|---|
| `SocketDescriptor.OpenOptions`: `.nonBlocking`, `.closeOnExec` | `SOCK_NONBLOCK`, `SOCK_CLOEXEC` |
| `SocketDescriptor.open(_:_:protocol:options:retryOnInterrupt:) throws(Errno)` | `socket`, with the flags in the type |
| `SocketDescriptor.pair(_:_:protocol:options:retryOnInterrupt:) throws(Errno)` | `socketpair`, likewise |
| `accept(options:retryOnInterrupt:)`, `accept(client:options:retryOnInterrupt:) throws(Errno)` | `accept4` |

### Design calls

- **Darwin emulates the options with `fcntl`**, after `socket`,
  `socketpair`, or `accept`, closing the new socket (both, for a pair) if
  that fails. Rejected: omitting them on Darwin, which leaves every portable
  caller to write NIO's `#if os(Linux)` and the same `fcntl`, with the same
  race. The race is inherent (Darwin has no atomic way), and
  `.closeOnExec`'s docs name it and point to
  `SpawnAttributes.Flags.closeOnExecByDefault`.
- **`accept(options:)` has `accept4`'s semantics everywhere**: the new
  socket is nonblocking exactly when the options say so. Darwin's `accept`
  passes on the listener's `O_NONBLOCK` (a C probe showed it, and not
  `FD_CLOEXEC`), so the emulation also clears it when it wasn't asked for,
  at the cost of an `F_GETFL`. Plain `accept()` keeps each platform's
  behavior. Rejected: inheriting on Darwin, so that one call's result
  differs by platform.
- **The type is `SocketDescriptor.OpenOptions`**, after
  `FileDescriptor.OpenOptions`, whose `.closeOnExec` and `.nonBlocking` it
  mirrors, and it's one type for all three calls, since `socket`,
  `socketpair`, and `accept4` take the same flags. Rejected: `Options`, too
  near `SocketOption` (`SO_*`), and one type per call, as
  `PipeOptions`/`DuplicateOptions` are for `pipe2`/`dup3`, whose flags
  differ from `open`'s.
- **New overloads with a required `options:`**, typed-throwing, beside the
  untyped `open`, `pair`, and `accept`, which don't change. Rejected: an
  `options: = []` parameter on the existing methods (an edit to their file,
  and a change of their throws type).
- **The raw values on Darwin are FreeBSD's `SOCK_*` bits**, System's own
  stand-ins, which it never passes to a call.
- **`csystem_accept4`**, since glibc and Musl declare `accept4` only with
  `_GNU_SOURCE`, takes untyped address arguments so that `CSystemLinux.h`
  needn't include `<sys/socket.h>` (whose `sockaddr` members would then be
  attributed to CSystem). The lane's shims go in a block of their own at the
  end of `CSystemLinux.h` and `shims.c`, away from the other lanes'
  insertions.
- `EAGAIN` from a nonblocking listener stays an error (`.wouldBlock`), as
  the existing `accept` reports it. NIO maps it to `nil`; that's NIO's
  convention.

### What it replaces in the adopters

- NIO `Sources/NIOPosix/BaseSocket.swift` `makeSocket` (`SOCK_NONBLOCK` on
  Linux, `fcntl` elsewhere), `Sources/NIOPosix/ServerSocket.swift` `accept`
  (`accept4` on Linux, `accept` and `fcntl` elsewhere),
  `Sources/NIOPosix/Linux.swift` (`SOCK_CLOEXEC`, `SOCK_NONBLOCK` per C
  library, and `accept4` over `CNIOLinux_accept4`). NIO's migration left
  these Linux paths unchanged, so no `SYSTEM-GAP` line names them.

### Platforms

- Built and tested: macOS 26.3, and Linux swift:6.2-noble (the accept test
  binds loopback; it ran on both).
- Unverified: Musl and Android (`SOCK_*` as macros; Bionic has `accept4` at
  API level 21), and FreeBSD, which takes the Glibc branch of SystemSockets
  with macro constants.

### Tests

- New: `SocketOpenOptionsTests` (4, swift-testing; one needs bind),
  `SocketOpenOptionsMockTests` (6).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 286 tests in
  38 suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 287 tests in 39 suites pass.

## 3. sendfile

### Commits and API

`0c49dde`.

| API | C |
|---|---|
| `SocketDescriptor.sendFile(_:fromAbsoluteOffset:count:retryOnInterrupt:) throws(Errno) -> Int` (SystemSockets; Darwin, Linux, Android) | `sendfile`: Darwin's `(fd, s, offset, &len, nil, 0)`, Linux's `(s, fd, &offset, count)` |
| `FileDescriptor.sendFile(_:fromAbsoluteOffset:count:retryOnInterrupt:) throws(Errno) -> Int` (SystemPackage; Linux, Android) | `sendfile` to any descriptor |

### Design calls

- **Partial progress is a result, never lost.** The method has `write`'s
  semantics: it returns the count sent, which can be short, and throws
  `.wouldBlock` (or `.interrupted`) only when nothing was sent. Darwin's
  `sendfile` fails with `EAGAIN` or `EINTR` even after sending bytes, and
  reports them in `*len` (a probe: 8092 bytes, then 0 on the next call);
  a thrown error would lose them, so the method returns them. The Darwin and
  Linux loops are then the same. Rejected: NIO's `IOResult` shape,
  `(count, wouldBlock)`, which every caller would unpack when the next call
  reports the full buffer anyway; and throwing with the count attached,
  which `Errno` can't carry.
- **An interruption after some bytes returns them**, rather than retrying
  from the old offset, which would send them twice. One before any is
  retried when `retryOnInterrupt` is set, as everywhere else.
- **A count of 0 makes no call and returns 0**: Darwin's `sendfile` treats 0
  as "the rest of the file", which Linux can't do. Rejected: exposing that
  meaning (`count: Int?`). A negative count traps.
- **`fromAbsoluteOffset:`**, as `read(fromAbsoluteOffset:into:)` labels
  `pread`: neither platform moves the file's own offset. No form that uses
  and advances the file's offset (Linux's `NULL` offset), which no adopter
  uses.
- **Two homes.** The socket form, in SystemSockets, is the one API over both
  signatures. The descriptor form is Linux-only, in SystemPackage, for
  NIOFS's file-to-file copy; on Darwin `sendfile` sends only to a stream
  socket (to a pipe it's `ENOTSOCK`, to a datagram socket `EINVAL`).
  Rejected: one `FileDescriptor` method that fails on Darwin for non-sockets.
- **No headers or trailers** (Darwin's `sf_hdtr`), which no adopter passes;
  **no FreeBSD form**, whose signature differs again and can't be built here.
- The Darwin mock sets `*len` from the driver's byte counts, on a forced
  error too, so the partial-progress path is mock-tested as well as tested
  for real.

### Findings

- On Linux 6.18, a pipe as `sendfile`'s source fails with `ESPIPE`, where
  the man page says `EINVAL`; the docs say only that it fails.
- Darwin's `sendfile` works on `.local` stream socketpairs, so the tests
  need no `bind`.

### What it replaces in the adopters

- NIO `Sources/NIOPosix/System.swift` `Posix.sendfile` (the Darwin and
  Glibc/Musl/Android signatures, and `.wouldBlock(written)`), behind
  `BSDSocketAPIPosix.swift` `sendfile(socket:fd:offset:len:)` and
  `Socket.swift`'s `sendFile(fd:offset:count:)`; NIO's gap list names
  `sendfile(2)` for `NIOPosix System`.
- NIOFS `Sources/NIOFS/Internal/System Calls/Syscalls.swift`
  `system_sendfile` and `Syscall.swift` `sendfile(to:from:offset:size:)`,
  used by `FileSystem.swift`'s Linux copy, through the Linux
  `FileDescriptor.sendFile`.

### Platforms

- Built and tested: macOS 26.3, Linux swift:6.2-noble.
- Unverified: Musl and Android (the same Linux signature).

### Tests

- New: `SocketSendFileTests` (4), `SocketSendFileMockTests` (5, one
  Darwin-only), and on Linux `SendFileTests` (2).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 295 tests in
  40 suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 297 tests in 42 suites pass.

## 4. IP and IPv6 socket options

### Commits and API

`b5887c3`, in SystemSockets: `Sockets/SocketAddress+Host.swift`,
`SocketOptions+IP.swift`, `SocketOptions+Timeouts.swift`,
`SocketMessages+IP.swift`, and one alias in `Internals/CInterop+Sockets.swift`.

| API | C |
|---|---|
| `IPv4Address.Host`: `init?(_:)`, `description`, `init(_:_:_:_:)`, `init(integerValue:)`, `integerValue`, `init?(bytes:)`, `withUnsafeBytes` | `in_addr`, `inet_pton`/`inet_ntop` with `AF_INET` |
| `IPv4Address.Host.any`, `.loopback`, `.broadcast` | `INADDR_ANY`, `INADDR_LOOPBACK`, `INADDR_BROADCAST` |
| `IPv6Address.Host`: `init?(_:)`, `description`, `init?(bytes:)`, `withUnsafeBytes`, `.any`, `.loopback` | `in6_addr`, `inet_pton`/`inet_ntop` with `AF_INET6`, `in6addr_any`, `in6addr_loopback` |
| `IPv4Address(host:port:)`, `.host`; `IPv6Address(host:port:flowLabel:scopeID:)`, `.host` | `sin_addr`, `sin6_addr` |
| `SocketDescriptor.IPOption`, `IPv6Option`; `getIPOption`/`setIPOption`, `getIPv6Option`/`setIPv6Option` | the `IP_*` and `IPV6_*` names, `getsockopt`/`setsockopt` |
| `timeToLive()`/`setTimeToLive(_:)` | `IP_TTL` |
| `typeOfService()`/`setTypeOfService(_:)`, `receivesTypeOfService()`/`setReceivesTypeOfService(_:)` | `IP_TOS`, `IP_RECVTOS` |
| `receivesIPv4PacketInfo()`/`setReceivesIPv4PacketInfo(_:)` | `IP_RECVPKTINFO` (Linux: `IP_PKTINFO`) |
| `includesIPHeader()`/`setIncludesIPHeader(_:)` | `IP_HDRINCL` |
| `multicastTimeToLive`, `ipv4MulticastLoopback`, `ipv4MulticastInterface` (and setters) | `IP_MULTICAST_TTL`, `IP_MULTICAST_LOOP`, `IP_MULTICAST_IF` |
| `joinMulticastGroup(_:interface:)`, `leaveMulticastGroup(_:interface:)` | `IP_ADD_MEMBERSHIP`, `IP_DROP_MEMBERSHIP`, `ip_mreq` |
| `isIPv6Only()`/`setIPv6Only(_:)` | `IPV6_V6ONLY` |
| `unicastHops`, `trafficClass`, `receivesTrafficClass`, `receivesIPv6PacketInfo` (and setters) | `IPV6_UNICAST_HOPS`, `IPV6_TCLASS`, `IPV6_RECVTCLASS`, `IPV6_RECVPKTINFO` |
| `multicastHops`, `ipv6MulticastLoopback`, `ipv6MulticastInterface` (and setters) | `IPV6_MULTICAST_HOPS`, `IPV6_MULTICAST_LOOP`, `IPV6_MULTICAST_IF` |
| `joinMulticastGroup(_:interfaceIndex:)`, `leaveMulticastGroup(_:interfaceIndex:)` | `IPV6_JOIN_GROUP`, `IPV6_LEAVE_GROUP`, `ipv6_mreq` |
| `receiveTimeout()`/`setReceiveTimeout(_: Duration?)`, `sendTimeout`/`setSendTimeout` | `SO_RCVTIMEO`, `SO_SNDTIMEO`, `timeval` |
| `linger()`/`setLinger(_: Duration?)` | `SO_LINGER` (Darwin: `SO_LINGER_SEC`), `struct linger` |
| `receivesTimestamps()`/`setReceivesTimestamps(_:)` | `SO_TIMESTAMP` |
| `SocketOption.receiveTimeout`, `.sendTimeout`, `.timestamp`, Darwin `.lingerSeconds` | `SO_RCVTIMEO`, `SO_SNDTIMEO`, `SO_TIMESTAMP`, `SO_LINGER_SEC` |
| `Message.typeOfService`, `.trafficClass`, `.ipv4PacketInfo`, `.ipv6PacketInfo`, `.timestamp` (both message types) | `IP_RECVTOS`/`IP_TOS`, `IPV6_TCLASS`, `IP_PKTINFO`/`in_pktinfo`, `IPV6_PKTINFO`/`in6_pktinfo`, `SCM_TIMESTAMP` |
| `SocketDescriptor.IPv4PacketInfo` (`destination`, `localAddress`, `interfaceIndex`), `IPv6PacketInfo` | `in_pktinfo`, `in6_pktinfo` |
| `AncillaryMessageBuffer.appendTypeOfService(_:)`, `appendTrafficClass(_:)` | `IP_TOS`, `IPV6_TCLASS` control messages |
| `CInterop.SockAddrStorage` | `sockaddr_storage` |

### Design calls

- **Typed get/set pairs**, one per option, as NIO's `SocketOptionProvider`
  (`setIPMulticastTTL`, `getSoLinger`) and Rust's socket2 have, with noun
  getters as SystemPackage's newer API spells them (`windowSize()`,
  `setWindowSize(_:)`). Rejected: phantom-typed option keys
  (`socket.setOption(.multicastHops, to: 3)`), which are more compact but
  need a public value protocol whose conversions are unsafe to expose; and
  getters prefixed with `get`, as SystemSockets' older `getSocketOption`.
- **Each IP version's own terms**: time to live and type of service for
  IPv4, hops and traffic class for IPv6, so most names don't collide;
  an `ipv4`/`ipv6` prefix only where both have the option (multicast
  loopback and interface, packet info). `joinMulticastGroup` overloads by
  the group's type.
- **The option names stay available** (`IPOption`, `IPv6Option`, as
  `SocketOption` and `TCPOption` are), for the generic `getOption` and for
  comparing a control message's type.
- **Host addresses are a nested `Host`**, since SystemSockets'
  `IPv4Address` is a socket address, `sockaddr_in`. Rejected: an
  `IPv4Address` with a meaningless port for multicast groups; extending
  `in_addr` itself; a new top-level type. The `Host` wraps the C struct as
  its `rawValue` (as `Stat` does), and nothing a client needs reads a
  member. `integerValue` is the address as a number, first byte most
  significant (`127.0.0.1` is `0x7F00_0001`), so byte order never leaks.
- **Timeouts are `Duration?`**: `nil` waits indefinitely, and a duration
  rounds up to a microsecond, so `.zero` or a negative duration times out
  at once. C's zero means "no timeout", the classic surprise. Rejected:
  passing zero through; trapping on it.
- **Linger is `Duration?`**: `nil` is off, a duration rounds up to a whole
  second, and `.zero` is an abortive close (a TCP reset), as C's
  `l_linger = 0` is. On Darwin it uses `SO_LINGER_SEC` (below).
- **Single-byte options are `UInt8`** where the BSDs take a `u_char`
  (`IP_MULTICAST_TTL`, `IP_MULTICAST_LOOP`); Linux accepts a byte too, and
  returns one for a one-byte buffer. IPv6's loop and interface are
  `u_int`s everywhere.
- **Control-message payloads are read by their layout**, `in_pktinfo`'s
  index, local address and destination, and `in6_pktinfo`'s destination
  and index, because glibc declares `in6_pktinfo` only with
  `_GNU_SOURCE`. The layouts are the same on every platform.
- **Sending TOS and traffic class** takes an `int` payload, as NIO sends
  and both kernels accept; there's no send-side packet info (choosing a
  source address), which no adopter does.
- No ECN type: the docs point at the low two bits; NIO keeps its own
  `NIOExplicitCongestionNotificationState`.

### Findings

- **Darwin's `SO_LINGER` is in clock ticks**, hundredths of a second: a C
  probe that set `SO_LINGER_SEC` to 5 read `SO_LINGER` back as 500, and
  `SO_LINGER` 300 as `SO_LINGER_SEC` 3. Code that sets `SO_LINGER` in
  seconds on Darwin (NIO's `setSoLinger` passes the caller's `linger`
  through) lingers a hundredth as long as it means.
- **Darwin hides RFC 3542's IPv6 packet-info names**: `IPV6_RECVPKTINFO`
  (61) and `IPV6_PKTINFO` (46) exist only with `__APPLE_USE_RFC_3542`,
  which Swift's Darwin module doesn't define, so NIO shims them in
  CNIODarwin. System spells them out; the IPv6 loopback test checks both
  against the kernel.
- **Darwin's `inet_pton` accepts a scope**: `"fe80::1%en0"` parses as
  `fe80:e::1`, the interface's index (14) written into the second 16 bits
  (the KAME convention); `"%1"` and an unknown name are ignored; Linux
  rejects all of them. `IPv6Address.Host` rejects `%` everywhere.
- Darwin sends a received IPv4 TOS as `IP_RECVTOS`, Linux as `IP_TOS`, as
  NIO's parser already knows.
- On 64-bit glibc, `SO_RCVTIMEO`, `SO_SNDTIMEO`, `SO_TIMESTAMP` and
  `SCM_TIMESTAMP` import as constants; NIO's `CNIOLinux_SO_RCVTIMEO`
  works around 32-bit glibc, where they're expressions. Swift's Linux
  platforms are 64-bit.
- Joining multicast groups on the loopback interface works on macOS
  (`lo0`) and in the Linux container (`lo`), so the membership tests need
  no network.

### What it replaces in the adopters

- NIO `Sources/NIOCore/BSDSocketAPI.swift`: the `NIOBSDSocket.Option`
  constants for every `IP_*`, `IPV6_*`, `SO_RCVTIMEO` and `SO_TIMESTAMP`
  name, clearing `// SYSTEM-GAP: IP_* and IPV6_* socket options` and, but
  for `TCP_CONNECTION_INFO` (cluster 5), `// SYSTEM-GAP: SO_RCVTIMEO,
  SO_TIMESTAMP, TCP_CONNECTION_INFO`.
- NIO `Sources/NIOCore/SocketOptionProvider.swift`: the implementations
  of `setSoLinger`/`getSoLinger`, `setIPMulticastIF`/`TTL`/`Loop`, and
  `setIPv6MulticastIF`/`Hops`/`Loop`. Their public signatures take C types
  (`linger`, `in_addr`), which NIO can't change without breaking clients,
  so the `SYSTEM-GAP: linger, in_addr, tcp_connection_info` import stays
  for the signatures.
- NIO `Sources/NIOPosix/SocketChannel.swift`: multicast join and leave
  (`ip_mreq`, `ipv6_mreq`, `INADDR_ANY`), clearing `// SYSTEM-GAP: ip_mreq,
  ipv6_mreq, INADDR_ANY`.
- NIO `Sources/NIOPosix/ControlMessage.swift`: ECN from `IP_TOS`,
  `IP_RECVTOS` and `IPV6_TCLASS`, and `in_pktinfo`/`in6_pktinfo`
  decoding, clearing `// SYSTEM-GAP: IP_TOS, IP_RECVTOS, IPV6_TCLASS and
  the packet-info structs`; with cluster 6, CNIODarwin's `IPV6_*PKTINFO`
  shims too.
- NIO `Sources/NIOPosix/BSDSocketAPICommon.swift` (`IP_RECVTOS`,
  `IPV6_RECVTCLASS`) and `Sources/NIOPosix/System.swift` (`IP_RECVPKTINFO`,
  `IP_PKTINFO`, and the `sockaddr_storage` alias of `// SYSTEM-GAP:
  CInterop has no alias for sockaddr_storage, nfds_t or timespec`).
- NIO tests: `NIOEmbeddedTests` `EmbeddedChannelTest.swift` and
  `AsyncTestingChannelTests.swift` (`IP_TTL`), `NIOPosixTests`
  `SystemTest.swift` (`IP_RECVDSTADDR`, `IP_RECVTOS`),
  `SocketChannelTest.swift` (`linger`).
- The ecosystem report's `sockets` lane entries for multicast, TOS and
  packet info, and `INADDR_ANY`.

### Not added

- `IP_RECVDSTADDR`'s decoding (the name is there, on Darwin),
  `IP_RECVORIGDSTADDR`, `IPV6_RECVHOPLIMIT`, source-specific multicast
  (`IP_ADD_SOURCE_MEMBERSHIP`, `MCAST_JOIN_GROUP`), and `ip_mreqn`.
- A probe in `Tests/MemberImportVisibility` for `CInterop.SockAddrStorage`:
  that target depends only on SystemPackage, and adding SystemSockets to it
  means editing `Package.swift`. The new API reads no C member in client
  code, so there's nothing else to probe.

### Platforms

- Built and tested: macOS 26.3; Linux swift:6.2-noble (as root, so the
  raw-socket `IP_HDRINCL` test runs; on macOS it returns early).
- Unverified: Musl and Android (their `IP_RECVTOS`, `IPV6_JOIN_GROUP` and
  `SO_RCVTIMEO` spellings), and FreeBSD.

### Tests

- New: `SocketAddressHostTests` (6), `SocketIPOptionsTests` (11),
  `SocketIPMessagesTests` (4, two binding), `SocketIPOptionsMockTests` (1,
  24 setters).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 317 tests in
  44 suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 319 tests in 46 suites pass.

## 5. TCP connection information

### Commits and API

`4d2b1e6`, in SystemSockets (`Sockets/SocketTCPInfo.swift`).

| API | C |
|---|---|
| `SocketDescriptor.TCPState` (`.closed` … `.timeWait`) | Darwin `TSI_S_*` (`<sys/proc_info.h>`), Linux `TCP_*` states |
| `SocketDescriptor.TCPConnectionOptions` | `TCPCI_OPT_*`, `TCPI_OPT_*` |
| Darwin: `tcpConnectionInfo() throws(Errno) -> TCPConnectionInfo`, `TCPOption.connectionInfo`, `CInterop.TCPConnectionInfo` | `TCP_CONNECTION_INFO`, `struct tcp_connection_info` |
| Linux: `tcpInfo() throws(Errno) -> TCPInfo`, `TCPOption.info`, `CInterop.TCPInfo` | `TCP_INFO`, `struct tcp_info` |

`TCPConnectionInfo` has typed properties for every field but the TCP Fast
Open bits; `TCPInfo` for every field glibc declares and, as optionals, the
kernel's newer ones through `tcpi_snd_wnd` (Linux 5.4).

### Design calls

- **Two types, one per platform**, since the C types differ in their
  fields and units: Darwin's windows are bytes and its times milliseconds,
  Linux's congestion window is segments and its times microseconds. The
  state and options are shared types, since they're the same concepts, and
  the option bits agree. Rejected: one cross-platform struct of the common
  fields, which would hide the units and drop half of each.
- **Linux's newer fields are optionals, read past glibc's struct.** glibc
  2.39 declares the first 104 bytes of `struct tcp_info`; Linux 6.18's is
  248. `tcpInfo()` asks for 256 bytes and keeps the count the kernel
  filled, reads glibc's fields through its declaration, and the newer ones
  by their `<linux/tcp.h>` offsets (checked with `offsetof` in the
  container), `nil` when the kernel is too old for them. Rejected: glibc's
  104 bytes alone, which is what NIO's `getTCPInfo()` returns, and misses
  byte counters and the minimum RTT; a CSystem mirror struct, which
  `<linux/tcp.h>` can't be included beside glibc's `<netinet/tcp.h>` to
  check.
- **Times are `Duration`s** (macOS 13, in a separate extension), sizes
  and counts `Int`, and 64-bit counters `UInt64`, with each property's doc
  naming the C field and its unit.
- **The states' raw values are each platform's own**, as `Signal`'s are.

### Findings

- Darwin reported `tcpi_rto` as 0 for an idle loopback connection; the
  docs say so.
- On Linux, `tcpi_bytes_acked` came out one more than `tcpi_bytes_sent`
  for 1000 bytes of data (the SYN's sequence number, it seems).
- Right after the server reads the client's FIN, the client can still be
  in `finWait1` on Linux; the test accepts either `finWait1` or
  `finWait2`.

### What it replaces in the adopters

- NIO `Sources/NIOCore/SocketOptionProvider.swift` `getTCPConnectionInfo()`
  (Darwin) and `getTCPInfo()` (Linux, FreeBSD, Android), and the
  `TCP_CONNECTION_INFO` of `Sources/NIOCore/BSDSocketAPI.swift`'s
  `// SYSTEM-GAP: SO_RCVTIMEO, SO_TIMESTAMP, TCP_CONNECTION_INFO`, now
  cleared with cluster 4. The public signatures return the C types, so
  NIO's `tcp_connection_info` import stays for them.
- NIO `Tests/NIOPosixTests/SocketOptionProviderTest.swift`
  (`TSI_S_ESTABLISHED` becomes `.established`).
- Not `mptcp_info` (NIO's `getMPTCPInfo`), which is Linux's MPTCP level.

### Platforms

- Built and tested: macOS 26.3, Linux swift:6.2-noble (kernel 6.18).
- Unverified: Android (Bionic's `tcp_info` is the kernel's, so more of it
  is declared) and Musl; FreeBSD's `tcp_info`, which differs again, isn't
  wrapped.

### Tests

- New: `SocketTCPInfoTests` (3; one binds).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 320 tests in
  45 suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 322 tests in 47 suites pass.

## 6. sendmmsg and recvmmsg

### Commits and API

`a6161fb`, in SystemSockets (`Sockets/SocketMultipleMessages.swift`,
`Internals/SocketSyscalls+MultipleMessages.swift`, and `csystem_sendmmsg`
and `csystem_recvmmsg` in CSystem); and `954d884`, the buffer forms, from
the review of clusters 1 to 6.

| API | C |
|---|---|
| `CInterop.MMsgHdr` (`msg_hdr`, `msg_len`), a Swift struct with the C layout | `struct mmsghdr` |
| `sendMessages(_: UnsafeMutableBufferPointer<CInterop.MMsgHdr>, flags:retryOnInterrupt:) throws(Errno) -> Int` | `sendmmsg` |
| `receiveMessages(_: UnsafeMutableBufferPointer<CInterop.MMsgHdr>, flags:retryOnInterrupt:) throws(Errno) -> Int` | `recvmmsg`, with no timeout |
| `sendMessages(_: some Collection<UnsafeRawBufferPointer>, to:flags:retryOnInterrupt:)`, `sendMessages(_: some Collection<(UnsafeRawBufferPointer, SocketAddress)>, flags:retryOnInterrupt:)` | `sendmmsg`, headers built inside |
| `receiveMessages(into: some Collection<UnsafeMutableRawBufferPointer>, flags:retryOnInterrupt:) throws(Errno) -> [ReceivedMessage]`, `SocketDescriptor.ReceivedMessage` (`byteCount`, `sender`, `flags`) | `recvmmsg`, headers built inside |

### Design calls

- **A Swift mirror of `struct mmsghdr`**, since glibc and Musl declare it
  only with `_GNU_SOURCE` and Darwin not at all: a `CInterop.MsgHdr` and a
  `CUnsignedInt`, with the C field names. Swift lays out a frozen struct's
  stored properties as C does, so `shims.c` asserts that `struct mmsghdr`
  has the layout of a C struct of those two fields, and a test that the
  Swift one has it too (64 bytes on 64-bit Linux, 56 on Darwin). Rejected:
  a C mirror in `CSystemLinux.h`, which would need `<sys/socket.h>` there
  and so hand `msghdr`'s members to CSystem under MemberImportVisibility.
  The shims take the vector (and the timeout) as `void *` for that reason.
- **Darwin emulates both calls** with a `sendmsg` or `recvmsg` a message,
  recording each count as `msg_len`: the first message's error is thrown,
  and a later one's ends the call short, as Linux reports it (the next call
  reports the error). An interruption is retried only before the first
  message. Rejected: omitting them on Darwin, which leaves NIO's C loop
  and its `recvmmsg` shim, which exits the process; emulating only
  `sendmmsg`, as NIO does.
- **No timeout parameter**: `recvmmsg` checks its timeout only after each
  datagram arrives, so it can't end a wait for the first one (the BUGS
  section of Linux's manual page). A receive timeout
  (`setReceiveTimeout(_:)`) or a nonblocking socket does that job.
- **An empty batch returns 0 without a call**, as the vectored I/O does.
- **Two forms.** The header form is for callers that pool their vectors,
  as NIO does, and send ancillary messages; filling a `msghdr` in means
  importing the C library for its members (and `msg_iovlen` is a
  `size_t` on glibc but an `int` on Musl and Darwin). The buffer forms,
  added after the review, build the vectors, addresses and headers in
  temporary allocations, so a client needs nothing from the C library;
  each message can have its own destination, and each received one
  reports its sender and flags. Rejected: spans, which an array can't
  hold; ancillary messages in the buffer forms, which would need one
  contiguous control buffer a batch.

### Findings

- Darwin limits a Unix-domain datagram to 2048 bytes: a 4096-byte one
  fails with `EMSGSIZE`.

### What it replaces in the adopters

- NIO `Sources/NIOPosix/System.swift` `Posix.sendmmsg` and
  `Posix.recvmmsg`, over `CNIOLinux_mmsghdr`, `CNIODarwin_mmsghdr` and
  `CNIOOpenBSD_mmsghdr`, and `CNIODarwin_sendmmsg`'s loop and
  `CNIODarwin_recvmmsg` (which calls `errx`), used by
  `PendingDatagramWritesManager` and `DatagramVectorReadManager` through
  `BSDSocketAPIPosix.swift`. The adopters' `SYSTEM-GAP` lists don't name
  them, since NIO's migration left the C targets out of scope.

### Platforms

- `a6161fb` was built and tested on macOS 26.3 and on Linux
  (swift:6.2-noble, with linux-build's then-pending probe fixes): the
  shims and their `_Static_assert`s compiled, and every test passed,
  sending and receiving batches through the real `sendmmsg` and
  `recvmmsg`.
- `954d884`, the buffer forms, was built and tested on macOS only: the
  Linux runs were paused before it.
- Unverified: Musl (whose `sendmmsg` and `recvmmsg` take `unsigned int`
  flags, which the C shims convert) and Android.

### Tests

- New: `SocketMultipleMessagesTests` (7: the mirror's layout, a header
  batch both ways over a datagram socketpair, a short send once a
  nonblocking socket fills, an empty batch, the buffer forms over a
  socketpair with a truncated datagram and over UDP loopback with
  per-message addresses, and each platform's calls under mocking).
- At `a6161fb`: macOS XCTest 430 run, 4 skipped, 0 failures,
  swift-testing 325 tests in 46 suites pass; Linux XCTest 369 run, 2
  skipped, 0 failures, swift-testing 327 tests in 48 suites pass.

## Merging system-next, and the review of clusters 1 to 6

- `e1c37c6` merges system-next `9f5b261` (posix-more's clusters 5 to 10,
  linux-build's fixes). Both conflicts were both sides adding entries, in
  `Sources/Samples/main.swift` and `Sources/System/CMakeLists.txt`. On
  macOS, XCTest 442 run (4 skipped), swift-testing 353 tests pass.
- The Linux runs were then paused, on request, before the merged tree was
  built there. Not done, as asked: building darwin-more, statfs and
  posix-more's clusters 5 to 10 on Linux; review fixes 3c (FreeBSD and
  OpenBSD `accept4` gating) and 3d (Musl's `TCP_*` macros and
  `struct tcp_info`); and queue clusters 9, 10 and 11.
- Review fixes made:
  - `9058be1`: `TCPInfo.rawValue` copies at most the bytes the kernel
    filled, the buffer's 256, and the C struct's size into a zeroed
    `tcp_info`, instead of loading a whole `tcp_info` from the buffer,
    which glibc's newest 280-byte declaration would read past. Linux-only;
    not built since.
  - `e7848a6`: a negative sub-second timeout (`.milliseconds(-500)`) had
    components `(0, -5e17)`, passed the old `seconds < 0` test, and became
    a negative `tv_usec`, which both kernels reject with `EDOM`. Timeouts
    and linger now test `timeout <= .zero`. The tests add negative
    durations.
  - `954d884`: the buffer forms of `sendMessages` and `receiveMessages`
    (cluster 6 above), so a batch needs no `msghdr` members;
    `3efdbde` makes their loopback test wait for its datagrams, which
    under a full test run's load arrived after the send returned.
  - `19bc15c`: the cluster 6 section above, which was missing.
- Swift 6.3 (swift:6.3-noble, before the pause): SystemSocketsTests
  builds; the SystemTests target crashes the 6.3.3 compiler
  (`StackNesting::fixNesting`, the pattern-catch crashes the linux-build
  lane recorded) in other lanes' tests: `ProcessResourceLimitTests.swift:120`
  (`catch Errno.notPermitted`), and, with that one set aside, a second
  `MandatoryAllocBoxToStack` crash in another SystemTests file of the same
  batch; building `system-samples` crashed too. None is in this lane's
  files, which have no pattern catches. With linux-build closed, no lane
  owns them.

## 7. Host address text in caller memory

### Commits and API

`0d7b43d`, in SystemSockets (`Sockets/SocketAddress+HostText.swift`).

| API | C |
|---|---|
| `IPv4Address.Host.init?(cString:)`, `IPv6Address.Host.init?(cString:)` | `inet_pton` |
| `description(into: UnsafeMutableBufferPointer<CChar>) throws(Errno) -> Int` on both | `inet_ntop` |
| `IPv4Address.Host.descriptionCapacity` (16), `IPv6Address.Host.descriptionCapacity` (46) | `INET_ADDRSTRLEN`, `INET6_ADDRSTRLEN` |

### Design calls

- **Cluster 4's host types are the conversions without a round trip
  through `SocketAddress`**: `Host(string)?.rawValue` is the `in_addr` or
  `in6_addr` that `inet_pton` fills, `Host(bytes:)` reads one from the
  caller's memory (a `sockaddr`'s address field, for example), and
  `description` is `inet_ntop`. This cluster adds the forms that allocate
  nothing: parsing from a C string, and formatting into a buffer the
  caller manages, with the buffer sizes.
- **`description(into:)` returns the length**, not counting the
  terminating null, and throws `.noSpace` (`ENOSPC`) for a buffer that's
  too small, or empty, as `inet_ntop` reports it.
- **IPv6's `init?(cString:)` rejects a scope**, as `init(_:)` does (the
  Darwin `inet_pton` behavior in cluster 4's findings).
- Rejected: `parse(_:into: UnsafeMutablePointer<in_addr>)` statics, which
  `Host(string)?.rawValue` already is; a family-generic form over raw
  pointers, which would take the address's size on trust.

### Findings

- `inet_ntop`'s longest IPv6 text is 39 characters, eight groups of four
  digits; `INET6_ADDRSTRLEN`'s 46 leaves room for RFC 4291's mixed form
  (`ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255`), which `inet_ntop`
  writes only for IPv4-mapped and -compatible addresses.

### What it replaces in the adopters

- NIO `Sources/NIOCore/SocketAddresses.swift`: `descriptionForAddress`
  and its `inet_ntop` buffers, clearing `// SYSTEM-GAP: INET_ADDRSTRLEN,
  INET6_ADDRSTRLEN (buffer sizes for NIO's inet_ntop)`, and the
  `inet_pton` into `in_addr` and `in6_addr` in `init(ipAddress:port:)`;
  `Sources/NIOCore/BSDSocketAPI.swift`'s `inet_pton` and `inet_ntop`
  wrappers (`// SYSTEM-GAP: … inet_ntop, inet_pton`); and
  `Tests/NIOCoreTests/SocketAddressTest.swift`.

### Platforms

- Built and tested: macOS 26.3. Not built on Linux (paused); it uses only
  `inet_pton`, `inet_ntop` and the two constants, which glibc, Musl and
  Bionic declare.

### Tests

- New: `SocketAddressHostTextTests` (4).
- macOS: XCTest 442 run, 4 skipped, 0 failures; swift-testing 359 tests in
  53 suites pass.
