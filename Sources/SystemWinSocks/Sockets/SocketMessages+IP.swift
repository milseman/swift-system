/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// SystemSockets' IP control messages (SocketMessages+IP.swift), with
// Winsock's layouts and types.

// MARK: - Packet Information

@available(System 199, *)
extension SocketDescriptor {
  /// Where a received IPv4 datagram was going,
  /// from the ancillary message that
  /// ``setReceivesIPv4PacketInfo(_:)`` asks for.
  ///
  /// Winsock's structure has no local address, which POSIX's
  /// `ipi_spec_dst` holds, so there's no `localAddress`.
  ///
  /// The corresponding C type is `IN_PKTINFO`.
  @frozen
  public struct IPv4PacketInfo: Hashable, Sendable {
    /// The destination address in the datagram's IP header.
    ///
    /// The corresponding C field is `ipi_addr`.
    public var destination: IPv4Address.Host

    /// The index of the interface the datagram arrived on.
    ///
    /// The corresponding C field is `ipi_ifindex`.
    public var interfaceIndex: UInt32

    /// Creates packet information from its fields.
    @_alwaysEmitIntoClient
    public init(destination: IPv4Address.Host, interfaceIndex: UInt32) {
      self.destination = destination
      self.interfaceIndex = interfaceIndex
    }
  }

  /// Where a received IPv6 datagram was going,
  /// from the ancillary message that
  /// ``setReceivesIPv6PacketInfo(_:)`` asks for.
  ///
  /// The corresponding C type is `IN6_PKTINFO`.
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

// MARK: - Explicit Congestion Notification

@available(System 199, *)
extension SocketDescriptor {
  /// An explicit congestion notification (ECN) codepoint:
  /// the low 2 bits of an IPv4 datagram's type-of-service byte,
  /// or of an IPv6 datagram's traffic class.
  ///
  /// A received datagram's codepoint is in the ancillary message
  /// that ``setReceivesTypeOfService(_:)`` or
  /// ``setReceivesTrafficClass(_:)`` asks for:
  ///
  ///     typealias ECN = SocketDescriptor.ExplicitCongestionNotification
  ///     if let byte = message.typeOfService,
  ///        ECN(typeOfService: byte) == .congestionExperienced {
  ///       // Slow down.
  ///     }
  ///
  /// The values are RFC 3168's, which every platform's C constants have.
  @frozen
  public struct ExplicitCongestionNotification: RawRepresentable, Hashable, Sendable {
    /// The codepoint, from 0 through 3.
    @_alwaysEmitIntoClient
    public var rawValue: UInt8

    /// Creates a codepoint from its value, from 0 through 3.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Reads the codepoint from a type-of-service byte or a traffic class.
    @_alwaysEmitIntoClient
    public init(typeOfService: UInt8) { self.rawValue = typeOfService & 0b11 }

    /// The transport isn't ECN-capable (Not-ECT).
    @_alwaysEmitIntoClient
    public static var notCapableTransport: Self { Self(rawValue: 0b00) }

    /// The transport is ECN-capable, with the ECT(1) codepoint.
    @_alwaysEmitIntoClient
    public static var capableTransport1: Self { Self(rawValue: 0b01) }

    /// The transport is ECN-capable, with the ECT(0) codepoint.
    @_alwaysEmitIntoClient
    public static var capableTransport0: Self { Self(rawValue: 0b10) }

    /// A router on the path experienced congestion (CE).
    @_alwaysEmitIntoClient
    public static var congestionExperienced: Self { Self(rawValue: 0b11) }
  }
}

// MARK: - Decoding Received Messages

/// The IP-level messages that System reads, by their levels, types, and
/// payloads, which are read by Winsock's layouts.
@available(System 199, *)
internal enum _IPControlMessage {
  static var ipLevel: CInt { SocketDescriptor.OptionLevel.ip.rawValue }
  static var ipv6Level: CInt { SocketDescriptor.OptionLevel.ipv6.rawValue }

  // The message's type is the option's, IP_RECVTOS, or IP_TOS's, as Linux
  // sends it; a Windows run tells which (SocketMessagesTests).
  static func typeOfService(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> UInt8? {
    guard level == ipLevel,
      type == SocketDescriptor.IPOption.receiveTypeOfService.rawValue
        || type == SocketDescriptor.IPOption.typeOfService.rawValue
    else { return nil }
    // An int, though some systems send a byte.
    if payload.count == MemoryLayout<CInt>.size {
      return UInt8(truncatingIfNeeded: payload.loadUnaligned(as: CInt.self))
    }
    return payload.first
  }

  // The same for IPV6_RECVTCLASS and IPV6_TCLASS.
  static func trafficClass(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> UInt8? {
    guard level == ipv6Level,
      type == SocketDescriptor.IPv6Option.trafficClass.rawValue
        || type == SocketDescriptor.IPv6Option.receiveTrafficClass.rawValue,
      payload.count >= MemoryLayout<CInt>.size
    else { return nil }
    return UInt8(truncatingIfNeeded: payload.loadUnaligned(as: CInt.self))
  }

  // typedef struct in_pktinfo { IN_ADDR ipi_addr; ULONG ipi_ifindex; }
  // IN_PKTINFO: 8 bytes, where Linux's is 12.
  static func ipv4PacketInfo(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> SocketDescriptor.IPv4PacketInfo? {
    guard level == ipLevel, type == SocketDescriptor.IPOption.packetInfo.rawValue,
      payload.count >= 8
    else { return nil }
    return SocketDescriptor.IPv4PacketInfo(
      destination: IPv4Address.Host(bytes: payload[0 ..< 4])!,
      interfaceIndex: payload.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
  }

  // typedef struct in6_pktinfo { IN6_ADDR ipi6_addr; ULONG ipi6_ifindex; }
  // IN6_PKTINFO: POSIX's layout.
  static func ipv6PacketInfo(
    _ level: CInt, _ type: CInt, _ payload: UnsafeRawBufferPointer
  ) -> SocketDescriptor.IPv6PacketInfo? {
    guard level == ipv6Level, type == SocketDescriptor.IPv6Option.packetInfo.rawValue,
      payload.count >= 20
    else { return nil }
    return SocketDescriptor.IPv6PacketInfo(
      destination: IPv6Address.Host(bytes: payload[0 ..< 16])!,
      interfaceIndex: payload.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
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
  /// The corresponding C constant is `IP_RECVTOS`, or `IP_TOS`,
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
  /// The corresponding C constant is `IPV6_TCLASS`, or `IPV6_RECVTCLASS`,
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
}

@available(System 199, *)
extension SocketDescriptor.UnsafeAncillaryMessages.Message {
  /// The type-of-service byte of the IPv4 datagram that the message came
  /// with, or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IP_RECVTOS`, or `IP_TOS`,
  /// at the `IPPROTO_IP` level.
  public var typeOfService: UInt8? {
    _IPControlMessage.typeOfService(level.rawValue, type.rawValue, payload)
  }

  /// The traffic class of the IPv6 datagram that the message came with,
  /// or `nil` if it's another kind of message.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`, or `IPV6_RECVTCLASS`,
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
}

// MARK: - Messages to Send

@available(System 199, *)
extension SocketDescriptor.AncillaryMessageBuffer {
  /// Appends a message that sets the type-of-service byte
  /// of the IPv4 datagram it's sent with,
  /// such as its explicit congestion notification (ECN) bits.
  ///
  /// Whether `WSASendMsg` honors it depends on the Windows version; Windows'
  /// own message for a datagram's ECN bits is `IP_ECN`.
  ///
  /// The corresponding C constant is `IP_TOS`, at the `IPPROTO_IP` level.
  public mutating func appendTypeOfService(_ typeOfService: UInt8) {
    var value = CInt(typeOfService)
    Swift.withUnsafeBytes(of: &value) { bytes in
      appendMessage(level: .ip, type: .init(rawValue: SocketDescriptor.IPOption.typeOfService.rawValue),
                    bytes: bytes)
    }
  }

  /// Appends a message that sets the traffic class
  /// of the IPv6 datagram it's sent with,
  /// such as its explicit congestion notification (ECN) bits.
  ///
  /// Whether `WSASendMsg` honors it depends on the Windows version; Windows'
  /// own message for a datagram's ECN bits is `IPV6_ECN`.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`, at the `IPPROTO_IPV6` level.
  public mutating func appendTrafficClass(_ trafficClass: UInt8) {
    var value = CInt(trafficClass)
    Swift.withUnsafeBytes(of: &value) { bytes in
      appendMessage(level: .ipv6, type: .init(rawValue: SocketDescriptor.IPv6Option.trafficClass.rawValue),
                    bytes: bytes)
    }
  }
}

#endif // os(Windows)
