/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Ending the calling process on Windows: ProcessID's exit, exitImmediately,
// abort and addExitHandler, and ProcessID.ExitCode's C-standard codes.
// ProcessExit.swift and ExitCode.swift declare them for the other platforms.

@available(System 199, *)
extension ProcessID {
  /// Ends the calling process with a status,
  /// after running its exit handlers and flushing its C streams.
  ///
  /// - Parameter status: The process's exit status.
  ///   By convention, 0 means success, and other values failure;
  ///   C's `EXIT_SUCCESS` and `EXIT_FAILURE` are 0 and 1.
  ///   On Windows, a parent gets all 32 bits of the status,
  ///   as a `DWORD`: -1 is `0xFFFFFFFF`.
  ///
  /// Ending the process this way runs the handlers
  /// that ``addExitHandler(_:)`` registered,
  /// in the reverse of the order they were registered in,
  /// then flushes and closes the C runtime's streams,
  /// such as the standard output that Swift's `print` writes to,
  /// and then ends the process with `ExitProcess`,
  /// which notifies each loaded DLL and closes the process's handles.
  /// Returning from a program's `main` does the same.
  ///
  /// No Swift code runs after this call but the exit handlers
  /// and the DLLs' notifications:
  /// not the deinitializers of values still alive,
  /// nor any `defer` block.
  /// Other threads keep running until `ExitProcess` ends them,
  /// so they can see the state that the exit handlers tear down.
  /// ``exitImmediately(_:)-(CInt)`` runs nothing.
  ///
  /// The corresponding C function is `exit`.
  @_alwaysEmitIntoClient
  public static func exit(_ status: CInt) -> Never {
    _exitProcess(status)
  }

  @usableFromInline
  internal static func _exitProcess(_ status: CInt) -> Never {
    system_exit(status)
  }

  /// Ends the calling process with a status at once,
  /// without running its exit handlers or flushing its C streams.
  ///
  /// - Parameter status: The process's exit status.
  ///   See ``exit(_:)-(CInt)``.
  ///
  /// Unlike ``exit(_:)-(CInt)``, this method runs no code in the process:
  /// output that a C stream still holds is lost,
  /// which includes what Swift's `print` wrote to a standard output
  /// that's a pipe or a file, unless the stream was flushed,
  /// and no DLL is notified.
  /// Otherwise the process ends as it does with `exit(_:)`:
  /// its handles close, and its parent can wait for it.
  ///
  /// On Windows this is `TerminateProcess` on the calling process,
  /// rather than the C runtime's `_exit`, which ends the process with
  /// `ExitProcess` and so runs the DLLs' notifications, and with them the
  /// exit handlers that DLLs registered.
  ///
  /// The corresponding C function is `TerminateProcess`.
  @_alwaysEmitIntoClient
  public static func exitImmediately(_ status: CInt) -> Never {
    _exitImmediately(status)
  }

  @usableFromInline
  internal static func _exitImmediately(_ status: CInt) -> Never {
    _ = system_TerminateProcess(system_GetCurrentProcess(), UINT(bitPattern: status))
    // TerminateProcess doesn't return when it ends the calling process.
    system__exit(status)
  }

  /// Ends the calling process abnormally, as a crash.
  ///
  /// On Windows, the C runtime first raises `SIGABRT`
  /// if a handler for it was installed with `signal`.
  /// If none was, or the handler returns,
  /// it ends the process with a fast-fail exception,
  /// which no exception handler sees.
  /// Windows Error Reporting records it as a crash,
  /// and, as for any crash, can show a dialog before the process ends.
  /// The exit code that the process's parent reads is then
  /// `STATUS_STACK_BUFFER_OVERRUN` (`0xC0000409`), whatever the cause.
  /// With the debug C runtime, which first shows the message
  /// "abort() has been called", or once `_set_abort_behavior`
  /// turns off `_CALL_REPORTFAULT`,
  /// the process exits with code 3 instead.
  ///
  /// The handlers that ``addExitHandler(_:)`` registered don't run,
  /// and the C streams aren't flushed.
  ///
  /// A failed precondition or `fatalError` traps instead,
  /// which ends the process with the processor's exception for a trap.
  ///
  /// The corresponding C function is `abort`.
  @_alwaysEmitIntoClient
  public static func abort() -> Never {
    _abort()
  }

  @usableFromInline
  internal static func _abort() -> Never {
    system_abort()
  }

  /// Registers a function to run when the calling process exits.
  ///
  /// - Parameter handler: The function to run.
  ///   It's a C function,
  ///   which a closure that captures nothing converts to,
  ///   as does a global function:
  ///
  ///       try ProcessID.addExitHandler {
  ///         Logger.shared.flush()
  ///       }
  ///
  /// The handlers run when the process calls ``exit(_:)-(CInt)``,
  /// or returns from its `main`,
  /// in the reverse of the order they were registered in,
  /// on the thread that ends the process,
  /// while other threads keep running.
  /// A handler registered twice runs twice.
  /// They don't run when the process calls ``exitImmediately(_:)-(CInt)``,
  /// when another process ends it, or when it traps,
  /// as a failed precondition or `fatalError` does.
  /// A handler can't be unregistered.
  ///
  /// On Windows, the C runtime keeps a table of handlers for each DLL as
  /// well as for the program: when System is a DLL of its own, the
  /// handlers run when it's unloaded, which `exit(_:)` does after the
  /// program's handlers run and the C streams are flushed.
  ///
  /// This method throws ``Errno/noMemory`` if the system can't record
  /// another handler. C reports only that the call failed.
  ///
  /// The corresponding C function is `atexit`.
  @_alwaysEmitIntoClient
  public static func addExitHandler(
    _ handler: @convention(c) () -> Void
  ) throws(Errno) {
    try _addExitHandler(handler).get()
  }

  @usableFromInline
  internal static func _addExitHandler(
    _ handler: @convention(c) () -> Void
  ) -> Result<Void, Errno> {
    system_atexit(handler) == 0 ? .success(()) : .failure(.noMemory)
  }
}

// MARK: - Exit codes

@available(System 199, *)
extension ProcessID {
  /// The status a process exits with.
  ///
  /// A process passes its exit code to ``ProcessID/exit(_:)-(ProcessID.ExitCode)``
  /// or ``ProcessID/exitImmediately(_:)-(ProcessID.ExitCode)``,
  /// and the process that waits for it reads it with
  /// ``Win32/ProcessHandle/exitCode()``, as a `DWORD`.
  /// By convention, ``success`` is 0 and every other code is a failure.
  ///
  /// Windows has the C standard's ``success`` and ``failure``, and no
  /// `<sysexits.h>`, so it has none of the other platforms' codes for why a
  /// program failed. A process that crashes exits with the `NTSTATUS` of
  /// the exception, such as `0xC0000005` for an access violation.
  @frozen
  public struct ExitCode: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw exit code.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed exit code from a raw one.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Success.
    ///
    /// The corresponding C constant is `EXIT_SUCCESS`.
    @_alwaysEmitIntoClient
    public static var success: Self { Self(rawValue: _EXIT_SUCCESS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "success")
    public static var EXIT_SUCCESS: Self { success }

    /// Failure, for no particular reason.
    ///
    /// The corresponding C constant is `EXIT_FAILURE`.
    @_alwaysEmitIntoClient
    public static var failure: Self { Self(rawValue: _EXIT_FAILURE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "failure")
    public static var EXIT_FAILURE: Self { failure }
  }
}

@available(System 199, *)
extension ProcessID.ExitCode: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the exit code:
  /// its name, if it has one, and its number,
  /// with its hexadecimal bits for a code whose high bit is set,
  /// as an `NTSTATUS` has.
  @inline(never)
  public var description: String {
    let name: String?
    switch self {
    case .success: name = "success"
    case .failure: name = "failure"
    default: name = nil
    }
    if let name { return "\(name) (\(rawValue))" }
    guard rawValue < 0 else { return "\(rawValue)" }
    return "\(rawValue) (0x\(String(UInt32(bitPattern: rawValue), radix: 16, uppercase: true)))"
  }

  /// A textual representation of the exit code, suitable for debugging.
  public var debugDescription: String { description }
}

@available(System 199, *)
extension ProcessID {
  /// Ends the calling process with an exit code,
  /// after running its exit handlers and flushing its C streams.
  ///
  /// - Parameter code: The process's exit code.
  ///
  /// This method is ``exit(_:)-(CInt)`` with a code's raw value;
  /// see that method for what it runs and in what order.
  ///
  /// The corresponding C function is `exit`.
  @_alwaysEmitIntoClient
  public static func exit(_ code: ExitCode) -> Never {
    _exitProcess(code.rawValue)
  }

  /// Ends the calling process with an exit code at once,
  /// without running its exit handlers or flushing its C streams.
  ///
  /// - Parameter code: The process's exit code.
  ///
  /// This method is ``exitImmediately(_:)-(CInt)`` with a code's raw value.
  ///
  /// The corresponding C function is `TerminateProcess`.
  @_alwaysEmitIntoClient
  public static func exitImmediately(_ code: ExitCode) -> Never {
    _exitImmediately(code.rawValue)
  }
}

#endif // os(Windows)
