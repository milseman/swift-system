# The winsock-1 lane: Windows sockets for System

System's sockets on Windows, so that swift-nio and swift-certificates can leave WinSDK's Winsock for System. The
design is `Prototype/Win32/REPORT.md` section 29 ("windows-3: Winsock, a design"), with the module structure Michael
chose on 2026-09-25: a separate, Windows-only module, `SystemWinSocks`, which declares SystemSockets' names and
signatures over Winsock (section 29's P0, its second form). Base: system-next at `3f3aed7`. Nothing here builds or
runs real Windows: the code is written from the Winsock documentation, compiled on macOS against a model of the SDK
by `Prototype/Win32/check-winsock.sh`, and kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

**Resume here:** P1 is done (section 1), in five parts: the module, its manifest and CMake hooks, the harness and
its model, Winsock's error codes as `Win32.Error`, the socket types, `open` (`WSASocketW`, starting Winsock lazily),
`close` and `shutdown` (`e7c4d48`); addresses, with `inet_pton` and `inet_ntop` (`5f3381d`); binding, listening,
accepting, connecting, sending and receiving, and the socket names (`1dea80c`); options (`13c9a37`); and nonblocking
mode with open options (`a4f6883`). P2's first four parts are done: polling, with `WSAPoll` (`56851b2`); messages,
with `WSASendMsg` and `WSARecvMsg` looked up once per process, SystemSockets' ancillary messages, and the IP control
messages (`f26f4c6`); completion ports, with overlapped `WSASend` and `WSARecv` (`9d94aa0`); and the stream extension
functions, `AcceptEx`, `ConnectEx` and `TransmitFile` (this commit). Section 5 has what each adopter would change,
row by row.
- **Next**, the last of P2: Unix domain sockets as Windows has them (`SOCKADDR_UN`, `UnixAddress`, stream only, and
  their files, which are reparse points); then, beyond P2, Windows name resolution (`GetAddrInfoW`), which the
  [Windows name resolution] row needs.
- **Open questions for Michael** (section 2): the manifest's form (host-conditional, or declared everywhere and empty
  elsewhere), and the module's name, which adopters that qualify names (`SystemSockets.SocketAddress`) spell per
  platform.
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
| `Sockets/SocketOpenOptions.swift` | `OpenOptions.nonBlocking`, `open(options:)`, `accept(options:)`, and `setNonBlocking(_:)` (`ioctlsocket(FIONBIO)`) |
| `Sockets/SocketPoll.swift` | `CInterop.PollFD` (`WSAPOLLFD`), `SocketDescriptor.PollEvents` and `PollEntry`, the static `poll(_:timeout:retryOnInterrupt:)` over a `MutableSpan`, and `poll(for:timeout:retryOnInterrupt:)` (`WSAPoll`) |
| `Internals/WinsockExtensions.swift` | the extension functions, looked up once per process through a probe socket (`WSAIoctl(SIO_GET_EXTENSION_FUNCTION_POINTER)`) |
| `Sockets/SocketMessages.swift` | `SocketDescriptor.Option`, `AncillaryMessageBuffer` and `UnsafeAncillaryMessages` over `WSACMSGHDR`, laid out as `WSA_CMSG_*` lays them out |
| `Sockets/SocketMessages+IP.swift` | `IPv4PacketInfo` (`IN_PKTINFO`), `IPv6PacketInfo`, `ExplicitCongestionNotification`, the messages' `typeOfService`, `trafficClass` and packet info, and `appendTypeOfService`/`appendTrafficClass` |
| `Sockets/SocketOperations+Messages.swift` | `sendMessage` and `receiveMessage` (`WSASendMsg`, `WSARecvMsg`), in the span forms and the header forms |
| `Internals/RawBuffer.swift` | SystemSockets' copy-on-write buffer, copied |
| `Sockets/SocketStreamExtensions.swift` | `accept(into:addresses:overlapped:)` (`AcceptEx`) and `updateAcceptContext(listener:)`, `connect(to:overlapped:)` (`ConnectEx`) and `updateConnectContext()`, `transmitFile(_:byteCount:fromAbsoluteOffset:options:overlapped:)` (`TransmitFile`) with `TransmitFileOptions` |
| `Sockets/SocketOverlappedIO.swift` | `Win32.CompletionPort.associate(_:key:)` for a socket; overlapped `send(_:flags:overlapped:)` (`WSASend`) and `receive(into:flags:overlapped:)` (`WSARecv`), `result(of:wait:)` (`WSAGetOverlappedResult`), `cancel(_:)` and `cancelAll()` (`CancelIoEx`) |

`CInterop` also gains `IOVec` (`WSABUF`), `MsgHdr` (`WSAMSG`) and `CMsgHdr` (`WSACMSGHDR`), with SystemSockets' accessors
for them, and SystemPackage's for `iovec`.

The parts, in order: the module, the socket types, `open`, `close` and `shutdown` (`e7c4d48`); addresses
(`5f3381d`); connections, transfers and names (`1dea80c`); options (`13c9a37`); nonblocking mode and open options
(`a4f6883`). P2: polling (`56851b2`); messages (`f26f4c6`); completion ports (`9d94aa0`); the stream extension
functions (this commit).

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
- **The module's name is Michael's working name, `SystemWinSocks`.** Code that qualifies a name with its module then
  spells it per platform. NIO does, since NIOCore has a `SocketAddress` of its own: its Darwin branches say
  `SystemSockets.SocketAddress.Family.ipv4` (`NIOCore/BSDSocketAPI.swift` near line 230), which on Windows would be
  `SystemWinSocks.SocketAddress.Family.ipv4`. **Open question for Michael**: the alternatives are naming the Windows
  module `SystemSockets` too, with a host-conditional `path:` in the manifest (the same module name on every platform,
  each with its own sources), or leaving each adopter to alias the module (SwiftPM's `moduleAliases` on the product
  dependency).
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
- **Nonblocking mode**: `OpenOptions.nonBlocking` for `open` and `accept`, set with `ioctlsocket(FIONBIO)` right after
  the call, as SystemSockets sets it with `fcntl` on Darwin, and `accept(options:)` sets the new socket's mode exactly,
  since Winsock's `accept` passes the listener's on. Winsock can set the mode but not report it, so the Windows-only
  addition is a setter, `setNonBlocking(_ enabled: Bool = true)`, named as `setReuseAddress` and `setNoDelay` are, for
  what POSIX does with `FileDescriptor.setStatusFlags`. There's no `OpenOptions.closeOnExec`: Windows has no `exec`, and
  System's sockets are never inherited. *Rejected*: a `closeOnExec` that does nothing, which would compile shared code
  that means something Windows can't; and a getter, which Winsock can't implement.
- **Polling is `SocketDescriptor`'s** (section 29's proposal 7): SystemPackage's POSIX `poll` is `FileDescriptor`'s, with
  `FileDescriptor.PollEvents`, `PollEntry`, a static `poll` over a `MutableSpan` and a `poll(for:timeout:)`; `WSAPoll`
  polls sockets alone, so the same names and signatures are on `SocketDescriptor`, with the entry's `socket` where
  POSIX's has `fileDescriptor`. There's no `priority` event: Winsock's provider rejects `POLLPRI`. `readable` is
  `POLLIN`, which Winsock defines as `POLLRDNORM | POLLRDBAND`, and NIO polls `POLLRDNORM`, `readableNormalData`.
  The documentation notes `WSAPoll`'s missed failed connects before Windows 10 version 2004. *Rejected*: putting
  Windows' poll on `FileDescriptor`, which a socket isn't. SystemSockets could add the same `SocketDescriptor` names
  on POSIX, over `poll`, so that code polling sockets spells it once (section 7).
- **Extension functions are looked up once per process** (section 29's proposal 7), each family through a socket
  System opens for the purpose and closes, as Go's `golang.org/x/sys/windows` does (a UDP socket for `WSARecvMsg`
  and `WSASendMsg`), from a global whose initializer runs once, so the first lookup's result is every call's. Windows'
  own providers give every socket the same functions. *Rejected*: NIO's lookup on every call, which costs a
  `WSAIoctl` per message; libuv's per handle, and .NET's per family, type and protocol, which serve layered
  providers, at the cost of a cache to keep. `WSASendMsg` is also an export of `ws2_32` since Vista; it's looked up
  with `WSARecvMsg`, as NIO does, so that both come from the socket's provider.
- **Messages keep SystemSockets' API over Winsock's structures**: `CInterop.MsgHdr` is `WSAMSG`, `CMsgHdr` is
  `WSACMSGHDR` (16 bytes, aligned to 8, so `space(forPayloadSize:)` and `length(forPayloadSize:)` are Linux's 64-bit
  values), and `IOVec` is `WSABUF`, with SystemSockets' accessors and SystemPackage's `iovec` ones. What shows:
  - `WSAMSG`'s own address field is called `name`, a `SOCKADDR` pointer, so SystemSockets' accessor of that name,
    a raw pointer, can't be declared beside it: the initializer takes a raw pointer, and code that sets the field
    spells its type.
  - `WSARecvMsg` reads its flags from the header's `dwFlags`, which `receiveMessage(_:flags:)` sets from `flags`
    before each call.
  - A datagram that doesn't fit throws `messageTooLong`, as `receive` does, where POSIX returns it with
    `dataTruncated`. *Rejected*: turning `WSAEMSGSIZE` into a count and `dataTruncated`, which would need the count
    Winsock doesn't report for a failed call.
  - Windows' own providers support `WSARecvMsg` and `WSASendMsg` on datagram and raw sockets, which the
    documentation says.
  - No `SCM_RIGHTS`: `appendFileDescriptors`, `fileDescriptors` and `Option.rights` are left out.
- **IP control messages read Winsock's layouts**: its `IN_PKTINFO` is the address then the index, 8 bytes, where
  Linux's `in_pktinfo` is 12 and has a local address, so `IPv4PacketInfo` has no `localAddress`, and its initializer
  takes two fields. A received type of service is read whether Winsock sends it as `IP_RECVTOS` or `IP_TOS`, and a
  traffic class as `IPV6_TCLASS` or `IPV6_RECVTCLASS`, since the documentation doesn't say; a Windows run tells
  which. `appendTypeOfService` and `appendTrafficClass` build the messages POSIX takes, which `WSASendMsg` may not
  honor; Windows' own are `IP_ECN` and `IPV6_ECN`, not wrapped. No `timestamp`: Winsock has no `SO_TIMESTAMP`.
- **Overlapped socket I/O follows section 27's overlapped files**: `@unsafe` operations with raw pointers for the
  `OVERLAPPED` and the buffer, which Windows uses until the operation finishes; `nil` for a pending one; the
  `OVERLAPPED` not read after the call starts it, since a completion port's waiter can take the packet first; and
  `cancel` returning `false` when nothing was pending. `Win32.CompletionPort` gains `associate(_:key:)` for a socket,
  in an extension in this module, through the port's `unsafeRawHandle`, which section 27 left for Winsock to add.
  What differs from files: `result(of:wait:)` can wait only for an operation whose `OVERLAPPED` has an event, as
  `WSAGetOverlappedResult` requires, and it throws Winsock's code, where a completion port's packet carries the
  Win32 code the kernel's status maps to (`ERROR_NETNAME_DELETED` for a reset connection, not `WSAECONNRESET`),
  which the documentation says. *Rejected*: an owner for overlapped sockets, as `Win32.OverlappedFileHandle` is for
  files: every socket System opens is overlapped already, and its blocking calls are safe, unlike `ReadFile` on an
  overlapped file; and returning `WSAGetOverlappedResult`'s flags, which matter only to message-oriented protocols.
- **`AcceptEx`, `ConnectEx` and `TransmitFile` are Windows API under Swift names** (section 29's proposal 2: "Windows'
  own, under Windows names"): `accept(into:addresses:overlapped:)`, `connect(to:overlapped:)` and
  `transmitFile(_:byteCount:fromAbsoluteOffset:options:overlapped:)`, overlapped by the rules above, returning whether
  the operation finished in the call; and the two options they need afterward, as methods: `updateAcceptContext
  (listener:)` (`SO_UPDATE_ACCEPT_CONTEXT`) and `updateConnectContext()` (`SO_UPDATE_CONNECT_CONTEXT`). They're looked
  up once per process through a TCP socket, as the message functions are through a UDP one; `mswsock.dll` exports
  them too, but linking it isn't needed then, and the lookup is Microsoft's advice. Their `BOOL` is an `int`, which
  their Swift types spell as `CInt`, rather than taking the SDK's `LPFN_` typedefs, since Swift imports `BOOL` as
  `WindowsBool` or `Bool` depending on the context (the model as `ObjCBool`). Neither takes initial data, which
  `AcceptEx` and `ConnectEx` can carry; `transmitFile` takes a borrowed raw `HANDLE`, which a C runtime descriptor's
  `withWin32HandleIfAvailable` gives, and no head or tail buffers. *Rejected*: taking a `Win32.FileHandle`, which a
  caller with a descriptor, as NIO is, can't make without taking ownership.
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
- `SocketNonBlockingTests`: `FIONBIO` against the SDK; `accept` with no connection and `receive` with nothing to read
  throwing `wouldBlock`, and blocking again after `setNonBlocking(false)`; `accept(options:)` setting the new socket's
  mode whatever the listener's (told apart by what an empty receive throws: `wouldBlock` at once, or `timedOut` after a
  50 ms time-out); and a nonblocking connect, which throws `wouldBlock` or finishes, then has no error once accepted.
- `SocketPollTests`: the events against the SDK and their descriptions; the time-out's rounding; a connection's
  readiness (writable, not readable, readable once a byte arrives, hung up or readable once the peer closes); a
  listening socket readable with a connection pending; two entries polled at once. Every wait has a time-out.
- `SocketMessagesTests`: the message functions found, and `SIO_GET_EXTENSION_FUNCTION_POINTER` against the SDK's
  `IOC_` macros; the layout's sizes, and messages appended, iterated and read back; a UDP message with its sender's
  address; a header of the test's own, gathering from two buffers and scattering into two; IPv4 and IPv6 packet
  information on loopback; a received type of service; and a datagram too long for the buffer. UDP over 127.0.0.1
  and `::1` only, each receive with a five-second time-out.
- `SocketOverlappedIOTests`: the codes against the SDK; an overlapped receive, pending until the peer sends, reported
  through a completion port with its key, `OVERLAPPED` and count, and by `result(of:wait:)`; an overlapped send's
  packet, whether it finished at once or not; a canceled receive's packet and result, `operationAborted`, and
  nothing left to cancel; a second association failing with `invalidParameter`. Each `OVERLAPPED` and buffer is freed
  only after its packet is dequeued, and every dequeue has a five-second time-out.
- `SocketStreamExtensionsTests`: the options and context codes against the SDK, the functions found, and the address
  capacity; an overlapped accept and an overlapped connect on loopback, both reported through a completion port, then
  the context updates and both sockets' names; and `transmitFile` sending 900 bytes of a temporary file from an offset
  of 100, reported through a port and received whole. The file is the test's own: a random name in
  `FilePath.temporaryDirectory()`, created with `createNew` (so it can't open another file), shared with no one, and
  opened with `deleteOnClose`, so the system deletes it when its handle closes, even if the test crashes.

None deletes, moves or changes the permissions of anything, signals anything, or reaches the network.

## 5. For the adopters

What each of STATUS.md section 5's socket rows would change in swift-nio (`../adopters/swift-nio`, `migrate-darwin` at
`e1623fbf`) and swift-certificates (`../adopters/swift-certificates`, `migrate-all` at `c310582c`), and what's still
missing. Neither is changed here.

The common change: both already use SystemSockets' names on the platforms that have it, behind `#if canImport(Darwin)`
(NIO) or `#if canImport(SystemSockets)` (certificates), with WinSDK's C names in the other branch. With SystemWinSocks
those branches widen to Windows (`|| os(Windows)`, `|| canImport(SystemWinSocks)`), importing SystemWinSocks there, and
the WinSDK branch and its `import let WinSDK.X` lines go. Their manifests add the product for Windows: inside `#if
os(Windows)` with this lane's default, or as `.when(platforms: [.windows])` with the alternative (section 2). NIO's
module-qualified names (`SystemSockets.SocketAddress`) need the naming decision.

| Row | Where | With SystemWinSocks | Still missing |
|---|---|---|---|
| [address families] | NIO `NIOCore/BSDSocketAPI.swift:36-42` and the families at 228-303; `NIOCore/SocketAddresses.swift:18-19`; `NIOCore/Interfaces.swift:34-35`; `NIOCore/Utilities.swift:34`; `NIOPosix/GetaddrinfoResolver.swift:45-46`. Certificates `ServerIdentityPolicy.swift:26`, `URIConstraints.swift:21` | `SocketAddress.Family` and `SocketDescriptor.Domain`, as the Darwin branches use them | the module qualifier |
| [protocol levels] | `BSDSocketAPI.swift:18-21`, 321-421 | `SocketDescriptor.OptionLevel` (`IPPROTO_IPV6.rawValue` and the rest go) | — |
| [socket options] | `BSDSocketAPI.swift:44-53`, 620-701; `BSDSocketAPIWindows.swift:61-69`, and `getsockopt`/`setsockopt` at 264-280 and 429-445 through CNIOWindows' shims | `SocketDescriptor.SocketOption`; `SocketDescriptor(rawValue:).getOption`/`setOption`, which take raw pointers' worth of `T` | NIO's raw-pointer form of the option calls (it passes `UnsafeRawPointer` and a length), which no platform's System has |
| [SO_RCVTIMEO and SO_TIMESTAMP] | `BSDSocketAPI.swift:49`, 673-679; `BSDSocketAPIWindows.swift:65` | `SocketOption.receiveTimeout`, and `receiveTimeout()`, whose value is milliseconds on Windows | `SO_TIMESTAMP`, which Winsock lacks |
| [multicast] | `BSDSocketAPI.swift:23-33`, 425-543; `NIOPosix/SocketChannel.swift:46-49` (`INADDR_ANY`, `ip_mreq`, `ipv6_mreq`) and the joins at 1285-1420; `BSDSocketAPIWindows.swift:38-48` | the option names, and `changeMembership` (`SocketChannel.swift` near 1391), the Darwin branch, which `joinMulticastGroup`/`leaveMulticastGroup` serve | — |
| [IPV6_V6ONLY and IP_HDRINCL] | `BSDSocketAPI.swift:25`, 34, 481-486, 545-550; `BSDSocketAPIWindows.swift:49` | `IPv6Option.v6Only`, `IPOption.headerIncluded` | — |
| [TCP_NODELAY] | `BSDSocketAPI.swift:55`, 558-563; `BSDSocketAPIWindows.swift:55` | `TCPOption.noDelay` | — |
| [ECN, TOS and packet info] | `NIOPosix/BSDSocketAPICommon.swift:29-30`; `NIOPosix/System.swift:116`; the decoding in `NIOPosix/ControlMessage.swift:225-330` and the encoding at 460-480 | the option names (`receiveTypeOfService`, `receiveTrafficClass`, `packetInfo`); the messages' `typeOfService`, `trafficClass`, `ipv4PacketInfo` and `ipv6PacketInfo`, as NIO's Darwin branch reads them, which also fixes NIO's Windows level: `ControlMessage.swift:34` takes the IPv4 messages' level to be `IPPROTO_IPV4` (4), where Winsock's is `IPPROTO_IP` (0) | `IP_ECN`, Windows' own ECN message |
| [socket types] | `BSDSocketAPICommon.swift:32-34` | `SocketDescriptor.ConnectionType` | — |
| [shutdown] | `BSDSocketAPIWindows.swift:57-59`, 177-188, 448-452 | `shutdown(_:)` with `ShutdownKind`, which takes Winsock's `SD_*` values | — |
| [Winsock sockets] | `BSDSocketAPIWindows.swift:26`, 32, 74, 80, 84, the close at 220-225 and `setNonBlocking` at 618-629; `BSDSocketAPICommon.swift:27`; `NIOPosix/Windows.swift:19` | `close()`, and `setNonBlocking()`, whose `invalidArgument` NIO turns into `NIOFcntlFailedError` | `INVALID_SOCKET`: System names no invalid socket on any platform, and NIO keeps its own sentinel |
| [socket], [bind], [listen], [accept], [connect], [send and receive], [getsockname and getpeername] | `BSDSocketAPIWindows.swift:192-262`, 283-300, 401-412, 454-465 | `open`, `bind(to:)`, `listen(backlog:)`, `accept`, `connect(to:)`, `send`, `receive`, `getLocalAddress`, `getPeerAddress`; NIO's `nil` from `accept` and `false` from `connect` on `WSAEWOULDBLOCK` become a `catch .wouldBlock` | as on Darwin: NIO passes raw `sockaddr` pointers, where System takes a `SocketAddress`, a copy |
| [Winsock addresses], [sockaddr types], [sockaddr_storage] | `BSDSocketAPIWindows.swift:99-124` (NIO's aliases of WinSDK's types to POSIX names); `SocketAddresses.swift:28-37`; `Interfaces.swift:40-48`; `GetaddrinfoResolver.swift:52-55`; certificates' `in_addr` and `in6_addr` | `CInterop.SockAddr` and the rest, and the Swift-named accessors, which NIO's Darwin code already reads (`groupAddress.address.address`); NIO's aliases go | `SOCKADDR_UN`: P2 |
| [INADDR_ANY] | `SocketChannel.swift:46`; `BSDSocketAPIWindows.swift:28-29`; `SocketAddresses.swift:21-22`; `Interfaces.swift:37-38` | `IPv4Address.Host.any`; each host type's `descriptionCapacity`, which is Windows' 22 and 65 | — |
| [inet_ntop and inet_pton] | `BSDSocketAPI.swift:59-60` and the conversions at 733-800; certificates `ServerIdentityPolicy.swift:170-195` (`inet_pton` into `in_addr`), 260-275, 380-390 (`memcmp`), and `URIConstraints.swift:71-74` (`InetPtonW`) | the Darwin branch's `IPv4Address.Host(cString:)` and `description(into:)`, which on Windows throws `invalidParameter` for a short buffer; certificates' `canImport(SystemSockets)` branches, whose `Host(string)` and `==` replace `inet_pton` and `memcmp` | — |
| [Winsock errors] | every `IOError(winsock: WSAGetLastError(), ...)` in `BSDSocketAPIWindows.swift`; `SelectorWSAPoll.swift:376` | errors arrive as `Win32.Error`; `IOError(winsock: CInt(bitPattern: error.rawValue), reason:)` keeps NIO's error type | — |
| [linger] | `NIOCore/SocketOptionProvider.swift:37`, 182-219 | `CInterop.Linger` and its accessors; the `setSoLinger(_: CInterop.Linger)` overload, which NIO has for Darwin, widened | — |
| [Winsock startup] | CNIOWindows' `WSAStartup.c`, a C runtime initializer | none needed: `open` starts Winsock | — |
| [Winsock messages] | `BSDSocketAPIWindows.swift:110-113` (the `WSAMSG`, `WSACMSGHDR` and `LPFN_WSARECVMSG` imports), 146-166 (the GUIDs and the ioctl code), `recvmsg` and `sendmsg` at 302-399, `writev` at 414-426, `sendmmsg` at 467-524, the `CMSG` shims at 703-751, and the `WSABUF` and `WSAMSG` accessors at 771-855 | `receiveMessage(_:flags:)` and `sendMessage(_:flags:)` with a `CInterop.MsgHdr`, which look the functions up once; `UnsafeAncillaryMessages(header)` for the shims; the accessors (`vectors`, `control`, `controlLength`, `flags`), but for `name`, the C field's own name; `CInterop.IOVec`'s `base` and `length` for NIO's `iov_base` and `iov_len` | `writev` (`WSASend` with several buffers) and `sendmmsg`, which Winsock lacks and NIO's loop of `WSASendMsg` stands in for |
| [poll] | `NIOPosix/SelectorWSAPoll.swift` (the events at 33-75, `WSAPoll` at 305 and its error at 376), `NIOPosix/SelectorGeneric.swift:24` (`pollfd`) | `SocketDescriptor.PollEntry` over its `pollfd` array and `SocketDescriptor.poll(_:timeout:)` over a `MutableSpan` of them, or `CInterop.PollFD` where NIO keeps raw entries; its event mapping uses `readableNormalData` and `writableNormalData`, as it uses `POLLRDNORM` and `POLLWRNORM` | — |
| [Windows name resolution] | `GetaddrinfoResolver.swift:44-55`, 145; `SocketAddresses.swift:24-29` | — | `GetAddrInfoW`, `FreeAddrInfoW`, `ADDRINFOW`: SystemSockets' `SocketAddress.resolve` over them, not started |
| [sendfile] | `BSDSocketAPIWindows.swift:76`, 90, 578-608 | `transmitFile(_:byteCount:fromAbsoluteOffset:options:overlapped:)` with `.useKernelAPC`, the descriptor's handle from `withWin32HandleIfAvailable`, and an `OVERLAPPED` that outlives the transmission, which NIO's code doesn't (section 7) | a synchronous form, which `TransmitFile` has only without an offset |

## 6. Where sharing SystemSockets' code would have saved work

So far: the five nested types of `SocketDescriptor.swift` and the operations' bodies are SystemSockets' with
constants and error types changed, and `Util.swift`'s helpers are its `valueOrErrno` family over another failure
test. Sharing would have saved writing them twice and keeping the doc comments in step; it would have cost the
`#if os(Windows)` in each body that the raw value's type, the error type, and the omissions need.

Messages: `SocketMessages.swift` and its IP part are SystemSockets' with Winsock's layout and the descriptor messages
removed, and `RawBuffer.swift` is copied whole; about 900 lines that sharing would have written once, with a
`#if` for the layout's alignment, the packet-info structure, and the `SCM_RIGHTS` parts.

## 7. Needs outside the lane's files

- **Building on Windows**: SystemSockets' files `#error` outside Darwin, Linux, Musl, Android and WASI, and
  `Package.swift` doesn't exclude it on Windows, so `swift build` and `swift test` there stop at those errors before
  reaching SystemWinSocks. The Windows box needs SystemSockets, SystemSocketsTests and Samples' dependency on
  SystemSockets left out of a Windows host's manifest (Samples' other sources may not build there either), or
  `swift build --target SystemWinSocks`, which can't run the tests.
- **`Win32.Error`'s `debugDescription`** names only the codes SystemPackage's `_symbolicName` lists, so Winsock's
  codes print as numbers (`10035 (0x2733)`); its table needs the `WSAE` names.
- **SystemSockets**: `SocketDescriptor.PollEntry` and `poll` over POSIX `poll` would let code that polls sockets spell
  it as on Windows. And its `_value` and `_setValue` (`Sources/SystemSockets/Sockets/SocketOptions+IP.swift:280`, 289)
  warn "forming 'UnsafeMutableRawPointer' to a variable of type 'T'"; SystemWinSocks passes the value through
  `withUnsafeMutableBytes(of:)` and `withUnsafeBytes(of:)`, which don't.
- **swift-nio**: `NIOPosix/ControlMessage.swift:34` takes the IPv4 control messages' level on Windows to be
  `IPPROTO_IPV4` (4), where Winsock's is `IPPROTO_IP` (0), so NIO's Windows branch never decodes a received type of
  service or IPv4 packet information. Adopting SystemWinSocks fixes it; until then, it's NIO's to fix.
- **swift-nio**: `NIOPosix/BSDSocketAPIWindows.swift`'s `sendfile` (578-608) passes `TransmitFile` an `OVERLAPPED` on the
  stack, on a socket that `socket` made overlapped, and throws when the call returns `FALSE`, which an overlapped
  transmission does with `WSA_IO_PENDING` while still going; Windows then writes the result into a stack frame that's
  gone, and the bytes NIO reported as an error are sent anyway. On success it reports the whole length as sent, which
  a transmission that's pending hasn't. Its `pread` and `pwrite` (530-576) pass `ReadFile` and `WriteFile` stack
  `OVERLAPPED`s the same way. These look like NIO's to fix; with System, the `OVERLAPPED` is the caller's to keep.
- **The tools** know two modules: `Utilities/api-delta/scripts/scan_sources.py` (`MODULE_DIRS`), the adopter-coverage
  scripts (`status.py`'s `SYSTEM_SOURCES`, `extract.py`'s `SYSTEM_MODULES`), and lint's cmake check (`MODULES`) read
  only `Sources/System` and `Sources/SystemSockets`, so neither lint's api rules, the coverage figures, nor the
  status page see SystemWinSocks yet.

## 8. Next

See *Resume here*.
