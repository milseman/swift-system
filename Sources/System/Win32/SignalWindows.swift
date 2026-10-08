/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design.
//
// Signal on Windows: the C runtime's signals. Signal.swift declares the type
// for the other platforms but WASI. Windows has no signals of its own: the C
// runtime raises them within a process, for raise and abort and for the
// hardware exceptions it maps onto them, and delivers SIGINT and SIGBREAK
// for a console's Ctrl+C and Ctrl+Break. One process can't send another a
// signal; Win32.ProcessHandle's terminate ends one.

#if os(Windows)

import ucrt

/// A signal: a notification that the C runtime delivers to the process.
///
/// On Windows, the C runtime defines seven signals, which a process raises
/// itself, or which the C runtime raises for a console's Ctrl+C and
/// Ctrl+Break and for some hardware exceptions. Their numbers differ from
/// POSIX's for `SIGABRT`, which is 22 on Windows.
///
/// The corresponding C type is `int`, as signal numbers.
@frozen
@available(System 199, *)
public struct Signal: RawRepresentable, Hashable, Sendable {
  /// The raw C signal number.
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  /// Creates a strongly-typed signal from a raw C signal number.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }
}

// The numbers are spelled as literals, as the Win32 namespace's constants
// are; Win32SignalTests checks each one against the C runtime's macro.
@available(System 199, *)
extension Signal {
  /// The user asked to interrupt the process,
  /// typically by typing Control-C in its console.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGINT`.
  @_alwaysEmitIntoClient
  public static var interrupt: Signal { Signal(rawValue: 2) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "interrupt")
  public static var SIGINT: Signal { interrupt }

  /// The process executed an illegal instruction.
  ///
  /// The corresponding C constant is `SIGILL`.
  @_alwaysEmitIntoClient
  public static var illegalInstruction: Signal { Signal(rawValue: 4) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "illegalInstruction")
  public static var SIGILL: Signal { illegalInstruction }

  /// The process performed an erroneous floating-point operation.
  ///
  /// The corresponding C constant is `SIGFPE`.
  @_alwaysEmitIntoClient
  public static var floatingPointException: Signal { Signal(rawValue: 8) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "floatingPointException")
  public static var SIGFPE: Signal { floatingPointException }

  /// The process made an invalid memory access.
  ///
  /// The corresponding C constant is `SIGSEGV`.
  @_alwaysEmitIntoClient
  public static var segmentationViolation: Signal { Signal(rawValue: 11) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "segmentationViolation")
  public static var SIGSEGV: Signal { segmentationViolation }

  /// A request to end the process.
  ///
  /// Windows never sends it: only `raise` does.
  ///
  /// The corresponding C constant is `SIGTERM`.
  @_alwaysEmitIntoClient
  public static var terminate: Signal { Signal(rawValue: 15) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "terminate")
  public static var SIGTERM: Signal { terminate }

  /// The user typed Control-Break in the process's console.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGBREAK`.
  ///
  /// - Note: Only available on Windows.
  @_alwaysEmitIntoClient
  public static var controlBreak: Signal { Signal(rawValue: 21) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "controlBreak")
  public static var SIGBREAK: Signal { controlBreak }

  /// The process aborted, as the C `abort` function does.
  ///
  /// The corresponding C constant is `SIGABRT`.
  @_alwaysEmitIntoClient
  public static var abort: Signal { Signal(rawValue: 22) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "abort")
  public static var SIGABRT: Signal { abort }
}

@available(System 199, *)
extension Signal: CustomStringConvertible, CustomDebugStringConvertible {
  /// The signal's C name, such as `SIGINT`,
  /// or its number, for a signal that has no name here.
  @inline(never)
  public var description: String {
    _name ?? "Signal(rawValue: \(rawValue))"
  }

  /// The signal's C name, such as `SIGINT`,
  /// or its number, for a signal that has no name here.
  public var debugDescription: String { description }

  /// The signal's C name, such as `SIGINT`,
  /// or `nil` for a number that names no signal.
  ///
  /// The C runtime has no table of signal names,
  /// so this is the name ``description`` gives.
  @_alwaysEmitIntoClient
  public var name: String? { _name }

  @usableFromInline
  internal var _name: String? {
    switch rawValue {
    case 2: return "SIGINT"
    case 4: return "SIGILL"
    case 8: return "SIGFPE"
    case 11: return "SIGSEGV"
    case 15: return "SIGTERM"
    case 21: return "SIGBREAK"
    case 22: return "SIGABRT"
    default: return nil
    }
  }
}

@available(System 199, *)
extension Signal {
  /// Raises the signal in the calling thread.
  ///
  /// If the signal has a handler, the handler runs before this method
  /// returns. A signal without one has its default action, which ends the
  /// process.
  ///
  /// A number that names no signal throws ``Errno/invalidArgument``,
  /// rather than reaching the C runtime's invalid parameter handler,
  /// which ends the process by default.
  ///
  /// The corresponding C function is `raise`.
  @_alwaysEmitIntoClient
  public func raise() throws(Errno) {
    try _raise().get()
  }

  @usableFromInline
  internal func _raise() -> Result<(), Errno> {
    guard system_raise(rawValue) == 0 else { return .failure(Errno.current) }
    return .success(())
  }
}

#endif // os(Windows)
