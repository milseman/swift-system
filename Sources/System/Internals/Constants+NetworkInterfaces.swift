/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Interface flags
// glibc declares these in an enum, which Swift imports as Int, and the
// others as macros, so each converts.

@_alwaysEmitIntoClient
internal var _IFF_UP: CUnsignedInt { CUnsignedInt(IFF_UP) }

@_alwaysEmitIntoClient
internal var _IFF_BROADCAST: CUnsignedInt { CUnsignedInt(IFF_BROADCAST) }

@_alwaysEmitIntoClient
internal var _IFF_DEBUG: CUnsignedInt { CUnsignedInt(IFF_DEBUG) }

@_alwaysEmitIntoClient
internal var _IFF_LOOPBACK: CUnsignedInt { CUnsignedInt(IFF_LOOPBACK) }

@_alwaysEmitIntoClient
internal var _IFF_POINTOPOINT: CUnsignedInt { CUnsignedInt(IFF_POINTOPOINT) }

@_alwaysEmitIntoClient
internal var _IFF_RUNNING: CUnsignedInt { CUnsignedInt(IFF_RUNNING) }

@_alwaysEmitIntoClient
internal var _IFF_NOARP: CUnsignedInt { CUnsignedInt(IFF_NOARP) }

@_alwaysEmitIntoClient
internal var _IFF_PROMISC: CUnsignedInt { CUnsignedInt(IFF_PROMISC) }

@_alwaysEmitIntoClient
internal var _IFF_ALLMULTI: CUnsignedInt { CUnsignedInt(IFF_ALLMULTI) }

@_alwaysEmitIntoClient
internal var _IFF_MULTICAST: CUnsignedInt { CUnsignedInt(IFF_MULTICAST) }

// MARK: - Names and address families

@_alwaysEmitIntoClient
internal var _IF_NAMESIZE: Int { Int(IF_NAMESIZE) }

@_alwaysEmitIntoClient
internal var _AF_INET: CInt { AF_INET }

@_alwaysEmitIntoClient
internal var _AF_INET6: CInt { AF_INET6 }

#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _AF_PACKET: CInt { AF_PACKET }
#endif

#endif // !os(Windows) && !os(WASI)
