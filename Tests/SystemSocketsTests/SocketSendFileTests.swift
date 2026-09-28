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
import SystemSockets

@Suite("sendfile")
private struct SocketSendFileTests {
  /// Calls `body` with a file of `count` bytes, each its offset's low 8 bits,
  /// and a connected pair of local stream sockets.
  @available(System 199, *)
  private func withFileAndSockets<R>(
    count: Int,
    options: SocketDescriptor.OpenOptions = .closeOnExec,
    _ body: (FileDescriptor, SocketDescriptor, SocketDescriptor) throws -> R
  ) throws -> R {
    var template = Array("/tmp/system-sendfile-XXXXXX".utf8CString)
    let fd = template.withUnsafeMutableBufferPointer { mkstemp($0.baseAddress!) }
    guard fd >= 0 else { throw Errno(rawValue: errno) }
    let file = FileDescriptor(rawValue: fd)
    defer { try? file.close() }
    _ = template.withUnsafeBufferPointer { unlink($0.baseAddress!) }
    _ = try file.writeAll((0..<count).map { UInt8(truncatingIfNeeded: $0) })

    let (sender, receiver) = try SocketDescriptor.pair(.local, .stream, options: options)
    defer {
      try? sender.close()
      try? receiver.close()
    }
    return try body(file, sender, receiver)
  }

  @available(System 199, *)
  private func receive(_ count: Int, from socket: SocketDescriptor) throws -> [UInt8] {
    var bytes: [UInt8] = []
    while bytes.count < count {
      var chunk = [UInt8](repeating: 0, count: count - bytes.count)
      let received = try chunk.withUnsafeMutableBytes { try socket.receive(into: $0) }
      guard received > 0 else { break }
      bytes += chunk.prefix(received)
    }
    return bytes
  }

  @available(System 199, *)
  @Test func sendsTheRangeAndLeavesTheFilesOffset() throws {
    try withFileAndSockets(count: 256) { file, sender, receiver throws in
      #expect(try sender.sendFile(file, fromAbsoluteOffset: 10, count: 20) == 20)
      #expect(try receive(20, from: receiver) == (10..<30).map { UInt8($0) })
      #expect(try file.seek(offset: 0, from: .current) == 256)
    }
  }

  @available(System 199, *)
  @Test func stopsAtTheEndOfTheFile() throws {
    try withFileAndSockets(count: 100) { file, sender, receiver throws in
      #expect(try sender.sendFile(file, fromAbsoluteOffset: 90, count: 50) == 10)
      #expect(try receive(10, from: receiver) == (90..<100).map { UInt8($0) })
      #expect(try sender.sendFile(file, fromAbsoluteOffset: 100, count: 50) == 0)
    }
  }

  @available(System 199, *)
  @Test func aZeroCountSendsNothing() throws {
    try withFileAndSockets(count: 100, options: [.closeOnExec, .nonBlocking]) { file, sender, receiver throws in
      #expect(try sender.sendFile(file, fromAbsoluteOffset: 0, count: 0) == 0)
      var byte: UInt8 = 0
      #expect(throws: Errno.wouldBlock) {
        try withUnsafeMutableBytes(of: &byte) { try receiver.receive(into: $0) }
      }
    }
  }

  /// A nonblocking socket whose buffer fills partway returns the count it
  /// sent, which Darwin's sendfile reports with EAGAIN, and then, while
  /// the buffer stays full, throws.
  @available(System 199, *)
  @Test func aFullNonblockingSocketReturnsWhatItSent() throws {
    let size = 8 << 20
    try withFileAndSockets(count: size, options: [.closeOnExec, .nonBlocking]) { file, sender, receiver throws in
      let sent = try sender.sendFile(file, fromAbsoluteOffset: 0, count: size)
      #expect(sent > 0 && sent < size)
      #expect(throws: Errno.wouldBlock) {
        try sender.sendFile(file, fromAbsoluteOffset: Int64(sent), count: size - sent)
      }
      let received = try receive(sent, from: receiver)
      #expect(received.count == sent)
      #expect(received.last == UInt8(truncatingIfNeeded: sent - 1))
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
