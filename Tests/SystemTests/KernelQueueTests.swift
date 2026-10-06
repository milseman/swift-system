/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// Real kqueues. The signal test changes a process-wide signal disposition,
// and the process test spawns a child, so these are XCTests, which run one
// at a time.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class KernelQueueTests: XCTestCase {
  let tag = UnsafeMutableRawPointer(bitPattern: 0x5157)

  func testReadablePipe() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    try queue.register(
      KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .add, userData: tag))

    let before = try poll(queue)
    XCTAssertEqual(before, [])

    try pipe.writeEnd.writeAll("abc".utf8)
    let events = try poll(queue)
    XCTAssertEqual(events.count, 1)
    let event = try XCTUnwrap(events.first)
    XCTAssertEqual(event.fileDescriptor, pipe.readEnd.fileDescriptor)
    XCTAssertEqual(event.filter, .read)
    XCTAssertEqual(event.data, 3, "the number of bytes to read")
    XCTAssertEqual(event.userData, tag)
    XCTAssertNil(event.registrationError)
  }

  func testEndOfFile() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try queue.register(KernelEvent(readEnd.fileDescriptor, filter: .read, flags: .add))
    try writeEnd.writeAll("x".utf8)
    try writeEnd.close()

    let event = try XCTUnwrap(try poll(queue).first)
    XCTAssertTrue(event.flags.contains(.endOfFile))
    XCTAssertEqual(event.data, 1, "data remains after the end of file")
  }

  func testDeleteAndDisable() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    let readable = KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .add)
    try queue.register(readable)
    try pipe.writeEnd.writeAll("x".utf8)

    var disable = readable
    disable.flags = .disable
    try queue.register(disable)
    XCTAssertEqual(try poll(queue), [], "a disabled event isn't reported")

    var enable = readable
    enable.flags = .enable
    try queue.register(enable)
    XCTAssertEqual(try poll(queue).count, 1)

    var delete = readable
    delete.flags = .delete
    try queue.register(delete)
    XCTAssertEqual(try poll(queue), [])
    assertThrows(.noSuchFileOrDirectory, "deleting it again") {
      try queue.register(delete)
    }
  }

  func testRegisterStopsAtFirstFailure() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    let changes = [
      KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .add),
      KernelEvent(FileDescriptor(rawValue: -1), filter: .read, flags: .add),
      KernelEvent(pipe.writeEnd.fileDescriptor, filter: .write, flags: .add),
    ]
    assertThrows(.badFileDescriptor) {
      try changes.withUnsafeBufferPointer {
        try queue.register(Span(_unsafeElements: $0))
      }
    }

    // The change before the failure was applied, and the one after wasn't.
    try queue.register(
      KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .delete))
    assertThrows(.noSuchFileOrDirectory) {
      try queue.register(
        KernelEvent(pipe.writeEnd.fileDescriptor, filter: .write, flags: .delete))
    }
  }

  func testFailedChangeIsReportedAsAnEvent() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    try pipe.writeEnd.writeAll("x".utf8)
    let events = try registerAndPoll(queue, [
      KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .add),
      KernelEvent(FileDescriptor(rawValue: -1), filter: .read, flags: .add, userData: tag),
    ])
    XCTAssertEqual(events.count, 1, "only the failure, not the readable pipe")
    let failure = try XCTUnwrap(events.first)
    XCTAssertTrue(failure.flags.contains(.error))
    XCTAssertEqual(failure.registrationError, .badFileDescriptor)
    XCTAssertEqual(failure.userData, tag)

    // The failure didn't stop the change before it.
    XCTAssertEqual(try poll(queue).first?.filter, .read)
  }

  func testReceipts() throws {
    let queue = try KernelQueue()
    let pipe = try OwnedFD.pipe()
    let receipts = try registerAndPoll(queue, [
      KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: [.add, .receipt]),
      KernelEvent(FileDescriptor(rawValue: -1), filter: .read, flags: [.add, .receipt]),
      KernelEvent(pipe.writeEnd.fileDescriptor, filter: .write, flags: [.add, .receipt]),
    ])
    XCTAssertEqual(receipts.count, 3)
    XCTAssertEqual(receipts.map(\.registrationError), [nil, .badFileDescriptor, nil])
    XCTAssertTrue(receipts.allSatisfy { $0.flags.contains(.error) })
  }

  func testOneShotTimer() throws {
    let queue = try KernelQueue()
    let start = ContinuousClock.now
    try queue.register(
      KernelEvent(identifier: 42, filter: .timer, flags: [.add, .oneShot], data: 10))

    let event = try XCTUnwrap(try poll(queue, timeout: .seconds(hangGuardSeconds)).first)
    XCTAssertGreaterThanOrEqual(ContinuousClock.now - start, .milliseconds(9))
    XCTAssertEqual(event.identifier, 42)
    XCTAssertEqual(event.filter, .timer)
    // Darwin counts the intervals that passed before the poll read the
    // event, more than one when the poll runs late.
    XCTAssertGreaterThanOrEqual(event.data, 1, "the number of expirations")

    assertThrows(.noSuchFileOrDirectory, "a one-shot timer is gone once reported") {
      try queue.register(KernelEvent(identifier: 42, filter: .timer, flags: .delete))
    }
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  func testRepeatingTimerInNanoseconds() throws {
    let queue = try KernelQueue()
    try queue.register(KernelEvent(
      identifier: 1, filter: .timer, flags: .add,
      filterFlags: .timerNanoseconds, data: 2_000_000))
    // Once the timer has fired, which the queue's readability shows without
    // reading the event, each interval that passes before the poll reads it
    // adds to its count.
    XCTAssertEqual(
      try queue.fileDescriptor.poll(for: .readable, timeout: .seconds(hangGuardSeconds)), .readable)
    usleep(10_000)
    let event = try XCTUnwrap(try poll(queue).first)
    XCTAssertGreaterThan(event.data, 1, "a repeating timer counts its expirations")
  }
  #endif

  func testUserEventWakesAnotherThread() throws {
    // A class shares the queue between threads, as an event loop would.
    final class Loop: Sendable {
      let queue: KernelQueue
      init() throws { queue = try KernelQueue() }
    }
    let loop = try Loop()
    try loop.queue.register(
      KernelEvent(identifier: 7, filter: .user, flags: [.add, .clear]))

    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(20)) {
      try? loop.queue.register(
        KernelEvent(identifier: 7, filter: .user, filterFlags: .userTrigger))
    }
    let event = try XCTUnwrap(try poll(loop.queue, timeout: .seconds(hangGuardSeconds)).first)
    XCTAssertEqual(event.identifier, 7)
    XCTAssertEqual(event.filter, .user)

    // Clearing resets the event once it's reported.
    XCTAssertEqual(try poll(loop.queue), [])
  }

  func testUserEventFlags() throws {
    let queue = try KernelQueue()
    try queue.register(KernelEvent(identifier: 1, filter: .user, flags: [.add, .clear]))
    try queue.register(KernelEvent(
      identifier: 1, filter: .user,
      filterFlags: [.userTrigger, .userCopy, KernelEvent.FilterFlags(rawValue: 0x2a)]))
    let event = try XCTUnwrap(try poll(queue).first)
    XCTAssertEqual(event.filterFlags.intersection(.userFlagsMask).rawValue, 0x2a)
  }

  func testTimeout() throws {
    let queue = try KernelQueue()
    let start = ContinuousClock.now
    XCTAssertEqual(try poll(queue, timeout: .milliseconds(20)), [])
    XCTAssertGreaterThanOrEqual(ContinuousClock.now - start, .milliseconds(15))
  }

  func testFullSpanDoesNotWait() throws {
    let queue = try KernelQueue()
    let start = ContinuousClock.now
    let count = try withUnsafeTemporaryAllocation(of: KernelEvent.self, capacity: 1) {
      buffer in
      buffer.initialize(repeating: KernelEvent(identifier: 0, filter: .user))
      var events = OutputSpan(buffer: buffer, initializedCount: 1)
      // Waiting would take the whole timeout, which is twice the guard.
      let count = try queue.poll(into: &events, timeout: .seconds(2 * hangGuardSeconds))
      _ = events.finalize(for: buffer)
      return count
    }
    XCTAssertEqual(count, 0)
    XCTAssertLessThan(ContinuousClock.now - start, .seconds(hangGuardSeconds))
  }

  func testPollAppendsToSpan() throws {
    let queue = try KernelQueue()
    try queue.register(KernelEvent(identifier: 3, filter: .user, flags: .add))
    try queue.register(KernelEvent(identifier: 3, filter: .user, filterFlags: .userTrigger))
    let existing = KernelEvent(identifier: 99, filter: .read)
    let events = try [KernelEvent](unsafeUninitializedCapacity: 4) { buffer, count in
      buffer.initializeElement(at: 0, to: existing)
      var output = OutputSpan(buffer: buffer, initializedCount: 1)
      let appended = try queue.poll(into: &output, timeout: .zero)
      count = output.finalize(for: buffer)
      XCTAssertEqual(appended, 1)
    }
    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(events.first, existing)
    XCTAssertEqual(events.last?.identifier, 3)
  }

  func testRelinquishAndTake() throws {
    let queue = try KernelQueue()
    try queue.register(KernelEvent(identifier: 5, filter: .user, flags: .add))
    let descriptor = queue.relinquish()

    let adopted = KernelQueue(taking: descriptor)
    try adopted.register(KernelEvent(identifier: 5, filter: .user, filterFlags: .userTrigger))
    XCTAssertEqual(try poll(adopted).first?.identifier, 5)
    try adopted.close()
  }

  func testQueueIsReadableWhenItHasEvents() throws {
    let queue = try KernelQueue()
    try queue.register(KernelEvent(identifier: 5, filter: .user, flags: .add))
    XCTAssertEqual(try queue.fileDescriptor.poll(for: .readable, timeout: .zero), [])
    try queue.register(KernelEvent(identifier: 5, filter: .user, filterFlags: .userTrigger))
    XCTAssertEqual(try queue.fileDescriptor.poll(for: .readable, timeout: .zero), .readable)
  }

  func testVnodeWrite() throws {
    try withTemporaryFilePath(basename: "testVnodeWrite") { directory in
      let path = directory.appending("file")
      let file = try OwnedFD.open(
        path, .readWrite, options: .create, permissions: .ownerReadWrite)
      let queue = try KernelQueue()
      try queue.register(KernelEvent(
        file.fileDescriptor, filter: .vnode, flags: [.add, .clear],
        filterFlags: [.vnodeWrite, .vnodeDelete]))

      try file.writeAll("x".utf8)
      let written = try XCTUnwrap(try poll(queue, timeout: .seconds(hangGuardSeconds)).first)
      XCTAssertTrue(written.filterFlags.contains(.vnodeWrite))
      XCTAssertFalse(written.filterFlags.contains(.vnodeDelete))

      try path.unlink()
      let deleted = try XCTUnwrap(try poll(queue, timeout: .seconds(hangGuardSeconds)).first)
      XCTAssertTrue(deleted.filterFlags.contains(.vnodeDelete))
    }
  }

  func testSignal() throws {
    let queue = try KernelQueue()
    // The filter reports a signal even when the process ignores it.
    let previous = signal(SIGUSR1, SIG_IGN)
    defer { signal(SIGUSR1, previous) }
    try queue.register(KernelEvent(identifier: UInt(SIGUSR1), filter: .signal, flags: .add))

    // The filter reports only signals sent to the process, not to a thread.
    kill(getpid(), SIGUSR1)
    let event = try XCTUnwrap(try poll(queue, timeout: .seconds(hangGuardSeconds)).first)
    XCTAssertEqual(event.identifier, UInt(SIGUSR1))
    XCTAssertEqual(event.data, 1, "the number of times the signal arrived")
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testProcessExit() throws {
    // The child waits for its standard input to close, so it can't exit
    // before the queue watches it.
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    let child = try spawn(["/bin/sh", "-c", "read line; exit 3"], standardInput: readEnd)
    try readEnd.close()

    let queue = try KernelQueue()
    try queue.register(KernelEvent(
      identifier: UInt(child.rawValue), filter: .process, flags: [.add, .oneShot],
      filterFlags: [.processExit, .processExitStatus]))
    try writeEnd.close()

    let event = try XCTUnwrap(try poll(queue, timeout: .seconds(hangGuardSeconds)).first)
    XCTAssertEqual(event.identifier, UInt(child.rawValue))
    XCTAssertTrue(event.filterFlags.contains(.processExit))
    XCTAssertEqual(event.data, 3 << 8, "the wait status of `exit 3`")

    // Watching a process doesn't reap it.
    var status: CInt = 0
    XCTAssertEqual(waitpid(child.rawValue, &status, 0), child.rawValue)
    XCTAssertEqual(status, 3 << 8)
  }
  #endif

  func testEquality() {
    let event = KernelEvent(identifier: 1, filter: .read, flags: .add, data: 2, userData: tag)
    XCTAssertEqual(event, KernelEvent(rawValue: event.rawValue))
    var other = event
    other.userData = nil
    XCTAssertNotEqual(event, other)
    XCTAssertEqual(Set([event, event, other]).count, 2)
  }

  func testFileDescriptorIdentifier() {
    let event = KernelEvent(FileDescriptor(rawValue: -1), filter: .read)
    XCTAssertEqual(event.identifier, UInt.max)
    XCTAssertEqual(event.fileDescriptor, FileDescriptor(rawValue: -1))
    XCTAssertEqual(KernelEvent(.standardError, filter: .write).identifier, 2)
  }

  func testDescriptions() {
    XCTAssertEqual(KernelEvent.Flags([.add, .clear]).description, "[.add, .clear]")
    XCTAssertEqual(KernelEvent.Flags([]).description, "[]")
    XCTAssertEqual(KernelEvent.Filter.read.description, "read")
    XCTAssertEqual(KernelEvent.Filter.user.description, "user")
    XCTAssertEqual(
      KernelEvent.Filter(rawValue: -100).description, "Filter(rawValue: -100)")
    XCTAssertEqual(
      KernelEvent(identifier: 4, filter: .read, flags: .add, data: 3).description,
      "KernelEvent(identifier: 4, filter: read, flags: [.add], "
        + "filterFlags: 0x0, data: 3, userData: nil)")
  }
}

// MARK: - Helpers

/// Polls `queue` into a new array with room for `capacity` events.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
internal func poll(
  _ queue: borrowing KernelQueue, capacity: Int = 8, timeout: Duration? = .zero
) throws -> [KernelEvent] {
  try [KernelEvent](unsafeUninitializedCapacity: capacity) { buffer, count in
    var output = OutputSpan(buffer: buffer, initializedCount: 0)
    try queue.poll(into: &output, timeout: timeout)
    count = output.finalize(for: buffer)
  }
}

/// Registers `changes` with `queue`, and polls it into a new array with
/// room for `capacity` events.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
internal func registerAndPoll(
  _ queue: borrowing KernelQueue, _ changes: [KernelEvent],
  capacity: Int = 8, timeout: Duration? = .zero
) throws -> [KernelEvent] {
  try changes.withUnsafeBufferPointer { changes in
    try [KernelEvent](unsafeUninitializedCapacity: capacity) { buffer, count in
      var output = OutputSpan(buffer: buffer, initializedCount: 0)
      try queue.registerAndPoll(
        Span(_unsafeElements: changes), into: &output, timeout: timeout)
      count = output.finalize(for: buffer)
    }
  }
}

#if SYSTEM_PACKAGE_DARWIN
/// Spawns `arguments`, with `standardInput` as the child's standard input,
/// and returns its process ID. The child inherits no other descriptors.
@available(System 199, *)
internal func spawn(
  _ arguments: [String], standardInput: borrowing OwnedFD
) throws -> ProcessID {
  var attributes: posix_spawnattr_t? = nil
  posix_spawnattr_init(&attributes)
  defer { posix_spawnattr_destroy(&attributes) }
  posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))

  var actions: posix_spawn_file_actions_t? = nil
  posix_spawn_file_actions_init(&actions)
  defer { posix_spawn_file_actions_destroy(&actions) }
  posix_spawn_file_actions_adddup2(&actions, standardInput.fileDescriptor.rawValue, 0)
  posix_spawn_file_actions_adddup2(&actions, 1, 1)
  posix_spawn_file_actions_adddup2(&actions, 2, 2)

  let argv = arguments.map { strdup($0) } + [nil]
  defer { argv.forEach { free($0) } }
  let environment: [UnsafeMutablePointer<CChar>?] = [nil]
  var pid: pid_t = 0
  let error = posix_spawn(&pid, arguments[0], &actions, &attributes, argv, environment)
  guard error == 0 else { throw Errno(rawValue: error) }
  return ProcessID(rawValue: pid)
}
#endif
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
