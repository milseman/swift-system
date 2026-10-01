# Status: System's API and its adopters

Generated 2026-10-01 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage-4` @ `79ee4f78` (Add a _SystemPackageForPlugin product: SystemPackage's sources as a module of another name, for SourceKit-LSP's plugins), which contains `system-next` @ `bb950dbd` (Merge branch 'api-graph-speed' into system-next); 4 commit(s) of `coverage-4` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `79ee4f78`.
- **Adopters** (`../adopters`, branch `migrate-darwin`, against its merge base with `main`):
  - WasmKit @ `4917e060`, base `1e9c513d`
  - indexstore-db @ `53bf43b6`, base `441ead77`
  - sourcekit-lsp @ `cb2881c5`, base `045c18e9`
  - swift-argument-parser @ `8f5916c0`, base `1021ac8c`
  - swift-async-algorithms @ `a523c60f`, base `789dcf1f`
  - swift-build @ `59372bbc`, base `f4685a11`
  - swift-certificates @ `919d6a32`, base `ff86b924`
  - swift-corelibs-xctest @ `80a3f954`, base `80a3f954` (no commits beyond the merge base yet)
  - swift-docc @ `ad021e35`, base `f37d9a7f`
  - swift-driver @ `ddb51ccd`, base `15cf6766`
  - swift-foundation @ `ef3c5667` (branch `no-darwin`), base `6669273a`
  - swift-llbuild @ `f7a0650b`, base `54a6aca5`
  - swift-log @ `280180f9`, base `9c9acde6`
  - swift-nio @ `e1623fbf`, base `feaf4ac5`
  - swift-package-manager @ `dbe05ec1`, base `24a8a7b0`
  - swift-sdk-generator @ `5956672b`, base `73612f74`
  - swift-subprocess @ `d6b58669`, base `8f099c6e`
  - swift-syntax @ `ec1d660b`, base `e9289aa4`
  - swift-tools-protocols @ `18e8a9f9`, base `07d2884f`
  - swift-tools-support-core @ `1ad4129f`, base `c574915f`

# 1. API

Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF=main`, `HEAD_REF=HEAD`); its links point into that run's API-DELTA.md.

## Summary

- **3187 added, 0 removed, 0 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2603 (448 → 3051 public symbols).
  - SystemSockets: +584 (0 → 584 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 3149
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 2
  - System 1.7.0: 2
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 1019 compiled only on other platforms;
  - 239 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 5 declarations the scan couldn't classify; see the list below.
  - 29 added, removed or changed graph symbols the scan didn't find (enum case: 28, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2921 / -0 declarations, which is the graphs' +2603 plus 313 implicit ones; explicit declarations it has that the graphs don't: `_opaque_pthread_cond_t.initializer`, `_opaque_pthread_mutex_t.errorCheckingInitializer`, `_opaque_pthread_mutex_t.initializer`, `_opaque_pthread_mutex_t.recursiveInitializer`, `_opaque_pthread_rwlock_t.initializer`; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
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
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 74 | 0 | 0 | S199 ×74 |
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
| **Total** | | **3187** | **0** | **0** | |

## ABI: exported symbols

What each module's release build exports, at `main` (`1b452c29`) → HEAD (`79ee4f78`), beside the API points above: `nm`'s external symbols in the objects of `swift build -c release`, built from an export of the commit. Every public property exports a property descriptor, `@_alwaysEmitIntoClient` or not (the SDK's System does too), so the descriptors grow with the API. *Code* is functions and accessors, what `@_alwaysEmitIntoClient` leaves to the client: of *public* declarations, in the symbol graphs, and *other*, which the graphs don't show (`@usableFromInline` internals, synthesized Equatable and Hashable members, deinitializers, stored properties' initial values).

| Module | Exported | Property descriptors | Conformances | Types | Code, public | Code, other |
|---|---:|---:|---:|---:|---:|---:|
| SystemPackage | 830 → 4848 | 406 → 2124 | 167 → 803 | 90 → 640 | 118 → 508 | 49 → 773 |
| SystemSockets | — → 901 | — → 336 | — → 139 | — → 132 | — → 188 | — → 106 |

### Candidates for `@_alwaysEmitIntoClient`

Of the 342 declarations added since `main` that export code, 39 only forward a C header value (SystemSockets 39): a *constant* is a static member that reads a C macro or enumerator, a *raw value* an initializer that stores one (or its getter), and an *accessor* an instance member that reads a C struct's field or tests a C constant, through conversions at most. With `@_alwaysEmitIntoClient`, the client would compile that code; a property keeps its descriptor. The other declarations' code is stored properties' accessors and code that does more than forward.

| Module | Declaration | Forwards | Exports | Where |
|---|---|---|---|---|
| SystemSockets | `SocketAddress.ResolutionFlags.init(rawValue:)` | raw value | initializer | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:90` |
| SystemSockets | `SocketAddress.ResolutionFlags.passive` | constant `AI_PASSIVE` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:97` |
| SystemSockets | `SocketAddress.ResolutionFlags.canonicalName` | constant `AI_CANONNAME` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:102` |
| SystemSockets | `SocketAddress.ResolutionFlags.numericHost` | constant `AI_NUMERICHOST` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:107` |
| SystemSockets | `SocketAddress.ResolutionFlags.numericService` | constant `AI_NUMERICSERV` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:112` |
| SystemSockets | `SocketAddress.ResolutionFlags.v4Mapped` | constant `AI_V4MAPPED` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:117` |
| SystemSockets | `SocketAddress.ResolutionFlags.all` | constant `AI_ALL` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:122` |
| SystemSockets | `SocketAddress.ResolutionFlags.addressConfigured` | constant `AI_ADDRCONFIG` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:127` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.init(rawValue:)` | raw value | initializer | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:264` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.numericHost` | constant `NI_NUMERICHOST` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:271` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.numericService` | constant `NI_NUMERICSERV` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:276` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.datagram` | constant `NI_DGRAM` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:281` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.noFullyQualified` | constant `NI_NOFQDN` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:286` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.nameRequired` | constant `NI_NAMEREQD` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:291` |
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.level` | accessor `cmsg_level` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:526` |
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.type` | accessor `cmsg_type` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:533` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.state` | accessor `tcpi_state` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:322` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.options` | accessor `tcpi_options` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:327` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendWindowScale` | accessor `tcpi_snd_wscale` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:334` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.receiveWindowScale` | accessor `tcpi_rcv_wscale` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:339` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.isRecoveringFromLoss` | accessor `tcpi_flags`, `TCPCI_FLAG_LOSSRECOVERY` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:344` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.hasDetectedReordering` | accessor `tcpi_flags`, `TCPCI_FLAG_REORDERING_DETECTED` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:351` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.maximumSegmentSize` | accessor `tcpi_maxseg` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:358` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendSlowStartThreshold` | accessor `tcpi_snd_ssthresh` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:363` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendCongestionWindow` | accessor `tcpi_snd_cwnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:368` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendWindow` | accessor `tcpi_snd_wnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:373` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendBufferedBytes` | accessor `tcpi_snd_sbbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:379` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.receiveWindow` | accessor `tcpi_rcv_wnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:384` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsSent` | accessor `tcpi_txpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:389` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesSent` | accessor `tcpi_txbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:394` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsRetransmitted` | accessor `tcpi_txretransmitpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:399` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesRetransmitted` | accessor `tcpi_txretransmitbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:404` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsReceived` | accessor `tcpi_rxpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:409` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesReceived` | accessor `tcpi_rxbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:414` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesReceivedOutOfOrder` | accessor `tcpi_rxoutoforderbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:419` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.retransmitTimeout` | accessor `tcpi_rto` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:431` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.roundTripTime` | accessor `tcpi_rttcur` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:436` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.smoothedRoundTripTime` | accessor `tcpi_srtt` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:441` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.roundTripTimeVariance` | accessor `tcpi_rttvar` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:446` |

# 2. Adoption

Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or `import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration (`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under `#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. *Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.

| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | Through a re-export (copied) | Markers (files) |
|---|---:|---:|---:|---:|---:|---:|---:|
| WasmKit | 333 | 16 → 0 | 0 | 0 → 1 | 0 | — | 0 (0) → 1 (1) |
| indexstore-db | 73 | 1 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| sourcekit-lsp | 444 | 8 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-argument-parser | 166 | 1 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-async-algorithms | 146 | 2 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-build | 1058 | 2 → 0 | 1 → 0 | 0 → 6 | 0 | — | 0 (0) → 11 (9) |
| swift-certificates | 133 | 2 → 0 | 0 | 0 | 0 | 3 → 0 | 0 (0) |
| swift-corelibs-xctest | 34 | 1 | 0 | 0 | 0 | — | 0 (0) |
| swift-docc | 888 | 3 → 0 | 1 → 0 | 0 → 1 | 0 | — | 0 (0) → 1 (1) |
| swift-driver | 195 | 11 → 0 | 1 → 0 | 0 | 0 | — | 0 (0) |
| swift-foundation | 431 | 33 → 0 | 1 → 0 | 0 | 3 | 7 → 0 | 0 (0) → 3 (2) |
| swift-llbuild | 19 | 0 | 5 → 0 | 0 | 0 | — | 0 (0) |
| swift-log | 30 | 5 → 0 | 0 | 0 | 0 | 1 → 0 | 0 (0) |
| swift-nio | 479 | 41 → 0 | 3 → 0 | 0 | 0 | — | 0 (0) |
| swift-package-manager | 883 | 3 → 0 | 2 → 0 | 0 | 0 | — | 0 (0) |
| swift-sdk-generator | 73 | 2 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-subprocess | 36 | 17 → 0 | 0 | 0 → 1 | 0 | — | 0 (0) → 2 (2) |
| swift-syntax | 586 | 2 → 0 | 0 | 0 → 1 | 0 | 3 → 0 | 0 (0) → 2 (1) |
| swift-tools-protocols | 232 | 2 → 0 | 0 | 0 | 0 | — | 0 (0) |
| swift-tools-support-core | 124 | 0 | 1 → 0 | 0 → 2 | 0 | 14 → 5 | 0 (0) → 2 (2) |
| **All** | 6363 | 152 → 1 | 16 → 0 | 0 → 12 | 3 | | 0 (0) → 22 (18) |

Files whose imports aren't narrow yet: swift-corelibs-xctest: `Sources/XCTest/Public/XCTestMain.swift` (whole module).

## Copied from the packages' reports

Verbatim, not rerun: each package's own test totals (at the start, and the latest it reports), and the rows behind the re-export column. Line numbers are 1-based, in the file at the package's commit above.

**WasmKit**

- No MIGRATION.md or REPORT.md with test totals at this commit.

**indexstore-db**

- MIGRATION.md, tests (lines 51, 52, 53, 54, 55, 56):

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

- MIGRATION.md, tests (lines 90, 92, 93):

  ```text
  | | Swift Testing | XCTest |
  | Before (unmodified clone) | 572 tests in 57 suites, all passed | 0 |
  | After | 572 tests in 57 suites, all passed | 0 |
  ```

- MIGRATION.md, re-exports (lines 12, 15):

  ```text
  | | At start | Now |
  | Darwin reached through a re-export | 1 (`Utilities/Mutex.swift`: `internal import os`, for `os_unfair_lock`, which the macOS 26 SDK puts in `Darwin.os.lock`) | 0 |
  ```

**swift-async-algorithms**

- MIGRATION.md, tests (lines 82, 84, 85):

  ```text
  | | XCTest | Swift Testing |
  | Before (unmodified clone) | 358 tests, 0 failures | 0 |
  | After | 358 tests, 0 failures | 0 |
  ```

- MIGRATION.md, re-exports (lines 13, 16):

  ```text
  | | At start | Now |
  | Darwin names reached through Foundation's or XCTest's re-export | 1: `Performance/ThroughputMeasurement.swift` (`usleep`, `USEC_PER_SEC`) | 0 |
  ```

**swift-build**

- No MIGRATION.md or REPORT.md with test totals at this commit.

**swift-certificates**

- MIGRATION.md, tests (lines 97, 99, 100):

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

- MIGRATION.md, tests (lines 100, 102, 103):

  ```text
  | | Swift Testing | XCTest |
  | Before (unmodified clone) | 170 tests in 16 suites, all passed | 0 |
  | After | 170 tests in 16 suites, all passed | 0 |
  ```

- MIGRATION.md, re-exports (lines 14, 17):

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

- MIGRATION.md, tests (lines 210, 212, 213):

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

Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: 22 markers in 18 files, of which 0 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `79ee4f78`:

- **missing**: System documents none of it (or only some: *k of n*), and `mapping.ini` has no answer outside System for it.
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry speaks for it; read the marker.
- **standard library**: System doesn't name it, and its entry in `mapping.ini` gives the standard library's answer (`swift`), shown with the entry's name.
- **not System's**: System doesn't name it, and its entry in `mapping.ini` is marked `wrap = no`: another module's or library's interface, such as the MachO module's file format, which System doesn't wrap.

The last two are answers outside System, read from `mapping.ini` at System's commit as the Darwin queue of `ecosystem.sh report` reads them; they aren't in the work list below.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 12 covered, 7 standard library, 25 not System's, 44 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | `load_command` | not System's ([Mach-O file format]) | 3 | swift-build | Mach-O |
| 2 | `OSStatus` | standard library ([MacTypes]: Int32 for OSStatus, UInt16 for UniChar, and Bool for DarwinBoolean and Boolean) | 2 | swift-build | MacTypes |
| 3 | `segment_command` | not System's ([Mach-O file format]) | 2 | swift-build | Mach-O file structures |
| 4 | `_dyld_image_count` | covered (doc comment) | 1 | swift-foundation | _dyld_image_count |
| 5 | `abort` | standard library ([termination]: fatalError(_:file:line:)) | 1 | swift-build | abort |
| 6 | adding a file action to C file actions | covered (doc comment) | 1 | swift-subprocess | posix_spawn |
| 7 | `AR_EFMT1` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 8 | `ar_hdr` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 9 | `ar_size` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 10 | `build_version_command` | not System's ([Mach-O file format]) | 1 | swift-build | build_version_command |
| 11 | C-string arguments for the C-values spawns | covered (by ProcessID.spawn's C-array forms with C values) | 1 | swift-subprocess | C-string arguments for the C-values spawns |
| 12 | `dirent` | covered (doc comment) | 1 | swift-tools-support-core | dirent |
| 13 | `dlerror` | covered (doc comment) | 1 | swift-tools-support-core | dynamic loader |
| 14 | dlopen in the caller's image | covered (doc comment) | 1 | swift-build | dynamic loader |
| 15 | `dylib` | not System's ([Mach-O file format]) | 1 | swift-build | dylib |
| 16 | `dylib_command` | not System's ([Mach-O file format]) | 1 | swift-build | dylib_command |
| 17 | `DynamicLibrary` | covered (by DynamicLibrary) | 1 | swift-foundation | DynamicLibrary |
| 18 | `fat_arch` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch |
| 19 | `fat_arch_64` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch_64 |
| 20 | `FAT_CIGAM` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 21 | `FAT_CIGAM_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 22 | `fat_header` | not System's ([Mach-O file format]) | 1 | swift-build | fat_header |
| 23 | `LC_MAIN` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 24 | `LC_SEGMENT` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 25 | `LC_SEGMENT_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 26 | `LC_SYMTAB` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 27 | `mach_header` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header |
| 28 | `mach_header_64` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header_64 |
| 29 | `macho_arch_name_for_cpu_type` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 30 | `macho_arch_name_for_mach_header` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 31 | `macho_cpu_type_for_arch_name` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 32 | `memcmp` | covered (doc comment) | 1 | swift-syntax | string.h |
| 33 | `off_t` | covered (doc comment) | 1 | swift-build | off_t |
| 34 | `PIPE_BUF` | covered (doc comment) | 1 | swift-docc | limits.h |
| 35 | `POSIXErrorCode` | covered (doc comment) | 1 | swift-foundation | POSIXErrorCode |
| 36 | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro | covered (doc comment) | 1 | WasmKit | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro |
| 37 | `rpath_command` | not System's ([Mach-O file format]) | 1 | swift-build | rpath_command |
| 38 | `SARMAG` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 39 | `section` | not System's ([Mach-O file format]) | 1 | swift-build | section |
| 40 | `section_64` | not System's ([Mach-O file format]) | 1 | swift-build | section_64 |
| 41 | `segment_command_64` | not System's ([Mach-O file format]) | 1 | swift-build | segment_command_64 |
| 42 | `uuid_command` | not System's ([Mach-O file format]) | 1 | swift-build | uuid_command |
| 43 | `version_min_command` | not System's ([Mach-O file format]) | 1 | swift-build | version_min_command |
| 44 | `vm_prot_t` | standard library ([C scalar types]: Int, UInt, Int64, UInt8 ... and Swift's C type aliases (CInt, CChar, CLong ...), and …) | 1 | swift-build | Mach virtual memory |

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
- `OSStatus` (standard library): swift-build: `Sources/SWBUtil/Error.swift:21`; swift-build: `Sources/SWBUtil/PbxCp.swift:22`
- `segment_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`; swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `_dyld_image_count` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:69`
- `abort` (standard library): swift-build: `Sources/SwiftBuild/SWBBuildServiceConnection.swift:23`
- adding a file action to C file actions (covered): swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `AR_EFMT1` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `ar_hdr` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `ar_size` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `build_version_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- C-string arguments for the C-values spawns (covered): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:618`
- `dirent` (covered): swift-tools-support-core: `Sources/TSCBasic/FileSystem.swift:19`
- `dlerror` (covered): swift-tools-support-core: `Sources/TSCUtility/dlopen.swift:20`
- dlopen in the caller's image (covered): swift-build: `Sources/SWBUtil/Library.swift:19`
- `dylib` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `dylib_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `DynamicLibrary` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`
- `fat_arch` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fat_arch_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `FAT_CIGAM` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `FAT_CIGAM_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `fat_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `LC_MAIN` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SYMTAB` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `mach_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `mach_header_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `macho_arch_name_for_cpu_type` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `macho_arch_name_for_mach_header` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `macho_cpu_type_for_arch_name` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `memcmp` (covered): swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:15`; swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:28`
- `off_t` (covered): swift-build: `Sources/SWBUtil/SWBDispatch.swift:22`
- `PIPE_BUF` (covered): swift-docc: `Sources/SwiftDocC/Infrastructure/External Data/OutOfProcessReferenceResolver.swift:16`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:20`
- readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:7`
- `rpath_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `SARMAG` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `section` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `section_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `segment_command_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `uuid_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `version_min_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `vm_prot_t` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:69`

</details>

# 4. Platform imports

The goal: no library of the repositories that swift's update-checkout clones for the main scheme imports a platform C module (Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT, visualc) in any form, on any platform. Each repository is read at its migrated clone in `../adopters`, on its newest migration branch (the first of migrate-all, migrate-unix, migrate-darwin that it has; swift-foundation: migrate-unix or no-darwin), else at its clone in `../ecosystem` as it is, else it's *not cloned*. Left out: swift (the compiler, the runtime, and the platform modules' own overlays); swift-system (System itself, whose imports are what it wraps). A platform's count is the library files whose build for that platform compiles an import of one of the modules, with each `#if` evaluated for it by adopter-coverage's `platforms.py`: an `import Glibc` under `#elseif canImport(Glibc)`, after a branch that Linux takes, counts for FreeBSD and OpenBSD but not for Linux. *Maybe*: files counted because a flag the scan can't read (a trait, a build setting) decides whether the import compiles. *Lexical* counts each import in any branch, compiled or not, as the tracker did before: for a platform, the files that import its own modules (Darwin: Darwin; Linux (glibc): Glibc; Musl: Musl; Android: Android, Bionic; WASI: WASILibc; FreeBSD: Glibc; OpenBSD: Glibc; Windows: ucrt, WinSDK, CRT, visualc). Kinds are by path (see [How this is computed](#how-this-is-computed)): *library* is under `Sources` (or `src`, `lib`, `products`), *tests* under a test directory, *other* the rest (benchmarks, examples, tools, plugins, docs, utilities), and a *nested package* is under a directory with its own `Package.swift`; the last three are counted lexically only.

| Platform | Library files that import one | Repositories | Library files, lexical |
|---|---:|---:|---:|
| Darwin | 22 | 8 | 25 |
| Linux (glibc) | 83 (5 maybe) | 20 | 124 |
| Musl | 74 (4 maybe) | 17 | 74 |
| Android | 94 (5 maybe) | 18 | 94 |
| WASI | 56 (3 maybe) | 6 | 56 |
| FreeBSD | 119 (6 maybe) | 20 | 124 |
| OpenBSD | 119 (6 maybe) | 20 | 124 |
| Windows | 184 (4 maybe) | 21 | 184 |
| **Any** | 241 | 25 | 243 |

| Repository | Read at | Library, lexical | Darwin | Linux | Musl | Android | WASI | FreeBSD | OpenBSD | Windows | Tests | Other | Nested packages |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| boringssl | not cloned | | | | | | | | | | | | |
| brotli | not cloned | | | | | | | | | | | | |
| cmake | not cloned | | | | | | | | | | | | |
| cmark | `../ecosystem/cmark` @ `0c8947bb` | — | — | — | — | — | — | — | — | — | — | — | — |
| curl | not cloned | | | | | | | | | | | | |
| indexstore-db | `../adopters/indexstore-db` `migrate-all` @ `96d2a952` | 4 | — | — | — | — | — | — | — | 4 | — | — | — |
| libxml2 | not cloned | | | | | | | | | | | | |
| llbuild | `../adopters/swift-llbuild` `migrate-unix` @ `f7a0650b` | 5 | — | 5 | 5 | 5 | — | 5 | 5 | 5 | 2 | — | — |
| llvm-project | not cloned | | | | | | | | | | | | |
| mimalloc | not cloned | | | | | | | | | | | | |
| ninja | not cloned | | | | | | | | | | | | |
| sourcekit-lsp | `../adopters/sourcekit-lsp` `migrate-darwin` @ `cb2881c5` | 16 | — | 9 | 9 | 11 | — | 9 | 9 | 14 | 3 | — | — |
| swift-argument-parser | `../adopters/swift-argument-parser` `migrate-all` @ `22831ad7` | 2 | — | — | — | — | — | — | — | 2 | — | — | — |
| swift-asn1 | `../ecosystem/swift-asn1` @ `a54383ad` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-async-algorithms | `../adopters/swift-async-algorithms` `migrate-all` @ `b9ff7c2f` | 1 | — | 1 | 1 | 1 | — | 1 | 1 | 1 | — | — | — |
| swift-atomics | `../ecosystem/swift-atomics` @ `0442cb5a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-build | `../adopters/swift-build` `migrate-darwin` @ `59372bbc` | 15 | 6 | 1 | 1 | 1 | — | 1 | 1 | 9 | 2 | — | — |
| swift-certificates | `../adopters/swift-certificates` `migrate-all` @ `7d492a42` | 3 | — | 1 | 1 | 1 | 1 | 1 | 1 | 3 | — | — | — |
| swift-collections | `../ecosystem/swift-collections` @ `c11818f3` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-corelibs-blocksruntime | not cloned | | | | | | | | | | | | |
| swift-corelibs-foundation | `../ecosystem/swift-corelibs-foundation` @ `6f21ccf1` | 25 | 9 | 11 | 7 | 19 | 6 | 11 | 11 | 19 | 7 | — | — |
| swift-corelibs-libdispatch | not cloned | | | | | | | | | | | | |
| swift-corelibs-xctest | `../adopters/swift-corelibs-xctest` `migrate-darwin` @ `80a3f954` | 1 | 1 | 1 | — | — | — | 1 | 1 | — | — | — | — |
| swift-crypto | `../ecosystem/swift-crypto` @ `d79c573e` | 2 | — | — | — | 2 (1 maybe) | — | — | — | 1 | — | — | — |
| swift-docc | `../adopters/swift-docc` `migrate-darwin` @ `ad021e35` | 5 | 1 | 1 | 1 | — | — | 1 | 1 | 4 | 2 | — | — |
| swift-docc-render-artifact | not cloned | | | | | | | | | | | | |
| swift-docc-symbolkit | `../ecosystem/swift-docc-symbolkit` @ `e9a4c0f2` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-driver | `../adopters/swift-driver` `migrate-unix` @ `ddb51ccd` | 8 | — | 6 | 6 | 6 | — | 6 | 6 | 7 | 5 | — | — |
| swift-experimental-string-processing | `../ecosystem/swift-experimental-string-processing` @ `db4678c7` | 1 | 1 | 1 | — | — | — | 1 | 1 | — | — | — | — |
| swift-format | `../ecosystem/swift-format` @ `b15dd59f` | 3 | — | — | — | 1 | — | — | — | 2 | — | — | — |
| swift-foundation | `../adopters/swift-foundation` `migrate-unix` @ `83bde529` | 31 | — | 9 | 9 | 9 | 21 | 23 | 23 | 27 | 7 | — | 2 |
| swift-foundation-icu | `../ecosystem/swift-foundation-icu` @ `e8538d25` | — | — | — | — | — | — | — | — | — | — | — | 1 |
| swift-installer-scripts | not cloned | | | | | | | | | | | | |
| swift-integration-tests | not cloned | | | | | | | | | | | | |
| swift-llvm-bindings | `../ecosystem/swift-llvm-bindings` @ `c1fffb92` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-lmdb | `../ecosystem/swift-lmdb` @ `866bc256` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-log | `../adopters/swift-log` `migrate-all` @ `afe82828` | 3 | — | 1 | 1 | 1 | 3 | 1 | 1 | 3 | 3 | — | — |
| swift-markdown | `../ecosystem/swift-markdown` @ `392b73b8` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-nio | `../adopters/swift-nio` `migrate-unix` @ `d486207c` | 50 | — | 5 | 5 | 4 | 17 | 29 | 29 | 34 | 19 | — | 2 |
| swift-numerics | `../ecosystem/swift-numerics` @ `0a5bc040` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-sdk-generator | `../adopters/swift-sdk-generator` `migrate-unix` @ `5956672b` | 1 | — | 1 | — | — | — | 1 | 1 | — | 1 | — | — |
| swift-stress-tester | not cloned | | | | | | | | | | | | |
| swift-subprocess | `../adopters/swift-subprocess` `migrate-unix` @ `d6b58669` | 16 | — | 11 (1 maybe) | 10 | 10 | — | 10 (2 maybe) | 10 (2 maybe) | 10 | 10 | — | — |
| swift-syntax | `../adopters/swift-syntax` `migrate-all` @ `c222965d` | 1 | 1 | 1 | 1 | 1 | — | 1 | 1 | — | — | 1 | 2 |
| swift-testing | `../ecosystem/swift-testing` @ `ea850751` | 10 | — | — | — | — | — | — | — | 10 (1 maybe) | 1 | — | — |
| swift-toolchain-sarif | `../ecosystem/swift-toolchain-sarif` @ `d611f23a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-toolchain-sqlite | `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-tools-protocols | `../adopters/swift-tools-protocols` `migrate-unix` @ `18e8a9f9` | 3 | — | 1 | 1 | 1 | — | 1 | 1 | 3 | 2 | — | — |
| swift-tools-support-core | `../adopters/swift-tools-support-core` `migrate-unix` @ `1ad4129f` | 8 | 2 | 1 | 1 | 1 | — | 1 | 1 | 6 | — | — | — |
| swift-xcode-playground-support | not cloned | | | | | | | | | | | | |
| swiftpm | `../adopters/swift-package-manager` `migrate-unix` @ `dbe05ec1` | 15 | — | 4 | 3 | 10 | — | 4 | 4 | 11 | — | — | 1 |
| wasi-libc | not cloned | | | | | | | | | | | | |
| wasmkit | `../adopters/WasmKit` `migrate-unix` @ `4917e060` | 14 | 1 | 12 (4 maybe) | 12 (4 maybe) | 10 (4 maybe) | 8 (3 maybe) | 11 (4 maybe) | 11 (4 maybe) | 9 (3 maybe) | 3 | — | 1 |
| zlib | not cloned | | | | | | | | | | | | |

37 repositories read; 25 compile an import of a platform module in library code on some platform: indexstore-db, llbuild, sourcekit-lsp, swift-argument-parser, swift-async-algorithms, swift-build, swift-certificates, swift-corelibs-foundation, swift-corelibs-xctest, swift-crypto, swift-docc, swift-driver, swift-experimental-string-processing, swift-format, swift-foundation, swift-log, swift-nio, swift-sdk-generator, swift-subprocess, swift-syntax, swift-testing, swift-tools-protocols, swift-tools-support-core, swiftpm, wasmkit.

All repositories, files by module and kind, lexically:

| Module | Library | Tests | Other | Nested packages | All |
|---|---:|---:|---:|---:|---:|
| Darwin | 25 | 3 | 1 | 5 | 34 |
| Glibc | 124 | 31 | 0 | 6 | 161 |
| Musl | 74 | 16 | 0 | 2 | 92 |
| Bionic | 33 | 6 | 0 | 0 | 39 |
| Android | 62 | 19 | 0 | 1 | 82 |
| WASILibc | 56 | 5 | 0 | 1 | 62 |
| ucrt | 38 | 9 | 0 | 1 | 48 |
| WinSDK | 157 | 35 | 0 | 2 | 194 |
| CRT | 35 | 12 | 0 | 0 | 47 |
| visualc | 0 | 0 | 0 | 0 | 0 |
| **Any** | 243 | 67 | 1 | 9 | 320 |

# How this is computed

`Utilities/adopter-coverage/status.sh` makes this file from commits, with git and the existing tools, and no
reading of reports for meaning. It takes about as long as api-delta and a release build when System's sources
have changed since their last runs, and a few seconds when they haven't.

- **API** is api-delta's own report (`BASE_REF=main HEAD_REF=HEAD`), its Summary and *By area* table copied
  verbatim. api-delta reruns only when `Sources/`, `Package.swift` or the tool changed since its last run.
- **ABI symbols** are the external symbols, less the private externs, that `nm` finds in each module's objects
  from `swift build -c release`, built from a `git archive` export of HEAD and of api-delta's base commit, with
  the manifest patched as api-delta patches it (no Samples, so no network). A result is cached by the commit's
  `Sources` and `Package.swift` trees, so only a change to either rebuilds. Each symbol is sorted by its demangled
  form into property descriptors, conformances (descriptors and witness tables), types (metadata and
  descriptors) and code (functions, accessors, initial values). Code is *public* when it belongs to a
  declaration in api-delta's symbol graphs, by USR: a function's symbol is its USR's mangling, and a property's
  accessors replace the USR's `vp` with `vg`, `vs`, `vM` and the like. A *candidate* is an added declaration
  that exports code and whose body, on the lines the macOS release build compiles, is one expression (a getter
  and a setter for a property; for an initializer, stores into `rawValue` or a delegation to
  `init(rawValue:)`) that calls nothing but conversions (a type's initializer, `numericCast`, Duration's unit
  factories) and reads a C name: an all-caps macro or enumerator or System's `_`-prefixed accessor for one, or a
  snake_case field, which System's own names never are. Rejected: swift-api-digester's ABI mode (`-dump-sdk
  -abi`), which lists declarations, not what a build exports (no property descriptors, conformances or
  metadata, and an `@_alwaysEmitIntoClient` function that exports nothing); and a library-evolution build, as
  the SDK's is, which a check exported nearly the same set from (REPORT.md section 50).
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
- **Platform imports** (section 4) are found as ecosystem.py's survey finds them: each Swift file, with comments
  and string literals blanked, is matched against the survey's import pattern (`import_of` in
  `scripts/ecosystem.py`), widened to Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT and visualc,
  in every form: the whole module, a submodule, one declaration, with `@_exported` or another attribute, and with
  an access modifier. Then each `#if` is evaluated for each platform family by adopter-coverage's `platforms.py`
  (Darwin is macOS; Linux is glibc; Musl, Android, WASI, FreeBSD, OpenBSD and Windows as its environments
  describe them), with FOUNDATION_FRAMEWORK false, as in the Adoption section, and a library file counts for a
  platform when an import of any of the modules is on a line that platform's build compiles. `canImport` finds
  the platform's own modules and the cross-platform ones `platforms.py` lists, not the package's own or its
  dependencies' (no manifest is read); an unknown flag or trait is *maybe*, counted, and so is every import in a
  file whose conditions don't parse. The lexical count, every import in any branch, stands beside it: per
  repository, the library files that import any of the modules; per platform, those that import the platform's
  own modules (Glibc for Linux, FreeBSD and OpenBSD). Each repository of `scheme-main.tsv` is read at a commit:
  its migrated clone's newest migration branch (the first of `--platform-branches` it has, by default
  migrate-all, migrate-unix, migrate-darwin; `--platform-branches-for` gives a package its own list:
  swift-foundation's migrate-unix, else no-darwin), else the ecosystem clone's HEAD. A file's kind is by its path:
  in a nested package if a directory above it, below the root, has a `Package.swift`; else tests if a directory
  in its path is a test directory (`Tests`, `IntegrationTests`, `Fixtures`, `unittests` and the like); else
  library under a top-level `Sources`, `Source`, `src`, `srcs`, `lib` or `products`, outside a `.docc` catalog;
  else other. Only library files are evaluated. Rejected: the manifests' targets, as the Adoption section uses
  them, which needs every clone's manifest evaluated (swift-foundation's needs a newer compiler than 6.2) and says
  nothing of nested packages, so a target that a manifest builds only for some platforms counts wherever its
  `#if`s let it; and the lexical count alone, which counts an `import Glibc` under `#elseif canImport(Glibc)`,
  after a branch that Linux takes, as Linux's.
