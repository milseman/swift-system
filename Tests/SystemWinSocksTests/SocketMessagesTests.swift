/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import Testing
import WinSDK

@testable import SystemWinSocks
import SystemPackage

private typealias AncillaryMessageBuffer = SocketDescriptor.AncillaryMessageBuffer

// WSASendMsg and WSARecvMsg over loopback datagram sockets of the test's
// own, bound to 127.0.0.1 or ::1 and ports the system picks.
@Suite("Socket Messages (Winsock)")
private struct SocketMessagesTests {
  @available(System 199, *)
  @Test func extensionFunctionsAreFound() throws {
    #expect(_SIO_GET_EXTENSION_FUNCTION_POINTER
      == DWORD(WinSDK.IOC_INOUT) | DWORD(WinSDK.IOC_WS2) | 6)
    _ = try _winsockMessageFunctions.get()
  }

  // Winsock's layout on 64-bit Windows: a 16-byte header, 8-byte alignment.
  @available(System 199, *)
  @Test func layout() {
    #expect(MemoryLayout<CInterop.CMsgHdr>.size == 16)
    #expect(AncillaryMessageBuffer.length(forPayloadSize: 4) == 20)
    #expect(AncillaryMessageBuffer.space(forPayloadSize: 4) == 24)
    #expect(AncillaryMessageBuffer.space(forPayloadSize: 8) == 24)

    var buffer = AncillaryMessageBuffer()
    buffer.appendTypeOfService(0b10)
    buffer.appendTrafficClass(0b11)
    #expect(buffer.byteCount == 2 * AncillaryMessageBuffer.space(forPayloadSize: 4))
    let messages = Array(buffer)
    #expect(messages.count == 2)
    #expect(messages[0].level == .ip && messages[0].typeOfService == 0b10)
    #expect(messages[1].level == .ipv6 && messages[1].trafficClass == 0b11)
    buffer.withUnsafeBytes { bytes in
      let unsafe = SocketDescriptor.UnsafeAncillaryMessages(bytes)
      #expect(unsafe.count == 2)
      #expect(unsafe.first?.typeOfService == 0b10)
    }
  }

  /// Two UDP sockets on loopback, and the second's address.
  @available(System 199, *)
  private static func datagramPair(
    ipv6: Bool = false
  ) throws(Win32.Error) -> (SocketDescriptor, SocketDescriptor, SocketAddress, SocketAddress) {
    let loopback = ipv6
      ? SocketAddress(ipv6: .loopback(port: 0)) : SocketAddress(ipv4: .loopback(port: 0))
    let first = try SocketDescriptor.open(ipv6 ? .ipv6 : .ipv4, .datagram)
    var succeeded = false
    defer { if !succeeded { try? first.close() } }
    let second = try SocketDescriptor.open(ipv6 ? .ipv6 : .ipv4, .datagram)
    defer { if !succeeded { try? second.close() } }
    try first.bind(to: loopback)
    try second.bind(to: loopback)
    var firstAddress = SocketAddress()
    try first.getLocalAddress(into: &firstAddress)
    var secondAddress = SocketAddress()
    try second.getLocalAddress(into: &secondAddress)
    try second.setReceiveTimeout(.seconds(5))
    succeeded = true
    return (first, second, firstAddress, secondAddress)
  }

  @available(System 199, *)
  @Test func sendAndReceiveMessages() throws {
    let (first, second, firstAddress, secondAddress) = try Self.datagramPair()
    defer {
      try? first.close()
      try? second.close()
    }
    let message = Array("via WSASendMsg".utf8)
    let sent = try message.withUnsafeBytes { bytes throws(Win32.Error) in
      try first.sendMessage(RawSpan(_unsafeBytes: bytes), to: secondAddress)
    }
    #expect(sent == message.count)

    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { storage.deallocate() }
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    var ancillary = AncillaryMessageBuffer(minimumCapacity: 64)
    var sender = SocketAddress()
    let received = try second.receiveMessage(
      into: &buffer, ancillaryMessages: &ancillary, sender: &sender)
    #expect(received.byteCount == message.count)
    #expect(buffer.byteCount == message.count)
    #expect(Array(storage.prefix(received.byteCount)) == message)
    #expect(received.flags.isEmpty)
    #expect(sender == firstAddress)
    #expect(ancillary.isEmpty)
  }

  // A header of the caller's: data gathered from two buffers, and scattered
  // into two.
  @available(System 199, *)
  @Test func scatterAndGather() throws {
    let (first, second, _, secondAddress) = try Self.datagramPair()
    defer {
      try? first.close()
      try? second.close()
    }
    var head: [UInt8] = [1, 2]
    var tail: [UInt8] = [3, 4, 5]
    let sent = try head.withUnsafeMutableBytes { head throws in
      try tail.withUnsafeMutableBytes { tail throws in
        var vectors = [CInterop.IOVec(head), CInterop.IOVec(tail)]
        return try vectors.withUnsafeMutableBufferPointer { vectors throws in
          try secondAddress.withUnsafePointer { name, nameLength throws in
            let header = CInterop.MsgHdr(
              name: UnsafeMutableRawPointer(mutating: name), nameLength: Int(nameLength),
              vectors: vectors.baseAddress, vectorCount: vectors.count)
            return try first.sendMessage(header)
          }
        }
      }
    }
    #expect(sent == 5)

    var front = [UInt8](repeating: 0, count: 2)
    var back = [UInt8](repeating: 0, count: 8)
    let count = try front.withUnsafeMutableBytes { front throws in
      try back.withUnsafeMutableBytes { back throws in
        var vectors = [CInterop.IOVec(front), CInterop.IOVec(back)]
        return try vectors.withUnsafeMutableBufferPointer { vectors throws in
          var header = CInterop.MsgHdr(vectors: vectors.baseAddress, vectorCount: vectors.count)
          let count = try second.receiveMessage(&header)
          #expect(header.flags.isEmpty)
          return count
        }
      }
    }
    #expect(count == 5)
    #expect(front == [1, 2] && back.prefix(3) == [3, 4, 5])
  }

  @available(System 199, *)
  @Test func ipv4PacketInfo() throws {
    let (first, second, _, secondAddress) = try Self.datagramPair()
    defer {
      try? first.close()
      try? second.close()
    }
    try second.setReceivesIPv4PacketInfo(true)
    _ = try [UInt8(1)].withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    let (_, ancillary) = try Self.receive(from: second)
    let info = try #require(ancillary.lazy.compactMap(\.ipv4PacketInfo).first)
    #expect(info.destination == .loopback)
    #expect(info.interfaceIndex != 0)
  }

  @available(System 199, *)
  @Test func ipv6PacketInfo() throws {
    let (first, second, _, secondAddress) = try Self.datagramPair(ipv6: true)
    defer {
      try? first.close()
      try? second.close()
    }
    try second.setReceivesIPv6PacketInfo(true)
    _ = try [UInt8(1)].withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    let (_, ancillary) = try Self.receive(from: second)
    let info = try #require(ancillary.lazy.compactMap(\.ipv6PacketInfo).first)
    #expect(info.destination == .loopback)
  }

  // Windows 10 version 1903 and later report a datagram's type of service;
  // this checks which message type Winsock sends it as (System reads both
  // IP_RECVTOS and IP_TOS).
  @available(System 199, *)
  @Test func typeOfService() throws {
    let (first, second, _, secondAddress) = try Self.datagramPair()
    defer {
      try? first.close()
      try? second.close()
    }
    try second.setReceivesTypeOfService(true)
    #expect(try second.receivesTypeOfService())
    _ = try [UInt8(1)].withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    let (_, ancillary) = try Self.receive(from: second)
    #expect(ancillary.contains { $0.typeOfService != nil })
  }

  @available(System 199, *)
  @Test func messagesThatDontFitThrow() throws {
    let (first, second, _, secondAddress) = try Self.datagramPair()
    defer {
      try? first.close()
      try? second.close()
    }
    _ = try [UInt8](1...8).withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 1)
    defer { storage.deallocate() }
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    var ancillary = AncillaryMessageBuffer()
    #expect(throws: Win32.Error.messageTooLong) {
      try second.receiveMessage(into: &buffer, ancillaryMessages: &ancillary)
    }
  }

  /// Receives a datagram of up to 64 bytes, with up to 256 bytes of
  /// ancillary messages.
  @available(System 199, *)
  private static func receive(
    from socket: SocketDescriptor
  ) throws(Win32.Error) -> (Int, AncillaryMessageBuffer) {
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { storage.deallocate() }
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    var ancillary = AncillaryMessageBuffer(minimumCapacity: 256)
    let received = try socket.receiveMessage(into: &buffer, ancillaryMessages: &ancillary)
    return (received.byteCount, ancillary)
  }
}

#endif // os(Windows)
