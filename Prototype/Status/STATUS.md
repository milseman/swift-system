# Status: System's API and its adopters

Generated 2026-10-08 by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than editing this file. How each figure is made, and what it can't see, is in [How this is computed](#how-this-is-computed).

- **System**: `coverage-9` @ `1f788961` (mapping.ini: [Windows current directory], covered by FilePath's current working directory API on Windows), which contains `coverage-9` @ `1f788961` (mapping.ini: [Windows current directory], covered by FilePath's current working directory API on Windows); 0 commit(s) of `coverage-9` aren't in `coverage-9`.
- **API delta**: `main` @ `1b452c29` → `HEAD` @ `4cb30026` (api-delta's last run; nothing it reads has changed since).
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

- **3427 added, 0 removed, 1 changed** declarations in the macOS symbol graphs.
  - SystemPackage: +2843, 1 changed (448 → 3291 public symbols).
  - SystemSockets: +584 (0 → 584 public symbols). SystemSockets is a new module; it doesn't exist on `main`.
- Availability of the additions:
  - System 199: 3393
  - System 199 + explicit OS floor: 26
  - System 0.0.1 + explicit OS floor: 8
- The source scan finds these new public declarations, which the macOS graphs can't show:
  - 1670 compiled only on other platforms;
  - 254 new `@available(*, unavailable, renamed:)` stubs;
  - 1 new underscored public declaration(s).
  - 5 declarations the scan couldn't classify; see the list below.
  - 29 added, removed or changed graph symbols the scan didn't find (enum case: 28, no source location: 1). Enum cases have no `public` keyword, and synthesized members have no location; any others are scanner misses. Their platforms show as `?`.
- 0 public declarations hidden from the graphs were removed.
- No public declaration is conditional on `ENABLE_MOCKING` or `DEBUG`, so a release build has the same public API as the debug graphs.
- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:
  - SystemPackage: +3170 / -1 declarations, which is the graphs' +2843 plus 321 implicit ones; explicit declarations it has that the graphs don't: `FileDescriptor.close()`, `_opaque_pthread_cond_t.initializer`, `_opaque_pthread_mutex_t.errorCheckingInitializer`, `_opaque_pthread_mutex_t.initializer`, `_opaque_pthread_mutex_t.recursiveInitializer`, `_opaque_pthread_rwlock_t.initializer`; it has every graph addition; `-diagnose-sdk` reports no breaking changes.
  - SystemSockets: +657 / -0 declarations, which is the graphs' +584 plus 72 implicit ones; explicit declarations it has that the graphs don't: `SocketAddress._withUnsafeMutablePointer(_:)`; it has every graph addition.
- 0 removed and 1 changed in the graphs, and 0 removed among the declarations the graphs can't see. The full list below gives the first kind, and section 5 the second. The *changed* check compares declaration text (including default arguments), availability, conformances, generic and extension constraints, and access level, and pairs symbols by path when a signature change alters the USR.

### By area

Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under `FilePath`. Extensions of another module's types appear under the extended type. Availability counts use S = `System`; +OS means an explicit OS floor.

| Module | Area | Added | Removed | Changed | Availability of additions |
|---|---|---:|---:|---:|---|
| SystemPackage | [`ArchiveFile`](#systempackage-archivefile) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`BaudRate`](#systempackage-baudrate) | 26 | 0 | 0 | S199 ×26 |
| SystemPackage | [`BrokenDownTime`](#systempackage-brokendowntime) | 29 | 0 | 0 | S199 ×29 |
| SystemPackage | [`CInterop`](#systempackage-cinterop) | 65 | 0 | 0 | S199 ×65 |
| SystemPackage | [`CLocale`](#systempackage-clocale) | 53 | 0 | 0 | S199 ×53 |
| SystemPackage | [`CString`](#systempackage-cstring) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`CType`](#systempackage-ctype) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`CallStack`](#systempackage-callstack) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`ChildProcess`](#systempackage-childprocess) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`ClockID`](#systempackage-clockid) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`ControlCharacter`](#systempackage-controlcharacter) | 21 | 0 | 0 | S199 ×21 |
| SystemPackage | [`ControlCharacters`](#systempackage-controlcharacters) | 8 | 0 | 0 | S199 ×8 |
| SystemPackage | [`ControlFlags`](#systempackage-controlflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`DirectoryStream`](#systempackage-directorystream) | 15 | 0 | 0 | S199 ×15 |
| SystemPackage | [`DirectoryWalk`](#systempackage-directorywalk) | 30 | 0 | 0 | S199 ×30 |
| SystemPackage | [`DiskQuota`](#systempackage-diskquota) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`DynamicLibrary`](#systempackage-dynamiclibrary) | 35 | 0 | 0 | S199 ×35 |
| SystemPackage | [`Entropy`](#systempackage-entropy) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`Errno`](#systempackage-errno) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`ExitStatus`](#systempackage-exitstatus) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`ExtendedAttributeName`](#systempackage-extendedattributename) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`ExtendedAttributeOptions`](#systempackage-extendedattributeoptions) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`FileDescriptor`](#systempackage-filedescriptor) | 247 | 0 | 1 | S199 ×234, S0.0.1+OS ×8, S199+OS ×5 |
| SystemPackage | [`FilePath`](#systempackage-filepath) | 449 | 0 | 0 | S199 ×435, S199+OS ×14 |
| SystemPackage | [`FilePermissions`](#systempackage-filepermissions) | 1 | 0 | 0 | S199 ×1 |
| SystemPackage | [`FileStream`](#systempackage-filestream) | 40 | 0 | 0 | S199 ×40 |
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
| SystemPackage | [`LoadAverage`](#systempackage-loadaverage) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`LocalFlags`](#systempackage-localflags) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`Mach`](#systempackage-mach) | 78 | 0 | 0 | S199 ×78 |
| SystemPackage | [`MachOFile`](#systempackage-machofile) | 42 | 0 | 0 | S199 ×42 |
| SystemPackage | [`Math`](#systempackage-math) | 55 | 0 | 0 | S199 ×55 |
| SystemPackage | [`Memory`](#systempackage-memory) | 93 | 0 | 0 | S199 ×93 |
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
| SystemPackage | [`Signal`](#systempackage-signal) | 75 | 0 | 0 | S199 ×75 |
| SystemPackage | [`SignalSet`](#systempackage-signalset) | 22 | 0 | 0 | S199 ×22 |
| SystemPackage | [`SpawnAttributes`](#systempackage-spawnattributes) | 20 | 0 | 0 | S199 ×20 |
| SystemPackage | [`SpawnCredentials`](#systempackage-spawncredentials) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`SpawnFileAction`](#systempackage-spawnfileaction) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`Stat`](#systempackage-stat) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`StatFS`](#systempackage-statfs) | 27 | 0 | 0 | S199 ×27 |
| SystemPackage | [`SystemConfig`](#systempackage-systemconfig) | 74 | 0 | 0 | S199 ×74 |
| SystemPackage | [`SystemControl`](#systempackage-systemcontrol) | 72 | 0 | 0 | S199 ×72 |
| SystemPackage | [`SystemIdentity`](#systempackage-systemidentity) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`TerminalAttributes`](#systempackage-terminalattributes) | 44 | 0 | 0 | S199 ×44 |
| SystemPackage | [`TerminalDescriptor`](#systempackage-terminaldescriptor) | 52 | 0 | 0 | S199 ×52 |
| SystemPackage | [`UnfairLock`](#systempackage-unfairlock) | 14 | 0 | 0 | S199 ×14 |
| SystemPackage | [`UserEntry`](#systempackage-userentry) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`UserID`](#systempackage-userid) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`ar_hdr (extends Darwin)`](#systempackage-ar-hdr-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`build_version_command (extends MachO)`](#systempackage-build-version-command-extends-macho) | 6 | 0 | 0 | S199 ×6 |
| SystemPackage | [`dirent (extends Darwin)`](#systempackage-dirent-extends-darwin) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`dylib (extends MachO)`](#systempackage-dylib-extends-macho) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`dylib_command (extends MachO)`](#systempackage-dylib-command-extends-macho) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`fat_arch (extends MachO)`](#systempackage-fat-arch-extends-macho) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`fat_arch_64 (extends MachO)`](#systempackage-fat-arch-64-extends-macho) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`fat_header (extends MachO)`](#systempackage-fat-header-extends-macho) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`iovec (extends Darwin)`](#systempackage-iovec-extends-darwin) | 4 | 0 | 0 | S199 ×4 |
| SystemPackage | [`kevent (extends Darwin)`](#systempackage-kevent-extends-darwin) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`kinfo_proc (extends Darwin)`](#systempackage-kinfo-proc-extends-darwin) | 10 | 0 | 0 | S199 ×10 |
| SystemPackage | [`load_command (extends MachO)`](#systempackage-load-command-extends-macho) | 2 | 0 | 0 | S199 ×2 |
| SystemPackage | [`mach_header (extends MachO)`](#systempackage-mach-header-extends-macho) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`mach_header_64 (extends MachO)`](#systempackage-mach-header-64-extends-macho) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`rpath_command (extends MachO)`](#systempackage-rpath-command-extends-macho) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`rusage (extends _DarwinFoundation3)`](#systempackage-rusage-extends-darwinfoundation3) | 13 | 0 | 0 | S199 ×13 |
| SystemPackage | [`section (extends MachO)`](#systempackage-section-extends-macho) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`section_64 (extends MachO)`](#systempackage-section-64-extends-macho) | 9 | 0 | 0 | S199 ×9 |
| SystemPackage | [`segment_command (extends MachO)`](#systempackage-segment-command-extends-macho) | 11 | 0 | 0 | S199 ×11 |
| SystemPackage | [`segment_command_64 (extends MachO)`](#systempackage-segment-command-64-extends-macho) | 11 | 0 | 0 | S199 ×11 |
| SystemPackage | [`stat (extends Darwin)`](#systempackage-stat-extends-darwin) | 17 | 0 | 0 | S199 ×17 |
| SystemPackage | [`timespec (extends _DarwinFoundation2)`](#systempackage-timespec-extends-darwinfoundation2) | 7 | 0 | 0 | S199 ×7 |
| SystemPackage | [`timeval (extends _DarwinFoundation2)`](#systempackage-timeval-extends-darwinfoundation2) | 5 | 0 | 0 | S199 ×5 |
| SystemPackage | [`uuid_command (extends MachO)`](#systempackage-uuid-command-extends-macho) | 3 | 0 | 0 | S199 ×3 |
| SystemPackage | [`version_min_command (extends MachO)`](#systempackage-version-min-command-extends-macho) | 4 | 0 | 0 | S199 ×4 |
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
| **Total** | | **3427** | **0** | **1** | |

## ABI: exported symbols

What each module's release build exports, at `main` (`1b452c29`) → HEAD (`1f788961`), beside the API points above: `nm`'s external symbols in the objects of `swift build -c release`, built from an export of the commit. Every public property exports a property descriptor, `@_alwaysEmitIntoClient` or not (the SDK's System does too), so the descriptors grow with the API. *Code* is functions and accessors, what `@_alwaysEmitIntoClient` leaves to the client: of *public* declarations, in the symbol graphs, and *other*, which the graphs don't show (`@usableFromInline` internals, synthesized Equatable and Hashable members, deinitializers, stored properties' initial values).

| Module | Exported | Property descriptors | Conformances | Types | Code, public | Code, other |
|---|---:|---:|---:|---:|---:|---:|
| SystemPackage | 830 → 5108 | 406 → 2307 | 167 → 817 | 90 → 670 | 118 → 518 | 49 → 796 |
| SystemSockets | — → 881 | — → 336 | — → 139 | — → 132 | — → 168 | — → 106 |

### Candidates for `@_alwaysEmitIntoClient`

Of the 330 declarations added since `main` that export code, 25 only forward a C header value (SystemSockets 25): a *constant* is a static member that reads a C macro or enumerator, a *raw value* an initializer that stores one (or its getter), and an *accessor* an instance member that reads a C struct's field or tests a C constant, through conversions at most. With `@_alwaysEmitIntoClient`, the client would compile that code; a property keeps its descriptor. The other declarations' code is stored properties' accessors and code that does more than forward.

| Module | Declaration | Forwards | Exports | Where |
|---|---|---|---|---|
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.level` | accessor `cmsg_level` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:528` |
| SystemSockets | `SocketDescriptor.AncillaryMessageBuffer.Message.type` | accessor `cmsg_type` | getter | `Sources/SystemSockets/Sockets/SocketMessages.swift:535` |
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

Every `SYSTEM-GAP:` marker in the packages' sources at each adopter's newest migration branch, the commit section 4 reads (WasmKit `migrate-unix` @ `d0f9f8de`, indexstore-db `migrate-all` @ `96d2a952`, sourcekit-lsp `migrate-all` @ `79583cc1`, swift-argument-parser `migrate-all` @ `22831ad7`, swift-async-algorithms `migrate-all` @ `0178ed40`, swift-build `migrate-all` @ `4f55b04e`, swift-certificates `migrate-all` @ `c310582c`, swift-corelibs-xctest `migrate-darwin` @ `80a3f954`, swift-crypto `migrate-all` @ `ef1e59aa`, swift-docc `migrate-all` @ `4e6a5cea`, swift-driver `migrate-unix` @ `e7850bd0`, swift-experimental-string-processing `migrate-all` @ `f0d0fc7f`, swift-format `migrate-all` @ `af182284`, swift-foundation `migrate-unix` @ `a9c8edea`, swift-foundation-icu `migrate-all` @ `2eb5e8e9`, swift-llbuild `migrate-unix` @ `314f1127`, swift-log `migrate-all` @ `a7d69695`, swift-nio `migrate-unix` @ `b2f3c6c9`, swift-package-manager `migrate-unix` @ `efff7333`, swift-sdk-generator `migrate-unix` @ `bc251e13`, swift-stress-tester `migrate-all` @ `e1702563`, swift-subprocess `migrate-unix` @ `a58cc217`, swift-syntax `migrate-all` @ `e6918103`, swift-testing `migrate-all` @ `7669b72e`, swift-tools-protocols `migrate-unix` @ `2b2c75dc`, swift-tools-support-core `migrate-unix` @ `5f85e38e`): 343 markers in 104 files, of which 1 are outside the packages' targets. Each marker's text is read for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names none is counted under its phrase, with the Darwin names imported under it deciding its status. Status is against System at `1f788961`:

- **missing**: System documents none of it (or only some: *k of n*), and `mapping.ini` has no answer outside System for it.
- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The marker is stale, or the package hasn't adopted the API yet.
- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry speaks for it; read the marker.
- **standard library**: System doesn't name it, and its entry in `mapping.ini` gives the standard library's answer (`swift`), shown with the entry's name.
- **not System's**: System doesn't name it, and its entry in `mapping.ini` is marked `wrap = no`: another module's or library's interface, such as the MachO module's file format, which System doesn't wrap.

The last two are answers outside System, read from `mapping.ini` at System's commit as the Darwin queue of `ecosystem.sh report` reads them; they aren't in the work list below.

A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the standard library; it counts like everything else.

Interfaces: 34 missing, 56 covered, 30 unread, 1 standard library, 121 in all.

| # | Interface | Status | Files | Packages | Family |
|---:|---|---|---:|---|---|
| 1 | C library | unread | 29 | swift-foundation, swift-nio | C library |
| 2 | SystemSockets on FreeBSD and Windows | unread | 17 | swift-nio | SystemSockets on FreeBSD and Windows |
| 3 | SystemSockets on FreeBSD | unread | 15 | swift-nio | SystemSockets on FreeBSD |
| 4 | `extattr_*` | covered (12 names) | 4 | swift-foundation | FilePath.extendedAttribute on FreeBSD |
| 5 | `remove` | covered (doc comment) | 4 | swift-testing | stdio.h |
| 6 | `free` | covered (doc comment) | 3 | swift-crypto, swift-testing | the C heap |
| 7 | `fts_open` | covered (by DirectoryWalk) | 3 | swift-foundation | fts |
| 8 | `fts_read` | covered (by DirectoryWalk) | 3 | swift-foundation | fts |
| 9 | `which` | missing | 3 | swift-testing | which |
| 10 | `openpty` | covered (doc comment) | 2 | swift-build, swift-testing | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 11 | `byteCount` | missing | 2 | swift-foundation | byteCount |
| 12 | `EXIT_SUCCESS` | covered (doc comment) | 2 | swift-testing | stdlib.h |
| 13 | family on Windows (Windows later) | unread | 2 | swift-nio | family on Windows (Windows later) |
| 14 | `FTS_PHYSICAL` | covered (by DirectoryWalk) | 2 | swift-foundation | fts |
| 15 | `MemoryMapping` | missing | 2 | swift-foundation | MemoryMapping |
| 16 | `memset_s` | covered (doc comment) | 2 | swift-crypto | string.h |
| 17 | `NetworkInterface` | missing | 2 | swift-nio | NetworkInterface |
| 18 | `strlen` | covered (doc comment) | 2 | swift-testing | string.h |
| 19 | `_dyld_image_count` | covered (doc comment) | 1 | swift-foundation | _dyld_image_count |
| 20 | `address` | missing | 1 | swift-nio | address |
| 21 | `arm` | missing | 1 | swift-async-algorithms | as UnfairLock is |
| 22 | `backtrace` | covered (doc comment) | 1 | swift-testing | OpenBSD |
| 23 | `bytes` | missing | 1 | swift-nio | bytes |
| 24 | C library's type and errno names that NIOPosix's clients reach through this public | unread | 1 | swift-nio | C library's type and errno names that NIOPosix's clients reach through this public |
| 25 | `calloc` | covered (doc comment) | 1 | swift-testing | the C heap |
| 26 | CInterop.POSIXErrorCode on Windows | unread | 1 | swift-foundation | CInterop.POSIXErrorCode on Windows |
| 27 | `CLocale` | missing | 1 | swift-foundation | CLocale |
| 28 | `CLOCK_MONOTONIC_RAW` | covered (doc comment) | 1 | WasmKit | ClockID.monotonicRaw on FreeBSD |
| 29 | `CNIOLinux` | missing | 1 | swift-nio | CNIOLinux |
| 30 | `copy_file_range` | missing | 1 | swift-testing | file cloning |
| 31 | CString.copy on Windows (string_h's platforms) | unread | 1 | swift-foundation | CString.copy on Windows (string_h's platforms) |
| 32 | `dlsym` | covered (doc comment) | 1 | swift-testing | dynamic loader |
| 33 | `DynamicLibrary` | covered (by DynamicLibrary) | 1 | swift-foundation | DynamicLibrary |
| 34 | Errno.multiHop and .noLink on OpenBSD (EMULTIHOP and ENOLINK, which OpenBSD doesn't define | unread | 1 | WasmKit | Errno.multiHop and .noLink on OpenBSD (EMULTIHOP and ENOLINK, which OpenBSD doesn't define |
| 35 | Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the C values) | unread | 1 | WasmKit | Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the C values) |
| 36 | `EX_UNAVAILABLE` | covered (doc comment) | 1 | swift-testing | sysexits |
| 37 | `EXIT_FAILURE` | covered (doc comment) | 1 | swift-testing | stdlib.h |
| 38 | extended attributes on OpenBSD | unread | 1 | swift-foundation | extended attributes on OpenBSD |
| 39 | `F_SETFD` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 40 | `family` | missing | 1 | swift-nio | family |
| 41 | `fclonefileat` | covered (doc comment) | 1 | swift-testing | sys/clonefile.h |
| 42 | `fcntl` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 43 | `FD_CLOEXEC` | covered (doc comment) | 1 | swift-build | TerminalDescriptor.openPseudoterminal on OpenBSD |
| 44 | `FICLONE` | covered (doc comment) | 1 | swift-testing | linux/fs.h |
| 45 | `file` | missing | 1 | swift-foundation | file |
| 46 | FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD | unread | 1 | swift-foundation | FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD |
| 47 | `fileSize` | missing | 1 | swift-foundation | fileSize |
| 48 | `fmemopen` | covered (doc comment) | 1 | swift-testing | FileStream.open on Android |
| 49 | `fopencookie` | missing | 1 | swift-testing | fopencookie |
| 50 | `FTS_*` | missing | 1 | swift-foundation | fts off Darwin |
| 51 | `fts_close` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 52 | `fts_set` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 53 | `FTS_XDEV` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 54 | `FTSENT` | covered (by DirectoryWalk) | 1 | swift-foundation | fts |
| 55 | `funopen` | missing | 1 | swift-testing | C stdio (provisional) |
| 56 | `getc_unlocked` | missing | 1 | swift-testing | C stdio (provisional) |
| 57 | `getsectiondata` | covered (doc comment) | 1 | swift-testing | mach-o/getsect.h |
| 58 | `images` | missing | 1 | swift-testing | Mach-O |
| 59 | `in6_pktinfo` | covered (doc comment) | 1 | swift-nio | IP-level socket options |
| 60 | `IPTOS_ECN_*` | covered (5 names) | 1 | swift-nio | IPTOS_ECN_* |
| 61 | `isatty` | covered (doc comment) | 1 | swift-testing | unistd.h |
| 62 | `KERN_PROC_PATHNAME` | covered (doc comment) | 1 | swift-testing | FilePath.currentExecutable on FreeBSD |
| 63 | `kinds` | missing | 1 | swift-foundation | fts off Darwin |
| 64 | `malloc` | covered (doc comment) | 1 | swift-crypto | the C heap |
| 65 | `maxCount` | missing | 1 | swift-testing | CallStack.returnAddresses on Musl |
| 66 | `maxSymbolicLinks` | missing | 1 | swift-foundation | maxSymbolicLinks |
| 67 | `memcmp` | covered (doc comment) | 1 | swift-crypto | string.h |
| 68 | `memmem` | covered (doc comment) | 1 | swift-testing | Memory.firstRange on WASI |
| 69 | `memmove` | standard library ([memory copies]: UnsafeMutableRawPointer's copyMemory(from:byteCount:) and …) | 1 | swift-foundation | memmove |
| 70 | Memory.reallocate on Windows | unread | 1 | swift-foundation | Memory.reallocate on Windows |
| 71 | `mptcp_info` | missing | 1 | swift-nio | mptcp_info |
| 72 | `MPTCP_INFO` | missing | 1 | swift-nio | MPTCP_INFO |
| 73 | `NAME_MAX` | covered (doc comment) | 1 | swift-testing | compile-time limits |
| 74 | `none` | missing | 1 | swift-foundation | WASI |
| 75 | OpenOptions.dataSync and .sync on WASI | unread | 1 | WasmKit | OpenOptions.dataSync and .sync on WASI |
| 76 | OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC and O_RSYNC are WASI's | unread | 1 | WasmKit | OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC and O_RSYNC are WASI's |
| 77 | `PathCchIsRoot` | missing | 1 | swift-format | PathCchIsRoot |
| 78 | `pipe2` | covered (doc comment) | 1 | swift-testing | unistd.h |
| 79 | POSIXError's API from an Errno off Darwin | unread | 1 | swift-foundation | POSIXError's API from an Errno off Darwin |
| 80 | POSIXError's API off Darwin | unread | 1 | swift-foundation | POSIXError's API off Darwin |
| 81 | POSIXError's static properties off Darwin | unread | 1 | swift-foundation | POSIXError's static properties off Darwin |
| 82 | `POSIXErrorCode` | covered (doc comment) | 1 | swift-foundation | POSIXErrorCode |
| 83 | PThread.Key on WASI without threads (coverage-5 N2) | unread | 1 | swift-foundation | PThread.Key on WASI without threads (coverage-5 N2) |
| 84 | PThread.Key on Windows | unread | 1 | swift-nio | PThread.Key on Windows |
| 85 | PThread.yield on WASI without threads (coverage-5 N2) | unread | 1 | swift-nio | PThread.yield on WASI without threads (coverage-5 N2) |
| 86 | PThread.yield on WASI without threads (wasip1 has sched_yield) | unread | 1 | WasmKit | PThread.yield on WASI without threads (wasip1 has sched_yield) |
| 87 | `pthread_create` | covered (doc comment) | 1 | swift-async-algorithms | pthread_create |
| 88 | `pthread_join` | covered (doc comment) | 1 | swift-async-algorithms | pthread_join |
| 89 | `pthread_mutex_t` | covered (doc comment) | 1 | swift-certificates | for `LockPrimitive`'s storage |
| 90 | `pthread_t` | covered (doc comment) | 1 | swift-async-algorithms | pthread_t |
| 91 | `raise` | covered (doc comment) | 1 | swift-testing | signal.h |
| 92 | `real` | missing | 1 | swift-foundation | real |
| 93 | `realpath` | covered (doc comment) | 1 | swift-testing | stdlib.h |
| 94 | `release` | covered (doc comment) | 1 | swift-foundation | release |
| 95 | `S_IFWHT` | covered (doc comment) | 1 | swift-nio | FileType.whiteout on OpenBSD |
| 96 | `secureValue` | missing | 1 | swift-foundation | secureValue |
| 97 | `sendmmsg` | covered (doc comment) | 1 | swift-nio | sendmmsg |
| 98 | `SIGABRT` | covered (doc comment) | 1 | swift-testing | signal.h |
| 99 | `SIGSEGV` | covered (doc comment) | 1 | swift-testing | SIGSEGV |
| 100 | `SO_REUSEPORT` | covered (doc comment) | 1 | swift-nio | socket options |
| 101 | SocketDescriptor.SocketOption.reusePort on Android and OpenBSD | unread | 1 | swift-nio | SocketDescriptor.SocketOption.reusePort on Android and OpenBSD |
| 102 | Stat on Windows (Windows later) | unread | 1 | swift-nio | Stat on Windows (Windows later) |
| 103 | Stat's birth time | unread | 1 | swift-nio | Stat's birth time |
| 104 | StatFS.FileSystemID as a number on every platform | unread | 1 | swift-foundation | StatFS.FileSystemID as a number on every platform |
| 105 | stdlib.h and sysexits.h exit codes' C names | unread | 1 | swift-testing | stdlib.h and sysexits.h exit codes' C names |
| 106 | `strchr` | missing | 1 | swift-testing | string.h and ctype.h (provisional) |
| 107 | `strerror_r` | missing | 1 | swift-testing | string.h and ctype.h (provisional) |
| 108 | `strncmp` | covered (doc comment) | 1 | swift-testing | strncmp |
| 109 | SystemConfig.maxIOVectors on FreeBSD and OpenBSD | unread | 1 | swift-nio | SystemConfig.maxIOVectors on FreeBSD and OpenBSD |
| 110 | `SystemIdentity` | missing | 1 | swift-foundation | SystemIdentity |
| 111 | SystemSockets on FreeBSD (PackageDescription can't name .freebsd) | unread | 1 | WasmKit | SystemSockets on FreeBSD (PackageDescription can't name .freebsd) |
| 112 | SystemSockets on OpenBSD | unread | 1 | swift-nio | SystemSockets on OpenBSD |
| 113 | `task_set_exception_ports` | missing | 1 | swift-testing | mach/task.h |
| 114 | `TCP_INFO` | covered (doc comment) | 1 | swift-nio | socket options |
| 115 | test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin round's design call 19) | unread | 1 | swift-nio | test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin round's design call 19) |
| 116 | `timespec_get` | covered (doc comment) | 1 | swift-testing | time.h |
| 117 | `unmap` | missing | 1 | swift-foundation | unmap |
| 118 | `unsafeAddress` | missing | 1 | swift-async-algorithms | as UnfairLock is |
| 119 | `usleep` | covered (as `nanosleep`) | 1 | swift-stress-tester | sleep |
| 120 | `version` | covered (doc comment) | 1 | swift-foundation | version |
| 121 | `wasip1` | missing | 1 | swift-async-algorithms | PThread on WASI without threads |

## Missing, by family

The missing interfaces above, grouped, largest first: the order to fill them in.

| # | Family | Files | Packages | Interfaces |
|---:|---|---:|---|---|
| 1 | which | 3 | swift-testing | `which` |
| 2 | byteCount | 2 | swift-foundation | `byteCount` |
| 3 | C stdio (provisional) | 2 | swift-testing | `funopen`, `getc_unlocked` |
| 4 | MemoryMapping | 2 | swift-foundation | `MemoryMapping` |
| 5 | NetworkInterface | 2 | swift-nio | `NetworkInterface` |
| 6 | string.h and ctype.h (provisional) | 2 | swift-testing | `strchr`, `strerror_r` |
| 7 | address | 1 | swift-nio | `address` |
| 8 | as UnfairLock is | 1 | swift-async-algorithms | `arm`, `unsafeAddress` |
| 9 | bytes | 1 | swift-nio | `bytes` |
| 10 | CallStack.returnAddresses on Musl | 1 | swift-testing | `maxCount` |
| 11 | CLocale | 1 | swift-foundation | `CLocale` |
| 12 | CNIOLinux | 1 | swift-nio | `CNIOLinux` |
| 13 | family | 1 | swift-nio | `family` |
| 14 | file | 1 | swift-foundation | `file` |
| 15 | file cloning | 1 | swift-testing | `copy_file_range` |
| 16 | fileSize | 1 | swift-foundation | `fileSize` |
| 17 | fopencookie | 1 | swift-testing | `fopencookie` |
| 18 | fts off Darwin | 1 | swift-foundation | `FTS_*`, `kinds` |
| 19 | Mach-O | 1 | swift-testing | `images` |
| 20 | mach/task.h | 1 | swift-testing | `task_set_exception_ports` |
| 21 | maxSymbolicLinks | 1 | swift-foundation | `maxSymbolicLinks` |
| 22 | mptcp_info | 1 | swift-nio | `mptcp_info` |
| 23 | MPTCP_INFO | 1 | swift-nio | `MPTCP_INFO` |
| 24 | PathCchIsRoot | 1 | swift-format | `PathCchIsRoot` |
| 25 | PThread on WASI without threads | 1 | swift-async-algorithms | `wasip1` |
| 26 | real | 1 | swift-foundation | `real` |
| 27 | secureValue | 1 | swift-foundation | `secureValue` |
| 28 | SystemIdentity | 1 | swift-foundation | `SystemIdentity` |
| 29 | unmap | 1 | swift-foundation | `unmap` |
| 30 | WASI | 1 | swift-foundation | `none` |

## Markers that name no C interface

- WasmKit: `Sources/CLICommands/TCPListener.swift:104`: SystemSockets on FreeBSD (PackageDescription can't name .freebsd)
- WasmKit: `Sources/WASI/Platform/PAL/PALErrnoMapping.swift:9`: Errno.multiHop and .noLink on OpenBSD (EMULTIHOP and ENOLINK, which OpenBSD doesn't define)
- WasmKit: `Sources/WASI/Platform/PAL/PALErrnoMapping.swift:122`: Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the C values)
- WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:123`: OpenOptions.dataSync and .sync on WASI
- WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:397`: OpenOptions.dataSync and .sync on WASI
- WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:546`: PThread.yield on WASI without threads (wasip1 has sched_yield)
- WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:697`: OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC and O_RSYNC are WASI's fdflags)
- swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`: DynamicLibrary, in the framework build (not built here): dlopen with RTLD_NOLOAD \| RTLD_FIRST, dlsym and dlclose are system-next's DynamicLibrary(_:options: [.noLoad, .first]), address(of:), close() a
- swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:28`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:32`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:40`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:294`: FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD; Windows shares
- swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:853`: extended attributes on OpenBSD, which has none
- swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:94`: Memory.reallocate on Windows, which shares this arm
- swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:22`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:28`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:104`: POSIXError's API from an Errno off Darwin, Linux and Android: each platform's errno set (platforms-2 8.4)
- swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:26`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:32`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:77`: CInterop.POSIXErrorCode on Windows; and POSIXError's API off Darwin, Linux and Android (each platform's errno set, platforms-2 8.4), where Code isn't deprecated
- swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:87`: POSIXError's API off Darwin, Linux and Android: each platform's errno set (platforms-2 8.4)
- swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:558`: POSIXError's static properties off Darwin, Linux and Android: each platform's errno set (platforms-2 8.4)
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift:19`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift:25`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Files.swift:752`: StatFS.FileSystemID as a number on every platform: on FreeBSD and OpenBSD, System's StatFS
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift:18`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift:25`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift:29`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift:36`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/Platform.swift:254`: CString.copy on Windows (string_h's platforms), as strlcpy, which returns for a size of 0
- swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:22`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:27`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/_ThreadLocal.swift:19`: the C library, for this file's C arms
- swift-foundation: `Sources/FoundationEssentials/_ThreadLocal.swift:57`: PThread.Key on WASI without threads (coverage-5 N2); Windows shares the arm
- swift-foundation: `Sources/FoundationInternationalization/Formatting/Date/ICUDateFormatter.swift:23`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/DataTests.swift:23`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/DecimalTests.swift:18`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/DecimalTests.swift:21`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:25`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/ProcessInfoTests.swift:26`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationEssentialsTests/ProcessInfoTests.swift:33`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationInternationalizationTests/DateComponentsTests.swift:29`: the C library, for this file's C arms
- swift-foundation: `Tests/FoundationInternationalizationTests/DateComponentsTests.swift:32`: the C library, for this file's C arms
- swift-nio: `Sources/NIOConcurrencyHelpers/atomics.swift:29`: PThread.yield on WASI without threads (coverage-5 N2)
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:78`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:89`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:98`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:226`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:256`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:267`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:279`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:294`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:315`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:338`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:361`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:381`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:403`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:418`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:429`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:440`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:451`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:462`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:476`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:490`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:501`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:512`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:523`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:534`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:546`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:560`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:630`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:641`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:652`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:663`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:674`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:685`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:696`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:707`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:722`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:739`: SocketDescriptor.SocketOption.reusePort on Android and OpenBSD, and SystemSockets on
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:780`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:831`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/ByteBuffer-core.swift:22`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/ByteBuffer-core.swift:26`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/GlobalSingletons.swift:23`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/GlobalSingletons.swift:27`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/IO.swift:34`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/IO.swift:38`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/Interfaces.swift:22`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/Interfaces.swift:28`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/Interfaces.swift:31`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/Interfaces.swift:211`: SystemSockets on FreeBSD, OpenBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:74`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:77`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:139`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:160`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:181`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:213`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:226`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:270`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:279`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:302`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:321`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:330`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:356`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:377`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:404`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:420`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:435`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:450`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:465`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:491`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:530`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:567`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:611`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:632`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:665`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:701`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:734`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:819`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:872`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:894`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:996`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:1012`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:1046`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:1059`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:1104`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketAddresses.swift:1126`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:29`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:33`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:39`: the C library, for this file's C arms
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:192`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:221`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:246`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:261`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:412`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOFS/FileInfo.swift:19`: the C library, for this file's C arms
- swift-nio: `Sources/NIOFS/Internal/System Calls/Mocking.swift:25`: the C library, for this file's C arms
- swift-nio: `Sources/NIOFS/Internal/SystemFileHandle.swift:25`: the C library, for this file's C arms
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:84`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:95`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:104`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:123`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:151`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:263`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:315`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:96`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:171`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:360`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:376`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:441`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:69`: family on Windows (Windows later)
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:84`: family on Windows (Windows later)
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:99`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:112`: family on Windows (Windows later)
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:138`: family on Windows (Windows later)
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:247`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:349`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/BaseSocket.swift:379`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:25`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:28`: the C library, for this file's C arms
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:42`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:203`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:242`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:290`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:310`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:335`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:437`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:478`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/ControlMessage.swift:490`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:159`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:230`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/GetaddrinfoResolver.swift:202`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/NonBlockingFileIO.swift:1358`: Stat on Windows (Windows later)
- swift-nio: `Sources/NIOPosix/PendingDatagramWritesManager.swift:188`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/Socket.swift:213`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/Socket.swift:232`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/Socket.swift:281`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/Socket.swift:300`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/SocketChannel.swift:1294`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/SocketChannel.swift:1310`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/SocketChannel.swift:1333`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/SocketChannel.swift:1353`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/System.swift:70`: the C library's type and errno names that NIOPosix's clients reach through this public
- swift-nio: `Sources/NIOPosix/System.swift:133`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:151`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:459`: SystemConfig.maxIOVectors on FreeBSD and OpenBSD; SocketDescriptor.ShutdownKind (SystemSockets) on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:528`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:535`: SystemSockets on OpenBSD: it uses C constants that OpenBSD lacks (IP_PKTINFO, IP_RECVTOS, TCP_KEEPIDLE, TCP_KEEPINTVL, TCP_KEEPCNT), so NIO's manifest doesn't name .openbsd for it
- swift-nio: `Sources/NIOPosix/System.swift:552`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:567`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:604`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:636`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:681`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:717`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:753`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:781`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:868`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:889`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:960`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:1037`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:1063`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/System.swift:1218`: SystemSockets on FreeBSD
- swift-nio: `Sources/NIOPosix/Thread.swift:251`: PThread.Key on Windows
- swift-nio: `Sources/NIOPosix/Thread.swift:312`: PThread.Key on Windows
- swift-nio: `Sources/NIOPosix/Thread.swift:332`: PThread.Key on Windows
- swift-nio: `Sources/NIOPosix/VsockAddress.swift:225`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/VsockAddress.swift:237`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/NIOPosix/VsockAddress.swift:248`: SystemSockets on FreeBSD and Windows
- swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:19`: the C library, for this file's C arms
- swift-nio: `Sources/_NIOFileSystem/Internal/System Calls/Mocking.swift:25`: the C library, for this file's C arms
- swift-nio: `Sources/_NIOFileSystem/Internal/SystemFileHandle.swift:25`: the C library, for this file's C arms
- swift-nio: `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift:30`: the C library, for this file's C arms
- swift-nio: `Tests/NIOFSTests/FileInfoTests.swift:25`: Stat's birth time, flags and generation (CInterop.Stat.creationTime, flags and generationNumber) on FreeBSD and OpenBSD, which have them, as Darwin does: this arm sets and compares the C struct's fiel
- swift-nio: `Tests/NIOPosixTests/ChannelPipelineTest.swift:251`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/ControlMessageTests.swift:34`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:28`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:154`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:175`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:200`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:213`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/MulticastTest.swift:160`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/MulticastTest.swift:182`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:49`: family on Windows (Windows later)
- swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:191`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:73`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:89`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:149`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:194`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:205`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:239`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:281`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:317`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:378`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:603`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:643`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketChannelTest.swift:63`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:159`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:182`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:247`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:260`: SystemSockets on FreeBSD and Windows
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:281`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:289`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:304`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SyscallAbstractionLayer.swift:515`: SystemSockets on FreeBSD
- swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:116`: the test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin round's design call 19)
- swift-nio: `Tests/NIOPosixTests/SystemTest.swift:57`: SystemSockets on FreeBSD
- swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:113`: stdlib.h and sysexits.h exit codes' C names, such as

## Where

<details><summary>Each interface's markers (package: file:line)</summary>

- C library (unread): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:28`; swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:32`; swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:40`; swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:22`; swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:28`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:26`; swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:32`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift:19`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift:25`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift:18`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift:25`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift:29`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift:36`; swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:22`; swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:27`; swift-foundation: `Sources/FoundationEssentials/_ThreadLocal.swift:19`; swift-foundation: `Sources/FoundationInternationalization/Formatting/Date/ICUDateFormatter.swift:23`; swift-foundation: `Tests/FoundationEssentialsTests/DataTests.swift:23`; swift-foundation: `Tests/FoundationEssentialsTests/DecimalTests.swift:18`; swift-foundation: `Tests/FoundationEssentialsTests/DecimalTests.swift:21`; swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:25`; swift-foundation: `Tests/FoundationEssentialsTests/ProcessInfoTests.swift:26`; swift-foundation: `Tests/FoundationEssentialsTests/ProcessInfoTests.swift:33`; swift-foundation: `Tests/FoundationInternationalizationTests/DateComponentsTests.swift:29`; swift-foundation: `Tests/FoundationInternationalizationTests/DateComponentsTests.swift:32`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:78`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:89`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:98`; swift-nio: `Sources/NIOCore/ByteBuffer-core.swift:22`; swift-nio: `Sources/NIOCore/ByteBuffer-core.swift:26`; swift-nio: `Sources/NIOCore/GlobalSingletons.swift:23`; swift-nio: `Sources/NIOCore/GlobalSingletons.swift:27`; swift-nio: `Sources/NIOCore/IO.swift:34`; swift-nio: `Sources/NIOCore/IO.swift:38`; swift-nio: `Sources/NIOCore/Interfaces.swift:22`; swift-nio: `Sources/NIOCore/Interfaces.swift:28`; swift-nio: `Sources/NIOCore/Interfaces.swift:31`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:77`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:29`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:33`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:39`; swift-nio: `Sources/NIOFS/FileInfo.swift:19`; swift-nio: `Sources/NIOFS/Internal/System Calls/Mocking.swift:25`; swift-nio: `Sources/NIOFS/Internal/SystemFileHandle.swift:25`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:28`; swift-nio: `Sources/_NIOFileSystem/FileInfo.swift:19`; swift-nio: `Sources/_NIOFileSystem/Internal/System Calls/Mocking.swift:25`; swift-nio: `Sources/_NIOFileSystem/Internal/SystemFileHandle.swift:25`; swift-nio: `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift:30`
- SystemSockets on FreeBSD and Windows (unread): swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:226`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:256`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:267`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:279`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:315`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:381`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:418`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:429`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:440`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:451`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:462`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:476`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:490`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:501`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:512`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:523`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:534`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:546`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:560`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:630`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:641`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:652`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:663`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:674`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:685`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:696`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:707`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:139`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:160`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:181`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:213`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:226`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:270`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:279`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:302`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:321`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:330`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:356`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:377`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:404`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:420`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:435`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:450`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:465`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:491`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:530`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:567`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:665`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:701`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:734`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:894`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:1012`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:1059`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:1104`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:1126`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:192`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:221`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:246`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:261`; swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:412`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:84`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:95`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:104`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:123`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:151`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:263`; swift-nio: `Sources/NIOPosix/BSDSocketAPICommon.swift:315`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:99`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:247`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:349`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:379`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:203`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:242`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:290`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:310`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:335`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:437`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:478`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:490`; swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:159`; swift-nio: `Sources/NIOPosix/PendingDatagramWritesManager.swift:188`; swift-nio: `Sources/NIOPosix/Socket.swift:213`; swift-nio: `Sources/NIOPosix/Socket.swift:232`; swift-nio: `Sources/NIOPosix/Socket.swift:281`; swift-nio: `Sources/NIOPosix/Socket.swift:300`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:1294`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:1310`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:1333`; swift-nio: `Sources/NIOPosix/SocketChannel.swift:1353`; swift-nio: `Sources/NIOPosix/VsockAddress.swift:225`; swift-nio: `Sources/NIOPosix/VsockAddress.swift:237`; swift-nio: `Sources/NIOPosix/VsockAddress.swift:248`; swift-nio: `Tests/NIOPosixTests/ChannelPipelineTest.swift:251`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:154`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:175`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:200`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:213`; swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:191`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:73`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:89`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:149`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:194`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:205`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:239`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:378`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:603`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:643`; swift-nio: `Tests/NIOPosixTests/SocketChannelTest.swift:63`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:159`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:182`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:247`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:260`
- SystemSockets on FreeBSD (unread): swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:294`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:338`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:361`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:403`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:722`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:780`; swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:831`; swift-nio: `Sources/NIOCore/Interfaces.swift:211`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:74`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:611`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:632`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:819`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:872`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:996`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:1046`; swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:96`; swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:171`; swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:360`; swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:376`; swift-nio: `Sources/NIOPosix/BSDSocketAPIPosix.swift:441`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:25`; swift-nio: `Sources/NIOPosix/ControlMessage.swift:42`; swift-nio: `Sources/NIOPosix/DatagramVectorReadManager.swift:230`; swift-nio: `Sources/NIOPosix/GetaddrinfoResolver.swift:202`; swift-nio: `Sources/NIOPosix/System.swift:133`; swift-nio: `Sources/NIOPosix/System.swift:151`; swift-nio: `Sources/NIOPosix/System.swift:528`; swift-nio: `Sources/NIOPosix/System.swift:552`; swift-nio: `Sources/NIOPosix/System.swift:567`; swift-nio: `Sources/NIOPosix/System.swift:604`; swift-nio: `Sources/NIOPosix/System.swift:636`; swift-nio: `Sources/NIOPosix/System.swift:681`; swift-nio: `Sources/NIOPosix/System.swift:717`; swift-nio: `Sources/NIOPosix/System.swift:753`; swift-nio: `Sources/NIOPosix/System.swift:781`; swift-nio: `Sources/NIOPosix/System.swift:868`; swift-nio: `Sources/NIOPosix/System.swift:889`; swift-nio: `Sources/NIOPosix/System.swift:960`; swift-nio: `Sources/NIOPosix/System.swift:1037`; swift-nio: `Sources/NIOPosix/System.swift:1063`; swift-nio: `Sources/NIOPosix/System.swift:1218`; swift-nio: `Tests/NIOPosixTests/ControlMessageTests.swift:34`; swift-nio: `Tests/NIOPosixTests/HappyEyeballsTest.swift:28`; swift-nio: `Tests/NIOPosixTests/MulticastTest.swift:160`; swift-nio: `Tests/NIOPosixTests/MulticastTest.swift:182`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:281`; swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:317`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:281`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:289`; swift-nio: `Tests/NIOPosixTests/SocketOptionProviderTest.swift:304`; swift-nio: `Tests/NIOPosixTests/SyscallAbstractionLayer.swift:515`; swift-nio: `Tests/NIOPosixTests/SystemTest.swift:57`
- `extattr_*` (covered): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:68`; swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:850`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Files.swift:498`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Files.swift:548`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift:198`
- `remove` (covered): swift-testing: `Tests/TestingTests/AttachmentTests.swift:95`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:112`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:143`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:151`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:179`; swift-testing: `Tests/TestingTests/AttachmentTests.swift:199`; swift-testing: `Tests/TestingTests/Support/ColorTests.swift:40`; swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:291`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:387`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:413`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:435`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:464`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:563`; swift-testing: `Tests/TestingTests/SwiftPMTests.swift:613`
- `free` (covered): swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:161`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:276`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:370`; swift-testing: `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift:150`; swift-testing: `Tests/TestingTests/ABIEntryPointTests.swift:242`
- `fts_open` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:279`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:487`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:1171`
- `fts_read` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:279`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:487`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:1171`
- `which` (missing): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/Support/Additions/CommandLineAdditions.swift:63`; swift-testing: `Sources/Testing/Support/Environment.swift:90`
- `openpty` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`; swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:168`
- `byteCount` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:472`; swift-foundation: `Sources/FoundationEssentials/Data/Data.swift:84`
- `EXIT_SUCCESS` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:152`; swift-testing: `Sources/Testing/ExitTests/ExitTest.Condition.swift:232`
- family on Windows (Windows later) (unread): swift-nio: `Sources/NIOPosix/BaseSocket.swift:69`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:84`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:112`; swift-nio: `Sources/NIOPosix/BaseSocket.swift:138`; swift-nio: `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift:49`
- `FTS_PHYSICAL` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift:279`; swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:1171`
- `MemoryMapping` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:472`; swift-foundation: `Sources/FoundationEssentials/Data/Data.swift:84`
- `memset_s` (covered): swift-crypto: `Sources/Crypto/Util/SecureBytes.swift:316`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:29`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:38`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:47`; swift-crypto: `Sources/Crypto/Util/Zeroization.swift:56`
- `NetworkInterface` (missing): swift-nio: `Sources/NIOCore/SystemCallHelpers.swift:31`; swift-nio: `Sources/NIOCore/SystemCallHelpers.swift:238`; swift-nio: `Sources/NIOPosix/System.swift:164`; swift-nio: `Sources/NIOPosix/System.swift:1080`
- `strlen` (covered): swift-testing: `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift:150`; swift-testing: `Tests/TestingTests/ABIEntryPointTests.swift:242`
- `_dyld_image_count` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:69`
- `address` (missing): swift-nio: `Sources/NIOCore/SocketAddresses.swift:923`; swift-nio: `Sources/NIOCore/SocketAddresses.swift:969`
- `arm` (missing): swift-async-algorithms: `Sources/AsyncAlgorithms/Locking.swift:15`
- `backtrace` (covered): swift-testing: `Sources/Testing/SourceAttribution/Backtrace.swift:84`
- `bytes` (missing): swift-nio: `Sources/NIOCore/SocketAddresses.swift:969`
- C library's type and errno names that NIOPosix's clients reach through this public (unread): swift-nio: `Sources/NIOPosix/System.swift:70`
- `calloc` (covered): swift-testing: `Sources/Testing/ABI/ABI.swift:364`
- CInterop.POSIXErrorCode on Windows (unread): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:77`
- `CLocale` (missing): swift-foundation: `Tests/FoundationEssentialsTests/JSONEncoderTests.swift:1514`
- `CLOCK_MONOTONIC_RAW` (covered): WasmKit: `Sources/WASI/Platform/PAL/PALClock.swift:55`
- `CNIOLinux` (missing): swift-nio: `Sources/NIOPosix/System.swift:105`
- `copy_file_range` (missing): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- CString.copy on Windows (string_h's platforms) (unread): swift-foundation: `Sources/FoundationEssentials/Platform.swift:254`
- `dlsym` (covered): swift-testing: `Sources/Testing/Support/GetSymbol.swift:34`
- `DynamicLibrary` (covered): swift-foundation: `Sources/FoundationEssentials/AttributedString/AttributeScope.swift:68`
- Errno.multiHop and .noLink on OpenBSD (EMULTIHOP and ENOLINK, which OpenBSD doesn't define (unread): WasmKit: `Sources/WASI/Platform/PAL/PALErrnoMapping.swift:9`
- Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the C values) (unread): WasmKit: `Sources/WASI/Platform/PAL/PALErrnoMapping.swift:122`
- `EX_UNAVAILABLE` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/SwiftPMEntryPoint.swift:31`
- `EXIT_FAILURE` (covered): swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:38`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:57`; swift-testing: `Sources/Testing/ABI/EntryPoints/EntryPoint.swift:161`
- extended attributes on OpenBSD (unread): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:853`
- `F_SETFD` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `family` (missing): swift-nio: `Tests/NIOPosixTests/SocketAddressTest.swift:449`
- `fclonefileat` (covered): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- `fcntl` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `FD_CLOEXEC` (covered): swift-build: `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift:127`
- `FICLONE` (covered): swift-testing: `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125`
- `file` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:472`
- FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD (unread): swift-foundation: `Sources/FoundationEssentials/Data/Data+Writing.swift:294`
- `fileSize` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:472`
- `fmemopen` (covered): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:225`
- `fopencookie` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:318`
- `FTS_*` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`
- `fts_close` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`
- `fts_set` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`
- `FTS_XDEV` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations.swift:487`
- `FTSENT` (covered): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`
- `funopen` (missing): swift-testing: `Tests/TestingTests/Support/FileHandleTests.swift:318`
- `getc_unlocked` (missing): swift-testing: `Sources/Testing/Support/FileHandle.swift:518`
- `getsectiondata` (covered): swift-testing: `Sources/_TestDiscovery/SectionBounds.swift:44`
- `images` (missing): swift-testing: `Sources/_TestDiscovery/SectionBounds.swift:44`
- `in6_pktinfo` (covered): swift-nio: `Sources/NIOPosix/System.swift:105`
- `IPTOS_ECN_*` (covered): swift-nio: `Sources/NIOPosix/System.swift:105`
- `isatty` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:800`
- `KERN_PROC_PATHNAME` (covered): swift-testing: `Sources/Testing/Support/Additions/CommandLineAdditions.swift:63`
- `kinds` (missing): swift-foundation: `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift:139`
- `malloc` (covered): swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:161`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:276`; swift-crypto: `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift:370`
- `maxCount` (missing): swift-testing: `Sources/Testing/SourceAttribution/Backtrace.swift:84`
- `maxSymbolicLinks` (missing): swift-foundation: `Sources/FoundationEssentials/String/String+Path.swift:668`
- `memcmp` (covered): swift-crypto: `Sources/_CryptoExtras/RSA/RSA_boring.swift:966`
- `memmem` (covered): swift-testing: `Sources/Testing/ABI/ABI.VersionNumber.swift:229`
- `memmove` (standard library): swift-foundation: `Sources/FoundationEssentials/Platform.swift:112`
- Memory.reallocate on Windows (unread): swift-foundation: `Sources/FoundationEssentials/Data/Representations/DataStorage.swift:94`
- `mptcp_info` (missing): swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:25`
- `MPTCP_INFO` (missing): swift-nio: `Sources/NIOCore/SocketOptionProvider.swift:25`
- `NAME_MAX` (covered): swift-testing: `Tests/TestingTests/AttachmentTests.swift:163`
- `none` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data+Reading.swift:68`
- OpenOptions.dataSync and .sync on WASI (unread): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:123`; WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:397`
- OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC and O_RSYNC are WASI's (unread): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:697`
- `PathCchIsRoot` (missing): swift-format: `Sources/SwiftFormat/Utilities/URL+isRoot.swift:16`
- `pipe2` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:722`
- POSIXError's API from an Errno off Darwin (unread): swift-foundation: `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift:104`
- POSIXError's API off Darwin (unread): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:87`
- POSIXError's static properties off Darwin (unread): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:558`
- `POSIXErrorCode` (covered): swift-foundation: `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift:14`
- PThread.Key on WASI without threads (coverage-5 N2) (unread): swift-foundation: `Sources/FoundationEssentials/_ThreadLocal.swift:57`
- PThread.Key on Windows (unread): swift-nio: `Sources/NIOPosix/Thread.swift:251`; swift-nio: `Sources/NIOPosix/Thread.swift:312`; swift-nio: `Sources/NIOPosix/Thread.swift:332`
- PThread.yield on WASI without threads (coverage-5 N2) (unread): swift-nio: `Sources/NIOConcurrencyHelpers/atomics.swift:29`
- PThread.yield on WASI without threads (wasip1 has sched_yield) (unread): WasmKit: `Sources/WASI/Platform/PAL/PALFileDescriptor.swift:546`
- `pthread_create` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `pthread_join` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `pthread_mutex_t` (covered): swift-certificates: `Sources/X509/Lock.swift:23`
- `pthread_t` (covered): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`
- `raise` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:80`
- `real` (missing): swift-foundation: `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift:206`
- `realpath` (covered): swift-testing: `Sources/Testing/Support/FileHandle.swift:901`
- `release` (covered): swift-foundation: `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift:432`
- `S_IFWHT` (covered): swift-nio: `Tests/NIOFSTests/FileTypeTests.swift:48`
- `secureValue` (missing): swift-foundation: `Sources/FoundationEssentials/Platform.swift:232`
- `sendmmsg` (covered): swift-nio: `Sources/NIOPosix/System.swift:105`
- `SIGABRT` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:50`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:89`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:149`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:181`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:187`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:813`
- `SIGSEGV` (covered): swift-testing: `Tests/TestingTests/ExitTestTests.swift:80`; swift-testing: `Tests/TestingTests/ExitTestTests.swift:813`
- `SO_REUSEPORT` (covered): swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:74`
- SocketDescriptor.SocketOption.reusePort on Android and OpenBSD (unread): swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:739`
- Stat on Windows (Windows later) (unread): swift-nio: `Sources/NIOPosix/NonBlockingFileIO.swift:1358`
- Stat's birth time (unread): swift-nio: `Tests/NIOFSTests/FileInfoTests.swift:25`
- StatFS.FileSystemID as a number on every platform (unread): swift-foundation: `Sources/FoundationEssentials/FileManager/FileManager+Files.swift:752`
- stdlib.h and sysexits.h exit codes' C names (unread): swift-testing: `Sources/Testing/ExitTests/ExitStatus.swift:113`
- `strchr` (missing): swift-testing: `Sources/Testing/Support/Environment.swift:90`
- `strerror_r` (missing): swift-testing: `Sources/Testing/Support/CError.swift:76`
- `strncmp` (covered): swift-testing: `Sources/Testing/Support/Environment.swift:90`
- SystemConfig.maxIOVectors on FreeBSD and OpenBSD (unread): swift-nio: `Sources/NIOPosix/System.swift:459`
- `SystemIdentity` (missing): swift-foundation: `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift:432`
- SystemSockets on FreeBSD (PackageDescription can't name .freebsd) (unread): WasmKit: `Sources/CLICommands/TCPListener.swift:104`
- SystemSockets on OpenBSD (unread): swift-nio: `Sources/NIOPosix/System.swift:535`
- `task_set_exception_ports` (missing): swift-testing: `Sources/Testing/ExitTests/ExitTest.swift:219`
- `TCP_INFO` (covered): swift-nio: `Sources/NIOCore/BSDSocketAPI.swift:574`
- test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin round's design call 19) (unread): swift-nio: `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift:116`
- `timespec_get` (covered): swift-testing: `Sources/Testing/Events/Clock.swift:33`
- `unmap` (missing): swift-foundation: `Sources/FoundationEssentials/Data/Data.swift:84`
- `unsafeAddress` (missing): swift-async-algorithms: `Sources/AsyncAlgorithms/Locking.swift:15`
- `usleep` (covered): swift-stress-tester: `SourceKitStressTester/Tests/SwiftCWrapperToolTests/SwiftCWrapperToolTests.swift:89` (outside the targets)
- `version` (covered): swift-foundation: `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift:432`
- `wasip1` (missing): swift-async-algorithms: `Sources/AsyncSequenceValidation/TaskDriver.swift:17`

</details>

# 4. Platform imports

The goal: no library of the repositories that swift's update-checkout clones for the main scheme imports a platform C module (the modules `modules.ini` counts: Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT, visualc, MachO, libkern, kcdata, libunwind, unwind_h, pthread, sched, sys_select, unistd, xlocale, nl_types, assert_h, complex_h, ctype_h, errno_h, fenv_h, float_h, inttypes_h, iso646_h, limits_h, locale_h, math_h, setjmp_h, signal_h, stdalign_h, stdarg_h, stdatomic_h, stdbool_h, stddef_h, stdint_h, stdio_h, stdlib_h, stdnoreturn_h, string_h, threads_h, time_h, and any module named `*_h`) in any form, on any platform. Each repository is read at its migrated clone in `../adopters`, on its newest migration branch (the first of migrate-all, migrate-unix, migrate-darwin that it has; swift-foundation: migrate-unix or no-darwin), else at its clone in `../ecosystem` as it is, else it's *not cloned*. Left out: swift (the compiler, the runtime, and the platform modules' own overlays); swift-system (System itself, whose imports are what it wraps). A platform's count is the library files whose build for that platform compiles an import of one of the modules, with each `#if` evaluated for it by adopter-coverage's `platforms.py`: an `import Glibc` under `#elseif canImport(Glibc)`, after a branch that Linux takes, counts for FreeBSD and OpenBSD but not for Linux. *Maybe*: files counted because a flag the scan can't read (a trait, a build setting) decides whether the import compiles. *Lexical* counts each import in any branch, compiled or not, as the tracker did before: for a platform, the files that import its own modules (Darwin: Darwin, MachO, libkern, kcdata; Linux (glibc): Glibc; Musl: Musl; Android: Android, Bionic; WASI: WASILibc; FreeBSD: Glibc; OpenBSD: Glibc; Windows: ucrt, WinSDK, CRT, visualc). Kinds are by path (see [How this is computed](#how-this-is-computed)): *library* is under `Sources` (or `src`, `lib`, `products`), *tests* under a test directory, *other* the rest (benchmarks, examples, tools, plugins, docs, utilities), and a *nested package* is under a directory with its own `Package.swift`; the last three are counted lexically only.

| Platform | Library files that import one | Repositories | Library files, lexical |
|---|---:|---:|---:|
| Darwin | 10 | 2 | 13 |
| Linux (glibc) | 20 | 5 | 51 |
| Musl | 18 | 4 | 20 |
| Android | 33 | 5 | 33 |
| WASI | 33 | 5 | 33 |
| FreeBSD | 49 (1 maybe) | 7 | 51 |
| OpenBSD | 48 | 6 | 51 |
| Windows | 182 (4 maybe) | 21 | 182 |
| **Any** | 204 | 22 | 206 |

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
| swift-async-algorithms | `../adopters/swift-async-algorithms` `migrate-all` @ `0178ed40` | 1 | — | 1 | 1 | 1 | — | 1 | 1 | 1 | — | — | — |
| swift-atomics | `../ecosystem/swift-atomics` @ `0442cb5a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-build | `../adopters/swift-build` `migrate-all` @ `4f55b04e` | 9 | — | — | — | — | — | — | — | 9 | 2 | — | — |
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
| swift-experimental-string-processing | `../adopters/swift-experimental-string-processing` `migrate-all` @ `f0d0fc7f` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-format | `../adopters/swift-format` `migrate-all` @ `af182284` | 1 | — | — | — | — | — | — | — | 1 | — | — | — |
| swift-foundation | `../adopters/swift-foundation` `migrate-unix` @ `a9c8edea` | 31 | — | 6 | 7 | 9 | 16 | 14 | 14 | 27 | 7 | — | — |
| swift-foundation-icu | `../adopters/swift-foundation-icu` `migrate-all` @ `2eb5e8e9` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-installer-scripts | not cloned | | | | | | | | | | | | |
| swift-integration-tests | not cloned | | | | | | | | | | | | |
| swift-llvm-bindings | `../ecosystem/swift-llvm-bindings` @ `c1fffb92` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-lmdb | `../ecosystem/swift-lmdb` @ `866bc256` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-log | `../adopters/swift-log` `migrate-all` @ `a7d69695` | 3 | — | — | — | — | — | — | — | 3 | 3 | — | — |
| swift-markdown | `../ecosystem/swift-markdown` @ `392b73b8` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-nio | `../adopters/swift-nio` `migrate-unix` @ `b2f3c6c9` | 45 | — | 1 | 3 | 3 | 9 | 20 | 20 | 34 | 18 | — | — |
| swift-numerics | `../ecosystem/swift-numerics` @ `0a5bc040` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-sdk-generator | `../adopters/swift-sdk-generator` `migrate-unix` @ `bc251e13` | — | — | — | — | — | — | — | — | — | 1 | — | — |
| swift-stress-tester | `../adopters/swift-stress-tester` `migrate-all` @ `e1702563` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-subprocess | `../adopters/swift-subprocess` `migrate-unix` @ `a58cc217` | 10 | — | — | — | — | — | — | — | 10 | 7 | — | — |
| swift-syntax | `../adopters/swift-syntax` `migrate-all` @ `e6918103` | — | — | — | — | — | — | — | — | — | — | 1 | 2 |
| swift-testing | `../adopters/swift-testing` `migrate-all` @ `7669b72e` | 10 | — | — | — | — | — | — | — | 10 (1 maybe) | 1 | — | — |
| swift-toolchain-sarif | `../ecosystem/swift-toolchain-sarif` @ `d611f23a` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-toolchain-sqlite | `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0` | — | — | — | — | — | — | — | — | — | — | — | — |
| swift-tools-protocols | `../adopters/swift-tools-protocols` `migrate-unix` @ `2b2c75dc` | 3 | — | — | — | — | — | — | — | 3 | 2 | — | — |
| swift-tools-support-core | `../adopters/swift-tools-support-core` `migrate-unix` @ `5f85e38e` | 6 | — | — | — | — | — | — | — | 6 | — | — | — |
| swift-xcode-playground-support | not cloned | | | | | | | | | | | | |
| swiftpm | `../adopters/swift-package-manager` `migrate-unix` @ `efff7333` | 12 | — | — | — | 1 | — | 1 | — | 11 | — | — | 1 |
| wasi-libc | not cloned | | | | | | | | | | | | |
| wasmkit | `../adopters/WasmKit` `migrate-unix` @ `d0f9f8de` | 10 | — | — | — | — | 1 | 1 (1 maybe) | 1 | 9 (3 maybe) | 1 | — | 1 |
| zlib | not cloned | | | | | | | | | | | | |

38 repositories read; 22 compile an import of a platform module in library code on some platform: indexstore-db, llbuild, sourcekit-lsp, swift-argument-parser, swift-async-algorithms, swift-build, swift-certificates, swift-corelibs-foundation, swift-corelibs-xctest, swift-crypto, swift-docc, swift-driver, swift-format, swift-foundation, swift-log, swift-nio, swift-subprocess, swift-testing, swift-tools-protocols, swift-tools-support-core, swiftpm, wasmkit.

All repositories, files by module and kind, lexically (the counted modules any file imports):

| Module | Library | Tests | Other | Nested packages | All |
|---|---:|---:|---:|---:|---:|
| Darwin | 13 | 2 | 1 | 2 | 18 |
| Glibc | 51 | 13 | 0 | 2 | 66 |
| Musl | 20 | 0 | 0 | 1 | 21 |
| Bionic | 11 | 3 | 0 | 0 | 14 |
| Android | 23 | 11 | 0 | 1 | 35 |
| WASILibc | 33 | 5 | 0 | 1 | 39 |
| ucrt | 38 | 9 | 0 | 1 | 48 |
| WinSDK | 156 | 35 | 0 | 2 | 193 |
| CRT | 34 | 12 | 0 | 0 | 46 |
| MachO | 1 | 0 | 1 | 0 | 2 |
| unistd | 4 | 0 | 0 | 0 | 4 |
| stdlib_h | 3 | 0 | 0 | 0 | 3 |
| string_h | 1 | 0 | 0 | 0 | 1 |
| threads_h | 1 | 0 | 0 | 0 | 1 |
| **Any** | 206 | 60 | 1 | 4 | 271 |

# 5. Sites left

**The floor** (no site left on a platform but exceptions) holds on no platform: Darwin (70 sites left), Linux (89 sites left), Musl (85 sites left), Android (116 sites left), FreeBSD (316 sites left), OpenBSD (306 sites left), WASI (213 sites left), Windows (672 sites left).

The ledger: every site in the update-checkout cluster that still uses a platform C module, each with one category and its reason, so that nothing left on C is lost; in full in `ledger.json` (status.sh's `STATUS_LEDGER_JSON`). A *site* is an import of a module that `Utilities/adopter-coverage/modules.ini` counts ([count]) or lists ([report]), at its file and line, with the platforms whose build compiles it (`?`: maybe) and the C names it serves there; or a `SYSTEM-GAP:` marker that sits over no such import (one that does is part of the imports' reason). Every library, test and other file is read, at the commits section 4 reads, and the swift repository too. Categories, by `Utilities/adopter-coverage/exceptions.ini`'s entries first, then by each C name against System at `coverage-9` @ `1f788961` and `Utilities/adopter-coverage/mapping.ini`: 569 unexplained, 217 System gap, 23 queued, 33 exception, 123 undecided, 62 standard library; 27 excluded. How each is decided is in [How this is computed](#how-this-is-computed).

## Unexplained

Sites that no entry and no System gap explains: the ones to look at. Either System covers every C name the site serves on its platforms (the site could move now, or the scan misses a name), or the scan found none (a type or macro it can't see, or an import nothing uses), or a marker names no C interface.

| Repository | File | Lines: what | Platforms | Why |
|---|---|---|---|---|
| indexstore-db | `Sources/IndexStore/dlopen.swift` | 16 `CRT`, 17 `WinSDK` | Windows | System covers every C name it serves there: GetLastError, GetProcAddress, HMODULE, LoadLibraryW |
| indexstore-db | `Sources/index-dump/index-dump.swift` | 18 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildDBBindings.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildKey.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/BuildValue.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `products/llbuildSwift/Internals.swift` | 12 `ucrt`, 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| llbuild | `unittests/Swift/BuildSystemBindingsTests.swift` | 19 `WinSDK` | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| llbuild | `unittests/Swift/BuildSystemEngineTests.swift` | 22 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| sourcekit-lsp | `Sources/BuildServerIntegration/CompilationDatabase.swift` | 22 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Sources/ClangLanguageService/ClangLanguageService.swift` | 29 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Sources/SemanticIndex/UpdateIndexStoreTaskDescription.swift` | 31 `WinSDK` | Windows | System covers every C name it serves there: ERROR_FILENAME_EXCED_RANGE |
| sourcekit-lsp | `Sources/SourceKitD/SKDRequestArray.swift` | 16 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SourceKitD/SKDRequestDictionary.swift` | 17 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SourceKitD/SKDResponse.swift` | 17 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SourceKitD/SKDResponseArray.swift` | 16 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SourceKitD/SKDResponseDictionary.swift` | 16 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SourceKitD/dlopen.swift` | 18 `CRT`, 19 `WinSDK` | Windows | System covers every C name it serves there: FreeLibrary, GetLastError, GetProcAddress, HMODULE, LoadLibraryW |
| sourcekit-lsp | `Sources/SwiftLanguageService/SwiftLanguageService.swift` | 36 `WinSDK` | Windows | no C name it serves was found on its platforms |
| sourcekit-lsp | `Sources/SwiftSourceKitPlugin/SKDRequestDictionaryReader.swift` | 17 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/SwiftSourceKitPlugin/SKDResponse.swift` | 17 `CRT` | Windows | System covers every C name it serves there: free |
| sourcekit-lsp | `Sources/TSCExtensions/Process+Run.swift` | 25 `WinSDK` | Windows | System covers every C name it serves there: BELOW_NORMAL_PRIORITY_CLASS, CloseHandle, GetLastError, IDLE_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS, OpenProcess, PROCESS_SET_INFORMATION, SIGABRT… |
| sourcekit-lsp | `Tests/BuildServerIntegrationTests/ExternalBuildServerTests.swift` | 27 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| sourcekit-lsp | `Tests/SourceKitLSPTests/PullDiagnosticsTests.swift` | 26 `WinSDK`, 28 `Android` | Android, Windows | no C name it serves was found on its platforms |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Mutex.swift` | 15 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 22 `CRT` | Windows | System covers every C name it serves there: CONSOLE_SCREEN_BUFFER_INFO, ERROR_BAD_ARGUMENTS, EXIT_FAILURE, EXIT_SUCCESS, GetConsoleScreenBufferInfo, GetStdHandle, STD_OUTPUT_HANDLE, _exit |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 127 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetStdHandle |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 128 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetConsoleScreenBufferInfo |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 129 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ERROR_BAD_ARGUMENTS |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 130 `WinSDK` (scoped) | Windows | System covers every C name it serves there: STD_OUTPUT_HANDLE |
| swift-argument-parser | `Sources/ArgumentParser/Utilities/Platform.swift` | 131 `WinSDK` (scoped) | Windows | System covers every C name it serves there: CONSOLE_SCREEN_BUFFER_INFO |
| swift-async-algorithms | `Sources/AsyncAlgorithms/Locking.swift` | 20 `Glibc`, 1 marker, 22 `Musl`, 26 `Bionic` | Linux, Musl, Android, FreeBSD, OpenBSD | System covers every C name it serves there: pthread_mutex_destroy, pthread_mutex_init, pthread_mutex_lock, pthread_mutex_t, pthread_mutex_unlock |
| swift-async-algorithms | `Sources/AsyncAlgorithms/Locking.swift` | 24 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-build | `Sources/MockToolchainCASPlugin/MockCASFileLock.swift` | 17 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, CreateFileW, DWORD, FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ, FILE_SHARE_WRITE, GENERIC_READ, GENERIC_WRITE… |
| swift-build | `Sources/SWBLibc/libc.swift` | 14 `ucrt`, re-exported, 15 `CRT`, re-exported, 16 `WinSDK`, re-exported | Windows | no C name it serves was found on its platforms |
| swift-build | `Sources/SWBTestSupport/Misc.swift` | 23 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-build | `Sources/SWBUtil/FSProxy.swift` | 38 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-build | `Sources/SWBUtil/HashContext.swift` | 14 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-certificates | `Sources/X509/Lock.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-crypto | `Sources/Crypto/Util/SecureBytes.swift` | 316 marker: string.h memset_s, on Windows: Memory.secureZero(_:). It's Darwin's on… | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: memset_s |
| swift-crypto | `Sources/Crypto/Util/Zeroization.swift` | 29 marker: string.h memset_s, on Windows: Memory.secureZero(_:). It's Darwin's on…, 38 marker: string.h memset_s, as above, 47 marker: string.h memset_s, as above, 56 marker: string.h memset_s, as above | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: memset_s |
| swift-crypto | `Sources/CryptoBoringWrapper/AEAD/BoringSSLAEAD.swift` | 161 marker: stdlib.h malloc and free, on Windows: Memory.allocate(byteCount:) and …, 276 marker: stdlib.h malloc and free, as above, 370 marker: stdlib.h malloc and free, as above | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: free, malloc |
| swift-crypto | `Sources/_CryptoExtras/Key Derivation/Scrypt/BoringSSL/Scrypt_boring.swift` | 28 `WinSDK` | Windows | System covers every C name it serves there: GetSystemInfo, SYSTEM_INFO |
| swift-crypto | `Sources/_CryptoExtras/RSA/RSA_boring.swift` | 966 marker: string.h memcmp, on Windows: Memory.compare(_:_:) | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: memcmp |
| swift-docc | `Sources/SwiftDocC/Benchmark/Metrics/PeakMemory.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: DWORD, GetCurrentProcess |
| swift-docc | `Sources/SwiftDocC/Utility/Synchronization.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-docc | `Tests/DocCCommandLineTests/C+Extensions.swift` | 13 `ucrt` | Windows | System covers every C name it serves there: _wputenv_s |
| swift-docc | `Tests/SwiftDocCTests/Utility/SynchronizationTests.swift` | 14 `WinSDK` (scoped) | Windows | System covers every C name it serves there: TryAcquireSRWLockExclusive |
| swift-driver | `Sources/SwiftDriver/Driver/ToolExecutionDelegate.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/SwiftDriver/SwiftScan/Loader.swift` | 19 `WinSDK` | Windows | System covers every C name it serves there: FreeLibrary, GetLastError, GetModuleHandleW, GetProcAddress, HMODULE, LoadLibraryW |
| swift-driver | `Sources/SwiftDriver/SwiftScan/SwiftScan.swift` | 18 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/SwiftDriver/Utilities/DateAdditions.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetSystemTimePreciseAsFileTime |
| swift-driver | `Sources/SwiftDriver/Utilities/PythonArchitecture.swift` | 28 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Sources/swift-build-sdk-interfaces/main.swift` | 18 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/Helpers/DriverTestHelpers.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/MiscDriverTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/SpecialModeTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/TargetTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-driver | `Tests/SwiftDriverTests/ToolchainTests.swift` | 24 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-format | `Sources/SwiftFormat/Utilities/URL+isRoot.swift` | 17 `WinSDK`, 1 marker | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Reading.swift` | 29 `Musl` | Musl | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Reading.swift` | 472 marker: MemoryMapping, byteCount, file, fileSize on WASI | WASI? | the marker names no C interface |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 29 `Android`, 1 marker, 30 `unistd`, 1 marker, 41 `WASILibc`, 1 marker | Android, WASI | System covers every C name it serves there: dirfd |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 33 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: EXTATTR_NAMESPACE_USER, dirfd, extattr_set_fd, mktemp |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 35 `Musl` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 294 marker: FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD; … | FreeBSD?, OpenBSD?, Windows? | the marker names no C interface (FilePath.makeUniqueFile(options:permissions:) on FreeBSD and OpenBSD) |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 850 marker: FileDescriptor.setExtendedAttribute on FreeBSD (extattr_*) | FreeBSD? | System covers every C name it serves there: extattr_* |
| swift-foundation | `Sources/FoundationEssentials/Data/Data+Writing.swift` | 853 marker: extended attributes on OpenBSD, which has none | OpenBSD? | the marker names no C interface (extended attributes on OpenBSD) |
| swift-foundation | `Sources/FoundationEssentials/Data/Data.swift` | 69 `string_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Data.swift` | 84 marker: MemoryMapping, byteCount, unmap on WASI | WASI | the marker names no C interface |
| swift-foundation | `Sources/FoundationEssentials/Data/DataProtocol.swift` | 18 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Data/DataProtocol.swift` | 22 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` | 23 `Musl`, 25 `ucrt`, 27 `WASILibc`, 31 `Bionic` | Musl, Android, WASI, Windows | System covers every C name it serves there: realloc |
| swift-foundation | `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` | 35 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Data/Representations/DataStorage.swift` | 94 marker: Memory.reallocate on Windows, which shares this arm | Musl, Android, WASI, Windows | the marker names no C interface (Memory.reallocate on Windows) |
| swift-foundation | `Sources/FoundationEssentials/Date.swift` | 21 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetSystemTimePreciseAsFileTime |
| swift-foundation | `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift` | 23 `Glibc`, 1 marker, 29 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift` | 25 `CRT`, 26 `WinSDK` | Windows | System covers every C name it serves there: DWORD |
| swift-foundation | `Sources/FoundationEssentials/Error/CocoaError+FilePath.swift` | 104 marker: POSIXError's API from an Errno off Darwin, Linux and Android: each pla… | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (POSIXError's API from an Errno off Darwin) |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` | 27 `Glibc`, 1 marker, 33 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | System covers every C name it serves there: POSIXErrorCode |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` | 77 marker: CInterop.POSIXErrorCode on Windows; and POSIXError's API off Darwin, L… | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (CInterop.POSIXErrorCode on Windows) |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` | 87 marker: POSIXError's API off Darwin, Linux and Android: each platform's errno … | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (POSIXError's API off Darwin) |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` | 558 marker: POSIXError's static properties off Darwin, Linux and Android: each pla… | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (POSIXError's static properties off Darwin) |
| swift-foundation | `Sources/FoundationEssentials/Error/ErrorCodes+Win32.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: DWORD |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift` | 20 `Glibc`, 1 marker, 26 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` | 24 `Android`, 30 `Musl`, 37 `WASILibc` | Musl, Android, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` | 498 marker: FilePath.extendedAttribute on FreeBSD (extattr_*), 548 marker: FilePath.extendedAttributeNames on FreeBSD (extattr_*) | FreeBSD | System covers every C name it serves there: extattr_* |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` | 752 marker: StatFS.FileSystemID as a number on every platform: on FreeBSD and Open… | FreeBSD, OpenBSD | the marker names no C interface (StatFS.FileSystemID as a number on every platform) |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift` | 19 `Glibc`, 1 marker, 26 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+SymbolicLinks.swift` | 21 `CRT`, 22 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, CreateFileW, CreateSymbolicLinkW, DWORD, DeviceIoControl, FSCTL_GET_REPARSE_POINT, GetFileAttributesExW, GetLastError… |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 30 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: EXTATTR_NAMESPACE_USER, extattr_set_file, extattr_set_link |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 33 `CRT`, 34 `WinSDK` | Windows | System covers every C name it serves there: FILETIME |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 37 `WASILibc`, 1 marker | WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/FileManager/FileManager+Utilities.swift` | 198 marker: FilePath.setExtendedAttribute on FreeBSD (extattr_*) | FreeBSD | System covers every C name it serves there: extattr_* |
| swift-foundation | `Sources/FoundationEssentials/Platform.swift` | 67 `stdlib_h`, 68 `unistd`, 72 `stdlib_h` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/Platform.swift` | 232 marker: ProcessEnvironment.secureValue, secureValue on WASI | WASI? | the marker names no C interface |
| swift-foundation | `Sources/FoundationEssentials/Platform.swift` | 254 marker: CString.copy on Windows (string_h's platforms), as strlcpy, which retu… | Android | the marker names no C interface (CString.copy on Windows (string_h's platforms)) |
| swift-foundation | `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` | 432 marker: SystemIdentity, SystemIdentity.current, release, version on WASI | WASI? | the marker names no C interface |
| swift-foundation | `Sources/FoundationEssentials/String/String+Path.swift` | 23 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/String/String+Path.swift` | 28 `WASILibc`, 1 marker | WASI | System covers every C name it serves there: MAXSYMLINKS |
| swift-foundation | `Sources/FoundationEssentials/String/String+Path.swift` | 668 marker: SystemConfig.maxSymbolicLinks, maxSymbolicLinks on WASI | WASI? | the marker names no C interface |
| swift-foundation | `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift` | 16 `unistd` | Android | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/UUID.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetSystemTimePreciseAsFileTime |
| swift-foundation | `Sources/FoundationEssentials/WASILibc+Extensions.swift` | 14 `WASILibc` | WASI | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 17 `WinSDK` | Windows | System covers every C name it serves there: DWORD, FlsAlloc, FlsGetValue, FlsSetValue |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 20 `threads_h`, 1 marker | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Sources/FoundationEssentials/_ThreadLocal.swift` | 57 marker: PThread.Key on WASI without threads (coverage-5 N2); Windows shares th… | WASI, Windows | the marker names no C interface (PThread.Key on WASI without threads (coverage-5 N2)) |
| swift-foundation | `Sources/FoundationInternationalization/Formatting/Date/ICUDateFormatter.swift` | 24 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Sources/FoundationInternationalization/TimeZone/TimeZone_ICU.swift` | 18 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/DataTests.swift` | 24 `Glibc`, 1 marker, 26 `ucrt` | FreeBSD, OpenBSD, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/DecimalTests.swift` | 19 `Glibc`, 1 marker, 22 `WASILibc`, 1 marker, 24 `CRT` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift` | 22 `Android`, 33 `Bionic`, 35 `Glibc`, 37 `CRT`, 38 `WinSDK` | Android, FreeBSD, OpenBSD, Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift` | 206 marker: UserID.real, real on WASI | WASI | the marker names no C interface |
| swift-foundation | `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` | 19 `Bionic`, 21 `Glibc` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-foundation | `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` | 26 `WASILibc`, 1 marker | WASI | System covers every C name it serves there: LC_ALL, setlocale |
| swift-foundation | `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` | 1514 marker: CLocale, CLocale.globalName, CLocale.setGlobal, globalName on Windows … | WASI, Windows | the marker names no C interface |
| swift-foundation | `Tests/FoundationEssentialsTests/ProcessInfoTests.swift` | 27 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationEssentialsTests/ProcessInfoTests.swift` | 31 `CRT` | Windows | System covers every C name it serves there: _putenv |
| swift-foundation | `Tests/FoundationEssentialsTests/ProcessInfoTests.swift` | 33 marker: the C library, for this file's C arms | WASI | the marker names no C interface (C library) |
| swift-foundation | `Tests/FoundationEssentialsTests/StringTests.swift` | 20 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-foundation | `Tests/FoundationInternationalizationTests/DateComponentsTests.swift` | 30 `Glibc`, 1 marker, 33 `WASILibc`, 1 marker, 35 `CRT` | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-log | `Sources/Logging/Handlers/StreamLogHandler.swift` | 18 `CRT` | Windows | System covers every C name it serves there: __time64_t, _localtime64_s, _lock_file, _time64, _unlock_file, fflush, fwrite, stdout… |
| swift-log | `Sources/Logging/Locks.swift` | 30 `ucrt`, 31 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, AcquireSRWLockShared, InitializeSRWLock, ReleaseSRWLockExclusive, ReleaseSRWLockShared, SRWLOCK |
| swift-log | `Sources/Logging/MetadataProvider.swift` | 17 `CRT` | Windows | no C name it serves was found on its platforms |
| swift-log | `Tests/LoggingTests/MetadataProviderTest.swift` | 21 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-log | `Tests/LoggingTests/StreamLogHandlerTest.swift` | 23 `WinSDK` | Windows | System covers every C name it serves there: DWORD, HANDLE, PIPE_NOWAIT, SetNamedPipeHandleState, _IOFBF, _fdopen, _get_osfhandle, _lock_file… |
| swift-log | `Tests/LoggingTests/TestLogger.swift` | 24 `WinSDK` | Windows | System covers every C name it serves there: GetCurrentThreadId |
| swift-nio | `Sources/NIOConcurrencyHelpers/NIOLock.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | System covers every C name it serves there: AcquireSRWLockExclusive, InitializeSRWLock, ReleaseSRWLockExclusive, SRWLOCK |
| swift-nio | `Sources/NIOConcurrencyHelpers/NIOThreadPoolWorkAvailable.swift` | 16 `ucrt`, 17 `WinSDK` | Windows | System covers every C name it serves there: CONDITION_VARIABLE, GetLastError, INFINITE, InitializeConditionVariable, SleepConditionVariableSRW, WakeAllConditionVariable, WakeConditionVariable |
| swift-nio | `Sources/NIOConcurrencyHelpers/atomics.swift` | 23 `ucrt`, 24 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Sources/NIOConcurrencyHelpers/atomics.swift` | 29 marker: PThread.yield on WASI without threads (coverage-5 N2) | FreeBSD, OpenBSD, WASI | the marker names no C interface (PThread.yield on WASI without threads (coverage-5 N2)) |
| swift-nio | `Sources/NIOConcurrencyHelpers/atomics.swift` | 31 `Glibc` | FreeBSD, OpenBSD | System covers every C name it serves there: sched_yield |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 62 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetLastError |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 71 `Musl` | Musl | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 79 `Glibc`, 1 marker | FreeBSD | System covers every C name it serves there: IPPROTO_IP, IPPROTO_IPV6, IPPROTO_TCP, IPPROTO_UDP, IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS, IPV6_MULTICAST_IF… |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 226 marker: SystemSockets on FreeBSD and Windows, 256 marker: SystemSockets on FreeBSD and Windows, 267 marker: SystemSockets on FreeBSD and Windows, 279 marker: SystemSockets on FreeBSD and Windows, 315 marker: SystemSockets on FreeBSD and Windows, 381 marker: SystemSockets on FreeBSD and Windows, 418 marker: SystemSockets on FreeBSD and Windows, 429 marker: SystemSockets on FreeBSD and Windows, 440 marker: SystemSockets on FreeBSD and Windows, 451 marker: SystemSockets on FreeBSD and Windows, 462 marker: SystemSockets on FreeBSD and Windows, 476 marker: SystemSockets on FreeBSD and Windows, 490 marker: SystemSockets on FreeBSD and Windows, 501 marker: SystemSockets on FreeBSD and Windows, 512 marker: SystemSockets on FreeBSD and Windows, 523 marker: SystemSockets on FreeBSD and Windows, 534 marker: SystemSockets on FreeBSD and Windows, 546 marker: SystemSockets on FreeBSD and Windows, 560 marker: SystemSockets on FreeBSD and Windows, 630 marker: SystemSockets on FreeBSD and Windows, 641 marker: SystemSockets on FreeBSD and Windows, 652 marker: SystemSockets on FreeBSD and Windows, 663 marker: SystemSockets on FreeBSD and Windows, 674 marker: SystemSockets on FreeBSD and Windows, 685 marker: SystemSockets on FreeBSD and Windows, 696 marker: SystemSockets on FreeBSD and Windows, 707 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 294 marker: SystemSockets on FreeBSD, 338 marker: SystemSockets on FreeBSD, 361 marker: SystemSockets on FreeBSD, 403 marker: SystemSockets on FreeBSD, 722 marker: SystemSockets on FreeBSD, 780 marker: SystemSockets on FreeBSD, 831 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 574 marker: SystemSockets on FreeBSD (TCP_INFO) | FreeBSD | System covers every C name it serves there: TCP_INFO |
| swift-nio | `Sources/NIOCore/BSDSocketAPI.swift` | 739 marker: SocketDescriptor.SocketOption.reusePort on Android and OpenBSD, and Sy… | Android, FreeBSD, OpenBSD | the marker names no C interface (SocketDescriptor.SocketOption.reusePort on Android and OpenBSD) |
| swift-nio | `Sources/NIOCore/ByteBuffer-core.swift` | 16 `ucrt`, 23 `Glibc`, 1 marker, 27 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/FileHandle.swift` | 18 `ucrt` | Windows | System covers every C name it serves there: O_RDONLY, O_RDWR, O_WRONLY, _O_NOINHERIT, _S_IREAD, _S_IWRITE |
| swift-nio | `Sources/NIOCore/FileRegion.swift` | 15 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/GlobalSingletons.swift` | 20 `ucrt`, 21 `WinSDK`, 24 `Glibc`, 1 marker, 28 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI, Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/IO.swift` | 17 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FormatMessageW |
| swift-nio | `Sources/NIOCore/IO.swift` | 18 `WinSDK` (scoped) | Windows | System covers every C name it serves there: LocalFree |
| swift-nio | `Sources/NIOCore/IO.swift` | 19 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FORMAT_MESSAGE_ALLOCATE_BUFFER |
| swift-nio | `Sources/NIOCore/IO.swift` | 20 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FORMAT_MESSAGE_FROM_SYSTEM |
| swift-nio | `Sources/NIOCore/IO.swift` | 21 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FORMAT_MESSAGE_IGNORE_INSERTS |
| swift-nio | `Sources/NIOCore/IO.swift` | 22 `WinSDK` (scoped) | Windows | System covers every C name it serves there: LANG_NEUTRAL |
| swift-nio | `Sources/NIOCore/IO.swift` | 23 `WinSDK` (scoped) | Windows | System covers every C name it serves there: SUBLANG_DEFAULT |
| swift-nio | `Sources/NIOCore/IO.swift` | 24 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOCore/IO.swift` | 26 `WinSDK` (scoped) | Windows | System covers every C name it serves there: WORD |
| swift-nio | `Sources/NIOCore/IO.swift` | 35 `Glibc`, 1 marker, 39 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 23 `Glibc`, 1 marker, 32 `WASILibc`, 1 marker | FreeBSD, WASI | System covers every C name it serves there: sa_family |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 28 marker: the C library, for this file's C arms | OpenBSD | the marker names no C interface (C library) |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 41 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_ADDRESSES |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 42 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_UNICAST_ADDRESS |
| swift-nio | `Sources/NIOCore/Interfaces.swift` | 211 marker: SystemSockets on FreeBSD, OpenBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOCore/SocketAddresses.swift` | 78 `WASILibc`, 1 marker | WASI | System covers every C name it serves there: s_addr, sin6_addr, sin6_family, sin6_flowinfo, sin6_port, sin6_scope_id, sin_addr, sin_family… |
| swift-nio | `Sources/NIOCore/SocketAddresses.swift` | 139 marker: SystemSockets on FreeBSD and Windows, 160 marker: SystemSockets on FreeBSD and Windows, 181 marker: SystemSockets on FreeBSD and Windows, 213 marker: SystemSockets on FreeBSD and Windows, 226 marker: SystemSockets on FreeBSD and Windows, 270 marker: SystemSockets on FreeBSD and Windows, 279 marker: SystemSockets on FreeBSD and Windows, 302 marker: SystemSockets on FreeBSD and Windows, 321 marker: SystemSockets on FreeBSD and Windows, 330 marker: SystemSockets on FreeBSD and Windows, 356 marker: SystemSockets on FreeBSD and Windows, 377 marker: SystemSockets on FreeBSD and Windows, 404 marker: SystemSockets on FreeBSD and Windows, 420 marker: SystemSockets on FreeBSD and Windows, 435 marker: SystemSockets on FreeBSD and Windows, 450 marker: SystemSockets on FreeBSD and Windows, 465 marker: SystemSockets on FreeBSD and Windows, 491 marker: SystemSockets on FreeBSD and Windows, 530 marker: SystemSockets on FreeBSD and Windows, 567 marker: SystemSockets on FreeBSD and Windows, 665 marker: SystemSockets on FreeBSD and Windows, 701 marker: SystemSockets on FreeBSD and Windows, 734 marker: SystemSockets on FreeBSD and Windows, 894 marker: SystemSockets on FreeBSD and Windows, 1012 marker: SystemSockets on FreeBSD and Windows, 1059 marker: SystemSockets on FreeBSD and Windows, 1104 marker: SystemSockets on FreeBSD and Windows, 1126 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOCore/SocketAddresses.swift` | 611 marker: SystemSockets on FreeBSD, 632 marker: SystemSockets on FreeBSD, 819 marker: SystemSockets on FreeBSD, 872 marker: SystemSockets on FreeBSD, 996 marker: SystemSockets on FreeBSD, 1046 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOCore/SocketAddresses.swift` | 923 marker: address, family on Windows (Windows later), 969 marker: address, bytes, family on Windows (Windows later) | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface |
| swift-nio | `Sources/NIOCore/SocketOptionProvider.swift` | 19 `Musl`, 21 `Bionic` | Musl, Android | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/SocketOptionProvider.swift` | 30 `Glibc`, 1 marker, 34 `Glibc`, 1 marker, 40 `WASILibc`, 1 marker | FreeBSD, OpenBSD, WASI | System covers every C name it serves there: linger |
| swift-nio | `Sources/NIOCore/SocketOptionProvider.swift` | 192 marker: SystemSockets on FreeBSD and Windows, 221 marker: SystemSockets on FreeBSD and Windows, 246 marker: SystemSockets on FreeBSD and Windows, 261 marker: SystemSockets on FreeBSD and Windows, 412 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOCore/SystemCallHelpers.swift` | 31 marker: NetworkInterface on Windows, 238 marker: NetworkInterface on Windows | Windows | the marker names no C interface |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 21 `Glibc`, 27 `Glibc`, 51 `WASILibc` | FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 32 `WinSDK` (scoped) | Windows | System covers every C name it serves there: RelationProcessorCore |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 35 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ERROR_BUFFER_OVERFLOW |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 36 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ERROR_SUCCESS |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 38 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetAdaptersAddresses |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 39 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetLastError |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 40 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetLogicalProcessorInformation |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 42 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_ADDRESSES |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 43 `WinSDK` (scoped) | Windows | System covers every C name it serves there: IP_ADAPTER_UNICAST_ADDRESS |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 44 `WinSDK` (scoped) | Windows | System covers every C name it serves there: SYSTEM_LOGICAL_PROCESSOR_INFORMATION |
| swift-nio | `Sources/NIOCore/Utilities.swift` | 47 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOEmbedded/Embedded.swift` | 26 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/FileInfo.swift` | 20 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: st_atim, st_ctim, st_mtim |
| swift-nio | `Sources/NIOFS/Internal/System Calls/FileDescriptor+Syscalls.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/System Calls/Mocking.swift` | 26 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/System Calls/Syscall.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOFS/Internal/SystemFileHandle.swift` | 26 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOHTTP1Server/main.swift` | 21 `WinSDK` | Windows | System covers every C name it serves there: STD_INPUT_HANDLE, STD_OUTPUT_HANDLE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPICommon.swift` | 84 marker: SystemSockets on FreeBSD and Windows, 95 marker: SystemSockets on FreeBSD and Windows, 104 marker: SystemSockets on FreeBSD and Windows, 123 marker: SystemSockets on FreeBSD and Windows, 151 marker: SystemSockets on FreeBSD and Windows, 263 marker: SystemSockets on FreeBSD and Windows, 315 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIPosix.swift` | 96 marker: SystemSockets on FreeBSD, 171 marker: SystemSockets on FreeBSD, 360 marker: SystemSockets on FreeBSD, 376 marker: SystemSockets on FreeBSD, 441 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 31 `WinSDK` (scoped) | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 88 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetLastError |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 89 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ReadFile |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 91 `WinSDK` (scoped) | Windows | System covers every C name it serves there: WriteFile |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 100 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 101 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-nio | `Sources/NIOPosix/BSDSocketAPIWindows.swift` | 104 `WinSDK` (scoped) | Windows | System covers every C name it serves there: OVERLAPPED |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 34 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EAFNOSUPPORT |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 35 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EBADF |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 69 marker: family on Windows (Windows later), 84 marker: family on Windows (Windows later), 112 marker: family on Windows (Windows later), 138 marker: family on Windows (Windows later) | FreeBSD, OpenBSD, Windows | the marker names no C interface (family on Windows (Windows later)) |
| swift-nio | `Sources/NIOPosix/BaseSocket.swift` | 99 marker: SystemSockets on FreeBSD and Windows, 247 marker: SystemSockets on FreeBSD and Windows, 349 marker: SystemSockets on FreeBSD and Windows, 379 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 26 `ucrt` | Windows | System covers every C name it serves there: FILE_TYPE_PIPE, GetFileType, HANDLE, INVALID_HANDLE_VALUE, _get_osfhandle |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 28 `WinSDK` (scoped) | Windows | System covers every C name it serves there: GetFileType |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 30 `WinSDK` (scoped) | Windows | System covers every C name it serves there: FILE_TYPE_PIPE |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 31 `WinSDK` (scoped) | Windows | System covers every C name it serves there: INVALID_HANDLE_VALUE |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 33 `WinSDK` (scoped) | Windows | System covers every C name it serves there: DWORD |
| swift-nio | `Sources/NIOPosix/Bootstrap.swift` | 34 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| swift-nio | `Sources/NIOPosix/ControlMessage.swift` | 25 marker: SystemSockets on FreeBSD, 42 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOPosix/ControlMessage.swift` | 30 `Glibc`, 1 marker | OpenBSD | System covers every C name it serves there: IPPROTO_IP, IPPROTO_IPV6, IPV6_TCLASS, IP_TOS, cmsg_len, cmsg_level, cmsg_type, ipi6_addr… |
| swift-nio | `Sources/NIOPosix/ControlMessage.swift` | 203 marker: SystemSockets on FreeBSD and Windows, 242 marker: SystemSockets on FreeBSD and Windows, 290 marker: SystemSockets on FreeBSD and Windows, 310 marker: SystemSockets on FreeBSD and Windows, 335 marker: SystemSockets on FreeBSD and Windows, 437 marker: SystemSockets on FreeBSD and Windows, 478 marker: SystemSockets on FreeBSD and Windows, 490 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/DatagramVectorReadManager.swift` | 159 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/DatagramVectorReadManager.swift` | 230 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOPosix/GetaddrinfoResolver.swift` | 202 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOPosix/NonBlockingFileIO.swift` | 1358 marker: Stat on Windows (Windows later) | WASI, Windows | the marker names no C interface (Stat on Windows (Windows later)) |
| swift-nio | `Sources/NIOPosix/PendingDatagramWritesManager.swift` | 188 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/Socket.swift` | 213 marker: SystemSockets on FreeBSD and Windows, 232 marker: SystemSockets on FreeBSD and Windows, 281 marker: SystemSockets on FreeBSD and Windows, 300 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 40 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ECONNABORTED |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 41 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ECONNREFUSED |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 42 `WinSDK` (scoped) | Windows | System covers every C name it serves there: EMFILE |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 43 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENFILE |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 44 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENOBUFS |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 45 `WinSDK` (scoped) | Windows | System covers every C name it serves there: ENOMEM |
| swift-nio | `Sources/NIOPosix/SocketChannel.swift` | 1294 marker: SystemSockets on FreeBSD and Windows, 1310 marker: SystemSockets on FreeBSD and Windows, 1333 marker: SystemSockets on FreeBSD and Windows, 1353 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/NIOPosix/System.swift` | 70 marker: the C library's type and errno names that NIOPosix's clients reach thr… | Linux, Musl, Android, FreeBSD | the marker names no C interface (C library's type and errno names that NIOPosix's clients reach through this public) |
| swift-nio | `Sources/NIOPosix/System.swift` | 77 `Musl`, re-exported, 79 `Android`, re-exported | Musl, Android | no C name it serves was found on its platforms |
| swift-nio | `Sources/NIOPosix/System.swift` | 110 `Glibc`, re-exported | OpenBSD | System covers every C name it serves there: EAGAIN, EINPROGRESS, IPPROTO_UDP, SHUT_RD, SHUT_RDWR, SHUT_WR, UIO_MAXIOV, kevent |
| swift-nio | `Sources/NIOPosix/System.swift` | 133 marker: SystemSockets on FreeBSD, 151 marker: SystemSockets on FreeBSD, 528 marker: SystemSockets on FreeBSD, 552 marker: SystemSockets on FreeBSD, 567 marker: SystemSockets on FreeBSD, 604 marker: SystemSockets on FreeBSD, 636 marker: SystemSockets on FreeBSD, 681 marker: SystemSockets on FreeBSD, 717 marker: SystemSockets on FreeBSD, 753 marker: SystemSockets on FreeBSD, 781 marker: SystemSockets on FreeBSD, 868 marker: SystemSockets on FreeBSD, 889 marker: SystemSockets on FreeBSD, 960 marker: SystemSockets on FreeBSD, 1037 marker: SystemSockets on FreeBSD, 1063 marker: SystemSockets on FreeBSD, 1218 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Sources/NIOPosix/System.swift` | 164 marker: NetworkInterface on Windows, 1080 marker: NetworkInterface on Windows | Windows | the marker names no C interface |
| swift-nio | `Sources/NIOPosix/System.swift` | 459 marker: SystemConfig.maxIOVectors on FreeBSD and OpenBSD; SocketDescriptor.Shu… | FreeBSD, OpenBSD | the marker names no C interface (SystemConfig.maxIOVectors on FreeBSD and OpenBSD) |
| swift-nio | `Sources/NIOPosix/System.swift` | 535 marker: SystemSockets on OpenBSD: it uses C constants that OpenBSD lacks (IP_P… | OpenBSD | the marker names no C interface (SystemSockets on OpenBSD) |
| swift-nio | `Sources/NIOPosix/Thread.swift` | 29 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, GetCurrentThread, GetCurrentThreadId |
| swift-nio | `Sources/NIOPosix/Thread.swift` | 251 marker: PThread.Key on Windows, 312 marker: PThread.Key on Windows, 332 marker: PThread.Key on Windows | Windows | the marker names no C interface (PThread.Key on Windows) |
| swift-nio | `Sources/NIOPosix/VsockAddress.swift` | 225 marker: SystemSockets on FreeBSD and Windows, 237 marker: SystemSockets on FreeBSD and Windows, 248 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Sources/_NIOFileSystem/FileInfo.swift` | 20 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: st_atim, st_ctim, st_mtim |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/FileDescriptor+Syscalls.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/Mocking.swift` | 26 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/System Calls/Syscall.swift` | 22 `Glibc` | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Sources/_NIOFileSystem/Internal/SystemFileHandle.swift` | 26 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift` | 31 `Glibc`, 1 marker | FreeBSD, OpenBSD | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOConcurrencyHelpersTests/NIOConcurrencyHelpersTests.swift` | 33 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOCoreTests/XCTest+Extensions.swift` | 29 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOEmbeddedTests/TestUtils.swift` | 31 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-nio | `Tests/NIOFSTests/FileInfoTests.swift` | 28 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: S_IFREG, st_atim, st_blksize, st_blocks, st_ctim, st_dev, st_gid, st_ino… |
| swift-nio | `Tests/NIOFSTests/FileInfoTests.swift` | 30 `Android` | Android | System covers every C name it serves there: st_atim, st_blksize, st_blocks, st_ctim, st_dev, st_gid, st_ino, st_mode… |
| swift-nio | `Tests/NIOHTTP1Tests/TestUtils.swift` | 59 `WinSDK`, 60 `ucrt` | Windows | System covers every C name it serves there: CreateDirectoryW, Sleep, _O_BINARY, _O_RDWR, _SH_DENYNO, _S_IREAD, _S_IWRITE, _sopen_s |
| swift-nio | `Tests/NIOPosixTests/AsyncChannelBootstrapTests.swift` | 23 `ucrt` | Windows | System covers every C name it serves there: _O_BINARY |
| swift-nio | `Tests/NIOPosixTests/ChannelPipelineTest.swift` | 251 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/ControlMessageTests.swift` | 34 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/HappyEyeballsTest.swift` | 29 `Glibc`, 1 marker | FreeBSD, OpenBSD | System covers every C name it serves there: sin6_addr, sin6_family, sin6_flowinfo, sin6_port, sin6_scope_id, sin_addr, sin_family, sin_port |
| swift-nio | `Tests/NIOPosixTests/HappyEyeballsTest.swift` | 154 marker: SystemSockets on FreeBSD and Windows, 175 marker: SystemSockets on FreeBSD and Windows, 200 marker: SystemSockets on FreeBSD and Windows, 213 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/MulticastTest.swift` | 160 marker: SystemSockets on FreeBSD, 182 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/NIOFileHandleTest.swift` | 22 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/NIOTransportAccessibleChannelCoreTests.swift` | 21 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift` | 49 marker: family on Windows (Windows later) | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (family on Windows (Windows later)) |
| swift-nio | `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift` | 191 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/SocketAddressTest.swift` | 73 marker: SystemSockets on FreeBSD and Windows, 89 marker: SystemSockets on FreeBSD and Windows, 149 marker: SystemSockets on FreeBSD and Windows, 194 marker: SystemSockets on FreeBSD and Windows, 205 marker: SystemSockets on FreeBSD and Windows, 239 marker: SystemSockets on FreeBSD and Windows, 378 marker: SystemSockets on FreeBSD and Windows, 603 marker: SystemSockets on FreeBSD and Windows, 643 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/SocketAddressTest.swift` | 281 marker: SystemSockets on FreeBSD, 317 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/SocketAddressTest.swift` | 449 marker: family, unspecified on Windows (Windows later) | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface |
| swift-nio | `Tests/NIOPosixTests/SocketChannelTest.swift` | 63 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/SocketOptionProviderTest.swift` | 159 marker: SystemSockets on FreeBSD and Windows, 182 marker: SystemSockets on FreeBSD and Windows, 247 marker: SystemSockets on FreeBSD and Windows, 260 marker: SystemSockets on FreeBSD and Windows | FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (SystemSockets on FreeBSD and Windows) |
| swift-nio | `Tests/NIOPosixTests/SocketOptionProviderTest.swift` | 281 marker: SystemSockets on FreeBSD, 289 marker: SystemSockets on FreeBSD, 304 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/StrictCrashTests.swift` | 24 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/SyscallAbstractionLayer.swift` | 515 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/SystemCallWrapperHelpers.swift` | 116 marker: the test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin rou… | FreeBSD, OpenBSD, WASI | the marker names no C interface (test's own C-shaped helpers on FreeBSD and OpenBSD (the Darwin round's design call 19)) |
| swift-nio | `Tests/NIOPosixTests/SystemCrashTests.swift` | 30 `ucrt` | Windows | no C name it serves was found on its platforms |
| swift-nio | `Tests/NIOPosixTests/SystemTest.swift` | 57 marker: SystemSockets on FreeBSD | FreeBSD, OpenBSD, WASI | the marker names no C interface (SystemSockets on FreeBSD) |
| swift-nio | `Tests/NIOPosixTests/TestUtils.swift` | 56 `WinSDK`, 57 `ucrt` | Windows | System covers every C name it serves there: CreateDirectoryW, Sleep, _O_BINARY, _O_RDWR, _SH_DENYNO, _S_IREAD, _S_IWRITE, _sopen_s |
| swift-nio | `Tests/NIOTestUtilsTests/NIOHTTP1TestServerTest.swift` | 32 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-sdk-generator | `Tests/AsyncProcessTests/IntegrationTests.swift` | 79 `Android` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-subprocess | `Sources/Subprocess/Configuration.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, CreateFileW, CreateNamedPipeW, DUPLICATE_SAME_ACCESS, DuplicateHandle, ERROR_ACCESS_DENIED, ERROR_INVALID_HANDLE, FILE_ATTRIBUTE_NORMAL… |
| swift-subprocess | `Sources/Subprocess/Error.swift` | 14 `WinSDK` | Windows | System covers every C name it serves there: HRESULT, NTSTATUS, errno_t |
| swift-subprocess | `Sources/Subprocess/Execution.swift` | 16 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-subprocess | `Sources/Subprocess/IO/AsyncIO+Windows.swift` | 20 `WinSDK` | Windows | System covers every C name it serves there: CancelIoEx, CloseHandle, CreateEventW, CreateIoCompletionPort, ERROR_BROKEN_PIPE, ERROR_IO_INCOMPLETE, ERROR_IO_PENDING, ERROR_NOT_FOUND… |
| swift-subprocess | `Sources/Subprocess/IO/Input.swift` | 15 `WinSDK` | Windows | System covers every C name it serves there: HANDLE, _get_osfhandle |
| swift-subprocess | `Sources/Subprocess/IO/Output.swift` | 15 `WinSDK` | Windows | System covers every C name it serves there: HANDLE, _get_osfhandle |
| swift-subprocess | `Sources/Subprocess/SubprocessOutputSequence.swift` | 612 `WinSDK` | Windows | System covers every C name it serves there: GetSystemInfo, HANDLE, SYSTEM_INFO |
| swift-subprocess | `Sources/Subprocess/Teardown.swift` | 17 `WinSDK` | Windows | System covers every C name it serves there: AttachConsole, CTRL_BREAK_EVENT, CTRL_C_EVENT, FreeConsole, GenerateConsoleCtrlEvent, SetConsoleCtrlHandler, WAIT_TIMEOUT, WaitForSingleObject |
| swift-subprocess | `Tests/SubprocessTests/AsyncIOTests.swift` | 16 `WinSDK` | Windows | System covers every C name it serves there: ERROR_INVALID_HANDLE, GetCurrentProcess, GetCurrentProcessId, GetCurrentThread, INVALID_HANDLE_VALUE |
| swift-subprocess | `Tests/SubprocessTests/PlatformConformance.swift` | 15 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-subprocess | `Tests/SubprocessTests/ProcessMonitoringTests.swift` | 18 `WinSDK` | Windows | System covers every C name it serves there: ERROR_INVALID_PARAMETER, GetExitCodeProcess, HANDLE, INFINITE, INVALID_HANDLE_VALUE, WaitForSingleObject, _get_osfhandle |
| swift-subprocess | `Tests/TestResources/TestResources.swift` | 13 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-syntax | `SwiftParserCLI/Sources/swift-parser-cli/Commands/Reduce.swift` | 17 `WinSDK` | Windows | System covers every C name it serves there: TerminateProcess |
| swift-syntax | `SwiftParserCLI/Sources/swift-parser-cli/swift-parser-cli.swift` | 23 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/AttachableAsIWICBitmapSource.swift` | 13 `WinSDK` | Windows | System covers every C name it serves there: GetLastError, HRESULT, S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/HICON+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/IWICBitmapSource+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/UnsafeMutablePointer+AttachableAsIWICBitmapSource.swift` | 12 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Attachments/_AttachableImageWrapper+AttachableWrapper.swift` | 12 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Support/Additions/IPropertyBag2Additions.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Overlays/_Testing_WinSDK/Support/Additions/IWICImagingFactoryAdditions.swift` | 12 `WinSDK` | Windows | System covers every C name it serves there: S_OK |
| swift-testing | `Sources/Testing/ABI/ABI.VersionNumber.swift` | 229 marker: Memory.firstRange(of:in:) on WASI (memmem) | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI? | System covers every C name it serves there: memmem |
| swift-testing | `Sources/Testing/ABI/ABI.swift` | 364 marker: stdlib.h calloc on Windows: Memory.allocateZeroed(count:stride:) | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: calloc |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 38 marker: stdlib.h EXIT_SUCCESS and EXIT_FAILURE in Embedded Swift, which | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_FAILURE, EXIT_SUCCESS |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 57 marker: stdlib.h EXIT_FAILURE in Embedded Swift, as above, 161 marker: stdlib.h EXIT_FAILURE in Embedded Swift, as above | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_FAILURE |
| swift-testing | `Sources/Testing/ABI/EntryPoints/EntryPoint.swift` | 152 marker: stdlib.h EXIT_SUCCESS in Embedded Swift, as above | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_SUCCESS |
| swift-testing | `Sources/Testing/ABI/EntryPoints/SwiftPMEntryPoint.swift` | 31 marker: sysexits.h EX_UNAVAILABLE on WASI: ProcessID.ExitCode.serviceUnavailab… | Darwin?, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows? | System covers every C name it serves there: EX_UNAVAILABLE |
| swift-testing | `Sources/Testing/Events/Clock.swift` | 33 marker: time.h timespec_get on Windows: ClockID.realtime's currentTimeSpec() | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: timespec_get |
| swift-testing | `Sources/Testing/ExitTests/ExitStatus.swift` | 113 marker: stdlib.h and sysexits.h exit codes' C names, such as | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | the marker names no C interface (stdlib.h and sysexits.h exit codes' C names) |
| swift-testing | `Sources/Testing/ExitTests/ExitTest.Condition.swift` | 232 marker: stdlib.h EXIT_SUCCESS in Embedded Swift, which SystemPackage | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | System covers every C name it serves there: EXIT_SUCCESS |
| swift-testing | `Sources/Testing/SourceAttribution/Backtrace+Symbolication.swift` | 150 marker: string.h strlen and stdlib.h free on Windows: CString.length(of:) | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: free, strlen |
| swift-testing | `Sources/Testing/Support/Additions/CommandLineAdditions.swift` | 63 marker: FilePath.currentExecutable() (KERN_PROC_PATHNAME) on FreeBSD, and on O… | FreeBSD? | System covers every C name it serves there: KERN_PROC_PATHNAME |
| swift-testing | `Sources/Testing/Support/CError.swift` | 76 marker: string.h strerror_r on FreeBSD and OpenBSD: Errno's description | FreeBSD, OpenBSD | System covers every C name it serves there: strerror_r |
| swift-testing | `Sources/Testing/Support/FileHandle.swift` | 800 marker: unistd.h isatty on WASI: FileDescriptor.isTerminal | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: isatty |
| swift-testing | `Sources/Testing/Support/FileHandle.swift` | 901 marker: stdlib.h realpath on WASI: FilePath.canonicalized() | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: realpath |
| swift-testing | `Sources/_TestDiscovery/SectionBounds.swift` | 44 marker: Mach-O images: mach-o/getsect.h getsectiondata and mach-o/dyld.h | Darwin? | System covers every C name it serves there: getsectiondata |
| swift-testing | `Tests/TestingTests/ABIEntryPointTests.swift` | 242 marker: stdlib.h free and string.h strlen on Windows: Memory.free(_:) | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: free, strlen |
| swift-testing | `Tests/TestingTests/AttachmentTests.swift` | 41 `WinSDK` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| swift-testing | `Tests/TestingTests/AttachmentTests.swift` | 95 marker: stdio.h remove on Windows and WASI: FilePath.remove(), 112 marker: stdio.h remove, as above, 143 marker: stdio.h remove, as above, 151 marker: stdio.h remove, as above, 179 marker: stdio.h remove, as above, 199 marker: stdio.h remove, as above | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: remove |
| swift-testing | `Tests/TestingTests/AttachmentTests.swift` | 163 marker: limits.h NAME_MAX on WASI: SystemConfig.maxFileNameBytes | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI? | System covers every C name it serves there: NAME_MAX |
| swift-testing | `Tests/TestingTests/ExitTestTests.swift` | 50 marker: signal.h SIGABRT on Windows: Signal.abort, 89 marker: signal.h SIGABRT on Windows, as above | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: SIGABRT |
| swift-testing | `Tests/TestingTests/Support/ColorTests.swift` | 40 marker: stdio.h remove on Windows and WASI: FilePath.remove() | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: remove |
| swift-testing | `Tests/TestingTests/Support/FileHandleTests.swift` | 291 marker: stdio.h remove on Windows and WASI: FilePath.remove() | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: remove |
| swift-testing | `Tests/TestingTests/SwiftPMTests.swift` | 387 marker: stdio.h remove on Windows and WASI: FilePath.remove(), 413 marker: stdio.h remove, as above, 435 marker: stdio.h remove, as above, 464 marker: stdio.h remove, as above, 563 marker: stdio.h remove, as above, 613 marker: stdio.h remove, as above | Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows? | System covers every C name it serves there: remove |
| swift-tools-protocols | `Sources/LanguageServerProtocolTransport/JSONRPCConnection.swift` | 24 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-tools-protocols | `Sources/SKLogging/SetGlobalLogFileHandler.swift` | 25 `WinSDK` | Windows | System covers every C name it serves there: CloseHandle, OpenProcess, PROCESS_QUERY_INFORMATION |
| swift-tools-protocols | `Sources/ToolsProtocolsSwiftExtensions/URLExtensions.swift` | 16 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swift-tools-protocols | `Tests/LanguageServerProtocolTransportTests/ConnectionTests.swift` | 24 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-tools-protocols | `Tests/ToolsProtocolsSwiftExtensionsTests/AsyncUtilsTests.swift` | 22 `WinSDK` | Windows | System covers every C name it serves there: Sleep |
| swift-tools-support-core | `Sources/TSCBasic/TerminalController.swift` | 14 `CRT` | Windows | System covers every C name it serves there: CONSOLE_SCREEN_BUFFER_INFO, ENABLE_VIRTUAL_TERMINAL_PROCESSING, GetConsoleMode, GetConsoleScreenBufferInfo, GetStdHandle, INVALID_HANDLE_VALUE, STD_OUTPUT_HANDLE, SetConsoleMode… |
| swift-tools-support-core | `Sources/TSCBasic/Thread.swift` | 14 `WinSDK` | Windows | System covers every C name it serves there: SwitchToThread |
| swift-tools-support-core | `Sources/TSCLibc/libc.swift` | 12 `CRT`, re-exported, 13 `WinSDK`, re-exported | Windows | System covers every C name it serves there: EINVAL, _O_BINARY, _O_NOINHERIT, _O_RDWR, _SH_DENYNO, _S_IREAD, _S_IWRITE, _set_errno… |
| swiftpm | `Sources/Basics/Archiver/TarArchiver.swift` | 19 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/Basics/Cancellator.swift` | 18 `WinSDK` | Windows | System covers every C name it serves there: GetCurrentProcess, SIGINT, SIGTERM, SetConsoleCtrlHandler, TerminateProcess |
| swiftpm | `Sources/Basics/Concurrency/AsyncProcess.swift` | 20 `Android` | Android | System covers every C name it serves there: fdopen |
| swiftpm | `Sources/Basics/Environment/Environment.swift` | 17 `CRT`, 18 `WinSDK` | Windows | System covers every C name it serves there: GetLastError, SetEnvironmentVariableW, _putenv, _read |
| swiftpm | `Sources/Commands/SwiftTestCommand.swift` | 49 `WinSDK` | Windows | System covers every C name it serves there: ERROR_NOT_FOUND |
| swiftpm | `Sources/Commands/Utilities/TestingSupport.swift` | 22 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/Commands/Utilities/TestingSupport.swift` | 26 `Glibc` | FreeBSD | System covers every C name it serves there: pthread_suspend_all_np |
| swiftpm | `Sources/CoreCommands/SwiftCommandState.swift` | 41 `WinSDK` | Windows | no C name it serves was found on its platforms |
| swiftpm | `Sources/PackageRegistryCommand/PackageRegistryCommand+Auth.swift` | 30 `WinSDK` | Windows | System covers every C name it serves there: DWORD, ENABLE_LINE_INPUT, GetConsoleMode, GetStdHandle, HANDLE, INVALID_HANDLE_VALUE, ReadConsoleA, STD_INPUT_HANDLE… |
| swiftpm | `Sources/Runtimes/PackageDescription/PackageDescription.swift` | 14 `ucrt` | Windows | System covers every C name it serves there: HANDLE, _O_APPEND, _close, _fdopen, _open_osfhandle, atexit, fclose, fputs |
| swiftpm | `Sources/Runtimes/PackageDescription/PackageDescription.swift` | 15 `WinSDK` (scoped) | Windows | System covers every C name it serves there: HANDLE |
| wasmkit | `Examples/embedded-wat/Sources/embedded-wat/Entrypoint.swift` | 4 `WASILibc`, 6 `Darwin`, 8 `Glibc` | Darwin, Linux, FreeBSD, OpenBSD, WASI | no C name it serves was found on its platforms |
| wasmkit | `Sources/CLICommands/Platform.swift` | 7 `ucrt` | Windows | System covers every C name it serves there: FILE, SEEK_SET, _fileno, _get_errno, _wfopen, fclose, ferror, fflush… |
| wasmkit | `Sources/CLICommands/TCPListener.swift` | 104 marker: SystemSockets on FreeBSD (PackageDescription can't name .freebsd) | FreeBSD?, WASI? | the marker names no C interface (SystemSockets on FreeBSD (PackageDescription can't name .freebsd)) |
| wasmkit | `Sources/CLICommands/TCPListener.swift` | 106 `Glibc` | FreeBSD? | System covers every C name it serves there: AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR, bind, close, inet_pton, listen… |
| wasmkit | `Sources/CLICommands/TCPListener.swift` | 108 `Musl`, 110 `Android` | none | no platform's build compiles it (a branch none takes, or a flag the model sets false) |
| wasmkit | `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` | 10 `Glibc`, 1 marker | OpenBSD | no C name it serves was found on its platforms |
| wasmkit | `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` | 13 `ucrt`, 14 `WinSDK` | Windows | System covers every C name it serves there: ERROR_BAD_NETPATH, ERROR_BAD_NET_NAME, ERROR_BAD_PATHNAME, ERROR_CANNOT_MAKE, ERROR_CURRENT_DIRECTORY, ERROR_DRIVE_LOCKED, ERROR_FAIL_I24, ERROR_INVALID_ACCESS… |
| wasmkit | `Sources/WASI/Platform/PAL/PALErrnoMapping.swift` | 122 marker: Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the… | OpenBSD, Windows | the marker names no C interface (Errno.multiHop and .noLink on OpenBSD (the arm Windows shares maps the C values)) |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 8 `ucrt`, 9 `WinSDK` | Windows | System covers every C name it serves there: BY_HANDLE_FILE_INFORMATION, DWORD, FILETIME, FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_REPARSE_POINT, FILE_END_OF_FILE_INFO, FileEndOfFileInfo, FlushFileBuffers… |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 12 `WASILibc` | WASI | System covers every C name it serves there: O_RDONLY, O_RDWR, O_WRONLY, mode_t, openat, st_atim, st_ctim, st_mtim |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 123 marker: OpenOptions.dataSync and .sync on WASI, 397 marker: OpenOptions.dataSync and .sync on WASI | WASI | the marker names no C interface (OpenOptions.dataSync and .sync on WASI) |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 546 marker: PThread.yield on WASI without threads (wasip1 has sched_yield) | WASI | the marker names no C interface (PThread.yield on WASI without threads (wasip1 has sched_yield)) |
| wasmkit | `Sources/WASI/Platform/PAL/PALFileDescriptor.swift` | 697 marker: OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC an… | WASI | the marker names no C interface (OpenOptions.dataSync and .sync on WASI (wasi-libc's O_DSYNC, O_SYNC and O_RSYNC are WASI's) |
| wasmkit | `Sources/WASI/Platform/PAL/PALSystemClocks.swift` | 6 `WinSDK` | Windows | System covers every C name it serves there: FILETIME, GetLastError, GetSystemTimePreciseAsFileTime, LARGE_INTEGER, QueryPerformanceCounter, QueryPerformanceFrequency |
| wasmkit | `Sources/WasmKit/Execution/StatsCollector.swift` | 7 `ucrt` | Windows? | System covers every C name it serves there: fwrite |
| wasmkit | `Sources/WasmKit/Platform/AtomicParkingLot.swift` | 38 `WinSDK` | Windows? | System covers every C name it serves there: AcquireSRWLockExclusive, CONDITION_VARIABLE, DWORD, GetTickCount64, INFINITE, InitializeConditionVariable, InitializeSRWLock, ReleaseSRWLockExclusive… |
| wasmkit | `Sources/WasmParser/Platform/FileIO.swift` | 7 `ucrt` | Windows? | System covers every C name it serves there: _O_BINARY, _O_RDONLY, _SH_DENYNO, _close, _get_errno, strerror |
| wasmkit | `Sources/WasmTools/WasmTools.swift` | 7 `ucrt` | Windows | System covers every C name it serves there: _O_BINARY, _close |
| wasmkit | `Tests/WASITests/TestSupport.swift` | 7 `ucrt` | Windows | System covers every C name it serves there: strerror |

## System gaps, by sites unblocked

Each row is a gap in System at `system-next`: a mapping.ini entry (or a C name in none) that System lacks on the platforms given, or a gap `exceptions.ini` keeps by hand. *Unblocks*: the sites that leave this category once it's filled, given the rows above are, and the files they're in (a scoped import is a site of its own, so a file that imports declaration by declaration has many); the order is greedy, ties going to more platforms. *Holds*: every site it's one of the gaps of.

| # | Gap | Lacks | Unblocks | Holds | Repositories | C names | System |
|---:|---|---|---:|---:|---|---|---|
| 1 | [multicast] | WASI, Windows | 22 (3 files) | 24 | swift-nio | `IPV6_JOIN_GROUP`, `IPV6_LEAVE_GROUP`, `IPV6_MULTICAST_HOPS`, `IPV6_MULTICAST_IF`, `IPV6_MULTICAST_LOOP`, `IP_ADD_MEMBERSHIP`… | SocketDescriptor.IPv6Option.joinGroup isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 2 | [address families] | Windows | 20 (6 files) | 24 | swift-certificates, swift-nio | `AF_INET`, `AF_INET6`, `AF_UNIX`, `AF_UNSPEC`, `PF_INET`, `PF_INET6`… | SocketAddress.Family.ipv4 isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 3 | [socket options] | Android, OpenBSD, WASI, Windows | 16 (2 files) | 18 | swift-nio | `SOL_SOCKET`, `SO_BROADCAST`, `SO_ERROR`, `SO_KEEPALIVE`, `SO_LINGER`, `SO_RCVBUF`… | SocketDescriptor.AncillaryMessageBuffer.Message.timestamp isn't built on Windows (only Darwin, Linux, Musl, … |
| 4 | [Winsock addresses] | Windows | 16 (5 files) | 18 | swift-certificates, swift-nio | `ADDRESS_FAMILY`, `IN6_ADDR`, `IN_ADDR`, `SOCKADDR`, `SOCKADDR_IN`, `SOCKADDR_IN6`… | System names it nowhere |
| 5 | [sockaddr types] | Windows | 15 (9 files) | 17 | swift-certificates, swift-nio | `in6_addr`, `in_addr`, `sockaddr`, `sockaddr_in`, `sockaddr_in6`, `sockaddr_un`… | CInterop.SockLen isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 6 | [Windows name resolution] | Windows | 8 (2 files) | 9 | swift-nio | `ADDRINFOW`, `FreeAddrInfoW`, `GetAddrInfoW`, `gai_strerrorA` | System names it nowhere |
| 7 | [Winsock sockets] | Windows | 7 (3 files) | 12 | swift-nio | `FIONBIO`, `INVALID_SOCKET`, `SOCKET`, `SOCKET_ERROR`, `closesocket`, `ioctlsocket` | System names it nowhere |
| 8 | [protocol levels] | Windows | 7 (2 files) | 9 | swift-nio | `IPPROTO_IP`, `IPPROTO_IPV6`, `IPPROTO_TCP`, `IPPROTO_UDP` | SocketDescriptor.ProtocolID.ip isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, … |
| 9 | [INADDR_ANY] | Windows | 7 (4 files) | 7 | swift-nio | `INADDR_ANY`, `INET6_ADDRSTRLEN`, `INET_ADDRSTRLEN` | IPv4Address.Host.descriptionCapacity isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 10 | [Winsock messages] | Windows | 6 (2 files) | 7 | swift-nio | `LPFN_WSARECVMSG`, `LPFN_WSASENDMSG`, `LPWSAMSG`, `WSABUF`, `WSACMSGHDR`, `WSAIoctl`… | System names it nowhere |
| 11 | [socket types] | Windows | 5 (2 files) | 6 | swift-nio | `SOCK_DGRAM`, `SOCK_RAW`, `SOCK_STREAM` | SocketDescriptor.ConnectionType.datagram isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 12 | [shutdown] | Windows | 4 (1 file) | 5 | swift-nio | `SD_BOTH`, `SD_RECEIVE`, `SD_SEND`, `shutdown` | System names it nowhere |
| 13 | [ECN, TOS and packet info] | Windows | 4 (2 files) | 4 | swift-nio | `IPV6_PKTINFO`, `IPV6_RECVTCLASS`, `IP_PKTINFO`, `IP_RECVTOS` | SocketDescriptor.IPv6Option.receiveTrafficClass isn't built on Windows (only Darwin, Linux, Musl, Android, … |
| 14 | [signal numbers] | WASI | 4 (1 file) | 4 | swift-testing | `SIGABRT` | Signal.abort isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows) |
| 15 | [IPV6_V6ONLY and IP_HDRINCL] | WASI, Windows | 3 (2 files) | 5 | swift-nio | `IPV6_V6ONLY`, `IP_HDRINCL` | SocketDescriptor.IPv6Option.v6Only isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 16 | [TCP_NODELAY] | WASI, Windows | 3 (2 files) | 4 | swift-nio | `TCP_NODELAY` | SocketDescriptor.TCPOption.noDelay isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, … |
| 17 | [sendfile] | FreeBSD, Windows | 3 (2 files) | 4 | swift-nio | `TF_USE_KERNEL_APC`, `TransmitFile`, `sendfile` | System names it nowhere |
| 18 | [inet_ntop and inet_pton] | Windows | 3 (2 files) | 4 | swift-certificates, swift-nio | `inet_ntop`, `inet_pton` | IPv4Address.Host.init isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 19 | [Winsock errors] | Windows | 2 (2 files) | 6 | swift-nio | `WSAEINVAL`, `WSAEWOULDBLOCK`, `WSAGetLastError` | System names it nowhere |
| 20 | [SO_RCVTIMEO and SO_TIMESTAMP] | Windows | 3 (2 files) | 3 | swift-nio | `SO_RCVTIMEO` | SocketDescriptor.SocketOption.receiveTimeout isn't built on Windows (only Darwin, Linux, Musl, Android, … |
| 21 | [Windows process exit] | Windows | 2 (2 files) | 3 | swift-build, swift-subprocess | `RegisterWaitForSingleObject`, `UnregisterWait`, `WAITORTIMERCALLBACK`, `WT_EXECUTELONGFUNCTION`, `WT_EXECUTEONLYONCE` | System names it nowhere |
| 22 | [getsockname and getpeername] | Windows | 2 (1 file) | 3 | swift-nio | `getpeername`, `getsockname` | SocketDescriptor.getPeerAddress isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 23 | [linger] | Windows | 2 (2 files) | 3 | swift-nio | `LINGER`, `linger` | CInterop.Linger isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 24 | POSIXErrorCode | Windows | 2 (1 file) | 2 | swift-foundation | `POSIXErrorCode` | CInterop.POSIXErrorCode isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 25 | [sockaddr_storage] | Windows | 2 (2 files) | 2 | swift-nio | `sockaddr_storage` | CInterop.SockAddrStorage isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 26 | funopen | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `funopen` | System names it nowhere |
| 27 | getc_unlocked | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `getc_unlocked` | System names it nowhere |
| 28 | strchr | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `strchr` | System names it nowhere |
| 29 | task_set_exception_ports | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `task_set_exception_ports` | System names it nowhere |
| 30 | [FreeBSD extended attributes] | OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-foundation | `extattr_*` | System names it nowhere |
| 31 | [call stack] | Musl, FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-testing | `backtrace` | CallStack.returnAddresses isn't built on Musl (only Darwin, Linux) |
| 32 | [usleep] | WASI, Windows | 1 (1 file) | 2 | swift-sdk-generator, swift-stress-tester | `usleep` | PThread.sleep(for:) isn't built on WASI |
| 33 | useconds_t | Android, WASI | 2 (1 file) | 2 | swift-sdk-generator | `useconds_t` | System names it nowhere |
| 34 | CLOCK_MONOTONIC_RAW | FreeBSD, OpenBSD | 1 (1 file) | 1 | wasmkit | `CLOCK_MONOTONIC_RAW` | ClockID.monotonicRaw isn't built on FreeBSD (only Darwin, Linux, Musl, Android) |
| 35 | [dlopen] | WASI, Windows | 1 (1 file) | 1 | swift-testing | `dlsym` | DynamicLibrary.address isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 36 | sin_addr | Windows | 1 (1 file) | 4 | swift-nio | `sin_addr` | System's accessor isn't built on Windows |
| 37 | sin_port | Windows | 1 (1 file) | 4 | swift-nio | `sin_port` | System's accessor isn't built on Windows |
| 38 | [accept] | Windows | 1 (1 file) | 3 | swift-nio | `accept` | SocketDescriptor.accept isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 39 | [listen] | Windows | 1 (1 file) | 3 | swift-nio | `listen` | SocketDescriptor.listen isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 40 | LC_ALL | Windows | 1 (1 file) | 2 | swift-foundation | `LC_ALL` | CLocale.Category.all isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 41 | [bind] | Windows | 1 (1 file) | 2 | swift-nio | `bind` | SocketDescriptor.bind isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 42 | [connect] | Windows | 1 (1 file) | 2 | swift-nio | `connect` | SocketDescriptor.connect isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 43 | [poll] | Windows | 1 (1 file) | 2 | swift-nio | `POLLERR`, `POLLHUP`, `POLLNVAL`, `POLLRDNORM`, `POLLWRNORM`, `WSAPoll`… | CInterop.PollFD isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 44 | [send and receive] | Windows | 1 (1 file) | 2 | swift-nio | `recv`, `send` | SocketDescriptor.receive isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 45 | [socket] | Windows | 1 (1 file) | 2 | swift-nio | `socket` | SocketDescriptor.open isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 46 | UnmapViewOfFile | Windows | 1 (1 file) | 1 | swift-foundation | `UnmapViewOfFile` | System names it nowhere |
| 47 | [Windows process creation] | Windows | 1 (1 file) | 1 | swift-subprocess | `CreateProcessWithLogonW`, `LOGON_WITH_PROFILE`, `LPPROC_THREAD_ATTRIBUTE_LIST`, `STARTF_USESHOWWINDOW`, `SW_HIDE`, `SW_SHOWMAXIMIZED`… | System names it nowhere |
| 48 | [file type bits] | OpenBSD | 1 (1 file) | 1 | swift-nio | `S_IFWHT` | FileType.whiteout isn't built on OpenBSD (only Darwin, FreeBSD) |
| 49 | [getuid] | WASI | 1 (1 file) | 1 | swift-foundation | `getuid` | UserID.real isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 50 | [pipe] | WASI | 1 (1 file) | 1 | swift-testing | `pipe2` | FileDescriptor.pipe isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows) |
| 51 | [stdio] | Android | 1 (1 file) | 1 | swift-testing | `fmemopen` | FileStream.open isn't built on Android (only Darwin, Linux, Musl, FreeBSD, OpenBSD, WASI) |
| 52 | f_frsize | FreeBSD | 1 (1 file) | 1 | swift-foundation | `f_frsize` | System's accessor isn't built on FreeBSD |
| 53 | munmap | WASI | 1 (1 file) | 1 | swift-foundation | `munmap` | MemoryMapping.unmap isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 54 | raise | WASI | 1 (1 file) | 1 | swift-testing | `raise` | Signal.raise isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows) |
| 55 | setlocale | Windows | 1 (1 file) | 1 | swift-foundation | `setlocale` | CLocale.globalName isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 56 | copy_file_range | Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `copy_file_range` | System names it nowhere |
| 57 | [Mach-O file format] | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 2 | swift-syntax | `mach_header_64` | CInterop.MachHeader64 isn't built on Linux (only Darwin) |
| 58 | [loaded images] | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 2 (1 file) | 2 | swift-syntax | `_dyld_get_image_header`, `getsectiondata` | DynamicLibrary.loadedImageHeader isn't built on Linux (only Darwin) |
| 59 | fclonefileat | Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows | 0 (0 files) | 1 | swift-testing | `fclonefileat` | FileDescriptor.clone isn't built on Linux (only Darwin) |
| 60 | FICLONE | Darwin, FreeBSD, OpenBSD, WASI, Windows | 1 (1 file) | 1 | swift-testing | `FICLONE` | FileDescriptor.cloneContents isn't built on Darwin (only Linux, Musl, Android) |
| 61 | IPTOS_ECN_* | Linux, Musl, Android, FreeBSD | 0 (0 files) | 1 | swift-nio | `IPTOS_ECN_*` | System names it nowhere |
| 62 | [sendmmsg and recvmmsg] | FreeBSD | 1 (1 file) | 1 | swift-nio | `sendmmsg` | SocketDescriptor.sendMessages isn't built on FreeBSD (only Darwin, Linux, Musl, Android) |
| 63 | ai_family | FreeBSD, OpenBSD, Windows | 0 (0 files) | 2 | swift-nio | `ai_family` | System names it nowhere |
| 64 | ai_flags | FreeBSD, OpenBSD | 1 (1 file) | 1 | swift-nio | `ai_flags` | System names it nowhere |
| 65 | msg_hdr | Windows | 0 (0 files) | 3 | swift-nio | `msg_hdr` | System's accessor isn't built on Windows |
| 66 | msg_len | Windows | 2 (2 files) | 3 | swift-nio | `msg_len` | System's accessor isn't built on Windows |
| 67 | cmsg_len | Windows | 1 (1 file) | 1 | swift-nio | `cmsg_len` | System's accessor isn't built on Windows |
| 68 | sin6_addr | Windows | 0 (0 files) | 3 | swift-nio | `sin6_addr` | System's accessor isn't built on Windows |
| 69 | sin6_family | Windows | 0 (0 files) | 3 | swift-nio | `sin6_family` | System's accessor isn't built on Windows |
| 70 | sin6_flowinfo | Windows | 0 (0 files) | 3 | swift-nio | `sin6_flowinfo` | System's accessor isn't built on Windows |
| 71 | sin6_port | Windows | 0 (0 files) | 3 | swift-nio | `sin6_port` | System's accessor isn't built on Windows |
| 72 | sin6_scope_id | Windows | 0 (0 files) | 3 | swift-nio | `sin6_scope_id` | System's accessor isn't built on Windows |
| 73 | sin_family | Windows | 1 (1 file) | 3 | swift-nio | `sin_family` | System's accessor isn't built on Windows |
| 74 | sun_family | Windows | 0 (0 files) | 3 | swift-nio | `sun_family` | System's accessor isn't built on Windows |
| 75 | sun_path | Windows | 2 (2 files) | 3 | swift-nio | `sun_path` | System's accessor isn't built on Windows |
| 76 | ss_family | Windows | 1 (1 file) | 1 | swift-nio | `ss_family` | System's accessor isn't built on Windows |
| 77 | st_dev | Windows | 0 (0 files) | 2 | llbuild | `st_dev` | System's accessor isn't built on Windows |
| 78 | st_ino | Windows | 0 (0 files) | 2 | llbuild | `st_ino` | System's accessor isn't built on Windows |
| 79 | st_mode | Windows | 0 (0 files) | 2 | llbuild | `st_mode` | System's accessor isn't built on Windows |
| 80 | st_size | Windows | 2 (1 file) | 2 | llbuild | `st_size` | System's accessor isn't built on Windows |
| 81 | FindClose | Windows | 0 (0 files) | 1 | swift-foundation | `FindClose` | System's implementation uses it; no public declaration names it |
| 82 | FindExInfoBasic | Windows | 0 (0 files) | 1 | swift-foundation | `FindExInfoBasic` | System names it nowhere |
| 83 | FindExSearchNameMatch | Windows | 0 (0 files) | 1 | swift-foundation | `FindExSearchNameMatch` | System names it nowhere |
| 84 | FindFirstFileExW | Windows | 0 (0 files) | 1 | swift-foundation | `FindFirstFileExW` | System names it nowhere |
| 85 | FindNextFileW | Windows | 0 (0 files) | 1 | swift-foundation | `FindNextFileW` | System's implementation uses it; no public declaration names it |
| 86 | WIN32_FIND_DATAW | Windows | 1 (1 file) | 1 | swift-foundation | `WIN32_FIND_DATAW` | System's implementation uses it; no public declaration names it |
| 87 | MAP_FAILED | WASI | 0 (0 files) | 1 | swift-foundation | `MAP_FAILED` | MemoryMapping.init isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 88 | MAP_PRIVATE | WASI | 0 (0 files) | 1 | swift-foundation | `MAP_PRIVATE` | MemoryMapping.Options.private isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 89 | MPTCP_INFO | Linux | 0 (0 files) | 1 | swift-nio | `MPTCP_INFO` | System names it nowhere |
| 90 | [TCP connection info] | Linux | 1 (1 file) | 1 | swift-nio | `mptcp_info` | System names it nowhere |
| 91 | PROT_READ | WASI | 0 (0 files) | 1 | swift-foundation | `PROT_READ` | MemoryMapping.Protection.read isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 92 | mmap | WASI | 1 (1 file) | 1 | swift-foundation | `mmap` | MemoryMapping isn't built on WASI (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD) |
| 93 | WSAEFAULT | Windows | 0 (0 files) | 1 | swift-nio | `WSAEFAULT` | System names it nowhere |
| 94 | [gettimeofday] | Windows | 0 (0 files) | 1 | swift-nio | `timeval` | CInterop.TimeVal isn't built on Windows (only Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI) |
| 95 | l_linger | Windows | 0 (0 files) | 1 | swift-nio | `l_linger` | System's accessor isn't built on Windows |
| 96 | l_onoff | Windows | 0 (0 files) | 1 | swift-nio | `l_onoff` | System's accessor isn't built on Windows |
| 97 | tv_usec | Windows | 1 (1 file) | 1 | swift-nio | `tv_usec` | System's accessor isn't built on Windows |

## Queued work

System or adopter work already identified, with where; ranked by the sites each holds (*+n*: sites it also holds whose category is another).

| Entry | Sites | Work | Where | Ends | Repositories |
|---|---:|---|---|---|---|
| N1: fts on Linux in swift-foundation | 17 | adopter | Prototype/Coverage5/REPORT.md, Needs design N1 (its rank 2) | Foundation's comparison run on Linux, and its Linux walks on DirectoryWalk | swift-foundation |
| N2: the thread API on WASI without threads | 3 | System | Prototype/Coverage5/REPORT.md, Needs design N2 (its rank 6) | a decision, and System's API for it on WASI | swift-async-algorithms, swift-certificates, swift-nio |
| N3: pseudoterminals on OpenBSD | 3 | System | Prototype/Coverage5/REPORT.md, Needs design N3 (its rank 9) | TerminalDescriptor.openPseudoterminal() on OpenBSD | swift-build, swift-subprocess, swift-testing |
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
| E6: swift-corelibs-foundation and swift-corelibs-xctest | 96 | Set aside by Michael 2026-10-07: likely superseded by swift-foundation; to revisit. Not counted as an exception. | Michael, 2026-10-07: set aside, to revisit (2026-10-05: undecided, not deferred) | swift-corelibs-foundation, swift-corelibs-xctest |

Reported modules (modules.ini [report]), sites by module: `os` 27.

## Not System's: mapping.ini's lane verdicts, unreviewed

mapping.ini's 11 `wrap = no` entries were written by lanes and never reviewed by Michael: lane proposals, not decisions. Each is listed with the sites it holds.

| mapping.ini entry | Category | Sites | Symbols |
|---|---|---:|---|
| [Windows window messages] | not System's (lane verdict, unreviewed) | 0 | `EnumWindows`, `GetWindowThreadProcessId`, `SendMessage`, `WM_CLOSE`, `HWND`, `_subprocess_windows_send_vm_close` |
| [autoreleasepool] | not System's (lane verdict, unreviewed) | 0 | `autoreleasepool` |
| [Dispatch] | not System's (lane verdict, unreviewed) | 0 | `DispatchQueue`, `DispatchGroup`, `DispatchData`, `DispatchSemaphore`, `DispatchTime`, `DispatchSpecificKey`… |
| [Security keychain] | not System's (lane verdict, unreviewed) | 0 | `SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `SecItemUpdate`, `kSecAttrAccount`, `kSecAttrCreationDate`… |
| [Security identities and keys] | not System's (lane verdict, unreviewed) | 0 | `SecIdentityRef`, `SecCertificateRef`, `SecKeyRef`, `SecCertificateCopyData`, `SecIdentityCopyCertificate`, `SecIdentityCopyPrivateKey`… |
| [CoreFoundation] | not System's (lane verdict, unreviewed) | 0 | `CFGetTypeID`, `CFStringRef`, `CFTypeRef`, `CFDataRef`, `CFDictionaryRef`, `CFErrorRef`… |
| [CryptoKit] | not System's (lane verdict, unreviewed) | 0 | `ECDSASignature`, `HashFunction`, `P256`, `PrivateKey`, `PublicKey`, `SHA256`… |
| [os_log and signposts] | not System's (lane verdict, unreviewed) | 0 | `OSSignpostID`, `os_signpost_type_t`, `OSLog`, `OSLogPrivacy`, `OSSignposter`, `OSSignpostIntervalState` |
| [other frameworks' names] | not System's (lane verdict, unreviewed) | 0 | `Logger`, `NSDictionary`, `CFRunLoopStop` |
| [Objective-C runtime] | not System's (lane verdict, unreviewed) | 0 | `NSObject`, `description` |
| [SQLite] | not System's (lane verdict, unreviewed) | 0 | `sqlite3_bind_blob`, `sqlite3_bind_int64`, `sqlite3_bind_null`, `sqlite3_bind_text`, `sqlite3_busy_timeout`, `sqlite3_clear_bindings`… |

Imports of the modules modules.ini lists as not System's (reviewed by Michael, 2026-10-05: libraries, not OS interfaces) aren't sites: `Dispatch` 216, `ObjectiveC` 5.

## Standard library

Sites whose C names that System doesn't cover all have the standard library's answer in mapping.ini (`swift`): adopter work, with the answer given.

| Answer | Sites | Repositories |
|---|---:|---|
| [Win32 scalar types] | 45 | indexstore-db, sourcekit-lsp, swift-build, swift-docc, swift-driver, swift-foundation, swift-nio, swift-testing, swift-tools-support-core, swiftpm, wasmkit |
| [C scalar types] | 7 | swift-foundation, swift-nio, swift-subprocess, swiftpm |
| [memory copies] | 7 | swift-foundation |
| [monotonic clock] | 2 | swift-nio |
| [mutexes] | 1 | swift-subprocess |

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

**indexstore-db**, at `../adopters/indexstore-db` `migrate-all` @ `96d2a952`: 5 sites, 3 of them unexplained (above).

- `Sources/ISDBTibs/TibsToolchain.swift` 17 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/index-dump/LibIndexStoreProvider.swift` 16 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (UINT, WCHAR: Windows)

**llbuild**, at `../adopters/swift-llbuild` `migrate-unix` @ `314f1127`: 12 sites, 10 of them unexplained (above).

- `products/llbuildSwift/BuildSystemBindings.swift` 12 `ucrt`, 13 `WinSDK` (Windows): **System gap**: st_dev (st_dev: Windows); st_ino (st_ino: Windows); st_mode (st_mode: Windows); st_size (st_size: Windows)

**sourcekit-lsp**, at `../adopters/sourcekit-lsp` `migrate-all` @ `79583cc1`: 19 sites, 17 of them unexplained (above).

- `Sources/SKTestSupport/FindTool.swift` 20 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/SKUtilities/LineTable.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

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

**swift-argument-parser**, at `../adopters/swift-argument-parser` `migrate-all` @ `22831ad7`: 7 sites, 7 of them unexplained (above).

**swift-asn1**, at `../ecosystem/swift-asn1` @ `a54383ad`: no sites.

**swift-async-algorithms**, at `../adopters/swift-async-algorithms` `migrate-all` @ `0178ed40`: 5 sites, 4 of them unexplained (above).

- `Sources/AsyncSequenceValidation/TaskDriver.swift` 17 marker: PThread on WASI without threads (wasip1, whose SDK has wasi_pthread), … (WASI): **queued** (N2): N2 (pthread_create, pthread_join, pthread_t: WASI)

**swift-atomics**, at `../ecosystem/swift-atomics` @ `0442cb5a`: no sites.

**swift-build**, at `../adopters/swift-build` `migrate-all` @ `4f55b04e`: 18 sites, 7 of them unexplained (above).

- `Sources/SWBCore/SpecImplementations/Tools/SwiftCompiler.swift` 26 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBTaskExecution/DynamicTaskSpecs/CompilationCachingUploader.swift` 20 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/HeavyCache.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/OSLog.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SWBUtil/PathWindows.swift` 14 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (LPWSTR, ULONG, WCHAR: Windows)
- `Sources/SWBUtil/Win32.swift` 14 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (LPCWSTR, WCHAR: Windows)
- `Sources/SWBUtil/Win32Error.swift` 14 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/SWBWindowsPlatform/KnownFolders.swift` 17 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` 21 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (UINT: Windows)
- `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` 127 marker: TerminalDescriptor.openPseudoterminal() on OpenBSD (openpty, fcntl, F_… (OpenBSD): **queued** (N3): N3 (openpty: OpenBSD)
- `Tests/SwiftBuildTests/ConsoleCommands/ServiceConsoleTests.swift` 19 `WinSDK` (Windows): **System gap**: [Windows process exit] (RegisterWaitForSingleObject, UnregisterWait, WT_EXECUTELONGFUNCTION…: Windows)

**swift-certificates**, at `../adopters/swift-certificates` `migrate-all` @ `c310582c`: 5 sites, 2 of them unexplained (above).

- `Sources/X509/Lock.swift` 24 `WASILibc`, 1 marker (WASI): **queued** (N2): N2 (pthread_mutex_t: WASI)
- `Sources/X509/Verifier/RFC5280/URIConstraints.swift` 21 `WinSDK` (Windows): **System gap**: [address families] (AF_INET, AF_INET6: Windows); [Winsock addresses] (IN6_ADDR, IN_ADDR: Windows)
- `Sources/X509/Verifier/ServerIdentityPolicy.swift` 26 `WinSDK` (Windows): **System gap**: [address families] (AF_INET, AF_INET6: Windows); [sockaddr types] (in6_addr, in_addr: Windows); [inet_ntop and inet_pton] (inet_pton: Windows)

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

**swift-crypto**, at `../adopters/swift-crypto` `migrate-all` @ `ef1e59aa`: 10 sites, 10 of them unexplained (above).

**swift-docc**, at `../adopters/swift-docc` `migrate-all` @ `4e6a5cea`: 11 sites, 4 of them unexplained (above).

- `Sources/DocCCommandLine/Action/Actions/Convert/ConvertAction.swift` 19 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/DocumentationService/ExternalReferenceResolverServiceClient.swift` 15 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/ConvertActionConverter.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/DocumentationContext.swift` 17 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Infrastructure/Symbol Graph/SymbolGraphLoader.swift` 16 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SwiftDocC/Servers/FileServer.swift` 20 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/SwiftDocC/Servers/FileServer.swift` 24 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-docc-symbolkit**, at `../ecosystem/swift-docc-symbolkit` @ `e9a4c0f2`: no sites.

**swift-driver**, at `../adopters/swift-driver` `migrate-unix` @ `e7850bd0`: 14 sites, 12 of them unexplained (above).

- `Sources/swift-driver/main.swift` 19 `CRT`, 26 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (UINT: Windows)

**swift-experimental-string-processing**, at `../adopters/swift-experimental-string-processing` `migrate-all` @ `f0d0fc7f`: no sites.

**swift-format**, at `../adopters/swift-format` `migrate-all` @ `af182284`: 1 sites, 1 of them unexplained (above).

**swift-foundation**, at `../adopters/swift-foundation` `migrate-unix` @ `a9c8edea`: 172 sites, 88 of them unexplained (above).

- `Sources/FoundationEssentials/AttributedString/AttributeScope.swift` 68 marker: DynamicLibrary, in the framework build (not built here): dlopen with R…, 70 `Darwin`, 1 marker, 71 `MachO` (submodule), 1 marker (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Calendar/Calendar_Enumerate.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Data/Data+Error.swift` 15 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 25 `Android` (Android): **standard library**: [C scalar types] (SSIZE_MAX: Android)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 27 `Glibc` (Linux, FreeBSD, OpenBSD): **standard library**: [C scalar types] (SSIZE_MAX: Linux)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 31 `CRT`, 32 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (SIZE_T: Windows)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 34 `WASILibc` (WASI): **System gap**: MAP_FAILED (MAP_FAILED: WASI); MAP_PRIVATE (MAP_PRIVATE: WASI); PROT_READ (PROT_READ: WASI); mmap (mmap: WASI)
- `Sources/FoundationEssentials/Data/Data+Reading.swift` 68 marker: FilePath.extendedAttribute on FreeBSD (extattr_*), OpenBSD and WASI (n… (FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [FreeBSD extended attributes] (extattr_*: OpenBSD, WASI, Windows)
- `Sources/FoundationEssentials/Data/Data+Writing.swift` 37 `CRT`, 38 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/FoundationEssentials/Data/Data.swift` 50 `ucrt` (Windows): **standard library**: [memory copies] (memcpy, memset: Windows)
- `Sources/FoundationEssentials/Data/Data.swift` 57 `WASILibc` (WASI): **System gap**: munmap (munmap: WASI)
- `Sources/FoundationEssentials/Data/Data.swift` 73 `WinSDK` (scoped) (Windows): **System gap**: UnmapViewOfFile (UnmapViewOfFile: Windows)
- `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` 15 `Darwin` (scoped), 1 marker (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/Error/ErrorCodes+POSIX.swift` 29 `CRT`, 30 `WinSDK` (Windows): **System gap**: POSIXErrorCode (POSIXErrorCode: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Basics.swift` 22 `CRT`, 23 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 24 `Android`, 25 `unistd` (Android): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Android)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 27 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Linux, FreeBSD)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 29 `Musl` (Musl): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: Musl)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 31 `CRT`, 32 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 34 `WASILibc` (WASI): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL: WASI)
- `Sources/FoundationEssentials/FileManager/FileManager+Directories.swift` 279 marker: fts (fts_open, fts_read, FTS_PHYSICAL), until Foundation's comparison … (Linux, Musl, Android, FreeBSD, WASI): **queued** (N1): N1 (FTS_PHYSICAL, fts_open, fts_read: Linux, Musl, Android, FreeBSD, WASI)
- `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` 27 `Glibc` (Linux, FreeBSD, OpenBSD): **System gap**: f_frsize (f_frsize: FreeBSD)
- `Sources/FoundationEssentials/FileManager/FileManager+Files.swift` 33 `CRT`, 34 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 15 `WinSDK` (Windows): **System gap**: FindClose (FindClose: Windows); FindExInfoBasic (FindExInfoBasic: Windows); FindExSearchNameMatch (FindExSearchNameMatch: Windows); FindFirstFileExW (FindFirstFileExW: Windows); FindNextFileW (FindNextFileW: Windows); WIN32_FIND_DATAW (WIN32_FIND_DATAW: Windows)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 121 `Android` (Android): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Android)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 125 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 128 `Musl` (Musl): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: Musl)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 130 `WASILibc` (WASI): **queued** (N1): N1 (FTS, FTSENT, FTS_SKIP…: WASI)
- `Sources/FoundationEssentials/FileManager/FileOperations+Enumeration.swift` 139 marker: fts (fts_open, fts_read, fts_set, fts_close, FTSENT, the FTS_* options… (Linux, Musl, Android, FreeBSD, OpenBSD, WASI): **queued** (N1): N1 (FTSENT, FTS_*, fts_close…: Linux, Musl, Android, FreeBSD, OpenBSD, WASI)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 20 `Android` (Android): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Android)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 22 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 24 `Musl` (Musl): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: Musl)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 26 `CRT`, 27 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 29 `WASILibc` (WASI): **queued** (N1): N1 (FTS_NOCHDIR, FTS_NOSTAT, FTS_PHYSICAL…: WASI)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 487 marker: fts (fts_open, fts_read, FTS_XDEV), until Foundation's comparison run … (Linux, Musl, Android, FreeBSD, OpenBSD, WASI): **queued** (N1): N1 (FTS_XDEV, fts_open, fts_read: Linux, Musl, Android, FreeBSD, OpenBSD, WASI)
- `Sources/FoundationEssentials/FileManager/FileOperations.swift` 1171 marker: fts (fts_open, fts_read, FTS_PHYSICAL), until Foundation's comparison … (Linux, Musl, Android, FreeBSD, OpenBSD, WASI): **queued** (N1): N1 (FTS_PHYSICAL, fts_open, fts_read: Linux, Musl, Android, FreeBSD, OpenBSD, WASI)
- `Sources/FoundationEssentials/FileManager/SearchPaths/FileManager+WindowsSearchPaths.swift` 15 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/FoundationEssentials/Locale/Locale_Cache.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/AsyncMessage+AsyncSequence.swift` 23 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/NotificationCenter/AsyncMessage.swift` 19 `os` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/MainActorMessage.swift` 19 `os` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/NotificationCenter/NotificationCenter.swift` 15 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/NotificationCenter/NotificationCenterMessage.swift` 19 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/Platform.swift` 32 `WinSDK` (Windows): **System gap**: LC_ALL (LC_ALL: Windows)
- `Sources/FoundationEssentials/Platform.swift` 45 `Android`, 76 `Bionic` (Android): **standard library**: [memory copies] (memmove: Android)
- `Sources/FoundationEssentials/Platform.swift` 49 `Glibc` (Linux, FreeBSD, OpenBSD): **standard library**: [memory copies] (memmove: Linux, FreeBSD, OpenBSD)
- `Sources/FoundationEssentials/Platform.swift` 53 `Musl` (Musl): **standard library**: [memory copies] (memmove: Musl)
- `Sources/FoundationEssentials/Platform.swift` 79 `WASILibc` (WASI): **standard library**: [memory copies] (memmove: WASI)
- `Sources/FoundationEssentials/Platform.swift` 112 marker: memmove (not System's: the standard library's copyMemory(from:byteCoun… (Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **standard library**: [memory copies] (memmove: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/FoundationEssentials/ProcessInfo/ProcessInfo.swift` 21 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (LPWCH, ULONG, ULONGLONG…: Windows)
- `Sources/FoundationEssentials/String/String+Internals.swift` 21 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (LPWSTR, ULONG, WCHAR: Windows)
- `Sources/FoundationEssentials/String/String+Path.swift` 25 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (LPWSTR, WCHAR: Windows)
- `Sources/FoundationEssentials/TimeZone/TimeZone_Cache.swift` 20 `ucrt`, 24 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/FoundationEssentials/URL/URL.swift` 629 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationEssentials/URL/URLComponents_ObjC.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Bridge.swift` 18 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Impl.swift` 17 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PCWSTR: Windows)
- `Sources/FoundationEssentials/URL/URL_Impl.swift` 24 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/URL/URL_Swift.swift` 16 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/UUID_Wrappers.swift` 18 `Darwin` (submodule) (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationEssentials/WinSDK+Extensions.swift` 14 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR, UINT, ULONG…: Windows)
- `Sources/FoundationInternationalization/Calendar/Calendar_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/ICU/ICU+Foundation.swift` 17 `os` (scoped) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/FoundationInternationalization/Locale/Locale_Bridge.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/Locale/Locale_ICU.swift` 21 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/Locale/Locale_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/TimeZone/TimeZone_Bridge.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Sources/FoundationInternationalization/TimeZone/TimeZone_ObjC.swift` 17 `os` (none): **excluded** (E7d): Foundation's #if FOUNDATION_FRAMEWORK code
- `Tests/FoundationEssentialsTests/FileManager/FileManagerTests.swift` 40 `WASILibc` (WASI): **System gap**: [getuid] (getuid: WASI)
- `Tests/FoundationEssentialsTests/JSONEncoderTests.swift` 23 `CRT` (Windows): **System gap**: LC_ALL (LC_ALL: Windows); setlocale (setlocale: Windows)

**swift-foundation-icu**, at `../adopters/swift-foundation-icu` `migrate-all` @ `2eb5e8e9`: no sites.

**swift-llvm-bindings**, at `../ecosystem/swift-llvm-bindings` @ `c1fffb92`: no sites.

**swift-lmdb**, at `../ecosystem/swift-lmdb` @ `866bc256`: no sites.

**swift-log**, at `../adopters/swift-log` `migrate-all` @ `a7d69695`: 7 sites, 7 of them unexplained (above).

**swift-markdown**, at `../ecosystem/swift-markdown` @ `392b73b8`: no sites.

**swift-nio**, at `../adopters/swift-nio` `migrate-unix` @ `b2f3c6c9`: 483 sites, 294 of them unexplained (above).

- `Sources/NIOConcurrencyHelpers/atomics.swift` 33 `WASILibc` (WASI): **queued** (N2): N2 (sched_yield: WASI)
- `Sources/NIOConcurrencyHelpers/lock.swift` 16 `ucrt`, 17 `WinSDK` (Windows): **standard library**: [monotonic clock] (timeGetTime: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 16 `ucrt` (Windows): **System gap**: [protocol levels] (IPPROTO_IP, IPPROTO_IPV6, IPPROTO_TCP…: Windows); [multicast] (IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS…: Windows); [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY, IP_HDRINCL: Windows); [address families] (PF_INET, PF_INET6, PF_UNIX: Windows); [Winsock sockets] (SOCKET: Windows); [socket options] (SOL_SOCKET, SO_BROADCAST, SO_ERROR…: Windows); and 4 more
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
- `Sources/NIOCore/BSDSocketAPI.swift` 63 `WinSDK` (scoped) (Windows): **System gap**: [Winsock errors] (WSAGetLastError: Windows)
- `Sources/NIOCore/BSDSocketAPI.swift` 75 `Android`, 1 marker (Android): **System gap**: [socket options] (SO_REUSEPORT: Android)
- `Sources/NIOCore/BSDSocketAPI.swift` 90 `Glibc`, 1 marker (OpenBSD): **System gap**: [socket options] (SO_REUSEPORT: OpenBSD)
- `Sources/NIOCore/BSDSocketAPI.swift` 99 `WASILibc`, 1 marker (WASI): **System gap**: [multicast] (IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, IPV6_MULTICAST_HOPS…: WASI); [IPV6_V6ONLY and IP_HDRINCL] (IPV6_V6ONLY, IP_HDRINCL: WASI); [socket options] (SOL_SOCKET: WASI); [TCP_NODELAY] (TCP_NODELAY: WASI)
- `Sources/NIOCore/IO.swift` 16 `ucrt`, 25 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/NIOCore/Interfaces.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET: Windows)
- `Sources/NIOCore/Interfaces.swift` 35 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_INET6: Windows)
- `Sources/NIOCore/Interfaces.swift` 37 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET_ADDRSTRLEN: Windows)
- `Sources/NIOCore/Interfaces.swift` 38 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INET6_ADDRSTRLEN: Windows)
- `Sources/NIOCore/Interfaces.swift` 40 `WinSDK` (scoped) (Windows): **System gap**: [Winsock addresses] (ADDRESS_FAMILY: Windows)
- `Sources/NIOCore/Interfaces.swift` 44 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr: Windows)
- `Sources/NIOCore/Interfaces.swift` 45 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in: Windows)
- `Sources/NIOCore/Interfaces.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_in6: Windows)
- `Sources/NIOCore/Interfaces.swift` 47 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr_storage] (sockaddr_storage: Windows)
- `Sources/NIOCore/Interfaces.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (sockaddr_un: Windows)
- `Sources/NIOCore/Interfaces.swift` 50 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (UINT8: Windows)
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
- `Sources/NIOCore/SocketAddresses.swift` 75 `Glibc`, 1 marker (FreeBSD, OpenBSD): **System gap**: ai_family (ai_family: FreeBSD, OpenBSD); ai_flags (ai_flags: FreeBSD, OpenBSD)
- `Sources/NIOCore/SocketOptionProvider.swift` 25 marker: mptcp_info (MPTCP_INFO), on Linux (Linux, Musl): **System gap**: MPTCP_INFO (MPTCP_INFO: Linux); [TCP connection info] (mptcp_info: Linux)
- `Sources/NIOCore/SocketOptionProvider.swift` 37 `WinSDK` (Windows): **System gap**: [linger] (linger: Windows)
- `Sources/NIOCore/Utilities.swift` 31 `ucrt`, 34 `WinSDK` (scoped) (Windows): **System gap**: [address families] (AF_UNSPEC: Windows)
- `Sources/NIOCore/Utilities.swift` 45 `WinSDK` (scoped) (Windows): **standard library**: [Win32 scalar types] (ULONG: Windows)
- `Sources/NIOMulticastChat/main.swift` 26 `WinSDK` (Windows): **System gap**: sin_addr (sin_addr: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 25 `ucrt` (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET: Windows); [ECN, TOS and packet info] (IPV6_RECVTCLASS, IP_RECVTOS: Windows); [socket types] (SOCK_DGRAM, SOCK_RAW, SOCK_STREAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 27 `WinSDK` (scoped) (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 29 `WinSDK` (scoped) (Windows): **System gap**: [ECN, TOS and packet info] (IP_RECVTOS: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 30 `WinSDK` (scoped) (Windows): **System gap**: [ECN, TOS and packet info] (IPV6_RECVTCLASS: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 32 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_DGRAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 33 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_STREAM: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 34 `WinSDK` (scoped) (Windows): **System gap**: [socket types] (SOCK_RAW: Windows)
- `Sources/NIOPosix/BSDSocketAPICommon.swift` 36 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/BSDSocketAPIWindows.swift` 20 `ucrt` (Windows): **System gap**: [Winsock sockets] (FIONBIO, INVALID_SOCKET, SOCKET_ERROR…: Windows); [Winsock addresses] (IN_ADDR, SOCKADDR, SOCKADDR_IN…: Windows); [Winsock messages] (LPFN_WSARECVMSG, LPFN_WSASENDMSG, LPWSAMSG…: Windows); [shutdown] (SD_BOTH, SD_RECEIVE, SD_SEND…: Windows); [sendfile] (TF_USE_KERNEL_APC, TransmitFile: Windows); [Winsock errors] (WSAEINVAL, WSAEWOULDBLOCK, WSAGetLastError: Windows); and 9 more
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
- `Sources/NIOPosix/SelectorWSAPoll.swift` 21 `WinSDK` (Windows): **System gap**: [Winsock sockets] (INVALID_SOCKET, SOCKET_ERROR: Windows); [poll] (POLLERR, POLLHUP, POLLNVAL…: Windows); [Winsock errors] (WSAGetLastError: Windows); [accept] (accept: Windows); [listen] (listen: Windows); [send and receive] (recv, send: Windows); and 2 more
- `Sources/NIOPosix/Socket.swift` 29 `WinSDK` (Windows): **System gap**: [Winsock messages] (WSABUF: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 46 `WinSDK` (scoped) (Windows): **System gap**: [INADDR_ANY] (INADDR_ANY: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 48 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (ip_mreq: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 49 `WinSDK` (scoped) (Windows): **System gap**: [multicast] (ipv6_mreq: Windows)
- `Sources/NIOPosix/SocketChannel.swift` 50 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/SocketProtocols.swift` 22 `WinSDK` (scoped) (Windows): **System gap**: [sockaddr types] (socklen_t: Windows)
- `Sources/NIOPosix/System.swift` 75 `Glibc`, re-exported (Linux, FreeBSD): **System gap**: [sendfile] (sendfile: FreeBSD)
- `Sources/NIOPosix/System.swift` 105 marker: sendmmsg and recvmmsg's mmsghdr, in6_pktinfo and IPTOS_ECN_* (CNIOLinu… (Linux, Musl, Android, FreeBSD): **System gap**: IPTOS_ECN_* (IPTOS_ECN_*: Linux, Musl, Android, FreeBSD); [sendmmsg and recvmmsg] (sendmmsg: FreeBSD)
- `Sources/NIOPosix/System.swift` 116 `ucrt`, re-exported (Windows): **System gap**: [protocol levels] (IPPROTO_UDP: Windows); [ECN, TOS and packet info] (IPV6_PKTINFO, IP_PKTINFO: Windows)
- `Sources/NIOPosix/ThreadWindows.swift` 19 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/NIOPosix/Windows.swift` 19 `WinSDK` (Windows): **System gap**: [Winsock sockets] (SOCKET, SOCKET_ERROR: Windows); [Winsock errors] (WSAGetLastError: Windows); [send and receive] (recv: Windows)
- `Tests/NIOFSTests/FileTypeTests.swift` 49 `Glibc`, 1 marker (FreeBSD, OpenBSD): **System gap**: [file type bits] (S_IFWHT: OpenBSD)
- `Tests/NIOPosixTests/ChannelPipelineTest.swift` 31 `WinSDK` (Windows): **System gap**: sin_port (sin_port: Windows)
- `Tests/NIOPosixTests/HappyEyeballsTest.swift` 31 `WinSDK` (Windows): **System gap**: sin6_addr (sin6_addr: Windows); sin6_family (sin6_family: Windows); sin6_flowinfo (sin6_flowinfo: Windows); sin6_port (sin6_port: Windows); sin6_scope_id (sin6_scope_id: Windows); sin_addr (sin_addr: Windows); and 2 more
- `Tests/NIOPosixTests/PendingDatagramWritesManagerTests.swift` 38 `WinSDK` (Windows): **System gap**: msg_hdr (msg_hdr: Windows); msg_len (msg_len: Windows); [sockaddr types] (socklen_t: Windows)
- `Tests/NIOPosixTests/SocketAddressTest.swift` 22 `WinSDK` (Windows): **System gap**: [address families] (AF_UNSPEC: Windows); sin6_addr (sin6_addr: Windows); sin6_family (sin6_family: Windows); sin6_flowinfo (sin6_flowinfo: Windows); sin6_port (sin6_port: Windows); sin6_scope_id (sin6_scope_id: Windows); and 6 more
- `Tests/NIOPosixTests/SocketOptionProviderTest.swift` 21 `WinSDK` (Windows): **System gap**: WSAEFAULT (WSAEFAULT: Windows); l_linger (l_linger: Windows); l_onoff (l_onoff: Windows); [linger] (linger: Windows); [gettimeofday] (timeval: Windows); tv_usec (tv_usec: Windows)

**swift-numerics**, at `../ecosystem/swift-numerics` @ `0a5bc040`: no sites.

**swift-sdk-generator**, at `../adopters/swift-sdk-generator` `migrate-unix` @ `bc251e13`: 3 sites, 1 of them unexplained (above).

- `Tests/AsyncProcessTests/IntegrationTests.swift` 75 `WASILibc` (WASI): **System gap**: useconds_t (useconds_t: WASI); [usleep] (usleep: WASI)
- `Tests/AsyncProcessTests/IntegrationTests.swift` 77 `Bionic` (Android): **System gap**: useconds_t (useconds_t: Android)

**swift-stress-tester**, at `../adopters/swift-stress-tester` `migrate-all` @ `e1702563`: 1 sites.

- `SourceKitStressTester/Tests/SwiftCWrapperToolTests/SwiftCWrapperToolTests.swift` 89 marker: unistd.h usleep: PThread.sleep(for:) takes a Duration, which needs mac… (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: [usleep] (usleep: WASI, Windows)

**swift-subprocess**, at `../adopters/swift-subprocess` `migrate-unix` @ `a58cc217`: 21 sites, 12 of them unexplained (above).

- `Sources/Subprocess/IO/AsyncIO+KQueue.swift` 23 `os` (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Platforms/Subprocess+BSD.swift` 21 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Platforms/Subprocess+Windows.swift` 14 `WinSDK` (Windows): **System gap**: [Windows process creation] (CreateProcessWithLogonW, LOGON_WITH_PROFILE, LPPROC_THREAD_ATTRIBUTE_LIST…: Windows); [Windows process exit] (RegisterWaitForSingleObject, UnregisterWait, WAITORTIMERCALLBACK…: Windows)
- `Sources/Subprocess/SubprocessOutputSequence.swift` 34 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Thread.swift` 15 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/Subprocess/Thread.swift` 17 `WinSDK` (Windows): **standard library**: [mutexes] (DeleteCriticalSection: Windows)
- `Tests/SubprocessTests/IntegrationTests.swift` 18 `WinSDK` (Windows): **standard library**: [C scalar types] (intptr_t: Windows)
- `Tests/SubprocessTests/UnixTests.swift` 22 `Glibc` (Linux, FreeBSD, OpenBSD): **queued** (N3): N3 (openpty: OpenBSD)
- `Tests/SubprocessTests/WindowsTests.swift` 14 `WinSDK` (Windows): **System gap**: [Windows process exit] (RegisterWaitForSingleObject, WAITORTIMERCALLBACK, WT_EXECUTELONGFUNCTION…: Windows)

**swift-syntax**, at `../adopters/swift-syntax` `migrate-all` @ `e6918103`: 6 sites, 2 of them unexplained (above).

- `EditorExtension/SwiftRefactorExtension/CommandDiscovery.swift` 13 `Darwin`, 15 `MachO` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows): **System gap**: [loaded images] (_dyld_get_image_header, getsectiondata: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); [Mach-O file format] (mach_header_64: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/SwiftSyntaxBuilder/SyntaxParsable+ExpressibleByStringInterpolation.swift` 21 `os`, 33 `os` (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-testing**, at `../adopters/swift-testing` `migrate-all` @ `7669b72e`: 60 sites, 42 of them unexplained (above).

- `Sources/Overlays/_Testing_Foundation/Attachments/Attachment+URL.swift` 17 `WinSDK` (Windows?): **standard library**: [Win32 scalar types] (UINT, ULONG: Windows)
- `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift` 125 marker: file cloning (sys/clonefile.h fclonefileat, linux/fs.h FICLONE, FreeBS… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: FICLONE (FICLONE: Darwin, FreeBSD, OpenBSD, WASI, Windows); copy_file_range (copy_file_range: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows); fclonefileat (fclonefileat: Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Overlays/_Testing_WinSDK/Attachments/AttachableImageFormat+CLSID.swift` 12 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PCWSTR, UINT: Windows)
- `Sources/Overlays/_Testing_WinSDK/Attachments/HBITMAP+AttachableAsIWICBitmapSource.swift` 12 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (UINT: Windows)
- `Sources/Testing/ExitTests/ExitTest.swift` 219 marker: mach/task.h task_set_exception_ports, Mach exception ports (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: task_set_exception_ports (task_set_exception_ports: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/SourceAttribution/Backtrace.swift` 84 marker: CallStack.returnAddresses(maxCount:) on Musl, FreeBSD and OpenBSD (bac… (Musl?, FreeBSD?, OpenBSD?): **System gap**: [call stack] (backtrace: Musl, FreeBSD, OpenBSD)
- `Sources/Testing/Support/Environment.swift` 90 marker: string.h strchr and strncmp in Embedded Swift, which (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: strchr (strchr: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/Support/FileHandle.swift` 518 marker: stdio.h getc_unlocked: FileStream reads only with the stream's lock ta… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: getc_unlocked (getc_unlocked: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)
- `Sources/Testing/Support/FileHandle.swift` 722 marker: unistd.h pipe2 before macOS 27: FileDescriptor.pipe(options:) (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?): **System gap**: [pipe] (pipe2: WASI)
- `Sources/Testing/Support/GetSymbol.swift` 34 marker: dlfcn.h dlsym with RTLD_DEFAULT or a handle the caller owns: DynamicLi… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [dlopen] (dlsym: WASI, Windows)
- `Tests/TestingTests/ExitTestTests.swift` 80 marker: signal.h raise and SIGSEGV on Windows: Signal.segmentationViolation.ra… (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: raise (raise: WASI)
- `Tests/TestingTests/ExitTestTests.swift` 149 marker: signal.h SIGABRT, as above, 181 marker: signal.h SIGABRT, as above, 187 marker: signal.h SIGABRT, as above, 813 marker: signal.h SIGABRT and SIGSEGV on Windows, as above (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: [signal numbers] (SIGABRT: WASI)
- `Tests/TestingTests/Support/FileHandleTests.swift` 168 marker: pty.h openpty on OpenBSD: TerminalDescriptor.openPseudoterminal() (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?): **queued** (N3): N3 (openpty: OpenBSD)
- `Tests/TestingTests/Support/FileHandleTests.swift` 225 marker: FileStream.open(memoryCapacity:mode:) on Android (fmemopen) (Android?): **System gap**: [stdio] (fmemopen: Android)
- `Tests/TestingTests/Support/FileHandleTests.swift` 318 marker: stdio.h funopen and fopencookie, a FileStream over callbacks (Darwin?, Linux?, Musl?, Android?, FreeBSD?, OpenBSD?, WASI?, Windows?): **System gap**: funopen (funopen: Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI, Windows)

**swift-toolchain-sarif**, at `../ecosystem/swift-toolchain-sarif` @ `d611f23a`: no sites.

**swift-toolchain-sqlite**, at `../ecosystem/swift-toolchain-sqlite` @ `c0ecc1e0`: no sites.

**swift-tools-protocols**, at `../adopters/swift-tools-protocols` `migrate-unix` @ `2b2c75dc`: 7 sites, 5 of them unexplained (above).

- `Sources/SKLogging/Logging.swift` 16 `os`, re-exported (Darwin?): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/SKLogging/OrLog.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)

**swift-tools-support-core**, at `../adopters/swift-tools-support-core` `migrate-unix` @ `5f85e38e`: 7 sites, 4 of them unexplained (above).

- `Sources/TSCBasic/Path.swift` 12 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR, ULONG: Windows)
- `Sources/TSCBasic/misc.swift` 15 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (ULONG_PTR, WCHAR: Windows)
- `Sources/TSCUtility/FSWatch.swift` 16 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)

**swiftpm**, at `../adopters/swift-package-manager` `migrate-unix` @ `efff7333`: 22 sites, 12 of them unexplained (above).

- `Fixtures/Miscellaneous/EchoExecutable/Sources/secho/main.swift` 2 `Glibc`, 4 `Musl`, 6 `Android`, 8 `Darwin` (submodule), 10 `ucrt` (Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, Windows): **excluded** (E7c): SwiftPM's Fixtures/ and TestObservation.swift's generated text
- `Sources/Basics/KnownFolders.swift` 16 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (PWSTR: Windows)
- `Sources/Basics/OSSignpost.swift` 14 `os` (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/PackageLoading/ManifestLoader.swift` 29 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (WCHAR: Windows)
- `Sources/Runtimes/PackagePlugin/Plugin.swift` 15 `ucrt`, 16 `WinSDK` (Windows): **standard library**: [C scalar types] (wchar_t: Windows)

**wasmkit**, at `../adopters/WasmKit` `migrate-unix` @ `d0f9f8de`: 29 sites, 25 of them unexplained (above).

- `Sources/CLICommands/Run.swift` 20 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/WASI/Platform/PAL/PALClock.swift` 55 marker: ClockID.monotonicRaw (CLOCK_MONOTONIC_RAW) on FreeBSD and OpenBSD, whi… (Linux, Musl, Android, FreeBSD, OpenBSD): **System gap**: CLOCK_MONOTONIC_RAW (CLOCK_MONOTONIC_RAW: FreeBSD, OpenBSD)
- `Sources/WasmKit/Execution/SignpostTracer.swift` 2 `os` (submodule) (Darwin): **undecided** (module os): `os` (modules.ini [report]: Michael decides module by module)
- `Sources/WasmKit/Platform/SystemVirtualMemory.swift` 5 `WinSDK` (Windows): **standard library**: [Win32 scalar types] (SIZE_T: Windows)

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
  (`Glibc.read`). A file's names count for each of its imports compiled on the platform. A marker's names count on
  the platforms its site compiles on, or on those of them the marker names right after a name (`isatty on WASI`,
  `backtrace on Linux and Android, and backtrace_async on Darwin`), as lint's markers check reads them. Rejected: adopter-coverage's
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
