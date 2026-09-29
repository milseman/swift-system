/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread, the owned thread, and PThread.ID. A test that
// changes a thread's name, scheduling, or quality of service does it on a
// thread of its own, since swift-testing runs tests in parallel on threads
// that other tests share.

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

@Suite("PThread")
private struct PThreadTests {

  // MARK: Creating and joining

  @available(System 199, *)
  @Test func joinWaitsForTheBody() throws {
    let result = Locked(0)
    let thread = try PThread {
      usleep(20_000)
      result.withValue { $0 = 42 }
    }
    try thread.join()
    #expect(result.value == 42)
  }

  @available(System 199, *)
  @Test func manyThreads() throws {
    // An Array can't hold noncopyable owners, so this one holds their IDs,
    // and each join takes ownership again.
    let total = Locked(0)
    var threads: [PThread.ID] = []
    for i in 1...16 {
      threads.append(try PThread { total.withValue { $0 += i } }.relinquish())
    }
    for id in threads {
      try PThread(taking: id).join()
    }
    #expect(total.value == (1...16).reduce(0, +))
  }

  @available(System 199, *)
  @Test func bodyIsReleasedOnTheThread() throws {
    final class Canary: @unchecked Sendable {}
    weak var weakCanary: Canary?
    let thread: PThread
    do {
      let canary = Canary()
      weakCanary = canary
      thread = try PThread { _ = canary }
    }
    try thread.join()
    #expect(weakCanary == nil)
  }

  // MARK: Identity

  @available(System 199, *)
  @Test func idOfTheThread() throws {
    let seen = Locked<PThread.ID?>(nil)
    let thread = try PThread { seen.withValue { $0 = .current } }
    let id = thread.id
    try thread.join()
    #expect(seen.value == id)
    #expect(id != .current)
    #expect(PThread.ID.current == PThread.ID.current)
    #expect(PThread.ID(rawValue: id.rawValue) == id)
    #expect(Set([id, id, PThread.ID.current]).count == 2)
  }

  // MARK: Destruction joins

  @available(System 199, *)
  @Test func deinitJoins() throws {
    let done = Locked(false)
    do {
      _ = try PThread {
        usleep(50_000)
        done.withValue { $0 = true }
      }
    }
    #expect(done.value)
  }

  @available(System 199, *)
  @Test func deinitJoinsWhenAnErrorEndsTheScope() throws {
    struct Stop: Error {}
    let done = Locked(false)
    func startAndThrow() throws {
      let thread = try PThread {
        usleep(50_000)
        done.withValue { $0 = true }
      }
      _ = thread.id
      throw Stop()
    }
    #expect(throws: Stop.self) { try startAndThrow() }
    #expect(done.value)
  }

  @available(System 199, *)
  @Test func deinitOnItsOwnThreadDetaches() throws {
    // The owner moves to its own thread, which destroys it. A joining deinit
    // would wait for itself forever; this one detaches instead.
    let slot = Slot()
    let ready = Latch()
    let destroyed = Latch()
    let tookOwner = Locked(false)
    let thread = try PThread {
      guard ready.wait() else { return }
      let owner = slot.take()
      tookOwner.withValue { $0 = owner != nil }
      _ = consume owner
      destroyed.open()
    }
    slot.put(thread)
    ready.open()
    #expect(destroyed.wait())
    #expect(tookOwner.value)
  }

  @available(System 199, *)
  @Test func joinOnItsOwnThreadDetachesAndThrows() throws {
    let slot = Slot()
    let ready = Latch()
    let finished = Latch()
    let result = Locked<Errno?>(nil)
    let thread = try PThread {
      guard ready.wait(), let owner = slot.take() else { return }
      do throws(Errno) {
        try owner.join()
      } catch {
        result.withValue { $0 = error }
      }
      finished.open()
    }
    slot.put(thread)
    ready.open()
    #expect(finished.wait())
    #expect(result.value == .deadlock)
  }

  // MARK: Detaching and ownership

  @available(System 199, *)
  @Test func detach() throws {
    let finished = Latch()
    let thread = try PThread { finished.open() }
    try thread.detach()
    #expect(finished.wait())
  }

  @available(System 199, *)
  @Test func relinquishAndTake() throws {
    let finished = Latch()
    let thread = try PThread { finished.open() }
    let id = thread.relinquish()
    #expect(finished.wait())
    // The thread finished but wasn't joined, so its ID is still valid.
    try PThread(taking: id).join()
  }

  // MARK: Attributes

  @available(System 199, *)
  @Test func defaultAttributes() {
    #expect(PThread.Attributes() == PThread.Attributes())
    #expect(PThread.Attributes().stackSize == nil)
    #expect(PThread.Attributes().guardSize == nil)
    #expect(PThread.Attributes().scheduling == nil)
  }

  @available(System 199, *)
  @Test func stackSize() throws {
    var attributes = PThread.Attributes()
    attributes.stackSize = 1 << 20
    attributes.guardSize = 1 << 16
    let stackSize = Locked(0)
    let thread = try PThread(attributes: attributes) {
      #if SYSTEM_PACKAGE_DARWIN
      stackSize.withValue { $0 = pthread_get_stacksize_np(pthread_self()) }
      #else
      stackSize.withValue { $0 = 1 << 20 }
      #endif
    }
    try thread.join()
    #expect(stackSize.value >= 1 << 20)
  }

  /// A thread without a stack size gets the default; Darwin's threads
  /// report at least as much.
  @available(System 199, *)
  @Test func defaultStackSize() throws {
    let size = try PThread.Attributes.defaultStackSize()
    #expect(size > 0)
    #expect(size % Int(getpagesize()) == 0)
    #if SYSTEM_PACKAGE_DARWIN
    let seen = Locked(0)
    let thread = try PThread { seen.withValue { $0 = pthread_get_stacksize_np(pthread_self()) } }
    try thread.join()
    #expect(seen.value >= size)
    #expect(size == 512 << 10)
    #endif
  }

  @available(System 199, *)
  @Test func invalidStackSize() {
    var attributes = PThread.Attributes()
    attributes.stackSize = 1
    let ran = Locked(false)
    #expect(throws: Errno.invalidArgument) {
      _ = try PThread(attributes: attributes) { ran.withValue { $0 = true } }
    }
    #expect(!ran.value)
  }

  @available(System 199, *)
  @Test func explicitScheduling() throws {
    let range = try PThread.SchedulingPolicy.other.priorityRange()
    #expect(range.lowerBound <= range.upperBound)
    var attributes = PThread.Attributes()
    attributes.scheduling = PThread.Scheduling(policy: .other, priority: range.lowerBound)
    let seen = Locked<PThread.Scheduling?>(nil)
    let thread = try PThread(attributes: attributes) {
      seen.withValue { $0 = try? PThread.ID.current.scheduling() }
    }
    try thread.join()
    #expect(seen.value == attributes.scheduling)
  }

  #if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func qualityOfServiceAttribute() throws {
    var attributes = PThread.Attributes()
    attributes.qosClass = .utility
    let seen = Locked<PThread.QoSClass?>(nil)
    let thread = try PThread(attributes: attributes) {
      seen.withValue { $0 = .current }
    }
    try thread.join()
    #expect(seen.value == .utility)
  }

  @available(System 199, *)
  @Test func setCurrentQualityOfService() throws {
    let seen = Locked<(PThread.QoSClass, CInt)?>(nil)
    let ready = Latch()
    let release = Latch()
    let thread = try PThread {
      try! PThread.setCurrentQoSClass(.background)
      ready.open()
      _ = release.wait()
    }
    do {
      defer { release.open() }
      #expect(ready.wait())
      seen.withValue { $0 = try? thread.id.qosClass() }
    }
    try thread.join()
    #expect(seen.value?.0 == .background)
    #expect(seen.value?.1 == 0)
  }

  #endif // SYSTEM_PACKAGE_DARWIN

  // MARK: Scheduling

  @available(System 199, *)
  @Test func schedulingOfAThread() throws {
    let result = Locked<Result<PThread.Scheduling, Errno>?>(nil)
    let thread = try PThread {
      result.withValue {
        $0 = Result { () throws(Errno) in
          let current = try PThread.ID.current.scheduling()
          try PThread.ID.current.setScheduling(current)
          return try PThread.ID.current.scheduling()
        }
      }
    }
    let other = try thread.id.scheduling()
    try thread.join()
    let scheduling = try #require(try result.value?.get())
    #expect(scheduling == other)
    #expect(try scheduling.policy.priorityRange().contains(scheduling.priority))
  }

  #if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func priorityRangeIgnoresThePolicyOnDarwin() throws {
    let range = try PThread.SchedulingPolicy.other.priorityRange()
    #expect(try PThread.SchedulingPolicy.fifo.priorityRange() == range)
    #expect(try PThread.SchedulingPolicy.roundRobin.priorityRange() == range)
    #expect(try PThread.SchedulingPolicy(rawValue: -12345).priorityRange() == range)
  }
  #else
  @available(System 199, *)
  @Test func invalidPolicy() {
    #expect(throws: Errno.invalidArgument) {
      _ = try PThread.SchedulingPolicy(rawValue: -12345).priorityRange()
    }
  }
  #endif

  // MARK: Calling thread

  @available(System 199, *)
  @Test func yield() throws {
    let thread = try PThread { PThread.yield() }
    try thread.join()
  }

  /// A thread that ends itself doesn't run the rest of its body,
  /// and joining it returns.
  @available(System 199, *)
  @Test func exitEndsTheThread() throws {
    let steps = Locked<[String]>([])
    let thread = try PThread {
      steps.withValue { $0.append("before") }
      PThread.exit()
    }
    try thread.join()
    #expect(steps.value == ["before"])
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  @available(System 199, *)
  @Test func isMainThread() throws {
    let onThread = Locked<Bool?>(nil)
    let thread = try PThread { onThread.withValue { $0 = PThread.isMainThread } }
    try thread.join()
    #expect(onThread.value == false)
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
