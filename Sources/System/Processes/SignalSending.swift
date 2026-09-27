/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

// MARK: - Processes and process groups

@available(System 199, *)
extension ProcessID {
  /// Sends a signal to the process.
  ///
  /// - Parameter signal: The signal to send,
  ///   or `nil` to send none,
  ///   which checks that the process exists
  ///   and that the caller may send it signals.
  ///
  /// The process must be one that the caller may signal:
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// A process that no longer exists throws ``Errno/noSuchProcess``,
  /// but a zombie, a child that exited and that no wait has reaped,
  /// still exists.
  ///
  /// Once a process is reaped, the system can give its ID to a new process,
  /// which this method would then signal instead.
  /// A child that the caller hasn't reaped keeps its ID,
  /// which is why ``ChildProcess`` signals safely.
  ///
  /// This method sends the signal to the one process that the ID names.
  /// C's `kill` gives other meanings to IDs that aren't positive:
  /// for those, use ``sendSignalToProcessGroup(_:)``
  /// and ``sendSignalToAllProcesses(_:)``.
  /// A nonpositive ID throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `kill`.
  @_alwaysEmitIntoClient
  public func sendSignal(_ signal: Signal?) throws(Errno) {
    try _sendSignal(signal).get()
  }

  @usableFromInline
  internal func _sendSignal(_ signal: Signal?) -> Result<(), Errno> {
    guard rawValue > 0 else { return .failure(.invalidArgument) }
    return nothingOrErrno(retryOnInterrupt: false) {
      system_kill(rawValue, signal?.rawValue ?? 0)
    }
  }

  /// Sends a signal to every process in the process group
  /// that this ID names.
  ///
  /// - Parameter signal: The signal to send,
  ///   or `nil` to send none,
  ///   which checks that the group has a process
  ///   that the caller may send signals to.
  ///
  /// A process group's ID is the process ID of the process that leads it.
  /// This method throws ``Errno/noSuchProcess``
  /// if no process is in the group,
  /// and ``Errno/notPermitted``
  /// if the caller may signal none of the processes that are.
  ///
  /// C's `killpg` has other meanings for group IDs below 2,
  /// including, on some platforms, every process,
  /// so this method throws ``Errno/invalidArgument`` for them.
  ///
  /// The corresponding C function is `killpg`.
  @_alwaysEmitIntoClient
  public func sendSignalToProcessGroup(_ signal: Signal?) throws(Errno) {
    try _sendSignalToProcessGroup(signal).get()
  }

  @usableFromInline
  internal func _sendSignalToProcessGroup(_ signal: Signal?) -> Result<(), Errno> {
    // killpg(1) is kill(-1) on glibc, which signals every process.
    guard rawValue > 1 else { return .failure(.invalidArgument) }
    return nothingOrErrno(retryOnInterrupt: false) {
      system_killpg(rawValue, signal?.rawValue ?? 0)
    }
  }

  /// Sends a signal to every process that the caller may signal,
  /// except for system processes, such as the init process,
  /// and on some platforms except for the caller.
  ///
  /// - Parameter signal: The signal to send.
  ///
  /// This method throws ``Errno/noSuchProcess``
  /// if there's no process it can signal.
  ///
  /// The corresponding C function is `kill`, with a process ID of -1.
  @_alwaysEmitIntoClient
  public static func sendSignalToAllProcesses(_ signal: Signal) throws(Errno) {
    try _sendSignalToAllProcesses(signal).get()
  }

  @usableFromInline
  internal static func _sendSignalToAllProcesses(_ signal: Signal) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_kill(-1, signal.rawValue)
    }
  }
}

// MARK: - Threads

@available(System 199, *)
extension PThread.ID {
  /// Sends a signal to the thread.
  ///
  /// - Parameter signal: The signal to send.
  ///
  /// The thread must belong to the calling process.
  /// The signal's action still applies to the whole process:
  /// by default, ``Signal/terminate`` ends the process,
  /// not only this thread.
  /// A handler, if the signal has one, runs on this thread.
  ///
  /// As for any operation on a thread ID,
  /// the thread must not have been joined, or, if detached, finished:
  /// Darwin reports ``Errno/noSuchProcess`` for such an ID,
  /// and on Linux, using it is undefined behavior.
  ///
  /// The corresponding C function is `pthread_kill`.
  @_alwaysEmitIntoClient
  public func sendSignal(_ signal: Signal) throws(Errno) {
    try _sendSignal(signal).get()
  }

  @usableFromInline
  internal func _sendSignal(_ signal: Signal) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_kill(rawValue, signal.rawValue)
    }
  }
}

// MARK: - The calling thread

@available(System 199, *)
extension Signal {
  /// Sends the signal to the calling thread.
  ///
  /// If the signal has a handler and the thread doesn't block it,
  /// the handler runs before this method returns.
  /// A common use is to end the process as if by the signal,
  /// after restoring its default action,
  /// so that the parent process sees why it ended:
  ///
  ///     try Signal.interrupt.setAction(.default)
  ///     try Signal.interrupt.raise()
  ///
  /// The corresponding C function is `raise`.
  @_alwaysEmitIntoClient
  public func raise() throws(Errno) {
    try _raise().get()
  }

  @usableFromInline
  internal func _raise() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_raise(rawValue)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
