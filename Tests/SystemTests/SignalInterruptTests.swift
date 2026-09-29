/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

// Blocking calls interrupted by a real signal, on every Unix platform: a
// read from an empty pipe and a write to a full one. A signal handled
// without SA_RESTART interrupts each with EINTR, which `retryOnInterrupt:
// false` throws, and which the default retries until the call can finish.
// WriteAllInterruptTests checks the Span-based writeAll this way on Darwin
// only.
//
// These are XCTest tests, which run one at a time: each installs a SIGUSR2
// handler for the whole process.
@available(System 199, *)
final class SignalInterruptTest: XCTestCase {
  func testReadRetriesOnlyWhenAsked() throws {
    for retry in [false, true] {
      let pipe = try FileDescriptor.pipe()
      defer {
        try? pipe.readEnd.close()
        try? pipe.writeEnd.close()
      }
      // With nothing to read, the read blocks until it's interrupted.
      let reader = pipe.readEnd
      let result = try interruptingCall(retried: retry, {
        var byte: UInt8 = 0
        return try withUnsafeMutableBytes(of: &byte) {
          try reader.read(into: $0, retryOnInterrupt: retry)
        }
      }, thenUnblock: {
        _ = try pipe.writeEnd.writeAll([1])
      })
      if retry {
        XCTAssertEqual(try result.get(), 1)
      } else {
        XCTAssertThrowsError(try result.get()) {
          XCTAssertEqual($0 as? Errno, .interrupted)
        }
      }
    }
  }

  func testWriteRetriesOnlyWhenAsked() throws {
    for retry in [false, true] {
      let result = try writeToAFullPipe(retried: retry) { fd, byte in
        try withUnsafeBytes(of: byte) { try fd.write($0, retryOnInterrupt: retry) }
      }
      if retry {
        XCTAssertEqual(try result.get(), 1)
      } else {
        XCTAssertThrowsError(try result.get()) {
          XCTAssertEqual($0 as? Errno, .interrupted)
        }
      }
    }
  }

  func testSpanWriteAllRetriesOnlyWhenAsked() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }
    for retry in [false, true] {
      let result = try writeToAFullPipe(retried: retry) { fd, byte in
        try withUnsafeBytes(of: byte) {
          try fd.writeAll(RawSpan(_unsafeBytes: $0), retryOnInterrupt: retry)
        }
      }
      if retry {
        XCTAssertEqual(try result.get(), 1)
      } else {
        XCTAssertThrowsError(try result.get()) {
          XCTAssertEqual($0 as? Errno, .interrupted)
        }
      }
    }
  }
}

/// Writes one byte to a full pipe with `write`, while interrupting it.
///
/// After interrupting, this function drains the pipe,
/// so that a write that was retried can finish.
@available(System 199, *)
private func writeToAFullPipe(
  retried: Bool,
  _ write: @escaping @Sendable (FileDescriptor, UInt8) throws -> Int
) throws -> Result<Int, any Error> {
  let pipe = try FileDescriptor.pipe()
  defer {
    try? pipe.readEnd.close()
    try? pipe.writeEnd.close()
  }
  try fill(pipe.writeEnd)
  let writer = pipe.writeEnd
  return try interruptingCall(retried: retried, { try write(writer, 1) }, thenUnblock: {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
    defer { buffer.deallocate() }
    _ = try pipe.readEnd.read(into: buffer)
  })
}

/// Writes to `fd` until the pipe it writes to is full.
@available(System 199, *)
private func fill(_ fd: FileDescriptor) throws {
  let flags = try fd.statusFlags()
  try fd.setStatusFlags(flags.union(.nonBlocking))
  defer { try? fd.setStatusFlags(flags) }
  let chunk = [UInt8](repeating: 0, count: 4096)
  // Whole chunks, then single bytes, until the pipe takes no more.
  for size in [chunk.count, 1] {
    while true {
      do {
        _ = try chunk.prefix(size).withUnsafeBytes { try fd.write($0) }
      } catch Errno.wouldBlock {
        break
      }
    }
  }
}

/// How many times the SIGUSR2 handler has run.
nonisolated(unsafe) private var handledSignals: CInt = 0

/// Calls `call` on a thread of its own, interrupting it with SIGUSR2.
///
/// Then this function calls `unblock`, so that a call that was retried
/// can finish, and returns the result of `call`.
///
/// A signal that arrives before the call blocks doesn't interrupt it, and
/// how soon the thread gets that far depends on the machine's load. So
/// this sends one signal at a time, each once the thread has handled the
/// last, until the call returns, which a call that isn't retried does at
/// its first interruption. One that is `retried` never returns by itself,
/// so for it this stops after three: it can't tell which of them reached
/// the call rather than the code before it, but the result it checks is
/// the same either way.
private func interruptingCall(
  retried: Bool,
  _ call: @escaping @Sendable () throws -> Int,
  thenUnblock unblock: () throws -> Void
) throws -> Result<Int, any Error> {
  handledSignals = 0
  var previous = try installInterruptingHandler(for: SIGUSR2)
  defer { sigaction(SIGUSR2, &previous, nil) }

  // The call runs on a thread of its own, the only one that gets the signal.
  // (A test's own thread can be a workqueue thread, and Darwin doesn't signal
  // those.) The thread waits to exit until the signals stop, since signaling
  // a thread that has exited is undefined.
  let state = InterruptedCall()
  Thread {
    // A new thread starts with its creator's signal mask, which may block
    // SIGUSR2. Unblock it for the call only.
    var signals = sigset_t()
    sigemptyset(&signals)
    sigaddset(&signals, SIGUSR2)
    pthread_sigmask(SIG_UNBLOCK, &signals, nil)
    state.started(pthread_self())
    let result = Result { try call() }
    pthread_sigmask(SIG_BLOCK, &signals, nil)
    state.finished(result)
    state.waitForRelease()
  }.start()
  defer { state.release() }

  let thread = try XCTUnwrap(state.waitForStart(), "The thread didn't start")
  // The guard counts milliseconds slept, which take at least as long.
  var guardLeft = hangGuardSeconds * 1_000
  while !state.isFinished && !(retried && handledSignals >= 3) && guardLeft > 0 {
    let handled = handledSignals
    pthread_kill(thread, SIGUSR2)
    repeat {
      usleep(1_000)
      guardLeft -= 1
    } while handledSignals == handled && !state.isFinished && guardLeft > 0
  }
  try unblock()
  return try XCTUnwrap(state.waitForResult(), "The call didn't return")
}

/// Handles `signal` without SA_RESTART, so that it interrupts a blocked call,
/// and returns the action it replaces.
private func installInterruptingHandler(for signal: CInt) throws(Errno) -> sigaction {
  let handler: @convention(c) (CInt) -> Void = { _ in handledSignals += 1 }
  var action = sigaction()
  // Each C library names the handler field differently, as in SwiftPM.
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  action.__sigaction_u.__sa_handler = handler
  #elseif canImport(Musl)
  action.__sa_handler.sa_handler = handler
  #elseif os(Android)
  action.sa_handler = handler
  #else
  action.__sigaction_handler = unsafeBitCast(
    handler, to: sigaction.__Unnamed_union___sigaction_handler.self)
  #endif
  sigemptyset(&action.sa_mask)
  action.sa_flags = 0
  var previous = sigaction()
  guard sigaction(signal, &action, &previous) == 0 else { throw Errno(rawValue: errno) }
  return previous
}

/// The state of a call on another thread.
private final class InterruptedCall: @unchecked Sendable {
  private let lock = NSLock()
  private var thread: pthread_t? = nil
  private var result: Result<Int, any Error>? = nil
  private let releaseSemaphore = DispatchSemaphore(value: 0)

  func started(_ thread: pthread_t) {
    lock.withLock { self.thread = thread }
  }

  func finished(_ result: Result<Int, any Error>) {
    lock.withLock { self.result = result }
  }

  var isFinished: Bool { lock.withLock { result != nil } }

  func waitForStart() -> pthread_t? {
    wait { self.thread }
  }

  func waitForResult() -> Result<Int, any Error>? {
    wait { self.result }
  }

  func waitForRelease() { releaseSemaphore.wait() }

  func release() { releaseSemaphore.signal() }

  /// Polls `value` for up to the hang guard.
  private func wait<T>(for value: () -> T?) -> T? {
    for _ in 0..<(hangGuardSeconds * 1_000) {
      if let value = lock.withLock(value) { return value }
      usleep(1_000)
    }
    return nil
  }
}

#endif // !os(Windows) && !os(WASI)
