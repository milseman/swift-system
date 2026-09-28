/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import SystemPackage

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

// MARK: - Packet Information

@available(System 199, *)
extension SocketDescriptor {
  /// Where a received IPv4 datagram was going,
  /// from the ancillary message that
  /// ``setReceivesIPv4PacketInfo(_:)`` asks for.
  ///
  /// The corresponding C type is `struct in_pktinfo`.
  @frozen
  public struct IPv4PacketInfo: Hashable, Sendable {
    /// The destination address in the datagram's IP header.
    ///
    /// The corresponding C field is `ipi_addr`.
    public var destination: IPv4Address.Host

    /// The local address of the datagram: the one a reply would come from.
    ///
    /// The corresponding C field is `ipi_spec_dst`.
    public var localAddress: IPv4Address.Host

    /// The index of the interface the datagram arrived on.
    ///
    /// The corresponding C field is `ipi_ifindex`.
    public var interfaceIndex: UInt32

    /// Creates packet information from its fields.
    @_alwaysEmitIntoClient
    public init(
      destination: IPv4Address.Host, localAddress: IPv4Address.Host, interfaceIndex: UInt32
    ) {
      self.destination = destination
      self.localAddress = localAddress
      self.interfaceIndex = interfaceIndex
    }
  }

  /// Where a received IPv6 datagram was going,
  /// from the ancillary message that
  /// ``setReceivesIPv6PacketInfo(_:)`` asks for.
  ///
  /// The corresponding C type is `struct in6_pktinfo`.
  @frozen
  public struct IPv6PacketInfo: Hashable, Sendable {
    /// The destination address in the datagram's IPv6 header.
    ///
    /// The corresponding C field is `ipi6_addr`.
    public var destination: IPv6Address.Host

    /// The index of the interface the datagram arrived on.
    ///
    /// The corresponding C field is `ipi6_ifindex`.
    public var interfaceIndex: UInt32

    /// Creates packet information from its fields.
    @_alwaysEmitIntoClient
    public init(destination: IPv6Address.Host, interfaceIndex: UInt32) {
      self.destination = destination
      self.interfaceIndex = interfaceIndex
    }
  }
}

// MARK: - Decoding Received Messages

/// The IP-level messages that System reads, by their levels, types, and
/// payloads. Their payloads are C structures that glibc declares only with
/// _GNU_SOURCE, such as in6_pktinfo, so they're read by their layouts,
/// which are the same on every platform.
@available(System 199, *)
internal enum _IPControlMessage {
  // Linux sends the received type of service as IP_TOS; Darwin as IP_RECVTOS.
  static var typeOfServiceType: CInt {
    #if SYSTEM_PACKAGE_DARWIN
    IP_RECVTOS
    #else
    IP_TOS
    #endif
  }

  static func typeOfService(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> UInt8? {
    guard level == CInt(IPPROTO_IP), type == typeOfServiceType else { return nil }
    // A byte, though some systems send an int.
    if payload.count == MemoryLayout<CInt>.size {
      return UInt8(truncatingIfNeeded: payload.loadUnaligned(as: CInt.self))
    }
    return payload.first
  }

  static func trafficClass(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> UInt8? {
    guard level == CInt(IPPROTO_IPV6), type == IPV6_TCLASS,
      payload.count >= MemoryLayout<CInt>.size
    else { return nil }
    return UInt8(truncatingIfNeeded: payload.loadUnaligned(as: CInt.self))
  }

  // struct in_pktinfo { unsigned int ipi_ifindex; struct in_addr ipi_spec_dst;
  //                     struct in_addr ipi_addr; }
  static func ipv4PacketInfo(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> SocketDescriptor.IPv4PacketInfo? {
    guard level == CInt(IPPROTO_IP), type == IP_PKTINFO, payload.count >= 12 else { return nil }
    return SocketDescriptor.IPv4PacketInfo(
      destination: IPv4Address.Host(bytes: payload[8 ..< 12])!,
      localAddress: IPv4Address.Host(bytes: payload[4 ..< 8])!,
      interfaceIndex: payload.loadUnaligned(fromByteOffset: 0, as: UInt32.self))
  }

  // struct in6_pktinfo { struct in6_addr ipi6_addr; unsigned int ipi6_ifindex; }
  static func ipv6PacketInfo(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> SocketDescriptor.IPv6PacketInfo? {
    guard level == CInt(IPPROTO_IPV6),
      type == SocketDescriptor.IPv6Option.packetInfo.rawValue,
      payload.count >= 20
    else { return nil }
    return SocketDescriptor.IPv6PacketInfo(
      destination: IPv6Address.Host(bytes: payload[0 ..< 16])!,
      interfaceIndex: payload.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  static func timestamp(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> Duration? {
    guard level == SOL_SOCKET, type == SCM_TIMESTAMP,
      payload.count >= MemoryLayout<timeval>.size
    else { return nil }
    let time = payload.loadUnaligned(as: timeval.self)
    return .seconds(Int64(time.tv_sec)) + .microseconds(Int64(time.tv_usec))
  }
}

@available(System 199, *)
extension SocketDescriptor.AncillaryMessageBuffer.Message {
  /// The type-of-service byte of the IPv4 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// ``SocketDescriptor/setReceivesTypeOfService(_:)`` asks for these.
  /// The low 2 bits are the explicit congestion notification (ECN) field.
  ///
  /// The corresponding C constant is `IP_RECVTOS`, or on Linux `IP_TOS`,
  /// at the `IPPROTO_IP` level.
  public var typeOfService: UInt8? {
    withUnsafeBytes { _IPControlMessage.typeOfService(level.rawValue, type.rawValue, $0) }
  }

  /// The traffic class of the IPv6 datagram that the message came with,
  /// or `nil` if it's another kind of message.
  ///
  /// ``SocketDescriptor/setReceivesTrafficClass(_:)`` asks for these.
  /// The low 2 bits are the explicit congestion notification (ECN) field.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`,
  /// at the `IPPROTO_IPV6` level.
  public var trafficClass: UInt8? {
    withUnsafeBytes { _IPControlMessage.trafficClass(level.rawValue, type.rawValue, $0) }
  }

  /// The packet information of the IPv4 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// ``SocketDescriptor/setReceivesIPv4PacketInfo(_:)`` asks for these.
  ///
  /// The corresponding C constant is `IP_PKTINFO`,
  /// at the `IPPROTO_IP` level.
  public var ipv4PacketInfo: SocketDescriptor.IPv4PacketInfo? {
    withUnsafeBytes { _IPControlMessage.ipv4PacketInfo(level.rawValue, type.rawValue, $0) }
  }

  /// The packet information of the IPv6 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// ``SocketDescriptor/setReceivesIPv6PacketInfo(_:)`` asks for these.
  ///
  /// The corresponding C constant is `IPV6_PKTINFO`,
  /// at the `IPPROTO_IPV6` level.
  public var ipv6PacketInfo: SocketDescriptor.IPv6PacketInfo? {
    withUnsafeBytes { _IPControlMessage.ipv6PacketInfo(level.rawValue, type.rawValue, $0) }
  }

  /// The time that the datagram the message came with arrived,
  /// since the start of 1970 in UTC,
  /// or `nil` if it's another kind of message.
  ///
  /// ``SocketDescriptor/setReceivesTimestamps(_:)`` asks for these.
  ///
  /// The corresponding C constant is `SCM_TIMESTAMP`,
  /// at the `SOL_SOCKET` level.
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  public var timestamp: Duration? {
    withUnsafeBytes { _IPControlMessage.timestamp(level.rawValue, type.rawValue, $0) }
  }
}

@available(System 199, *)
extension SocketDescriptor.UnsafeAncillaryMessages.Message {
  /// The type-of-service byte of the IPv4 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IP_RECVTOS`, or on Linux `IP_TOS`,
  /// at the `IPPROTO_IP` level.
  public var typeOfService: UInt8? {
    _IPControlMessage.typeOfService(level.rawValue, type.rawValue, payload)
  }

  /// The traffic class of the IPv6 datagram that the message came with,
  /// or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`,
  /// at the `IPPROTO_IPV6` level.
  public var trafficClass: UInt8? {
    _IPControlMessage.trafficClass(level.rawValue, type.rawValue, payload)
  }

  /// The packet information of the IPv4 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IP_PKTINFO`,
  /// at the `IPPROTO_IP` level.
  public var ipv4PacketInfo: SocketDescriptor.IPv4PacketInfo? {
    _IPControlMessage.ipv4PacketInfo(level.rawValue, type.rawValue, payload)
  }

  /// The packet information of the IPv6 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IPV6_PKTINFO`,
  /// at the `IPPROTO_IPV6` level.
  public var ipv6PacketInfo: SocketDescriptor.IPv6PacketInfo? {
    _IPControlMessage.ipv6PacketInfo(level.rawValue, type.rawValue, payload)
  }

  /// The time that the datagram the message came with arrived,
  /// since the start of 1970 in UTC,
  /// or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `SCM_TIMESTAMP`,
  /// at the `SOL_SOCKET` level.
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  public var timestamp: Duration? {
    _IPControlMessage.timestamp(level.rawValue, type.rawValue, payload)
  }
}

// MARK: - Messages to Send

@available(System 199, *)
extension SocketDescriptor.AncillaryMessageBuffer {
  /// Appends a message that sets the type-of-service byte
  /// of the IPv4 datagram it's sent with,
  /// such as its explicit congestion notification (ECN) bits.
  ///
  /// The corresponding C constant is `IP_TOS`, at the `IPPROTO_IP` level.
  public mutating func appendTypeOfService(_ typeOfService: UInt8) {
    var value = CInt(typeOfService)
    Swift.withUnsafeBytes(of: &value) { bytes in
      appendMessage(level: .ip, type: .init(rawValue: IP_TOS), bytes: bytes)
    }
  }

  /// Appends a message that sets the traffic class
  /// of the IPv6 datagram it's sent with,
  /// such as its explicit congestion notification (ECN) bits.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`, at the `IPPROTO_IPV6` level.
  public mutating func appendTrafficClass(_ trafficClass: UInt8) {
    var value = CInt(trafficClass)
    Swift.withUnsafeBytes(of: &value) { bytes in
      appendMessage(level: .ipv6, type: .init(rawValue: IPV6_TCLASS), bytes: bytes)
    }
  }
}
