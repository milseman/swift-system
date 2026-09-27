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

// MARK: - Actions

@available(System 199, *)
extension Signal {
  /// What the system does when it delivers a signal:
  /// the signal's default action, nothing, or calling a function.
  ///
  /// The most common change is to ignore a signal,
  /// such as ``Signal/brokenPipe``,
  /// so that writing to a closed pipe fails with an error
  /// instead of ending the process:
  ///
  ///     try Signal.brokenPipe.setAction(.ignore)
  ///
  /// The corresponding C type is `struct sigaction`.
  @frozen
  public struct Action: Hashable, Sendable {
    /// What the system does with the signal.
    public var handler: Handler

    /// The signals to block, in addition to this one,
    /// while a handler function runs.
    ///
    /// The corresponding C field is `sa_mask`.
    public var mask: SignalSet

    /// Options for the action.
    ///
    /// The corresponding C field is `sa_flags`,
    /// except for `SA_SIGINFO`, which ``handler`` determines.
    public var flags: Flags

    /// Creates an action.
    ///
    /// - Parameters:
    ///   - handler: What the system does with the signal.
    ///   - mask: The signals to block, in addition to this one,
    ///     while a handler function runs.
    ///   - flags: Options for the action.
    @_alwaysEmitIntoClient
    public init(handler: Handler, mask: SignalSet = SignalSet(), flags: Flags = []) {
      self.handler = handler
      self.mask = mask
      self.flags = flags
    }

    /// The signal's default action,
    /// such as ending the process.
    ///
    /// The corresponding C constant is `SIG_DFL`.
    @_alwaysEmitIntoClient
    public static var `default`: Action { Action(handler: .default) }

    /// Ignoring the signal: the system discards it.
    ///
    /// The system never lets a process ignore
    /// ``Signal/kill`` or ``Signal/stop``.
    ///
    /// The corresponding C constant is `SIG_IGN`.
    @_alwaysEmitIntoClient
    public static var ignore: Action { Action(handler: .ignore) }
  }

  /// What the system does with a signal: take its default action,
  /// discard it, or call a function.
  ///
  /// A handler function runs on whatever thread the signal interrupts,
  /// possibly in the middle of other code on that thread,
  /// so it must do only what's safe there:
  /// call only async-signal-safe functions, such as `write`,
  /// and store only to atomics or other lock-free state.
  /// Swift code that allocates, takes a lock,
  /// or reads a global for the first time, which initializes it,
  /// isn't safe in a handler.
  /// A handler that must do more
  /// can write a byte to a pipe that another thread watches.
  @frozen
  public enum Handler: Hashable, Sendable {
    /// The signal's default action.
    ///
    /// The corresponding C constant is `SIG_DFL`.
    case `default`

    /// Discarding the signal.
    ///
    /// The corresponding C constant is `SIG_IGN`.
    case ignore

    /// Calling a function with the signal's number.
    ///
    /// The corresponding C field is `sa_handler`.
    case function(@convention(c) (CInt) -> Void)

    /// Calling a function with the signal's number,
    /// information about its cause,
    /// and the context that it interrupted.
    ///
    /// The second argument points to the information,
    /// which ``Signal/Information`` interprets,
    /// and the third to a `ucontext_t`.
    ///
    /// The corresponding C field is `sa_sigaction`,
    /// with the `SA_SIGINFO` flag.
    case functionWithInfo(
      @convention(c) (
        CInt, UnsafeMutablePointer<CInterop.SignalInfo>?, UnsafeMutableRawPointer?
      ) -> Void)

    /// Whether two handlers are the same function,
    /// or the same default or ignoring.
    @_alwaysEmitIntoClient
    public static func == (lhs: Handler, rhs: Handler) -> Bool {
      lhs._bits == rhs._bits && lhs._takesInfo == rhs._takesInfo
    }

    @_alwaysEmitIntoClient
    public func hash(into hasher: inout Hasher) {
      hasher.combine(_bits)
      hasher.combine(_takesInfo)
    }

    // The handler's value in the C structure: SIG_DFL is 0 and SIG_IGN is 1
    // on every platform this package supports.
    @_alwaysEmitIntoClient
    internal var _bits: UnsafeRawPointer? {
      switch self {
      case .default: return nil
      case .ignore: return UnsafeRawPointer(bitPattern: 1)
      case .function(let function): return unsafeBitCast(function, to: UnsafeRawPointer.self)
      case .functionWithInfo(let function):
        return unsafeBitCast(function, to: UnsafeRawPointer.self)
      }
    }

    @_alwaysEmitIntoClient
    internal var _takesInfo: Bool {
      if case .functionWithInfo = self { return true }
      return false
    }
  }
}

@available(System 199, *)
extension Signal.Action {
  /// Options for a signal's action.
  @frozen
  public struct Flags: OptionSet, Sendable, Hashable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Restarts a system call that the signal interrupts,
    /// rather than failing it with ``Errno/interrupted``.
    ///
    /// Only some calls restart, and which varies by platform;
    /// System's calls retry after an interruption by default anyway.
    ///
    /// The corresponding C constant is `SA_RESTART`.
    @_alwaysEmitIntoClient
    public static var restart: Flags { Flags(rawValue: _SA_RESTART) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "restart")
    public static var SA_RESTART: Flags { restart }

    /// Resets the action to the default when the system delivers the signal,
    /// so that the handler runs only once.
    ///
    /// The corresponding C constant is `SA_RESETHAND`.
    @_alwaysEmitIntoClient
    public static var resetHandler: Flags { Flags(rawValue: _SA_RESETHAND) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "resetHandler")
    public static var SA_RESETHAND: Flags { resetHandler }

    /// Lets the signal interrupt its own handler,
    /// rather than blocking it while the handler runs.
    ///
    /// The corresponding C constant is `SA_NODEFER`.
    @_alwaysEmitIntoClient
    public static var noDefer: Flags { Flags(rawValue: _SA_NODEFER) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "noDefer")
    public static var SA_NODEFER: Flags { noDefer }

    /// Runs the handler on the thread's alternate signal stack,
    /// if it has one.
    ///
    /// The corresponding C constant is `SA_ONSTACK`.
    @_alwaysEmitIntoClient
    public static var alternateStack: Flags { Flags(rawValue: _SA_ONSTACK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "alternateStack")
    public static var SA_ONSTACK: Flags { alternateStack }

    /// For ``Signal/childStatusChange``,
    /// delivers the signal only when a child exits,
    /// and not when it stops or continues.
    ///
    /// The corresponding C constant is `SA_NOCLDSTOP`.
    @_alwaysEmitIntoClient
    public static var noChildStop: Flags { Flags(rawValue: _SA_NOCLDSTOP) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "noChildStop")
    public static var SA_NOCLDSTOP: Flags { noChildStop }

    /// For ``Signal/childStatusChange``,
    /// stops terminated children from becoming zombies,
    /// so that no wait can report their status.
    ///
    /// The corresponding C constant is `SA_NOCLDWAIT`.
    @_alwaysEmitIntoClient
    public static var noChildWait: Flags { Flags(rawValue: _SA_NOCLDWAIT) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "noChildWait")
    public static var SA_NOCLDWAIT: Flags { noChildWait }
  }
}

@available(System 199, *)
extension Signal.Action: RawRepresentable {
  /// Creates an action from a raw C `struct sigaction`.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.SignalAction) {
    self = Signal.Action._decode(rawValue)
  }

  /// The raw C `struct sigaction`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.SignalAction { _encode() }

  @usableFromInline
  internal static func _decode(_ raw: CInterop.SignalAction) -> Signal.Action {
    var raw = raw
    let bits = UnsafeRawPointer(csystem_sigaction_handler(&raw))
    let flags = Flags(rawValue: raw.sa_flags)
    let handler: Signal.Handler
    switch bits {
    case nil:
      handler = .default
    case UnsafeRawPointer(bitPattern: 1):
      handler = .ignore
    case let bits? where flags.contains(Flags(rawValue: _SA_SIGINFO)):
      handler = .functionWithInfo(unsafeBitCast(bits, to: Signal.Handler._InfoFunction.self))
    case let bits?:
      handler = .function(unsafeBitCast(bits, to: Signal.Handler._Function.self))
    }
    return Signal.Action(
      handler: handler,
      mask: SignalSet(rawValue: raw.sa_mask),
      flags: flags.subtracting(Flags(rawValue: _SA_SIGINFO)))
  }

  @usableFromInline
  internal func _encode() -> CInterop.SignalAction {
    var raw = CInterop.SignalAction()
    csystem_sigaction_set_handler(&raw, UnsafeMutableRawPointer(mutating: handler._bits))
    raw.sa_mask = mask.rawValue
    var flags = self.flags.subtracting(Flags(rawValue: _SA_SIGINFO))
    if handler._takesInfo { flags.insert(Flags(rawValue: _SA_SIGINFO)) }
    raw.sa_flags = flags.rawValue
    return raw
  }
}

@available(System 199, *)
extension Signal.Handler {
  @usableFromInline
  internal typealias _Function = @convention(c) (CInt) -> Void

  @usableFromInline
  internal typealias _InfoFunction = @convention(c) (
    CInt, UnsafeMutablePointer<CInterop.SignalInfo>?, UnsafeMutableRawPointer?
  ) -> Void
}

@available(System 199, *)
extension Signal {
  /// Returns the signal's action.
  ///
  /// The corresponding C function is `sigaction`.
  @_alwaysEmitIntoClient
  public func action() throws(Errno) -> Action {
    try _action(nil).get()
  }

  /// Sets the signal's action.
  ///
  /// - Parameter action: What the system does
  ///   when it delivers the signal from now on.
  /// - Returns: The signal's previous action,
  ///   for restoring it later.
  ///
  /// The action belongs to the whole process,
  /// and so does ignoring a signal:
  /// a child process that `exec` starts inherits ignored signals,
  /// and the default action for signals that ran a handler.
  /// ``Signal/kill`` and ``Signal/stop`` can't have another action,
  /// and setting one throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `sigaction`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func setAction(_ action: Action) throws(Errno) -> Action {
    try _action(action).get()
  }

  @usableFromInline
  internal func _action(_ new: Action?) -> Result<Action, Errno> {
    var old = CInterop.SignalAction()
    let result: Result<(), Errno>
    if let new {
      let raw = new.rawValue
      result = withUnsafePointer(to: raw) { raw in
        nothingOrErrno(retryOnInterrupt: false) {
          system_sigaction(rawValue, raw, &old)
        }
      }
    } else {
      result = nothingOrErrno(retryOnInterrupt: false) {
        system_sigaction(rawValue, nil, &old)
      }
    }
    return result.map { Action(rawValue: old) }
  }
}

// MARK: - Information

@available(System 199, *)
extension Signal {
  /// Information about why the system delivered a signal,
  /// or about a child process's change of state.
  ///
  /// A handler function set with ``Handler/functionWithInfo(_:)``
  /// receives it, as does a wait that reports a child's state.
  /// Reading it is safe in a handler.
  ///
  /// The corresponding C type is `siginfo_t`.
  @frozen
  public struct Information: RawRepresentable, @unchecked Sendable {
    // An address in the information is a value, which this type never
    // dereferences, so it's safe to send.

    /// The raw C `siginfo_t`.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.SignalInfo

    /// Creates strongly-typed signal information from a raw C `siginfo_t`.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.SignalInfo) { self.rawValue = rawValue }

    /// The signal.
    ///
    /// The corresponding C field is `si_signo`.
    @_alwaysEmitIntoClient
    public var signal: Signal { Signal(rawValue: rawValue.si_signo) }

    /// Why the system delivered the signal.
    ///
    /// Its meaning depends on the signal:
    /// for ``Signal/childStatusChange``,
    /// it's a C constant such as `CLD_EXITED`,
    /// and for a signal that a process sent, it's `SI_USER`.
    ///
    /// The corresponding C field is `si_code`.
    @_alwaysEmitIntoClient
    public var code: CInt { rawValue.si_code }

    /// The process that sent the signal,
    /// or the child process that changed state.
    ///
    /// The corresponding C field is `si_pid`.
    @_alwaysEmitIntoClient
    public var processID: ProcessID { ProcessID(rawValue: _processID) }

    @usableFromInline
    internal var _processID: CInterop.ProcessID {
      withUnsafePointer(to: rawValue) { csystem_siginfo_pid($0) }
    }

    /// The real user ID of the process that sent the signal,
    /// or of the child process that changed state.
    ///
    /// The corresponding C field is `si_uid`.
    @_alwaysEmitIntoClient
    public var userID: UserID { UserID(rawValue: _userID) }

    @usableFromInline
    internal var _userID: CInterop.UserID {
      withUnsafePointer(to: rawValue) { csystem_siginfo_uid($0) }
    }

    /// For a child process that exited, its exit status;
    /// for one that a signal ended, stopped, or continued,
    /// the signal's number.
    ///
    /// The corresponding C field is `si_status`.
    @_alwaysEmitIntoClient
    public var status: CInt { _status }

    @usableFromInline
    internal var _status: CInt {
      withUnsafePointer(to: rawValue) { csystem_siginfo_status($0) }
    }

    /// For a signal that a memory access or an instruction caused,
    /// such as ``Signal/segmentationViolation``, the faulting address.
    ///
    /// The corresponding C field is `si_addr`.
    @_alwaysEmitIntoClient
    public var address: UnsafeRawPointer? { _address }

    @usableFromInline
    internal var _address: UnsafeRawPointer? {
      withUnsafePointer(to: rawValue) { UnsafeRawPointer(csystem_siginfo_addr($0)) }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
