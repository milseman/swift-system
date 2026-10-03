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

// Events, waiting for several objects, and an event in an OVERLAPPED.
@available(System 199, *)
final class Win32EventsTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_MAXIMUM_WAIT_OBJECTS, Int(WinSDK.MAXIMUM_WAIT_OBJECTS))
  }

  func testManualResetEvents() throws {
    let event = try Win32.EventHandle.create(manualReset: true)
    let before = try event.wait(timeout: .zero)
    XCTAssertFalse(before)
    try event.signal()
    // It stays signaled for every wait, until it's reset.
    let first = try event.wait(timeout: .zero)
    let second = try event.wait(timeout: .zero)
    XCTAssertTrue(first)
    XCTAssertTrue(second)
    try event.reset()
    let after = try event.wait(timeout: .zero)
    XCTAssertFalse(after)
    try event.close()
  }

  func testAutoResetEvents() throws {
    let event = try Win32.EventHandle.create(manualReset: false, initiallySignaled: true)
    // The wait it ends resets it.
    let first = try event.wait(timeout: .zero)
    let second = try event.wait(timeout: .zero)
    XCTAssertTrue(first)
    XCTAssertFalse(second)
  }

  func testWakingAnotherThread() throws {
    let event = try Win32.EventHandle.create(manualReset: false)
    // A handle's bits, which are Sendable, as the pointer isn't.
    let address = UInt(bitPattern: event.unsafeRawHandle)
    DispatchQueue.global().async {
      Sleep(50)
      SetEvent(HANDLE(bitPattern: address))
    }
    let woken = try event.wait(timeout: .seconds(30))
    XCTAssertTrue(woken)
  }

  func testWaitingForAny() throws {
    let first = try Win32.EventHandle.create(manualReset: true)
    let second = try Win32.EventHandle.create(manualReset: true)
    let handles = [first.unsafeRawHandle, second.unsafeRawHandle]
    let none = try Win32.waitForAny(handles, timeout: .zero)
    XCTAssertNil(none)
    try second.signal()
    let one = try Win32.waitForAny(handles, timeout: .zero)
    XCTAssertEqual(one, 1)
    try first.signal()
    // The lowest index of the signaled objects.
    let both = try Win32.waitForAny(handles, timeout: .zero)
    XCTAssertEqual(both, 0)

    // A process is signaled when it exits.
    let child = try Win32.ProcessHandle.create(commandLine: "cmd.exe /c exit 0", flags: .noWindow)
    let event = try Win32.EventHandle.create(manualReset: false)
    let exited = try Win32.waitForAny(
      [event.unsafeRawHandle, child.process.unsafeRawHandle], timeout: .seconds(30))
    XCTAssertEqual(exited, 1)

    XCTAssertThrowsWin32Error(.invalidParameter) { try Win32.waitForAny([]) }
    let tooMany = [HANDLE](repeating: first.unsafeRawHandle, count: 65)
    XCTAssertThrowsWin32Error(.invalidParameter) { try Win32.waitForAny(tooMany, timeout: .zero) }
  }

  func testWaitingForAll() throws {
    let first = try Win32.EventHandle.create(manualReset: false)
    let second = try Win32.EventHandle.create(manualReset: false)
    let handles = [first.unsafeRawHandle, second.unsafeRawHandle]
    try first.signal()
    let one = try Win32.waitForAll(handles, timeout: .zero)
    XCTAssertFalse(one)
    // A wait that doesn't end leaves the auto-reset event signaled.
    let stillSignaled = try first.wait(timeout: .zero)
    XCTAssertTrue(stillSignaled)
    try first.signal()
    try second.signal()
    let both = try Win32.waitForAll(handles, timeout: .zero)
    XCTAssertTrue(both)
    // And the wait that ends resets both.
    let reset = try Win32.waitForAny(handles, timeout: .zero)
    XCTAssertNil(reset)
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.waitForAll([first.unsafeRawHandle, first.unsafeRawHandle], timeout: .zero)
    }
  }

  func testOverlappedEvents() throws {
    let event = try Win32.EventHandle.create(manualReset: true)
    let raw = UInt(bitPattern: event.unsafeRawHandle)
    XCTAssertEqual(UInt(bitPattern: event.overlappedEvent()), raw)
    XCTAssertEqual(UInt(bitPattern: event.overlappedEvent(queuesCompletion: false)), raw | 1)

    // A read whose event has its low bit set signals the event and queues
    // no packet; one whose event doesn't, does both.
    let name = FilePath("\\\\.\\pipe\\swift-system-\(GetCurrentProcessId())-testOverlappedEvents")
    let server = try Win32.OverlappedFileHandle.createNamedPipe(name, direction: .inbound)
    let client = try Win32.FileHandle.open(name, access: .genericWrite)
    let port = try Win32.CompletionPort.create()
    try port.associate(server, key: 5)
    let overlapped = UnsafeMutablePointer<OVERLAPPED>.allocate(capacity: 1)
    defer { overlapped.deallocate() }
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    overlapped.initialize(to: OVERLAPPED())
    overlapped.pointee.hEvent = event.overlappedEvent(queuesCompletion: false)
    _ = try server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    try withRawSpan([1]) { try client.write($0) }
    let signaled = try event.wait(timeout: .seconds(30))
    XCTAssertTrue(signaled)
    let none = try port.dequeue(timeout: .milliseconds(100))
    XCTAssertNil(none)

    try event.reset()
    overlapped.initialize(to: OVERLAPPED())
    overlapped.pointee.hEvent = event.overlappedEvent()
    _ = try server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    try withRawSpan([2]) { try client.write($0) }
    let packet = try port.dequeue(timeout: .seconds(30))
    XCTAssertEqual(packet?.key, 5)
    let signaledAgain = try event.wait(timeout: .zero)
    XCTAssertTrue(signaledAgain)
    try client.close()
    try server.close()
  }
}

#endif // os(Windows)
