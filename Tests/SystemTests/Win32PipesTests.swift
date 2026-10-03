/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

import Dispatch

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Anonymous and named pipes. Each named pipe's name has the process's ID
// and the test's name, so tests and test runs don't share one.
@available(System 199, *)
final class Win32PipesTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(Win32.PipeDirection.inbound.rawValue, DWORD(WinSDK.PIPE_ACCESS_INBOUND))
    XCTAssertEqual(Win32.PipeDirection.outbound.rawValue, DWORD(WinSDK.PIPE_ACCESS_OUTBOUND))
    XCTAssertEqual(Win32.PipeDirection.duplex.rawValue, DWORD(WinSDK.PIPE_ACCESS_DUPLEX))
    XCTAssertEqual(Win32.PipeType.byteStream.rawValue, DWORD(WinSDK.PIPE_TYPE_BYTE))
    XCTAssertEqual(Win32.PipeType.message.rawValue, DWORD(WinSDK.PIPE_TYPE_MESSAGE))
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_FILE_FLAG_FIRST_PIPE_INSTANCE, DWORD(WinSDK.FILE_FLAG_FIRST_PIPE_INSTANCE))
    XCTAssertEqual(_PIPE_NOWAIT, DWORD(WinSDK.PIPE_NOWAIT))
    XCTAssertEqual(_PIPE_READMODE_MESSAGE, DWORD(WinSDK.PIPE_READMODE_MESSAGE))
    XCTAssertEqual(_PIPE_REJECT_REMOTE_CLIENTS, DWORD(WinSDK.PIPE_REJECT_REMOTE_CLIENTS))
    XCTAssertEqual(_PIPE_UNLIMITED_INSTANCES, DWORD(WinSDK.PIPE_UNLIMITED_INSTANCES))
    XCTAssertEqual(_ERROR_PIPE_CONNECTED, DWORD(WinSDK.ERROR_PIPE_CONNECTED))
  }

  func testAnonymousPipes() throws {
    let pipe = try Win32.FileHandle.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    let empty = try readEnd.bytesAvailable()
    XCTAssertEqual(empty, 0)
    try withRawSpan(Array("hello".utf8)) { try writeEnd.write($0) }
    let available = try readEnd.bytesAvailable()
    XCTAssertEqual(available, 5)
    let read = try readSome(readEnd, upTo: 16)
    XCTAssertEqual(read, Array("hello".utf8))
    // Once the write end closes, an empty pipe is at its end.
    try writeEnd.close()
    XCTAssertThrowsWin32Error(.brokenPipe) { try readEnd.bytesAvailable() }
    let atEnd = try readSome(readEnd, upTo: 16)
    XCTAssertEqual(atEnd, [])
    try readEnd.close()

    // A buffer size is a suggestion; a negative one isn't.
    let small = try Win32.FileHandle.pipe(bufferSize: 1)
    try withRawSpan([1, 2, 3]) { try small.writeEnd.write($0) }
    XCTAssertThrowsWin32Error(.invalidParameter) { try Win32.FileHandle.pipe(bufferSize: -1) }
  }

  func testNamedPipes() throws {
    let name = pipeName("testNamedPipes")
    let server = try Win32.FileHandle.createNamedPipe(name, direction: .inbound)
    XCTAssertTrue(Win32._isSynchronous(server.unsafeRawHandle))
    let client = try Win32.FileHandle.open(name, access: .genericWrite)
    // The client connected before the wait, which returns at once.
    try server.waitForClient()
    try withRawSpan(Array("ping".utf8)) { try client.write($0) }
    let available = try server.bytesAvailable()
    XCTAssertEqual(available, 4)
    let read = try readSome(server, upTo: 16)
    XCTAssertEqual(read, Array("ping".utf8))

    // The first instance's guard, and its limit of one instance.
    XCTAssertThrowsWin32Error(.accessDenied) {
      try Win32.FileHandle.createNamedPipe(name, direction: .inbound)
    }
    XCTAssertThrowsWin32Error(.pipeBusy) {
      try Win32.FileHandle.createNamedPipe(name, direction: .inbound, firstInstance: false)
    }
    try client.close()
    try server.close()
  }

  func testInstancesOfAPipe() throws {
    let name = pipeName("testInstancesOfAPipe")
    let first = try Win32.FileHandle.createNamedPipe(
      name, direction: .inbound, maximumInstances: nil)
    let second = try Win32.FileHandle.createNamedPipe(
      name, direction: .inbound, maximumInstances: nil, firstInstance: false)
    // Each client connects to an instance that's free.
    let clientOfFirst = try Win32.FileHandle.open(name, access: .genericWrite)
    let clientOfSecond = try Win32.FileHandle.open(name, access: .genericWrite)
    try first.waitForClient()
    try second.waitForClient()
    try clientOfFirst.close()
    try clientOfSecond.close()
    try first.close()
    try second.close()
  }

  func testWaitingForAClient() throws {
    let name = pipeName("testWaitingForAClient")
    let server = try Win32.FileHandle.createNamedPipe(name, direction: .inbound)
    let opened = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      Sleep(100)
      if let client = try? Win32.FileHandle.open(name, access: .genericWrite) {
        _ = try? withRawSpan([42]) { try client.write($0) }
        opened.signal()
        _ = try? client.close()
      } else {
        opened.signal()
      }
    }
    try server.waitForClient()
    opened.wait()
    let read = try readSome(server, upTo: 4)
    XCTAssertEqual(read, [42])

    // Disconnecting frees the instance for another client.
    try server.disconnectClient()
    let next = try Win32.FileHandle.open(name, access: .genericWrite)
    try server.waitForClient()
    // A client that opened the pipe and closed it before the wait.
    try next.close()
    try server.disconnectClient()
    let gone = try Win32.FileHandle.open(name, access: .genericWrite)
    try gone.close()
    XCTAssertThrowsWin32Error(.noData) { try server.waitForClient() }
    try server.close()
  }

  func testMessagePipes() throws {
    let name = pipeName("testMessagePipes")
    let server = try Win32.FileHandle.createNamedPipe(name, direction: .duplex, type: .message)
    let client = try Win32.FileHandle.open(name, access: [.genericRead, .genericWrite])
    try withRawSpan(Array("one".utf8)) { try client.write($0) }
    try withRawSpan(Array("three".utf8)) { try client.write($0) }
    // The server's end reads a message at a time, and a short buffer part
    // of one.
    let first = try readSome(server, upTo: 16)
    XCTAssertEqual(first, Array("one".utf8))
    let part = try readSome(server, upTo: 2)
    XCTAssertEqual(part, Array("th".utf8))
    let rest = try readSome(server, upTo: 16)
    XCTAssertEqual(rest, Array("ree".utf8))

    // A client's end reads bytes until it asks for messages.
    try withRawSpan(Array("four".utf8)) { try server.write($0) }
    try withRawSpan(Array("five".utf8)) { try server.write($0) }
    try client.setPipeMode(readMode: .message)
    let four = try readSome(client, upTo: 16)
    XCTAssertEqual(four, Array("four".utf8))
    let five = try readSome(client, upTo: 16)
    XCTAssertEqual(five, Array("five".utf8))
    try client.close()
    try server.close()
  }

  func testNonblockingReads() throws {
    // swift-log's test: the read end of a pipe made nonblocking.
    let pipe = try Win32.FileHandle.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try readEnd.setPipeMode(blocking: false)
    XCTAssertThrowsWin32Error(.noData) { try readSome(readEnd, upTo: 16) }
    try withRawSpan([7]) { try writeEnd.write($0) }
    let read = try readSome(readEnd, upTo: 16)
    XCTAssertEqual(read, [7])
    try readEnd.setPipeMode(blocking: true)
    try writeEnd.close()
    try readEnd.close()
  }

  func testOverlappedNamedPipes() throws {
    let name = pipeName("testOverlappedNamedPipes")
    let server = try Win32.OverlappedFileHandle.createNamedPipe(name, direction: .inbound)
    XCTAssertFalse(Win32._isSynchronous(server.unsafeRawHandle))
    let client = try Win32.FileHandle.open(name, access: .genericWrite)
    try withRawSpan([1, 2, 3]) { try client.write($0) }
    let available = try server.bytesAvailable()
    XCTAssertEqual(available, 3)
    // The data outlasts the client's end.
    try client.close()
    let remaining = try server.bytesAvailable()
    XCTAssertEqual(remaining, 3)
    try server.close()
  }

  func testRejectedArguments() throws {
    let name = pipeName("testRejectedArguments")
    for instances in [0, 255, -1] {
      XCTAssertThrowsWin32Error(.invalidParameter, "\(instances)") {
        try Win32.FileHandle.createNamedPipe(
          name, direction: .inbound, maximumInstances: instances)
      }
    }
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.FileHandle.createNamedPipe(name, direction: .inbound, bufferSize: -1)
    }
    // A name outside \\.\pipe\.
    do {
      _ = try Win32.FileHandle.createNamedPipe("C:\\not-a-pipe", direction: .inbound)
      XCTFail("created a pipe outside \\\\.\\pipe\\")
    } catch {}
    // A disk file has no pipe to peek.
    try withTemporaryFilePath(basename: "testPipesRejectedArguments") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      XCTAssertThrowsError(try file.bytesAvailable())
      XCTAssertThrowsError(try file.setPipeMode(blocking: false))
      try file.close()
    }
  }
}

/// A pipe name of this process's for a test.
private func pipeName(_ test: String) -> FilePath {
  FilePath("\\\\.\\pipe\\swift-system-\(GetCurrentProcessId())-\(test)")
}

/// What one read of `handle` returns, into a buffer of `count` bytes.
@available(System 199, *)
private func readSome(_ handle: borrowing Win32.FileHandle, upTo count: Int) throws -> [UInt8] {
  var buffer = [UInt8](repeating: 0, count: count)
  let read: Int
  do {
    var span = buffer.mutableSpan
    read = try handle.read(into: &span)
  }
  return Array(buffer[..<read])
}

#endif // os(Windows)
