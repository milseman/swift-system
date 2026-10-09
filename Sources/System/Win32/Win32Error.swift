/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// A Windows system error code.
  ///
  /// This represents a value reported by `GetLastError`.
  ///
  /// The named codes aren't exhaustive. Windows defines several thousand, and
  /// drivers and file system filters can report more, so `rawValue` can hold
  /// any code, and an unnamed code round-trips unchanged.
  ///
  /// A `throws(Win32.Error)` function can throw ``success``: a Win32 function
  /// may fail while `GetLastError` reports `ERROR_SUCCESS`, and System reports
  /// what the system reported.
  @frozen
  public struct Error: RawRepresentable, Swift.Error, Sendable, Hashable, Codable {
    /// The raw C error code.
    @_alwaysEmitIntoClient
    public let rawValue: DWORD

    /// Creates a strongly-typed error from a raw C error code.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Creates a strongly-typed error from a raw C error code.
    @_alwaysEmitIntoClient
    public init(_ rawValue: DWORD) { self.rawValue = rawValue }
  }
}

// The codes are spelled as literals, not as the SDK's macros: their values
// are fixed ABI, and the literals don't depend on which Windows SDK builds
// System. Win32ErrorTests checks each one against the SDK.
@available(System 199, *)
extension Win32.Error {
  /// The operation completed successfully.
  ///
  /// A failing Win32 function can leave this code in place, so a
  /// `throws(Win32.Error)` function can throw it.
  ///
  /// The corresponding C constant is `ERROR_SUCCESS`, also known as
  /// `NO_ERROR`.
  @_alwaysEmitIntoClient
  public static var success: Win32.Error { Win32.Error(rawValue: 0) }

  /// Incorrect function.
  ///
  /// The device or file system doesn't support the operation, as when
  /// locking a byte range of a pipe or a console.
  ///
  /// The corresponding C constant is `ERROR_INVALID_FUNCTION`.
  @_alwaysEmitIntoClient
  public static var invalidFunction: Win32.Error { Win32.Error(rawValue: 1) }

  /// The system can't find the file specified.
  ///
  /// The corresponding C constant is `ERROR_FILE_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var fileNotFound: Win32.Error { Win32.Error(rawValue: 2) }

  /// The system can't find the path specified.
  ///
  /// A directory in the path doesn't exist.
  ///
  /// The corresponding C constant is `ERROR_PATH_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var pathNotFound: Win32.Error { Win32.Error(rawValue: 3) }

  /// Access is denied.
  ///
  /// The corresponding C constant is `ERROR_ACCESS_DENIED`.
  @_alwaysEmitIntoClient
  public static var accessDenied: Win32.Error { Win32.Error(rawValue: 5) }

  /// The handle is invalid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_HANDLE`.
  @_alwaysEmitIntoClient
  public static var invalidHandle: Win32.Error { Win32.Error(rawValue: 6) }

  /// There isn't enough memory to process the command.
  ///
  /// The corresponding C constant is `ERROR_NOT_ENOUGH_MEMORY`.
  @_alwaysEmitIntoClient
  public static var notEnoughMemory: Win32.Error { Win32.Error(rawValue: 8) }

  /// The system can't move the file to a different disk drive.
  ///
  /// A rename or a hard link crosses volumes.
  ///
  /// The corresponding C constant is `ERROR_NOT_SAME_DEVICE`.
  @_alwaysEmitIntoClient
  public static var notSameDevice: Win32.Error { Win32.Error(rawValue: 17) }

  /// The device isn't ready.
  ///
  /// The corresponding C constant is `ERROR_NOT_READY`.
  @_alwaysEmitIntoClient
  public static var deviceNotReady: Win32.Error { Win32.Error(rawValue: 21) }

  /// A cyclic redundancy check failed: a media error.
  ///
  /// The corresponding C constant is `ERROR_CRC`.
  @_alwaysEmitIntoClient
  public static var cyclicRedundancyCheck: Win32.Error { Win32.Error(rawValue: 23) }

  /// The system can't write to the specified device.
  ///
  /// The corresponding C constant is `ERROR_WRITE_FAULT`.
  @_alwaysEmitIntoClient
  public static var writeFault: Win32.Error { Win32.Error(rawValue: 29) }

  /// Another open of the file has an incompatible share mode.
  ///
  /// This is retryable: the open can succeed once the other handle closes.
  /// POSIX has no equivalent.
  ///
  /// The corresponding C constant is `ERROR_SHARING_VIOLATION`.
  @_alwaysEmitIntoClient
  public static var sharingViolation: Win32.Error { Win32.Error(rawValue: 32) }

  /// A byte-range lock blocked the access.
  ///
  /// The corresponding C constant is `ERROR_LOCK_VIOLATION`.
  @_alwaysEmitIntoClient
  public static var lockViolation: Win32.Error { Win32.Error(rawValue: 33) }

  /// The range is already unlocked.
  ///
  /// An unlock must name exactly a range that was locked.
  ///
  /// The corresponding C constant is `ERROR_NOT_LOCKED`.
  @_alwaysEmitIntoClient
  public static var notLocked: Win32.Error { Win32.Error(rawValue: 158) }

  /// An attempt was made to move the file pointer before the start of the
  /// file.
  ///
  /// The corresponding C constant is `ERROR_NEGATIVE_SEEK`.
  @_alwaysEmitIntoClient
  public static var negativeSeek: Win32.Error { Win32.Error(rawValue: 131) }

  /// The end of the file was reached.
  ///
  /// System's reads report the end of a file by returning zero bytes, so
  /// they never throw this code.
  ///
  /// The corresponding C constant is `ERROR_HANDLE_EOF`.
  @_alwaysEmitIntoClient
  public static var endOfFile: Win32.Error { Win32.Error(rawValue: 38) }

  /// The pipe has been ended.
  ///
  /// For a reader, the pipe's writer closed. A write to a pipe whose reader
  /// closed reports ``noData`` instead, unlike POSIX's `EPIPE`.
  ///
  /// The corresponding C constant is `ERROR_BROKEN_PIPE`.
  @_alwaysEmitIntoClient
  public static var brokenPipe: Win32.Error { Win32.Error(rawValue: 109) }

  /// The volume or device doesn't support the request.
  ///
  /// The corresponding C constant is `ERROR_NOT_SUPPORTED`.
  @_alwaysEmitIntoClient
  public static var notSupported: Win32.Error { Win32.Error(rawValue: 50) }

  /// The file exists.
  ///
  /// The corresponding C constant is `ERROR_FILE_EXISTS`.
  @_alwaysEmitIntoClient
  public static var fileExists: Win32.Error { Win32.Error(rawValue: 80) }

  /// The parameter is incorrect.
  ///
  /// The corresponding C constant is `ERROR_INVALID_PARAMETER`.
  @_alwaysEmitIntoClient
  public static var invalidParameter: Win32.Error { Win32.Error(rawValue: 87) }

  /// The buffer passed to a system call is too small.
  ///
  /// The corresponding C constant is `ERROR_INSUFFICIENT_BUFFER`.
  @_alwaysEmitIntoClient
  public static var insufficientBuffer: Win32.Error { Win32.Error(rawValue: 122) }

  /// The file name, directory name, or volume label syntax is incorrect.
  ///
  /// The corresponding C constant is `ERROR_INVALID_NAME`.
  @_alwaysEmitIntoClient
  public static var invalidName: Win32.Error { Win32.Error(rawValue: 123) }

  /// The specified module couldn't be found: a library to load, or one it
  /// depends on, isn't where the search looked, or isn't loaded.
  ///
  /// The corresponding C constant is `ERROR_MOD_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var moduleNotFound: Win32.Error { Win32.Error(rawValue: 126) }

  /// The specified procedure couldn't be found: a library doesn't export
  /// the symbol.
  ///
  /// The corresponding C constant is `ERROR_PROC_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var procedureNotFound: Win32.Error { Win32.Error(rawValue: 127) }

  /// The directory isn't empty.
  ///
  /// The corresponding C constant is `ERROR_DIR_NOT_EMPTY`.
  @_alwaysEmitIntoClient
  public static var directoryNotEmpty: Win32.Error { Win32.Error(rawValue: 145) }

  /// The specified path is invalid.
  ///
  /// The corresponding C constant is `ERROR_BAD_PATHNAME`.
  @_alwaysEmitIntoClient
  public static var badPathName: Win32.Error { Win32.Error(rawValue: 161) }

  /// The file can't be created because it already exists.
  ///
  /// The corresponding C constant is `ERROR_ALREADY_EXISTS`.
  @_alwaysEmitIntoClient
  public static var alreadyExists: Win32.Error { Win32.Error(rawValue: 183) }

  /// The size exceeds a file system limit.
  ///
  /// The corresponding C constant is `ERROR_FILE_TOO_LARGE`.
  @_alwaysEmitIntoClient
  public static var fileTooLarge: Win32.Error { Win32.Error(rawValue: 223) }

  /// There isn't enough space on the disk.
  ///
  /// The corresponding C constant is `ERROR_DISK_FULL`.
  @_alwaysEmitIntoClient
  public static var diskFull: Win32.Error { Win32.Error(rawValue: 112) }

  /// All instances of the named pipe are busy.
  ///
  /// The corresponding C constant is `ERROR_PIPE_BUSY`.
  @_alwaysEmitIntoClient
  public static var pipeBusy: Win32.Error { Win32.Error(rawValue: 231) }

  /// The pipe is being closed.
  ///
  /// This is what a write reports when the pipe's reader has closed, where
  /// POSIX reports `EPIPE`.
  ///
  /// The corresponding C constant is `ERROR_NO_DATA`.
  @_alwaysEmitIntoClient
  public static var noData: Win32.Error { Win32.Error(rawValue: 232) }

  /// No process is on the other end of the pipe.
  ///
  /// The corresponding C constant is `ERROR_PIPE_NOT_CONNECTED`.
  @_alwaysEmitIntoClient
  public static var pipeNotConnected: Win32.Error { Win32.Error(rawValue: 233) }

  /// More data is available.
  ///
  /// This is an instruction to retry with a larger buffer, not a failure.
  /// A message-mode pipe also reports it for a message larger than the read.
  ///
  /// The corresponding C constant is `ERROR_MORE_DATA`.
  @_alwaysEmitIntoClient
  public static var moreData: Win32.Error { Win32.Error(rawValue: 234) }

  /// The directory name is invalid: the path isn't a directory.
  ///
  /// The corresponding C constant is `ERROR_DIRECTORY`.
  @_alwaysEmitIntoClient
  public static var notADirectory: Win32.Error { Win32.Error(rawValue: 267) }

  /// The I/O operation was aborted by a thread exit or an application
  /// request, such as Ctrl+C during a console read.
  ///
  /// The corresponding C constant is `ERROR_OPERATION_ABORTED`.
  @_alwaysEmitIntoClient
  public static var operationAborted: Win32.Error { Win32.Error(rawValue: 995) }

  /// An overlapped I/O operation is in progress.
  ///
  /// The corresponding C constant is `ERROR_IO_PENDING`.
  @_alwaysEmitIntoClient
  public static var ioPending: Win32.Error { Win32.Error(rawValue: 997) }

  /// The operation can't be performed on a file with a mapped view.
  ///
  /// The corresponding C constant is `ERROR_USER_MAPPED_FILE`.
  @_alwaysEmitIntoClient
  public static var userMappedFile: Win32.Error { Win32.Error(rawValue: 1224) }

  /// The caller doesn't hold a privilege the operation needs, such as
  /// `SeCreateSymbolicLinkPrivilege`.
  ///
  /// The corresponding C constant is `ERROR_PRIVILEGE_NOT_HELD`.
  @_alwaysEmitIntoClient
  public static var privilegeNotHeld: Win32.Error { Win32.Error(rawValue: 1314) }

  /// No mapping between account names and security identifiers was done:
  /// no account has the name or the identifier, or the name isn't
  /// available in the format asked for.
  ///
  /// The corresponding C constant is `ERROR_NONE_MAPPED`.
  @_alwaysEmitIntoClient
  public static var noneMapped: Win32.Error { Win32.Error(rawValue: 1332) }

  /// The security identifier isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_SID`.
  @_alwaysEmitIntoClient
  public static var invalidSecurityIdentifier: Win32.Error { Win32.Error(rawValue: 1337) }

  /// The domain doesn't exist, or its domain controller can't be reached.
  ///
  /// The corresponding C constant is `ERROR_NO_SUCH_DOMAIN`.
  @_alwaysEmitIntoClient
  public static var noSuchDomain: Win32.Error { Win32.Error(rawValue: 1355) }

  /// The system can't resolve the name of the file.
  ///
  /// The corresponding C constant is `ERROR_CANT_RESOLVE_FILENAME`.
  @_alwaysEmitIntoClient
  public static var cannotResolveFileName: Win32.Error { Win32.Error(rawValue: 1921) }

  /// The file or directory isn't a reparse point.
  ///
  /// The corresponding C constant is `ERROR_NOT_A_REPARSE_POINT`.
  @_alwaysEmitIntoClient
  public static var notAReparsePoint: Win32.Error { Win32.Error(rawValue: 4390) }

  /// The reparse point's data isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_REPARSE_DATA`.
  @_alwaysEmitIntoClient
  public static var invalidReparseData: Win32.Error { Win32.Error(rawValue: 4392) }

  /// A transfer succeeded without moving all of its bytes.
  ///
  /// System synthesizes this code, and Windows never reports it. A write
  /// that succeeds without writing anything, or an append that writes only
  /// part of its span, throws it rather than retrying forever or dropping
  /// the rest.
  ///
  /// The code sets bit 29, which Windows reserves for application-defined
  /// codes (`APPLICATION_ERROR_MASK`), and bit 31, so `HRESULT_FROM_WIN32`
  /// leaves it unchanged.
  @_alwaysEmitIntoClient
  public static var incompleteTransfer: Win32.Error { Win32.Error(rawValue: 0xA053_5901) }

  /// Whether System synthesized this error instead of Windows reporting it.
  ///
  /// System's codes share the base `0xA0535900`, with their own number in the
  /// low byte.
  @_alwaysEmitIntoClient
  public var isSynthesized: Bool { rawValue & 0xFFFF_FF00 == 0xA053_5900 }
}

// More codes that Windows' file, network, thread and wait functions report,
// in their numeric order, which adopters test for or map onto errno values.
@available(System 199, *)
extension Win32.Error {
  /// The storage control block address isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_BLOCK`.
  @_alwaysEmitIntoClient
  public static var invalidBlock: Win32.Error { Win32.Error(rawValue: 9) }

  /// The access code isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_ACCESS`.
  @_alwaysEmitIntoClient
  public static var invalidAccess: Win32.Error { Win32.Error(rawValue: 12) }

  /// The data isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_DATA`.
  @_alwaysEmitIntoClient
  public static var invalidData: Win32.Error { Win32.Error(rawValue: 13) }

  /// The system can't find the drive specified.
  ///
  /// The corresponding C constant is `ERROR_INVALID_DRIVE`.
  @_alwaysEmitIntoClient
  public static var invalidDrive: Win32.Error { Win32.Error(rawValue: 15) }

  /// The directory can't be removed, as when it's the current directory.
  ///
  /// The corresponding C constant is `ERROR_CURRENT_DIRECTORY`.
  @_alwaysEmitIntoClient
  public static var currentDirectory: Win32.Error { Win32.Error(rawValue: 16) }

  /// There are no more files: a directory enumeration has reached its end.
  ///
  /// `FindNextFileW` reports the end of a directory this way.
  ///
  /// The corresponding C constant is `ERROR_NO_MORE_FILES`.
  @_alwaysEmitIntoClient
  public static var noMoreFiles: Win32.Error { Win32.Error(rawValue: 18) }

  /// The media is write protected.
  ///
  /// The corresponding C constant is `ERROR_WRITE_PROTECT`.
  @_alwaysEmitIntoClient
  public static var writeProtected: Win32.Error { Win32.Error(rawValue: 19) }

  /// The network path wasn't found.
  ///
  /// The corresponding C constant is `ERROR_BAD_NETPATH`.
  @_alwaysEmitIntoClient
  public static var badNetworkPath: Win32.Error { Win32.Error(rawValue: 53) }

  /// Network access is denied.
  ///
  /// The corresponding C constant is `ERROR_NETWORK_ACCESS_DENIED`.
  @_alwaysEmitIntoClient
  public static var networkAccessDenied: Win32.Error { Win32.Error(rawValue: 65) }

  /// The network name can't be found.
  ///
  /// The corresponding C constant is `ERROR_BAD_NET_NAME`.
  @_alwaysEmitIntoClient
  public static var badNetworkName: Win32.Error { Win32.Error(rawValue: 67) }

  /// The directory or file can't be created.
  ///
  /// The corresponding C constant is `ERROR_CANNOT_MAKE`.
  @_alwaysEmitIntoClient
  public static var cannotCreate: Win32.Error { Win32.Error(rawValue: 82) }

  /// The operation failed in the critical-error handler, interrupt 24h,
  /// as for a device that's not ready.
  ///
  /// The corresponding C constant is `ERROR_FAIL_I24`.
  @_alwaysEmitIntoClient
  public static var failOnInterrupt24: Win32.Error { Win32.Error(rawValue: 83) }

  /// Another process has the disk in use or locked.
  ///
  /// The corresponding C constant is `ERROR_DRIVE_LOCKED`.
  @_alwaysEmitIntoClient
  public static var driveLocked: Win32.Error { Win32.Error(rawValue: 108) }

  /// A buffer is too small for the data.
  ///
  /// `GetAdaptersAddresses` reports a buffer too small for the adapters this
  /// way. The system's message for it says that a file name is too long.
  ///
  /// The corresponding C constant is `ERROR_BUFFER_OVERFLOW`.
  @_alwaysEmitIntoClient
  public static var bufferOverflow: Win32.Error { Win32.Error(rawValue: 111) }

  /// The target internal file identifier isn't valid.
  ///
  /// The corresponding C constant is `ERROR_INVALID_TARGET_HANDLE`.
  @_alwaysEmitIntoClient
  public static var invalidTargetHandle: Win32.Error { Win32.Error(rawValue: 114) }

  /// The file pointer can't be set on the specified device or file.
  ///
  /// The corresponding C constant is `ERROR_SEEK_ON_DEVICE`.
  @_alwaysEmitIntoClient
  public static var seekOnDevice: Win32.Error { Win32.Error(rawValue: 132) }

  /// The volume label is longer than the file system allows.
  ///
  /// The corresponding C constant is `ERROR_LABEL_TOO_LONG`.
  @_alwaysEmitIntoClient
  public static var labelTooLong: Win32.Error { Win32.Error(rawValue: 154) }

  /// One or more arguments aren't correct.
  ///
  /// The corresponding C constant is `ERROR_BAD_ARGUMENTS`.
  @_alwaysEmitIntoClient
  public static var badArguments: Win32.Error { Win32.Error(rawValue: 160) }

  /// The system can't create another thread.
  ///
  /// The corresponding C constant is `ERROR_MAX_THRDS_REACHED`.
  @_alwaysEmitIntoClient
  public static var maxThreadsReached: Win32.Error { Win32.Error(rawValue: 164) }

  /// A region of a file can't be locked.
  ///
  /// The corresponding C constant is `ERROR_LOCK_FAILED`.
  @_alwaysEmitIntoClient
  public static var lockFailed: Win32.Error { Win32.Error(rawValue: 167) }

  /// An executable's starting code segment isn't valid: the file isn't a
  /// program Windows can run.
  ///
  /// The corresponding C constant is `ERROR_INVALID_STARTING_CODESEG`.
  @_alwaysEmitIntoClient
  public static var invalidStartingCodeSegment: Win32.Error { Win32.Error(rawValue: 188) }

  /// The file name or extension is too long.
  ///
  /// The corresponding C constant is `ERROR_FILENAME_EXCED_RANGE`.
  @_alwaysEmitIntoClient
  public static var fileNameOrExtensionTooLong: Win32.Error { Win32.Error(rawValue: 206) }

  /// The disk's physical resources are exhausted.
  ///
  /// The corresponding C constant is `ERROR_DISK_RESOURCES_EXHAUSTED`.
  @_alwaysEmitIntoClient
  public static var diskResourcesExhausted: Win32.Error { Win32.Error(rawValue: 314) }

  /// A file system limitation keeps the operation from completing, as when
  /// a file has too many fragments to grow.
  ///
  /// The corresponding C constant is `ERROR_FILE_SYSTEM_LIMITATION`.
  @_alwaysEmitIntoClient
  public static var fileSystemLimitation: Win32.Error { Win32.Error(rawValue: 665) }

  /// An overlapped operation hasn't completed.
  ///
  /// `GetOverlappedResult` reports an operation still in progress this way
  /// when it isn't asked to wait.
  ///
  /// The corresponding C constant is `ERROR_IO_INCOMPLETE`.
  @_alwaysEmitIntoClient
  public static var ioIncomplete: Win32.Error { Win32.Error(rawValue: 996) }

  /// The element wasn't found.
  ///
  /// `CancelIoEx` reports that it found no operation to cancel this way.
  ///
  /// The corresponding C constant is `ERROR_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var notFound: Win32.Error { Win32.Error(rawValue: 1168) }

  /// The user canceled the operation, as by closing a dialog.
  ///
  /// The corresponding C constant is `ERROR_CANCELLED`.
  @_alwaysEmitIntoClient
  public static var canceledByUser: Win32.Error { Win32.Error(rawValue: 1223) }

  /// The timeout expired before the operation completed.
  ///
  /// `SleepConditionVariableSRW` reports a wait that timed out this way.
  ///
  /// The corresponding C constant is `ERROR_TIMEOUT`.
  @_alwaysEmitIntoClient
  public static var timeoutExpired: Win32.Error { Win32.Error(rawValue: 1460) }
}

@available(System 199, *)
extension Win32.Error {
  // PROTOTYPE: public access to the last error, which needs the same care
  // as Errno.current's access to errno. Whether to offer either is still
  // open; see Prototype/PosixMore.

  /// The calling thread's last error, which Win32 functions set when they
  /// fail.
  ///
  /// - Important: The value is reliable only when it's read immediately
  ///   after the Win32 call that set it, because Swift can run other code
  ///   between the call and the read: releasing a value can run
  ///   a deinitializer that calls `CloseHandle` or frees memory,
  ///   which can change the last error.
  ///   Read it in the statement after the call,
  ///   before using any other value.
  ///
  /// Most Win32 functions set the last error only when they fail, so its
  /// value means something only after a call that reported a failure. A
  /// function whose failure value is also a result, such as `GetFileType`,
  /// whose `FILE_TYPE_UNKNOWN` can mean either, needs the last error
  /// cleared first, which setting this property does:
  ///
  ///     Win32.Error.current = .success
  ///     let type = GetFileType(handle)
  ///     if type == FILE_TYPE_UNKNOWN && Win32.Error.current != .success {
  ///       throw Win32.Error.current
  ///     }
  ///
  /// Each thread has its own last error.
  ///
  /// The corresponding C functions are `GetLastError` and `SetLastError`.
  @_alwaysEmitIntoClient
  public static var current: Win32.Error {
    get { Win32.Error(rawValue: GetLastError()) }
    set { SetLastError(newValue.rawValue) }
  }
}

@available(System 199, *)
extension Win32.Error: CustomStringConvertible, CustomDebugStringConvertible {
  /// The system's message for this code.
  ///
  /// The message is localized to the thread's or the system's language, so
  /// it suits display and logging, not matching. Getting it allocates and
  /// frees a buffer, so avoid it in hot paths. A code with no system message
  /// is rendered as a number.
  ///
  /// The corresponding C function is `FormatMessageW`, with
  /// `FORMAT_MESSAGE_FROM_SYSTEM`, `FORMAT_MESSAGE_ALLOCATE_BUFFER` and
  /// `FORMAT_MESSAGE_IGNORE_INSERTS`.
  @inline(never)
  public var description: String {
    if let message = _synthesizedMessage { return message }
    return _systemMessage ?? "Unknown error \(_numericDescription)"
  }

  /// The symbolic constant with the decimal and hexadecimal value, such as
  /// `ERROR_SHARING_VIOLATION (32, 0x20)` or Winsock's
  /// `WSAEWOULDBLOCK (10035, 0x2733)`, or the value alone for a code with no
  /// name here.
  ///
  /// Unlike ``description``, this is independent of the locale, so it suits
  /// tests and structured logs.
  @inline(never)
  public var debugDescription: String {
    guard let name = _symbolicName else { return _numericDescription }
    return "\(name) (\(rawValue), \(_hexadecimal))"
  }
}

@available(System 199, *)
extension Win32.Error {
  internal var _hexadecimal: String {
    "0x" + String(rawValue, radix: 16, uppercase: true)
  }

  internal var _numericDescription: String {
    "\(rawValue) (\(_hexadecimal))"
  }

  internal var _systemMessage: String? {
    _win32Message(rawValue, flags: _FORMAT_MESSAGE_FROM_SYSTEM, source: nil)
  }

  // Codes System synthesizes have no system message.
  internal var _synthesizedMessage: String? {
    switch rawValue {
    case Win32.Error.incompleteTransfer.rawValue:
      return "The transfer ended before all of the data was transferred."
    default:
      return nil
    }
  }

  internal var _symbolicName: String? {
    switch rawValue {
    case 0: return "ERROR_SUCCESS"
    case 1: return "ERROR_INVALID_FUNCTION"
    case 2: return "ERROR_FILE_NOT_FOUND"
    case 3: return "ERROR_PATH_NOT_FOUND"
    case 5: return "ERROR_ACCESS_DENIED"
    case 6: return "ERROR_INVALID_HANDLE"
    case 8: return "ERROR_NOT_ENOUGH_MEMORY"
    case 9: return "ERROR_INVALID_BLOCK"
    case 12: return "ERROR_INVALID_ACCESS"
    case 13: return "ERROR_INVALID_DATA"
    case 15: return "ERROR_INVALID_DRIVE"
    case 16: return "ERROR_CURRENT_DIRECTORY"
    case 17: return "ERROR_NOT_SAME_DEVICE"
    case 18: return "ERROR_NO_MORE_FILES"
    case 19: return "ERROR_WRITE_PROTECT"
    case 21: return "ERROR_NOT_READY"
    case 23: return "ERROR_CRC"
    case 29: return "ERROR_WRITE_FAULT"
    case 32: return "ERROR_SHARING_VIOLATION"
    case 33: return "ERROR_LOCK_VIOLATION"
    case 38: return "ERROR_HANDLE_EOF"
    case 50: return "ERROR_NOT_SUPPORTED"
    case 53: return "ERROR_BAD_NETPATH"
    case 65: return "ERROR_NETWORK_ACCESS_DENIED"
    case 67: return "ERROR_BAD_NET_NAME"
    case 80: return "ERROR_FILE_EXISTS"
    case 82: return "ERROR_CANNOT_MAKE"
    case 83: return "ERROR_FAIL_I24"
    case 87: return "ERROR_INVALID_PARAMETER"
    case 108: return "ERROR_DRIVE_LOCKED"
    case 109: return "ERROR_BROKEN_PIPE"
    case 111: return "ERROR_BUFFER_OVERFLOW"
    case 112: return "ERROR_DISK_FULL"
    case 114: return "ERROR_INVALID_TARGET_HANDLE"
    case 122: return "ERROR_INSUFFICIENT_BUFFER"
    case 123: return "ERROR_INVALID_NAME"
    case 126: return "ERROR_MOD_NOT_FOUND"
    case 127: return "ERROR_PROC_NOT_FOUND"
    case 131: return "ERROR_NEGATIVE_SEEK"
    case 132: return "ERROR_SEEK_ON_DEVICE"
    case 145: return "ERROR_DIR_NOT_EMPTY"
    case 154: return "ERROR_LABEL_TOO_LONG"
    case 158: return "ERROR_NOT_LOCKED"
    case 160: return "ERROR_BAD_ARGUMENTS"
    case 161: return "ERROR_BAD_PATHNAME"
    case 164: return "ERROR_MAX_THRDS_REACHED"
    case 167: return "ERROR_LOCK_FAILED"
    case 183: return "ERROR_ALREADY_EXISTS"
    case 188: return "ERROR_INVALID_STARTING_CODESEG"
    case 206: return "ERROR_FILENAME_EXCED_RANGE"
    case 223: return "ERROR_FILE_TOO_LARGE"
    case 231: return "ERROR_PIPE_BUSY"
    case 232: return "ERROR_NO_DATA"
    case 233: return "ERROR_PIPE_NOT_CONNECTED"
    case 234: return "ERROR_MORE_DATA"
    case 267: return "ERROR_DIRECTORY"
    case 314: return "ERROR_DISK_RESOURCES_EXHAUSTED"
    case 665: return "ERROR_FILE_SYSTEM_LIMITATION"
    case 995: return "ERROR_OPERATION_ABORTED"
    case 996: return "ERROR_IO_INCOMPLETE"
    case 997: return "ERROR_IO_PENDING"
    case 1168: return "ERROR_NOT_FOUND"
    case 1223: return "ERROR_CANCELLED"
    case 1224: return "ERROR_USER_MAPPED_FILE"
    case 1314: return "ERROR_PRIVILEGE_NOT_HELD"
    case 1332: return "ERROR_NONE_MAPPED"
    case 1337: return "ERROR_INVALID_SID"
    case 1355: return "ERROR_NO_SUCH_DOMAIN"
    case 1460: return "ERROR_TIMEOUT"
    case 1921: return "ERROR_CANT_RESOLVE_FILENAME"
    case 4390: return "ERROR_NOT_A_REPARSE_POINT"
    case 4392: return "ERROR_INVALID_REPARSE_DATA"
    // Winsock's codes, which winerror.h defines too, and which SystemWinSocks
    // throws. Those that share a value with a code above (WSA_IO_PENDING is
    // ERROR_IO_PENDING) have that code's name.
    case 10004: return "WSAEINTR"
    case 10009: return "WSAEBADF"
    case 10013: return "WSAEACCES"
    case 10014: return "WSAEFAULT"
    case 10022: return "WSAEINVAL"
    case 10024: return "WSAEMFILE"
    case 10035: return "WSAEWOULDBLOCK"
    case 10036: return "WSAEINPROGRESS"
    case 10037: return "WSAEALREADY"
    case 10038: return "WSAENOTSOCK"
    case 10039: return "WSAEDESTADDRREQ"
    case 10040: return "WSAEMSGSIZE"
    case 10041: return "WSAEPROTOTYPE"
    case 10042: return "WSAENOPROTOOPT"
    case 10043: return "WSAEPROTONOSUPPORT"
    case 10044: return "WSAESOCKTNOSUPPORT"
    case 10045: return "WSAEOPNOTSUPP"
    case 10046: return "WSAEPFNOSUPPORT"
    case 10047: return "WSAEAFNOSUPPORT"
    case 10048: return "WSAEADDRINUSE"
    case 10049: return "WSAEADDRNOTAVAIL"
    case 10050: return "WSAENETDOWN"
    case 10051: return "WSAENETUNREACH"
    case 10052: return "WSAENETRESET"
    case 10053: return "WSAECONNABORTED"
    case 10054: return "WSAECONNRESET"
    case 10055: return "WSAENOBUFS"
    case 10056: return "WSAEISCONN"
    case 10057: return "WSAENOTCONN"
    case 10058: return "WSAESHUTDOWN"
    case 10059: return "WSAETOOMANYREFS"
    case 10060: return "WSAETIMEDOUT"
    case 10061: return "WSAECONNREFUSED"
    case 10062: return "WSAELOOP"
    case 10063: return "WSAENAMETOOLONG"
    case 10064: return "WSAEHOSTDOWN"
    case 10065: return "WSAEHOSTUNREACH"
    case 10066: return "WSAENOTEMPTY"
    case 10067: return "WSAEPROCLIM"
    case 10068: return "WSAEUSERS"
    case 10069: return "WSAEDQUOT"
    case 10070: return "WSAESTALE"
    case 10071: return "WSAEREMOTE"
    case 10091: return "WSASYSNOTREADY"
    case 10092: return "WSAVERNOTSUPPORTED"
    case 10093: return "WSANOTINITIALISED"
    case 10101: return "WSAEDISCON"
    case 10102: return "WSAENOMORE"
    case 10103: return "WSAECANCELLED"
    case 10104: return "WSAEINVALIDPROCTABLE"
    case 10105: return "WSAEINVALIDPROVIDER"
    case 10106: return "WSAEPROVIDERFAILEDINIT"
    case 10107: return "WSASYSCALLFAILURE"
    case 10108: return "WSASERVICE_NOT_FOUND"
    case 10109: return "WSATYPE_NOT_FOUND"
    case 10110: return "WSA_E_NO_MORE"
    case 10111: return "WSA_E_CANCELLED"
    case 10112: return "WSAEREFUSED"
    case 11001: return "WSAHOST_NOT_FOUND"
    case 11002: return "WSATRY_AGAIN"
    case 11003: return "WSANO_RECOVERY"
    case 11004: return "WSANO_DATA"
    // System's own code has no C name.
    case Win32.Error.incompleteTransfer.rawValue: return "incompleteTransfer"
    default: return nil
    }
  }
}

/// The message that `FormatMessageW` finds for a code, from the system's
/// message tables or a module's, or `nil` if it finds none.
internal func _win32Message(_ code: DWORD, flags: DWORD, source: HMODULE?) -> String? {
  // FORMAT_MESSAGE_ALLOCATE_BUFFER makes the buffer parameter a pointer to
  // the pointer that receives the allocation.
  var buffer: UnsafeMutablePointer<WCHAR>? = nil
  let length = withUnsafeMutablePointer(to: &buffer) { pointer in
    pointer.withMemoryRebound(
      to: WCHAR.self,
      capacity: MemoryLayout<UnsafeMutablePointer<WCHAR>?>.size / MemoryLayout<WCHAR>.size
    ) { buffer in
      system_FormatMessageW(
        _FORMAT_MESSAGE_ALLOCATE_BUFFER | _FORMAT_MESSAGE_IGNORE_INSERTS | flags,
        source.map { UnsafeRawPointer($0) }, code, 0, buffer, 0)
    }
  }
  guard length > 0, let buffer else { return nil }
  defer { _ = system_LocalFree(buffer) }
  var message = String(
    decoding: UnsafeBufferPointer(start: buffer, count: Int(length)), as: UTF16.self)
  // System messages end with "\r\n".
  while let last = message.last, last.isWhitespace { message.removeLast() }
  return message
}

@available(System 199, *)
extension Win32.Error {
  /// Matches a `Win32.Error` pattern against an untyped error, as `Errno`'s
  /// operator does.
  ///
  /// This operator is `@_disfavoredOverload`, as `Errno`'s is.
  /// Where both types name a code (`fileExists`, `fileTooLarge`,
  /// `notSupported`, `brokenPipe`, and `noData`), a pattern such as
  /// `catch .fileExists` is ambiguous with both operators favored. With only
  /// one disfavored, the pattern resolves to the other type's code and never
  /// matches. With both disfavored, a typed catch uses the standard library's
  /// `~=` for `Equatable` values, and matches. Spelling the type, as in
  /// `catch Win32.Error.fileExists`, matches in every case.
  @_alwaysEmitIntoClient
  @_disfavoredOverload
  public static func ~= (_ lhs: Win32.Error, _ rhs: Swift.Error) -> Bool {
    guard let value = rhs as? Win32.Error else { return false }
    return lhs == value
  }
}

@available(System 199, *)
extension Errno {
  /// The closest POSIX equivalent of a Windows system error.
  ///
  /// This mapping is lossy. It approximates the C runtime's `_dosmaperr`
  /// behavior, which folds Windows' several thousand system error codes onto
  /// sixteen `Errno` values. Unrecognized codes become
  /// ``Errno/invalidArgument``. Prefer handling ``Win32/Error`` directly.
  ///
  /// This is the mapping System's `FileDescriptor` operations on Windows use
  /// to report a Win32 failure as `errno`.
  @_alwaysEmitIntoClient
  public init(approximating error: Win32.Error) {
    self.init(rawValue: Errno._approximating(error.rawValue))
  }

  @usableFromInline
  internal static func _approximating(_ code: DWORD) -> CInt {
    _mapWindowsErrorToErrno(code)
  }
}

#endif // os(Windows)
