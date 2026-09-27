/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

import CSystem
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

/// How a process ended: it exited with a status, or a signal ended it.
///
///     switch try child.wait() {
///     case .exited(0): print("succeeded")
///     case .exited(let status): print("failed with status \(status)")
///     case .signaled(let signal, _): print("ended by \(signal)")
///     }
@frozen
@available(System 199, *)
public enum ExitStatus: Hashable, Sendable {
  /// The process exited,
  /// with the low 8 bits of the status that it passed to `exit`.
  ///
  /// By convention, 0 means success.
  ///
  /// The corresponding C macros are `WIFEXITED` and `WEXITSTATUS`,
  /// and the C constant is `CLD_EXITED`.
  case exited(CInt)

  /// A signal ended the process.
  ///
  /// `coreDumped` says whether the system also wrote a core file,
  /// which some signals' default actions do,
  /// when the resource limit on core files allows it.
  ///
  /// The corresponding C macros are `WIFSIGNALED`, `WTERMSIG`,
  /// and `WCOREDUMP`, and the C constants are `CLD_KILLED` and `CLD_DUMPED`.
  case signaled(Signal, coreDumped: Bool)
}

@available(System 199, *)
extension ExitStatus {
  /// Whether the process exited with status 0,
  /// which by convention means success.
  @_alwaysEmitIntoClient
  public var isSuccess: Bool { self == .exited(0) }

  /// Decodes the status that a C wait function reports,
  /// for a process that ended.
  ///
  /// - Parameter waitStatus: The status that `waitpid` or `wait` stored.
  ///   A status that reports a stopped or continued process
  ///   returns `nil`.
  @_alwaysEmitIntoClient
  public init?(waitStatus: CInt) {
    guard let status = ExitStatus._decode(waitStatus) else { return nil }
    self = status
  }

  @usableFromInline
  internal static func _decode(_ status: CInt) -> ExitStatus? {
    if csystem_wifexited(status) != 0 {
      return .exited(csystem_wexitstatus(status))
    }
    if csystem_wifsignaled(status) != 0 {
      return .signaled(
        Signal(rawValue: csystem_wtermsig(status)),
        coreDumped: csystem_wcoredump(status) != 0)
    }
    return nil
  }
}

@available(System 199, *)
extension ExitStatus: CustomStringConvertible {
  /// A description of how the process ended,
  /// such as `exited with status 1` or `ended by SIGKILL`.
  public var description: String {
    switch self {
    case .exited(let status):
      return "exited with status \(status)"
    case .signaled(let signal, let coreDumped):
      return "ended by \(signal)" + (coreDumped ? " (core dumped)" : "")
    }
  }
}

/// A change in a child process's state, which a wait reports:
/// it ended, a signal stopped it, or it continued after a stop.
@frozen
@available(System 199, *)
public enum ProcessStateChange: Hashable, Sendable {
  /// The process ended.
  case terminated(ExitStatus)

  /// A signal stopped the process.
  ///
  /// A traced process that stops is also reported this way.
  ///
  /// The corresponding C macros are `WIFSTOPPED` and `WSTOPSIG`,
  /// and the C constants are `CLD_STOPPED` and `CLD_TRAPPED`.
  case stopped(Signal)

  /// The process continued after a stop,
  /// because it received ``Signal/continue``.
  ///
  /// The corresponding C macro is `WIFCONTINUED`,
  /// and the C constant is `CLD_CONTINUED`.
  case continued
}

@available(System 199, *)
extension ProcessStateChange {
  /// Decodes the status that a C wait function reports.
  ///
  /// - Parameter waitStatus: The status that `waitpid` or `wait` stored.
  @_alwaysEmitIntoClient
  public init?(waitStatus: CInt) {
    guard let change = ProcessStateChange._decode(waitStatus) else { return nil }
    self = change
  }

  @usableFromInline
  internal static func _decode(_ status: CInt) -> ProcessStateChange? {
    if let exit = ExitStatus._decode(status) { return .terminated(exit) }
    // Darwin encodes a continued process as one stopped by SIGCONT, so
    // check for that first.
    if csystem_wifcontinued(status) != 0 { return .continued }
    if csystem_wifstopped(status) != 0 {
      return .stopped(Signal(rawValue: csystem_wstopsig(status)))
    }
    return nil
  }

  /// Decodes the information that `waitid` reports,
  /// or `nil` if it reports no child.
  ///
  /// - Parameter information: The information that `waitid` filled in,
  ///   or that a ``Signal/childStatusChange`` handler received.
  @_alwaysEmitIntoClient
  public init?(_ information: Signal.Information) {
    guard let change = ProcessStateChange._decode(information) else { return nil }
    self = change
  }

  @usableFromInline
  internal static func _decode(_ information: Signal.Information) -> ProcessStateChange? {
    // With WNOHANG, waitid reports no child by leaving si_pid zero.
    guard information._processID != 0 else { return nil }
    let status = information._status
    switch information.code {
    case _CLD_EXITED:
      return .terminated(.exited(status))
    case _CLD_KILLED:
      return .terminated(.signaled(Signal(rawValue: status), coreDumped: false))
    case _CLD_DUMPED:
      return .terminated(.signaled(Signal(rawValue: status), coreDumped: true))
    case _CLD_STOPPED, _CLD_TRAPPED:
      return .stopped(Signal(rawValue: status))
    case _CLD_CONTINUED:
      return .continued
    default:
      // A wait reports only the codes above.
      return nil
    }
  }
}

@available(System 199, *)
extension ProcessStateChange: CustomStringConvertible {
  /// A description of the change,
  /// such as `exited with status 1` or `stopped by SIGTSTP`.
  public var description: String {
    switch self {
    case .terminated(let status): return status.description
    case .stopped(let signal): return "stopped by \(signal)"
    case .continued: return "continued"
    }
  }
}

#endif // !os(Windows) && !os(WASI)
