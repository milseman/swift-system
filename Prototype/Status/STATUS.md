# Status: System's API and its adopters

Generated 2026-10-05 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `ledger` @ `6fe0d806` (Utilities/adopter-coverage: the ledger's gap ranking gives the files each gap's unblocked sites are in), which contains `system-next` @ `a3dbd4ec` (Merge branch 'verify' into system-next); 3 commit(s) of `ledger` aren't in `system-next`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `d3aac7dc` (api-delta's last run; nothing it reads has changed since).
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

- **3239 added, 0 removed, 1 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2655, 1 changed (448 → 3103 public symbols).
  - SystemSockets: +584 (0 → 584 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 3201
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
  - System 0.0.1: 2
  - System 1.7.0: 2
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 1539 compiled only on other platforms;
  - 244 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 5 declarations the scan couldn't classify; see the list below.
  - 29 added, removed or changed graph symbols the scan didn't find (enum case: 28, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +2976 / -1 declarations, which is the graphs' +2655 plus 315 implicit ones; explicit declarations it has that the graphs don't: `FileDescriptor.close()`, `_opaque_pthread_cond_t.initializer`, `_opaque_pthread_mutex_t.errorCheckingInitializer`, `_opaque_pthread_mutex_t.initializer`, `_opaque_pthread_mutex_t.recursiveInitializer`, `_opaque_pthread_rwlock_t.initializer`; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +657 / -0 declarations, which is the graphs' +584 plus 72 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- 0 removed and 1 changed in the graphs, and 0 removed among the declarations the graphs can't see. The full list below gives the first kind, and section 5 the second. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 48 | 0 | 0 | S199 ×48 |
| SystemPackage | [`CLocale`](#systempackage-clocale) | 53 | 0 | 0 | S199 ×53 |
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
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 247 | 0 | 1 | S199 ×234, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 449 | 0 | 0 | S199 ×435, S199+OS ×14 |
| SystemPackage | [`FilePermissions`](#systempackage-filepermissions) | 1 | 0 | 0 | S199 ×1 |
| SystemPackage | [`FileStream`](#systempackage-filestream) | 37 | 0 | 0 | S199 ×37 |
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
| SystemPackage | [`ProcessID`](#systempackage-processid) | 225 | 0 | 0 | S199 ×225 |
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
| SystemPackage | [`rusage (extends _DarwinFoundation3)`](#systempackage-rusage-extends-darwinfoundation3) | 13 | 0 | 0 | S199 ×13 |
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
| **Total** | | **3239** | **0** | **1** | |

## ABI: exported symbols

What each module's release build exports, at `main` (`1b452c29`) → HEAD (`6fe0d806`), beside the API points above: `nm`'s external symbols in the objects of `swift build -c release`, built from an export of the commit. Every public property exports a property descriptor, `@_alwaysEmitIntoClient` or not (the SDK's System does too), so the descriptors grow with the API. *Code* is functions and accessors, what `@_alwaysEmitIntoClient` leaves to the client: of *public* declarations, in the symbol graphs, and *other*, which the graphs don't show (`@usableFromInline` internals, synthesized Equatable and Hashable members, deinitializers, stored properties' initial values).

| Module | Exported | Property descriptors | Conformances | Types | Code, public | Code, other |
|---|---:|---:|---:|---:|---:|---:|
| SystemPackage | 830 → 4901 | 406 → 2156 | 167 → 809 | 90 → 646 | 118 → 508 | 49 → 782 |
| SystemSockets | — → 901 | — → 336 | — → 139 | — → 132 | — → 188 | — → 106 |

### Candidates for `@_alwaysEmitIntoClient`

Of the 342 declarations added since `main` that export code, 39 only forward a C header value (SystemSockets 39): a *constant* is a static member that reads a C macro or enumerator, a *raw value* an initializer that stores one (or its getter), and an *accessor* an instance member that reads a C struct's field or tests a C constant, through conversions at most. With `@_alwaysEmitIntoClient`, the client would compile that code; a property keeps its descriptor. The other declarations' code is stored properties' accessors and code that does more than forward.

| Module | Declaration | Forwards | Exports | Where |
|---|---|---|---|---|
| SystemSockets | `SocketAddress.ResolutionFlags.init(rawValue:)` | raw value | initializer | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:92` |
| SystemSockets | `SocketAddress.ResolutionFlags.passive` | constant `AI_PASSIVE` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:99` |
| SystemSockets | `SocketAddress.ResolutionFlags.canonicalName` | constant `AI_CANONNAME` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:104` |
| SystemSockets | `SocketAddress.ResolutionFlags.numericHost` | constant `AI_NUMERICHOST` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:109` |
| SystemSockets | `SocketAddress.ResolutionFlags.numericService` | constant `AI_NUMERICSERV` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:114` |
| SystemSockets | `SocketAddress.ResolutionFlags.v4Mapped` | constant `AI_V4MAPPED` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:119` |
| SystemSockets | `SocketAddress.ResolutionFlags.all` | constant `AI_ALL` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:124` |
| SystemSockets | `SocketAddress.ResolutionFlags.addressConfigured` | constant `AI_ADDRCONFIG` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:129` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.init(rawValue:)` | raw value | initializer | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:266` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.numericHost` | constant `NI_NUMERICHOST` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:273` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.numericService` | constant `NI_NUMERICSERV` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:278` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.datagram` | constant `NI_DGRAM` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:283` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.noFullyQualified` | constant `NI_NOFQDN` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:288` |
| SystemSockets | `SocketAddress.ReverseResolutionFlags.nameRequired` | constant `NI_NAMEREQD` | getter | `Sources/SystemSockets/Sockets/SocketAddress+Resolution.swift:293` |
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.level` | accessor `cmsg_level` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:528` |
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.type` | accessor `cmsg_type` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:535` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.state` | accessor `tcpi_state` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:324` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.options` | accessor `tcpi_options` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:329` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendWindowScale` | accessor `tcpi_snd_wscale` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:336` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.receiveWindowScale` | accessor `tcpi_rcv_wscale` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:341` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.isRecoveringFromLoss` | accessor `tcpi_flags`, `TCPCI_FLAG_LOSSRECOVERY` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:346` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.hasDetectedReordering` | accessor `tcpi_flags`, `TCPCI_FLAG_REORDERING_DETECTED` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:353` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.maximumSegmentSize` | accessor `tcpi_maxseg` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:360` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendSlowStartThreshold` | accessor `tcpi_snd_ssthresh` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:365` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendCongestionWindow` | accessor `tcpi_snd_cwnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:370` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendWindow` | accessor `tcpi_snd_wnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:375` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.sendBufferedBytes` | accessor `tcpi_snd_sbbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:381` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.receiveWindow` | accessor `tcpi_rcv_wnd` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:386` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsSent` | accessor `tcpi_txpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:391` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesSent` | accessor `tcpi_txbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:396` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsRetransmitted` | accessor `tcpi_txretransmitpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:401` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesRetransmitted` | accessor `tcpi_txretransmitbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:406` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.packetsReceived` | accessor `tcpi_rxpackets` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:411` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesReceived` | accessor `tcpi_rxbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:416` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.bytesReceivedOutOfOrder` | accessor `tcpi_rxoutoforderbytes` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:421` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.retransmitTimeout` | accessor `tcpi_rto` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:433` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.roundTripTime` | accessor `tcpi_rttcur` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:438` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.smoothedRoundTripTime` | accessor `tcpi_srtt` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:443` |
| SystemSockets | `SocketDescriptor.TCPConnectionInfo.roundTripTimeVariance` | accessor `tcpi_rttvar` | getter | `Sources/SystemSockets/Sockets/SocketTCPInfo.swift:448` |

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

Every `SYSTEM-GAP:` marker in the packages' sources at each adopter's newest migration branch, the commit section 4 reads (WasmKit `migrate-unix` @ `fd06e2a3`, indexstore-db `migrate-all` @ `96d2a952`, sourcekit-lsp `migrate-all` @ `79583cc1`, swift-argument-parser `migrate-all` @ `22831ad7`, swift-async-algorithms `migrate-all` @ `d4ad19b0`, swift-build `migrate-all` @ `1dce162d`, swift-certificates `migrate-all` @ `c310582c`, swift-corelibs-xctest `migrate-darwin` @ `80a3f954`, swift-crypto `migrate-all` @ `ef1e59aa`, swift-docc `migrate-all` @ `4e6a5cea`, swift-driver `migrate-unix` @ `e7850bd0`, swift-foundation `migrate-unix` @ `d7589041`, swift-llbuild `migrate-unix` @ `314f1127`, swift-log `migrate-all` @ `7e49107b`, swift-nio `migrate-unix` @ `56deee84`, swift-package-manager `migrate-unix` @ `efff7333`, swift-sdk-generator `migrate-unix` @ `bc251e13`, swift-stress-tester `migrate-all` @ `e1702563`, swift-subprocess `migrate-unix` @ `661de35c`, swift-syntax `migrate-all` @ `e6918103`, swift-testing `migrate-all` @ `e2f8d449`, swift-tools-protocols `migrate-unix` @ `2b2c75dc`, swift-tools-support-core `migrate-unix` @ `5f85e38e`): 83 markers in 47 files, of which 1 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `6fe0d806`:

- **missing**: System documents none of it (or only some: *k of n*), and `mapping.ini` has no answer outside System for it.
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet. *Not yet in `system-next`* means only this branch has it.
- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry speaks for it; read the marker.
- **standard library**: System doesn't name it, and its entry in `mapping.ini` gives the standard library's answer (`swift`), shown with the entry's name.
- **not System's**: System doesn't name it, and its entry in `mapping.ini` is marked `wrap = no`: another module's or library's interface, such as the MachO module's file format, which System doesn't wrap.

The last two are answers outside System, read from `mapping.ini` at System's commit as the Darwin queue of `ecosystem.sh report` reads them; they aren't in the work list below.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 38 missing, 48 covered, 1 unread, 5 standard library, 25 not System's, 117 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | `remove` | covered (doc comment) | 4 | swift-testing | stdio.h |
| 2 | `free` | covered (doc comment) | 3 | swift-crypto, swift-testing | the C heap |
| 3 | `load_command` | not System's ([Mach-O file format]) | 3 | swift-build | Mach-O |
| 4 | `abort` | covered (doc comment) | 2 | swift-build, swift-testing | stdlib.h |
| 5 | `openpty` | covered (doc comment) | 2 | swift-build, swift-testing | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 6 | `EXIT_SUCCESS` | covered (doc comment) | 2 | swift-testing | stdlib.h |
| 7 | `memset_s` | covered (doc comment) | 2 | swift-crypto | string.h |
| 8 | `segment_command` | not System's ([Mach-O file format]) | 2 | swift-build | Mach-O file structures |
| 9 | `strlen` | covered (doc comment) | 2 | swift-testing | string.h |
| 10 | `wasip1` | missing | 2 | swift-async-algorithms | PThread.Mutex on WASI without threads |
| 11 | `which` | missing | 2 | swift-testing | which |
| 12 | `_dyld_image_count` | covered (doc comment) | 1 | swift-foundation | _dyld_image_count |
| 13 | `_NSGetExecutablePath` | covered (doc comment) | 1 | swift-testing | executable's path |
| 14 | adding a file action to C file actions | covered (doc comment) | 1 | swift-subprocess | posix_spawn |
| 15 | `addr` | missing | 1 | swift-build | their members |
| 16 | `AR_EFMT1` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 17 | `ar_hdr` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 18 | `ar_size` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 19 | `backtrace` | covered (doc comment) | 1 | swift-testing | execinfo.h |
| 20 | `backtrace_async` | missing | 1 | swift-testing | backtrace_async |
| 21 | `build_version_command` | not System's ([Mach-O file format]) | 1 | swift-build | build_version_command |
| 22 | C-string arguments for the C-values spawns | covered (by ProcessID.spawn's C-array forms with C values) | 1 | swift-subprocess | C-string arguments for the C-values spawns |
| 23 | `calloc` | covered (doc comment) | 1 | swift-testing | the C heap |
| 24 | `cmd` | missing | 1 | swift-build | their members |
| 25 | `cmdsize` | missing | 1 | swift-build | their members |
| 26 | `copy_file_range` | missing | 1 | swift-testing | file cloning |
| 27 | `cpusubtype` | missing | 1 | swift-build | their members |
| 28 | `cputype` | missing | 1 | swift-build | their members |
| 29 | `dlopen` | covered (doc comment) | 1 | swift-build | dynamic loader |
| 30 | `dlsym` | covered (doc comment) | 1 | swift-testing | dynamic loader |
| 31 | `dylib` | not System's ([Mach-O file format]) | 1 | swift-build | dylib |
| 32 | `dylib_command` | not System's ([Mach-O file format]) | 1 | swift-build | dylib_command |
| 33 | `DynamicLibrary` | covered (by DynamicLibrary) | 1 | swift-foundation | DynamicLibrary |
| 34 | `EX_UNAVAILABLE` | covered (doc comment) | 1 | swift-testing | sysexits |
| 35 | `EXIT_FAILURE` | covered (doc comment) | 1 | swift-testing | stdlib.h |
| 36 | `F_SETFD` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 37 | `fat_arch` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch |
| 38 | `fat_arch_64` | not System's ([Mach-O file format]) | 1 | swift-build | fat_arch_64 |
| 39 | `FAT_CIGAM` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 40 | `FAT_CIGAM_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 41 | `fat_header` | not System's ([Mach-O file format]) | 1 | swift-build | fat_header |
| 42 | `fclonefileat` | covered (doc comment) | 1 | swift-testing | sys/clonefile.h |
| 43 | `fcntl` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 44 | `FD_CLOEXEC` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 45 | `fflush` | covered (doc comment) | 1 | swift-log | fflush |
| 46 | `FICLONE` | covered (doc comment) | 1 | swift-testing | linux/fs.h |
| 47 | `fileoff` | missing | 1 | swift-build | their members |
| 48 | `filesize` | missing | 1 | swift-build | their members |
| 49 | `filetype` | missing | 1 | swift-build | their members |
| 50 | `fmemopen` | missing | 1 | swift-testing | C stdio (provisional) |
| 51 | `fopencookie` | missing | 1 | swift-testing | fopencookie |
| 52 | `funopen` | missing | 1 | swift-testing | C stdio (provisional) |
| 53 | `fwrite` | covered (doc comment) | 1 | swift-log | fwrite |
| 54 | `getc_unlocked` | missing | 1 | swift-testing | C stdio (provisional) |
| 55 | `getsectiondata` | missing | 1 | swift-testing | mach-o/getsect.h |
| 56 | `gnu_get_libc_version` | missing | 1 | swift-testing | gnu/libc-version.h |
| 57 | `images` | missing | 1 | swift-testing | Mach-O |
| 58 | `isatty` | covered (doc comment) | 1 | swift-testing | unistd.h |
| 59 | `KERN_PROC_PATHNAME` | missing | 1 | swift-testing | executable's path |
| 60 | `LC_MAIN` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 61 | `LC_SEGMENT` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 62 | `LC_SEGMENT_64` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 63 | `LC_SYMTAB` | not System's ([Mach-O file format]) | 1 | swift-build | constants |
| 64 | `mach_header` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header |
| 65 | `mach_header_64` | not System's ([Mach-O file format]) | 1 | swift-build | mach_header_64 |
| 66 | `macho_arch_name_for_cpu_type` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 67 | `macho_arch_name_for_mach_header` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 68 | `macho_cpu_type_for_arch_name` | not System's ([Mach-O architecture names]) | 1 | swift-build | mach-o/utils.h |
| 69 | `magic` | missing | 1 | swift-build | their members |
| 70 | `malloc` | covered (doc comment) | 1 | swift-crypto | the C heap |
| 71 | `memcmp` | covered (doc comment) | 1 | swift-crypto | string.h |
| 72 | `memmem` | missing | 1 | swift-testing | string.h and ctype.h (provisional) |
| 73 | `minos` | missing | 1 | swift-build | their members |
| 74 | `name` | covered (doc comment) | 1 | swift-build | their members |
| 75 | `NAME_MAX` | covered (doc comment) | 1 | swift-testing | compile-time limits |
| 76 | `nfat_arch` | missing | 1 | swift-build | their members |
| 77 | `offset` | covered (doc comment) | 1 | swift-build | their members |
| 78 | `path` | missing | 1 | swift-build | their members |
| 79 | `pipe2` | covered (doc comment) | 1 | swift-testing | unistd.h |
| 80 | `platform` | missing | 1 | swift-build | their members |
| 81 | `posix_spawn_file_actions_addclosefrom_np` | covered (doc comment) | 1 | swift-testing | posix_spawn |
| 82 | `POSIXErrorCode` | covered (doc comment) | 1 | swift-foundation | POSIXErrorCode |
| 83 | `pthread_create` | covered (doc comment) | 1 | swift-async-algorithms | pthread_create |
| 84 | `pthread_join` | covered (doc comment) | 1 | swift-async-algorithms | pthread_join |
| 85 | `pthread_mutex_t` | covered (doc comment) | 1 | swift-certificates | for `LockPrimitive`'s storage |
| 86 | `pthread_set_name_np` | missing | 1 | swift-testing | pthread.h |
| 87 | `pthread_t` | covered (doc comment) | 1 | swift-async-algorithms | pthread_t |
| 88 | `raise` | covered (doc comment) | 1 | swift-testing | signal.h |
| 89 | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro | covered (doc comment) | 1 | WasmKit | readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro |
| 90 | `realpath` | covered (doc comment) | 1 | swift-testing | stdlib.h |
| 91 | `rpath_command` | not System's ([Mach-O file format]) | 1 | swift-build | rpath_command |
| 92 | `SARMAG` | standard library ([ar archive header]: the header's fields, read from the archive's bytes: ar_hdr is 60 bytes of text (ar_name …) | 1 | swift-build | ar.h archive headers |
| 93 | `sdk` | missing | 1 | swift-build | their members |
| 94 | `section` | not System's ([Mach-O file format]) | 1 | swift-build | section |
| 95 | `section_64` | not System's ([Mach-O file format]) | 1 | swift-build | section_64 |
| 96 | `segment_command_64` | not System's ([Mach-O file format]) | 1 | swift-build | segment_command_64 |
| 97 | `sigabbrev_np` | missing | 1 | swift-testing | string.h |
| 98 | `SIGABRT` | covered (doc comment) | 1 | swift-testing | signal.h |
| 99 | `SIGSEGV` | covered (doc comment) | 1 | swift-testing | SIGSEGV |
| 100 | `size` | missing | 1 | swift-build | their members |
| 101 | stdlib.h and sysexits.h exit codes' C names | unread | 1 | swift-testing | stdlib.h and sysexits.h exit codes' C names |
| 102 | `strchr` | missing | 1 | swift-testing | string.h and ctype.h (provisional) |
| 103 | `strerror_r` | missing | 1 | swift-testing | string.h and ctype.h (provisional) |
| 104 | `strncmp` | covered (doc comment) | 1 | swift-testing | strncmp |
| 105 | `sys_signame` | missing | 1 | swift-testing | signal.h |
| 106 | `sysctl` | covered (doc comment) | 1 | swift-testing | executable's path |
| 107 | `task_set_exception_ports` | missing | 1 | swift-testing | mach/task.h |
| 108 | `timespec_get` | covered (doc comment) | 1 | swift-testing | time.h |
| 109 | `tmpfile` | missing | 1 | swift-testing | C stdio (provisional) |
| 110 | `usleep` | covered (as `nanosleep`) | 1 | swift-stress-tester | sleep |
| 111 | `uuid` | missing | 1 | swift-build | their members |
| 112 | `uuid_command` | not System's ([Mach-O file format]) | 1 | swift-build | uuid_command |
| 113 | `version` | covered (doc comment) | 1 | swift-build | their members |
| 114 | `version_min_command` | not System's ([Mach-O file format]) | 1 | swift-build | version_min_command |
| 115 | `vm_prot_t` | standard library ([C scalar types]: Int, UInt, Int64, UInt8 ... and Swift's C type aliases (CInt, CChar, CLong ...), and …) | 1 | swift-build | Mach virtual memory |
| 116 | `vmaddr` | missing | 1 | swift-build | their members |
| 117 | `vmsize` | missing | 1 | swift-build | their members |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|
| 1 | string.h and ctype.h (provisional) | 3 | swift-testing | `memmem`, `strchr`, `strerror_r` |
| 2 | C stdio (provisional) | 2 | swift-testing | `fmemopen`, `funopen`, `getc_unlocked`, `tmpfile` |
| 3 | PThread.Mutex on WASI without threads | 2 | swift-async-algorithms | `wasip1` |
| 4 | which | 2 | swift-testing | `which` |
| 5 | backtrace_async | 1 | swift-testing | `backtrace_async` |
| 6 | executable's path | 1 | swift-testing | `KERN_PROC_PATHNAME` |
| 7 | file cloning | 1 | swift-testing | `copy_file_range` |
| 8 | fopencookie | 1 | swift-testing | `fopencookie` |
| 9 | gnu/libc-version.h | 1 | swift-testing | `gnu_get_libc_version` |
| 10 | Mach-O | 1 | swift-testing | `images` |
| 11 | mach-o/getsect.h | 1 | swift-testing | `getsectiondata` |
| 12 | mach/task.h | 1 | swift-testing | `task_set_exception_ports` |
| 13 | pthread.h | 1 | swift-testing | `pthread_set_name_np` |
| 14 | signal.h | 1 | swift-testing | `sys_signame` |
| 15 | string.h | 1 | swift-testing | `sigabbrev_np` |
| 16 | their members | 1 | swift-build | `addr`, `cmd`, `cmdsize`, `cpusubtype`, `cputype`, `fileoff`, `filesize`, `filetype`, `magic`, `minos`, `nfat_arch`, `path`, `platform`, `sdk`, `size`, `uuid`, `vmaddr`, `vmsize` |

## Markers that name no C interface

- swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`: DynamicLibrary, in the framework build (not built here): dlopen with RTLD_NOLOAD \| RTLD_FIRST, dlsym and dlclose are system-next's DynamicLibrary(_:options: [.noLoad, .first]), address(of:), close() a
- swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:618`: C-string arguments for the C-values spawns. System's ProcessID.spawn with cFileActions: and cAttributes:, with or without credentials:, takes the arguments and environment only
- swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:122`: stdlib.h and sysexits.h exit codes' C names, such as

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- `remove` (covered): swift-testing: `Tests/TestingTests/AttachmentTests.swift:95`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:112`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:143`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:151`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:179`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:199`; swift-testing: `Tests/TestingTests/Support/ColorTests.swift:40`; swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:286`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:387`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:413`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:435`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:464`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:563`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:613`
- `free` (covered): swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:161`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:276`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:370`; swift-testing: `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift:150`; swift-testing: `Tests/TestingTests/ABIEntryPointTests.swift:242`
- `load_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`; swift-build: `Tests/SWBBuildSystemTests/MergeableLibrariesBuildOperationTests.swift:23`; swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `abort` (covered): swift-build: `Sources/SwiftBuild/SWBBuildServiceConnection.swift:23`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:89`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:813`
- `openpty` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`; swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:168`
- `EXIT_SUCCESS` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:152`; swift-testing: `Sources/Testing/ExitTests/ExitTest.Condition.swift:232`
- `memset_s` (covered): swift-crypto: `Sources/Crypto/Util/SecureBytes.swift:316`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:29`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:38`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:47`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:56`
- `segment_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`; swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `strlen` (covered): swift-testing: `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift:150`; swift-testing: `Tests/TestingTests/ABIEntryPointTests.swift:242`
- `wasip1` (missing): swift-async-algorithms: `Sources/AsyncAlgorithms/Locking.swift:15`; swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `which` (missing): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/Support/Environment.swift:90`
- `_dyld_image_count` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:69`
- `_NSGetExecutablePath` (covered): swift-testing: `Sources/Testing/Support/Additions/CommandLineAdditions.swift:55`
- adding a file action to C file actions (covered): swift-subprocess: `Tests/SubprocessTests/DarwinTests.swift:15`
- `addr` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `AR_EFMT1` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `ar_hdr` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `ar_size` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `backtrace` (covered): swift-testing: `Sources/Testing/SourceAttribution/Backtrace.swift:67`
- `backtrace_async` (missing): swift-testing: `Sources/Testing/SourceAttribution/Backtrace.swift:67`
- `build_version_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- C-string arguments for the C-values spawns (covered): swift-subprocess: `Sources/Subprocess/Platforms/Subprocess+Darwin.swift:618`
- `calloc` (covered): swift-testing: `Sources/Testing/ABI/ABI.swift:364`
- `cmd` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `cmdsize` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `copy_file_range` (missing): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- `cpusubtype` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `cputype` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `dlopen` (covered): swift-build: `Sources/SWBUtil/Library.swift:18`
- `dlsym` (covered): swift-testing: `Sources/Testing/Support/GetSymbol.swift:34`
- `dylib` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `dylib_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `DynamicLibrary` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`
- `EX_UNAVAILABLE` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/SwiftPMEntryPoint.swift:31`
- `EXIT_FAILURE` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:57`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:161`
- `F_SETFD` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `fat_arch` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fat_arch_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `FAT_CIGAM` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `FAT_CIGAM_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `fat_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fclonefileat` (covered): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- `fcntl` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `FD_CLOEXEC` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `fflush` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:20`
- `FICLONE` (covered): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- `fileoff` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `filesize` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `filetype` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `fmemopen` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:224`
- `fopencookie` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:313`
- `funopen` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:313`
- `fwrite` (covered): swift-log: `Sources/Logging/Handlers/StreamLogHandler.swift:20`
- `getc_unlocked` (missing): swift-testing: `Sources/Testing/Support/FileHandle.swift:518`
- `getsectiondata` (missing): swift-testing: `Sources/_TestDiscovery/SectionBounds.swift:44`
- `gnu_get_libc_version` (missing): swift-testing: `Sources/Testing/Support/Versions.swift:240`
- `images` (missing): swift-testing: `Sources/_TestDiscovery/SectionBounds.swift:44`
- `isatty` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:800`
- `KERN_PROC_PATHNAME` (missing): swift-testing: `Sources/Testing/Support/Additions/CommandLineAdditions.swift:55`
- `LC_MAIN` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SEGMENT_64` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `LC_SYMTAB` (not System's): swift-build: `Tests/SWBUtilTests/MachOTests.swift:20`
- `mach_header` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `mach_header_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `macho_arch_name_for_cpu_type` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `macho_arch_name_for_mach_header` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `macho_cpu_type_for_arch_name` (not System's): swift-build: `Sources/SWBUtil/Architecture.swift:22`
- `magic` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `malloc` (covered): swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:161`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:276`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:370`
- `memcmp` (covered): swift-crypto: `Sources/_CryptoExtras/RSA/RSA_boring.swift:966`
- `memmem` (missing): swift-testing: `Sources/Testing/ABI/ABI.VersionNumber.swift:225`
- `minos` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `name` (covered): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `NAME_MAX` (covered): swift-testing: `Tests/TestingTests/AttachmentTests.swift:163`
- `nfat_arch` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `offset` (covered): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `path` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `pipe2` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:722`
- `platform` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `posix_spawn_file_actions_addclosefrom_np` (covered): swift-testing: `Sources/Testing/ExitTests/SpawnProcess.swift:91`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:14`
- `pthread_create` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `pthread_join` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `pthread_mutex_t` (covered): swift-certificates: `Sources/X509/Lock.swift:23`
- `pthread_set_name_np` (missing): swift-testing: `Sources/Testing/ExitTests/WaitFor.swift:175`
- `pthread_t` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `raise` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:80`
- readlinkat into a caller's buffer (System's readSymbolicLink returns a FilePath, which dro (covered): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:7`
- `realpath` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:901`
- `rpath_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `SARMAG` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:71`
- `sdk` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `section` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `section_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `segment_command_64` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `sigabbrev_np` (missing): swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:126`
- `SIGABRT` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:50`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:149`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:181`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:187`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:813`
- `SIGSEGV` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:80`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:813`
- `size` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- stdlib.h and sysexits.h exit codes' C names (unread): swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:122`
- `strchr` (missing): swift-testing: `Sources/Testing/Support/Environment.swift:90`
- `strerror_r` (missing): swift-testing: `Sources/Testing/Support/CError.swift:67`
- `strncmp` (covered): swift-testing: `Sources/Testing/Support/Environment.swift:90`
- `sys_signame` (missing): swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:126`
- `sysctl` (covered): swift-testing: `Sources/Testing/Support/Additions/CommandLineAdditions.swift:55`
- `task_set_exception_ports` (missing): swift-testing: `Sources/Testing/ExitTests/ExitTest.swift:219`
- `timespec_get` (covered): swift-testing: `Sources/Testing/Events/Clock.swift:33`
- `tmpfile` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:257`
- `usleep` (covered): swift-stress-tester: `SourceKitStressTester/Tests/SwiftCWrapperToolTests/SwiftCWrapperToolTests.swift:89` (outside the targets)
- `uuid` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `uuid_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `version` (covered): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `version_min_command` (not System's): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `vm_prot_t` (standard library): swift-build: `Sources/SWBUtil/MachO.swift:69`
- `vmaddr` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`
- `vmsize` (missing): swift-build: `Sources/SWBUtil/MachO.swift:16`

</details>

# 4. Platform imports

The goal: no library of the repositories that swift's update-checkout clones for the main scheme imports a platform C module (the modules `modules.ini` counts: Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT, visualc, MachO, libkern, kcdata, libunwind, unwind_h, pthread, sched, sys_select, unistd, xlocale, nl_types, assert_h, complex_h, ctype_h, errno_h, fenv_h, float_h, inttypes_h, iso646_h, limits_h, locale_h, math_h, setjmp_h, signal_h, stdalign_h, stdarg_h, stdatomic_h, stdbool_h, stddef_h, stdint_h, stdio_h, stdlib_h, stdnoreturn_h, string_h, threads_h, time_h, and any module named `*_h`) in any form, on any platform. Each repository is read at its migrated clone in `../adopters`, on its newest migration branch (the first of migrate-all, migrate-unix, migrate-darwin that it has; swift-foundation: migrate-unix or no-darwin), else at its clone in `../ecosystem` as it is, else it's *not cloned*. Left out: swift (the compiler, the runtime, and the platform modules' own overlays); swift-system (System itself, whose imports are what it wraps). A platform's count is the library files whose build for that platform compiles an import of one of the modules, with each `#if` evaluated for it by adopter-coverage's `platforms.py`: an `import Glibc` under `#elseif canImport(Glibc)`, after a branch that Linux takes, counts for FreeBSD and OpenBSD but not for Linux. *Maybe*: files counted because a flag the scan can't read (a trait, a build setting) decides whether the import compiles. *Lexical* counts each import in any branch, compiled or not, as the tracker did before: for a platform, the files that import its own modules (Darwin: Darwin, MachO, libkern, kcdata; Linux (glibc): Glibc; Musl: Musl; Android: Android, Bionic; WASI: WASILibc; FreeBSD: Glibc; OpenBSD: Glibc; Windows: ucrt, WinSDK, CRT, visualc). Kinds are by path (see [How this is computed](#how-this-is-computed)): *library* is under `Sources` (or `src`, `lib`, `products`), *tests* under a test directory, *other* the rest (benchmarks, examples, tools, plugins, docs, utilities), and a *nested package* is under a directory with its own `Package.swift`; the last three are counted lexically only.

| Platform | Library files that import one | Repositories | Library files, lexical |
|---|---:|---:|---:|
| Darwin | 16 | 5 | 19 |
| Linux (glibc) | 32 (1 maybe) | 8 | 72 |
| Musl | 26 (1 maybe) | 6 | 27 |
| Android | 41 (1 maybe) | 8 | 40 |
| WASI | 45 | 6 | 45 |
| FreeBSD | 71 (1 maybe) | 9 | 72 |
| OpenBSD | 70 (1 maybe) | 8 | 72 |
| Windows | 183 (4 maybe) | 21 | 183 |
| **Any** | 216 | 23 | 218 |

| Repository | Read at | Library, lexical | Darwin | Linux | Musl | Android | WASI | FreeBSD | OpenBSD | Windows | Tests | Other | Nested packages |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| boringssl | not cloned | | | | | | | | | | | | |
| brotli | not cloned | | | | | | | | | | | | |
| cmake | not cloned | | | | | | | | | | | | |
| cmark | `../ecosystem/cmark` @ `0c8947bb` | — | — | — | — | — | — | — | — | — | — | — | — |
| curl | not cloned | | | | | | | | | | | | |
| indexstore-db | `../adopters/indexstore-db` `migrate-all` @ `96d2a952` | 4 | — | — | — | — | — | — | — | 4 | — | — | — |
| libxml2 | not cloned | | | | | | | | | | | | |
| llbuild | `../adopters/swift-llbuild` `migrate-unix` @ `314f1127` | 5 | — | — | — | — | — | — | — | 5 | 2 | — | — |
| llvm-project | not cloned | | | | | | | | | | | | |
| mimalloc | not cloned | | | | | | | | | | | | |
| ninja | not cloned | | | | | | | | | | | | |
| sourcekit-lsp | `../adopters/sourcekit-lsp` `migrate-all` @ `79583cc1` | 14 | — | — | — | — | — | — | — | 14 | 2 | — | — |
| swift-argument-parser | `../adopters/swift-argument-parser` `migrate-all` @ `22831ad7` | 2 | — | — | — | — | — | — | — | 2 | — | — | — |
| swift-asn1 | `../ecosystem/swift-asn1` @ `a54383ad` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-async-algorithms | `../adopters/swift-async-algorithms` `migrate-all` @ `d4ad19b0` | 1 | — | 1 | 1 | 1 | — | 1 | 1 | 1 | — | — | — |
| swift-atomics | `../ecosystem/swift-atomics` @ `0442cb5a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-build | `../adopters/swift-build` `migrate-all` @ `1dce162d` | 13 | 4 | 1 | 1 | 1 | — | 1 | 1 | 9 | 4 | — | — |
| swift-certificates | `../adopters/swift-certificates` `migrate-all` @ `c310582c` | 3 | — | — | — | — | 1 | — | — | 3 | — | — | — |
| swift-collections | `../ecosystem/swift-collections` @ `c11818f3` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-corelibs-blocksruntime | not cloned | | | | | | | | | | | | |
| swift-corelibs-foundation | `../ecosystem/swift-corelibs-foundation` @ `6f21ccf1` | 25 | 9 | 11 | 7 | 19 | 6 | 11 | 11 | 19 | 7 | — | — |
| swift-corelibs-libdispatch | not cloned | | | | | | | | | | | | |
| swift-corelibs-xctest | `../adopters/swift-corelibs-xctest` `migrate-darwin` @ `80a3f954` | 1 | 1 | 1 | — | — | — | 1 | 1 | — | — | — | — |
| swift-crypto | `../adopters/swift-crypto` `migrate-all` @ `ef1e59aa` | 1 | — | — | — | — | — | — | — | 1 | — | — | — |
| swift-docc | `../adopters/swift-docc` `migrate-all` @ `4e6a5cea` | 3 | — | — | — | — | — | — | — | 3 | 2 | — | — |
| swift-docc-render-artifact | not cloned | | | | | | | | | | | | |
| swift-docc-symbolkit | `../ecosystem/swift-docc-symbolkit` @ `e9a4c0f2` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-driver | `../adopters/swift-driver` `migrate-unix` @ `e7850bd0` | 7 | — | — | — | — | — | — | — | 7 | 5 | — | — |
| swift-experimental-string-processing | `../ecosystem/swift-experimental-string-processing` @ `db4678c7` | 1 | 1 | 1 | — | — | — | 1 | 1 | — | — | — | — |
| swift-format | `../ecosystem/swift-format` @ `b15dd59f` | 3 | — | — | — | 1 | — | — | — | 2 | — | — | — |
| swift-foundation | `../adopters/swift-foundation` `migrate-unix` @ `d7589041` | 31 | — | 8 | 8 | 10 | 21 | 23 | 23 | 27 | 7 | — | 2 |
| swift-foundation-icu | `../ecosystem/swift-foundation-icu` @ `e8538d25` | — | — | — | — | — | — | — | — | — | — | — | 1 |
| swift-installer-scripts | not cloned | | | | | | | | | | | | |
| swift-integration-tests | not cloned | | | | | | | | | | | | |
| swift-llvm-bindings | `../ecosystem/swift-llvm-bindings` @ `c1fffb92` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-lmdb | `../ecosystem/swift-lmdb` @ `866bc256` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-log | `../adopters/swift-log` `migrate-all` @ `7e49107b` | 3 | — | — | — | — | 1 | — | — | 3 | 3 | — | — |
| swift-markdown | `../ecosystem/swift-markdown` @ `392b73b8` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-nio | `../adopters/swift-nio` `migrate-unix` @ `56deee84` | 48 | — | 3 | 3 | 3 | 13 | 26 | 26 | 34 | 19 | — | 2 |
| swift-numerics | `../ecosystem/swift-numerics` @ `0a5bc040` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-sdk-generator | `../adopters/swift-sdk-generator` `migrate-unix` @ `bc251e13` | — | — | — | — | — | — | — | — | — | 1 | — | — |
| swift-stress-tester | `../adopters/swift-stress-tester` `migrate-all` @ `e1702563` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-subprocess | `../adopters/swift-subprocess` `migrate-unix` @ `661de35c` | 10 | — | — | — | — | — | — | — | 10 | 8 | — | — |
| swift-syntax | `../adopters/swift-syntax` `migrate-all` @ `e6918103` | — | — | — | — | — | — | — | — | — | — | 1 | 2 |
| swift-testing | `../adopters/swift-testing` `migrate-all` @ `e2f8d449` | 10 | — | — | — | — | — | — | — | 10 (1 maybe) | 1 | — | — |
| swift-toolchain-sarif | `../ecosystem/swift-toolchain-sarif` @ `d611f23a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-toolchain-sqlite | `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-tools-protocols | `../adopters/swift-tools-protocols` `migrate-unix` @ `2b2c75dc` | 3 | — | — | — | — | — | — | — | 3 | 2 | — | — |
| swift-tools-support-core | `../adopters/swift-tools-support-core` `migrate-unix` @ `5f85e38e` | 6 | — | — | — | — | — | — | — | 6 | — | — | — |
| swift-xcode-playground-support | not cloned | | | | | | | | | | | | |
| swiftpm | `../adopters/swift-package-manager` `migrate-unix` @ `efff7333` | 12 | — | — | — | 1 | — | 1 | — | 11 | — | — | 1 |
| wasi-libc | not cloned | | | | | | | | | | | | |
| wasmkit | `../adopters/WasmKit` `migrate-unix` @ `fd06e2a3` | 12 | 1 | 6 (1 maybe) | 6 (1 maybe) | 5 (1 maybe) | 3 | 6 (1 maybe) | 6 (1 maybe) | 9 (3 maybe) | 2 | — | 1 |
| zlib | not cloned | | | | | | | | | | | | |

38 repositories read; 23 compile an import of a platform module in library code on some platform: indexstore-db, llbuild, sourcekit-lsp, swift-argument-parser, swift-async-algorithms, swift-build, swift-certificates, swift-corelibs-foundation, swift-corelibs-xctest, swift-crypto, swift-docc, swift-driver, swift-experimental-string-processing, swift-format, swift-foundation, swift-log, swift-nio, swift-subprocess, swift-testing, swift-tools-protocols, swift-tools-support-core, swiftpm, wasmkit.

All repositories, files by module and kind, lexically (the counted modules any file imports):

| Module | Library | Tests | Other | Nested packages | All |
|---|---:|---:|---:|---:|---:|
| Darwin | 18 | 3 | 1 | 5 | 27 |
| Glibc | 72 | 15 | 0 | 6 | 93 |
| Musl | 27 | 1 | 0 | 2 | 30 |
| Bionic | 12 | 3 | 0 | 0 | 15 |
| Android | 29 | 11 | 0 | 1 | 41 |
| WASILibc | 45 | 5 | 0 | 1 | 51 |
| ucrt | 38 | 9 | 0 | 1 | 48 |
| WinSDK | 157 | 35 | 0 | 2 | 194 |
| CRT | 34 | 12 | 0 | 0 | 46 |
| MachO | 3 | 2 | 1 | 0 | 6 |
| unistd | 5 | 0 | 0 | 0 | 5 |
| stdlib_h | 3 | 0 | 0 | 0 | 3 |
| string_h | 1 | 0 | 0 | 0 | 1 |
| threads_h | 1 | 0 | 0 | 0 | 1 |
| **Any** | 218 | 65 | 1 | 9 | 293 |

# 5. Sites left

**The floor** (no site left on a platform but exceptions) holds on no platform: Darwin (151 sites left), Linux (112 sites left), Musl (96 sites left), Android (124 sites left), FreeBSD (156 sites left), OpenBSD (156 sites left), WASI (116 sites left), Windows (542 sites left).

The ledger: every site in the update-checkout cluster that still uses a platform C module, each with one category and its reason, so that nothing left on C is lost; in full in `ledger.json` (status.sh's `STATUS_LEDGER_JSON`). A *site* is an import of a module that `Utilities/adopter-coverage/modules.ini` counts ([count]) or lists ([report]), at its file and line, with the platforms whose build compiles it (`?`: maybe) and the C names it serves there; or a `SYSTEM-GAP:` marker that sits over no such import (one that does is part of the imports' reason). Every library, test and other file is read, at the commits section 4 reads, and the swift repository too. Categories, by `Utilities/adopter-coverage/exceptions.ini`'s entries first, then by each C name against System at `system-next` @ `a3dbd4ec` and `Utilities/adopter-coverage/mapping.ini`: 310 unexplained, 435 System gap, 18 queued, 33 exception, 123 undecided, 22 standard library; 27 excluded. How each is decided is in [How this is computed](#how-this-is-computed).

## Unexplained

Sites that no entry and no System gap explains: the ones to look at. Either System covers every C name the site serves on its platforms (the site could move now, or the scan misses a name), or the scan found none (a type or macro it can't see, or an import nothing uses), or a marker names no C interface.

| Repository | File | Lines: what | Platforms | Why |
|---|---|---|---|---|
| indexstore-db | `Sources/index-dump/index-dump.swift` | 18 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildDBBindings.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildKey.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildValue.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/Internals.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `unittests/Swift/BuildSystemBindingsTests.swift` | 19 `WinSDK` | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| llbuild | `unittests/Swift/BuildSystemEngineTests.swift` | 22 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| sourcekit-lsp | `Sources/BuildServerIntegration/CompilationDatabase.swift` | 22 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Sources/ClangLanguageService/ClangLanguageService.swift` | 29 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Sources/SwiftLanguageService/SwiftLanguageService.swift` | 36 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Tests/BuildServerIntegrationTests/ExternalBuildServerTests.swift` | 27 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| sourcekit-lsp | `Tests/SourceKitLSPTests/PullDiagnosticsTests.swift` | 26 `WinSDK`, 28 `Android` | Android, Windows | no C name it serves was found on its platforms |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 127 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetStdHandle |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 128 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetConsoleScreenBufferInfo |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 130 `WinSDK` (scoped) | Windows | System covers every C name it serves there: STD_OUTPUT_HANDLE |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 131 `WinSDK` (scoped) | Windows | System covers every C name it serves there: CONSOLE_SCREEN_BUFFER_INFO |
| swift-async-algorithms | `Sources/AsyncAlgorithms/Locking.swift` | 17 `Glibc`, 1 marker, 19 `Musl`, 23 `Bionic` | Linux, Musl, Android, FreeBSD, OpenBSD | System covers every C name it serves there: pthread_mutex_destroy, pthread_mutex_init, pthread_mutex_lock, pthread_mutex_t, pthread_mutex_unlock |
| swift-async-algorithms | `Sources/AsyncAlgorithms/Locking.swift` | 21 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-build | `Sources/SWBLibc/libc.swift` | 14 `ucrt`, re-exported, 15 `CRT`, re-exported, 16 `WinSDK`, re-exported | Windows | no C name it serves was found on its platforms |
| swift-build | `Sources/SWBTestSupport/Misc.swift` | 23 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-build | `Sources/SWBUtil/FSProxy.swift` | 38 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-build | `Sources/SWBUtil/HashContext.swift` | 14 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-build | `Sources/SwiftBuild/SWBBuildServiceConnection.swift` | 25 `Darwin` (scoped), 1 marker | Darwin | System covers every C name it serves there: abort |
| swift-certificates | `Sources/X509/Lock.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-crypto | `Sources/_CryptoExtras/Key Derivation/Scrypt/BoringSSL/Scrypt_boring.swift` | 28 `WinSDK` | Windows | System covers every C name it serves there: GetSystemInfo, SYSTEM_INFO |
| swift-docc | `Sources/SwiftDocC/Benchmark/Metrics/PeakMemory.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: DWORD, GetCurrentProcess |
| swift-docc | `Sources/SwiftDocC/Utility/Synchronization.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-docc | `Tests/DocCCommandLineTests/C+Extensions.swift` | 13 `ucrt` | Windows | System covers every C name it serves there: _wputenv_s |
| swift-docc | `Tests/SwiftDocCTests/Utility/SynchronizationTests.swift` | 14 `WinSDK` (scoped) | Windows | System covers every C name it serves there: TryAcquireSRWLockExclusive |
| swift-driver | `Sources/SwiftDriver/Driver/ToolExecutionDelegate.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/SwiftDriver/SwiftScan/SwiftScan.swift` | 18 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/SwiftDriver/Utilities/DateAdditions.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetSystemTimePreciseAsFileTime |
| swift-driver | `Sources/SwiftDriver/Utilities/PythonArchitecture.swift` | 28 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/swift-build-sdk-interfaces/main.swift` | 18 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/Helpers/DriverTestHelpers.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/MiscDriverTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/SpecialModeTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/TargetTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/ToolchainTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-format | `Sources/SwiftFormat/Utilities/URL+isRoot.swift` | 16 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-format | `Sources/swift-format/Utilities/TTY.swift` | 16 `Android` | Android | System covers every C name it serves there: isatty |
| swift-foundation | `Benchmarks/Benchmarks/Base64/Base64.swift` | 27 `Glibc`, 30 `Darwin` | Darwin, Linux, FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Benchmarks/Benchmarks/DataIO/BenchmarkDataIO.swift` | 27 `Glibc`, 30 `Darwin` | Darwin, Linux, FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Reading.swift` | 31 `Musl` | Musl | System covers every C name it serves there: realloc |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 28 `Android`, 29 `unistd`, 38 `WASILibc` | Android, WASI | System covers every C name it serves there: dirfd |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 33 `Musl` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Data.swift` | 74 `string_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/DataProtocol.swift` | 18 `Glibc`, 20 `ucrt`, 22 `WASILibc` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Data/DataProtocol.swift` | 26 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` | 20 `Glibc`, 22 `Musl`, 26 `WASILibc`, 30 `Bionic` | Linux, Musl, Android, FreeBSD, OpenBSD, WASI | System covers every C name it serves there: realloc |
| swift-foundation | `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` | 34 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Date.swift` | 17 `Glibc`, 23 `WASILibc` | FreeBSD, OpenBSD, WASI | System covers every C name it serves there: gmtime_r, strftime, time_t |
| swift-foundation | `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift` | 22 `Glibc`, 27 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift` | 24 `CRT`, 25 `WinSDK` | Windows | System covers every C name it serves there: DWORD |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` | 26 `Glibc`, 31 `WASILibc` | FreeBSD, OpenBSD, WASI | System covers every C name it serves there: POSIXErrorCode |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+Win32.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: DWORD |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift` | 19 `Glibc`, 24 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` | 24 `Android`, 30 `Musl` | Musl, Android | System covers every C name it serves there: f_bavail, f_blocks, f_ffree, f_files, f_frsize, f_fsid, statvfs |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` | 37 `WASILibc` | WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift` | 18 `Glibc`, 24 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 29 `Glibc`, 35 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 32 `CRT`, 33 `WinSDK` | Windows | System covers every C name it serves there: FILETIME |
| swift-foundation | `Sources/FoundationEssentials/Platform.swift` | 67 `stdlib_h`, 68 `unistd`, 72 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` | 22 `Bionic`, 23 `unistd`, 27 `Musl` | Musl, Android | System covers every C name it serves there: clock_gettime, timespec, tv_nsec |
| swift-foundation | `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` | 25 `Glibc` | Linux, FreeBSD, OpenBSD | System covers every C name it serves there: clock_gettime, strdup, timespec, tv_nsec, uname, utsname |
| swift-foundation | `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` | 31 `WASILibc` | WASI | System covers every C name it serves there: clock_gettime, strdup, timespec, tv_nsec |
| swift-foundation | `Sources/FoundationEssentials/String/String+Path.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift` | 16 `unistd`, 20 `Glibc` | Android, FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/URL/URL_Impl.swift` | 18 `Glibc`, 22 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/UUID.swift` | 16 `Glibc`, 22 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/UUID.swift` | 20 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetSystemTimePreciseAsFileTime |
| swift-foundation | `Sources/FoundationEssentials/WASILibc+Extensions.swift` | 14 `WASILibc` | WASI | System covers every C name it serves there: clockid_t |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 16 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 20 `WinSDK` | Windows | System covers every C name it serves there: DWORD, FlsAlloc, FlsGetValue, FlsSetValue |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 22 `threads_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationInternationalization/Formatting/Date/ICUDateFormatter.swift` | 23 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationInternationalization/TimeZone/TimeZone_ICU.swift` | 18 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/DataTests.swift` | 23 `Glibc`, 25 `ucrt` | FreeBSD, OpenBSD, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/DecimalTests.swift` | 18 `Glibc`, 20 `WASILibc`, 22 `CRT` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift` | 22 `Android`, 33 `Bionic`, 35 `Glibc`, 37 `Musl`, 39 `CRT`, 40 `WinSDK` | Linux, Musl, Android, FreeBSD, OpenBSD, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` | 19 `Bionic`, 21 `Glibc` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` | 25 `WASILibc` | WASI | System covers every C name it serves there: LC_ALL, setlocale |
| swift-foundation | `Tests/FoundationEssentialsTests/ProcessInfoTests.swift` | 26 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/StringTests.swift` | 20 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationInternationalizationTests/DateComponentsTests.swift` | 29 `Glibc`, 31 `WASILibc`, 33 `CRT` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-log | `Sources/Logging/Handlers/StreamLogHandler.swift` | 22 `WASILibc`, 1 marker | WASI | System covers every C name it serves there: fflush, fwrite, stdout |
| swift-log | `Sources/Logging/Locks.swift` | 30 `ucrt`, 31 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, AcquireSRWLockShared, InitializeSRWLock, ReleaseSRWLockExclusive, ReleaseSRWLockShared, SRWLOCK |
| swift-log | `Sources/Logging/MetadataProvider.swift` | 17 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-log | `Tests/LoggingTests/MetadataProviderTest.swift` | 21 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-log | `Tests/LoggingTests/TestLogger.swift` | 24 `WinSDK` | Windows | System covers every C name it serves there: GetCurrentThreadId |
| swift-nio | `Benchmarks/Benchmarks/NIOPosixBenchmarks/Util/GlobalExecutor.swift` | 19 `Glibc` | Linux, FreeBSD, OpenBSD | System covers every C name it serves there: RTLD_LAZY, dlopen, dlsym |
| swift-nio | `IntegrationTests/allocation-counter-tests-framework/template/scaffolding.swift` | 31 `Glibc` | Linux, FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOConcurrencyHelpers/NIOLock.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-nio | `Sources/NIOConcurrencyHelpers/atomics.swift` | 23 `ucrt`, 24 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Sources/NIOConcurrencyHelpers/atomics.swift` | 30 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: sched_yield |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 72 `Glibc`, 74 `Musl` | Linux, Musl | System covers every C name it serves there: TCP_INFO |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 80 `Glibc` | FreeBSD | System covers every C name it serves there: IPPROTO_IP, IPPROTO_IPV6, IPPROTO_TCP, IPPROTO_UDP, IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS, IPV6_MULTICAST_IF… |
| swift-nio | `Sources/NIOCore/ByteBuffer-core.swift` | 16 `ucrt`, 22 `Glibc`, 25 `WASILibc` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/FileHandle.swift` | 18 `ucrt` | Windows | System covers every C name it serves there: O_CREAT, O_RDONLY, O_RDWR, O_WRONLY, _O_NOINHERIT, _S_IREAD, _S_IWRITE |
| swift-nio | `Sources/NIOCore/FileHandle.swift` | 22 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: O_CREAT |
| swift-nio | `Sources/NIOCore/FileHandle.swift` | 25 `WASILibc` | WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/FileRegion.swift` | 15 `ucrt`, 19 `Glibc`, 21 `WASILibc` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/GlobalSingletons.swift` | 20 `ucrt`, 21 `WinSDK`, 23 `Glibc`, 26 `WASILibc` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/IO.swift` | 17 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FormatMessageW |
| swift-nio | `Sources/NIOCore/IO.swift` | 24 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOCore/IO.swift` | 26 `WinSDK` (scoped) | Windows | System covers every C name it serves there: WORD |
| swift-nio | `Sources/NIOCore/IO.swift` | 34 `Glibc`, 37 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 20 `Glibc` | FreeBSD | System covers every C name it serves there: IFF_BROADCAST, IFF_MULTICAST, IFF_POINTOPOINT, ifa_addr, ifa_dstaddr, ifa_flags, ifa_name, ifa_netmask… |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 25 `WASILibc` | WASI | System covers every C name it serves there: sa_family |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 34 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_ADDRESSES |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 35 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_UNICAST_ADDRESS |
| swift-nio | `Sources/NIOCore/SocketAddresses.swift` | 76 `WASILibc` | WASI | System covers every C name it serves there: s_addr, sin6_addr, sin6_family, sin6_flowinfo, sin6_port, sin6_scope_id, sin_addr, sin_family… |
| swift-nio | `Sources/NIOCore/SocketOptionProvider.swift` | 20 `Glibc`, 22 `Musl`, 24 `Bionic` | Linux, Musl, Android | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/SocketOptionProvider.swift` | 31 `Glibc`, 34 `Glibc`, 39 `WASILibc` | FreeBSD, OpenBSD, WASI | System covers every C name it serves there: linger |
| swift-nio | `Sources/NIOCore/SystemCallHelpers.swift` | 25 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: ifaddrs |
| swift-nio | `Sources/NIOCore/SystemCallHelpers.swift` | 28 `WASILibc` | WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 32 `WinSDK` (scoped) | Windows | System covers every C name it serves there: RelationProcessorCore |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 36 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ERROR_SUCCESS |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 38 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetAdaptersAddresses |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 40 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetLogicalProcessorInformation |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 42 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_ADDRESSES |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 43 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_UNICAST_ADDRESS |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 44 `WinSDK` (scoped) | Windows | System covers every C name it serves there: SYSTEM_LOGICAL_PROCESSOR_INFORMATION |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 47 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 51 `WASILibc` | WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOEmbedded/Embedded.swift` | 28 `Glibc`, 31 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/FileInfo.swift` | 19 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: st_atim, st_ctim, st_mtim |
| swift-nio | `Sources/NIOFS/Internal/System Calls/Errno.swift` | 20 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/System Calls/FileDescriptor+Syscalls.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/System Calls/Mocking.swift` | 25 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/System Calls/Syscall.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/SystemFileHandle.swift` | 25 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOHTTP1Server/main.swift` | 21 `WinSDK` | Windows | System covers every C name it serves there: STD_INPUT_HANDLE, STD_OUTPUT_HANDLE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 31 `WinSDK` (scoped) | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 89 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ReadFile |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 91 `WinSDK` (scoped) | Windows | System covers every C name it serves there: WriteFile |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 100 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 101 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 104 `WinSDK` (scoped) | Windows | System covers every C name it serves there: OVERLAPPED |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 34 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EAFNOSUPPORT |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 35 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EBADF |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 26 `ucrt` | Windows | System covers every C name it serves there: FILE_TYPE_PIPE, GetFileType, HANDLE, INVALID_HANDLE_VALUE, _get_osfhandle |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 28 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetFileType |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 30 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FILE_TYPE_PIPE |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 31 `WinSDK` (scoped) | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 33 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 34 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-nio | `Sources/NIOPosix/ControlMessage.swift` | 28 `Glibc` | OpenBSD | System covers every C name it serves there: IPPROTO_IP, IPPROTO_IPV6, IPV6_TCLASS, IP_TOS, cmsg_len, cmsg_level, cmsg_type, ipi6_addr… |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 40 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ECONNABORTED |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 41 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ECONNREFUSED |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 42 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EMFILE |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 43 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENFILE |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 44 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENOBUFS |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 45 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENOMEM |
| swift-nio | `Sources/NIOPosix/System.swift` | 73 `Musl`, re-exported, 75 `Android`, re-exported | Musl, Android | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOPosix/System.swift` | 86 `Glibc`, re-exported | OpenBSD | System covers every C name it serves there: EAGAIN, EINPROGRESS, IPPROTO_UDP, SHUT_RD, SHUT_RDWR, SHUT_WR, UIO_MAXIOV, kevent |
| swift-nio | `Sources/NIOPosix/Thread.swift` | 30 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, GetCurrentThread, GetCurrentThreadId |
| swift-nio | `Sources/_NIOFileSystem/FileInfo.swift` | 19 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: st_atim, st_ctim, st_mtim |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/Errno.swift` | 20 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/FileDescriptor+Syscalls.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/Mocking.swift` | 25 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/Syscall.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/SystemFileHandle.swift` | 25 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift` | 30 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift` | 32 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOCoreTests/XCTest+Extensions.swift` | 29 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOEmbeddedTests/TestUtils.swift` | 31 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOFSTests/FileInfoTests.swift` | 24 `Glibc` | Linux, FreeBSD, OpenBSD | System covers every C name it serves there: S_IFREG, st_atim, st_blksize, st_blocks, st_ctim, st_dev, st_gid, st_ino… |
| swift-nio | `Tests/NIOFSTests/FileInfoTests.swift` | 26 `Android` | Android | System covers every C name it serves there: st_atim, st_blksize, st_blocks, st_ctim, st_dev, st_gid, st_ino, st_mode… |
| swift-nio | `Tests/NIOFSTests/FileTypeTests.swift` | 48 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOHTTP1Tests/TestUtils.swift` | 59 `WinSDK`, 60 `ucrt` | Windows | System covers every C name it serves there: CreateDirectoryW, Sleep, _O_BINARY, _O_RDWR, _SH_DENYNO, _S_IREAD, _S_IWRITE, _sopen_s |
| swift-nio | `Tests/NIOPosixTests/AsyncChannelBootstrapTests.swift` | 23 `ucrt` | Windows | System covers every C name it serves there: _O_BINARY |
| swift-nio | `Tests/NIOPosixTests/HappyEyeballsTest.swift` | 28 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: sin6_addr, sin6_family, sin6_flowinfo, sin6_port, sin6_scope_id, sin_addr, sin_family, sin_port |
| swift-nio | `Tests/NIOPosixTests/NIOFileHandleTest.swift` | 22 `ucrt` | Windows | System covers every C name it serves there: _O_BINARY |
| swift-nio | `Tests/NIOPosixTests/NIOTransportAccessibleChannelCoreTests.swift` | 21 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/StrictCrashTests.swift` | 24 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/SystemCrashTests.swift` | 30 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/TestUtils.swift` | 56 `WinSDK`, 57 `ucrt` | Windows | System covers every C name it serves there: CreateDirectoryW, Sleep, _O_BINARY, _O_RDWR, _SH_DENYNO, _S_IREAD, _S_IWRITE, _sopen_s |
| swift-nio | `Tests/NIOTestUtilsTests/NIOHTTP1TestServerTest.swift` | 32 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-sdk-generator | `Tests/AsyncProcessTests/IntegrationTests.swift` | 79 `Android` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-subprocess | `Sources/Subprocess/Execution.swift` | 16 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-subprocess | `Sources/Subprocess/IO/Output.swift` | 15 `WinSDK` | Windows | System covers every C name it serves there: HANDLE, _get_osfhandle |
| swift-subprocess | `Sources/Subprocess/Platforms/Subprocess+Darwin.swift` | 618 marker: C-string arguments for the C-values spawns. System's ProcessID.spawn w… | Darwin | the marker names no C interface (C-string arguments for the C-values spawns); System covers it by ProcessID.spawn's C-array forms with C values |
| swift-subprocess | `Sources/Subprocess/SubprocessOutputSequence.swift` | 612 `WinSDK` | Windows | System covers every C name it serves there: GetSystemInfo, HANDLE, SYSTEM_INFO |
| swift-subprocess | `Tests/SubprocessTests/AsyncIOTests.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: ERROR_INVALID_HANDLE, GetCurrentProcess, GetCurrentProcessId, GetCurrentThread, INVALID_HANDLE_VALUE |
| swift-subprocess | `Tests/SubprocessTests/DarwinTests.swift` | 20 `Darwin` (scoped), 1 marker | Darwin | System covers every C name it serves there: posix_spawn_file_actions_addchdir_np |
| swift-subprocess | `Tests/SubprocessTests/PlatformConformance.swift` | 15 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-subprocess | `Tests/TestResources/TestResources.swift` | 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-syntax | `SwiftParserCLI/Sources/swift-parser-cli/Commands/Reduce.swift` | 17 `WinSDK` | Windows | System covers every C name it serves there: TerminateProcess |
| swift-syntax | `SwiftParserCLI/Sources/swift-parser-cli/swift-parser-cli.swift` | 23 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/HICON+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/IWICBitmapSource+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/UnsafeMutablePointer+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/_AttachableImageWrapper+AttachableWrapper.swift` | 12 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Support/Additions/IPropertyBag2Additions.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Support/Additions/IWICImagingFactoryAdditions.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 38 marker: stdlib.h EXIT_SUCCESS and EXIT_FAILURE in Embedded Swift, which | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_FAILURE, EXIT_SUCCESS |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 57 marker: stdlib.h EXIT_FAILURE in Embedded Swift, as above, 161 marker: stdlib.h EXIT_FAILURE in Embedded Swift, as above | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_FAILURE |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 152 marker: stdlib.h EXIT_SUCCESS in Embedded Swift, as above | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_SUCCESS |
| swift-testing | `Sources/Testing/ExitTests/ExitStatus.swift` | 122 marker: stdlib.h and sysexits.h exit codes' C names, such as | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (stdlib.h and sysexits.h exit codes' C names) |
| swift-testing | `Sources/Testing/ExitTests/ExitTest.Condition.swift` | 232 marker: stdlib.h EXIT_SUCCESS in Embedded Swift, which SystemPackage | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_SUCCESS |
| swift-testing | `Sources/Testing/Support/CError.swift` | 67 marker: string.h strerror_r on FreeBSD and OpenBSD: Errno's description | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: strerror_r |
| swift-testing | `Tests/TestingTests/AttachmentTests.swift` | 41 `WinSDK` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-tools-protocols | `Sources/LanguageServerProtocolTransport/JSONRPCConnection.swift` | 24 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-tools-protocols | `Sources/SKLogging/SetGlobalLogFileHandler.swift` | 25 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, OpenProcess, PROCESS_QUERY_INFORMATION |
| swift-tools-protocols | `Sources/ToolsProtocolsSwiftExtensions/URLExtensions.swift` | 16 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-tools-protocols | `Tests/LanguageServerProtocolTransportTests/ConnectionTests.swift` | 24 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-tools-protocols | `Tests/ToolsProtocolsSwiftExtensionsTests/AsyncUtilsTests.swift` | 22 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-tools-support-core | `Sources/TSCBasic/Thread.swift` | 14 `WinSDK` | Windows | System covers every C name it serves there: SwitchToThread |
| swiftpm | `Sources/Basics/Archiver/TarArchiver.swift` | 19 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/Basics/Concurrency/AsyncProcess.swift` | 20 `Android` | Android | System covers every C name it serves there: fdopen |
| swiftpm | `Sources/Commands/Utilities/TestingSupport.swift` | 22 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/Commands/Utilities/TestingSupport.swift` | 26 `Glibc` | FreeBSD | System covers every C name it serves there: pthread_suspend_all_np |
| swiftpm | `Sources/CoreCommands/SwiftCommandState.swift` | 41 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/Runtimes/PackageDescription/PackageDescription.swift` | 14 `ucrt` | Windows | System covers every C name it serves there: HANDLE, _O_APPEND, _close, _fdopen, _open_osfhandle, atexit, fclose, fputs |
| swiftpm | `Sources/Runtimes/PackageDescription/PackageDescription.swift` | 15 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| wasmkit | `Examples/embedded-wat/Sources/embedded-wat/Entrypoint.swift` | 4 `WASILibc`, 6 `Darwin`, 8 `Glibc` | Darwin, Linux, FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| wasmkit | `Sources/CLICommands/Run.swift` | 14 `Glibc`, 16 `Musl` | Linux, Musl, FreeBSD, OpenBSD | System covers every C name it serves there: exit |
| wasmkit | `Sources/CLICommands/TCPListener.swift` | 105 `Glibc`, 107 `Musl`, 109 `Android` | Linux?, Musl?, Android?, FreeBSD?, OpenBSD? | System covers every C name it serves there: AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR, bind, close, inet_pton, listen… |
| wasmkit | `Sources/WASI/Platform/PAL/PALClock.swift` | 9 `Musl`, 11 `Android` | Musl, Android | System covers every C name it serves there: CLOCK_MONOTONIC, CLOCK_MONOTONIC_RAW, CLOCK_REALTIME, clock_getres, clock_gettime, clockid_t, timespec, tv_nsec… |
| wasmkit | `Sources/WASI/Platform/PAL/PALClock.swift` | 14 `WASILibc` | WASI | System covers every C name it serves there: clock_getres, clock_gettime, clockid_t, timespec, tv_nsec, tv_sec |
| wasmkit | `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` | 7 `Glibc`, 10 `Musl`, 13 `Android`, 19 `WASILibc` | Linux, Musl, Android, FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 9 `Darwin` (scoped), 1 marker | Darwin | System covers every C name it serves there: readlinkat |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 11 `Glibc`, 14 `Musl`, 17 `Android` | Linux, Musl, Android, FreeBSD, OpenBSD | System covers every C name it serves there: AT_REMOVEDIR, AT_SYMLINK_NOFOLLOW, DT_BLK, DT_CHR, DT_DIR, DT_LNK, DT_REG, DT_SOCK… |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 24 `WASILibc` | WASI | System covers every C name it serves there: AT_REMOVEDIR, AT_SYMLINK_NOFOLLOW, O_RDONLY, O_RDWR, O_WRONLY, SEEK_CUR, SEEK_END, SEEK_SET… |
| wasmkit | `Sources/WasmKit/Execution/StatsCollector.swift` | 7 `ucrt` | Windows? | System covers every C name it serves there: fwrite |
| wasmkit | `Sources/WasmKit/Platform/AtomicParkingLot.swift` | 38 `WinSDK` | Windows? | System covers every C name it serves there: AcquireSRWLockExclusive, CONDITION_VARIABLE, DWORD, GetTickCount64, INFINITE, InitializeConditionVariable, InitializeSRWLock, ReleaseSRWLockExclusive… |
| wasmkit | `Sources/WasmKit/Platform/SystemVirtualMemory.swift` | 14 `Android` | Android | System covers every C name it serves there: MAP_ANON, MAP_PRIVATE, PROT_NONE, mmap |
| wasmkit | `Sources/WasmTools/WasmTools.swift` | 7 `ucrt` | Windows | System covers every C name it serves there: _O_BINARY, _close |
| wasmkit | `Tests/WASITests/TestSupport.swift` | 7 `ucrt` | Windows | System covers every C name it serves there: strerror |
| wasmkit | `Tests/WASITests/WASITests.swift` | 11 `Glibc` | Linux, Musl | System covers every C name it serves there: RLIMIT_NOFILE, getrlimit, rlim_cur, rlim_t, rlimit, setrlimit |

## System gaps, by sites unblocked

Each row is a gap in System at `system-next`: a mapping.ini entry (or a C name in none) that System lacks on the platforms given, or a gap `exceptions.ini` keeps by hand. *Unblocks*: the sites that leave this category once it's filled, given the rows above are, and the files they're in (a scoped import is a site of its own, so a file that imports declaration by declaration has many); the order is greedy, ties going to more platforms. *Holds*: every site it's one of the gaps of.

| # | Gap | Lacks | Unblocks | Holds | Repositories | C names | System |
|---:|---|---|---:|---:|---|---|---|
| 1 | E3: Mach-O's file structures and architecture names, vm_prot_t, and ar.h's archive header | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 63 (4 files) | 65 | swift-build, swift-syntax | `AR_EFMT1`, `FAT_CIGAM`, `FAT_CIGAM_64`, `FAT_MAGIC`, `FAT_MAGIC_64`, `LC_BUILD_VERSION`… | kept by hand (`exceptions.ini`) |
| 2 | [multicast] | WASI, Windows | 22 (3 files) | 24 | swift-nio | `IPV6_JOIN_GROUP`, `IPV6_LEAVE_GROUP`, `IPV6_MULTICAST_HOPS`, `IPV6_MULTICAST_IF`, `IPV6_MULTICAST_LOOP`, `IP_ADD_MEMBERSHIP`… | SocketDescriptor.IPv6Option.joinGroup isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 3 | [address families] | Windows | 19 (6 files) | 24 | swift-certificates, swift-nio | `AF_INET`, `AF_INET6`, `AF_UNIX`, `AF_UNSPEC`, `PF_INET`, `PF_INET6`… | SocketAddress.Family.ipv4 isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 4 | [Win32 errors] | Windows | 18 (11 files) | 64 | indexstore-db, sourcekit-lsp, swift-build, swift-driver, swift-foundation, swift-nio, swift-subprocess, swift-testing, swift-tools-support-core, swiftpm, wasmkit | `ERROR_IO_INCOMPLETE`, `ERROR_NOT_FOUND`, `ERROR_TIMEOUT`, `FACILITY_WIN32`, `FORMAT_MESSAGE_ALLOCATE_BUFFER`, `FORMAT_MESSAGE_FROM_SYSTEM`… | System's implementation uses it; no public declaration names it |
| 5 | [socket options] | Android, OpenBSD, WASI, Windows | 16 (2 files) | 18 | swift-nio | `SOL_SOCKET`, `SO_BROADCAST`, `SO_ERROR`, `SO_KEEPALIVE`, `SO_LINGER`, `SO_RCVBUF`… | SocketDescriptor.AncillaryMessageBuffer.Message.timestamp isn't built on Windows (only Darwin, Linux, Musl, … |
| 6 | [Winsock addresses] | Windows | 16 (5 files) | 18 | swift-certificates, swift-nio | `ADDRESS_FAMILY`, `IN6_ADDR`, `IN_ADDR`, `SOCKADDR`, `SOCKADDR_IN`, `SOCKADDR_IN6`… | System names it nowhere |
| 7 | [sockaddr types] | Windows | 15 (9 files) | 17 | swift-certificates, swift-nio | `in6_addr`, `in_addr`, `sockaddr`, `sockaddr_in`, `sockaddr_in6`, `sockaddr_un`… | CInterop.SockLen isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 8 | [remove] | WASI, Windows | 14 (4 files) | 14 | swift-testing | `remove` | FilePath.remove isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 9 | [Windows name resolution] | Windows | 8 (2 files) | 9 | swift-nio | `ADDRINFOW`, `FreeAddrInfoW`, `GetAddrInfoW`, `gai_strerrorA` | System names it nowhere |
| 10 | [Winsock sockets] | Windows | 7 (3 files) | 12 | swift-nio | `FIONBIO`, `INVALID_SOCKET`, `SOCKET`, `SOCKET_ERROR`, `closesocket`, `ioctlsocket` | System names it nowhere |
| 11 | [protocol levels] | Windows | 7 (2 files) | 9 | swift-nio | `IPPROTO_IP`, `IPPROTO_IPV6`, `IPPROTO_TCP`, `IPPROTO_UDP` | SocketDescriptor.ProtocolID.ip isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, … |
| 12 | [INADDR_ANY] | Windows | 7 (4 files) | 7 | swift-nio | `INADDR_ANY`, `INET6_ADDRSTRLEN`, `INET_ADDRSTRLEN` | IPv4Address.Host.descriptionCapacity isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 13 | [signal numbers] | WASI, Windows | 6 (2 files) | 10 | sourcekit-lsp, swift-driver, swift-testing, swiftpm | `SIGABRT`, `SIGINT`, `SIGSEGV`, `SIGTERM` | Signal.abort isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 14 | [string functions] | Windows | 6 (5 files) | 21 | swift-certificates, swift-crypto, swift-foundation, swift-subprocess, swift-testing, swift-tools-support-core | `_strdup`, `memcmp`, `strlen`, `strncmp`, `wcslen` | System's implementation uses it; no public declaration names it |
| 15 | [Winsock messages] | Windows | 6 (2 files) | 7 | swift-nio | `LPFN_WSARECVMSG`, `LPFN_WSASENDMSG`, `LPWSAMSG`, `WSABUF`, `WSACMSGHDR`, `WSAIoctl`… | System names it nowhere |
| 16 | E5: a dlopen that runs in the caller's image | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 5 (1 file) | 5 | swift-build | `dlopen` | kept by hand (`exceptions.ini`) |
| 17 | strncasecmp | Linux, Musl, Android, FreeBSD, OpenBSD, WASI | 5 (1 file) | 5 | swift-foundation | `strncasecmp` | System's implementation uses it; no public declaration names it |
| 18 | [socket types] | Windows | 5 (2 files) | 6 | swift-nio | `SOCK_DGRAM`, `SOCK_RAW`, `SOCK_STREAM` | SocketDescriptor.ConnectionType.datagram isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 19 | memset_s | Windows | 5 (2 files) | 5 | swift-crypto | `memset_s` | Memory.secureZero isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 20 | [Windows local memory] | Windows | 4 (3 files) | 16 | swift-build, swift-foundation, swift-nio, swift-subprocess, swift-testing, swift-tools-support-core | `LocalFree` | System's implementation uses it; no public declaration names it |
| 21 | [Windows errno] | Windows | 4 (3 files) | 9 | swift-foundation, swift-nio, swift-subprocess, swift-tools-support-core, wasmkit | `_get_errno`, `_set_errno`, `errno_t` | System names it nowhere |
| 22 | LoadLibraryW | Windows | 4 (2 files) | 6 | indexstore-db, sourcekit-lsp, swift-driver, swift-foundation | `LoadLibraryW` | System names it nowhere |
| 23 | [Windows known folders] | Windows | 4 (4 files) | 5 | swift-build, swift-docc, swift-foundation, swiftpm | `CoTaskMemFree`, `FOLDERID_ProgramFilesX86`, `FOLDERID_System`, `FOLDERID_UserProgramFiles`, `KF_FLAG_DEFAULT`, `KNOWNFOLDERID`… | System names it nowhere |
| 24 | [shutdown] | Windows | 4 (1 file) | 5 | swift-nio | `SD_BOTH`, `SD_RECEIVE`, `SD_SEND`, `shutdown` | System names it nowhere |
| 25 | [ECN, TOS and packet info] | Windows | 4 (2 files) | 4 | swift-nio | `IPV6_PKTINFO`, `IPV6_RECVTCLASS`, `IP_PKTINFO`, `IP_RECVTOS` | SocketDescriptor.IPv6Option.receiveTrafficClass isn't built on Windows (only Darwin, Linux, Musl, Android, … |
| 26 | [IPV6_V6ONLY and IP_HDRINCL] | WASI, Windows | 3 (2 files) | 5 | swift-nio | `IPV6_V6ONLY`, `IP_HDRINCL` | SocketDescriptor.IPv6Option.v6Only isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 27 | [TCP_NODELAY] | WASI, Windows | 3 (2 files) | 4 | swift-nio | `TCP_NODELAY` | SocketDescriptor.TCPOption.noDelay isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 28 | [sendfile] | FreeBSD, Windows | 3 (2 files) | 4 | swift-nio | `TF_USE_KERNEL_APC`, `TransmitFile`, `sendfile` | System names it nowhere |
| 29 | UINT | Windows | 3 (2 files) | 8 | indexstore-db, swift-build, swift-driver, swift-foundation, swift-testing | `UINT` | System's implementation uses it; no public declaration names it |
| 30 | [Windows DLLs] | Windows | 4 (3 files) | 5 | swift-build, swift-driver, swift-subprocess, swiftpm | `GetModuleHandleA`, `GetModuleHandleW` | System's implementation uses it; no public declaration names it |
| 31 | [PATH_MAX] | Windows | 3 (3 files) | 13 | indexstore-db, sourcekit-lsp, swift-build, swift-foundation, swift-nio, swift-subprocess, swift-tools-support-core | `MAX_PATH` | System's implementation uses it; no public declaration names it |
| 32 | [Windows handles] | Windows | 3 (3 files) | 8 | swift-foundation, swift-nio, swift-subprocess, swift-tools-support-core | `DUPLICATE_SAME_ACCESS`, `SECURITY_ATTRIBUTES`, `WAIT_OBJECT_0`, `WAIT_TIMEOUT` | System names it nowhere |
| 33 | [Windows paths] | Windows | 3 (3 files) | 5 | swift-build, swift-foundation, swift-subprocess, swift-testing, swift-tools-support-core | `PATHCCH_ALLOW_LONG_PATHS` | System's implementation uses it; no public declaration names it |
| 34 | [inet_ntop and inet_pton] | Windows | 3 (2 files) | 4 | swift-certificates, swift-nio | `inet_ntop`, `inet_pton` | IPv4Address.Host.init isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 35 | timeout | Linux, FreeBSD, OpenBSD, Windows | 2 (2 files) | 3 | swift-subprocess | `timeout` | System names it nowhere |
| 36 | getloadavg | Darwin, Linux, FreeBSD, OpenBSD | 2 (1 file) | 2 | swift-experimental-string-processing | `getloadavg` | System names it nowhere |
| 37 | MAP_ANONYMOUS | Linux, Musl | 2 (1 file) | 2 | wasmkit | `MAP_ANONYMOUS` | System names it nowhere |
| 38 | ifa_next | FreeBSD, OpenBSD | 2 (1 file) | 2 | swift-nio | `ifa_next` | System names it nowhere |
| 39 | [Winsock errors] | Windows | 2 (2 files) | 6 | swift-nio | `WSAEINVAL`, `WSAEWOULDBLOCK`, `WSAGetLastError` | System names it nowhere |
| 40 | [SO_RCVTIMEO and SO_TIMESTAMP] | Windows | 3 (2 files) | 3 | swift-nio | `SO_RCVTIMEO` | SocketDescriptor.SocketOption.receiveTimeout isn't built on Windows (only Darwin, Linux, Musl, Android, … |
| 41 | [getenv] | Windows | 2 (1 file) | 4 | swift-foundation, swift-nio, swiftpm | `_dupenv_s`, `_putenv` | System names it nowhere |
| 42 | [Windows adapters] | Windows | 2 (1 file) | 4 | swift-foundation, swift-nio | `ERROR_BUFFER_OVERFLOW` | System names it nowhere |
| 43 | ERROR_BAD_ARGUMENTS | Windows | 2 (1 file) | 3 | swift-argument-parser, swift-foundation | `ERROR_BAD_ARGUMENTS` | System names it nowhere |
| 44 | [getsockname and getpeername] | Windows | 2 (1 file) | 3 | swift-nio | `getpeername`, `getsockname` | SocketDescriptor.getPeerAddress isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 45 | [linger] | Windows | 2 (2 files) | 3 | swift-nio | `LINGER`, `linger` | CInterop.Linger isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 46 | COPYFILE2_EXTENDED_PARAMETERS | Windows | 2 (1 file) | 2 | swift-foundation | `COPYFILE2_EXTENDED_PARAMETERS` | System's implementation uses it; no public declaration names it |
| 47 | MAXIMUM_REPARSE_DATA_BUFFER_SIZE | Windows | 2 (1 file) | 2 | swift-foundation | `MAXIMUM_REPARSE_DATA_BUFFER_SIZE` | System names it nowhere |
| 48 | PCWSTR | Windows | 2 (2 files) | 2 | swift-foundation, swift-testing | `PCWSTR` | System names it nowhere |
| 49 | [sockaddr_storage] | Windows | 2 (2 files) | 2 | swift-nio | `sockaddr_storage` | CInterop.SockAddrStorage isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 50 | getsectiondata | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 3 | swift-syntax, swift-testing | `getsectiondata` | System names it nowhere |
| 51 | _dyld_get_image_header | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 2 (1 file) | 2 | swift-syntax | `_dyld_get_image_header` | System names it nowhere |
| 52 | funopen | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `funopen` | System names it nowhere |
| 53 | getc_unlocked | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `getc_unlocked` | System names it nowhere |
| 54 | strchr | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `strchr` | System names it nowhere |
| 55 | task_set_exception_ports | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `task_set_exception_ports` | System names it nowhere |
| 56 | [thread names] | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows | 1 (1 file) | 1 | swift-testing | `pthread_set_name_np` | System names it nowhere |
| 57 | memmem | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI | 1 (1 file) | 1 | swift-testing | `memmem` | System names it nowhere |
| 58 | fmemopen | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-testing | `fmemopen` | System names it nowhere |
| 59 | tmpfile | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-testing | `tmpfile` | System names it nowhere |
| 60 | posix_spawn_file_actions_addclosefrom_np | Darwin, Android, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `posix_spawn_file_actions_addclosefrom_np` | SpawnFileAction.closeAll isn't built on Darwin (only Linux, Musl, FreeBSD) |
| 61 | [usleep] | WASI, Windows | 1 (1 file) | 2 | swift-sdk-generator, swift-stress-tester | `usleep` | PThread.sleep(for:) isn't built on WASI |
| 62 | isatty | WASI, Windows | 1 (1 file) | 2 | swift-testing, swift-tools-support-core | `isatty` | TerminalDescriptor.init isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 63 | [stdio] | Windows | 2 (2 files) | 2 | swift-tools-support-core, swiftpm | `fileno`, `fopen` | FileStream.fileDescriptor isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 64 | CLOCK_MONOTONIC_RAW | FreeBSD, OpenBSD | 1 (1 file) | 1 | wasmkit | `CLOCK_MONOTONIC_RAW` | ClockID.monotonicRaw isn't built on FreeBSD (only Darwin, Linux, Musl, Android) |
| 65 | [dlopen] | WASI, Windows | 1 (1 file) | 1 | swift-testing | `dlsym` | DynamicLibrary.address isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 66 | [exit] | WASI, Windows | 1 (1 file) | 1 | swift-testing | `EX_UNAVAILABLE` | ProcessID.ExitCode.serviceUnavailable isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 67 | mktemp | FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-foundation | `mktemp` | FilePath.makeUniqueFile isn't built on FreeBSD (only Darwin, Linux, Musl, Android) |
| 68 | raise | WASI, Windows | 1 (1 file) | 1 | swift-testing | `raise` | Signal.raise isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 69 | realpath | WASI, Windows | 1 (1 file) | 1 | swift-testing | `realpath` | FilePath.canonicalized isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 70 | sin_addr | Windows | 1 (1 file) | 4 | swift-nio | `sin_addr` | System's accessor isn't built on Windows |
| 71 | sin_port | Windows | 1 (1 file) | 4 | swift-nio | `sin_port` | System's accessor isn't built on Windows |
| 72 | LARGE_INTEGER | Windows | 1 (1 file) | 3 | swift-foundation, wasmkit | `LARGE_INTEGER` | System's implementation uses it; no public declaration names it |
| 73 | [Windows threads] | Windows | 3 (2 files) | 3 | swift-foundation, swift-nio | `CompareObjectHandles` | System names it nowhere |
| 74 | [Windows process exit] | Windows | 1 (1 file) | 3 | swift-build, swift-subprocess | `RegisterWaitForSingleObject`, `UnregisterWait`, `WAITORTIMERCALLBACK`, `WT_EXECUTELONGFUNCTION`, `WT_EXECUTEONLYONCE` | System names it nowhere |
| 75 | [accept] | Windows | 1 (1 file) | 3 | swift-nio | `accept` | SocketDescriptor.accept isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 76 | [listen] | Windows | 1 (1 file) | 3 | swift-nio | `listen` | SocketDescriptor.listen isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 77 | ERROR_FILENAME_EXCED_RANGE | Windows | 1 (1 file) | 2 | sourcekit-lsp, swift-foundation | `ERROR_FILENAME_EXCED_RANGE` | System names it nowhere |
| 78 | [Windows I/O completion ports] | Windows | 1 (1 file) | 2 | swift-subprocess, swift-tools-support-core | `LPOVERLAPPED` | System names it nowhere |
| 79 | [bind] | Windows | 1 (1 file) | 2 | swift-nio | `bind` | SocketDescriptor.bind isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 80 | [connect] | Windows | 1 (1 file) | 2 | swift-nio | `connect` | SocketDescriptor.connect isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 81 | [poll] | Windows | 1 (1 file) | 2 | swift-nio | `POLLERR`, `POLLHUP`, `POLLNVAL`, `POLLRDNORM`, `POLLWRNORM`, `WSAPoll`… | CInterop.PollFD isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 82 | [send and receive] | Windows | 1 (1 file) | 2 | swift-nio | `recv`, `send` | SocketDescriptor.receive isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 83 | [socket] | Windows | 1 (1 file) | 2 | swift-nio | `socket` | SocketDescriptor.open isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 84 | __time64_t | Windows | 1 (1 file) | 2 | swift-foundation, swift-log | `__time64_t` | System's implementation uses it; no public declaration names it |
| 85 | calloc | Windows | 1 (1 file) | 2 | swift-foundation, swift-testing | `calloc` | Memory.allocateZeroed isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 86 | ConvertSidToStringSidW | Windows | 1 (1 file) | 1 | swift-foundation | `ConvertSidToStringSidW` | System names it nowhere |
| 87 | Internal | Windows | 1 (1 file) | 1 | swift-format | `Internal` | System names it nowhere |
| 88 | LPCWSTR | Windows | 1 (1 file) | 1 | swift-build | `LPCWSTR` | System names it nowhere |
| 89 | MAXSYMLINKS | WASI | 1 (1 file) | 1 | swift-foundation | `MAXSYMLINKS` | SystemConfig.maxSymbolicLinks isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 90 | NAME_MAX | WASI | 1 (1 file) | 1 | swift-testing | `NAME_MAX` | SystemConfig.maxFileNameBytes isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 91 | PIPE_NOWAIT | Windows | 1 (1 file) | 1 | swift-log | `PIPE_NOWAIT` | System names it nowhere |
| 92 | UnmapViewOfFile | Windows | 1 (1 file) | 1 | swift-foundation | `UnmapViewOfFile` | System names it nowhere |
| 93 | [Windows consoles] | Windows | 1 (1 file) | 1 | swiftpm | `ReadConsoleA` | System names it nowhere |
| 94 | [Windows named pipes] | Windows | 1 (1 file) | 1 | swift-subprocess | `FILE_FLAG_FIRST_PIPE_INSTANCE`, `PIPE_READMODE_BYTE`, `PIPE_REJECT_REMOTE_CLIENTS`, `PIPE_WAIT` | System names it nowhere |
| 95 | [getuid] | WASI | 1 (1 file) | 1 | swift-foundation | `getuid` | UserID.real isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 96 | [pipe] | WASI | 1 (1 file) | 1 | swift-testing | `pipe2` | FileDescriptor.pipe isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows) |
| 97 | _time64 | Windows | 1 (1 file) | 1 | swift-log | `_time64` | System names it nowhere |
| 98 | buf | Windows | 1 (1 file) | 1 | swift-argument-parser | `buf` | System's implementation uses it; no public declaration names it |
| 99 | f_frsize | FreeBSD | 1 (1 file) | 1 | swift-foundation | `f_frsize` | System's accessor isn't built on FreeBSD |
| 100 | fseek | Windows | 1 (1 file) | 1 | wasmkit | `fseek` | System names it nowhere |
| 101 | gnu_get_libc_version | Linux | 1 (1 file) | 1 | swift-testing | `gnu_get_libc_version` | System names it nowhere |
| 102 | munmap | WASI | 1 (1 file) | 1 | swift-foundation | `munmap` | MemoryMapping.unmap isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 103 | overwrite | Windows | 1 (1 file) | 1 | swift-foundation | `overwrite` | System's implementation uses it; no public declaration names it |
| 104 | raw | Windows | 1 (1 file) | 1 | swift-subprocess | `raw` | System names it nowhere |
| 105 | timespec_get | Windows | 1 (1 file) | 1 | swift-testing | `timespec_get` | ClockID.currentTimeSpec isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 106 | KERN_PROC_PATHNAME | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `KERN_PROC_PATHNAME` | System names it nowhere |
| 107 | backtrace_async | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `backtrace_async` | System names it nowhere |
| 108 | backtrace | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `backtrace` | CallStack.returnAddresses isn't built on Linux (only Darwin) |
| 109 | copy_file_range | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `copy_file_range` | System names it nowhere |
| 110 | sigabbrev_np | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `sigabbrev_np` | System names it nowhere |
| 111 | sys_signame | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `sys_signame` | System names it nowhere |
| 112 | _NSGetExecutablePath | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `_NSGetExecutablePath` | FilePath.currentExecutable isn't built on Linux (only Darwin) |
| 113 | sysctl | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `sysctl` | SystemControl isn't built on Linux (only Darwin) |
| 114 | fclonefileat | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `fclonefileat` | FileDescriptor.clone isn't built on Linux (only Darwin) |
| 115 | FICLONE | Darwin, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `FICLONE` | FileDescriptor.cloneContents isn't built on Darwin (only Linux, Musl, Android) |
| 116 | label | Linux, Musl, Android, FreeBSD, OpenBSD, WASI | 0 (0 files) | 4 | swift-nio, swift-sdk-generator | `label` | System names it nowhere |
| 117 | ws_col | Linux, Musl, FreeBSD, OpenBSD | 2 (1 file) | 2 | swift-nio | `ws_col` | System names it nowhere |
| 118 | useconds_t | Android, WASI | 2 (1 file) | 2 | swift-sdk-generator | `useconds_t` | System names it nowhere |
| 119 | ai_family | FreeBSD, OpenBSD, Windows | 0 (0 files) | 2 | swift-nio | `ai_family` | System names it nowhere |
| 120 | ai_flags | FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-nio | `ai_flags` | System names it nowhere |
| 121 | [Windows file information] | Windows | 0 (0 files) | 5 | swift-foundation, swift-subprocess | `INVALID_FILE_ATTRIBUTES` | System's implementation uses it; no public declaration names it |
| 122 | SetFileTime | Windows | 2 (1 file) | 4 | swift-foundation, wasmkit | `SetFileTime` | System names it nowhere |
| 123 | FILE_END_OF_FILE_INFO | Windows | 2 (1 file) | 2 | wasmkit | `FILE_END_OF_FILE_INFO` | System's implementation uses it; no public declaration names it |
| 124 | ERROR_INVALID_ACCESS | Windows | 0 (0 files) | 3 | swift-foundation, wasmkit | `ERROR_INVALID_ACCESS` | System names it nowhere |
| 125 | ERROR_INVALID_DATA | Windows | 0 (0 files) | 3 | swift-foundation, wasmkit | `ERROR_INVALID_DATA` | System names it nowhere |
| 126 | ERROR_INVALID_DRIVE | Windows | 0 (0 files) | 3 | swift-foundation, wasmkit | `ERROR_INVALID_DRIVE` | System names it nowhere |
| 127 | msg_hdr | Windows | 0 (0 files) | 3 | swift-nio | `msg_hdr` | System's accessor isn't built on Windows |
| 128 | msg_len | Windows | 2 (2 files) | 3 | swift-nio | `msg_len` | System's accessor isn't built on Windows |
| 129 | sin6_addr | Windows | 0 (0 files) | 3 | swift-nio | `sin6_addr` | System's accessor isn't built on Windows |
| 130 | sin6_family | Windows | 0 (0 files) | 3 | swift-nio | `sin6_family` | System's accessor isn't built on Windows |
| 131 | sin6_flowinfo | Windows | 0 (0 files) | 3 | swift-nio | `sin6_flowinfo` | System's accessor isn't built on Windows |
| 132 | sin6_port | Windows | 0 (0 files) | 3 | swift-nio | `sin6_port` | System's accessor isn't built on Windows |
| 133 | sin6_scope_id | Windows | 0 (0 files) | 3 | swift-nio | `sin6_scope_id` | System's accessor isn't built on Windows |
| 134 | sin_family | Windows | 1 (1 file) | 3 | swift-nio | `sin_family` | System's accessor isn't built on Windows |
| 135 | st_mode | Windows | 0 (0 files) | 3 | llbuild, swift-foundation-icu | `st_mode` | System's accessor isn't built on Windows |
| 136 | sun_family | Windows | 0 (0 files) | 3 | swift-nio | `sun_family` | System's accessor isn't built on Windows |
| 137 | sun_path | Windows | 2 (2 files) | 3 | swift-nio | `sun_path` | System's accessor isn't built on Windows |
| 138 | ss_family | Windows | 1 (1 file) | 1 | swift-nio | `ss_family` | System's accessor isn't built on Windows |
| 139 | ERROR_BAD_NETPATH | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_BAD_NETPATH` | System names it nowhere |
| 140 | ERROR_BAD_NET_NAME | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_BAD_NET_NAME` | System names it nowhere |
| 141 | ERROR_CANCELLED | Windows | 0 (0 files) | 2 | swift-foundation | `ERROR_CANCELLED` | System names it nowhere |
| 142 | POSIXErrorCode | Windows | 2 (1 file) | 2 | swift-foundation | `POSIXErrorCode` | CInterop.POSIXErrorCode isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 143 | ERROR_CANNOT_MAKE | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_CANNOT_MAKE` | System names it nowhere |
| 144 | ERROR_CURRENT_DIRECTORY | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_CURRENT_DIRECTORY` | System names it nowhere |
| 145 | ERROR_DRIVE_LOCKED | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_DRIVE_LOCKED` | System names it nowhere |
| 146 | ERROR_FAIL_I24 | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_FAIL_I24` | System names it nowhere |
| 147 | ERROR_FILE_SYSTEM_LIMITATION | Windows | 0 (0 files) | 2 | swift-foundation | `ERROR_FILE_SYSTEM_LIMITATION` | System names it nowhere |
| 148 | FILE_RENAME_INFO | Windows | 2 (1 file) | 2 | swift-foundation | `FILE_RENAME_INFO` | System's implementation uses it; no public declaration names it |
| 149 | ERROR_INVALID_BLOCK | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_INVALID_BLOCK` | System names it nowhere |
| 150 | ERROR_INVALID_STARTING_CODESEG | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_INVALID_STARTING_CODESEG` | System names it nowhere |
| 151 | ERROR_INVALID_TARGET_HANDLE | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_INVALID_TARGET_HANDLE` | System names it nowhere |
| 152 | ERROR_LOCK_FAILED | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_LOCK_FAILED` | System names it nowhere |
| 153 | ERROR_MAX_THRDS_REACHED | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_MAX_THRDS_REACHED` | System names it nowhere |
| 154 | ERROR_NETWORK_ACCESS_DENIED | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_NETWORK_ACCESS_DENIED` | System names it nowhere |
| 155 | ERROR_NO_MORE_FILES | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_NO_MORE_FILES` | System names it nowhere |
| 156 | ERROR_SEEK_ON_DEVICE | Windows | 0 (0 files) | 2 | wasmkit | `ERROR_SEEK_ON_DEVICE` | System names it nowhere |
| 157 | ERROR_WRITE_PROTECT | Windows | 2 (1 file) | 2 | wasmkit | `ERROR_WRITE_PROTECT` | System names it nowhere |
| 158 | GetCurrentDirectoryW | Windows | 0 (0 files) | 2 | swift-foundation | `GetCurrentDirectoryW` | System names it nowhere |
| 159 | SetCurrentDirectoryW | Windows | 2 (1 file) | 2 | swift-foundation | `SetCurrentDirectoryW` | System names it nowhere |
| 160 | JOBOBJECT_EXTENDED_LIMIT_INFORMATION | Windows | 0 (0 files) | 2 | swift-subprocess, swift-tools-support-core | `JOBOBJECT_EXTENDED_LIMIT_INFORMATION` | System's implementation uses it; no public declaration names it |
| 161 | LC_ALL | Windows | 0 (0 files) | 2 | swift-foundation | `LC_ALL` | CLocale.Category.all isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 162 | TOKEN_ELEVATION | Windows | 1 (1 file) | 1 | swift-foundation | `TOKEN_ELEVATION` | System's implementation uses it; no public declaration names it |
| 163 | setlocale | Windows | 1 (1 file) | 1 | swift-foundation | `setlocale` | CLocale.globalName isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 164 | STARTUPINFOW | Windows | 0 (0 files) | 2 | swift-subprocess, swift-tools-support-core | `STARTUPINFOW` | System's implementation uses it; no public declaration names it |
| 165 | [Windows process creation] | Windows | 0 (0 files) | 2 | swift-subprocess, swift-tools-support-core | `CREATE_UNICODE_ENVIRONMENT`, `CreateProcessWithLogonW`, `DeleteProcThreadAttributeList`, `EXTENDED_STARTUPINFO_PRESENT`, `InitializeProcThreadAttributeList`, `LOGON_WITH_PROFILE`… | System names it nowhere |
| 166 | [environment block] | Windows | 1 (1 file) | 2 | swift-foundation, swift-subprocess | `FreeEnvironmentStringsW` | System's implementation uses it; no public declaration names it |
| 167 | ULONGLONG | Windows | 1 (1 file) | 1 | swift-foundation | `ULONGLONG` | System's implementation uses it; no public declaration names it |
| 168 | ULONG_PTR | Windows | 1 (1 file) | 1 | swift-tools-support-core | `ULONG_PTR` | System's implementation uses it; no public declaration names it |
| 169 | st_dev | Windows | 0 (0 files) | 2 | llbuild | `st_dev` | System's accessor isn't built on Windows |
| 170 | st_ino | Windows | 0 (0 files) | 2 | llbuild | `st_ino` | System's accessor isn't built on Windows |
| 171 | st_size | Windows | 2 (1 file) | 2 | llbuild | `st_size` | System's accessor isn't built on Windows |
| 172 | BELOW_NORMAL_PRIORITY_CLASS | Windows | 0 (0 files) | 1 | sourcekit-lsp | `BELOW_NORMAL_PRIORITY_CLASS` | System names it nowhere |
| 173 | ERROR_DISK_RESOURCES_EXHAUSTED | Windows | 0 (0 files) | 1 | swift-foundation | `ERROR_DISK_RESOURCES_EXHAUSTED` | System names it nowhere |
| 174 | ERROR_LABEL_TOO_LONG | Windows | 0 (0 files) | 1 | swift-foundation | `ERROR_LABEL_TOO_LONG` | System names it nowhere |
| 175 | FILE_NAME_NORMALIZED | Windows | 1 (1 file) | 1 | swift-foundation | `FILE_NAME_NORMALIZED` | System names it nowhere |
| 176 | FindClose | Windows | 0 (0 files) | 1 | swift-foundation | `FindClose` | System's implementation uses it; no public declaration names it |
| 177 | FindExInfoBasic | Windows | 0 (0 files) | 1 | swift-foundation | `FindExInfoBasic` | System names it nowhere |
| 178 | FindExSearchNameMatch | Windows | 0 (0 files) | 1 | swift-foundation | `FindExSearchNameMatch` | System names it nowhere |
| 179 | FindFirstFileExW | Windows | 0 (0 files) | 1 | swift-foundation | `FindFirstFileExW` | System names it nowhere |
| 180 | FindNextFileW | Windows | 0 (0 files) | 1 | swift-foundation | `FindNextFileW` | System's implementation uses it; no public declaration names it |
| 181 | WIN32_FIND_DATAW | Windows | 1 (1 file) | 1 | swift-foundation | `WIN32_FIND_DATAW` | System's implementation uses it; no public declaration names it |
| 182 | IDLE_PRIORITY_CLASS | Windows | 0 (0 files) | 1 | sourcekit-lsp | `IDLE_PRIORITY_CLASS` | System names it nowhere |
| 183 | NORMAL_PRIORITY_CLASS | Windows | 1 (1 file) | 1 | sourcekit-lsp | `NORMAL_PRIORITY_CLASS` | System names it nowhere |
| 184 | MAP_FAILED | WASI | 0 (0 files) | 1 | swift-foundation | `MAP_FAILED` | MemoryMapping.init isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 185 | MAP_PRIVATE | WASI | 0 (0 files) | 1 | swift-foundation | `MAP_PRIVATE` | MemoryMapping.Options.private isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 186 | PROT_READ | WASI | 0 (0 files) | 1 | swift-foundation | `PROT_READ` | MemoryMapping.Protection.read isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 187 | mmap | WASI | 1 (1 file) | 1 | swift-foundation | `mmap` | MemoryMapping isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 188 | PSID | Windows | 0 (0 files) | 1 | swift-subprocess | `PSID` | System's implementation uses it; no public declaration names it |
| 189 | UNLEN | Windows | 1 (1 file) | 1 | swift-subprocess | `UNLEN` | System names it nowhere |
| 190 | WSAEFAULT | Windows | 0 (0 files) | 1 | swift-nio | `WSAEFAULT` | System names it nowhere |
| 191 | [Windows delete] | Windows | 0 (0 files) | 1 | swift-nio | `FILE_DISPOSITION_INFO_EX` | System's implementation uses it; no public declaration names it |
| 192 | cmsg_len | Windows | 1 (1 file) | 1 | swift-nio | `cmsg_len` | System's accessor isn't built on Windows |
| 193 | [file type bits] | Windows | 0 (0 files) | 1 | swift-foundation-icu | `S_IFDIR`, `S_IFMT` | FileType.directory isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 194 | [stat] | Windows | 1 (1 file) | 1 | swift-foundation-icu | `stat` | Stat.init isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 195 | [gettimeofday] | Windows | 0 (0 files) | 1 | swift-nio | `timeval` | CInterop.TimeVal isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 196 | l_linger | Windows | 0 (0 files) | 1 | swift-nio | `l_linger` | System's accessor isn't built on Windows |
| 197 | l_onoff | Windows | 0 (0 files) | 1 | swift-nio | `l_onoff` | System's accessor isn't built on Windows |
| 198 | tv_usec | Windows | 1 (1 file) | 1 | swift-nio | `tv_usec` | System's accessor isn't built on Windows |

## Queued work

System or adopter work already identified, with where; ranked by the sites each holds (*+n*: sites it also holds whose category is another).

| Entry | Sites | Work | Where | Ends | Repositories |
|---|---:|---|---|---|---|
| N1: fts on Linux in swift-foundation | 13 | System and adopter | Prototype/Coverage5/REPORT.md, Needs design N1 (its rank 2) | DirectoryWalk's same-device option, then Foundation's comparison run on Linux | swift-foundation |
| N2: the thread API on WASI without threads | 3 (+1) | System | Prototype/Coverage5/REPORT.md, Needs design N2 (its rank 6) | a decision, and System's API for it on WASI | swift-async-algorithms, swift-certificates, swift-nio |
| N3: pseudoterminals on OpenBSD | 2 (+1) | System | Prototype/Coverage5/REPORT.md, Needs design N3 (its rank 9) | TerminalDescriptor.openPseudoterminal() on OpenBSD | swift-build, swift-testing |
| E2: swift-syntax's memcmp in SyntaxText.swift | 0 | adopter | Michael's answers of 2026-10-05, in the coordinator's correction to recollapse-a, recollapse-b and ledger | SwiftSyntax calling Memory.compare(_:_:) | — |
| E4: SWBLibc's and TSCLibc's Unix re-exports | 0 | adopter | Michael's answers of 2026-10-05, in the coordinator's correction to recollapse-a, recollapse-b and ledger | the Unix re-exports gone, with their importers on System | — |
| N4: a byte view on FilePath.Component | 0 | System | Prototype/Coverage5/REPORT.md, Needs design N4 (its rank 11) | the view | — |
| N5: collation | 0 | System | Prototype/Coverage5/REPORT.md, Needs design N5 (its rank 14) | a decision | — |
| N6: wide characters | 0 | System | Prototype/Coverage5/REPORT.md, Needs design N6 (its rank 15) | a decision | — |
| N7: System's ExitStatus against swift-testing's | 0 | System | Prototype/Coverage5/REPORT.md, Needs design N7 (its rank 16) | a decision | — |
| N9: ACLs | 0 | System | Prototype/Coverage5/REPORT.md, Needs design N9 (its rank 18) | an ACL type | — |

## Exceptions

Michael's explicit list: sites approved to stay on C.

| Entry | Sites | Reason | Approved | Ends | Repositories |
|---|---:|---|---|---|---|
| E1: the swift repo's standard library | 33 | Code below System, which can't be imported there: the standard library (stdlib/public/Synchronization, stdlib/public/libexec/swift-backtrace, stdlib/public/Concurrency and the rest of stdlib/). | Michael, 2026-10-05 | System moving beneath them in the toolchain. What proper layering would take is an open investigation. | swift |

## Undecided

Sites whose status is Michael's to decide: the entries below, and every import of a module modules.ini lists under [report], which doesn't count toward the floor yet.

| Entry | Sites | Reason | Decided | Repositories |
|---|---:|---|---|---|
| E6: swift-corelibs-foundation and swift-corelibs-xctest | 96 | No recorded reason for deferring them; their status is undecided. | Michael, 2026-10-05: undecided, not deferred | swift-corelibs-foundation, swift-corelibs-xctest |

Reported modules (modules.ini [report]), sites by module: `os` 27.

## Not System's: mapping.ini's lane verdicts, unreviewed

mapping.ini's 14 `wrap = no` entries were written by lanes and never reviewed by Michael: lane proposals, not decisions. Each is listed with the sites it holds; the Mach-O and ar.h ones are System gaps now (`exceptions.ini` E3).

| mapping.ini entry | Category | Sites | Symbols |
|---|---|---:|---|
| [Windows window messages] | not System's (lane verdict, unreviewed) | 0 | `EnumWindows`, `GetWindowThreadProcessId`, `SendMessage`, `WM_CLOSE`, `HWND`, `_subprocess_windows_send_vm_close` |
| [autoreleasepool] | not System's (lane verdict, unreviewed) | 0 | `autoreleasepool` |
| [Mach-O file format] | System gap (E3) | 58 | `mach_header`, `mach_header_64`, `load_command`, `segment_command`, `segment_command_64`, `section`… |
| [Mach-O architecture names] | System gap (E3) | 3 | `macho_arch_name_for_mach_header`, `macho_cpu_type_for_arch_name`, `macho_arch_name_for_cpu_type` |
| [Dispatch] | not System's (lane verdict, unreviewed) | 0 | `DispatchQueue`, `DispatchGroup`, `DispatchData`, `DispatchSemaphore`, `DispatchTime`, `DispatchSpecificKey`… |
| [Security keychain] | not System's (lane verdict, unreviewed) | 0 | `SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `SecItemUpdate`, `kSecAttrAccount`, `kSecAttrCreationDate`… |
| [Security identities and keys] | not System's (lane verdict, unreviewed) | 0 | `SecIdentityRef`, `SecCertificateRef`, `SecKeyRef`, `SecCertificateCopyData`, `SecIdentityCopyCertificate`, `SecIdentityCopyPrivateKey`… |
| [CoreFoundation] | not System's (lane verdict, unreviewed) | 0 | `CFGetTypeID`, `CFStringRef`, `CFTypeRef`, `CFDataRef`, `CFDictionaryRef`, `CFErrorRef`… |
| [CryptoKit] | not System's (lane verdict, unreviewed) | 0 | `ECDSASignature`, `HashFunction`, `P256`, `PrivateKey`, `PublicKey`, `SHA256`… |
| [os_log and signposts] | not System's (lane verdict, unreviewed) | 0 | `OSSignpostID`, `os_signpost_type_t`, `OSLog`, `OSLogPrivacy`, `OSSignposter`, `OSSignpostIntervalState` |
| [other frameworks' names] | not System's (lane verdict, unreviewed) | 0 | `Logger`, `NSDictionary`, `CFRunLoopStop` |
| [Objective-C runtime] | not System's (lane verdict, unreviewed) | 0 | `NSObject`, `description` |
| [SQLite] | not System's (lane verdict, unreviewed) | 0 | `sqlite3_bind_blob`, `sqlite3_bind_int64`, `sqlite3_bind_null`, `sqlite3_bind_text`, `sqlite3_busy_timeout`, `sqlite3_clear_bindings`… |
| [ar archive header] | System gap (E3) | 3 | `ar_hdr`, `ar_name`, `ar_size`, `SARMAG`, `AR_EFMT1`, `ARMAG`… |

Imports of the modules modules.ini lists as not System's (reviewed by Michael, 2026-10-05: libraries, not OS interfaces) aren't sites: `Dispatch` 215, `ObjectiveC` 5.

## Standard library

Sites whose C names that System doesn't cover all have the standard library's answer in mapping.ini (`swift`): adopter work, with the answer given.

| Answer | Sites | Repositories |
|---|---:|---|
| [malloc] | 11 | sourcekit-lsp, swift-crypto, swift-foundation |
| [C scalar types] | 4 | swift-foundation, swift-nio |
| [Win32 scalar types] | 4 | swift-nio, wasmkit |
| [memory copies] | 1 | swift-foundation |
| [mutexes] | 1 | swift-subprocess |
| [termination] | 1 | swift-testing |

## Excluded

Not sites at all; they count nowhere.

| Entry | Sites | Reason | Decided | Repositories |
|---|---:|---|---|---|
| E7d: Foundation's #if FOUNDATION_FRAMEWORK code | 22 | Apple's internal build only. | Michael, 2026-10-05 | swift-foundation |
| E7c: SwiftPM's Fixtures/ and TestObservation.swift's generated text | 5 | Test data. | Michael, 2026-10-05 | swiftpm |
| E7a: swift-integration-tests | 0 | Its imports are what it tests. | Michael, 2026-10-05 | — |
| E7b: swift-format's OrderedImportsTests string literals | 0 | Text, not imports. (The scan blanks string literals, so it finds none there anyway.) | Michael, 2026-10-05 | — |

## Every site

<details><summary>By repository: file, lines and what they import, platforms, category, holder and reason; the unexplained sites are in the table above</summary>

**cmark**, at `../ecosystem/cmark` @ `0c8947bb`: no sites.

**indexstore-db**, at `../adopters/indexstore-db` `migrate-all` @ `96d2a952`: 5 sites, 1 of them unexplained (above).

- `Sources/ISDBTibs/TibsToolchain.swift` 17 `WinSDK` (Windows): **System gap**: [PATH_MAX] (MAX_PATH: Windows)
- `Sources/IndexStore/dlopen.swift` 16 `CRT`, 17 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); LoadLibraryW (LoadLibraryW: Windows)
- `Sources/index-dump/LibIndexStoreProvider.swift` 16 `WinSDK` (Windows): **System gap**: [PATH_MAX] (MAX_PATH: Windows); UINT (UINT: Windows)

**llbuild**, at `../adopters/swift-llbuild` `migrate-unix` @ `314f1127`: 12 sites, 10 of them unexplained (above).

- `products/llbuildSwift/BuildSystemBindings.swift` 12 `ucrt`, 13 `WinSDK` (Windows): **System gap**: st_dev (st_dev: Windows); st_ino (st_ino: Windows); st_mode (st_mode: Windows); st_size (st_size: Windows)

**sourcekit-lsp**, at `../adopters/sourcekit-lsp` `migrate-all` @ `79583cc1`: 19 sites, 6 of them unexplained (above).

- `Sources/SKTestSupport/FindTool.swift` 20 `WinSDK` (Windows): **System gap**: [PATH_MAX] (MAX_PATH: Windows)
- `Sources/SKUtilities/LineTable.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SemanticIndex/UpdateIndexStoreTaskDescription.swift` 31 `WinSDK` (Windows): **System gap**: ERROR_FILENAME_EXCED_RANGE (ERROR_FILENAME_EXCED_RANGE: Windows)
- `Sources/SourceKitD/SKDRequestArray.swift` 16 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SourceKitD/SKDRequestDictionary.swift` 17 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SourceKitD/SKDResponse.swift` 17 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SourceKitD/SKDResponseArray.swift` 16 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SourceKitD/SKDResponseDictionary.swift` 16 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SourceKitD/dlopen.swift` 18 `CRT`, 19 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); LoadLibraryW (LoadLibraryW: Windows)
- `Sources/SwiftSourceKitPlugin/SKDRequestDictionaryReader.swift` 17 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/SwiftSourceKitPlugin/SKDResponse.swift` 17 `CRT` (Windows): **standard library**: [malloc] (free: Windows)
- `Sources/TSCExtensions/Process+Run.swift` 25 `WinSDK` (Windows): **System gap**: BELOW_NORMAL_PRIORITY_CLASS (BELOW_NORMAL_PRIORITY_CLASS: Windows); [Win32 errors] (GetLastError: Windows); IDLE_PRIORITY_CLASS (IDLE_PRIORITY_CLASS: Windows); NORMAL_PRIORITY_CLASS (NORMAL_PRIORITY_CLASS: Windows); [signal numbers] (SIGABRT, SIGINT: Windows)

**swift**, at `../ecosystem/swift` @ `dd2b2263`, its sparse checkout (`include/swift/Threading`, `lib/Threading`, `stdlib/include`, `stdlib/public/Concurrency`, `stdlib/public/Platform`, `stdlib/public/SwiftShims`, `stdlib/public/Synchronization`, `stdlib/public/core`, `stdlib/public/libexec`, `stdlib/public/runtime`, `stdlib/public/stubs`, `stdlib/public/threading`, `utils/update_checkout`): 33 sites.

- `stdlib/public/Concurrency/AsyncStreamBuffer.swift` 18 `Darwin` (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **exception** (E1): the swift repo's standard library
- `stdlib/public/Platform/ucrt.swift` 13 `ucrt`, re-exported (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/Synchronization/Mutex/DarwinImpl.swift` 13 `Darwin` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/Synchronization/Mutex/FreeBSDImpl.swift` 13 `Glibc` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/Synchronization/Mutex/LinuxImpl.swift` 20 `Android`, 22 `Musl`, 24 `Glibc` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/Synchronization/Mutex/OpenBSDImpl.swift` 13 `Glibc` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/Synchronization/Mutex/WindowsImpl.swift` 13 `WinSDK` (submodule) (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/JSON.swift` 14 `Darwin`, 16 `Glibc`, 18 `Musl`, 20 `CRT` (Darwin, Linux, Musl, FreeBSD, OpenBSD, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/TargetLinux.swift` 21 `Glibc`, 23 `Musl` (Linux, Musl): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/TargetMacOS.swift` 20 `Darwin`, 21 `Darwin` (submodule) (Darwin): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/TargetWindows.swift` 20 `WinSDK`, 21 `CRT` (Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/Timing.swift` 2 `Darwin`, 4 `Glibc`, 6 `Musl`, 8 `WinSDK` (Darwin, Linux, Musl, FreeBSD, OpenBSD, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/Utils.swift` 18 `CRT`, 19 `WinSDK`, 21 `Darwin`, 23 `Glibc`, 25 `Musl` (Darwin, Linux, Musl, FreeBSD, OpenBSD, Windows): **exception** (E1): the swift repo's standard library
- `stdlib/public/libexec/swift-backtrace/main.swift` 16 `Darwin`, 18 `Glibc`, 20 `Musl`, 22 `CRT`, 23 `WinSDK` (Darwin?, Linux?, Musl?, Windows?): **exception** (E1): the swift repo's standard library

**swift-argument-parser**, at `../adopters/swift-argument-parser` `migrate-all` @ `22831ad7`: 7 sites, 4 of them unexplained (above).

- `Sources/ArgumentParser/Utilities/Mutex.swift` 15 `WinSDK` (Windows): **System gap**: buf (buf: Windows)
- `Sources/ArgumentParser/Utilities/Platform.swift` 22 `CRT`, 129 `WinSDK` (scoped) (Windows): **System gap**: ERROR_BAD_ARGUMENTS (ERROR_BAD_ARGUMENTS: Windows)

**swift-asn1**, at `../ecosystem/swift-asn1` @ `a54383ad`: no sites.

**swift-async-algorithms**, at `../adopters/swift-async-algorithms` `migrate-all` @ `d4ad19b0`: 5 sites, 4 of them unexplained (above).

- `Sources/AsyncSequenceValidation/TaskDriver.swift` 17 marker: PThread on WASI without threads (wasip1, whose SDK has wasi_pthread), … (WASI): **queued** (N2): N2 (pthread_create, pthread_join, pthread_t: WASI)

**swift-atomics**, at `../ecosystem/swift-atomics` @ `0442cb5a`: no sites.

**swift-build**, at `../adopters/swift-build` `migrate-all` @ `1dce162d`: 87 sites, 7 of them unexplained (above).

- `Sources/MockToolchainCASPlugin/MockCASFileLock.swift` 17 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/SWBCore/SpecImplementations/Tools/SwiftCompiler.swift` 26 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBTaskExecution/DynamicTaskSpecs/CompilationCachingUploader.swift` 20 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/Architecture.swift` 23-25 `MachO` (scoped), 1 marker ×3 (Darwin): **System gap**: E3 (macho_arch_name_for_cpu_type, macho_arch_name_for_mach_header, macho_cpu_type_for_arch_name: Darwin)
- `Sources/SWBUtil/HeavyCache.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/Library.swift` 18 marker: dlopen in the caller's image. `Library.open` is emitted into its calle… (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: E5 (dlopen: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/SWBUtil/Library.swift` 21 `Darwin` (scoped) (Darwin): **System gap**: E5 (dlopen: Darwin)
- `Sources/SWBUtil/Library.swift` 23 `Glibc` (scoped) (Linux, FreeBSD, OpenBSD): **System gap**: E5 (dlopen: Linux, FreeBSD, OpenBSD)
- `Sources/SWBUtil/Library.swift` 25 `Musl` (scoped) (Musl): **System gap**: E5 (dlopen: Musl)
- `Sources/SWBUtil/Library.swift` 27 `Android` (scoped) (Android): **System gap**: E5 (dlopen: Android)
- `Sources/SWBUtil/MachO.swift` 22-37 `MachO` (scoped), 1 marker ×16 (Darwin): **System gap**: E3 (build_version_command, dylib, dylib_command…: Darwin)
- `Sources/SWBUtil/MachO.swift` 38 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_MAGIC, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 39 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_CIGAM, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 40 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_MAGIC_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 41 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_CIGAM_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 42 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_OBJECT, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 43 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_EXECUTE, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 44 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 45 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (MH_BUNDLE, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 46 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_SEGMENT, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 47 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_SEGMENT_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 48 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_ID_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 49 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_LOAD_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 50 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_LOAD_WEAK_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 51 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_REEXPORT_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 52 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_LAZY_LOAD_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 53 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_LOAD_UPWARD_DYLIB, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 54 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_UUID, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 55 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_RPATH, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 56 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_BUILD_VERSION, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 57 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_VERSION_MIN_MACOSX, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 58 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_VERSION_MIN_IPHONEOS, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 59 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_VERSION_MIN_TVOS, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 60 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (LC_VERSION_MIN_WATCHOS, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 61 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (FAT_MAGIC, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 62 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (FAT_CIGAM, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 63 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (FAT_MAGIC_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 64 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (FAT_CIGAM_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 65 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (SYMDEF, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 66 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (SYMDEF_SORTED, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 67 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (SYMDEF_64, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 68 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (SYMDEF_64_SORTED, build_version_command, dylib…: Darwin)
- `Sources/SWBUtil/MachO.swift` 70 `Darwin` (scoped), 1 marker (Darwin): **System gap**: E3 (vm_prot_t: Darwin)
- `Sources/SWBUtil/MachO.swift` 72-74 `Darwin` (scoped), 1 marker ×3 (Darwin): **System gap**: E3 (AR_EFMT1, SARMAG, ar_hdr…: Darwin)
- `Sources/SWBUtil/OSLog.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/PathWindows.swift` 14 `WinSDK` (Windows): **System gap**: [Win32 errors] (FACILITY_WIN32, GetLastError: Windows); [Windows local memory] (LocalFree: Windows); [Windows paths] (PATHCCH_ALLOW_LONG_PATHS: Windows)
- `Sources/SWBUtil/Win32.swift` 14 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); LPCWSTR (LPCWSTR: Windows); [PATH_MAX] (MAX_PATH: Windows)
- `Sources/SWBUtil/Win32Error.swift` 14 `WinSDK` (Windows): **System gap**: [Win32 errors] (FORMAT_MESSAGE_ALLOCATE_BUFFER, FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS: Windows); [Windows local memory] (LocalFree: Windows)
- `Sources/SWBWindowsPlatform/KnownFolders.swift` 17 `WinSDK` (Windows): **System gap**: [Windows known folders] (CoTaskMemFree, FOLDERID_ProgramFilesX86, FOLDERID_UserProgramFiles…: Windows)
- `Tests/SWBBuildSystemTests/MergeableLibrariesBuildOperationTests.swift` 24 `MachO` (scoped), 1 marker (Darwin): **System gap**: E3 (load_command: Darwin)
- `Tests/SWBUtilTests/MachOTests.swift` 22-29 `MachO` (scoped), 1 marker ×8 (Darwin): **System gap**: E3 (FAT_CIGAM, FAT_CIGAM_64, LC_MAIN…: Darwin)
- `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` 21 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows DLLs] (GetModuleHandleW: Windows); UINT (UINT: Windows)
- `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` 127 marker: TerminalDescriptor.openPseudoterminal() on OpenBSD (openpty, fcntl, F_… (OpenBSD): **queued** (N3): N3 (openpty: OpenBSD)
- `Tests/SwiftBuildTests/ConsoleCommands/ServiceConsoleTests.swift` 19 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows process exit] (RegisterWaitForSingleObject, UnregisterWait, WT_EXECUTELONGFUNCTION…: Windows)

**swift-certificates**, at `../adopters/swift-certificates` `migrate-all` @ `c310582c`: 5 sites, 2 of them unexplained (above).

- `Sources/X509/Lock.swift` 24 `WASILibc`, 1 marker (WASI): **queued** (N2): N2 (pthread_mutex_t: WASI)
- `Sources/X509/Verifier/RFC5280/URIConstraints.swift` 21 `WinSDK` (Windows): **System gap**: [address families] (AF_INET, AF_INET6: Windows); [Winsock addresses] (IN6_ADDR, IN_ADDR: Windows)
- `Sources/X509/Verifier/ServerIdentityPolicy.swift` 26 `WinSDK` (Windows): **System gap**: [address families] (AF_INET, AF_INET6: Windows); [sockaddr types] (in6_addr, in_addr: Windows); [inet_ntop and inet_pton] (inet_pton: Windows); [string functions] (memcmp: Windows)

**swift-collections**, at `../ecosystem/swift-collections` @ `c11818f3`: no sites.

**swift-corelibs-foundation**, at `../ecosystem/swift-corelibs-foundation` @ `6f21ccf1`: 94 sites.

- `Sources/Foundation/CGFloat.swift` 11 `Android` (Android): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/FileHandle.swift` 18 `Darwin`, 23 `Glibc`, 28 `Musl`, 33 `WASILibc`, 38 `Android`, 45-46 `WinSDK` (scoped) ×2 (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/FileManager+POSIX.swift` 11 `Android`, 24 `WASILibc` (Android, WASI): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/FileManager+Win32.swift` 13 `WinSDK` (scoped), 14 `WinSDK` (Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/FileManager.swift` 18 `CRT`, 19 `WinSDK`, 23 `WASILibc`, 25 `Bionic` (Android, WASI, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/FoundationErrors.swift` 11 `WinSDK` (Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/Host.swift` 12 `WinSDK`, 16 `Android` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSCFTypeShims.swift` 11 `Darwin` (Darwin): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSData.swift` 15 `Android` (Android): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSError.swift` 14 `Darwin`, 16 `Glibc`, 18 `CRT`, 20 `Android` (Darwin, Linux, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSLock.swift` 13 `Glibc`, 15 `Bionic`, 19 `WinSDK` (Linux, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSPathUtilities.swift` 12 `WinSDK`, 14 `Android`, 16 `WASILibc` (Android, WASI, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSPlatform.swift` 14 `Android`, 19 `WinSDK` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSSwiftRuntime.swift` 17 `Darwin`, re-exported, 19 `Glibc`, re-exported, 21 `Musl`, re-exported, 23 `Bionic`, re-exported, 25 `WASILibc`, re-exported, 27 `CRT`, re-exported, 35 `WinSDK` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/NSURL.swift` 13 `WinSDK`, 20 `Darwin`, 22 `Glibc`, 24 `Musl`, 26 `Bionic` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/Port.swift` 104 `Darwin`, 110 `Glibc`, 116 `Musl`, 122 `Glibc`, 130 `Android`, 138 `WinSDK` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/Process.swift` 13 `WinSDK`, 14-16 `WinSDK` (scoped) ×3, 20 `Darwin`, 22 `Android` (Darwin, Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/Thread.swift` 12 `WinSDK`, 16 `Glibc`, 18 `Musl`, 20 `Bionic` (Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Foundation/WinSDK+Extensions.swift` 10 `WinSDK` (Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/FoundationNetworking/HTTPCookie.swift` 17 `WinSDK`, 19 `Android` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/Testing/Testing.swift` 11 `Glibc`, 13 `Musl`, 15 `Bionic`, 17 `WASILibc`, 19 `CRT` (Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/XCTest/Private/PrintObserver.swift` 15 `Glibc` (Linux, FreeBSD, OpenBSD): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/XCTest/Public/XCTestMain.swift` 28 `Darwin`, 30 `Glibc` (Darwin, Linux, FreeBSD, OpenBSD): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/plutil/main.swift` 16 `Darwin`, 19 `Glibc`, 22 `Musl`, 25 `Bionic`, 27 `CRT` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Sources/xdgTestHelper/main.swift` 21 `WinSDK`, 23 `Android` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/FTPServer.swift` 15 `Glibc`, 17 `Darwin`, 19 `Android` (Darwin, Linux, Android, FreeBSD, OpenBSD): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/HTTPServer.swift` 18 `CRT`, 19 `WinSDK`, 21 `Darwin`, 23 `Glibc`, 25 `Android` (Darwin, Linux, Android, FreeBSD, OpenBSD, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/TestFileHandle.swift` 21 `WinSDK`, 23 `Android` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/TestNSData.swift` 14 `Android` (Android): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/TestProcess.swift` 12 `Android` (Android): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/TestSocketPort.swift` 10 `WinSDK`, 12 `Android` (Android, Windows): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest
- `Tests/Foundation/TestURL.swift` 11 `Android` (Android): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest

**swift-corelibs-xctest**, at `../adopters/swift-corelibs-xctest` `migrate-darwin` @ `80a3f954`: 2 sites.

- `Sources/XCTest/Public/XCTestMain.swift` 28 `Darwin`, 30 `Glibc` (Darwin, Linux, FreeBSD, OpenBSD): **undecided** (E6): swift-corelibs-foundation and swift-corelibs-xctest

**swift-crypto**, at `../adopters/swift-crypto` `migrate-all` @ `ef1e59aa`: 10 sites, 1 of them unexplained (above).

- `Sources/Crypto/Util/SecureBytes.swift` 316 marker: string.h memset_s, on Windows: Memory.secureZero(_:). It's Darwin's on… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: memset_s (memset_s: Windows)
- `Sources/Crypto/Util/Zeroization.swift` 29 marker: string.h memset_s, on Windows: Memory.secureZero(_:). It's Darwin's on…, 38 marker: string.h memset_s, as above, 47 marker: string.h memset_s, as above, 56 marker: string.h memset_s, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: memset_s (memset_s: Windows)
- `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift` 161 marker: stdlib.h malloc and free, on Windows: Memory.allocate(byteCount:) and …, 276 marker: stdlib.h malloc and free, as above, 370 marker: stdlib.h malloc and free, as above (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **standard library**: [malloc] (free, malloc: Windows)
- `Sources/_CryptoExtras/RSA/RSA_boring.swift` 966 marker: string.h memcmp, on Windows: Memory.compare(_:_:) (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: [string functions] (memcmp: Windows)

**swift-docc**, at `../adopters/swift-docc` `migrate-all` @ `4e6a5cea`: 11 sites, 4 of them unexplained (above).

- `Sources/DocCCommandLine/Action/Actions/Convert/ConvertAction.swift` 19 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/DocumentationService/ExternalReferenceResolverServiceClient.swift` 15 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/ConvertActionConverter.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/DocumentationContext.swift` 17 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/Symbol Graph/SymbolGraphLoader.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Servers/FileServer.swift` 20 `WinSDK` (Windows): **System gap**: [Windows known folders] (CoTaskMemFree: Windows)
- `Sources/SwiftDocC/Servers/FileServer.swift` 24 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-docc-symbolkit**, at `../ecosystem/swift-docc-symbolkit` @ `e9a4c0f2`: no sites.

**swift-driver**, at `../adopters/swift-driver` `migrate-unix` @ `e7850bd0`: 14 sites, 11 of them unexplained (above).

- `Sources/SwiftDriver/SwiftScan/Loader.swift` 19 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows DLLs] (GetModuleHandleW: Windows); LoadLibraryW (LoadLibraryW: Windows)
- `Sources/swift-driver/main.swift` 19 `CRT`, 26 `WinSDK` (Windows): **System gap**: [signal numbers] (SIGINT: Windows); UINT (UINT: Windows)

**swift-experimental-string-processing**, at `../ecosystem/swift-experimental-string-processing` @ `db4678c7`: 2 sites.

- `Sources/RegexBenchmark/Utils/Environment.swift` 13 `Darwin` (Darwin): **System gap**: getloadavg (getloadavg: Darwin)
- `Sources/RegexBenchmark/Utils/Environment.swift` 15 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: getloadavg (getloadavg: Linux, FreeBSD, OpenBSD)

**swift-format**, at `../ecosystem/swift-format` @ `b15dd59f`: 3 sites, 2 of them unexplained (above).

- `Sources/SwiftFormat/Utilities/FileIterator.swift` 16 `WinSDK` (Windows): **System gap**: Internal (Internal: Windows)

**swift-foundation**, at `../adopters/swift-foundation` `migrate-unix` @ `d7589041`: 166 sites, 80 of them unexplained (above).

- `Sources/FoundationEssentials/AttributedString/AttributeScope.swift` 68 marker: DynamicLibrary, in the framework build (not built here): dlopen with R…, 70 `Darwin`, 1 marker, 71 `MachO` (submodule), 1 marker (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Calendar/Calendar_Enumerate.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Data/Data+Error.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 27 `Android` (Android): **standard library**: [C scalar types] (SSIZE_MAX: Android)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 29 `Glibc` (Linux, FreeBSD, OpenBSD): **standard library**: [C scalar types] (SSIZE_MAX: Linux)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 33 `CRT`, 34 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 36 `WASILibc` (WASI): **System gap**: MAP_FAILED (MAP_FAILED: WASI); MAP_PRIVATE (MAP_PRIVATE: WASI); PROT_READ (PROT_READ: WASI); mmap (mmap: WASI)
- `Sources/FoundationEssentials/Data/Data+Writing.swift` 31 `Glibc` (FreeBSD, OpenBSD): **System gap**: mktemp (mktemp: FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/Data/Data+Writing.swift` 35 `CRT`, 36 `WinSDK` (Windows): **System gap**: ERROR_FILE_SYSTEM_LIMITATION (ERROR_FILE_SYSTEM_LIMITATION: Windows); FILE_RENAME_INFO (FILE_RENAME_INFO: Windows); [Win32 errors] (GetLastError: Windows); [Windows file information] (INVALID_FILE_ATTRIBUTES: Windows); [string functions] (strlen, wcslen: Windows)
- `Sources/FoundationEssentials/Data/Data.swift` 49 `Glibc` (FreeBSD, OpenBSD): **standard library**: [memory copies] (memcpy, memset: FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/Data/Data.swift` 54 `ucrt` (Windows): **System gap**: [string functions] (memcmp: Windows)
- `Sources/FoundationEssentials/Data/Data.swift` 59 `WASILibc` (WASI): **System gap**: munmap (munmap: WASI)
- `Sources/FoundationEssentials/Data/Data.swift` 78 `WinSDK` (scoped) (Windows): **System gap**: UnmapViewOfFile (UnmapViewOfFile: Windows)
- `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` 24 `ucrt` (Windows): **standard library**: [malloc] (realloc: Windows)
- `Sources/FoundationEssentials/Date.swift` 21 `WinSDK` (Windows): **System gap**: __time64_t (__time64_t: Windows); [Windows errno] (errno_t: Windows)
- `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` 15 `Darwin` (scoped), 1 marker (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` 28 `CRT`, 29 `WinSDK` (Windows): **System gap**: ERROR_CANCELLED (ERROR_CANCELLED: Windows); POSIXErrorCode (POSIXErrorCode: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift` 21 `CRT`, 22 `WinSDK` (Windows): **System gap**: [Windows threads] (CompareObjectHandles: Windows); LARGE_INTEGER (LARGE_INTEGER: Windows); [Windows local memory] (LocalFree: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 24 `Android`, 25 `unistd` (Android): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Android)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 27 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Linux, FreeBSD)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 29 `Musl` (Musl): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Musl)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 31 `CRT`, 32 `WinSDK` (Windows): **System gap**: GetCurrentDirectoryW (GetCurrentDirectoryW: Windows); [Win32 errors] (GetLastError: Windows); [Windows local memory] (LocalFree: Windows); [PATH_MAX] (MAX_PATH: Windows); [Windows handles] (SECURITY_ATTRIBUTES: Windows); SetCurrentDirectoryW (SetCurrentDirectoryW: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 34 `WASILibc` (WASI): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: WASI)
- `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` 27 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: f_frsize (f_frsize: FreeBSD)
- `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` 33 `CRT`, 34 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows file information] (INVALID_FILE_ATTRIBUTES: Windows); SetFileTime (SetFileTime: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift` 20 `CRT`, 21 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); MAXIMUM_REPARSE_DATA_BUFFER_SIZE (MAXIMUM_REPARSE_DATA_BUFFER_SIZE: Windows)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 15 `WinSDK` (Windows): **System gap**: FindClose (FindClose: Windows); FindExInfoBasic (FindExInfoBasic: Windows); FindExSearchNameMatch (FindExSearchNameMatch: Windows); FindFirstFileExW (FindFirstFileExW: Windows); FindNextFileW (FindNextFileW: Windows); [Win32 errors] (GetLastError: Windows); and 1 more
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 121 `Android` (Android): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Android)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 125 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 128 `Musl` (Musl): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Musl)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 130 `WASILibc` (WASI): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: WASI)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 20 `Android` (Android): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Android)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 22 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 24 `Musl` (Musl): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Musl)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 26 `CRT`, 27 `WinSDK` (Windows): **System gap**: COPYFILE2_EXTENDED_PARAMETERS (COPYFILE2_EXTENDED_PARAMETERS: Windows); [Windows adapters] (ERROR_BUFFER_OVERFLOW: Windows); [Win32 errors] (GetLastError: Windows); [Windows local memory] (LocalFree: Windows); [PATH_MAX] (MAX_PATH: Windows); [string functions] (strlen: Windows)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 29 `WASILibc` (WASI): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: WASI)
- `Sources/FoundationEssentials/FileManager/SearchPaths/FileManager+WindowsSearchPaths.swift` 15 `WinSDK` (Windows): **System gap**: [Windows known folders] (CoTaskMemFree, KNOWNFOLDERID, SHGetKnownFolderPath: Windows)
- `Sources/FoundationEssentials/Locale/Locale_Cache.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/AsyncMessage+AsyncSequence.swift` 23 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/NotificationCenter/AsyncMessage.swift` 19 `os` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/MainActorMessage.swift` 19 `os` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/NotificationCenter.swift` 15 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/NotificationCenter/NotificationCenterMessage.swift` 19 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/Platform.swift` 32 `WinSDK` (Windows): **System gap**: LC_ALL (LC_ALL: Windows); [PATH_MAX] (MAX_PATH: Windows); TOKEN_ELEVATION (TOKEN_ELEVATION: Windows); calloc (calloc: Windows); [string functions] (memcmp, strlen: Windows)
- `Sources/FoundationEssentials/Platform.swift` 45 `Android`, 76 `Bionic` (Android): **System gap**: strncasecmp (strncasecmp: Android)
- `Sources/FoundationEssentials/Platform.swift` 49 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: strncasecmp (strncasecmp: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/Platform.swift` 53 `Musl` (Musl): **System gap**: strncasecmp (strncasecmp: Musl)
- `Sources/FoundationEssentials/Platform.swift` 79 `WASILibc` (WASI): **System gap**: strncasecmp (strncasecmp: WASI)
- `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` 29 `WinSDK` (Windows): **System gap**: [environment block] (FreeEnvironmentStringsW: Windows); LoadLibraryW (LoadLibraryW: Windows); [Win32 errors] (NTSTATUS: Windows); ULONGLONG (ULONGLONG: Windows); [string functions] (_strdup, wcslen: Windows)
- `Sources/FoundationEssentials/String/String+Internals.swift` 21 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows local memory] (LocalFree: Windows); [string functions] (wcslen: Windows)
- `Sources/FoundationEssentials/String/String+Path.swift` 24 `WinSDK` (Windows): **System gap**: ConvertSidToStringSidW (ConvertSidToStringSidW: Windows)
- `Sources/FoundationEssentials/String/String+Path.swift` 26 `WASILibc` (WASI): **System gap**: MAXSYMLINKS (MAXSYMLINKS: WASI)
- `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift` 22 `ucrt`, 26 `WinSDK` (Windows): **System gap**: [string functions] (wcslen: Windows)
- `Sources/FoundationEssentials/URL/URL.swift` 629 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/URL/URLComponents_ObjC.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Bridge.swift` 18 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Impl.swift` 20 `WinSDK` (Windows): **System gap**: PCWSTR (PCWSTR: Windows)
- `Sources/FoundationEssentials/URL/URL_Impl.swift` 29 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Swift.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/UUID_Wrappers.swift` 18 `Darwin` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/WinSDK+Extensions.swift` 14 `WinSDK` (Windows): **System gap**: ERROR_BAD_ARGUMENTS (ERROR_BAD_ARGUMENTS: Windows); ERROR_DISK_RESOURCES_EXHAUSTED (ERROR_DISK_RESOURCES_EXHAUSTED: Windows); ERROR_FILENAME_EXCED_RANGE (ERROR_FILENAME_EXCED_RANGE: Windows); ERROR_INVALID_ACCESS (ERROR_INVALID_ACCESS: Windows); ERROR_INVALID_DATA (ERROR_INVALID_DATA: Windows); ERROR_INVALID_DRIVE (ERROR_INVALID_DRIVE: Windows); and 6 more
- `Sources/FoundationInternationalization/Calendar/Calendar_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/ICU/ICU+Foundation.swift` 17 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationInternationalization/Locale/Locale_Bridge.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/Locale/Locale_ICU.swift` 21 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/Locale/Locale_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/TimeZone/TimeZone_Bridge.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/TimeZone/TimeZone_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift` 42 `WASILibc` (WASI): **System gap**: [getuid] (getuid: WASI)
- `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` 23 `CRT` (Windows): **System gap**: LC_ALL (LC_ALL: Windows); setlocale (setlocale: Windows)
- `Tests/FoundationEssentialsTests/ProcessInfoTests.swift` 30 `CRT` (Windows): **System gap**: [getenv] (_putenv: Windows); overwrite (overwrite: Windows)

**swift-foundation-icu**, at `../ecosystem/swift-foundation-icu` @ `e8538d25`: 1 sites.

- `ICUExport/Sources/main.swift` 16 `Darwin` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: [file type bits] (S_IFDIR, S_IFMT: Windows); st_mode (st_mode: Windows); [stat] (stat: Windows)

**swift-llvm-bindings**, at `../ecosystem/swift-llvm-bindings` @ `c1fffb92`: no sites.

**swift-lmdb**, at `../ecosystem/swift-lmdb` @ `866bc256`: no sites.

**swift-log**, at `../adopters/swift-log` `migrate-all` @ `7e49107b`: 8 sites, 6 of them unexplained (above).

- `Sources/Logging/Handlers/StreamLogHandler.swift` 18 `CRT` (Windows): **System gap**: __time64_t (__time64_t: Windows); _time64 (_time64: Windows)
- `Tests/LoggingTests/StreamLogHandlerTest.swift` 23 `WinSDK` (Windows): **System gap**: PIPE_NOWAIT (PIPE_NOWAIT: Windows)

**swift-markdown**, at `../ecosystem/swift-markdown` @ `392b73b8`: no sites.

**swift-nio**, at `../adopters/swift-nio` `migrate-unix` @ `56deee84`: 311 sites, 108 of them unexplained (above).

- `Sources/NIOConcurrencyHelpers/NIOThreadPoolWorkAvailable.swift` 16 `ucrt`, 17 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/NIOConcurrencyHelpers/atomics.swift` 32 `WASILibc` (WASI): **queued** (N2): N2 (sched_yield: WASI)
- `Sources/NIOConcurrencyHelpers/lock.swift` 16 `ucrt`, 17 `WinSDK` (Windows): **System gap**: [Win32 errors] (ERROR_TIMEOUT, GetLastError: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 16 `ucrt` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [protocol levels] (IPPROTO_IP, IPPROTO_IPV6, IPPROTO_TCP…: Windows); [multicast] (IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS…: Windows); [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY, IP_HDRINCL: Windows); [address families] (PF_INET, PF_INET6, PF_UNIX: Windows); [Winsock sockets] (SOCKET: Windows); and 5 more
- `Sources/NIOCore/BSDSocketAPI.swift` 18 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_IP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 19 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_IPV6: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 20 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_TCP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 21 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_UDP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 23 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_ADD_MEMBERSHIP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 24 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_DROP_MEMBERSHIP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 25 `WinSDK` (scoped) (Windows): **System gap**: [IPV6_V6ONLY and IP_HDRINCL] (IP_HDRINCL: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 26 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_IF: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 27 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_LOOP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 28 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_TTL: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 29 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_JOIN_GROUP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 30 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_LEAVE_GROUP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 31 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_HOPS: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 32 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_IF: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 33 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_LOOP: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 36 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 37 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 38 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_UNIX: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 40 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_INET: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 41 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_INET6: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 42 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_UNIX: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 44 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_BROADCAST: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 45 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_ERROR: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_KEEPALIVE: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 47 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_LINGER: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_RCVBUF: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 49 `WinSDK` (scoped) (Windows): **System gap**: [SO_RCVTIMEO and SO_TIMESTAMP] (SO_RCVTIMEO: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 50 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_REUSEADDR: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 51 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_SNDBUF: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 53 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SOL_SOCKET: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 55 `WinSDK` (scoped) (Windows): **System gap**: [TCP_NODELAY] (TCP_NODELAY: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 57 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (SOCKET: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 59 `WinSDK` (scoped) (Windows): **System gap**: [inet_ntop and inet_pton] (inet_ntop: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 60 `WinSDK` (scoped) (Windows): **System gap**: [inet_ntop and inet_pton] (inet_pton: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 62 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 63 `WinSDK` (scoped) (Windows): **System gap**: [Winsock errors] (WSAGetLastError: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 77 `Android` (Android): **System gap**: [socket options] (SO_REUSEPORT: Android)
- `Sources/NIOCore/BSDSocketAPI.swift` 90 `Glibc` (OpenBSD): **System gap**: [socket options] (SO_REUSEPORT: OpenBSD)
- `Sources/NIOCore/BSDSocketAPI.swift` 98 `WASILibc` (WASI): **System gap**: [multicast] (IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS…: WASI); [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY, IP_HDRINCL: WASI); [socket options] (SOL_SOCKET: WASI); [TCP_NODELAY] (TCP_NODELAY: WASI)
- `Sources/NIOCore/IO.swift` 16 `ucrt` (Windows): **System gap**: [Win32 errors] (FORMAT_MESSAGE_ALLOCATE_BUFFER, FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS…: Windows); [Windows local memory] (LocalFree: Windows)
- `Sources/NIOCore/IO.swift` 18 `WinSDK` (scoped) (Windows): **System gap**: [Windows local memory] (LocalFree: Windows)
- `Sources/NIOCore/IO.swift` 19 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (FORMAT_MESSAGE_ALLOCATE_BUFFER: Windows)
- `Sources/NIOCore/IO.swift` 20 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (FORMAT_MESSAGE_FROM_SYSTEM: Windows)
- `Sources/NIOCore/IO.swift` 21 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (FORMAT_MESSAGE_IGNORE_INSERTS: Windows)
- `Sources/NIOCore/IO.swift` 22 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (LANG_NEUTRAL: Windows)
- `Sources/NIOCore/IO.swift` 23 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (SUBLANG_DEFAULT: Windows)
- `Sources/NIOCore/IO.swift` 25 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/NIOCore/Interfaces.swift` 27 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOCore/Interfaces.swift` 28 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOCore/Interfaces.swift` 30 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET_ADDRSTRLEN: Windows)
- `Sources/NIOCore/Interfaces.swift` 31 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET6_ADDRSTRLEN: Windows)
- `Sources/NIOCore/Interfaces.swift` 33 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY: Windows)
- `Sources/NIOCore/Interfaces.swift` 37 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr: Windows)
- `Sources/NIOCore/Interfaces.swift` 38 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in: Windows)
- `Sources/NIOCore/Interfaces.swift` 39 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in6: Windows)
- `Sources/NIOCore/Interfaces.swift` 40 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr_storage] (sockaddr_storage: Windows)
- `Sources/NIOCore/Interfaces.swift` 41 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_un: Windows)
- `Sources/NIOCore/Interfaces.swift` 43 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (UINT8: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 16 `ucrt` (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY, IN6_ADDR, IN_ADDR: Windows); [Windows name resolution] (ADDRINFOW, FreeAddrInfoW, GetAddrInfoW…: Windows); ai_family (ai_family: Windows); sin6_addr (sin6_addr: Windows); sin6_family (sin6_family: Windows); sin6_flowinfo (sin6_flowinfo: Windows); and 7 more
- `Sources/NIOCore/SocketAddresses.swift` 18 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 19 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 21 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET_ADDRSTRLEN: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 22 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET6_ADDRSTRLEN: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 24 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (FreeAddrInfoW: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 25 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (GetAddrInfoW: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 26 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (gai_strerrorA: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 28 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 29 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (ADDRINFOW: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 30 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (IN_ADDR: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 31 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (IN6_ADDR: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 33 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 35 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in6: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 36 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr_storage] (sockaddr_storage: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 37 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_un: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 39 `WinSDK` (scoped) (Windows): **standard library**: [C scalar types] (u_short: Windows)
- `Sources/NIOCore/SocketAddresses.swift` 74 `Glibc` (FreeBSD, OpenBSD): **System gap**: ai_family (ai_family: FreeBSD, OpenBSD); ai_flags (ai_flags: FreeBSD, OpenBSD)
- `Sources/NIOCore/SocketOptionProvider.swift` 37 `WinSDK` (Windows): **System gap**: [linger] (linger: Windows)
- `Sources/NIOCore/Utilities.swift` 21 `Glibc` (FreeBSD): **System gap**: ifa_next (ifa_next: FreeBSD)
- `Sources/NIOCore/Utilities.swift` 27 `Glibc` (OpenBSD): **System gap**: ifa_next (ifa_next: OpenBSD)
- `Sources/NIOCore/Utilities.swift` 31 `ucrt` (Windows): **System gap**: [address families] (AF_UNSPEC: Windows); [Windows adapters] (ERROR_BUFFER_OVERFLOW: Windows); [Win32 errors] (GetLastError: Windows); [getenv] (_dupenv_s: Windows)
- `Sources/NIOCore/Utilities.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_UNSPEC: Windows)
- `Sources/NIOCore/Utilities.swift` 35 `WinSDK` (scoped) (Windows): **System gap**: [Windows adapters] (ERROR_BUFFER_OVERFLOW: Windows)
- `Sources/NIOCore/Utilities.swift` 39 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/NIOCore/Utilities.swift` 45 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (ULONG: Windows)
- `Sources/NIOEmbedded/Embedded.swift` 34 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/NIOMulticastChat/main.swift` 26 `WinSDK` (Windows): **System gap**: sin_addr (sin_addr: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 25 `ucrt` (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET: Windows); [ECN, TOS and packet info] (IPV6_RECVTCLASS, IP_RECVTOS: Windows); [socket types] (SOCK_DGRAM, SOCK_RAW, SOCK_STREAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 27 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 29 `WinSDK` (scoped) (Windows): **System gap**: [ECN, TOS and packet info] (IP_RECVTOS: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 30 `WinSDK` (scoped) (Windows): **System gap**: [ECN, TOS and packet info] (IPV6_RECVTCLASS: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 32 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_DGRAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 33 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_STREAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_RAW: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 36 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 20 `ucrt` (Windows): **System gap**: [Windows delete] (FILE_DISPOSITION_INFO_EX: Windows); [Winsock sockets] (FIONBIO, INVALID_SOCKET, SOCKET_ERROR…: Windows); [Win32 errors] (GetLastError, NO_ERROR: Windows); [Winsock addresses] (IN_ADDR, SOCKADDR, SOCKADDR_IN…: Windows); [Winsock messages] (LPFN_WSARECVMSG, LPFN_WSASENDMSG, LPWSAMSG…: Windows); [shutdown] (SD_BOTH, SD_RECEIVE, SD_SEND…: Windows); and 11 more
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 22 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 23 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 24 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_UNIX: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 26 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (FIONBIO: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 28 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET_ADDRSTRLEN: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 29 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET6_ADDRSTRLEN: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 32 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_IP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 35 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_IPV6: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 36 `WinSDK` (scoped) (Windows): **System gap**: [protocol levels] (IPPROTO_TCP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 38 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_ADD_MEMBERSHIP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 39 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_DROP_MEMBERSHIP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 40 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_IF: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 41 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_LOOP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 42 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IP_MULTICAST_TTL: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 44 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_JOIN_GROUP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 45 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_LEAVE_GROUP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_HOPS: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 47 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_IF: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (IPV6_MULTICAST_LOOP: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 49 `WinSDK` (scoped) (Windows): **System gap**: [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 51 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_INET: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 52 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_INET6: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 53 `WinSDK` (scoped) (Windows): **System gap**: [address families] (PF_UNIX: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 55 `WinSDK` (scoped) (Windows): **System gap**: [TCP_NODELAY] (TCP_NODELAY: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 57 `WinSDK` (scoped) (Windows): **System gap**: [shutdown] (SD_BOTH: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 58 `WinSDK` (scoped) (Windows): **System gap**: [shutdown] (SD_RECEIVE: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 59 `WinSDK` (scoped) (Windows): **System gap**: [shutdown] (SD_SEND: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 61 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_ERROR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 62 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_KEEPALIVE: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 63 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_LINGER: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 64 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_RCVBUF: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 65 `WinSDK` (scoped) (Windows): **System gap**: [SO_RCVTIMEO and SO_TIMESTAMP] (SO_RCVTIMEO: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 66 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SO_REUSEADDR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 67 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SO_REUSE_UNICASTPORT: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 69 `WinSDK` (scoped) (Windows): **System gap**: [socket options] (SOL_SOCKET: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 71 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_DGRAM: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 72 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_STREAM: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 74 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (SOCKET_ERROR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 76 `WinSDK` (scoped) (Windows): **System gap**: [sendfile] (TF_USE_KERNEL_APC: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 78 `WinSDK` (scoped) (Windows): **System gap**: [accept] (accept: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 79 `WinSDK` (scoped) (Windows): **System gap**: [bind] (bind: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 80 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (closesocket: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 81 `WinSDK` (scoped) (Windows): **System gap**: [connect] (connect: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 82 `WinSDK` (scoped) (Windows): **System gap**: [getsockname and getpeername] (getpeername: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 83 `WinSDK` (scoped) (Windows): **System gap**: [getsockname and getpeername] (getsockname: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 84 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (ioctlsocket: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 85 `WinSDK` (scoped) (Windows): **System gap**: [listen] (listen: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 86 `WinSDK` (scoped) (Windows): **System gap**: [shutdown] (shutdown: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 87 `WinSDK` (scoped) (Windows): **System gap**: [socket] (socket: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 88 `WinSDK` (scoped) (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 90 `WinSDK` (scoped) (Windows): **System gap**: [sendfile] (TransmitFile: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 92 `WinSDK` (scoped) (Windows): **System gap**: [Winsock errors] (WSAGetLastError: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 93 `WinSDK` (scoped) (Windows): **System gap**: [Winsock messages] (WSAIoctl: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 94 `WinSDK` (scoped) (Windows): **System gap**: [Winsock messages] (WSASend: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 96 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 97 `WinSDK` (scoped) (Windows): **standard library**: [C scalar types] (u_long: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 99 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 102 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (IN_ADDR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 103 `WinSDK` (scoped) (Windows): **System gap**: [linger] (LINGER: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 105 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 106 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_IN: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 107 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_IN6: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 108 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_UN: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 109 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_STORAGE: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 110 `WinSDK` (scoped) (Windows): **System gap**: [Winsock messages] (WSACMSGHDR: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 111 `WinSDK` (scoped) (Windows): **System gap**: [Winsock messages] (WSAMSG: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 113 `WinSDK` (scoped) (Windows): **System gap**: [Winsock messages] (LPFN_WSARECVMSG: Windows)
- `Sources/NIOPosix/BaseSocket.swift` 37 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/DatagramVectorReadManager.swift` 33 `WinSDK` (Windows): **System gap**: msg_hdr (msg_hdr: Windows); msg_len (msg_len: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 45 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (FreeAddrInfoW: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 49 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (GetAddrInfoW: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 50 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (gai_strerrorA: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 52 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 53 `WinSDK` (scoped) (Windows): **System gap**: [Windows name resolution] (ADDRINFOW: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 54 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_IN: Windows)
- `Sources/NIOPosix/GetaddrinfoResolver.swift` 55 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (SOCKADDR_IN6: Windows)
- `Sources/NIOPosix/PendingDatagramWritesManager.swift` 40 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/PipePair.swift` 26 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/SelectorGeneric.swift` 24 `WinSDK` (Windows): **System gap**: [poll] (pollfd: Windows)
- `Sources/NIOPosix/SelectorWSAPoll.swift` 21 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Winsock sockets] (INVALID_SOCKET, SOCKET_ERROR: Windows); [PATH_MAX] (MAX_PATH: Windows); [poll] (POLLERR, POLLHUP, POLLNVAL…: Windows); [Winsock errors] (WSAGetLastError: Windows); [accept] (accept: Windows); and 4 more
- `Sources/NIOPosix/Socket.swift` 29 `WinSDK` (Windows): **System gap**: [Winsock messages] (WSABUF: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INADDR_ANY: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (ip_mreq: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 49 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (ipv6_mreq: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 50 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/SocketProtocols.swift` 22 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/System.swift` 71 `Glibc`, re-exported (Linux, FreeBSD): **System gap**: [sendfile] (sendfile: FreeBSD)
- `Sources/NIOPosix/System.swift` 92 `ucrt`, re-exported (Windows): **System gap**: [protocol levels] (IPPROTO_UDP: Windows); [ECN, TOS and packet info] (IPV6_PKTINFO, IP_PKTINFO: Windows); [Windows errno] (_get_errno: Windows)
- `Sources/NIOPosix/ThreadWindows.swift` 19 `WinSDK` (Windows): **System gap**: [Windows threads] (CompareObjectHandles: Windows); [Windows handles] (DUPLICATE_SAME_ACCESS, WAIT_OBJECT_0: Windows); [Win32 errors] (GetLastError: Windows); [Windows local memory] (LocalFree: Windows)
- `Sources/NIOPosix/Windows.swift` 19 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError, SetLastError: Windows); [Windows local memory] (LocalFree: Windows); [Winsock sockets] (SOCKET, SOCKET_ERROR: Windows); [Winsock errors] (WSAGetLastError: Windows); [send and receive] (recv: Windows)
- `Tests/NIOPosixTests/ChannelPipelineTest.swift` 31 `WinSDK` (Windows): **System gap**: sin_port (sin_port: Windows)
- `Tests/NIOPosixTests/HappyEyeballsTest.swift` 30 `WinSDK` (Windows): **System gap**: sin6_addr (sin6_addr: Windows); sin6_family (sin6_family: Windows); sin6_flowinfo (sin6_flowinfo: Windows); sin6_port (sin6_port: Windows); sin6_scope_id (sin6_scope_id: Windows); sin_addr (sin_addr: Windows); and 2 more
- `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift` 38 `WinSDK` (Windows): **System gap**: msg_hdr (msg_hdr: Windows); msg_len (msg_len: Windows); [sockaddr types] (socklen_t: Windows)
- `Tests/NIOPosixTests/SocketAddressTest.swift` 22 `WinSDK` (Windows): **System gap**: [address families] (AF_UNSPEC: Windows); sin6_addr (sin6_addr: Windows); sin6_family (sin6_family: Windows); sin6_flowinfo (sin6_flowinfo: Windows); sin6_port (sin6_port: Windows); sin6_scope_id (sin6_scope_id: Windows); and 6 more
- `Tests/NIOPosixTests/SocketOptionProviderTest.swift` 21 `WinSDK` (Windows): **System gap**: WSAEFAULT (WSAEFAULT: Windows); l_linger (l_linger: Windows); l_onoff (l_onoff: Windows); [linger] (linger: Windows); [gettimeofday] (timeval: Windows); tv_usec (tv_usec: Windows)
- `dev/stackdiff/Sources/stackdiff/Stackdiff+Merge.swift` 21 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: label (label: Linux, FreeBSD, OpenBSD); ws_col (ws_col: Linux, FreeBSD, OpenBSD)
- `dev/stackdiff/Sources/stackdiff/Stackdiff+Merge.swift` 23 `Musl` (Musl): **System gap**: label (label: Musl); ws_col (ws_col: Musl)

**swift-numerics**, at `../ecosystem/swift-numerics` @ `0a5bc040`: no sites.

**swift-sdk-generator**, at `../adopters/swift-sdk-generator` `migrate-unix` @ `bc251e13`: 3 sites, 1 of them unexplained (above).

- `Tests/AsyncProcessTests/IntegrationTests.swift` 75 `WASILibc` (WASI): **System gap**: label (label: WASI); useconds_t (useconds_t: WASI); [usleep] (usleep: WASI)
- `Tests/AsyncProcessTests/IntegrationTests.swift` 77 `Bionic` (Android): **System gap**: label (label: Android); useconds_t (useconds_t: Android)

**swift-stress-tester**, at `../adopters/swift-stress-tester` `migrate-all` @ `e1702563`: 1 sites.

- `SourceKitStressTester/Tests/SwiftCWrapperToolTests/SwiftCWrapperToolTests.swift` 89 marker: unistd.h usleep: PThread.sleep(for:) takes a Duration, which needs mac… (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: [usleep] (usleep: WASI, Windows)

**swift-subprocess**, at `../adopters/swift-subprocess` `migrate-unix` @ `661de35c`: 23 sites, 8 of them unexplained (above).

- `Sources/Subprocess/Configuration.swift` 16 `WinSDK` (Windows): **System gap**: [Windows handles] (DUPLICATE_SAME_ACCESS, SECURITY_ATTRIBUTES: Windows); [Windows named pipes] (FILE_FLAG_FIRST_PIPE_INSTANCE, PIPE_READMODE_BYTE, PIPE_REJECT_REMOTE_CLIENTS…: Windows); [Win32 errors] (GetLastError: Windows); [string functions] (_strdup: Windows)
- `Sources/Subprocess/Error.swift` 14 `WinSDK` (Windows): **System gap**: [Win32 errors] (NTSTATUS: Windows); [Windows errno] (errno_t: Windows)
- `Sources/Subprocess/IO/AsyncIO+KQueue.swift` 23 `os` (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/IO/AsyncIO+Windows.swift` 20 `WinSDK` (Windows): **System gap**: [Win32 errors] (ERROR_IO_INCOMPLETE, ERROR_NOT_FOUND, GetLastError: Windows); [Windows I/O completion ports] (LPOVERLAPPED: Windows)
- `Sources/Subprocess/IO/Input.swift` 15 `WinSDK` (Windows): **System gap**: raw (raw: Windows)
- `Sources/Subprocess/Platforms/Subprocess+BSD.swift` 21 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Platforms/Subprocess+Windows.swift` 14 `WinSDK` (Windows): **System gap**: [Windows process creation] (CREATE_UNICODE_ENVIRONMENT, CreateProcessWithLogonW, DeleteProcThreadAttributeList…: Windows); [Win32 errors] (FACILITY_WIN32, GetLastError: Windows); [environment block] (FreeEnvironmentStringsW: Windows); [Windows DLLs] (GetModuleHandleA: Windows); [Windows file information] (INVALID_FILE_ATTRIBUTES: Windows); [Windows local memory] (LocalFree: Windows); and 5 more
- `Sources/Subprocess/SubprocessOutputSequence.swift` 34 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Teardown.swift` 17 `WinSDK` (Windows): **System gap**: [Windows handles] (WAIT_TIMEOUT: Windows)
- `Sources/Subprocess/Thread.swift` 15 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Thread.swift` 17 `WinSDK` (Windows): **standard library**: [mutexes] (DeleteCriticalSection: Windows)
- `Tests/SubprocessTests/IntegrationTests.swift` 18 `WinSDK` (Windows): **System gap**: [Windows handles] (DUPLICATE_SAME_ACCESS: Windows); [Win32 errors] (GetLastError: Windows)
- `Tests/SubprocessTests/ProcessMonitoringTests.swift` 18 `WinSDK` (Windows): **System gap**: timeout (timeout: Windows)
- `Tests/SubprocessTests/UnixTests.swift` 22 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: timeout (timeout: Linux, FreeBSD, OpenBSD)
- `Tests/SubprocessTests/WindowsTests.swift` 14 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); JOBOBJECT_EXTENDED_LIMIT_INFORMATION (JOBOBJECT_EXTENDED_LIMIT_INFORMATION: Windows); [PATH_MAX] (MAX_PATH: Windows); PSID (PSID: Windows); [Windows process exit] (RegisterWaitForSingleObject, WAITORTIMERCALLBACK, WT_EXECUTELONGFUNCTION…: Windows); UNLEN (UNLEN: Windows); and 2 more

**swift-syntax**, at `../adopters/swift-syntax` `migrate-all` @ `e6918103`: 6 sites, 2 of them unexplained (above).

- `EditorExtension/SwiftRefactorExtension/CommandDiscovery.swift` 13 `Darwin`, 15 `MachO` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: _dyld_get_image_header (_dyld_get_image_header: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); getsectiondata (getsectiondata: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); E3 (mach_header_64: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/SwiftSyntaxBuilder/SyntaxParsable+ExpressibleByStringInterpolation.swift` 21 `os`, 33 `os` (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-testing**, at `../adopters/swift-testing` `migrate-all` @ `e2f8d449`: 65 sites, 14 of them unexplained (above).

- `Sources/Overlays/_Testing_Foundation/Attachments/Attachment+URL.swift` 17 `WinSDK` (Windows?): **System gap**: [Windows local memory] (LocalFree: Windows); [Windows paths] (PATHCCH_ALLOW_LONG_PATHS: Windows); UINT (UINT: Windows)
- `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift` 125 marker: file cloning (sys/clonefile.h fclonefileat, linux/fs.h FICLONE, FreeBS… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: FICLONE (FICLONE: Darwin, FreeBSD, OpenBSD, WASI, Windows); copy_file_range (copy_file_range: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); fclonefileat (fclonefileat: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Overlays/_Testing_WinSDK/Attachments/AttachableAsIWICBitmapSource.swift` 13 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows)
- `Sources/Overlays/_Testing_WinSDK/Attachments/AttachableImageFormat+CLSID.swift` 12 `WinSDK` (Windows): **System gap**: PCWSTR (PCWSTR: Windows); UINT (UINT: Windows); [string functions] (wcslen: Windows)
- `Sources/Overlays/_Testing_WinSDK/Attachments/HBITMAP+AttachableAsIWICBitmapSource.swift` 12 `WinSDK` (Windows): **System gap**: UINT (UINT: Windows)
- `Sources/Testing/ABI/ABI.VersionNumber.swift` 225 marker: string.h memmem, a search for bytes in bytes (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?): **System gap**: memmem (memmem: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI)
- `Sources/Testing/ABI/ABI.swift` 364 marker: stdlib.h calloc on Windows: Memory.allocateZeroed(count:stride:) (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: calloc (calloc: Windows)
- `Sources/Testing/ABI/EntryPoints/SwiftPMEntryPoint.swift` 31 marker: sysexits.h EX_UNAVAILABLE on WASI: ProcessID.ExitCode.serviceUnavailab… (Darwin?, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows?): **System gap**: [exit] (EX_UNAVAILABLE: WASI, Windows)
- `Sources/Testing/Events/Clock.swift` 33 marker: time.h timespec_get on Windows: ClockID.realtime's currentTimeSpec() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: timespec_get (timespec_get: Windows)
- `Sources/Testing/ExitTests/ExitStatus.swift` 126 marker: signal.h sys_signame and string.h sigabbrev_np: a signal's C name, or … (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: sigabbrev_np (sigabbrev_np: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); sys_signame (sys_signame: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/ExitTests/ExitTest.swift` 219 marker: mach/task.h task_set_exception_ports, Mach exception ports (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: task_set_exception_ports (task_set_exception_ports: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/ExitTests/SpawnProcess.swift` 91 marker: spawn.h posix_spawn_file_actions_addclosefrom_np on Linux: SpawnFileAc… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: posix_spawn_file_actions_addclosefrom_np (posix_spawn_file_actions_addclosefrom_np: Darwin, Android, OpenBSD, WASI, Windows)
- `Sources/Testing/ExitTests/WaitFor.swift` 175 marker: pthread.h pthread_set_name_np on OpenBSD: PThread.setCurrentName(_:) (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [thread names] (pthread_set_name_np: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows)
- `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift` 150 marker: string.h strlen and stdlib.h free on Windows: CString.length(of:) (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [string functions] (strlen: Windows)
- `Sources/Testing/SourceAttribution/Backtrace.swift` 67 marker: execinfo.h backtrace on Linux, Android, FreeBSD and OpenBSD, and backt… (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: backtrace (backtrace: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); backtrace_async (backtrace_async: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/Support/Additions/CommandLineAdditions.swift` 55 marker: the executable's path (_NSGetExecutablePath, /proc/self/exe, sysctl's … (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: KERN_PROC_PATHNAME (KERN_PROC_PATHNAME: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); _NSGetExecutablePath (_NSGetExecutablePath: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); sysctl (sysctl: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/Support/Environment.swift` 90 marker: string.h strchr and strncmp in Embedded Swift, which (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: strchr (strchr: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); [string functions] (strncmp: Windows)
- `Sources/Testing/Support/FileHandle.swift` 518 marker: stdio.h getc_unlocked: FileStream reads only with the stream's lock ta… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: getc_unlocked (getc_unlocked: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/Support/FileHandle.swift` 722 marker: unistd.h pipe2 before macOS 27: FileDescriptor.pipe(options:) (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?): **System gap**: [pipe] (pipe2: WASI)
- `Sources/Testing/Support/FileHandle.swift` 800 marker: unistd.h isatty on WASI: FileDescriptor.isTerminal (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: isatty (isatty: WASI, Windows)
- `Sources/Testing/Support/FileHandle.swift` 901 marker: stdlib.h realpath on WASI: FilePath.canonicalized() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: realpath (realpath: WASI, Windows)
- `Sources/Testing/Support/GetSymbol.swift` 34 marker: dlfcn.h dlsym with RTLD_DEFAULT or a handle the caller owns: DynamicLi… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [dlopen] (dlsym: WASI, Windows)
- `Sources/Testing/Support/Versions.swift` 240 marker: gnu/libc-version.h gnu_get_libc_version: the C library's version at ru… (Linux): **System gap**: gnu_get_libc_version (gnu_get_libc_version: Linux)
- `Sources/_TestDiscovery/SectionBounds.swift` 44 marker: Mach-O images: mach-o/getsect.h getsectiondata and mach-o/dyld.h (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: getsectiondata (getsectiondata: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Tests/TestingTests/ABIEntryPointTests.swift` 242 marker: stdlib.h free and string.h strlen on Windows: Memory.free(_:) (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [string functions] (strlen: Windows)
- `Tests/TestingTests/AttachmentTests.swift` 95 marker: stdio.h remove on Windows and WASI: FilePath.remove(), 112 marker: stdio.h remove, as above, 143 marker: stdio.h remove, as above, 151 marker: stdio.h remove, as above, 179 marker: stdio.h remove, as above, 199 marker: stdio.h remove, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [remove] (remove: WASI, Windows)
- `Tests/TestingTests/AttachmentTests.swift` 163 marker: limits.h NAME_MAX on WASI: SystemConfig.maxFileNameBytes (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?): **System gap**: NAME_MAX (NAME_MAX: WASI)
- `Tests/TestingTests/ExitTestTests.swift` 50 marker: signal.h SIGABRT on Windows: Signal.abort, 149 marker: signal.h SIGABRT, as above, 181 marker: signal.h SIGABRT, as above, 187 marker: signal.h SIGABRT, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [signal numbers] (SIGABRT: WASI, Windows)
- `Tests/TestingTests/ExitTestTests.swift` 80 marker: signal.h raise and SIGSEGV on Windows: Signal.segmentationViolation.ra… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [signal numbers] (SIGSEGV: WASI, Windows); raise (raise: WASI, Windows)
- `Tests/TestingTests/ExitTestTests.swift` 89 marker: stdlib.h abort, every platform (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **standard library**: [termination] (abort: Windows)
- `Tests/TestingTests/ExitTestTests.swift` 813 marker: stdlib.h abort and signal.h SIGABRT and SIGSEGV, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [signal numbers] (SIGABRT, SIGSEGV: WASI, Windows)
- `Tests/TestingTests/Support/ColorTests.swift` 40 marker: stdio.h remove on Windows and WASI: FilePath.remove() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [remove] (remove: WASI, Windows)
- `Tests/TestingTests/Support/FileHandleTests.swift` 168 marker: pty.h openpty on OpenBSD: TerminalDescriptor.openPseudoterminal() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?): **queued** (N3): N3 (openpty: OpenBSD)
- `Tests/TestingTests/Support/FileHandleTests.swift` 224 marker: stdio.h fmemopen, a FileStream over memory (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?): **System gap**: fmemopen (fmemopen: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD)
- `Tests/TestingTests/Support/FileHandleTests.swift` 257 marker: stdio.h tmpfile, an anonymous temporary FileStream (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?): **System gap**: tmpfile (tmpfile: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD)
- `Tests/TestingTests/Support/FileHandleTests.swift` 286 marker: stdio.h remove on Windows and WASI: FilePath.remove() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [remove] (remove: WASI, Windows)
- `Tests/TestingTests/Support/FileHandleTests.swift` 313 marker: stdio.h funopen and fopencookie, a FileStream over callbacks (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: funopen (funopen: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Tests/TestingTests/SwiftPMTests.swift` 387 marker: stdio.h remove on Windows and WASI: FilePath.remove(), 413 marker: stdio.h remove, as above, 435 marker: stdio.h remove, as above, 464 marker: stdio.h remove, as above, 563 marker: stdio.h remove, as above, 613 marker: stdio.h remove, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [remove] (remove: WASI, Windows)

**swift-toolchain-sarif**, at `../ecosystem/swift-toolchain-sarif` @ `d611f23a`: no sites.

**swift-toolchain-sqlite**, at `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0`: no sites.

**swift-tools-protocols**, at `../adopters/swift-tools-protocols` `migrate-unix` @ `2b2c75dc`: 7 sites, 5 of them unexplained (above).

- `Sources/SKLogging/Logging.swift` 16 `os`, re-exported (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SKLogging/OrLog.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-tools-support-core**, at `../adopters/swift-tools-support-core` `migrate-unix` @ `5f85e38e`: 7 sites, 1 of them unexplained (above).

- `Sources/TSCBasic/Path.swift` 12 `WinSDK` (Windows): **System gap**: [Windows local memory] (LocalFree: Windows); [Windows paths] (PATHCCH_ALLOW_LONG_PATHS: Windows); [string functions] (wcslen: Windows)
- `Sources/TSCBasic/TerminalController.swift` 14 `CRT` (Windows): **System gap**: [stdio] (fileno: Windows); isatty (isatty: Windows)
- `Sources/TSCBasic/misc.swift` 15 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); JOBOBJECT_EXTENDED_LIMIT_INFORMATION (JOBOBJECT_EXTENDED_LIMIT_INFORMATION: Windows); [Windows I/O completion ports] (LPOVERLAPPED: Windows); [Windows process creation] (PROCESS_INFORMATION: Windows); STARTUPINFOW (STARTUPINFOW: Windows); ULONG_PTR (ULONG_PTR: Windows)
- `Sources/TSCLibc/libc.swift` 12 `CRT`, re-exported, 13 `WinSDK`, re-exported (Windows): **System gap**: [Windows errno] (_set_errno: Windows); [string functions] (memcmp, strlen: Windows)
- `Sources/TSCUtility/FSWatch.swift` 16 `WinSDK` (Windows): **System gap**: [PATH_MAX] (MAX_PATH: Windows); [Windows handles] (WAIT_TIMEOUT: Windows)

**swiftpm**, at `../adopters/swift-package-manager` `migrate-unix` @ `efff7333`: 22 sites, 7 of them unexplained (above).

- `Fixtures/Miscellaneous/EchoExecutable/Sources/secho/main.swift` 2 `Glibc`, 4 `Musl`, 6 `Android`, 8 `Darwin` (submodule), 10 `ucrt` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **excluded** (E7c): SwiftPM's Fixtures/ and TestObservation.swift's generated text
- `Sources/Basics/Cancellator.swift` 18 `WinSDK` (Windows): **System gap**: [signal numbers] (SIGINT, SIGTERM: Windows)
- `Sources/Basics/Environment/Environment.swift` 17 `CRT`, 18 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [getenv] (_putenv: Windows)
- `Sources/Basics/KnownFolders.swift` 16 `WinSDK` (Windows): **System gap**: [Windows known folders] (CoTaskMemFree, FOLDERID_ProgramFilesX86, FOLDERID_System…: Windows)
- `Sources/Basics/OSSignpost.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Commands/SwiftTestCommand.swift` 49 `WinSDK` (Windows): **System gap**: [Win32 errors] (ERROR_NOT_FOUND: Windows)
- `Sources/PackageLoading/ManifestLoader.swift` 29 `WinSDK` (Windows): **System gap**: [stdio] (fopen: Windows)
- `Sources/PackageRegistryCommand/PackageRegistryCommand+Auth.swift` 30 `WinSDK` (Windows): **System gap**: [Windows consoles] (ReadConsoleA: Windows)
- `Sources/Runtimes/PackagePlugin/Plugin.swift` 15 `ucrt`, 16 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); [Windows DLLs] (GetModuleHandleW: Windows)

**wasmkit**, at `../adopters/WasmKit` `migrate-unix` @ `fd06e2a3`: 39 sites, 26 of them unexplained (above).

- `Sources/CLICommands/Platform.swift` 7 `ucrt` (Windows): **System gap**: [Windows errno] (_get_errno: Windows); fseek (fseek: Windows)
- `Sources/CLICommands/Run.swift` 24 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/WASI/Platform/PAL/PALClock.swift` 7 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: CLOCK_MONOTONIC_RAW (CLOCK_MONOTONIC_RAW: FreeBSD, OpenBSD)
- `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` 16 `ucrt`, 17 `WinSDK` (Windows): **System gap**: ERROR_BAD_NETPATH (ERROR_BAD_NETPATH: Windows); ERROR_BAD_NET_NAME (ERROR_BAD_NET_NAME: Windows); ERROR_CANNOT_MAKE (ERROR_CANNOT_MAKE: Windows); ERROR_CURRENT_DIRECTORY (ERROR_CURRENT_DIRECTORY: Windows); ERROR_DRIVE_LOCKED (ERROR_DRIVE_LOCKED: Windows); ERROR_FAIL_I24 (ERROR_FAIL_I24: Windows); and 12 more
- `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` 20 `ucrt`, 21 `WinSDK` (Windows): **System gap**: FILE_END_OF_FILE_INFO (FILE_END_OF_FILE_INFO: Windows); [Win32 errors] (GetLastError: Windows); SetFileTime (SetFileTime: Windows); [Windows errno] (_get_errno: Windows)
- `Sources/WASI/Platform/PAL/PALSystemClocks.swift` 6 `WinSDK` (Windows): **System gap**: [Win32 errors] (GetLastError: Windows); LARGE_INTEGER (LARGE_INTEGER: Windows)
- `Sources/WasmKit/Execution/SignpostTracer.swift` 2 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/WasmKit/Platform/SystemVirtualMemory.swift` 5 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (SIZE_T: Windows)
- `Sources/WasmKit/Platform/SystemVirtualMemory.swift` 10 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: MAP_ANONYMOUS (MAP_ANONYMOUS: Linux)
- `Sources/WasmKit/Platform/SystemVirtualMemory.swift` 12 `Musl` (Musl): **System gap**: MAP_ANONYMOUS (MAP_ANONYMOUS: Musl)
- `Sources/WasmParser/Platform/FileIO.swift` 7 `ucrt` (Windows?): **System gap**: [Windows errno] (_get_errno: Windows)

</details>

Not read: boringssl (not cloned); brotli (not cloned); cmake (not cloned); curl (not cloned); libxml2 (not cloned); llvm-project (not cloned); mimalloc (not cloned); ninja (not cloned); swift (outside its clone's sparse checkout (include/swift/Threading, lib/Threading, stdlib/include, stdlib/public/Concurrency, stdlib/public/Platform, stdlib/public/SwiftShims, stdlib/public/Synchronization, stdlib/public/core, stdlib/public/libexec, stdlib/public/runtime, stdlib/public/stubs, stdlib/public/threading, utils/update_checkout): a partial clone, read without fetching); swift-corelibs-blocksruntime (not cloned); swift-corelibs-libdispatch (not cloned); swift-docc-render-artifact (not cloned); swift-installer-scripts (not cloned); swift-integration-tests (not cloned); swift-xcode-playground-support (not cloned); wasi-libc (not cloned); zlib (not cloned).

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
- **Sites left** (section 5) reads every repository of `scheme-main.tsv` but swift-system at the commits section 4
  reads, and the swift repository too, at its ecosystem clone: that clone is partial (blobless), so it's read only
  within its sparse checkout, and every git command runs with `GIT_NO_LAZY_FETCH=1`, so that nothing is fetched.
  Every Swift file is read, library, tests, other code and nested packages alike, with comments and strings blanked.
  A *site* is an import of a module that `modules.ini` puts in [count] or [report], in any form, at its line, with
  the platforms whose build compiles that line (platforms.py's evaluation, FOUNDATION_FRAMEWORK false); or a
  `SYSTEM-GAP:` marker that sits over no such import (the imports it does sit over take its interfaces as theirs).
  Imports of [not System's] modules aren't sites; their counts are given. A file that reaches a platform module
  only through another module's re-export (TSCLibc's, SWBLibc's) isn't a site; the re-export is.
- **C names**: a scoped import serves the declaration it names. A whole-module or submodule import serves the C
  names on the lines its platform compiles, found lexically as `../adopters-unix/scripts/inventory.py` finds them:
  the macOS SDK's names in the counted modules (adopter-coverage's stored vocabulary), System's C names, and
  mapping.ini's symbols (not Dispatch's, the frameworks', SQLite's or the Objective-C runtime's), with Windows' names
  (Prototype/Win32/WindowsModel and Rust's Win32 bindings, where rustc is installed) on Windows only; not a
  declaration or a label, not a member of anything but a platform module (a C field is one), a call-only word (`read`,
  `close`) only when called, and none the repository declares itself, in Swift or in its C headers, unless qualified
  (`Glibc.read`). A file's names count for each of its imports compiled on the platform. Rejected: adopter-coverage's
  extractions (`interfaces.json.gz`), which exist for some repositories, at other commits; and a vocabulary of any
  capitalized name, which reads every Swift type as C.
- **Categories**: `exceptions.ini`'s entries decide a site first, by kind: *excluded* (not a site), *exception* (Michael's
  list, with who approved it and when), *undecided*, *queued* (work already identified, with where), then a gap kept by
  hand; an entry with `names` or `mapping` holds only those names. A [report] module's import is *undecided*. Otherwise
  each C name is answered on each platform it's used on, against System at `system-next` (api-delta's scan of its
  sources and `derive.py`, as inventory.py reads them, with WASI as WASI without threads): *covered* when a public
  declaration built there names it in a doc comment's *The corresponding C …* sentence (or only for some uses), a
  CInterop alias or accessor covers it, mapping.ini's hand status covers it there, or System covers it under another C
  name (status.py's and inventory.py's equivalents); else the standard library's answer (`swift`), else *not System's*
  (`wrap = no`, a lane's verdict, unreviewed); else a *System gap*, whose unit is the name's mapping.ini entry, or the
  name. The site takes the first of: System gap, queued, not System's, standard library; with none, it's *unexplained*:
  System covers every name it serves there, the scan found none, or it's a marker that names no C interface.
- **Ranking**: System gaps in the order to fill them, greedily: next is the gap that unblocks the most sites, given the
  ones above are filled (a site is unblocked when none of its gaps is left), ties going to more platforms, then to more
  sites held. A scoped import is a site of its own, so a file that imports declaration by declaration (swift-build's
  MachO.swift) weighs more than one whole-module import; each row gives the files too. Entries by the sites they hold. **The floor** holds on a platform when no site compiled there (maybe
  included) is left but exceptions, excluded ones and [report] modules'. Rejected: counting each C name on each line as
  a site (inventory.py's unit), which made a whole-module import of WinSDK hundreds of sites; and ranking gaps by the
  sites they hold, which counts a site once per gap and ranks gaps that free nothing alone above ones that do.
