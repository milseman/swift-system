/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// epoll, eventfd, and timerfd. Nothing on macOS compiles these tests;
// Prototype/Events/check-linux.sh typechecks them there against a model of
// the C declarations.
#if os(Linux) || os(Android)

import XCTest

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
// On glibc, SystemPackage's module refers to CSystem's copy of sigset_t,
// which EventPoll's wait(into:timeout:signalMask:retryOnInterrupt:) takes,
// so a client that builds a mask can't see its initializer without
// importing CSystem. The tests work around that; clients can't.
import CSystem

@available(System 199, *)
final class EventPollTests: XCTestCase {
  func testReadablePipe() throws {
    let epoll = try EventPoll(options: .closeOnExec)
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd.fileDescriptor
    try epoll.add(readEnd, events: .readable, data: .fileDescriptor(readEnd))
    XCTAssertEqual(try readyEvents(epoll), [])

    try pipe.writeEnd.writeAll("abc".utf8)
    let event = try XCTUnwrap(try readyEvents(epoll).first)
    XCTAssertEqual(event.events, .readable)
    XCTAssertEqual(event.data.fileDescriptor, readEnd)
  }

  func testAddModifyRemove() throws {
    let epoll = try EventPoll()
    let pipe = try OwnedFD.pipe()
    let writeEnd = pipe.writeEnd.fileDescriptor
    try epoll.add(writeEnd, events: .readable, data: EventData(rawValue: 1))
    assertThrows(.fileExists, "adding it twice") {
      try epoll.add(writeEnd, events: .readable, data: EventData(rawValue: 1))
    }
    XCTAssertEqual(try readyEvents(epoll), [], "a write end is never readable")

    try epoll.modify(writeEnd, events: .writable, data: EventData(rawValue: 2))
    XCTAssertEqual(
      try readyEvents(epoll), [EventPoll.Event(events: .writable, data: EventData(rawValue: 2))])

    try epoll.remove(writeEnd)
    XCTAssertEqual(try readyEvents(epoll), [])
    assertThrows(.noSuchFileOrDirectory, "removing it twice") {
      try epoll.remove(writeEnd)
    }
    assertThrows(.noSuchFileOrDirectory, "modifying it once removed") {
      try epoll.modify(writeEnd, events: .writable, data: EventData(rawValue: 2))
    }
  }

  func testHangUp() throws {
    let epoll = try EventPoll()
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try epoll.add(readEnd.fileDescriptor, events: .readable, data: EventData(rawValue: 0))
    try writeEnd.close()
    let event = try XCTUnwrap(try readyEvents(epoll).first)
    XCTAssertTrue(event.events.contains(.hangUp), "reported whether or not it's asked for")
  }

  func testEdgeTriggeredAndOneShot() throws {
    let epoll = try EventPoll()
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd.fileDescriptor
    try epoll.add(readEnd, events: [.readable, .edgeTriggered], data: EventData(rawValue: 0))
    try pipe.writeEnd.writeAll("a".utf8)
    XCTAssertEqual(try readyEvents(epoll).count, 1)
    XCTAssertEqual(try readyEvents(epoll), [], "reported once, though still readable")
    try pipe.writeEnd.writeAll("b".utf8)
    XCTAssertEqual(try readyEvents(epoll).count, 1, "reported again on new data")

    try epoll.modify(readEnd, events: [.readable, .oneShot], data: EventData(rawValue: 0))
    XCTAssertEqual(try readyEvents(epoll).count, 1)
    try pipe.writeEnd.writeAll("c".utf8)
    XCTAssertEqual(try readyEvents(epoll), [], "not watched again until modified")
  }

  func testFullSpanThrows() throws {
    let epoll = try EventPoll()
    withUnsafeTemporaryAllocation(of: EventPoll.Event.self, capacity: 1) { buffer in
      buffer.initialize(repeating: EventPoll.Event(events: [], data: EventData(rawValue: 0)))
      var events = OutputSpan(buffer: buffer, initializedCount: 1)
      do {
        try epoll.wait(into: &events, timeout: .zero)
        XCTFail("expected invalidArgument")
      } catch {
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      _ = events.finalize(for: buffer)
    }
  }

  func testTimeout() throws {
    let epoll = try EventPoll()
    let start = ContinuousClock.now
    XCTAssertEqual(try readyEvents(epoll, timeout: .milliseconds(20)), [])
    XCTAssertGreaterThanOrEqual(ContinuousClock.now - start, .milliseconds(15))
  }

  func testWaitWithSignalMask() throws {
    let epoll = try EventPoll()
    let counter = try EventCounter(initialValue: 1)
    try epoll.add(counter.fileDescriptor, events: .readable, data: EventData(rawValue: 9))
    var mask = sigset_t()
    sigemptyset(&mask)
    let events = try [EventPoll.Event](unsafeUninitializedCapacity: 4) { buffer, count in
      var output = OutputSpan(buffer: buffer, initializedCount: 0)
      try epoll.wait(into: &output, timeout: .zero, signalMask: mask)
      count = output.finalize(for: buffer)
    }
    XCTAssertEqual(events.map(\.data), [EventData(rawValue: 9)])
  }

  func testData() {
    let fd = FileDescriptor(rawValue: 42)
    XCTAssertEqual(EventData.fileDescriptor(fd).fileDescriptor, fd)
    let pointer = UnsafeMutableRawPointer(bitPattern: 0x1234)
    XCTAssertEqual(EventData.pointer(pointer).pointer, pointer)
    XCTAssertEqual(EventData(rawValue: .max).rawValue, .max)
  }

  func testDescriptions() {
    XCTAssertEqual(EventPoll.Event.Mask([.readable, .edgeTriggered]).description,
      "[.readable, .edgeTriggered]")
    XCTAssertEqual(
      EventPoll.Event(events: .writable, data: EventData(rawValue: 255)).description,
      "EventPoll.Event(events: [.writable], data: 0xff)")
  }

  // MARK: eventfd

  func testCounter() throws {
    let counter = try EventCounter(options: .nonBlocking)
    assertThrows(.resourceTemporarilyUnavailable, "a counter of zero") {
      _ = try counter.read()
    }
    try counter.increment()
    try counter.increment(by: 4)
    XCTAssertEqual(try counter.read(), 5)
    assertThrows(.resourceTemporarilyUnavailable, "reading resets it") {
      _ = try counter.read()
    }
  }

  func testSemaphore() throws {
    let counter = try EventCounter(initialValue: 2, options: [.semaphore, .nonBlocking])
    XCTAssertEqual(try counter.read(), 1)
    XCTAssertEqual(try counter.read(), 1)
    assertThrows(.resourceTemporarilyUnavailable) { _ = try counter.read() }
  }

  func testCounterWakesEventPoll() throws {
    let epoll = try EventPoll()
    let counter = try EventCounter(options: .nonBlocking)
    try epoll.add(
      counter.fileDescriptor, events: .readable,
      data: .fileDescriptor(counter.fileDescriptor))
    XCTAssertEqual(try readyEvents(epoll), [])
    try counter.increment()
    XCTAssertEqual(try readyEvents(epoll).first?.data.fileDescriptor, counter.fileDescriptor)
  }

  // MARK: timerfd

  func testOneShotTimer() throws {
    let timer = try IntervalTimer(clock: .monotonic, options: .closeOnExec)
    XCTAssertEqual(try timer.schedule(), .disarmed)
    let previous = try timer.setSchedule(.init(nextExpiration: .milliseconds(10)))
    XCTAssertEqual(previous, .disarmed)
    let running = try timer.schedule()
    XCTAssertGreaterThan(running.nextExpiration, .zero)
    XCTAssertLessThanOrEqual(running.nextExpiration, .milliseconds(10))
    XCTAssertEqual(running.interval, .zero)

    XCTAssertEqual(try timer.readExpirations(), 1)
    XCTAssertEqual(try timer.schedule(), .disarmed, "a one-shot timer stops")
  }

  func testRepeatingTimerWithEventPoll() throws {
    let epoll = try EventPoll()
    let timer = try IntervalTimer(options: .nonBlocking)
    assertThrows(.resourceTemporarilyUnavailable, "before it's set") {
      _ = try timer.readExpirations()
    }
    try epoll.add(timer.fileDescriptor, events: .readable, data: EventData(rawValue: 1))
    try timer.setSchedule(
      .init(nextExpiration: .milliseconds(2), interval: .milliseconds(2)))
    XCTAssertEqual(try readyEvents(epoll, timeout: .seconds(10)).first?.data, EventData(rawValue: 1))
    usleep(20_000)
    XCTAssertGreaterThan(try timer.readExpirations(), 1)

    let previous = try timer.setSchedule(.disarmed)
    XCTAssertEqual(previous.interval, .milliseconds(2))
  }

  func testSchedule() {
    var schedule = IntervalTimer.Schedule(
      nextExpiration: .seconds(1) + .nanoseconds(5), interval: .milliseconds(3))
    XCTAssertEqual(schedule.nextExpiration, .seconds(1) + .nanoseconds(5))
    XCTAssertEqual(schedule.interval, .milliseconds(3))
    schedule.nextExpiration = Duration(secondsComponent: 0, attosecondsComponent: 1)
    XCTAssertEqual(
      schedule.nextExpiration, .nanoseconds(1),
      "a positive time rounds up, so that it doesn't stop the timer")
    schedule.nextExpiration = .seconds(-1)
    XCTAssertEqual(schedule.nextExpiration, .zero)
  }

  // MARK: Mocks

  #if ENABLE_MOCKING
  // The mocks record each call's arguments. epoll_ctl records the event's
  // mask and 64 bits of data; timerfd_settime records the new schedule's
  // seconds and nanoseconds.
  func testSyscalls() {
    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "epoll_create1", .noInterrupt, _EPOLL_CLOEXEC) { _ in
        _ = try EventPoll(options: .closeOnExec).relinquish()
      },

      MockTestCase(
        name: "epoll_ctl", .noInterrupt, 42, _EPOLL_CTL_ADD, 7, _EPOLLIN | _EPOLLET, 7 as UInt64
      ) { _ in
        try withEventPoll {
          try $0.add(
            FileDescriptor(rawValue: 7), events: [.readable, .edgeTriggered],
            data: EventData(rawValue: 7))
        }
      },

      MockTestCase(name: "epoll_ctl", .noInterrupt, 42, _EPOLL_CTL_MOD, 7, _EPOLLOUT, 8 as UInt64) {
        _ in
        try withEventPoll {
          try $0.modify(FileDescriptor(rawValue: 7), events: .writable, data: EventData(rawValue: 8))
        }
      },

      MockTestCase(name: "epoll_ctl", .noInterrupt, 42, _EPOLL_CTL_DEL, 7, 0 as UInt32, 0 as UInt64) {
        _ in
        try withEventPoll { try $0.remove(FileDescriptor(rawValue: 7)) }
      },

      MockTestCase(name: "epoll_wait", .interruptable, 42, 4, 1500) { retryOnInterrupt in
        try withEventPoll {
          _ = try readyEvents(
            $0, timeout: .milliseconds(1500), retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "epoll_pwait", .interruptable, 42, 4, -1, Wildcard()) {
        retryOnInterrupt in
        try withEventPoll { epoll in
          var mask = sigset_t()
          sigemptyset(&mask)
          try withUnsafeTemporaryAllocation(of: EventPoll.Event.self, capacity: 4) { buffer in
            var events = OutputSpan(buffer: buffer, initializedCount: 0)
            try epoll.wait(
              into: &events, timeout: nil, signalMask: mask,
              retryOnInterrupt: retryOnInterrupt)
            _ = events.finalize(for: buffer)
          }
        }
      },

      MockTestCase(name: "eventfd", .noInterrupt, 3 as CUnsignedInt, _EFD_NONBLOCK | _EFD_SEMAPHORE) {
        _ in
        _ = try EventCounter(initialValue: 3, options: [.nonBlocking, .semaphore]).relinquish()
      },

      MockTestCase(name: "write", .interruptable, 42, Wildcard(), 8) { retryOnInterrupt in
        try withCounter { try $0.increment(by: 2, retryOnInterrupt: retryOnInterrupt) }
      },

      MockTestCase(name: "read", .interruptable, 42, Wildcard(), 8) { retryOnInterrupt in
        try withCounter { _ = try $0.read(retryOnInterrupt: retryOnInterrupt) }
      },

      MockTestCase(name: "timerfd_create", .noInterrupt, _CLOCK_BOOTTIME, _TFD_CLOEXEC) { _ in
        _ = try IntervalTimer(clock: .boottime, options: .closeOnExec).relinquish()
      },

      MockTestCase(
        name: "timerfd_settime", .noInterrupt, 42, _TFD_TIMER_ABSTIME, 1, 500_000_000, 0, 1_000
      ) { _ in
        try withTimer {
          try $0.setSchedule(
            .init(nextExpiration: .milliseconds(1500), interval: .microseconds(1)),
            options: .absolute)
        }
      },

      MockTestCase(name: "timerfd_gettime", .noInterrupt, 42) { _ in
        try withTimer { _ = try $0.schedule() }
      },

      MockTestCase(name: "read", .interruptable, 42, Wildcard(), 8) { retryOnInterrupt in
        try withTimer { _ = try $0.readExpirations(retryOnInterrupt: retryOnInterrupt) }
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif // ENABLE_MOCKING
}

private typealias EventData = EventPoll.Event.Data

/// Waits on `epoll` with room for four events.
@available(System 199, *)
private func readyEvents(
  _ epoll: borrowing EventPoll, timeout: Duration? = .zero, retryOnInterrupt: Bool = true
) throws -> [EventPoll.Event] {
  try [EventPoll.Event](unsafeUninitializedCapacity: 4) { buffer, count in
    var output = OutputSpan(buffer: buffer, initializedCount: 0)
    try epoll.wait(into: &output, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
    count = output.finalize(for: buffer)
  }
}

/// Calls `body` with an instance for the mock's descriptor, 42,
/// which the instance gives up afterward so that it isn't closed.
@available(System 199, *)
private func withEventPoll(_ body: (borrowing EventPoll) throws -> Void) throws {
  // A defer block can't consume the instance, so each path gives it up.
  let epoll = EventPoll(taking: FileDescriptor(rawValue: 42))
  do {
    try body(epoll)
  } catch {
    _ = epoll.relinquish()
    throw error
  }
  _ = epoll.relinquish()
}

/// Calls `body` with a counter for the mock's descriptor, 42.
@available(System 199, *)
private func withCounter(_ body: (borrowing EventCounter) throws -> Void) throws {
  let counter = EventCounter(taking: FileDescriptor(rawValue: 42))
  do {
    try body(counter)
  } catch {
    _ = counter.relinquish()
    throw error
  }
  _ = counter.relinquish()
}

/// Calls `body` with a timer for the mock's descriptor, 42.
@available(System 199, *)
private func withTimer(_ body: (borrowing IntervalTimer) throws -> Void) throws {
  let timer = IntervalTimer(taking: FileDescriptor(rawValue: 42))
  do {
    try body(timer)
  } catch {
    _ = timer.relinquish()
    throw error
  }
  _ = timer.relinquish()
}
#endif // os(Linux) || os(Android)
