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
  /// The corresponding C constant is `ERROR_SUCCESS`.
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

  /// The system can't resolve the name of the file.
  ///
  /// The corresponding C constant is `ERROR_CANT_RESOLVE_FILENAME`.
  @_alwaysEmitIntoClient
  public static var cannotResolveFileName: Win32.Error { Win32.Error(rawValue: 1921) }

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

@available(System 199, *)
extension Win32.Error: CustomStringConvertible, CustomDebugStringConvertible {
  /// The system's message for this code.
  ///
  /// The message is localized to the thread's or the system's language, so
  /// it suits display and logging, not matching. Getting it allocates and
  /// frees a buffer, so avoid it in hot paths. A code with no system message
  /// is rendered as a number.
  ///
  /// The corresponding C function is `FormatMessageW`.
  @inline(never)
  public var description: String {
    if let message = _synthesizedMessage { return message }
    return _systemMessage ?? "Unknown error \(_numericDescription)"
  }

  /// The symbolic constant with the decimal and hexadecimal value, such as
  /// `ERROR_SHARING_VIOLATION (32, 0x20)`, or the value alone for a code
  /// with no name here.
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
    // FORMAT_MESSAGE_ALLOCATE_BUFFER makes the buffer parameter a pointer to
    // the pointer that receives the allocation.
    var buffer: UnsafeMutablePointer<WCHAR>? = nil
    let length = withUnsafeMutablePointer(to: &buffer) { pointer in
      pointer.withMemoryRebound(
        to: WCHAR.self,
        capacity: MemoryLayout<UnsafeMutablePointer<WCHAR>?>.size / MemoryLayout<WCHAR>.size
      ) { buffer in
        system_FormatMessageW(
          _FORMAT_MESSAGE_ALLOCATE_BUFFER | _FORMAT_MESSAGE_FROM_SYSTEM
            | _FORMAT_MESSAGE_IGNORE_INSERTS,
          nil, rawValue, 0, buffer, 0)
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
    case 21: return "ERROR_NOT_READY"
    case 23: return "ERROR_CRC"
    case 29: return "ERROR_WRITE_FAULT"
    case 32: return "ERROR_SHARING_VIOLATION"
    case 33: return "ERROR_LOCK_VIOLATION"
    case 38: return "ERROR_HANDLE_EOF"
    case 50: return "ERROR_NOT_SUPPORTED"
    case 80: return "ERROR_FILE_EXISTS"
    case 87: return "ERROR_INVALID_PARAMETER"
    case 109: return "ERROR_BROKEN_PIPE"
    case 112: return "ERROR_DISK_FULL"
    case 122: return "ERROR_INSUFFICIENT_BUFFER"
    case 123: return "ERROR_INVALID_NAME"
    case 131: return "ERROR_NEGATIVE_SEEK"
    case 158: return "ERROR_NOT_LOCKED"
    case 161: return "ERROR_BAD_PATHNAME"
    case 183: return "ERROR_ALREADY_EXISTS"
    case 223: return "ERROR_FILE_TOO_LARGE"
    case 231: return "ERROR_PIPE_BUSY"
    case 232: return "ERROR_NO_DATA"
    case 233: return "ERROR_PIPE_NOT_CONNECTED"
    case 234: return "ERROR_MORE_DATA"
    case 267: return "ERROR_DIRECTORY"
    case 995: return "ERROR_OPERATION_ABORTED"
    case 997: return "ERROR_IO_PENDING"
    case 1224: return "ERROR_USER_MAPPED_FILE"
    case 1921: return "ERROR_CANT_RESOLVE_FILENAME"
    // System's own code has no C name.
    case Win32.Error.incompleteTransfer.rawValue: return "incompleteTransfer"
    default: return nil
    }
  }
}

@available(System 199, *)
extension Win32.Error {
  /// Matches a `Win32.Error` pattern against an untyped error, as `Errno`'s
  /// operator does.
  ///
  /// This operator is `@_disfavoredOverload`, and `Errno`'s must be too.
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
