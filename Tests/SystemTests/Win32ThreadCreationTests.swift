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

/// A value handed between threads.
private final class Shared<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) { _value = value }

  var value: Value {
    get { lock.withLock { _value } }
    set { lock.withLock { _value = newValue } }
  }
}

/// A value that counts its destructions.
private final class Tracked: @unchecked Sendable {
  let destroyed: Shared<Int>

  init(_ destroyed: Shared<Int>) { self.destroyed = destroyed }

  deinit { destroyed.value += 1 }
}

/// A key that a test can destroy while another thread uses it.
@available(System 199, *)
private final class KeyHolder: @unchecked Sendable {
  var key: Win32.FiberLocalKey<Tracked>?

  init() throws { key = try Win32.FiberLocalKey<Tracked>() }
}

// Creating threads, their names, yielding, and Win32.FiberLocalKey.
@available(System 199, *)
final class Win32ThreadCreationTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_CREATE_SUSPENDED, DWORD(WinSDK.CREATE_SUSPENDED))
    XCTAssertEqual(
      _STACK_SIZE_PARAM_IS_A_RESERVATION, DWORD(WinSDK.STACK_SIZE_PARAM_IS_A_RESERVATION))
    XCTAssertEqual(_FLS_OUT_OF_INDEXES, DWORD(WinSDK.FLS_OUT_OF_INDEXES))
  }

  func testCreatingAThread() throws {
    let ranOn = Shared<DWORD>(0)
    let thread = try Win32.ThreadHandle.create { ranOn.value = GetCurrentThreadId() }
    try thread.waitForExit()
    let id = try thread.threadID()
    XCTAssertEqual(ranOn.value, id.rawValue)
    XCTAssertNotEqual(id, .current)
    let code = try thread.exitCode()
    XCTAssertEqual(code, 0)
    let inheritable = try thread.isInheritable()
    XCTAssertFalse(inheritable)
    try thread.close()

    let inheritableThread = try Win32.ThreadHandle.create(inheritable: true) {}
    let isInheritable = try inheritableThread.isInheritable()
    XCTAssertTrue(isInheritable)
    try inheritableThread.waitForExit()
  }

  func testClosingTheHandleLetsTheThreadRun() throws {
    let finished = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let thread = try Win32.ThreadHandle.create {
      release.wait()
      finished.signal()
    }
    try thread.close()
    release.signal()
    XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)
  }

  func testSuspendedThreads() throws {
    let ran = Shared(false)
    let thread = try Win32.ThreadHandle.create(suspended: true) { ran.value = true }
    let exitedWhileSuspended = try thread.waitForExit(timeout: .milliseconds(50))
    XCTAssertFalse(exitedWhileSuspended)
    XCTAssertFalse(ran.value)
    let count = try thread.resume()
    XCTAssertEqual(count, 1)
    try thread.waitForExit()
    XCTAssertTrue(ran.value)
  }

  func testStackReservation() throws {
    let size = Shared<UInt>(0)
    let thread = try Win32.ThreadHandle.create(stackSize: 4 << 20) {
      var low: ULONG_PTR = 0
      var high: ULONG_PTR = 0
      GetCurrentThreadStackLimits(&low, &high)
      size.value = UInt(high - low)
    }
    try thread.waitForExit()
    // 4 MiB is a multiple of the allocation granularity.
    XCTAssertEqual(size.value, 4 << 20)
  }

  func testInvalidStackSizesAreRejected() {
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ThreadHandle.create(stackSize: -1) {}
    }
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ThreadHandle.create(stackSize: Int(UInt32.max) + 1) {}
    }
  }

  func testNames() throws {
    let thread = try Win32.ThreadHandle.create(suspended: true) {}
    let unnamed = try thread.name()
    XCTAssertEqual(unnamed, "")
    try thread.setName("system-tests worker é")
    let named = try thread.name()
    XCTAssertEqual(named, "system-tests worker é")
    XCTAssertThrowsWin32Error(.invalidParameter) { try thread.setName("a\u{0}b") }
    try thread.resume()
    try thread.waitForExit()

    // The rights each call needs, through E_ACCESSDENIED's Win32 code.
    let narrow = try Win32.ThreadHandle.current(access: .synchronize)
    XCTAssertThrowsWin32Error(.accessDenied) { try narrow.name() }
    XCTAssertThrowsWin32Error(.accessDenied) { try narrow.setName("x") }
  }

  func testYield() {
    // Whether another thread ran depends on what else is ready.
    let switched: Bool = Win32.yield()
    _ = switched
  }

  // MARK: - Fiber-local storage

  func testFiberLocalValues() throws {
    let key = try Win32.FiberLocalKey<Int>()
    XCTAssertNil(key.value())
    try key.setValue(1)
    XCTAssertEqual(key.value(), 1)

    let seen = Shared<Int?>(nil)
    let thread = try Win32.ThreadHandle.create {
      seen.value = key.value()
      try? key.setValue(2)
    }
    try thread.waitForExit()
    XCTAssertNil(seen.value)
    // The other thread's value was its own.
    XCTAssertEqual(key.value(), 1)
    try key.setValue(nil)
    XCTAssertNil(key.value())
  }

  func testReplacedValuesAreDestroyed() throws {
    let destroyed = Shared(0)
    let key = try Win32.FiberLocalKey<Tracked>()
    try key.setValue(Tracked(destroyed))
    try key.setValue(Tracked(destroyed))
    XCTAssertEqual(destroyed.value, 1)
    try key.setValue(nil)
    XCTAssertEqual(destroyed.value, 2)
  }

  func testValuesAreDestroyedWhenTheirThreadExits() throws {
    let destroyed = Shared(0)
    let holder = try KeyHolder()
    let thread = try Win32.ThreadHandle.create {
      try? holder.key?.setValue(Tracked(destroyed))
    }
    try thread.waitForExit()
    XCTAssertEqual(destroyed.value, 1)
  }

  func testDestroyingAKeyDestroysEveryThreadsValue() throws {
    let destroyed = Shared(0)
    let holder = try KeyHolder()
    let set = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let thread = try Win32.ThreadHandle.create {
      try? holder.key?.setValue(Tracked(destroyed))
      set.signal()
      release.wait()
    }
    set.wait()
    try holder.key?.setValue(Tracked(destroyed))
    // FlsFree destroys both values here, while the other thread still runs.
    holder.key = nil
    XCTAssertEqual(destroyed.value, 2)
    release.signal()
    try thread.waitForExit()
    XCTAssertEqual(destroyed.value, 2)
  }
}

#endif // os(Windows)
