/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

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

// MARK: - Waiting for a child to end

@available(System 199, *)
extension ProcessID {
  /// Waits for the child process to end, and reaps it.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the wait
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to try only once
  ///   and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: How the process ended.
  ///
  /// A child that ends stays a zombie, keeping its process ID,
  /// until its parent reaps it by waiting.
  /// After this method returns,
  /// the system can give the ID to another process,
  /// so don't signal or wait for it again.
  /// A process that isn't an unreaped child of the caller
  /// throws ``Errno/noChildProcess``.
  ///
  /// The corresponding C function is `waitpid`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread; wait for the process's exit event instead, then call tryWait()")
  public func wait(retryOnInterrupt: Bool = true) throws(Errno) -> ExitStatus {
    try _wait(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _wait(retryOnInterrupt: Bool) -> Result<ExitStatus, Errno> {
    var status: CInt = 0
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_waitpid(rawValue, &status, 0)
    }.map { _ in
      // Without WUNTRACED or WCONTINUED, waitpid reports only an end.
      ExitStatus._decode(status) ?? .exited(0)
    }
  }

  /// Reaps the child process if it has ended, without waiting.
  ///
  /// - Returns: How the process ended,
  ///   or `nil` if it's still running.
  ///
  /// A process that isn't an unreaped child of the caller
  /// throws ``Errno/noChildProcess``.
  /// See ``wait(retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `waitpid`, with `WNOHANG`.
  @_alwaysEmitIntoClient
  public func tryWait() throws(Errno) -> ExitStatus? {
    try _tryWait().get()
  }

  @usableFromInline
  internal func _tryWait() -> Result<ExitStatus?, Errno> {
    var status: CInt = 0
    return valueOrErrno(retryOnInterrupt: false) {
      system_waitpid(rawValue, &status, _WNOHANG)
    }.map { reaped in
      reaped == 0 ? nil : ExitStatus._decode(status)
    }
  }

  /// Waits for any child process to end, and reaps it.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the wait
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to try only once
  ///   and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: The child that ended, and how.
  ///
  /// This method reaps a child of the whole process,
  /// including one that other code, such as a library, started
  /// and still expects to wait for.
  /// A process without children throws ``Errno/noChildProcess``.
  ///
  /// The corresponding C function is `waitpid`, with a process ID of -1.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public static func waitForAnyChild(
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (id: ProcessID, status: ExitStatus) {
    try _waitForAnyChild(options: 0, retryOnInterrupt: retryOnInterrupt).get()!
  }

  /// Reaps any child process that has ended, without waiting.
  ///
  /// - Returns: A child that ended, and how,
  ///   or `nil` if every child is still running.
  ///
  /// A process that handles ``Signal/childStatusChange``
  /// calls this method until it returns `nil`,
  /// since the system can deliver one signal for several children.
  /// See ``waitForAnyChild(retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `waitpid`,
  /// with a process ID of -1 and `WNOHANG`.
  @_alwaysEmitIntoClient
  public static func tryWaitForAnyChild() throws(Errno) -> (id: ProcessID, status: ExitStatus)? {
    try _waitForAnyChild(options: _WNOHANG, retryOnInterrupt: false).get()
  }

  @usableFromInline
  internal static func _waitForAnyChild(
    options: CInt, retryOnInterrupt: Bool
  ) -> Result<(id: ProcessID, status: ExitStatus)?, Errno> {
    var status: CInt = 0
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_waitpid(-1, &status, options)
    }.map { reaped in
      guard reaped != 0 || options & _WNOHANG == 0 else { return nil }
      return (ProcessID(rawValue: reaped), ExitStatus._decode(status) ?? .exited(0))
    }
  }
}

// MARK: - Waiting for a change of state

@available(System 199, *)
extension ProcessID {
  /// The changes of state that a wait reports, and how it waits.
  ///
  /// A wait reports at least one of ``exited``, ``stopped``,
  /// and ``continued``.
  @frozen
  public struct WaitOptions: OptionSet, Sendable, Hashable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Reports a child that ended.
    ///
    /// The corresponding C constant is `WEXITED`.
    @_alwaysEmitIntoClient
    public static var exited: WaitOptions { WaitOptions(rawValue: _WEXITED) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "exited")
    public static var WEXITED: WaitOptions { exited }

    /// Reports a child that a signal stopped.
    ///
    /// The corresponding C constant is `WSTOPPED`.
    @_alwaysEmitIntoClient
    public static var stopped: WaitOptions { WaitOptions(rawValue: _WSTOPPED) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "stopped")
    public static var WSTOPPED: WaitOptions { stopped }

    /// Reports a child that continued after a stop.
    ///
    /// The corresponding C constant is `WCONTINUED`.
    @_alwaysEmitIntoClient
    public static var continued: WaitOptions { WaitOptions(rawValue: _WCONTINUED) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "continued")
    public static var WCONTINUED: WaitOptions { continued }

    /// Returns immediately, rather than waiting,
    /// if no child has changed state.
    ///
    /// The corresponding C constant is `WNOHANG`.
    @_alwaysEmitIntoClient
    public static var noHang: WaitOptions { WaitOptions(rawValue: _WNOHANG) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "noHang")
    public static var WNOHANG: WaitOptions { noHang }

    /// Leaves the child waitable:
    /// an ended child stays a zombie,
    /// so that its ID stays reserved and a later wait reports it again.
    ///
    /// The corresponding C constant is `WNOWAIT`.
    @_alwaysEmitIntoClient
    public static var keepWaitable: WaitOptions { WaitOptions(rawValue: _WNOWAIT) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "keepWaitable")
    public static var WNOWAIT: WaitOptions { keepWaitable }
  }

  /// Waits for the child process to change state.
  ///
  /// - Parameters:
  ///   - options: The changes to report,
  ///     and options for how to wait.
  ///     To check whether a child has ended without reaping it,
  ///     pass `[.exited, .noHang, .keepWaitable]`.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     Pass `false` to try only once
  ///     and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: How the process changed state,
  ///   or `nil`, with ``WaitOptions/noHang``,
  ///   if it hasn't changed in one of the ways that `options` asks for.
  ///
  /// Reporting that a child ended reaps it,
  /// unless `options` includes ``WaitOptions/keepWaitable``.
  /// A process that isn't an unreaped child of the caller
  /// throws ``Errno/noChildProcess``.
  ///
  /// Unless `options` includes ``WaitOptions/noHang``,
  /// this method blocks the calling thread.
  ///
  /// The corresponding C function is `waitid`, with `P_PID`.
  @_alwaysEmitIntoClient
  public func wait(
    for options: WaitOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> ProcessStateChange? {
    try ProcessID._waitID(
      _P_PID, id_t(truncatingIfNeeded: rawValue), options: options, retryOnInterrupt: retryOnInterrupt
    ).get()?.change
  }

  /// Waits for any child process to change state,
  /// or any child in a process group.
  ///
  /// - Parameters:
  ///   - group: The process group whose children to wait for,
  ///     or `nil` for any child.
  ///   - options: The changes to report,
  ///     and options for how to wait.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     Pass `false` to try only once
  ///     and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: The child that changed state, and how,
  ///   or `nil`, with ``WaitOptions/noHang``,
  ///   if no child has changed in one of the ways that `options` asks for.
  ///
  /// See ``wait(for:retryOnInterrupt:)`` and ``waitForAnyChild(retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `waitid`, with `P_ALL` or `P_PGID`.
  @_alwaysEmitIntoClient
  public static func waitForAnyChild(
    inProcessGroup group: ProcessID? = nil,
    for options: WaitOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (id: ProcessID, change: ProcessStateChange)? {
    try ProcessID._waitID(
      group == nil ? _P_ALL : _P_PGID, id_t(truncatingIfNeeded: group?.rawValue ?? 0),
      options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _waitID(
    _ type: idtype_t, _ id: id_t, options: WaitOptions, retryOnInterrupt: Bool
  ) -> Result<(id: ProcessID, change: ProcessStateChange)?, Errno> {
    var info = CInterop.SignalInfo()
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_waitid(type, id, &info, options.rawValue)
    }.map {
      let information = Signal.Information(rawValue: info)
      guard let change = ProcessStateChange._decode(information) else { return nil }
      return (information.processID, change)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
