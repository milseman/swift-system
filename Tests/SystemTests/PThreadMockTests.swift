/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the PThread wrappers, checked against the calls they make.
// pthread functions never fail with EINTR, so every case is .noInterrupt:
// a forced EINTR is thrown, never retried. The objects the cases use are
// created before mocking starts and destroyed after it ends, so that their
// initialization and destruction are real.

#if ENABLE_MOCKING && !os(Windows) && !os(WASI)

import XCTest

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

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class PThreadMockTests: XCTestCase {
  // Noncopyable owners can't be captured by MockTestCase's escaping
  // closures, so the cases reach them through a class.
  final class Objects: @unchecked Sendable {
    let mutex = try! PThread.Mutex()
    let condition = try! PThread.Condition()
    let lock = try! PThread.ReadWriteLock()
    let key = try! PThread.Key<Int>()
  }

  func testSyscalls() {
    let objects = Objects()
    let id = PThread.ID.current
    var syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "pthread_mutex_lock", .noInterrupt, objects.mutex.unsafeAddress) { _ in
        try objects.mutex.lock()
      },
      MockTestCase(name: "pthread_mutex_trylock", .noInterrupt, objects.mutex.unsafeAddress) {
        _ in
        _ = try objects.mutex.tryLock()
      },
      MockTestCase(name: "pthread_mutex_unlock", .noInterrupt, objects.mutex.unsafeAddress) {
        _ in
        try objects.mutex.unlock()
      },
      MockTestCase(
        name: "pthread_cond_wait", .noInterrupt,
        objects.condition.unsafeAddress, objects.mutex.unsafeAddress
      ) { _ in
        try objects.condition.wait(on: objects.mutex)
      },
      MockTestCase(
        name: "pthread_cond_timedwait", .noInterrupt,
        objects.condition.unsafeAddress, objects.mutex.unsafeAddress, 1, 2
      ) { _ in
        _ = try objects.condition.wait(on: objects.mutex, until: timespec(tv_sec: 1, tv_nsec: 2))
      },
      MockTestCase(name: "pthread_cond_signal", .noInterrupt, objects.condition.unsafeAddress) {
        _ in
        try objects.condition.signal()
      },
      MockTestCase(name: "pthread_cond_broadcast", .noInterrupt, objects.condition.unsafeAddress) {
        _ in
        try objects.condition.broadcast()
      },
      MockTestCase(name: "pthread_rwlock_rdlock", .noInterrupt, objects.lock.unsafeAddress) { _ in
        try objects.lock.lockForReading()
      },
      MockTestCase(name: "pthread_rwlock_tryrdlock", .noInterrupt, objects.lock.unsafeAddress) {
        _ in
        _ = try objects.lock.tryLockForReading()
      },
      MockTestCase(name: "pthread_rwlock_wrlock", .noInterrupt, objects.lock.unsafeAddress) { _ in
        try objects.lock.lockForWriting()
      },
      MockTestCase(name: "pthread_rwlock_trywrlock", .noInterrupt, objects.lock.unsafeAddress) {
        _ in
        _ = try objects.lock.tryLockForWriting()
      },
      MockTestCase(name: "pthread_rwlock_unlock", .noInterrupt, objects.lock.unsafeAddress) { _ in
        try objects.lock.unlock()
      },
      // The key has no value on this thread, so setting nil releases nothing.
      MockTestCase(name: "pthread_setspecific", .noInterrupt, objects.key._rawValue, Wildcard()) {
        _ in
        try objects.key.setValue(nil)
      },
      MockTestCase(name: "pthread_getschedparam", .noInterrupt, id.rawValue, Wildcard(), Wildcard()) {
        _ in
        _ = try id.scheduling()
      },
      MockTestCase(name: "pthread_setschedparam", .noInterrupt, id.rawValue, SCHED_RR, CInt(20)) {
        _ in
        try id.setScheduling(PThread.Scheduling(policy: .roundRobin, priority: 20))
      },
    ]

    #if !os(Android)
    syscallTestCases += [
      MockTestCase(
        name: "pthread_mutex_getprioceiling", .noInterrupt, objects.mutex.unsafeAddress, Wildcard()
      ) { _ in
        _ = try objects.mutex.priorityCeiling()
      },
      MockTestCase(
        name: "pthread_mutex_setprioceiling", .noInterrupt,
        objects.mutex.unsafeAddress, CInt(30), Wildcard()
      ) { _ in
        _ = try objects.mutex.setPriorityCeiling(30)
      },
    ]
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    syscallTestCases += [
      // Darwin's pthread_setname_np names the calling thread, and sets errno.
      MockTestCase(name: "pthread_setname_np", .noInterrupt, "worker") { _ in
        try PThread.setCurrentName("worker")
      },
      MockTestCase(name: "pthread_getname_np", .noInterrupt, id.rawValue, Wildcard(), 64) { _ in
        _ = try id.name()
      },
      MockTestCase(
        name: "pthread_cond_timedwait_relative_np", .noInterrupt,
        objects.condition.unsafeAddress, objects.mutex.unsafeAddress, 0, 5_000_000
      ) { _ in
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
          _ = try objects.condition.wait(on: objects.mutex, timeout: .milliseconds(5))
        }
      },
      MockTestCase(
        name: "pthread_set_qos_class_self_np", .noInterrupt,
        QOS_CLASS_UTILITY.rawValue, CInt(-1)
      ) { _ in
        try PThread.setCurrentQoSClass(.utility, relativePriority: -1)
      },
      MockTestCase(
        name: "pthread_get_qos_class_np", .noInterrupt, id.rawValue, Wildcard(), Wildcard()
      ) { _ in
        _ = try id.qosClass()
      },
    ]
    #endif

    #if os(Linux) || os(Android) || os(FreeBSD)
    syscallTestCases += [
      MockTestCase(name: "pthread_setname_np", .noInterrupt, id.rawValue, "worker") { _ in
        try id.setName("worker")
      },
      MockTestCase(name: "pthread_getname_np", .noInterrupt, id.rawValue, Wildcard(), 64) { _ in
        _ = try id.name()
      },
    ]
    #endif

    #if !SYSTEM_PACKAGE_DARWIN
    syscallTestCases += [
      MockTestCase(name: "pthread_mutex_timedlock", .noInterrupt, objects.mutex.unsafeAddress, 1, 2) {
        _ in
        _ = try objects.mutex.lock(until: timespec(tv_sec: 1, tv_nsec: 2))
      }
    ]
    #endif

    #if os(Linux) || os(FreeBSD)
    syscallTestCases += [
      MockTestCase(name: "pthread_mutex_consistent", .noInterrupt, objects.mutex.unsafeAddress) {
        _ in
        try objects.mutex.markConsistent()
      }
    ]
    #endif

    #if os(Linux) || os(Android)
    let size = PThread.CPUSet.capacity / 8
    syscallTestCases += [
      MockTestCase(name: "sched_getaffinity", .noInterrupt, CInt(0), size, Wildcard()) { _ in
        _ = try PThread.currentAffinity()
      },
      MockTestCase(name: "sched_setaffinity", .noInterrupt, CInt(0), size, Wildcard()) { _ in
        try PThread.setCurrentAffinity([0])
      },
    ]
    #endif

    #if os(Linux)
    syscallTestCases += [
      MockTestCase(name: "pthread_getaffinity_np", .noInterrupt, id.rawValue, size, Wildcard()) {
        _ in
        _ = try id.affinity()
      },
      MockTestCase(name: "pthread_setaffinity_np", .noInterrupt, id.rawValue, size, Wildcard()) {
        _ in
        try id.setAffinity([0])
      },
    ]
    #endif

    for test in syscallTestCases { test.runAllTests() }
  }

  #if !SYSTEM_PACKAGE_DARWIN
  final class MonotonicCondition: @unchecked Sendable {
    let condition: PThread.Condition = {
      var attributes = PThread.Condition.Attributes()
      attributes.clock = .monotonic
      return try! PThread.Condition(attributes: attributes)
    }()
  }

  // Off Darwin, a relative wait reads the condition variable's clock, and
  // waits until the deadline that the timeout gives on it. The mocked
  // clock_gettime leaves the time it reads at zero, so the deadline is the
  // timeout.
  func testRelativeWaitReadsTheConditionsClock() throws {
    let objects = Objects()
    let monotonic = MonotonicCondition()
    let borrowed = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    defer { borrowed.deallocate() }
    // The try in XCTAssertThrowsError's argument makes the closure throwing.
    try MockingDriver.withMockingEnabled { mocking in
      func expectWait(
        clock: clockid_t, _ condition: UnsafeMutablePointer<CInterop.PThreadCondition>,
        until seconds: Int, _ nanoseconds: Int, line: UInt = #line
      ) {
        let read = mocking.trace.dequeue()
        XCTAssertTrue(
          read?.matches(Trace.Entry(name: "clock_gettime", [clock, Wildcard()])) ?? false,
          "\(String(describing: read))", line: line)
        let wait = mocking.trace.dequeue()
        XCTAssertTrue(
          wait?.matches(
            Trace.Entry(
              name: "pthread_cond_timedwait",
              [condition, objects.mutex.unsafeAddress, seconds, nanoseconds])) ?? false,
          "\(String(describing: wait))", line: line)
      }

      _ = try? objects.condition.wait(on: objects.mutex, timeout: .milliseconds(5))
      expectWait(clock: _CLOCK_REALTIME, objects.condition.unsafeAddress, until: 0, 5_000_000)
      _ = try? monotonic.condition.wait(on: objects.mutex, timeout: .seconds(2))
      expectWait(clock: _CLOCK_MONOTONIC, monotonic.condition.unsafeAddress, until: 2, 0)
      PThread.Condition.withUnsafeCondition(at: borrowed, clock: .monotonic) { condition in
        _ = try? condition.wait(on: objects.mutex, timeout: .seconds(-1))
      }
      expectWait(clock: _CLOCK_MONOTONIC, borrowed, until: 0, 0)
      XCTAssertTrue(mocking.trace.isEmpty)

      // An error reading the clock is thrown, without a wait.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertThrowsError(try objects.condition.wait(on: objects.mutex, timeout: .seconds(1))) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "clock_gettime")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif

  // MARK: Threads

  func testCreateFailureReleasesTheBody() {
    final class Canary: Sendable {}
    weak var weakCanary: Canary?
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EAGAIN)
      do throws(Errno) {
        let canary = Canary()
        weakCanary = canary
        let thread = try PThread { _ = canary }
        XCTFail("creating the thread should have thrown")
        try? thread.detach()
      } catch {
        XCTAssertEqual(error, .resourceTemporarilyUnavailable)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_create")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
    XCTAssertNil(weakCanary)
  }

  func testCreateUnderMocking() throws {
    // A mocked pthread_create starts no thread, and reports the calling
    // thread as the new one.
    try MockingDriver.withMockingEnabled { mocking in
      let thread = try PThread { XCTFail("a mocked thread shouldn't run") }
      XCTAssertEqual(thread.id, .current)
      try thread.detach()
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_create")
      let detach = mocking.trace.dequeue()
      XCTAssertEqual(detach?.name, "pthread_detach")
      XCTAssertEqual(detach?.arguments, [PThread.ID.current.rawValue])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testCreateWithAttributes() throws {
    var attributes = PThread.Attributes()
    attributes.stackSize = 1 << 20
    try MockingDriver.withMockingEnabled { mocking in
      let thread = try PThread(attributes: attributes) {}
      try thread.detach()
      let create = mocking.trace.dequeue()
      XCTAssertEqual(create?.name, "pthread_create")
      // The attributes are passed, rather than NULL.
      XCTAssertNotEqual(
        create?.arguments[1], AnyHashable(Optional<UnsafePointer<pthread_attr_t>>.none))
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_detach")
    }
  }

  func testJoinAndDetach() throws {
    let finished = Latch()
    let id = try PThread { finished.open() }.relinquish()
    XCTAssertTrue(finished.wait())
    defer { try? PThread(taking: id).join() }

    MockTestCase(name: "pthread_join", .noInterrupt, id.rawValue) { _ in
      try PThread(taking: id).join()
    }.runAllTests()
    MockTestCase(name: "pthread_detach", .noInterrupt, id.rawValue) { _ in
      try PThread(taking: id).detach()
    }.runAllTests()

    // Destroying the owner joins.
    MockingDriver.withMockingEnabled { mocking in
      _ = PThread(taking: id)
      let join = mocking.trace.dequeue()
      XCTAssertEqual(join?.name, "pthread_join")
      XCTAssertEqual(join?.arguments, [id.rawValue])
      XCTAssertTrue(mocking.trace.isEmpty)
    }

    // A join that reports a deadlock detaches the thread, which is still
    // running.
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EDEADLK, count: 1)
      do throws(Errno) {
        try PThread(taking: id).join()
        XCTFail("joining should have thrown")
      } catch {
        XCTAssertEqual(error, .deadlock)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_join")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_detach")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testJoinOnTheCallingThreadDoesNotCallJoin() {
    MockingDriver.withMockingEnabled { mocking in
      do throws(Errno) {
        try PThread(taking: .current).join()
        XCTFail("joining the calling thread should have thrown")
      } catch {
        XCTAssertEqual(error, .deadlock)
      }
      // pthread_join isn't called: Musl would wait forever.
      let detach = mocking.trace.dequeue()
      XCTAssertEqual(detach?.name, "pthread_detach")
      XCTAssertEqual(detach?.arguments, [PThread.ID.current.rawValue])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  // MARK: Creating and destroying objects

  func testMutexLifecycle() throws {
    try MockingDriver.withMockingEnabled { mocking in
      do {
        let mutex = try PThread.Mutex()
        _ = mutex.unsafeAddress
      } catch {
        XCTFail("\(error)")
      }
      let initialize = mocking.trace.dequeue()
      XCTAssertEqual(initialize?.name, "pthread_mutex_init")
      // The default attributes pass NULL.
      XCTAssertEqual(
        initialize?.arguments[1],
        AnyHashable(Optional<UnsafePointer<pthread_mutexattr_t>>.none))
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_mutex_destroy")
      XCTAssertTrue(mocking.trace.isEmpty)

      // A failed init destroys nothing.
      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      XCTAssertThrowsError(try PThread.Mutex(attributes: .init(kind: .errorChecking)).unsafeAddress) {
        XCTAssertEqual($0 as? Errno, .resourceTemporarilyUnavailable)
      }
      let failed = mocking.trace.dequeue()
      XCTAssertEqual(failed?.name, "pthread_mutex_init")
      XCTAssertNotEqual(
        failed?.arguments[1],
        AnyHashable(Optional<UnsafePointer<pthread_mutexattr_t>>.none))
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testConditionAndLockLifecycle() {
    MockingDriver.withMockingEnabled { mocking in
      _ = try? PThread.Condition()
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_cond_init")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_cond_destroy")
      _ = try? PThread.ReadWriteLock()
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_rwlock_init")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_rwlock_destroy")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testKeyLifecycle() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try? PThread.Key<Int>()
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_key_create")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_key_delete")
      XCTAssertTrue(mocking.trace.isEmpty)

      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      XCTAssertThrowsError(try PThread.Key<Int>().value()) {
        XCTAssertEqual($0 as? Errno, .resourceTemporarilyUnavailable)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pthread_key_create")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  // MARK: Scheduling

  func testPriorityRange() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try? PThread.SchedulingPolicy.fifo.priorityRange()
      let minimum = mocking.trace.dequeue()
      XCTAssertEqual(minimum?.name, "sched_get_priority_min")
      XCTAssertEqual(minimum?.arguments, [SCHED_FIFO])
      let maximum = mocking.trace.dequeue()
      XCTAssertEqual(maximum?.name, "sched_get_priority_max")
      XCTAssertEqual(maximum?.arguments, [SCHED_FIFO])

      // These report errors through errno.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertThrowsError(try PThread.SchedulingPolicy.fifo.priorityRange()) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "sched_get_priority_min")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
}

#endif // ENABLE_MOCKING && !os(Windows) && !os(WASI)
