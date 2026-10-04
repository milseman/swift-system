/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2025 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// C interoperability types for socket operations

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
@_implementationOnly import CSystem
import Glibc
#elseif canImport(Musl)
@_implementationOnly import CSystem
import Musl
#elseif canImport(Android)
@_implementationOnly import CSystem
import Android
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported Platform")
#endif

import SystemPackage

// On WASI, SystemSockets has the address types alone: these aliases, but
// cmsghdr's and addrinfo's, which wasi-libc doesn't declare; SocketAddress,
// with its families and IPv4 and IPv6 addresses; and SocketDescriptor, with
// its domains and protocols. wasip1 has only preopened sockets, with accept,
// recv, send and shutdown (but no socket, bind or connect), and System wraps
// none of them there yet.

@available(System 199, *)
extension CInterop {
  /// Socket address structure.
  ///
  /// The corresponding C type is `sockaddr`.
  public typealias SockAddr = sockaddr

  /// Socket address length type.
  ///
  /// The corresponding C type is `socklen_t`.
  public typealias SockLen = socklen_t

  /// Socket address family type.
  ///
  /// The corresponding C type is `sa_family_t`.
  public typealias SAFamily = sa_family_t

  /// IPv4 socket address structure.
  ///
  /// The corresponding C type is `sockaddr_in`.
  public typealias SockAddrIn = sockaddr_in

  /// IPv4 address structure.
  ///
  /// The corresponding C type is `in_addr`.
  public typealias InAddr = in_addr

  /// IPv4 address type.
  ///
  /// The corresponding C type is `in_addr_t`.
  public typealias InAddrT = in_addr_t

  /// IPv6 address structure.
  ///
  /// The corresponding C type is `in6_addr`.
  public typealias In6Addr = in6_addr

  /// Port number type.
  ///
  /// The corresponding C type is `in_port_t`.
  public typealias InPort = in_port_t

  /// IPv6 socket address structure.
  ///
  /// The corresponding C type is `sockaddr_in6`.
  public typealias SockAddrIn6 = sockaddr_in6

  /// Unix domain socket address structure.
  ///
  /// The corresponding C type is `sockaddr_un`.
  public typealias SockAddrUn = sockaddr_un

  /// Socket address storage, large enough and aligned for any address family.
  ///
  /// The corresponding C type is `sockaddr_storage`.
  public typealias SockAddrStorage = sockaddr_storage

  /// I/O vector structure for scatter/gather I/O.
  ///
  /// The corresponding C type is `iovec`.
  public typealias IOVec = iovec

  /// Message header structure for sendmsg/recvmsg.
  ///
  /// The corresponding C type is `msghdr`.
  public typealias MsgHdr = msghdr

  #if !os(WASI)
  /// Control message header structure.
  ///
  /// The corresponding C type is `cmsghdr`.
  ///
  /// - Note: Not available on WASI.
  public typealias CMsgHdr = cmsghdr

  /// Address info structure for getaddrinfo.
  ///
  /// The corresponding C type is `addrinfo`.
  ///
  /// - Note: Not available on WASI.
  public typealias AddrInfo = addrinfo
  #endif

  /// The value of the linger-on-close socket option.
  ///
  /// The corresponding C type is `struct linger`.
  public typealias Linger = linger
}
