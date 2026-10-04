/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Linux's UDP-level options: segmentation and receive offload, UDP_SEGMENT
// and UDP_GRO. They're in <netinet/udp.h>, which glibc's and Bionic's Swift
// modules don't include, so they're the kernel's numbers, which are the same
// on every architecture; shims.c checks them against the header.

import SystemPackage

#if os(Linux) || os(Android)

@available(System 199, *)
extension SocketDescriptor {
  /// UDP-level options, at the ``OptionLevel/udp`` level,
  /// for use with `getOption` and `setOption`,
  /// or ``getUDPOption(_:)`` and ``setUDPOption(_:to:)``.
  ///
  /// - Note: Only available on Linux and Android.
  @frozen
  public struct UDPOption: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The size of the datagrams that the kernel splits each datagram
    /// the socket sends into, which is segmentation offload,
    /// or 0 to send each as it is.
    ///
    /// A message's own ancillary message of this type sets the size
    /// for that message. Linux 4.18 added it; an older kernel throws
    /// ``Errno/protocolNotAvailable``.
    ///
    /// The corresponding C constant is `UDP_SEGMENT`.
    @_alwaysEmitIntoClient
    public static var segmentSize: UDPOption { UDPOption(rawValue: 103) }

    /// Whether the kernel coalesces the datagrams that the socket receives
    /// from one flow into larger ones, which is receive offload.
    ///
    /// A coalesced datagram comes with an ancillary message of this type,
    /// whose value is the size of the datagrams it joined.
    /// Linux 5.0 added it; an older kernel throws
    /// ``Errno/protocolNotAvailable``.
    ///
    /// The corresponding C constant is `UDP_GRO`.
    @_alwaysEmitIntoClient
    public static var receiveOffload: UDPOption { UDPOption(rawValue: 104) }
  }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Gets a UDP-level option whose value is an integer.
  ///
  /// The corresponding C function is `getsockopt`, at the `IPPROTO_UDP` level.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func getUDPOption(_ option: UDPOption) throws(Errno) -> CInt {
    try _value(OptionLevel.udp.rawValue, option.rawValue, CInt(0)).get()
  }

  /// Sets a UDP-level option whose value is an integer.
  ///
  /// The corresponding C function is `setsockopt`, at the `IPPROTO_UDP` level.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func setUDPOption(_ option: UDPOption, to value: CInt) throws(Errno) {
    try _setValue(OptionLevel.udp.rawValue, option.rawValue, value).get()
  }
}

#endif // os(Linux) || os(Android)
