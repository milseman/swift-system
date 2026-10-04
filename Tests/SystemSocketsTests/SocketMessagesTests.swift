/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
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

@testable import SystemSockets
import SystemPackage

private typealias AncillaryMessageBuffer = SocketDescriptor.AncillaryMessageBuffer

// Real-call tests of sendmsg and recvmsg. Descriptor passing uses socket
// pairs, which need neither a file system path nor permission to bind.
// Swift Testing runs these in parallel, so none of them reuses a
// descriptor number after closing it.
@Suite("Socket Message Operations")
private struct SocketMessagesTests {

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test(.requiresSocketBinding) func sendReceiveMessageBasic() throws {
    // Test basic sendMessage/receiveMessage with TCP sockets
    let server = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    defer { try? server.close() }

    try server.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try server.listen(backlog: 1)
    var boundAddr = SocketAddress()
    try server.getLocalAddress(into: &boundAddr)

    let client = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    defer { try? client.close() }
    try client.connect(to: boundAddr)

    let accepted = try server.accept()
    defer { try? accepted.close() }

    // Send message without ancillary data
    let message = "Hello via sendMessage!"
    let sent = try Array(message.utf8).withUnsafeBytes {
      try client.sendMessage(RawSpan(_unsafeBytes: $0))
    }
    #expect(sent == message.utf8.count)

    // A connected stream's messages have no sender address,
    // and no ancillary messages here.
    var ancillary = AncillaryMessageBuffer(minimumCapacity: 256)
    var sender = SocketAddress(ipv4: .loopback(port: 1))
    let (text, received) = try receiveText(from: accepted, ancillary: &ancillary, sender: &sender)
    #expect(text == message)
    #expect(received.flags.isEmpty)
    #expect(sender.isEmpty)
    #expect(ancillary.isEmpty)
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test(.requiresSocketBinding) func sendReceiveMessageUDP() throws {
    // Test sendMessage/receiveMessage with UDP datagram sockets
    let receiver = try SocketDescriptor.open(.ipv4, .datagram, protocol: .udp)
    defer { try? receiver.close() }
    try receiver.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var receiverAddress = SocketAddress()
    try receiver.getLocalAddress(into: &receiverAddress)

    let sender = try SocketDescriptor.open(.ipv4, .datagram, protocol: .udp)
    defer { try? sender.close() }
    try sender.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var senderAddress = SocketAddress()
    try sender.getLocalAddress(into: &senderAddress)

    // Send datagram via sendMessage
    let message = "UDP via sendMessage"
    let sent = try Array(message.utf8).withUnsafeBytes {
      try sender.sendMessage(RawSpan(_unsafeBytes: $0), to: receiverAddress)
    }
    #expect(sent == message.utf8.count)

    // The sender's address is the whole sockaddr_in, port included.
    var ancillary = AncillaryMessageBuffer()
    var from = SocketAddress()
    let (text, received) = try receiveText(from: receiver, ancillary: &ancillary, sender: &from)
    #expect(text == message)
    #expect(received.flags.isEmpty)
    #expect(from == senderAddress)
    #expect(from.length == MemoryLayout<sockaddr_in>.size)
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func passesAFileDescriptor() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }

    var ancillary = AncillaryMessageBuffer()
    ancillary.appendFileDescriptors([pipe.readEnd])
    let sent = try Array("FD attached".utf8).withUnsafeBytes {
      try first.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: ancillary)
    }
    #expect(sent == 11)

    var received = AncillaryMessageBuffer(minimumCapacity: 256)
    let (text, result) = try receiveText(from: second, ancillary: &received)
    #expect(text == "FD attached")
    #expect(result.flags.isEmpty)
    let messages = Array(received)
    #expect(messages.count == 1)
    let descriptors = try #require(messages.first?.fileDescriptors)
    #expect(descriptors.count == 1)
    let passed = try #require(descriptors.first)
    defer { try? passed.close() }

    // The new descriptor is another name for the pipe's read end.
    #expect(passed != pipe.readEnd)
    try pipe.writeEnd.writeAll("through the pipe".utf8)
    #expect(try readText(from: passed) == "through the pipe")
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func passesSeveralFileDescriptorsInOneMessage() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    let pipes = try (0 ..< 3).map { _ in try FileDescriptor.pipe() }
    defer {
      for pipe in pipes {
        try? pipe.readEnd.close()
        try? pipe.writeEnd.close()
      }
    }

    var ancillary = AncillaryMessageBuffer()
    ancillary.appendFileDescriptors(pipes.map(\.readEnd))
    _ = try Array("Three FDs attached".utf8).withUnsafeBytes {
      try first.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: ancillary)
    }

    var received = AncillaryMessageBuffer(
      minimumCapacity: AncillaryMessageBuffer.space(forPayloadSize: 3 * MemoryLayout<CInt>.size))
    let (text, result) = try receiveText(from: second, ancillary: &received)
    #expect(text == "Three FDs attached")
    #expect(result.flags.isEmpty)
    let descriptors = try #require(received.first?.fileDescriptors)
    defer { for descriptor in descriptors { try? descriptor.close() } }
    #expect(descriptors.count == 3)

    // They arrive in the order they were sent.
    for (index, (pipe, passed)) in zip(pipes, descriptors).enumerated() {
      try pipe.writeEnd.writeAll("pipe \(index)".utf8)
      #expect(try readText(from: passed) == "pipe \(index)")
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func reportsAncillaryMessagesThatDidNotFit() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram)
    defer {
      try? first.close()
      try? second.close()
    }
    var ancillary = AncillaryMessageBuffer()
    ancillary.appendFileDescriptors([FileDescriptor.standardInput, .standardOutput])
    for _ in 0 ..< 2 {
      _ = try Array("x".utf8).withUnsafeBytes {
        try first.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: ancillary)
      }
    }

    // A control buffer without room for a header gets no messages, and the
    // flag says so. The system closes the descriptors that didn't arrive.
    // An AncillaryMessageBuffer's capacity is whatever its allocation
    // rounds up to, so this uses a header and a buffer of its own. (With no
    // control buffer at all, Darwin doesn't set the flag.)
    let byte = UnsafeMutableRawBufferPointer.allocate(byteCount: 1, alignment: 1)
    let noRoom = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 8)
    defer {
      byte.deallocate()
      noRoom.deallocate()
    }
    var vector = CInterop.IOVec(iov_base: byte.baseAddress, iov_len: byte.count)
    var header = CInterop.MsgHdr()
    let count = try withUnsafeMutablePointer(to: &vector) { vector in
      header.msg_iov = vector
      header.msg_iovlen = 1
      header.msg_control = noRoom.baseAddress
      header.msg_controllen = .init(noRoom.count)
      return try second.receiveMessage(&header)
    }
    #expect(count == 1)
    #expect(header.msg_flags & CInt(MSG_CTRUNC) != 0)
    #expect(SocketDescriptor.UnsafeAncillaryMessages(header).isEmpty)

    // Receiving replaces a buffer's messages, rather than appending to them.
    var reused = AncillaryMessageBuffer(minimumCapacity: 256)
    reused.appendFileDescriptors([FileDescriptor.standardError])
    let (_, replaced) = try receiveText(from: second, ancillary: &reused)
    #expect(replaced.flags.isEmpty)
    let descriptors = try #require(reused.first?.fileDescriptors)
    defer { for descriptor in descriptors { try? descriptor.close() } }
    #expect(reused.count == 1)
    #expect(descriptors.count == 2)
    #expect(!descriptors.contains(.standardError))
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func reportsATruncatedDatagram() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram)
    defer {
      try? first.close()
      try? second.close()
    }
    _ = try Array("0123456789".utf8).withUnsafeBytes {
      try first.sendMessage(RawSpan(_unsafeBytes: $0))
    }
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 1)
    defer { storage.deallocate() }
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    var ancillary = AncillaryMessageBuffer()
    let result = try second.receiveMessage(into: &buffer, ancillaryMessages: &ancillary)
    #expect(result.byteCount == 4)
    #expect(result.flags == .dataTruncated)
    #expect(buffer.byteCount == 4)
    #expect(Array(storage) == Array("0123".utf8))
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func receivesAfterTheBytesAlreadyInTheBuffer() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    _ = try Array("cde".utf8).withUnsafeBytes { try first.send($0) }

    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { storage.deallocate() }
    storage.copyBytes(from: "ab".utf8)
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 2)
    var ancillary = AncillaryMessageBuffer()
    let result = try second.receiveMessage(into: &buffer, ancillaryMessages: &ancillary)
    #expect(result.byteCount == 3)
    #expect(buffer.byteCount == 5)
    #expect(Array(storage.prefix(5)) == Array("abcde".utf8))
  }

  /// The header forms: scatter and gather, and control buffers in memory
  /// that the caller manages, as NIO pools them.
  @available(System 199, *)
  @Test func headerFormsGatherAndScatter() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram)
    defer {
      try? first.close()
      try? second.close()
    }
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }

    // Gather the datagram from two buffers.
    var ancillary = AncillaryMessageBuffer()
    ancillary.appendFileDescriptors([pipe.writeEnd])
    let parts = [Array("hello, ".utf8), Array("world".utf8)]
    let sent = try parts[0].withUnsafeBytes { part0 in
      try parts[1].withUnsafeBytes { part1 in
        var vectors = [
          CInterop.IOVec(iov_base: UnsafeMutableRawPointer(mutating: part0.baseAddress), iov_len: part0.count),
          CInterop.IOVec(iov_base: UnsafeMutableRawPointer(mutating: part1.baseAddress), iov_len: part1.count),
        ]
        return try vectors.withUnsafeMutableBufferPointer { vectors in
          try ancillary.withUnsafeBytes { control in
            var header = CInterop.MsgHdr()
            header.msg_iov = vectors.baseAddress
            header.msg_iovlen = .init(vectors.count)
            header.msg_control = UnsafeMutableRawPointer(mutating: control.baseAddress)
            header.msg_controllen = .init(control.count)
            return try first.sendMessage(header)
          }
        }
      }
    }
    #expect(sent == 12)

    // Scatter it into two buffers, with a control buffer of our own.
    let head = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 1)
    let tail = UnsafeMutableRawBufferPointer.allocate(byteCount: 20, alignment: 1)
    let control = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 8)
    defer {
      head.deallocate()
      tail.deallocate()
      control.deallocate()
    }
    var vectors = [
      CInterop.IOVec(iov_base: head.baseAddress, iov_len: head.count),
      CInterop.IOVec(iov_base: tail.baseAddress, iov_len: tail.count),
    ]
    let (count, header) = try vectors.withUnsafeMutableBufferPointer { vectors in
      var header = CInterop.MsgHdr()
      header.msg_iov = vectors.baseAddress
      header.msg_iovlen = .init(vectors.count)
      header.msg_control = control.baseAddress
      header.msg_controllen = .init(control.count)
      let count = try second.receiveMessage(&header)
      return (count, header)
    }
    #expect(count == 12)
    #expect(String(decoding: Array(head) + tail.prefix(count - head.count), as: UTF8.self) == "hello, world")

    // recvmsg updated the header: the control buffer's length is now the
    // length of the messages it received.
    #expect(header.msg_flags == 0)
    #expect(Int(header.msg_controllen) < control.count)
    let messages = SocketDescriptor.UnsafeAncillaryMessages(header)
    #expect(messages.count == 1)
    let passed = try #require(messages.first?.fileDescriptors?.first)
    defer { try? passed.close() }
    try passed.writeAll("into the pipe".utf8)
    #expect(try readText(from: pipe.readEnd) == "into the pipe")
  }
}

/// Receives a message of up to 1 KiB as UTF-8 text.
@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func receiveText(
  from socket: SocketDescriptor,
  ancillary: inout SocketDescriptor.AncillaryMessageBuffer
) throws -> (String, (byteCount: Int, flags: SocketDescriptor.MessageFlags)) {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { storage.deallocate() }
  var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
  let result = try socket.receiveMessage(into: &buffer, ancillaryMessages: &ancillary)
  #expect(buffer.byteCount == result.byteCount)
  return (String(decoding: storage.prefix(result.byteCount), as: UTF8.self), result)
}

/// Receives a message of up to 1 KiB as UTF-8 text, and its sender.
@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func receiveText(
  from socket: SocketDescriptor,
  ancillary: inout SocketDescriptor.AncillaryMessageBuffer,
  sender: inout SocketAddress
) throws -> (String, (byteCount: Int, flags: SocketDescriptor.MessageFlags)) {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { storage.deallocate() }
  var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
  let result = try socket.receiveMessage(
    into: &buffer, ancillaryMessages: &ancillary, sender: &sender)
  #expect(buffer.byteCount == result.byteCount)
  return (String(decoding: storage.prefix(result.byteCount), as: UTF8.self), result)
}

/// Reads up to 64 bytes from a descriptor as UTF-8 text.
private func readText(from descriptor: FileDescriptor) throws -> String {
  var bytes = [UInt8](repeating: 0, count: 64)
  let count = try bytes.withUnsafeMutableBytes { try descriptor.read(into: $0) }
  return String(decoding: bytes.prefix(count), as: UTF8.self)
}

#endif // !os(Windows) && !os(WASI)
