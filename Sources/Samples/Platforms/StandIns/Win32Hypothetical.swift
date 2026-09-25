/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// HYPOTHETICAL, simulated configuration only. Win32 types that no draft
// proposes, written in the drafts' style so that the enum's Windows cases
// have something to wrap:
//
// - Standard handles: SYS-0011 lists `GetStdHandle` as a future direction.
// - `Win32.ProcessHandle`: an owned process handle, as `CreateProcessW` and
//   `OpenProcess` return. The drafts cover only the file system.
// - `Win32.Socket`: an owned WinSock socket. SYS-0011 says only that a socket
//   must not be adopted as a FileHandle, since `closesocket` closes it.
//
// Process IDs use System's `ProcessID`, as though it existed on Windows over
// a DWORD: the same concept under a different C spelling can share a name
// (Next/Vision.md). System declares it only outside Windows today.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#endif

// MARK: - Standard handles

extension Win32.FileHandle {
  /// The process's standard input handle, or `nil` if it has none, as a
  /// process without a console doesn't.
  ///
  /// Static stored properties are never destroyed and can't be consumed, so
  /// this value never closes the handle. Windows can replace the handle with
  /// `SetStdHandle`; this one is read once.
  ///
  /// The corresponding C function is `GetStdHandle`, with `STD_INPUT_HANDLE`.
  static let standardInput: Win32.FileHandle? = Win32.FileHandle(_simulated: 0)

  /// The process's standard output handle, or `nil` if it has none.
  static let standardOutput: Win32.FileHandle? = Win32.FileHandle(_simulated: 1)

  /// The process's standard error handle, or `nil` if it has none.
  static let standardError: Win32.FileHandle? = Win32.FileHandle(_simulated: 2)
}

// MARK: - Processes

extension Win32 {
  /// The access rights `OpenProcess` accepts.
  struct ProcessAccess: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var terminate: ProcessAccess { ProcessAccess(rawValue: 0x0001) }
    static var queryLimitedInformation: ProcessAccess { ProcessAccess(rawValue: 0x1000) }
    static var synchronize: ProcessAccess { ProcessAccess(rawValue: 0x0010_0000) }
  }

  /// An open process.
  ///
  /// The handle keeps the process object alive after the process exits, so
  /// its exit code stays readable, and its ID isn't reused, until every
  /// handle is closed. Waiting doesn't reap anything, and any process with
  /// the access right can wait, not only the parent.
  ///
  /// The corresponding C type is `HANDLE`.
  @safe
  struct ProcessHandle: ~Copyable, Sendable {
    // Simulation: a kqueue that watches the process for its exit.
    let _queue: CInt
    let _id: ProcessID

    init(_simulated queue: CInt, id: ProcessID) {
      _queue = queue
      _id = id
    }

    /// Adopts a raw process handle, such as `hProcess` from
    /// `CreateProcessW`, taking ownership of it.
    @unsafe
    init?(unsafelyAdopting raw: HANDLE?) {
      guard let queue = Win32Simulation.descriptor(of: raw),
        let id = Win32Simulation.processID(watchedBy: queue)
      else { return nil }
      self.init(_simulated: queue, id: id)
    }

    @unsafe
    var unsafeRawHandle: HANDLE { Win32Simulation.handle(for: _queue) }

    @unsafe
    consuming func relinquish() -> HANDLE {
      let queue = _queue
      discard self
      return Win32Simulation.handle(for: queue)
    }

    /// The corresponding C function is `CloseHandle`.
    consuming func close() throws(Win32.Error) {
      let queue = _queue
      discard self
      Win32Simulation.forgetProcess(queue: queue)
    }

    deinit {
      Win32Simulation.forgetProcess(queue: _queue)
    }
  }
}

extension Win32.ProcessHandle {
  /// Opens a process by its ID.
  ///
  /// The corresponding C function is `OpenProcess`.
  static func open(
    _ id: ProcessID,
    access: Win32.ProcessAccess = [.synchronize, .queryLimitedInformation, .terminate],
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ProcessHandle {
    let queue = try Win32Simulation.posix {
      try Win32Simulation.watchProcess(id)
    }
    return Win32.ProcessHandle(_simulated: queue, id: id)
  }

  /// The process's ID.
  ///
  /// The corresponding C function is `GetProcessId`.
  var processID: ProcessID { _id }

  /// Waits until the process exits.
  ///
  /// The corresponding C function is `WaitForSingleObject`, with `INFINITE`.
  func waitForExit() throws(Win32.Error) {
    _ = try Win32Simulation.posix {
      try Win32Simulation.waitForExit(_id, queue: _queue, block: true)
    }
  }

  /// The process's exit code, or `nil` while it's still running.
  ///
  /// The corresponding C function is `GetExitCodeProcess`, which reports
  /// `STILL_ACTIVE` (259) for a running process; that's `nil` here.
  func exitCode() throws(Win32.Error) -> DWORD? {
    let status = try Win32Simulation.posix {
      try Win32Simulation.waitForExit(_id, queue: _queue, block: false)
    }
    guard let status else { return nil }
    return Win32Simulation.windowsExitCode(_id, status: status)
  }

  /// Ends the process, which exits with `exitCode`.
  ///
  /// The corresponding C function is `TerminateProcess`.
  func terminate(exitCode: DWORD) throws(Win32.Error) {
    try Win32Simulation.posix {
      try Win32Simulation.terminate(_id, exitCode: exitCode)
    }
  }
}

// MARK: - Sockets

extension Win32 {
  /// The C `SOCKET` type, a `UINT_PTR`.
  typealias SOCKET = UInt

  /// An open WinSock socket.
  ///
  /// Closed with `closesocket`, not `CloseHandle`, so it isn't a FileHandle.
  @safe
  struct Socket: ~Copyable, Sendable {
    // Simulation: a POSIX socket descriptor.
    let _descriptor: CInt

    init(_simulated descriptor: CInt) {
      _descriptor = descriptor
      // WinSock never raises SIGPIPE.
      _ = try? FileDescriptor(rawValue: descriptor).setNoSigPipe(true)
    }

    /// Adopts a raw socket. Returns `nil` for `INVALID_SOCKET`.
    @unsafe
    init?(unsafelyAdopting raw: SOCKET) {
      guard raw != ~0 else { return nil }
      self.init(_simulated: CInt(truncatingIfNeeded: raw))
    }

    @unsafe
    var unsafeRawSocket: SOCKET { SOCKET(_descriptor) }

    @unsafe
    consuming func relinquish() -> SOCKET {
      let descriptor = _descriptor
      discard self
      return SOCKET(descriptor)
    }

    /// The corresponding C function is `closesocket`.
    consuming func close() throws(Win32.Error) {
      let descriptor = _descriptor
      discard self
      try Win32Simulation.posix { try FileDescriptor(rawValue: descriptor).close() }
    }

    deinit {
      _ = try? FileDescriptor(rawValue: _descriptor).close()
    }
  }

  /// Which directions of a connection `shutdown` ends.
  enum ShutdownDirection: Sendable {
    case receiving  // SD_RECEIVE
    case sending    // SD_SEND
    case both       // SD_BOTH
  }
}

extension Win32.Socket {
  /// Both ends of a connection. A tuple can't hold noncopyable values.
  struct Pair: ~Copyable, Sendable {
    var first: Win32.Socket
    var second: Win32.Socket
  }

  /// Two connected TCP sockets on the loopback interface. WinSock has no
  /// `socketpair`; this is what libraries build instead.
  ///
  /// The corresponding C functions are `socket`, `bind`, `listen`,
  /// `connect`, and `accept`. The simulation uses `socketpair`.
  static func loopbackPair() throws(Win32.Error) -> Pair {
    var ends: [CInt] = [-1, -1]
    guard socketpair(AF_UNIX, SOCK_STREAM, 0, &ends) == 0 else {
      throw Win32Simulation.error(from: Errno(rawValue: errno))
    }
    return Pair(first: Win32.Socket(_simulated: ends[0]), second: Win32.Socket(_simulated: ends[1]))
  }

  /// Sends all of `span`.
  ///
  /// The corresponding C function is `send`, called in a loop.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  func send(_ span: RawSpan) throws(Win32.Error) {
    try Win32Simulation.posix {
      _ = try FileDescriptor(rawValue: _descriptor).writeAll(span)
    }
  }

  /// Receives what has arrived, up to `span`'s free capacity. Zero means
  /// the peer shut down its sending direction.
  ///
  /// The corresponding C function is `recv`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  func receive(into span: inout OutputRawSpan) throws(Win32.Error) -> Int {
    try Win32Simulation.posix {
      try FileDescriptor(rawValue: _descriptor).read(into: &span)
    }
  }

  /// The corresponding C function is `shutdown`.
  func shutdown(_ direction: Win32.ShutdownDirection) throws(Win32.Error) {
    let how: CInt
    switch direction {
    case .receiving: how = SHUT_RD
    case .sending: how = SHUT_WR
    case .both: how = SHUT_RDWR
    }
    guard Darwin.shutdown(_descriptor, how) == 0 else {
      throw Win32Simulation.error(from: Errno(rawValue: errno))
    }
  }
}

#endif // SIMULATE_PLATFORMS
