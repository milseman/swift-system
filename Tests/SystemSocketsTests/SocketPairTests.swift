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

@testable import SystemSockets
import SystemPackage

// Real-call tests for SocketDescriptor.pair and for the checked conversion
// from FileDescriptor. Swift Testing runs these in parallel, so none of them
// reuses a descriptor number after closing it.
@Suite("Socket pairs and conversions")
private struct SocketPairTests {

  // MARK: - Checked conversion

  @available(System 199, *)
  @Test func checkedConversionAcceptsBothEndsOfAPair() throws {
    for type in [SocketDescriptor.ConnectionType.stream, .datagram] {
      let (first, second) = try SocketDescriptor.pair(.local, type)
      defer {
        try? first.close()
        try? second.close()
      }
      #expect(try SocketDescriptor(first.fileDescriptor) == first)
      #expect(try SocketDescriptor(second.fileDescriptor) == second)
    }
  }

  @available(System 199, *)
  @Test func checkedConversionAcceptsADuplicatedSocket() throws {
    let socket = try SocketDescriptor.open(.local, .stream)
    defer { try? socket.close() }
    let duplicate = try socket.fileDescriptor.duplicate()
    defer { try? duplicate.close() }

    #expect(duplicate != socket.fileDescriptor)
    #expect(try SocketDescriptor(duplicate).fileDescriptor == duplicate)
  }

  @available(System 199, *)
  @Test func checkedConversionRejectsFilesAndDirectories() throws {
    try withTemporaryFile { file in
      #expect(throws: Errno.notSocket) { try SocketDescriptor(file) }
    }
    let root = try FileDescriptor.open("/", .readOnly)
    defer { try? root.close() }
    #expect(throws: Errno.notSocket) { try SocketDescriptor(root) }
  }

  @available(System 199, *)
  @Test func uncheckedConversionDoesNotVerify() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    // Nothing checks the descriptor, so socket operations fail later.
    let notASocket = SocketDescriptor(unchecked: pipe.readEnd)
    #expect(notASocket.fileDescriptor == pipe.readEnd)
    #expect(throws: Errno.notSocket) {
      try notASocket.getSocketOption(SocketDescriptor.SocketOption.type)
    }
  }

  // MARK: - Pairs

  @available(System 199, *)
  @Test func datagramPairPreservesMessageBoundaries() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .datagram)
    defer {
      try? first.close()
      try? second.close()
    }
    for message in ["ab", "cde"] {
      _ = try Array(message.utf8).withUnsafeBytes { try first.send($0) }
    }
    // Each receive returns one whole datagram, even with room for more.
    #expect(try receiveString(from: second) == "ab")
    #expect(try receiveString(from: second) == "cde")
  }

  @available(System 199, *)
  @Test func pairEndsWorkAsFileDescriptors() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    try first.fileDescriptor.writeAll("xyz".utf8)
    #expect(try receiveString(from: second) == "xyz")

    _ = try Array("uvw".utf8).withUnsafeBytes { try second.send($0) }
    var buffer = [UInt8](repeating: 0, count: 16)
    let count = try buffer.withUnsafeMutableBytes { try first.fileDescriptor.read(into: $0) }
    #expect(String(decoding: buffer.prefix(count), as: UTF8.self) == "uvw")
  }

  @available(System 199, *)
  @Test func shutdownOfOneEndIsEndOfFileAtTheOther() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    _ = try Array("last".utf8).withUnsafeBytes { try first.send($0) }
    try first.shutdown(.write)
    #expect(try receiveString(from: second) == "last")
    #expect(try receiveString(from: second) == "")

    // The other direction stays open.
    _ = try Array("reply".utf8).withUnsafeBytes { try second.send($0) }
    #expect(try receiveString(from: first) == "reply")
  }

  @available(System 199, *)
  @Test func pairRejectsTheInternetDomain() {
    // socketpair only supports local sockets on Darwin and Linux.
    #expect(throws: Errno.notSupportedOnSocket) {
      try SocketDescriptor.pair(.ipv4, .stream)
    }
  }

  // MARK: - TCP keepalive

  #if SYSTEM_PACKAGE_DARWIN || os(Linux)
  @available(System 199, *)
  @Test func keepAliveCountRejectsANegativeValue() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    defer { try? socket.close() }
    #expect(throws: Errno.invalidArgument) {
      try socket.setTCPOption(.keepAliveCount, to: -5)
    }
    // The failed call leaves the previous value in place.
    try socket.setTCPOption(.keepAliveCount, to: 4)
    #expect(throws: Errno.invalidArgument) {
      try socket.setTCPOption(.keepAliveCount, to: -1)
    }
    #expect(try socket.getTCPOption(.keepAliveCount) == 4)
  }
  #endif
}

/// Receives up to 64 bytes from `socket` as UTF-8 text.
@available(System 199, *)
private func receiveString(from socket: SocketDescriptor) throws -> String {
  var buffer = [UInt8](repeating: 0, count: 64)
  let count = try buffer.withUnsafeMutableBytes { try socket.receive(into: $0) }
  return String(decoding: buffer.prefix(count), as: UTF8.self)
}

/// Creates an empty regular file, and removes it after `body` returns.
private func withTemporaryFile<R>(_ body: (FileDescriptor) throws -> R) throws -> R {
  let directory = getenv("TMPDIR").map { String(cString: $0) } ?? "/tmp"
  var template = Array("\(directory)/SocketPairTests.XXXXXX".utf8CString)
  let raw = template.withUnsafeMutableBufferPointer { mkstemp($0.baseAddress!) }
  guard raw >= 0 else { throw Errno(rawValue: errno) }
  let file = FileDescriptor(rawValue: raw)
  defer {
    try? file.close()
    _ = template.withUnsafeBufferPointer { unlink($0.baseAddress!) }
  }
  return try body(file)
}

#endif // !os(Windows) && !os(WASI)
