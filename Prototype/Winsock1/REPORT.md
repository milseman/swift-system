# The winsock-1 lane: Windows sockets for System

System's sockets on Windows, so that swift-nio and swift-certificates can leave WinSDK's Winsock for System. The
design is `Prototype/Win32/REPORT.md` section 29 ("windows-3: Winsock, a design"), with the module structure Michael
chose on 2026-09-25: a separate, Windows-only module, `SystemWinSocks`, which declares SystemSockets' names and
signatures over Winsock (section 29's P0, its second form). Base: system-next at `3f3aed7`. Nothing here builds or
runs real Windows: the code is written from the Winsock documentation, compiled on macOS against a model of the SDK
by `Prototype/Win32/check-winsock.sh`, and kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

**Resume here:** P1's first four parts are done (section 1): the module, its manifest and CMake hooks, the harness
and its model, Winsock's error codes as `Win32.Error`, the socket types, `open` (`WSASocketW`, starting Winsock
lazily), `close` and `shutdown` (`e7c4d48`); addresses, with `inet_pton` and `inet_ntop` (`5f3381d`); binding,
listening, accepting, connecting, sending and receiving, and the socket names (`1dea80c`); and options (this commit).
- **Next**, in order: nonblocking (`ioctlsocket(FIONBIO)`) and open options, which finish P1; then P2: `WSAPoll`,
  the extension functions and `WSASendMsg`/`WSARecvMsg`, completion ports, Unix domain sockets.
- **Check** with `Prototype/Win32/check-winsock.sh` after each change; `swift build` and `swift test` on macOS, which
  compile none of it; `Utilities/lint/lint.sh cmake api`.

## 1. What

`Sources/SystemWinSocks`, a module that only a Windows host's manifest declares, with a target that links `ws2_32`
(the WinSDK module map's WinSock2 submodule links it too), its test target `Tests/SystemWinSocksTests`, and a CMake
list that `Sources/CMakeLists.txt` adds only when `CMAKE_SYSTEM_NAME` is Windows. Every file is inside `#if
os(Windows)`. Its files mirror SystemSockets' layout:

| File | What |
|---|---|
| `Sockets/SocketDescriptor.swift` | `SocketDescriptor` (`rawValue: SOCKET`), `Domain`, `ConnectionType`, `ProtocolID`, `MessageFlags`, `ShutdownKind` |
| `Sockets/SocketOperations.swift` | `open` (`WSASocketW`), `close` (`closesocket`), `shutdown`, `bind`, `listen`, `accept`, `connect`, `send` and `receive` (with and without an address: `send`, `recv`, `sendto`, `recvfrom`), `getLocalAddress` and `getPeerAddress` |
| `Win32Error+Winsock.swift` | Winsock's codes as `Win32.Error`, with `Errno`'s names |
| `Internals/WinsockStartup.swift` | `WSAStartup`, once per process, before the first socket |
| `Internals/WinsockSyscalls.swift` | the `system_` layer, the only callers of Winsock's functions |
| `Internals/WinsockConstants.swift` | internal constants, as values |
| `Util.swift` | `valueOrWinsockError` and its kin, `_buildDescription` |
| `Sockets/SocketAddress*.swift` | `SocketAddress` and `Family`, `IPv4Address`, `IPv6Address`, their `Host`s and text forms |
| `Internals/CInterop+WinSocks.swift` | `CInterop.SockAddr` (`SOCKADDR`), `SockLen`, `SAFamily`, `SockAddrIn`, `InAddr`, `In6Addr`, `SockAddrIn6`, `SockAddrStorage`, `Linger` |
| `Internals/CInterop+WinSockAccessors.swift` | SystemSockets' Swift-named accessors for those structures |
| `Sockets/SocketOptions.swift` | `OptionLevel`, `SocketOption`, `TCPOption`, `getOption`/`setOption` (`getsockopt`, `setsockopt`) and their conveniences |
| `Sockets/SocketOptions+IP.swift` | `IPOption`, `IPv6Option`, their typed options, multicast membership |
| `Sockets/SocketOptions+Timeouts.swift` | send and receive time-outs, linger |

The parts, in order: the module, the socket types, `open`, `close` and `shutdown` (`e7c4d48`); addresses
(`5f3381d`); connections, transfers and names (`1dea80c`); options (this commit).

## 2. Design calls, with the alternatives rejected

- **The module declares SystemSockets' names** (section 29's proposal 1, in P0's second form, as Michael decided):
  `SocketDescriptor`, its nested types, and their members have SystemSockets' spellings and parameter lists, so code
  written against them compiles on both where the concept holds. The differences are the ones section 29 predicts:
  the raw value's type (`SOCKET`, a `UINT_PTR`), the error type (`Win32.Error`), and what Winsock lacks. *Rejected*:
  section 29's default, SystemSockets' own sources compiled for Windows over a Winsock `system_` layer; Michael chose
  the separate module for its different handle type, errors, startup, linkage and message API. Section 6 says where
  sharing the code would have saved work.
- **Only a Windows host declares the target and product**, as only a host other than Windows declares the plugin
  targets, and as the request says ("built only on Windows"). Nothing changes on macOS or Linux. *Rejected for now*:
  declaring them everywhere, with every file inside `#if os(Windows)` so that they're empty elsewhere. That would let
  an adopter's manifest say `.product(name: "SystemWinSocks", package: "swift-system", condition: .when(platforms:
  [.windows]))`, as NIO's says of SystemSockets: SwiftPM looks a product dependency up whatever its condition, and a
  product the host's manifest doesn't declare is an error (`productDependencyNotFound`, in
  `../swift-package-manager/Sources/PackageGraph/ModulesGraph+Loading.swift`, the loop at "Establish product
  dependencies"). With the default, an adopter wraps its dependency in `#if os(Windows)`, which a cross-compiling
  build (manifest on one host, Windows the target) gets wrong. **Open question for Michael**; switching is a few
  lines of `Package.swift`.
- **Errors are `Win32.Error`** (section 29's proposal 4). Winsock's codes are system error codes, which `FormatMessageW`
  describes. Each code is named as `Errno` names the POSIX code it stands for (`wouldBlock`, `connectionReset`,
  `socketNotConnected`, `nowInProgress`, `notSupportedOnSocket`), so that a typed `catch .wouldBlock` reads the same
  on both platforms; the three Winsock-only codes have names of their own (`networkSubsystemNotReady`,
  `winsockVersionNotSupported`, `winsockNotStarted`). In an untyped catch, `.wouldBlock` is ambiguous between `Errno`
  and `Win32.Error`, both of whose `~=` are disfavored, so spell the type there. *Rejected*: section 29's shorter
  names (`inProgress`, `notConnected`), which would make a shared call site spell the code two ways; and `Errno`,
  which section 29 rejects. The names are in an extension in this module, not in `Sources/System/Win32/`.
- **Winsock starts lazily** (proposal 5): `open` calls `WSAStartup(2.2)` through a global whose initializer runs
  once per process, so the first call's result is every call's, failure included; System never calls `WSACleanup`.
  *Rejected*: retrying a failed start on the next `open`, which a modern Windows never needs; starting from a C
  runtime initializer, as NIO's `CNIOWindows` does, which needs a C target; and asking callers to start it.
- **Sockets are created with `WSASocketW`, `WSA_FLAG_OVERLAPPED` and `WSA_FLAG_NO_HANDLE_INHERIT`** (proposal 6):
  `socket`'s sockets are overlapped already, and blocking `send` and `recv` still block on them; the second flag is
  `SOCK_CLOEXEC`'s counterpart, and a test checks it with `GetHandleInformation`.
- **`retryOnInterrupt` stays**, with SystemSockets' defaults, and retries `WSAEINTR`, which Winsock 2 reports only for
  a call that Winsock 1.1's `WSACancelBlockingCall` canceled. *Rejected*: dropping the parameter, which would break the
  shared signatures for nothing.
- **Constants are values** (`Domain(rawValue: 23)`), as the Win32 namespace's are, with the doc sentence naming the C
  constant, and `@_alwaysEmitIntoClient`. The tests hold each to the SDK's macro on Windows; on macOS the harness
  holds them to the model's values, and the model's to Rust's bindings where those have them (section 3).
- **What Winsock lacks is left out** (proposal 2), not faked: `fileDescriptor` and the initializers from a
  `FileDescriptor` (a Winsock socket isn't a C runtime descriptor), `MessageFlags.endOfRecord` and `.noSignal`,
  `Domain.routing` and `.keyManagement`, and `CInterop.InAddrT` and `.InPort` (Winsock has no `in_addr_t` or
  `in_port_t`).
- **Addresses keep SystemSockets' API**, with what Winsock spells differently hidden behind the Swift-named
  accessors: `in_addr`'s `s_addr` and `in6_addr`'s `s6_addr` are macros for union members on Windows
  (`S_un.S_addr`, `u.Byte`), which Swift can't import, and Winsock's structures have no length field. The
  differences that show: `descriptionCapacity` is Windows' `INET_ADDRSTRLEN` and `INET6_ADDRSTRLEN`, 22 and 65,
  where POSIX's are 16 and 46; `description(into:)` throws `invalidParameter` for a buffer too small, which is what
  Windows' `inet_ntop` reports, where POSIX's reports `ENOSPC`; and `SocketAddress(address:length:)` treats a
  negative length as 0, since Winsock's `socklen_t` is a signed `int`.
- **Accepted sockets are made non-inheritable** with `SetHandleInformation` just after `accept` returns, as Python
  does: `WSA_FLAG_NO_HANDLE_INHERIT` is a creation flag, which the listening socket's doesn't pass on, so a child that
  another thread creates in between, inheriting handles, can inherit the socket, as on Darwin with `closeOnExec`. If
  that fails, the socket is closed and the error thrown. *Rejected*: leaving accepted sockets inheritable, unlike
  `open`'s; `AcceptEx` with a socket created non-inheritable, which has no window but is the overlapped API (P2).
- **Winsock's behaviors that differ from POSIX are documented where they show, not hidden**: a datagram that doesn't
  fit fills the buffer and throws `messageTooLong`, where POSIX returns the truncated count; a nonblocking connect
  throws `wouldBlock`, where POSIX throws `EINPROGRESS`; `getLocalAddress` of an unbound socket throws
  `invalidArgument`, where POSIX reports the unspecified address; closing a nonblocking socket with a linger time
  can throw `wouldBlock` and leave it open; a refused connection takes a second or more, since Windows' TCP retries
  it. One is hidden: Winsock leaves `recvfrom`'s address untouched on a connected stream socket, where POSIX reports
  none, so `receive(into:sender:)` empties the address first and leaves it empty if nothing filled it, as
  SystemSockets' callers expect.
- **Lengths are clamped to `Int32.max`**, since Winsock's `send` and `recv` take an `int`: a stream sends or receives
  less, as it may anyway, and no datagram is that long.
- **Options keep SystemSockets' signatures; Winsock's value types are inside them**: the time-outs are `DWORD`
  milliseconds, so `setReceiveTimeout` rounds up to a millisecond where SystemSockets rounds to a microsecond, and a
  time-out throws `timedOut`, not `wouldBlock`, and leaves the socket in a state Winsock says not to use; `linger`'s
  fields are `u_short`, so `setLinger` clamps to 65,535 seconds; the IPv4 multicast loop and time-to-live are
  `DWORD`s, where POSIX's are bytes. Winsock writes some boolean options (`TCP_NODELAY`) as one byte, which the zeroed
  `CInt` that `_flag` and `getOption` read from still reads right.
- **Option names Winsock has, and only those**: no `reusePort` (Winsock has no `SO_REUSEPORT`), no low-water marks (its
  providers fail them), no `noSigPipe` or `timestamp`; `receivePacketInfo` is `IP_PKTINFO` and `IPV6_PKTINFO`, as
  Linux's IPv4 one is, since Winsock has no `IPV6_RECVPKTINFO`. Two Windows options under Windows names:
  `exclusiveAddressUse` (`SO_EXCLUSIVEADDRUSE`), since Windows' `reuseAddress` lets a socket take an address another
  socket is bound to, which its documentation now says, and `reuseUnicastPort` (`SO_REUSE_UNICASTPORT`), which NIO
  imports. *Rejected*: making `reuseAddress` mean POSIX's on Windows, which Winsock has no option for.
- **The address conversions don't start Winsock**: their documentation lists no `WSANOTINITIALISED`, and
  swift-certificates already calls `inet_pton` without starting it. An exit test checks it in a fresh process.
  *Rejected*: starting Winsock for them, which would load Winsock's providers into a process that only parses
  certificates.
- **`in6addr_any` and `in6addr_loopback` are built in Swift**, from their bytes: the SDK declares them as data that
  `ws2_32.dll` exports, which a Swift client would reach through a DLL import for sixteen fixed bytes.

## 3. The model, and what it can't catch

`Prototype/Win32/check-winsock.sh` compiles `Sources/SystemWinSocks` and `Tests/SystemWinSocksTests` on macOS to object
code, with their `os(Windows)` conditions turned on, against `Prototype/Win32/WindowsModel` and its new
`Winsock/` part: `winsock2.h`, `ws2tcpip.h` and `mswsock.h` (each declaration marked with the SDK header it mirrors),
their module map, and `WinSDK+Winsock.swift`, the overlay's Winsock declarations (`INVALID_SOCKET`, `FIONBIO`). It
builds SystemPackage from `SystemPackageStubs.swift` and the real `Sources/System/Win32`, as `check-windows.sh` does,
so `Win32.Error` is the real one. It takes about ten seconds.

- **The module map.** On Windows, Winsock is the WinSock2 submodule of the WinSDK Clang module. Clang won't add a
  submodule to WindowsModel's WinSDK from a second module map (`module WinSDK.WinSock2` parses, but Clang's build of
  WinSDK reads only the map that defines it), so the Winsock model is a Clang module of its own, `WinSock2Model`,
  which the harness's WinSDK overlay re-exports: `import WinSDK` and `WinSDK.socket` then work as on Windows. The
  harness fails if a source or test file names `WinSock2Model`.
- **Private tags.** The structures that macOS's C library also defines (`sockaddr_in`, `in_addr`, `linger` and the
  rest) have private tags, as WinSDK.h's `sockaddr` does, since Clang rejects two definitions of a tag when a file sees
  both modules; the code spells them by their SDK typedefs (`SOCKADDR_IN`), which Windows has too.
- **Checks before compiling**: every top-level declaration in the headers names its SDK header; every numeric
  constant matches Rust's standard library bindings (Homebrew's Rust source, or `WINDOWS_SYS_RS`), which Microsoft's
  metadata generates, where they have it, which is about two thirds; the overlay stand-ins match the real overlay,
  read from `../ecosystem/swift` (`SWIFT_SOURCE`); and every SystemWinSocks constant whose doc names its C constant has
  the model's value. A wrong value in either place fails the run (tried).
- **It can't catch** where the model differs from the SDK in a way Swift sees: a macro that doesn't import on
  Windows, a type the importer gives differently, a structure's layout (the model's `SCOPE_ID` has no bit-fields, and
  `WSAPROTOCOL_INFOW` is incomplete); runtime behavior; or the constants Rust's bindings lack (the IP and IPv6
  options other than multicast's, the TCP keepalive options, `INET_ADDRSTRLEN`), which only the Windows tests check.

## 4. Tests

`Tests/SystemWinSocksTests`, swift-testing as SystemSocketsTests is, each test opening and closing its own sockets.
What each file checks, and what it can reach:

- `WinsockConstantsTests`: every constant, public and internal, against the SDK's macro; the descriptions. No sockets.
- `WinsockErrorTests`: every Winsock code against the SDK; `FormatMessageW` describes one; Winsock starts. No sockets.
- `SocketDescriptorTests`: opening and closing TCP, UDP and IPv6 sockets; that they aren't inherited; that an unknown
  family, closing `INVALID_SOCKET`, and shutting down an unconnected socket throw the codes the documentation gives.
  Nothing binds or connects.
- `SocketAddressTests`: the address families and text capacities against the SDK; parsing and formatting IPv4 and
  IPv6 addresses (strict dotted-decimal, no scopes); host addresses' bytes in network order; `SocketAddress`
  conversions and lengths; `description(into:)` and its `invalidParameter`; parsing C strings; the accessors against
  the C fields; and, in an exit test (a child process of swift-testing's own, which runs only the closure), that
  the conversions work before Winsock starts. No sockets.
- `SocketOperationsTests`: TCP over IPv4 and IPv6 loopback (bind to port 0, listen, connect, accept with the client's
  address, the peer's address, a `waitForAll` receive, a shutdown seen as the end of the stream); that accepted
  sockets aren't inherited; that a stream receive leaves the sender empty; a UDP round trip with the sender's
  address; a datagram larger than the buffer throwing `messageTooLong` after filling it; a refused connection to a
  port a socket holds without listening; the names of an unbound and unconnected socket; a second bind of an address
  in use. Every address is 127.0.0.1 or `::1`, with a port the system picks, so nothing reaches beyond the host or
  listens where the firewall would ask; every socket is the test's own and closed by a `defer`.
- `SocketOptionsTests`: every option name against the SDK; socket and TCP options, the keepalive times among them;
  `exclusiveAddressUse`; the time-outs' milliseconds and rounding; a receive that times out with `timedOut`; linger
  and its rounding; IPv4 and IPv6 options (Windows' `true` default for `isIPv6Only`); and a multicast datagram on
  loopback, a group joined on the loopback interface by a socket bound to 127.0.0.1 and sent to from the loopback
  interface, so that neither the datagram nor the membership report leaves the host.

None deletes, moves or changes the permissions of anything, signals anything, or reaches the network.

## 5. For the adopters

Filled in as the API lands; see section 8.

## 6. Where sharing SystemSockets' code would have saved work

So far: the five nested types of `SocketDescriptor.swift` and the operations' bodies are SystemSockets' with
constants and error types changed, and `Util.swift`'s helpers are its `valueOrErrno` family over another failure
test. Sharing would have saved writing them twice and keeping the doc comments in step; it would have cost the
`#if os(Windows)` in each body that the raw value's type, the error type, and the omissions need.

## 7. Needs outside the lane's files

- **Building on Windows**: SystemSockets' files `#error` outside Darwin, Linux, Musl, Android and WASI, and
  `Package.swift` doesn't exclude it on Windows, so `swift build` and `swift test` there stop at those errors before
  reaching SystemWinSocks. The Windows box needs SystemSockets, SystemSocketsTests and Samples' dependency on
  SystemSockets left out of a Windows host's manifest (Samples' other sources may not build there either), or
  `swift build --target SystemWinSocks`, which can't run the tests.
- **`Win32.Error`'s `debugDescription`** names only the codes SystemPackage's `_symbolicName` lists, so Winsock's
  codes print as numbers (`10035 (0x2733)`); its table needs the `WSAE` names.
- **The tools** know two modules: `Utilities/api-delta/scripts/scan_sources.py` (`MODULE_DIRS`), the adopter-coverage
  scripts (`status.py`'s `SYSTEM_SOURCES`, `extract.py`'s `SYSTEM_MODULES`), and lint's cmake check (`MODULES`) read
  only `Sources/System` and `Sources/SystemSockets`, so neither lint's api rules, the coverage figures, nor the
  status page see SystemWinSocks yet.

## 8. Next

See *Resume here*.
