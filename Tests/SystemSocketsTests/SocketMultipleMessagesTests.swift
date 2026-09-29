/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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
#if ENABLE_MOCKING
@testable import SystemSockets
#else
import SystemSockets
#endif

/// Message headers for `count` messages of `size` bytes each, in buffers
/// this owns, whose byte `j` of message `i` is `i + j`.
@available(System 199, *)
private final class Messages {
  let count: Int
  let size: Int
  let storage: UnsafeMutableRawBufferPointer
  let vectors: UnsafeMutableBufferPointer<CInterop.IOVec>
  let headers: UnsafeMutableBufferPointer<CInterop.MMsgHdr>

  init(count: Int, size: Int, filled: Bool) {
    self.count = count
    self.size = size
    storage = .allocate(byteCount: count * size, alignment: 8)
    vectors = .allocate(capacity: count)
    headers = .allocate(capacity: count)
    for i in 0..<count {
      let buffer = UnsafeMutableRawBufferPointer(rebasing: storage[i * size ..< (i + 1) * size])
      for j in 0..<size { buffer[j] = filled ? UInt8(truncatingIfNeeded: i + j) : 0 }
      vectors[i] = CInterop.IOVec(iov_base: buffer.baseAddress, iov_len: size)
      var header = CInterop.MsgHdr()
      header.msg_iov = vectors.baseAddress! + i
      header.msg_iovlen = 1
      headers[i] = CInterop.MMsgHdr(msg_hdr: header)
    }
  }

  func bytes(of i: Int) -> [UInt8] {
    Array(storage[i * size ..< (i + 1) * size])
  }

  deinit {
    storage.deallocate()
    vectors.deallocate()
    headers.deallocate()
  }
}

@Suite("sendmmsg and recvmmsg")
private struct SocketMultipleMessagesTests {
  /// The Swift mirror has struct mmsghdr's layout: a msghdr, then an
  /// unsigned int, padded to the msghdr's alignment.
  @available(System 199, *)
  @Test func theMirrorHasTheCLayout() {
    let header = MemoryLayout<CInterop.MsgHdr>.self
    #expect(MemoryLayout<CInterop.MMsgHdr>.offset(of: \.msg_hdr) == 0)
    #expect(MemoryLayout<CInterop.MMsgHdr>.offset(of: \.msg_len) == header.size)
    let unpadded = header.size + MemoryLayout<CUnsignedInt>.size
    let padded = (unpadded + header.alignment - 1) / header.alignment * header.alignment
    #expect(MemoryLayout<CInterop.MMsgHdr>.stride == padded)
    #if os(Linux) && arch(x86_64) || os(Linux) && arch(arm64)
    #expect(MemoryLayout<CInterop.MMsgHdr>.stride == 64)
    #endif
  }

  @available(System 199, *)
  @Test func sendsAndReceivesABatch() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram, options: [.closeOnExec, .nonBlocking])
    defer {
      try? first.close()
      try? second.close()
    }
    let outgoing = Messages(count: 3, size: 100, filled: true)
    #expect(try first.sendMessages(outgoing.headers) == 3)
    #expect(outgoing.headers.map(\.msg_len) == [100, 100, 100])

    // Room for four; three are waiting.
    let incoming = Messages(count: 4, size: 200, filled: false)
    #expect(try second.receiveMessages(incoming.headers) == 3)
    #expect(incoming.headers.prefix(3).map(\.msg_len) == [100, 100, 100])
    for i in 0..<3 {
      #expect(incoming.bytes(of: i).prefix(100) == outgoing.bytes(of: i)[...])
    }
    // Nothing is left, so the next call throws rather than returning 0.
    #expect(throws: Errno.wouldBlock) { try second.receiveMessages(incoming.headers) }
  }

  @available(System 199, *)
  @Test func aFullSocketSendsShort() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram, options: [.closeOnExec, .nonBlocking])
    defer {
      try? first.close()
      try? second.close()
    }
    // More than any default buffer holds, in datagrams under Darwin's 2048-byte limit.
    let outgoing = Messages(count: 256, size: 1024, filled: true)
    let sent = try first.sendMessages(outgoing.headers)
    #expect(sent > 0 && sent < 256)
    // The rest starts with the message that didn't fit, which fails.
    let rest = UnsafeMutableBufferPointer(rebasing: outgoing.headers[sent...])
    #expect(throws: Errno.self) { try first.sendMessages(rest) }

    let incoming = Messages(count: 1, size: 1024, filled: false)
    #expect(try second.receiveMessages(incoming.headers) == 1)
    #expect(incoming.bytes(of: 0) == outgoing.bytes(of: 0))
  }

  @available(System 199, *)
  @Test func noMessagesMakeNoCall() throws {
    let socket = SocketDescriptor(rawValue: -1)
    let empty = UnsafeMutableBufferPointer<CInterop.MMsgHdr>(start: nil, count: 0)
    #expect(try socket.sendMessages(empty) == 0)
    #expect(try socket.receiveMessages(empty) == 0)
  }

  /// The buffer forms build the headers themselves.
  @available(System 199, *)
  @Test func sendsAndReceivesBuffers() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram, options: [.closeOnExec, .nonBlocking])
    defer {
      try? first.close()
      try? second.close()
    }
    let outgoing = Messages(count: 3, size: 50, filled: true)
    let sent = try first.sendMessages((0..<3).map {
      UnsafeRawBufferPointer(rebasing: outgoing.storage[$0 * 50 ..< ($0 + 1) * 50])
    })
    #expect(sent == 3)

    // Four buffers, the last too small for the datagram it gets.
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 400, alignment: 1)
    defer { storage.deallocate() }
    let buffers = [
      UnsafeMutableRawBufferPointer(rebasing: storage[0 ..< 100]),
      UnsafeMutableRawBufferPointer(rebasing: storage[100 ..< 200]),
      UnsafeMutableRawBufferPointer(rebasing: storage[200 ..< 210]),
      UnsafeMutableRawBufferPointer(rebasing: storage[300 ..< 400]),
    ]
    let received = try second.receiveMessages(into: buffers)
    #expect(received.map(\.byteCount) == [50, 50, 10])
    #expect(received.map { $0.flags.contains(.dataTruncated) } == [false, false, true])
    #expect(Array(buffers[1].prefix(50)) == outgoing.bytes(of: 1))
    #expect(Array(buffers[2]) == Array(outgoing.bytes(of: 2).prefix(10)))
    #expect(try first.sendMessages([UnsafeRawBufferPointer]()) == 0)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test(.requiresSocketBinding) func sendsToAndReceivesFromAddresses() throws {
    func bound() throws -> (SocketDescriptor, SocketAddress) {
      let socket = try SocketDescriptor.open(.ipv4, .datagram, options: [.closeOnExec, .nonBlocking])
      try socket.bind(to: SocketAddress(ipv4: IPv4Address(host: .loopback, port: 0)))
      var address = SocketAddress()
      try socket.getLocalAddress(into: &address)
      return (socket, address)
    }
    let (sender, senderAddress) = try bound()
    defer { try? sender.close() }
    let (first, firstAddress) = try bound()
    defer { try? first.close() }
    let (second, secondAddress) = try bound()
    defer { try? second.close() }

    let bytes: [UInt8] = [1, 2, 3, 4, 5, 6]
    try bytes.withUnsafeBytes { bytes in
      let sent = try sender.sendMessages([
        (UnsafeRawBufferPointer(rebasing: bytes[0 ..< 2]), firstAddress),
        (UnsafeRawBufferPointer(rebasing: bytes[2 ..< 4]), secondAddress),
        (UnsafeRawBufferPointer(rebasing: bytes[4 ..< 6]), firstAddress),
      ])
      #expect(sent == 3)
    }
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { storage.deallocate() }
    let buffers = (0 ..< 4).map { UnsafeMutableRawBufferPointer(rebasing: storage[$0 * 16 ..< ($0 + 1) * 16]) }

    /// Receives until `count` messages have arrived, since loopback
    /// datagrams can arrive a moment after they're sent.
    func receive(_ count: Int, from socket: SocketDescriptor) throws -> [(bytes: [UInt8], sender: SocketAddress)] {
      var messages: [(bytes: [UInt8], sender: SocketAddress)] = []
      while messages.count < count {
        _ = try socket.fileDescriptor.poll(for: .readable, timeout: .seconds(hangGuardSeconds))
        let received = try socket.receiveMessages(into: buffers.prefix(count - messages.count))
        #expect(!received.isEmpty)
        if received.isEmpty { break }
        for (message, buffer) in zip(received, buffers) {
          messages.append((Array(buffer.prefix(message.byteCount)), message.sender))
        }
      }
      return messages
    }
    let atFirst = try receive(2, from: first)
    #expect(atFirst.map(\.bytes) == [[1, 2], [5, 6]])
    #expect(atFirst.map(\.sender) == [senderAddress, senderAddress])
    let atSecond = try receive(1, from: second)
    #expect(atSecond.map(\.bytes) == [[3, 4]])
  }

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func mockedCalls() throws {
    let socket = SocketDescriptor(rawValue: 4)
    let messages = Messages(count: 2, size: 8, filled: true)
    try MockingDriver.withMockingEnabled { mocking in
      #if SYSTEM_PACKAGE_DARWIN
      // One sendmsg or recvmsg a message, each recording its length.
      mocking.byteCounts = [5, 8]
      #expect(try socket.sendMessages(messages.headers, flags: .doNotRoute) == 2)
      #expect(messages.headers.map(\.msg_len) == [5, 8])
      mocking.byteCounts = [3, 4]
      #expect(try socket.receiveMessages(messages.headers) == 2)
      var names: [String] = []
      while let entry = mocking.trace.dequeue() { names.append(entry.name) }
      #expect(names == ["sendmsg", "sendmsg", "recvmsg", "recvmsg"])

      // The first message's error is the call's.
      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      #expect(throws: Errno.wouldBlock) { try socket.sendMessages(messages.headers) }
      #expect(mocking.trace.dequeue()?.name == "sendmsg")
      #expect(mocking.trace.dequeue() == nil)
      #else
      mocking.byteCounts = [2]
      #expect(try socket.sendMessages(messages.headers, flags: .doNotRoute) == 2)
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "sendmmsg")
      #expect(entry?.arguments == [CInt(4), CUnsignedInt(2), CInt(MSG_DONTROUTE)])
      mocking.byteCounts = [1]
      #expect(try socket.receiveMessages(messages.headers) == 1)
      #expect(mocking.trace.dequeue()?.name == "recvmmsg")
      #endif

      // An interruption before anything is sent is retried.
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      mocking.byteCounts = [8, 8, 2]
      _ = try socket.sendMessages(messages.headers)
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
