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

  #if SYSTEM_PACKAGE_DARWIN
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
    // Darwin waits forever for a negative relative timeout (V16k), so the
    // wrapper times out at once instead.
    let queue = Queue()
    try queue.mutex.lock()
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .zero) == false)
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .seconds(-1)) == false)
    #expect(try queue.workAvailable.wait(on: queue.mutex, timeout: .nanoseconds(-5)) == false)
    try queue.mutex.unlock()
  }
  #else
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
