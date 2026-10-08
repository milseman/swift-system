/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// C interoperability types for Winsock, under SystemSockets' names. Winsock
// spells its structures as BSD does, with the same fields, but has no
// in_addr_t or in_port_t, whose aliases are left out; its sockaddr has no
// length field, and its in_addr and in6_addr hold their bytes in unions,
// which CInterop+WinSockAccessors.swift's accessors hide.

@available(System 199, *)
extension CInterop {
  /// Socket address structure.
  ///
  /// The corresponding C type is `SOCKADDR`.
  public typealias SockAddr = SOCKADDR

  /// Socket address length type: an `int` on Windows.
  ///
  /// The corresponding C type is `socklen_t`.
  public typealias SockLen = socklen_t

  /// Socket address family type.
  ///
  /// The corresponding C type is `ADDRESS_FAMILY`.
  public typealias SAFamily = ADDRESS_FAMILY

  /// IPv4 socket address structure.
  ///
  /// The corresponding C type is `SOCKADDR_IN`.
  public typealias SockAddrIn = SOCKADDR_IN

  /// IPv4 address structure.
  ///
  /// The corresponding C type is `IN_ADDR`.
  public typealias InAddr = IN_ADDR

  /// IPv6 address structure.
  ///
  /// The corresponding C type is `IN6_ADDR`.
  public typealias In6Addr = IN6_ADDR

  /// IPv6 socket address structure.
  ///
  /// The corresponding C type is `SOCKADDR_IN6`.
  public typealias SockAddrIn6 = SOCKADDR_IN6

  /// Unix domain socket address structure.
  ///
  /// The corresponding C type is `SOCKADDR_UN`.
  public typealias SockAddrUn = SOCKADDR_UN

  /// Socket address storage, large enough and aligned for any address family.
  ///
  /// The corresponding C type is `SOCKADDR_STORAGE`.
  public typealias SockAddrStorage = SOCKADDR_STORAGE

  /// The value of the linger-on-close socket option, whose fields are
  /// 16 bits on Windows.
  ///
  /// The corresponding C type is `LINGER`.
  public typealias Linger = LINGER

  /// I/O vector structure for scatter/gather I/O: Winsock's, whose length
  /// comes first and is a `ULONG`.
  ///
  /// The corresponding C type is `WSABUF`.
  public typealias IOVec = WSABUF

  /// Message header structure for `WSASendMsg` and `WSARecvMsg`, Winsock's
  /// `sendmsg` and `recvmsg`.
  ///
  /// The corresponding C type is `WSAMSG`.
  public typealias MsgHdr = WSAMSG

  /// Control message header structure, whose length is a `SIZE_T`.
  ///
  /// The corresponding C type is `WSACMSGHDR`.
  public typealias CMsgHdr = WSACMSGHDR
}

#endif // os(Windows)
