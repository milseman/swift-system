/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the multi-platform process enum. Not API. See Platform.swift.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension Platform {
  /// A reference to a process.
  ///
  /// Unlike the other enums, a platform can have more than one case here:
  /// Linux has `.id` and `.descriptor`, and Windows has `.id` and `.handle`.
  /// That's where a switch earns its keep, since each platform's switches
  /// must handle every representation it has. On Darwin, `.id` is the only
  /// case.
  ///
  /// Owning one is an obligation to release the reference, not to reap the
  /// process. Destroying one closes the pidfd or handle, if there is one,
  /// and leaves the process running.
  enum Process: ~Copyable, Sendable {
    /// A process ID, on every platform. A name, not a reference: once the
    /// process is reaped, or on Windows once its last handle closes, the ID
    /// can name another process.
    case id(ProcessID)

    #if os(Linux) || SIMULATE_PLATFORMS
    /// A process descriptor (pidfd), on Linux. It refers to one process for
    /// its lifetime, and polls readable when the process exits.
    case descriptor(ProcessDescriptor)
    #endif

    #if os(Windows) || SIMULATE_PLATFORMS
    /// A process handle, on Windows. It refers to one process, and keeps its
    /// exit code, for its lifetime.
    case handle(Win32.ProcessHandle)
    #endif
  }

  /// How a process ended.
  ///
  /// Another multi-platform enum, on a small scale: `.exited` everywhere,
  /// and `.signaled` only where there are signals.
  enum ExitStatus: Sendable, Equatable, CustomStringConvertible {
    /// It exited with a code. Unix keeps 8 bits of what the process passed
    /// to `exit`. Windows keeps all 32, and reports a crash this way too,
    /// as an NTSTATUS code such as 0xC0000005.
    case exited(Int)

    #if !os(Windows)
    /// A signal ended it, on Unix.
    case signaled(CInt)
    #endif

    var description: String {
      switch self {
      case .exited(let code): return "exited with code \(code)"
      #if !os(Windows)
      case .signaled(let signal): return "ended by signal \(signal)"
      #endif
      }
    }
  }
}

extension Platform.Process {
  /// The process's ID.
  var id: ProcessID {
    switch self {
    case .id(let id):
      return id
    #if os(Linux) || SIMULATE_PLATFORMS
    case .descriptor(let descriptor):
      return descriptor.processID
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return handle.processID
    #endif
    }
  }

  /// Ends the process now, without letting it clean up.
  ///
  /// - Unix: SIGKILL. For `.id`, through `kill`, which could signal another
  ///   process if this one was already reaped and its ID reused. For
  ///   `.descriptor`, through `pidfd_send_signal`, which can't.
  /// - Windows: `TerminateProcess`, which needs an exit code; this uses 1.
  ///   So `waitForExit()` reports `.exited(1)` there, and `.signaled(9)` on
  ///   Unix.
  func terminate() throws(Platform.Error) {
    switch self {
    case .id(let id):
      // The one case every platform has, but not one implementation: the
      // `#if` moves inside the arm.
      #if os(Windows)
      try Win32.ProcessHandle.open(id, access: .terminate).terminate(exitCode: 1)
      #else
      // C: System has no kill wrapper.
      guard kill(id.rawValue, SIGKILL) == 0 else { throw Errno(rawValue: errno) }
      #endif
    #if os(Linux) || SIMULATE_PLATFORMS
    case .descriptor(let descriptor):
      try descriptor.sendSignal(SIGKILL)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.terminate(exitCode: 1)
    #endif
    }
  }

  /// Waits until the process ends, and reports how.
  ///
  /// - Unix: `waitpid` for `.id`, or `waitid` with `P_PIDFD` for
  ///   `.descriptor`. Either works only for a child of this process, and
  ///   reaps it: a second wait fails with `noChildProcess`, and the ID can be
  ///   reused.
  /// - Windows: `WaitForSingleObject`, then `GetExitCodeProcess`. Any process
  ///   with the access right can wait, nothing is reaped, and asking again
  ///   gives the same answer.
  func waitForExit() throws(Platform.Error) -> Platform.ExitStatus {
    switch self {
    case .id(let id):
      #if os(Windows)
      let handle = try Win32.ProcessHandle.open(id, access: .synchronize)
      try handle.waitForExit()
      return .exited(Int(try handle.exitCode()!))
      #else
      // C: System has no waitpid wrapper.
      var status: CInt = 0
      while waitpid(id.rawValue, &status, 0) < 0 {
        guard errno == EINTR else { throw Errno(rawValue: errno) }
      }
      return Platform.ExitStatus(waitStatus: status)
      #endif
    #if os(Linux) || SIMULATE_PLATFORMS
    case .descriptor(let descriptor):
      return Platform.ExitStatus(waitStatus: try descriptor.wait())
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.waitForExit()
      // After a wait, GetExitCodeProcess can't report STILL_ACTIVE.
      return .exited(Int(try handle.exitCode()!))
    #endif
    }
  }

  /// Releases the reference, reporting any error. The process keeps running.
  consuming func close() throws(Platform.Error) {
    switch consume self {
    case .id:
      break
    #if os(Linux) || SIMULATE_PLATFORMS
    case .descriptor(let descriptor):
      try descriptor.close()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.close()
    #endif
    }
  }

  /// The case and its process ID, for display.
  var summary: String {
    switch self {
    case .id(let id):
      return ".id(\(id.rawValue))"
    #if os(Linux) || SIMULATE_PLATFORMS
    case .descriptor(let descriptor):
      return ".descriptor(fd \(descriptor.fileDescriptor.rawValue), pid \(descriptor.processID.rawValue))"
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return ".handle(0x\(String(UInt(bitPattern: handle.unsafeRawHandle), radix: 16)), pid \(handle.processID.rawValue))"
    #endif
    }
  }
}

#if !os(Windows)
extension Platform.ExitStatus {
  /// Decodes a Unix wait status, as `WIFEXITED` and `WTERMSIG` do.
  init(waitStatus status: CInt) {
    let signal = status & 0x7F
    self = signal == 0 ? .exited(Int((status >> 8) & 0xFF)) : .signaled(signal)
  }
}
#endif
