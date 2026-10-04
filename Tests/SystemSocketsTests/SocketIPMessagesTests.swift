/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

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

import SystemPackage
import SystemSockets

private typealias AncillaryMessageBuffer = SocketDescriptor.AncillaryMessageBuffer

private let loopbackIndex: UInt32 = {
  #if SYSTEM_PACKAGE_DARWIN
  if_nametoindex("lo0")
  #else
  if_nametoindex("lo")
  #endif
}()

@Suite("IP ancillary messages")
private struct SocketIPMessagesTests {
  @available(System 199, *)
  @Test func decodesReceivedMessages() throws {
    #if SYSTEM_PACKAGE_DARWIN
    let typeOfServiceType = IP_RECVTOS
    #else
    let typeOfServiceType = IP_TOS
    #endif
    var messages = AncillaryMessageBuffer()
    [UInt8(0x03)].withUnsafeBytes {
      messages.appendMessage(level: .ip, type: .init(rawValue: typeOfServiceType), bytes: $0)
    }
    var trafficClass = CInt(0x2A)
    withUnsafeBytes(of: &trafficClass) {
      messages.appendMessage(level: .ipv6, type: .init(rawValue: IPV6_TCLASS), bytes: $0)
    }
    // in_pktinfo: the interface index, the local address, then the destination.
    let info4: [UInt8] = withUnsafeBytes(of: UInt32(7)) { Array($0) } + [127, 0, 0, 2] + [224, 0, 0, 251]
    info4.withUnsafeBytes {
      messages.appendMessage(level: .ip, type: .init(rawValue: IP_PKTINFO), bytes: $0)
    }
    // in6_pktinfo: the destination, then the interface index.
    let group = try #require(IPv6Address.Host("ff02::fb"))
    let info6 = group.withUnsafeBytes { Array($0) } + withUnsafeBytes(of: UInt32(9)) { Array($0) }
    info6.withUnsafeBytes {
      messages.appendMessage(
        level: .ipv6, type: .init(rawValue: SocketDescriptor.IPv6Option.packetInfo.rawValue),
        bytes: $0)
    }
    messages.appendFileDescriptors([])

    let all = Array(messages)
    #expect(all.count == 5)
    #expect(all.compactMap(\.typeOfService) == [0x03])
    #expect(all.compactMap(\.trafficClass) == [0x2A])
    #expect(all.compactMap(\.ipv4PacketInfo) == [
      SocketDescriptor.IPv4PacketInfo(
        destination: IPv4Address.Host(224, 0, 0, 251),
        localAddress: IPv4Address.Host(127, 0, 0, 2), interfaceIndex: 7),
    ])
    #expect(all.compactMap(\.ipv6PacketInfo) == [
      SocketDescriptor.IPv6PacketInfo(destination: group, interfaceIndex: 9)
    ])

    // The same messages, read where they are.
    messages.withUnsafeBytes { bytes in
      let unsafe = Array(SocketDescriptor.UnsafeAncillaryMessages(bytes))
      #expect(unsafe.compactMap(\.typeOfService) == [0x03])
      #expect(unsafe.compactMap(\.trafficClass) == [0x2A])
      #expect(unsafe.compactMap(\.ipv4PacketInfo).map(\.interfaceIndex) == [7])
      #expect(unsafe.compactMap(\.ipv6PacketInfo).map(\.destination) == [group])
    }
  }

  @available(System 199, *)
  @Test func appendsMessagesToSend() {
    var messages = AncillaryMessageBuffer()
    messages.appendTypeOfService(0x01)
    messages.appendTrafficClass(0x02)
    let all = Array(messages)
    #expect(all.map(\.level) == [.ip, .ipv6])
    #expect(all.map(\.type.rawValue) == [IP_TOS, IPV6_TCLASS])
    #expect(all.map { $0.withUnsafeBytes { $0.loadUnaligned(as: CInt.self) } } == [1, 2])
  }

  @available(System 199, *)
  @Test func explicitCongestionNotificationCodepoints() {
    typealias ECN = SocketDescriptor.ExplicitCongestionNotification
    #expect([ECN.notCapableTransport, .capableTransport1, .capableTransport0, .congestionExperienced]
      .map(\.rawValue) == [0, 1, 2, 3])
    #if SYSTEM_PACKAGE_DARWIN
    #expect(ECN.notCapableTransport.rawValue == UInt8(IPTOS_ECN_NOTECT))
    #expect(ECN.capableTransport1.rawValue == UInt8(IPTOS_ECN_ECT1))
    #expect(ECN.capableTransport0.rawValue == UInt8(IPTOS_ECN_ECT0))
    #expect(ECN.congestionExperienced.rawValue == UInt8(IPTOS_ECN_CE))
    #expect(IPTOS_ECN_MASK == 0b11)
    #endif
    // The codepoint is the low 2 bits; the differentiated services field
    // is the rest.
    #expect(ECN(typeOfService: 0xb8 | 0b11) == .congestionExperienced)
    #expect(ECN(typeOfService: 0xb8) == .notCapableTransport)
    #expect(ECN(typeOfService: 0x02) == .capableTransport0)
  }

  /// Receives one datagram and its ancillary messages.
  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func receive(
    from socket: SocketDescriptor
  ) throws -> (bytes: [UInt8], messages: AncillaryMessageBuffer) {
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { storage.deallocate() }
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    var messages = AncillaryMessageBuffer(minimumCapacity: 512)
    let result = try socket.receiveMessage(into: &buffer, ancillaryMessages: &messages)
    #expect(!result.flags.contains(.controlTruncated))
    return (Array(storage.prefix(result.byteCount)), messages)
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test(.requiresSocketBinding) func receivesIPv4DatagramInformation() throws {
    let receiver = try SocketDescriptor.open(.ipv4, .datagram, options: .closeOnExec)
    defer { try? receiver.close() }
    try receiver.bind(to: SocketAddress(ipv4: IPv4Address(host: .loopback, port: 0)))
    var address = SocketAddress()
    try receiver.getLocalAddress(into: &address)
    try receiver.setReceivesTypeOfService(true)
    try receiver.setReceivesIPv4PacketInfo(true)
    try receiver.setReceivesTimestamps(true)

    let sender = try SocketDescriptor.open(.ipv4, .datagram, options: .closeOnExec)
    defer { try? sender.close() }
    // The type of service from the socket's option.
    try sender.setTypeOfService(0x02)
    let sent = time(nil)
    _ = try [UInt8(1)].withUnsafeBytes { try sender.send($0, to: address) }
    let first = try receive(from: receiver)
    let received = time(nil)
    #expect(first.bytes == [1])
    #expect(first.messages.compactMap(\.typeOfService) == [0x02])
    let info = try #require(first.messages.compactMap(\.ipv4PacketInfo).first)
    #expect(info.destination == .loopback)
    #expect(info.interfaceIndex == loopbackIndex)
    // It arrived between the clock readings around sending and receiving it.
    let arrival = try #require(first.messages.compactMap(\.timestamp).first)
    #expect(arrival >= .seconds(sent) && arrival < .seconds(received + 1))

    // The type of service from an ancillary message.
    var outgoing = AncillaryMessageBuffer()
    outgoing.appendTypeOfService(0x01)
    _ = try [UInt8(2)].withUnsafeBytes {
      try sender.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: outgoing, to: address)
    }
    let second = try receive(from: receiver)
    #expect(second.bytes == [2])
    #expect(second.messages.compactMap(\.typeOfService) == [0x01])
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test(.requiresSocketBinding) func receivesIPv6DatagramInformation() throws {
    let receiver = try SocketDescriptor.open(.ipv6, .datagram, options: .closeOnExec)
    defer { try? receiver.close() }
    try receiver.bind(to: SocketAddress(ipv6: IPv6Address(host: .loopback, port: 0)))
    var address = SocketAddress()
    try receiver.getLocalAddress(into: &address)
    try receiver.setReceivesTrafficClass(true)
    try receiver.setReceivesIPv6PacketInfo(true)

    let sender = try SocketDescriptor.open(.ipv6, .datagram, options: .closeOnExec)
    defer { try? sender.close() }
    try sender.setTrafficClass(0x02)
    _ = try [UInt8(1)].withUnsafeBytes { try sender.send($0, to: address) }
    let first = try receive(from: receiver)
    #expect(first.bytes == [1])
    #expect(first.messages.compactMap(\.trafficClass) == [0x02])
    // On Darwin, this checks RFC 3542's IPV6_PKTINFO, which System spells out.
    let info = try #require(first.messages.compactMap(\.ipv6PacketInfo).first)
    #expect(info.destination == .loopback)
    #expect(info.interfaceIndex == loopbackIndex)

    var outgoing = AncillaryMessageBuffer()
    outgoing.appendTrafficClass(0x01)
    _ = try [UInt8(2)].withUnsafeBytes {
      try sender.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: outgoing, to: address)
    }
    let second = try receive(from: receiver)
    #expect(second.messages.compactMap(\.trafficClass) == [0x01])
  }
}

#endif // !os(Windows) && !os(WASI)
