/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned pidfd, on the pattern of OwnedFD, as
// Prototype/Subtypes sketches it. See Prototype/Processes for the design.

// pidfds exist on Linux and Android, from Linux 5.3.
#if os(Linux) || os(Android)

import CSystem
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// A file descriptor that refers to a process: a pidfd.
///
/// A process ID names whatever process has it,
/// and the system reuses an ID once its process is reaped,
/// so a signal or a wait by ID can reach the wrong process.
/// A process descriptor refers to one process for its whole lifetime:
/// signaling it after the process ends, even after it's reaped,
/// throws ``Errno/noSuchProcess`` rather than reaching another process.
/// Its descriptor becomes readable when the process ends,
/// so an ``EventPoll`` can watch for the end.
///
///     let descriptor = try child.openDescriptor()
///     try epoll.add(
///       descriptor.fileDescriptor, events: .readable,
///       data: .fileDescriptor(descriptor.fileDescriptor))
///
/// Owning a process descriptor is an obligation to close it,
/// not to reap the process:
/// destroying one closes its descriptor, as ``OwnedFD`` does,
/// and leaves the process as it is.
/// Its descriptor is always close-on-exec.
///
/// The corresponding C function is `pidfd_open`.
///
/// - Note: Only available on Linux and Android.
@frozen
@available(System 199, *)
public struct ProcessDescriptor: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  @usableFromInline
  internal let _processID: ProcessID

  /// Opens a descriptor for a process.
  ///
  /// - Parameters:
  ///   - process: The process to refer to.
  ///   - options: Options for the descriptor.
  ///
  /// Opening a descriptor by ID has the race that the descriptor removes:
  /// if the process was reaped, the ID may name another process.
  /// For a child, open it before reaping the child,
  /// as ``ChildProcess/openDescriptor(options:)`` does.
  /// A kernel without pidfds throws ``Errno/noFunction``.
  ///
  /// The corresponding C function is `pidfd_open`.
  @_alwaysEmitIntoClient
  public init(_ process: ProcessID, options: Options = []) throws(Errno) {
    self._owner = OwnedFD(taking: try ProcessDescriptor._open(process, options).get())
    self._processID = process
  }

  @usableFromInline
  internal static func _open(
    _ process: ProcessID, _ options: Options
  ) -> Result<FileDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_pidfd_open(process.rawValue, options.rawValue)
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a descriptor that refers to a process,
  /// such as one that `clone3` returned.
  ///
  /// This initializer doesn't check that `descriptor` refers to `process`.
  /// The descriptor is closed at the end of the instance's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor, processID process: ProcessID) {
    self._owner = OwnedFD(taking: descriptor)
    self._processID = process
  }

  /// The ID of the process that the descriptor refers to.
  @_alwaysEmitIntoClient
  public var processID: ProcessID { _processID }

  /// The descriptor, for operations that `ProcessDescriptor` doesn't provide,
  /// such as watching it with an ``EventPoll``.
  ///
  /// The returned value is valid only while this instance is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the descriptor.
  ///
  /// The descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

@available(System 199, *)
extension ProcessDescriptor {
  /// Options for a process descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CUnsignedInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }

    /// Makes a wait on the descriptor for a running child
    /// throw ``Errno/resourceTemporarilyUnavailable`` rather than wait.
    ///
    /// The corresponding C constant is `PIDFD_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: Options { Options(rawValue: _PIDFD_NONBLOCK) }
  }

  /// Sends a signal to the process.
  ///
  /// - Parameter signal: The signal to send,
  ///   or `nil` to send none, which checks that the process exists.
  ///
  /// The signal reaches the process that the descriptor refers to, or none:
  /// once that process ends, this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `pidfd_send_signal`.
  @_alwaysEmitIntoClient
  public func sendSignal(_ signal: Signal?) throws(Errno) {
    try _sendSignal(signal).get()
  }

  @usableFromInline
  internal func _sendSignal(_ signal: Signal?) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_pidfd_send_signal(fileDescriptor.rawValue, signal?.rawValue ?? 0, 0)
    }
  }

  /// Waits for the process, a child of the caller, to end, and reaps it.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the wait
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to try only once
  ///   and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: How the process ended.
  ///
  /// Waiting on a descriptor needs Linux 5.4;
  /// earlier kernels throw ``Errno/invalidArgument``.
  /// A process that isn't an unreaped child of the caller
  /// throws ``Errno/noChildProcess``.
  ///
  /// The corresponding C function is `waitid`, with `P_PIDFD`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(retryOnInterrupt: Bool = true) throws(Errno) -> ExitStatus {
    let change = try ProcessID._waitID(
      _P_PIDFD, id_t(fileDescriptor.rawValue), options: .exited,
      retryOnInterrupt: retryOnInterrupt
    ).get()?.change
    guard case .terminated(let status)? = change else { throw .noChildProcess }
    return status
  }

  /// Waits for the process, a child of the caller, to change state.
  ///
  /// See ``ProcessID/wait(for:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `waitid`, with `P_PIDFD`.
  @_alwaysEmitIntoClient
  public func wait(
    for options: ProcessID.WaitOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> ProcessStateChange? {
    try ProcessID._waitID(
      _P_PIDFD, id_t(fileDescriptor.rawValue), options: options,
      retryOnInterrupt: retryOnInterrupt
    ).get()?.change
  }
}

@available(System 199, *)
extension ChildProcess {
  /// Opens a descriptor that refers to the child.
  ///
  /// The child isn't reaped while the owner lives,
  /// so the descriptor refers to it, and not to another process.
  /// Once ``tryWait()`` has reaped the child,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `pidfd_open`.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func openDescriptor(
    options: ProcessDescriptor.Options = []
  ) throws(Errno) -> ProcessDescriptor {
    guard _status == nil else { throw .noSuchProcess }
    return try ProcessDescriptor(id, options: options)
  }
}

#endif // os(Linux) || os(Android)
