/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

/// A signal: a notification that the system delivers to a process or a
/// thread, asynchronously.
///
/// Each signal has a default action,
/// such as ending the process or doing nothing,
/// which a process can change with ``setAction(_:)``.
/// Its number differs between platforms:
/// `SIGUSR1` is 30 on Darwin and 10 on Linux.
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

@available(System 199, *)
extension Signal {
  /// The terminal hung up, or the process that controlled it ended.
  ///
  /// A daemon, which has no terminal,
  /// often treats this signal as a request to reload its configuration.
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGHUP`.
  @_alwaysEmitIntoClient
  public static var hangup: Signal { Signal(rawValue: _SIGHUP) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "hangup")
  public static var SIGHUP: Signal { hangup }

  /// The user asked to interrupt the process,
  /// typically by typing Control-C in its terminal.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGINT`.
  @_alwaysEmitIntoClient
  public static var interrupt: Signal { Signal(rawValue: _SIGINT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "interrupt")
  public static var SIGINT: Signal { interrupt }

  /// The user asked the process to quit,
  /// typically by typing Control-Backslash in its terminal.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGQUIT`.
  @_alwaysEmitIntoClient
  public static var quit: Signal { Signal(rawValue: _SIGQUIT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "quit")
  public static var SIGQUIT: Signal { quit }

  /// The process executed an illegal instruction.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGILL`.
  @_alwaysEmitIntoClient
  public static var illegalInstruction: Signal { Signal(rawValue: _SIGILL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "illegalInstruction")
  public static var SIGILL: Signal { illegalInstruction }

  /// The process reached a breakpoint or a trace trap.
  ///
  /// Swift's runtime traps, such as a failed precondition,
  /// deliver this signal on some platforms.
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGTRAP`.
  @_alwaysEmitIntoClient
  public static var traceTrap: Signal { Signal(rawValue: _SIGTRAP) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "traceTrap")
  public static var SIGTRAP: Signal { traceTrap }

  /// The process aborted, as the C `abort` function does.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGABRT`.
  @_alwaysEmitIntoClient
  public static var abort: Signal { Signal(rawValue: _SIGABRT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "abort")
  public static var SIGABRT: Signal { abort }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "abort")
  public static var SIGIOT: Signal { abort }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The process executed an instruction that the system emulates.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGEMT`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var emulatorTrap: Signal { Signal(rawValue: _SIGEMT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "emulatorTrap")
  public static var SIGEMT: Signal { emulatorTrap }
  #endif

  /// The process performed an erroneous arithmetic operation,
  /// such as dividing an integer by zero.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGFPE`.
  @_alwaysEmitIntoClient
  public static var floatingPointException: Signal { Signal(rawValue: _SIGFPE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "floatingPointException")
  public static var SIGFPE: Signal { floatingPointException }

  /// Ends the process immediately.
  ///
  /// This signal can't be caught, blocked, or ignored,
  /// so the process can't clean up.
  ///
  /// The corresponding C constant is `SIGKILL`.
  @_alwaysEmitIntoClient
  public static var kill: Signal { Signal(rawValue: _SIGKILL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "kill")
  public static var SIGKILL: Signal { kill }

  /// The process accessed memory in a way the hardware doesn't allow,
  /// such as a misaligned access,
  /// or an access to a mapped file beyond its end.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGBUS`.
  @_alwaysEmitIntoClient
  public static var busError: Signal { Signal(rawValue: _SIGBUS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "busError")
  public static var SIGBUS: Signal { busError }

  /// The process accessed memory that isn't mapped,
  /// or accessed mapped memory in a way its protection doesn't allow.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGSEGV`.
  @_alwaysEmitIntoClient
  public static var segmentationViolation: Signal { Signal(rawValue: _SIGSEGV) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "segmentationViolation")
  public static var SIGSEGV: Signal { segmentationViolation }

  /// The process made a system call that doesn't exist,
  /// or that a security policy forbids.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGSYS`.
  @_alwaysEmitIntoClient
  public static var badSystemCall: Signal { Signal(rawValue: _SIGSYS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "badSystemCall")
  public static var SIGSYS: Signal { badSystemCall }

  /// The process wrote to a pipe or a socket
  /// whose other end is closed.
  ///
  /// By default, this signal ends the process.
  /// A process that ignores it, with ``Action/ignore``,
  /// gets ``Errno/brokenPipe`` from the write instead.
  ///
  /// The corresponding C constant is `SIGPIPE`.
  @_alwaysEmitIntoClient
  public static var brokenPipe: Signal { Signal(rawValue: _SIGPIPE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "brokenPipe")
  public static var SIGPIPE: Signal { brokenPipe }

  /// A timer that measures real time, such as `alarm`'s, expired.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGALRM`.
  @_alwaysEmitIntoClient
  public static var alarm: Signal { Signal(rawValue: _SIGALRM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "alarm")
  public static var SIGALRM: Signal { alarm }

  /// Asks the process to end.
  ///
  /// Unlike ``kill``, this signal can be caught,
  /// so the process can clean up before it ends.
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGTERM`.
  @_alwaysEmitIntoClient
  public static var terminate: Signal { Signal(rawValue: _SIGTERM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "terminate")
  public static var SIGTERM: Signal { terminate }

  /// Out-of-band data arrived on a socket.
  ///
  /// By default, the system discards this signal.
  ///
  /// The corresponding C constant is `SIGURG`.
  @_alwaysEmitIntoClient
  public static var urgentCondition: Signal { Signal(rawValue: _SIGURG) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "urgentCondition")
  public static var SIGURG: Signal { urgentCondition }

  /// Stops the process until it receives ``continue``.
  ///
  /// This signal can't be caught, blocked, or ignored.
  ///
  /// The corresponding C constant is `SIGSTOP`.
  @_alwaysEmitIntoClient
  public static var stop: Signal { Signal(rawValue: _SIGSTOP) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "stop")
  public static var SIGSTOP: Signal { stop }

  /// The user asked to stop the process,
  /// typically by typing Control-Z in its terminal.
  ///
  /// Unlike ``stop``, this signal can be caught.
  /// By default, this signal stops the process.
  ///
  /// The corresponding C constant is `SIGTSTP`.
  @_alwaysEmitIntoClient
  public static var terminalStop: Signal { Signal(rawValue: _SIGTSTP) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "terminalStop")
  public static var SIGTSTP: Signal { terminalStop }

  /// Continues a stopped process.
  ///
  /// The system continues the process when it sends this signal,
  /// even if the process catches or ignores it.
  /// By default, the process does nothing more.
  ///
  /// The corresponding C constant is `SIGCONT`.
  @_alwaysEmitIntoClient
  public static var `continue`: Signal { Signal(rawValue: _SIGCONT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "continue")
  public static var SIGCONT: Signal { .continue }

  /// A child process exited, or stopped or continued.
  ///
  /// By default, the system discards this signal.
  /// Setting its action to ``Action/ignore``
  /// also stops terminated children from becoming zombies,
  /// so no wait can report their status.
  ///
  /// The corresponding C constant is `SIGCHLD`.
  @_alwaysEmitIntoClient
  public static var childStatusChange: Signal { Signal(rawValue: _SIGCHLD) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "childStatusChange")
  public static var SIGCHLD: Signal { childStatusChange }

  /// A process in a background process group
  /// tried to read from its controlling terminal.
  ///
  /// By default, this signal stops the process.
  ///
  /// The corresponding C constant is `SIGTTIN`.
  @_alwaysEmitIntoClient
  public static var backgroundRead: Signal { Signal(rawValue: _SIGTTIN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "backgroundRead")
  public static var SIGTTIN: Signal { backgroundRead }

  /// A process in a background process group
  /// tried to write to its controlling terminal,
  /// or to change the terminal's attributes.
  ///
  /// By default, this signal stops the process.
  ///
  /// The corresponding C constant is `SIGTTOU`.
  @_alwaysEmitIntoClient
  public static var backgroundWrite: Signal { Signal(rawValue: _SIGTTOU) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "backgroundWrite")
  public static var SIGTTOU: Signal { backgroundWrite }

  /// Input or output is possible on a file descriptor
  /// that has ``FileDescriptor/StatusFlags/async`` set.
  ///
  /// By default, the system discards this signal on Darwin and the BSDs,
  /// and ends the process on Linux.
  ///
  /// The corresponding C constant is `SIGIO`.
  @_alwaysEmitIntoClient
  public static var ioPossible: Signal { Signal(rawValue: _SIGIO) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "ioPossible")
  public static var SIGIO: Signal { ioPossible }

  /// The process exceeded its soft limit on processor time,
  /// ``ResourceLimit/Resource/cpuTime``.
  ///
  /// By default, this signal ends the process and writes a core file.
  ///
  /// The corresponding C constant is `SIGXCPU`.
  @_alwaysEmitIntoClient
  public static var cpuTimeLimitExceeded: Signal { Signal(rawValue: _SIGXCPU) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "cpuTimeLimitExceeded")
  public static var SIGXCPU: Signal { cpuTimeLimitExceeded }

  /// The process tried to grow a file beyond its limit on file size,
  /// ``ResourceLimit/Resource/fileSize``.
  ///
  /// By default, this signal ends the process and writes a core file.
  /// A process that ignores it gets ``Errno/fileTooLarge`` instead.
  ///
  /// The corresponding C constant is `SIGXFSZ`.
  @_alwaysEmitIntoClient
  public static var fileSizeLimitExceeded: Signal { Signal(rawValue: _SIGXFSZ) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "fileSizeLimitExceeded")
  public static var SIGXFSZ: Signal { fileSizeLimitExceeded }

  /// A timer that measures the process's time in user mode expired.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGVTALRM`.
  @_alwaysEmitIntoClient
  public static var virtualAlarm: Signal { Signal(rawValue: _SIGVTALRM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "virtualAlarm")
  public static var SIGVTALRM: Signal { virtualAlarm }

  /// A profiling timer, which measures the process's processor time, expired.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGPROF`.
  @_alwaysEmitIntoClient
  public static var profilingAlarm: Signal { Signal(rawValue: _SIGPROF) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "profilingAlarm")
  public static var SIGPROF: Signal { profilingAlarm }

  /// The size of the process's controlling terminal changed.
  ///
  /// By default, the system discards this signal.
  /// ``TerminalDescriptor/windowSize()`` reports the new size.
  ///
  /// The corresponding C constant is `SIGWINCH`.
  @_alwaysEmitIntoClient
  public static var windowSizeChange: Signal { Signal(rawValue: _SIGWINCH) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "windowSizeChange")
  public static var SIGWINCH: Signal { windowSizeChange }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The user asked the process for a status report,
  /// typically by typing Control-T in its terminal.
  ///
  /// By default, the system discards this signal.
  ///
  /// The corresponding C constant is `SIGINFO`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var informationRequest: Signal { Signal(rawValue: _SIGINFO) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "informationRequest")
  public static var SIGINFO: Signal { informationRequest }
  #endif

  /// A signal whose meaning the program defines.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGUSR1`.
  @_alwaysEmitIntoClient
  public static var userDefined1: Signal { Signal(rawValue: _SIGUSR1) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userDefined1")
  public static var SIGUSR1: Signal { userDefined1 }

  /// A second signal whose meaning the program defines.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGUSR2`.
  @_alwaysEmitIntoClient
  public static var userDefined2: Signal { Signal(rawValue: _SIGUSR2) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userDefined2")
  public static var SIGUSR2: Signal { userDefined2 }

  #if os(Linux) || os(Android)
  /// The system's power supply is failing.
  ///
  /// By default, this signal ends the process.
  ///
  /// The corresponding C constant is `SIGPWR`.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var powerFailure: Signal { Signal(rawValue: _SIGPWR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "powerFailure")
  public static var SIGPWR: Signal { powerFailure }
  #endif
}

@available(System 199, *)
extension Signal: CustomStringConvertible, CustomDebugStringConvertible {
  /// The signal's C name, such as `SIGINT`,
  /// or its number, for a signal that has no name here.
  @inline(never)
  public var description: String {
    for (signal, name) in Signal._names where signal == self {
      return name.description
    }
    return "Signal(rawValue: \(rawValue))"
  }

  /// The signal's C name, such as `SIGINT`,
  /// or its number, for a signal that has no name here.
  public var debugDescription: String { description }

  // Every signal that has a name here, in increasing order on Darwin, with
  // its C name.
  internal static var _names: [(Signal, StaticString)] {
    var names: [(Signal, StaticString)] = [
      (.hangup, "SIGHUP"), (.interrupt, "SIGINT"), (.quit, "SIGQUIT"),
      (.illegalInstruction, "SIGILL"), (.traceTrap, "SIGTRAP"), (.abort, "SIGABRT"),
      (.floatingPointException, "SIGFPE"), (.kill, "SIGKILL"), (.busError, "SIGBUS"),
      (.segmentationViolation, "SIGSEGV"), (.badSystemCall, "SIGSYS"),
      (.brokenPipe, "SIGPIPE"), (.alarm, "SIGALRM"), (.terminate, "SIGTERM"),
      (.urgentCondition, "SIGURG"), (.stop, "SIGSTOP"), (.terminalStop, "SIGTSTP"),
      (.continue, "SIGCONT"), (.childStatusChange, "SIGCHLD"),
      (.backgroundRead, "SIGTTIN"), (.backgroundWrite, "SIGTTOU"), (.ioPossible, "SIGIO"),
      (.cpuTimeLimitExceeded, "SIGXCPU"), (.fileSizeLimitExceeded, "SIGXFSZ"),
      (.virtualAlarm, "SIGVTALRM"), (.profilingAlarm, "SIGPROF"),
      (.windowSizeChange, "SIGWINCH"), (.userDefined1, "SIGUSR1"),
      (.userDefined2, "SIGUSR2"),
    ]
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    names.append((.emulatorTrap, "SIGEMT"))
    names.append((.informationRequest, "SIGINFO"))
    #endif
    #if os(Linux) || os(Android)
    names.append((.powerFailure, "SIGPWR"))
    #endif
    return names
  }
}

#endif // !os(Windows) && !os(WASI)
