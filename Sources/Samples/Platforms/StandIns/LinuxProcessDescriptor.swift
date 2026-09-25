/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// STAND-IN, simulated configuration only. A Linux process descriptor
// (pidfd) owner, shaped as Prototype/Subtypes/Sketch.swift sketches
// `ProcessDescriptor`. System has no such type yet, on Linux or elsewhere.
// Simulated with a kqueue that watches the process for its exit, which, like
// a pidfd, is a descriptor that polls readable once the process exits.
// Unlike pidfd_send_signal, the simulated `sendSignal` goes through `kill`,
// so it isn't free of pid-reuse races.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#endif

/// A process descriptor that is closed exactly once.
///
/// Owning it is an obligation to close the descriptor, not to reap the
/// process. Reaping is the separate "responsibility" role for processes
/// (Next/Vision.md, direction 3).
struct ProcessDescriptor: ~Copyable, Sendable {
  private let owner: OwnedFD

  /// The process this descriptor refers to.
  let processID: ProcessID

  /// Opens a descriptor for a process.
  ///
  /// The corresponding C function is `pidfd_open`.
  init(_ process: ProcessID) throws(Errno) {
    let queue = kqueue()
    guard queue >= 0 else { throw Errno(rawValue: errno) }
    var change = kevent(
      ident: UInt(process.rawValue), filter: Int16(EVFILT_PROC),
      flags: UInt16(EV_ADD | EV_ONESHOT), fflags: UInt32(NOTE_EXIT), data: 0, udata: nil)
    guard kevent(queue, &change, 1, nil, 0, nil) == 0 else {
      let failure = Errno(rawValue: errno)
      Darwin.close(queue)
      throw failure
    }
    owner = OwnedFD(taking: FileDescriptor(rawValue: queue))
    processID = process
  }

  /// The descriptor, which polls readable once the process exits. Valid only
  /// while this owner is alive.
  var fileDescriptor: FileDescriptor { owner.fileDescriptor }

  consuming func close() throws(Errno) { try owner.close() }
  consuming func relinquish() -> FileDescriptor { owner.relinquish() }

  /// Sends a signal to the process.
  ///
  /// The corresponding C function is `pidfd_send_signal`.
  func sendSignal(_ signal: CInt) throws(Errno) {
    guard kill(processID.rawValue, signal) == 0 else { throw Errno(rawValue: errno) }
  }

  /// Waits for the process, a child of this one, to exit, reaps it, and
  /// returns its wait status. A second wait fails with `ECHILD`.
  ///
  /// The corresponding C function is `waitid`, with `P_PIDFD`.
  func wait() throws(Errno) -> CInt {
    var status: CInt = 0
    while waitpid(processID.rawValue, &status, 0) < 0 {
      guard errno == EINTR else { throw Errno(rawValue: errno) }
    }
    return status
  }
}

#endif // SIMULATE_PLATFORMS
