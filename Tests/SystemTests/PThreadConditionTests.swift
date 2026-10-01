/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread.Condition against real condition variables.

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

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("PThread.Condition")
private struct PThreadConditionTests {
  // A queue of jobs, as in NIO's thread pool.
  @available(System 199, *)
  final class Queue: @unchecked Sendable {
    let mutex = try! PThread.Mutex()
    let workAvailable = try! PThread.Condition()
    var jobs: [Int] = []
    var done: [Int] = []
    var isShutDown = false

    // Runs jobs until the queue shuts down.
    func work() {
      try! mutex.withLock {
        while true {
          while jobs.isEmpty && !isShutDown {
            try workAvailable.wait(on: mutex)
          }
          guard let job = jobs.popLast() else { return }
          done.append(job)
        }
      }
    }
  }

  @available(System 199, *)
  @Test func signalWakesAWaiter() throws {
    let queue = Queue()
    let worker = try PThread { queue.work() }
    for job in 1...100 {
      try queue.mutex.withLock { queue.jobs.append(job) }
      try queue.workAvailable.signal()
    }
    try queue.mutex.withLock { queue.isShutDown = true }
    try queue.workAvailable.broadcast()
    try worker.join()
    #expect(queue.done.sorted() == Array(1...100))
  }

  @available(System 199, *)
  @Test func broadcastWakesEveryWaiter() throws {
    let queue = Queue()
    var workers: [PThread.ID] = []
    for _ in 0..<4 {
      workers.append(try PThread { queue.work() }.relinquish())
    }
    try queue.mutex.withLock {
      queue.jobs = Array(1...1000)
      queue.isShutDown = true
    }
    try queue.workAvailable.broadcast()
    for id in workers {
      try PThread(taking: id).join()
    }
    #expect(queue.done.sorted() == Array(1...1000))
  }

  @available(System 199, *)
  @Test func deadlineInThePast() throws {
    let queue = Queue()
    try queue.mutex.lock()
    #expect(try queue.workAvailable.wait(on: queue.mutex, until: timespec(tv_sec: 0, tv_nsec: 0)) == false)
    try queue.mutex.unlock()
  }

  @available(System 199, *)
  @Test func deadlinePasses() throws {
    let queue = Queue()
    let start = monotonicNanoseconds()
    try queue.mutex.lock()
    let deadline = realtimeDeadline(nanoseconds: 20_000_000)
    var signaled = true
    while signaled {
      signaled = try queue.workAvailable.wait(on: queue.mutex, until: deadline)
    }
    try queue.mutex.unlock()
    #expect(monotonicNanoseconds() - start >= 15_000_000)
  }

  @available(System 199, *)
  @Test func invalidDeadline() throws {
    let queue = Queue()
    try queue.mutex.lock()
    #expect(throws: Errno.invalidArgument) {
      try queue.workAvailable.wait(
        on: queue.mutex, until: timespec(tv_sec: 0, tv_nsec: 2_000_000_000))
    }
    try queue.mutex.unlock()
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timeout() throws {
    let queue = Queue()
    let start = monotonicNanoseconds()
    try queue.mutex.lock()
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .milliseconds(20)) == false)
    try queue.mutex.unlock()
    #expect(monotonicNanoseconds() - start >= 15_000_000)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timeoutThatIsNotPositive() throws {
    // Darwin waits forever for a negative relative timeout (T11), so the
    // wrapper times out at once instead; elsewhere the deadline is now.
    let queue = Queue()
    try queue.mutex.lock()
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .zero) == false)
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .seconds(-1)) == false)
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .nanoseconds(-5)) == false)
    try queue.mutex.unlock()
  }

  // A timeout too long for any test to reach: the wait ends when the
  // condition is signaled.
  @available(System 199, *)
  final class TimedWait: @unchecked Sendable {
    let mutex = try! PThread.Mutex()
    let waiterIsWaiting = try! PThread.Condition()
    let jobAdded = try! PThread.Condition()
    var isWaiting = false
    var jobs = 0
    var timedOut = false
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func signalEndsATimedWait() throws {
    let state = TimedWait()
    let waiter = try PThread {
      try! state.mutex.withLock {
        state.isWaiting = true
        try state.waiterIsWaiting.signal()
        while state.jobs == 0 {
          if try !state.jobAdded.wait(on: state.mutex, timeout: .seconds(hangGuardSeconds)) {
            state.timedOut = true
            return
          }
        }
      }
    }
    // The waiter holds the mutex from setting isWaiting until its wait
    // releases it, so once this thread has the mutex and sees isWaiting,
    // the waiter is waiting.
    try state.mutex.withLock {
      while !state.isWaiting {
        _ = try state.waiterIsWaiting.wait(on: state.mutex, timeout: .seconds(hangGuardSeconds))
      }
      state.jobs = 1
    }
    try state.jobAdded.signal()
    try waiter.join()
    #expect(state.jobs == 1)
    #expect(!state.timedOut)
  }

  #if !SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func monotonicClock() throws {
    var attributes = PThread.Condition.Attributes()
    attributes.clock = .monotonic
    let condition = try PThread.Condition(attributes: attributes)
    let mutex = try PThread.Mutex()
    var now = timespec()
    clock_gettime(CLOCK_MONOTONIC, &now)
    now.tv_nsec += 10_000_000
    if now.tv_nsec >= 1_000_000_000 { now.tv_sec += 1; now.tv_nsec -= 1_000_000_000 }
    try mutex.lock()
    var signaled = true
    while signaled {
      signaled = try condition.wait(on: mutex, until: now)
    }
    try mutex.unlock()
  }

  // A timeout on the monotonic clock, from a deadline on that clock: one on
  // the time of day would be decades past the monotonic clock's time, and
  // the wait wouldn't end.
  @available(System 199, *)
  @Test func timeoutOnTheMonotonicClock() throws {
    var attributes = PThread.Condition.Attributes()
    attributes.clock = .monotonic
    let condition = try PThread.Condition(attributes: attributes)
    let mutex = try PThread.Mutex()
    let start = monotonicNanoseconds()
    try mutex.lock()
    #expect(try condition.wait(on: mutex, timeout: .milliseconds(20)) == false)
    try mutex.unlock()
    #expect(monotonicNanoseconds() - start >= 15_000_000)
  }

  @available(System 199, *)
  @Test func timeoutOnABorrowedConditionsClock() throws {
    let address = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    defer { address.deallocate() }
    var attributes = pthread_condattr_t()
    #expect(pthread_condattr_init(&attributes) == 0)
    #expect(pthread_condattr_setclock(&attributes, CLOCK_MONOTONIC) == 0)
    #expect(pthread_cond_init(address, &attributes) == 0)
    #expect(pthread_condattr_destroy(&attributes) == 0)
    let mutex = try PThread.Mutex()
    let start = monotonicNanoseconds()
    let signaled = try PThread.Condition.withUnsafeCondition(
      at: address, clock: .monotonic
    ) { condition in
      try mutex.withLock {
        try condition.wait(on: mutex, timeout: .milliseconds(20))
      }
    }
    #expect(!signaled)
    #expect(monotonicNanoseconds() - start >= 15_000_000)
    #expect(pthread_cond_destroy(address) == 0)
  }

  @available(System 199, *)
  @Test func deadlineAfterATimeout() {
    let now = timespec(tv_sec: 100, tv_nsec: 999_999_999)
    let deadline = PThread.Condition._deadline(after: now, timeout: .milliseconds(2))
    #expect(deadline.tv_sec == 101 && deadline.tv_nsec == 1_999_999)
    // A part of a nanosecond rounds up.
    let rounded = PThread.Condition._deadline(after: now, timeout: .nanoseconds(1) / 2)
    #expect(rounded.tv_sec == 101 && rounded.tv_nsec == 0)
    let negative = PThread.Condition._deadline(after: now, timeout: .seconds(-5))
    #expect(negative.tv_sec == 100 && negative.tv_nsec == 999_999_999)
    // A deadline past time_t's last time is that time.
    let late = PThread.Condition._deadline(after: now, timeout: .seconds(Int64.max))
    #expect(late.tv_sec == .max && late.tv_nsec == 999_999_999)
  }
  #endif

  @available(System 199, *)
  @Test func defaultAttributes() {
    let attributes = PThread.Condition.Attributes()
    #expect(!attributes.isProcessShared)
    #if !SYSTEM_PACKAGE_DARWIN
    #expect(attributes.clock == .realtime)
    #endif
  }

  @available(System 199, *)
  @Test func processSharedConditionInSharedMemory() throws {
    typealias Shared = (CInterop.PThreadMutex, CInterop.PThreadCondition)
    let size = MemoryLayout<Shared>.size
    let memory = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0)
    try #require(memory != MAP_FAILED)
    defer { munmap(memory, size) }
    let mutexAddress = memory!.bindMemory(to: CInterop.PThreadMutex.self, capacity: 1)
    let conditionAddress = (memory! + MemoryLayout<Shared>.offset(of: \.1)!)
      .bindMemory(to: CInterop.PThreadCondition.self, capacity: 1)
    let mutex = try PThread.Mutex(
      unsafeUninitializedAddress: mutexAddress, attributes: .init(isProcessShared: true))
    let condition = try PThread.Condition(
      unsafeUninitializedAddress: conditionAddress, attributes: .init(isProcessShared: true))
    try mutex.lock()
    #expect(try condition.wait(on: mutex, until: timespec(tv_sec: 0, tv_nsec: 0)) == false)
    try mutex.unlock()
    try condition.signal()
  }

  @available(System 199, *)
  @Test func borrowingAConditionThatCOwns() throws {
    let address = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    defer { address.deallocate() }
    #expect(pthread_cond_init(address, nil) == 0)
    let mutex = try PThread.Mutex()
    let timedOut = try PThread.Condition.withUnsafeCondition(at: address) { condition in
      try mutex.withLock {
        try !condition.wait(on: mutex, until: timespec(tv_sec: 0, tv_nsec: 0))
      }
    }
    #expect(timedOut)
    #expect(pthread_cond_destroy(address) == 0)
  }
}

#endif // !os(Windows) && !os(WASI)
