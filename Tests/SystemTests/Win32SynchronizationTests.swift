/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest
import Dispatch

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

/// A lock, a condition variable, and the state they protect, shared with
/// other threads.
@available(System 199, *)
private final class Shared: @unchecked Sendable {
  let lock = Win32.SRWLock()
  let condition = Win32.ConditionVariable()
  var ready = false
  var woken = 0
}

/// A result handed from another thread.
private final class Handoff<Value>: @unchecked Sendable {
  var value: Value?
}

/// Runs `body` on another thread, and returns its result.
private func onAnotherThread<Value>(_ body: @escaping @Sendable () -> Value) -> Value {
  let done = DispatchSemaphore(value: 0)
  let handoff = Handoff<Value>()
  DispatchQueue.global().async {
    handoff.value = body()
    done.signal()
  }
  done.wait()
  return handoff.value!
}

// Win32.SRWLock and Win32.ConditionVariable. Other threads come from
// Dispatch, as in FileLockTests.
@available(System 199, *)
final class Win32SynchronizationTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(
      _CONDITION_VARIABLE_LOCKMODE_SHARED, ULONG(WinSDK.CONDITION_VARIABLE_LOCKMODE_SHARED))
    XCTAssertEqual(_ERROR_TIMEOUT, DWORD(WinSDK.ERROR_TIMEOUT))
  }

  func testExclusiveLock() {
    let shared = Shared()
    let value = shared.lock.withLock { 42 }
    XCTAssertEqual(value, 42)
    XCTAssertTrue(shared.lock.tryLock())
    // Held here, so another thread can take it neither way.
    XCTAssertFalse(onAnotherThread { shared.lock.tryLock() })
    XCTAssertFalse(onAnotherThread { shared.lock.tryLockShared() })
    shared.lock.unlock()
    XCTAssertTrue(onAnotherThread { () -> Bool in
      guard shared.lock.tryLock() else { return false }
      shared.lock.unlock()
      return true
    })
  }

  func testSharedLock() {
    let shared = Shared()
    shared.lock.lockShared()
    XCTAssertTrue(onAnotherThread { () -> Bool in
      guard shared.lock.tryLockShared() else { return false }
      shared.lock.unlockShared()
      return true
    })
    XCTAssertFalse(onAnotherThread { shared.lock.tryLock() })
    shared.lock.unlockShared()
    let value = shared.lock.withSharedLock { "shared" }
    XCTAssertEqual(value, "shared")
  }

  func testWithLockRethrowsAndReleases() {
    let shared = Shared()
    XCTAssertThrowsWin32Error(.accessDenied) {
      try shared.lock.withLock { () throws(Win32.Error) in throw .accessDenied }
    }
    XCTAssertTrue(onAnotherThread { () -> Bool in
      guard shared.lock.tryLock() else { return false }
      shared.lock.unlock()
      return true
    })
  }

  func testConditionVariableWakesAWaiter() throws {
    let shared = Shared()
    DispatchQueue.global().async {
      shared.lock.withLock { shared.ready = true }
      shared.condition.wake()
    }
    try shared.lock.withLock { () throws(Win32.Error) in
      while !shared.ready {
        try shared.condition.wait(on: shared.lock)
      }
    }
    let ready = shared.lock.withLock { shared.ready }
    XCTAssertTrue(ready)
  }

  func testWaitTimesOut() throws {
    let shared = Shared()
    // A spurious wake-up returns true, so wait until a wait times out.
    var timedOut = false
    for _ in 0..<100 where !timedOut {
      timedOut = try shared.lock.withLock { () throws(Win32.Error) -> Bool in
        try !shared.condition.wait(on: shared.lock, timeout: .milliseconds(5))
      }
    }
    XCTAssertTrue(timedOut)
    // The wait took the lock again, and withLock released it.
    XCTAssertTrue(onAnotherThread { () -> Bool in
      guard shared.lock.tryLock() else { return false }
      shared.lock.unlock()
      return true
    })
  }

  func testSharedWait() throws {
    let shared = Shared()
    var timedOut = false
    shared.lock.lockShared()
    for _ in 0..<100 where !timedOut {
      timedOut = try !shared.condition.wait(
        on: shared.lock, shared: true, timeout: .milliseconds(5))
    }
    XCTAssertTrue(timedOut)
    // Held shared again: another thread can share it, but can't take it.
    XCTAssertTrue(onAnotherThread { () -> Bool in
      guard shared.lock.tryLockShared() else { return false }
      shared.lock.unlockShared()
      return true
    })
    XCTAssertFalse(onAnotherThread { shared.lock.tryLock() })
    shared.lock.unlockShared()
  }

  func testWakeAll() {
    let shared = Shared()
    let finished = DispatchSemaphore(value: 0)
    let waiters = 3
    for _ in 0..<waiters {
      DispatchQueue.global().async {
        try? shared.lock.withLock { () throws(Win32.Error) in
          while !shared.ready {
            try shared.condition.wait(on: shared.lock)
          }
          shared.woken += 1
        }
        finished.signal()
      }
    }
    shared.lock.withLock { shared.ready = true }
    shared.condition.wakeAll()
    for _ in 0..<waiters {
      XCTAssertEqual(finished.wait(timeout: .now() + 30), .success)
    }
    let woken = shared.lock.withLock { shared.woken }
    XCTAssertEqual(woken, waiters)
  }
}

#endif // os(Windows)
