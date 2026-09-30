/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: thread cancellation. Each test cancels, or changes the
// cancellation of, a thread of its own, since swift-testing runs tests in
// parallel on threads that other tests share. No test waits for time: a
// thread signals when it's ready, and the test cancels it then, whatever the
// thread has reached, since cancellation stays pending until a cancellation
// point with cancellation enabled.

#if !os(Windows) && !os(WASI) && !os(Android)

import Testing
import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

/// Opens a latch when it's destroyed. As a thread-specific value, it's
/// destroyed when its thread ends, however the thread ends.
@available(System 199, *)
private final class OpensWhenDestroyed: Sendable {
  let latch: Latch
  init(_ latch: Latch) { self.latch = latch }
  deinit { latch.open() }
}

/// A key that a thread's closure can capture, which it can't capture as a
/// noncopyable value. A cancelled thread's closure leaks, as
/// PThread.ID.cancel() says, so the key does too.
@available(System 199, *)
private final class EndWatch: @unchecked Sendable {
  let key = try! PThread.Key<OpensWhenDestroyed>()
}

@Suite("PThread cancellation")
private struct PThreadCancellationTests {
  /// Reads one byte from a pipe: a cancellation point, which blocks until
  /// the test writes.
  @available(System 199, *)
  static func readByte(_ fd: FileDescriptor) -> Int {
    var byte: UInt8 = 0
    return (try? withUnsafeMutableBytes(of: &byte) { try fd.read(into: $0) }) ?? -1
  }

  /// The calling thread's cancellation state, read by setting it to itself.
  @available(System 199, *)
  static func state() -> CInt {
    let state = PThread._disableCancellation()
    PThread._restoreCancellation(state)
    return state
  }

  /// A thread cancelled in the scope finishes it, through a cancellation
  /// point that blocks until after the cancel, and ends at the first
  /// cancellation point after the scope.
  @available(System 199, *)
  @Test func aDisabledScopeFinishesAndTheNextPointEndsTheThread() throws {
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    defer {
      try? readEnd.close()
      try? writeEnd.close()
    }
    let ready = Latch()
    let steps = Locked<[String]>([])
    let thread = try PThread {
      PThread.withCancellationDisabled {
        ready.open()
        let count = Self.readByte(readEnd)
        steps.withValue { $0.append("read \(count)") }
      }
      steps.withValue { $0.append("after the scope") }
      PThread.testCancellation()
      steps.withValue { $0.append("after testCancellation") }
    }
    #expect(ready.wait())
    try thread.id.cancel()
    try writeEnd.writeAll([7])
    try thread.join()
    #expect(steps.value == ["read 1", "after the scope"])
  }

  /// A thread blocked in a read, with cancellation enabled, ends there.
  @available(System 199, *)
  @Test func aCancelledReadEndsTheThread() throws {
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    defer {
      try? readEnd.close()
      try? writeEnd.close()
    }
    let ready = Latch()
    let ended = Latch()
    let steps = Locked<[String]>([])
    let watch = EndWatch()
    let thread = try PThread {
      try! watch.key.setValue(OpensWhenDestroyed(ended))
      ready.open()
      let count = Self.readByte(readEnd)
      steps.withValue { $0.append("read \(count)") }
    }
    #expect(ready.wait())
    try thread.id.cancel()
    // If the cancel didn't end the read, a byte ends it, and the test fails
    // instead of hanging.
    let endedByCancel = ended.wait()
    if !endedByCancel {
      try writeEnd.writeAll([7])
    }
    try thread.join()
    #expect(endedByCancel)
    #expect(steps.value.isEmpty)
  }

  /// The scope restores the state it found: disabled after an inner scope,
  /// and enabled after the outer one and after a body that throws.
  @available(System 199, *)
  @Test func theScopeRestoresThePreviousState() throws {
    struct Failure: Error {}
    let states = Locked<[CInt]>([])
    let thread = try PThread {
      var seen = [Self.state()]
      PThread.withCancellationDisabled {
        seen.append(Self.state())
        PThread.withCancellationDisabled { seen.append(Self.state()) }
        seen.append(Self.state())
      }
      seen.append(Self.state())
      do {
        try PThread.withCancellationDisabled { throw Failure() }
      } catch {}
      seen.append(Self.state())
      states.withValue { $0 = seen }
    }
    try thread.join()
    let enabled = _PTHREAD_CANCEL_ENABLE
    let disabled = _PTHREAD_CANCEL_DISABLE
    #expect(states.value == [enabled, disabled, disabled, disabled, enabled, enabled])
  }

  /// The scope returns its body's value, and testCancellation returns on a
  /// thread that no one cancelled.
  @available(System 199, *)
  @Test func uncancelledThreadsRunOn() throws {
    let result = Locked(0)
    let thread = try PThread {
      PThread.testCancellation()
      let value = PThread.withCancellationDisabled { 42 }
      PThread.testCancellation()
      result.withValue { $0 = value }
    }
    try thread.join()
    #expect(result.value == 42)
  }
}

#if ENABLE_MOCKING
@available(System 199, *)
final class PThreadCancellationMockTests: XCTestCase {
  // pthread functions never fail with EINTR, so a forced EINTR is thrown,
  // never retried.
  func testCancel() {
    let id = PThread.ID.current
    MockTestCase(name: "pthread_cancel", .noInterrupt, id.rawValue) { _ in
      try id.cancel()
    }.runAllTests()
  }

  /// The scope disables cancellation and then sets back the state it found,
  /// and a forced error, which only a bad state can give, doesn't stop the
  /// body.
  func testWithCancellationDisabled() {
    MockingDriver.withMockingEnabled { mocking in
      XCTAssertEqual(PThread.withCancellationDisabled { 42 }, 42)
      let disable = mocking.trace.dequeue()
      XCTAssertEqual(disable?.name, "pthread_setcancelstate")
      XCTAssertEqual(disable?.arguments.first, AnyHashable(_PTHREAD_CANCEL_DISABLE))
      let restore = mocking.trace.dequeue()
      XCTAssertEqual(restore?.name, "pthread_setcancelstate")
      // The mock doesn't report the state, so what's restored is the
      // default the call starts from, enabled.
      XCTAssertEqual(restore?.arguments.first, AnyHashable(_PTHREAD_CANCEL_ENABLE))
      XCTAssertTrue(mocking.trace.isEmpty)

      mocking.forceErrno = .always(errno: EINVAL)
      XCTAssertEqual(PThread.withCancellationDisabled { 7 }, 7)
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_setcancelstate")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_setcancelstate")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
}
#endif // ENABLE_MOCKING

#endif // !os(Windows) && !os(WASI) && !os(Android)
