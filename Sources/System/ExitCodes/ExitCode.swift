/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

@available(System 199, *)
extension ProcessID {
  /// The status a process exits with.
  ///
  /// A process passes its exit code to ``ProcessID/exit(_:)-(ExitCode)``
  /// or ``ProcessID/exitImmediately(_:)-(ExitCode)``,
  /// and the process that waits for it reads it from
  /// ``ExitStatus/exited(_:)``, as the low 8 bits of the code.
  /// By convention, ``success`` is 0 and every other code is a failure.
  ///
  /// Besides the C standard's ``success`` and ``failure``,
  /// the codes from 64 through 78 are the ones `<sysexits.h>` defines,
  /// which BSD programs and mail systems use to say why they failed,
  /// such as ``usageError`` for a command used incorrectly.
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
    /// The corresponding C constant is `EXIT_SUCCESS`,
    /// which `<sysexits.h>` also names `EX_OK`.
    @_alwaysEmitIntoClient
    public static var success: Self { Self(rawValue: _EXIT_SUCCESS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "success")
    public static var EXIT_SUCCESS: Self { success }

    #if !os(WASI)
    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "success")
    public static var EX_OK: Self { success }
    #endif

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

#if !os(WASI)
@available(System 199, *)
extension ProcessID.ExitCode {
  /// The command was used incorrectly:
  /// with the wrong number of arguments, an unknown option,
  /// or an argument it can't parse.
  ///
  /// The corresponding C constant is `EX_USAGE`.
  @_alwaysEmitIntoClient
  public static var usageError: Self { Self(rawValue: _EX_USAGE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "usageError")
  public static var EX_USAGE: Self { usageError }

  /// The input data was incorrect in some way:
  /// user data, not a system file.
  ///
  /// The corresponding C constant is `EX_DATAERR`.
  @_alwaysEmitIntoClient
  public static var dataError: Self { Self(rawValue: _EX_DATAERR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "dataError")
  public static var EX_DATAERR: Self { dataError }

  /// An input file, not a system file,
  /// doesn't exist or can't be read.
  ///
  /// The corresponding C constant is `EX_NOINPUT`.
  @_alwaysEmitIntoClient
  public static var cannotOpenInput: Self { Self(rawValue: _EX_NOINPUT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "cannotOpenInput")
  public static var EX_NOINPUT: Self { cannotOpenInput }

  /// The user named doesn't exist.
  ///
  /// The corresponding C constant is `EX_NOUSER`.
  @_alwaysEmitIntoClient
  public static var unknownUser: Self { Self(rawValue: _EX_NOUSER) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "unknownUser")
  public static var EX_NOUSER: Self { unknownUser }

  /// The host named doesn't exist.
  ///
  /// The corresponding C constant is `EX_NOHOST`.
  @_alwaysEmitIntoClient
  public static var unknownHost: Self { Self(rawValue: _EX_NOHOST) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "unknownHost")
  public static var EX_NOHOST: Self { unknownHost }

  /// A service the command needs is unavailable,
  /// or the command failed for a reason no other code describes.
  ///
  /// The corresponding C constant is `EX_UNAVAILABLE`.
  @_alwaysEmitIntoClient
  public static var serviceUnavailable: Self { Self(rawValue: _EX_UNAVAILABLE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "serviceUnavailable")
  public static var EX_UNAVAILABLE: Self { serviceUnavailable }

  /// The command found an error in itself,
  /// such as a condition it assumed couldn't happen.
  ///
  /// The corresponding C constant is `EX_SOFTWARE`.
  @_alwaysEmitIntoClient
  public static var internalError: Self { Self(rawValue: _EX_SOFTWARE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "internalError")
  public static var EX_SOFTWARE: Self { internalError }

  /// The operating system failed the command,
  /// such as by refusing to create a process or a pipe.
  ///
  /// The corresponding C constant is `EX_OSERR`.
  @_alwaysEmitIntoClient
  public static var systemError: Self { Self(rawValue: _EX_OSERR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "systemError")
  public static var EX_OSERR: Self { systemError }

  /// A system file, such as `/etc/passwd`,
  /// doesn't exist, can't be opened, or has an error in it.
  ///
  /// The corresponding C constant is `EX_OSFILE`.
  @_alwaysEmitIntoClient
  public static var systemFileError: Self { Self(rawValue: _EX_OSFILE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "systemFileError")
  public static var EX_OSFILE: Self { systemFileError }

  /// An output file that the user named can't be created.
  ///
  /// The corresponding C constant is `EX_CANTCREAT`.
  @_alwaysEmitIntoClient
  public static var cannotCreateOutput: Self { Self(rawValue: _EX_CANTCREAT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "cannotCreateOutput")
  public static var EX_CANTCREAT: Self { cannotCreateOutput }

  /// An I/O operation on a file failed.
  ///
  /// The corresponding C constant is `EX_IOERR`.
  @_alwaysEmitIntoClient
  public static var ioError: Self { Self(rawValue: _EX_IOERR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "ioError")
  public static var EX_IOERR: Self { ioError }

  /// The command failed for a reason that may pass,
  /// such as a connection that couldn't be made,
  /// so the user can try again later.
  ///
  /// The corresponding C constant is `EX_TEMPFAIL`.
  @_alwaysEmitIntoClient
  public static var temporaryFailure: Self { Self(rawValue: _EX_TEMPFAIL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "temporaryFailure")
  public static var EX_TEMPFAIL: Self { temporaryFailure }

  /// A remote system replied in a way
  /// its protocol doesn't allow.
  ///
  /// The corresponding C constant is `EX_PROTOCOL`.
  @_alwaysEmitIntoClient
  public static var protocolError: Self { Self(rawValue: _EX_PROTOCOL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "protocolError")
  public static var EX_PROTOCOL: Self { protocolError }

  /// The user doesn't have permission for the operation.
  /// This isn't for a file's permissions,
  /// which ``cannotOpenInput`` and ``cannotCreateOutput`` describe.
  ///
  /// The corresponding C constant is `EX_NOPERM`.
  @_alwaysEmitIntoClient
  public static var permissionDenied: Self { Self(rawValue: _EX_NOPERM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "permissionDenied")
  public static var EX_NOPERM: Self { permissionDenied }

  /// Something is unconfigured or misconfigured.
  ///
  /// The corresponding C constant is `EX_CONFIG`.
  @_alwaysEmitIntoClient
  public static var configurationError: Self { Self(rawValue: _EX_CONFIG) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "configurationError")
  public static var EX_CONFIG: Self { configurationError }
}
#endif // !os(WASI)

@available(System 199, *)
extension ProcessID.ExitCode: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the exit code:
  /// its name, if it has one, and its number.
  @inline(never)
  public var description: String {
    let name: String?
    switch self {
    case .success: name = "success"
    case .failure: name = "failure"
    #if !os(WASI)
    case .usageError: name = "usageError"
    case .dataError: name = "dataError"
    case .cannotOpenInput: name = "cannotOpenInput"
    case .unknownUser: name = "unknownUser"
    case .unknownHost: name = "unknownHost"
    case .serviceUnavailable: name = "serviceUnavailable"
    case .internalError: name = "internalError"
    case .systemError: name = "systemError"
    case .systemFileError: name = "systemFileError"
    case .cannotCreateOutput: name = "cannotCreateOutput"
    case .ioError: name = "ioError"
    case .temporaryFailure: name = "temporaryFailure"
    case .protocolError: name = "protocolError"
    case .permissionDenied: name = "permissionDenied"
    case .configurationError: name = "configurationError"
    #endif
    default: name = nil
    }
    guard let name else { return "\(rawValue)" }
    return "\(name) (\(rawValue))"
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
  /// This method is ``exitImmediately(_:)-(CInt)`` with a code's raw value;
  /// see that method for when it's safe where ``exit(_:)-(ExitCode)`` isn't.
  ///
  /// The corresponding C function is `_exit`.
  @_alwaysEmitIntoClient
  public static func exitImmediately(_ code: ExitCode) -> Never {
    _exitImmediately(code.rawValue)
  }
}

#endif // !os(Windows)
