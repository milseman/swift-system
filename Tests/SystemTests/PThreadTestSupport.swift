/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Helpers for the PThread tests. Waits are bounded, so that a broken
// implementation fails a test instead of hanging it.

#if !os(Windows) && !os(WASI)

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

/// A value that threads share, protected by a pthread mutex.
@available(System 199, *)
final class Locked<Value>: @unchecked Sendable {
  let mutex = try! PThread.Mutex()
  private var _value: Value

  init(_ value: Value) { _value = value }

  func withValue<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    try! mutex.lock()
    defer { try! mutex.unlock() }
    return try body(&_value)
  }

  var value: Value { withValue { $0 } }
}

/// A place to move a thread's owner, so that another thread can take it.
@available(System 199, *)
final class Slot: @unchecked Sendable {
  let mutex = try! PThread.Mutex()
  private var thread: PThread?

  func put(_ thread: consuming PThread) {
    try! mutex.lock()
    self.thread = consume thread
    try! mutex.unlock()
  }

  func take() -> PThread? {
    try! mutex.lock()
    defer { try! mutex.unlock() }
    return thread.take()
  }
}

/// A one-shot gate: threads wait until another thread opens it.
@available(System 199, *)
final class Latch: @unchecked Sendable {
  let mutex = try! PThread.Mutex()
  let condition = try! PThread.Condition()
  private var isOpen = false

  func open() {
    try! mutex.withLock { isOpen = true }
    try! condition.broadcast()
  }

  /// Waits until the latch opens, for at most `seconds`.
  /// Returns whether it opened.
  func wait(seconds: Int = 10) -> Bool {
    let deadline = realtimeDeadline(seconds: seconds)
    return try! mutex.withLock {
      while !isOpen {
        if try !condition.wait(on: mutex, until: deadline) { return isOpen }
      }
      return true
    }
  }
}

/// A time on the CLOCK_REALTIME clock, `seconds` from now.
func realtimeDeadline(seconds: Int = 0, nanoseconds: Int = 0) -> timespec {
  var now = timespec()
  clock_gettime(CLOCK_REALTIME, &now)
  var deadline = timespec(tv_sec: now.tv_sec + seconds, tv_nsec: now.tv_nsec + nanoseconds)
  if deadline.tv_nsec >= 1_000_000_000 {
    deadline.tv_sec += 1
    deadline.tv_nsec -= 1_000_000_000
  }
  return deadline
}

/// The time on the CLOCK_MONOTONIC clock, in nanoseconds.
func monotonicNanoseconds() -> Int {
  var now = timespec()
  clock_gettime(CLOCK_MONOTONIC, &now)
  return now.tv_sec * 1_000_000_000 + now.tv_nsec
}

#endif // !os(Windows) && !os(WASI)
