/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Synchronization
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// FileDescriptor.writeAll(_: RawSpan, retryOnInterrupt:) and
// writeAll(toAbsoluteOffset:_: RawSpan, retryOnInterrupt:) retry an
// interrupted write only when `retryOnInterrupt` is true, and the OwnedFD
// methods of the same names forward the argument to them.
//
// These are XCTest tests, which run one at a time: the first installs a
// signal handler for the process, and keeps a full pipe that another test
// could drain by using a closed descriptor.
final class WriteAllInterruptTest: XCTestCase {
  #if SYSTEM_PACKAGE_DARWIN
  // Signal handling needs sigaction, whose handler field has a different name
  // in each C library; this test spells Darwin's.
  func testSpanWriteAllRetriesOnlyWhenAsked() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }
    // The unbuffered write honors `retryOnInterrupt: false`, which shows
    // that the signal reaches the blocked write.
    let control = try writeOneByteToAFullPipe(retried: false) { fd, bytes in
      try fd.write(bytes, retryOnInterrupt: false)
    }
    XCTAssertThrowsError(try control.get()) {
      XCTAssertEqual($0 as? Errno, .interrupted)
    }

    let notRetried = try writeOneByteToAFullPipe(retried: false) { fd, bytes in
      try fd.writeAll(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
    }
    XCTAssertThrowsError(try notRetried.get()) {
      XCTAssertEqual($0 as? Errno, .interrupted)
    }

    // By default, the write is retried after each interruption, and
    // finishes once the pipe is drained.
    let retried = try writeOneByteToAFullPipe(retried: true) { fd, bytes in
      try fd.writeAll(RawSpan(_unsafeBytes: bytes))
    }
    XCTAssertEqual(try retried.get(), 1)
  }
  #endif // SYSTEM_PACKAGE_DARWIN

  #if ENABLE_MOCKING && !os(WASI)
  // This covers the positioned variant too, which can't block. It checks
  // only `retryOnInterrupt: false`: when a mocked write is retried, it
  // returns 0 bytes, and writeAll retries that forever.
  @available(System 199, *)
  func testSpanWriteAllThrowsOnInterruptWhenNotRetrying() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }

    let bytes: [UInt8] = [1, 2, 3]
    let fd = FileDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try bytes.withUnsafeBytes { bytes in
        try fd.writeAll(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
      }) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "write")
      XCTAssertTrue(mocking.trace.isEmpty)

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try bytes.withUnsafeBytes { bytes in
        try fd.writeAll(
          toAbsoluteOffset: 7, RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
      }) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "pwrite")
      XCTAssertTrue(mocking.trace.isEmpty)

      let owned = OwnedFD(taking: fd)
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try bytes.withUnsafeBytes { bytes in
        try owned.writeAll(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
      }) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "write")
      XCTAssertTrue(mocking.trace.isEmpty)
      _ = owned.relinquish()
    }
  }
  #endif // ENABLE_MOCKING && !os(WASI)
}

#if SYSTEM_PACKAGE_DARWIN
private typealias OneByteWrite = @Sendable (FileDescriptor, UnsafeRawBufferPointer) throws -> Int

/// How many times the SIGUSR2 handler has run.
nonisolated(unsafe) private var handledSignals: CInt = 0

/// Calls `write` to write one byte to a full pipe, on a new thread,
/// while this thread interrupts it with SIGUSR2.
///
/// After interrupting, this function reads from the pipe,
/// so that a write that was retried can finish.
/// It returns the result of `write`.
///
/// A signal that arrives before the write blocks doesn't interrupt it, so
/// this sends one at a time, each once the thread has handled the last,
/// until the write returns: at its first interruption, if it isn't
/// retried. One that is `retried` never returns while the pipe is full, so
/// for it this stops after three, whichever of them reached the write.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func writeOneByteToAFullPipe(
  retried: Bool,
  _ write: @escaping OneByteWrite
) throws -> Result<Int, any Error> {
  let pipe = try FileDescriptor.pipe()
  defer {
    try? pipe.readEnd.close()
    try? pipe.writeEnd.close()
  }
  try fill(pipe.writeEnd)

  // A signal without SA_RESTART interrupts a blocked write with EINTR.
  handledSignals = 0
  var action = sigaction()
  action.__sigaction_u.__sa_handler = { _ in handledSignals += 1 }
  sigemptyset(&action.sa_mask)
  var previous = sigaction()
  try check(sigaction(SIGUSR2, &action, &previous))
  defer { sigaction(SIGUSR2, &previous, nil) }

  // The write runs on a thread of its own, the only one that gets the
  // signal. (A test's own thread can be a workqueue thread, as it is under
  // Swift Testing, and Darwin doesn't signal those: pthread_kill fails with
  // ENOTSUP.)
  let writer = Writer(fd: pipe.writeEnd, write: write)
  let thread = try writer.start()
  // The guard counts milliseconds slept, which take at least as long.
  var guardLeft = hangGuardSeconds * 1_000
  func finished() -> Bool { writer.finished.load(ordering: .acquiring) }
  while !finished() && !(retried && handledSignals >= 3) && guardLeft > 0 {
    let handled = handledSignals
    pthread_kill(thread, SIGUSR2)
    repeat {
      usleep(1_000)
      guardLeft -= 1
    } while handledSignals == handled && !finished() && guardLeft > 0
  }
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { buffer.deallocate() }
  _ = try pipe.readEnd.read(into: buffer)
  pthread_join(thread, nil)
  return writer.result!
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private final class Writer: @unchecked Sendable {
  let fd: FileDescriptor
  let write: OneByteWrite
  let finished = Atomic<Bool>(false)
  // Written by the new thread, and read after joining it.
  var result: Result<Int, any Error>? = nil

  init(fd: FileDescriptor, write: @escaping OneByteWrite) {
    self.fd = fd
    self.write = write
  }

  func start() throws(Errno) -> pthread_t {
    let context = Unmanaged.passRetained(self)
    var thread: pthread_t? = nil
    let status = pthread_create(&thread, nil, { raw in
      let writer = Unmanaged<Writer>.fromOpaque(raw).takeRetainedValue()
      // A new thread starts with its creator's signal mask, which may block
      // SIGUSR2. Unblock it for the write only.
      var signals = sigset_t()
      sigemptyset(&signals)
      sigaddset(&signals, SIGUSR2)
      pthread_sigmask(SIG_UNBLOCK, &signals, nil)
      writer.result = [UInt8(1)].withUnsafeBytes { bytes in
        Result { try writer.write(writer.fd, bytes) }
      }
      pthread_sigmask(SIG_BLOCK, &signals, nil)
      writer.finished.store(true, ordering: .releasing)
      return nil
    }, context.toOpaque())
    guard status == 0, let thread else {
      context.release()
      throw Errno(rawValue: status)
    }
    return thread
  }
}

private func check(_ result: CInt) throws(Errno) {
  if result != 0 { throw Errno(rawValue: errno) }
}

/// Writes to `fd` until the pipe it writes to is full.
private func fill(_ fd: FileDescriptor) throws(Errno) {
  let flags = fcntl(fd.rawValue, F_GETFL)
  try check(fcntl(fd.rawValue, F_SETFL, flags | O_NONBLOCK))
  defer { _ = fcntl(fd.rawValue, F_SETFL, flags) }
  let chunk = [UInt8](repeating: 0, count: 4096)
  // Large writes first, then single bytes, since a write that doesn't fit
  // whole may not write at all.
  for size in [chunk.count, 1] {
    while true {
      let result = chunk.withUnsafeBytes { write(fd.rawValue, $0.baseAddress, size) }
      if result < 0 {
        guard errno == EAGAIN else { throw Errno(rawValue: errno) }
        break
      }
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN
