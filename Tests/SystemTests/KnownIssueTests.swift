/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
import Synchronization
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

// Tests for bugs in merged source. Each one checks the documented behavior,
// and is marked as a known issue, or disabled, until the bug is fixed.
//
// FileDescriptor.writeAll(_: RawSpan, retryOnInterrupt:) and
// writeAll(toAbsoluteOffset:_: RawSpan, retryOnInterrupt:) document that
// `retryOnInterrupt: false` throws `Errno.interrupted` instead of retrying,
// but they ignore the argument: `_writeAllBuffer` always passes
// `retryOnInterrupt: true` to `_write` (Sources/System/FileHelpers.swift).
// The OwnedFD methods of the same names forward the argument to them.
@Suite("Known issues")
private struct KnownIssueTests {

  #if SYSTEM_PACKAGE_DARWIN
  // Signal handling needs sigaction, whose handler field has a different name
  // in each C library; this test spells Darwin's.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func spanWriteAllRetriesAnInterruptedWrite() throws {
    // The unbuffered write honors `retryOnInterrupt: false`, which shows
    // that the signal reaches the blocked write.
    let control = try writeOneByteToAFullPipe { fd, bytes in
      try fd.write(bytes, retryOnInterrupt: false)
    }
    #expect(throws: Errno.interrupted) { try control.get() }

    let result = try writeOneByteToAFullPipe { fd, bytes in
      try fd.writeAll(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
    }
    withKnownIssue("writeAll(_: RawSpan, retryOnInterrupt:) ignores retryOnInterrupt") {
      #expect(throws: Errno.interrupted) { try result.get() }
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN

  #if ENABLE_MOCKING
  // This covers the positioned variant too, which can't block. It's disabled
  // because, with the bug, it never returns: after the forced EINTR, the
  // retried write returns 0 bytes, and writeAll retries that forever.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test(.disabled("writeAll(_: RawSpan, retryOnInterrupt:) ignores retryOnInterrupt"))
  func spanWriteAllThrowsOnInterruptWhenNotRetrying() throws {
    let bytes: [UInt8] = [1, 2, 3]
    let fd = FileDescriptor(rawValue: 42)
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try bytes.withUnsafeBytes { bytes in
          _ = try fd.writeAll(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
        }
      }
      #expect(mocking.trace.dequeue()?.name == "write")
      #expect(mocking.trace.isEmpty)

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try bytes.withUnsafeBytes { bytes in
          _ = try fd.writeAll(
            toAbsoluteOffset: 7, RawSpan(_unsafeBytes: bytes), retryOnInterrupt: false)
        }
      }
      #expect(mocking.trace.dequeue()?.name == "pwrite")
      #expect(mocking.trace.isEmpty)
    }
  }
  #endif // ENABLE_MOCKING
}

#if SYSTEM_PACKAGE_DARWIN
private typealias OneByteWrite = @Sendable (FileDescriptor, UnsafeRawBufferPointer) throws -> Int

/// Calls `write` to write one byte to a full pipe, on a new thread,
/// while this thread interrupts it with SIGUSR2.
///
/// After interrupting, this function reads from the pipe,
/// so that a write that was retried can finish.
/// It returns the result of `write`.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func writeOneByteToAFullPipe(
  _ write: @escaping OneByteWrite
) throws -> Result<Int, any Error> {
  let pipe = try FileDescriptor.pipe()
  defer {
    try? pipe.readEnd.close()
    try? pipe.writeEnd.close()
  }
  try fill(pipe.writeEnd)

  // A signal without SA_RESTART interrupts a blocked write with EINTR.
  var action = sigaction()
  action.__sigaction_u.__sa_handler = { _ in }
  sigemptyset(&action.sa_mask)
  var previous = sigaction()
  try check(sigaction(SIGUSR2, &action, &previous))
  defer { sigaction(SIGUSR2, &previous, nil) }

  // Darwin doesn't send signals to workqueue threads, which Swift Testing
  // runs tests on (pthread_kill fails with ENOTSUP), so the write runs on a
  // thread of its own.
  let writer = Writer(fd: pipe.writeEnd, write: write)
  let thread = try writer.start()
  usleep(10_000)
  for _ in 0..<40 where !writer.finished.load(ordering: .acquiring) {
    pthread_kill(thread, SIGUSR2)
    usleep(5_000)
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
      // A new thread starts with its creator's signal mask, which blocks
      // SIGUSR2 on a workqueue thread. Unblock it for the write only.
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

#endif // !os(Windows) && !os(WASI)
