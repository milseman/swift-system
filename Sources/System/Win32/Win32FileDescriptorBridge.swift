/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt
import WinSDK

@available(System 199, *)
extension FileDescriptor {
  /// Calls `body` with the Win32 handle backing this descriptor, if it maps to
  /// a usable handle.
  ///
  /// The handle is **borrowed** from the C runtime descriptor, which owns it
  /// and closes it when the descriptor is closed. The borrow is valid only for
  /// the duration of the call.
  ///
  /// `body` isn't called for an invalid descriptor, for a valid descriptor
  /// with no underlying handle (which the C runtime reports for the standard
  /// descriptors in a process with no console), or for a descriptor over an
  /// overlapped handle, such as a socket.
  ///
  /// The handle shares the descriptor's file pointer.
  ///
  /// - Parameter body: A closure that receives the handle backing this
  ///   descriptor.
  /// - Returns: The return value of `body`, or `nil` if it wasn't called.
  ///
  /// The corresponding C function is `_get_osfhandle`.
  @_alwaysEmitIntoClient
  public func withWin32HandleIfAvailable<R: ~Copyable, E: Error>(
    _ body: (borrowing Win32.FileHandle) throws(E) -> R
  ) throws(E) -> R? {
    guard let handle = _win32HandleIfAvailable() else { return nil }
    // The C runtime owns the handle, so the lent FileHandle is relinquished
    // on every path, and its deinit never closes it.
    let lent = Win32.FileHandle(_owning: handle)
    let result: R
    do throws(E) {
      result = try body(lent)
    } catch {
      _ = lent.relinquish()
      throw error
    }
    _ = lent.relinquish()
    return result
  }

  /// Wraps a Win32 handle in a C runtime file descriptor, **consuming**
  /// the handle.
  ///
  /// On success, the returned descriptor owns the handle, and closing the
  /// descriptor closes it. On failure, this initializer closes the handle
  /// before throwing.
  ///
  /// Throws ``Errno/invalidArgument`` for a handle whose `GetFileType` is
  /// `FILE_TYPE_UNKNOWN`, which the C runtime rejects.
  ///
  /// - Parameters:
  ///   - handle: The handle to wrap.
  ///   - translation: The descriptor's translation mode. Defaults to
  ///     `.binary`, which passes bytes through unchanged.
  ///   - append: Whether every write seeks to the end of the file first.
  ///
  /// - Note: The descriptor's access is that of the underlying handle.
  ///
  /// The corresponding C function is `_open_osfhandle`.
  @_alwaysEmitIntoClient
  public init(
    adopting handle: consuming Win32.FileHandle,
    translation: TranslationMode = .binary,
    append: Bool = false
  ) throws(Errno) {
    let raw = handle.relinquish()
    self.init(
      rawValue: try FileDescriptor._adopt(
        raw, translation: translation.rawValue, append: append
      ).get())
  }

  /// The C runtime's translation mode for a file descriptor.
  @frozen
  public struct TranslationMode: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C flag.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed translation mode from a raw C flag.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Bytes pass through unchanged.
    ///
    /// The corresponding C constant is `_O_BINARY`.
    @_alwaysEmitIntoClient
    public static var binary: TranslationMode { TranslationMode(rawValue: 0x8000) }

    /// Expands `\n` to `\r\n` on write and collapses it on read. A read also
    /// stops at a Ctrl+Z (`0x1A`) byte, which the C runtime treats as end of
    /// file.
    ///
    /// The corresponding C constant is `_O_TEXT`.
    @_alwaysEmitIntoClient
    public static var text: TranslationMode { TranslationMode(rawValue: 0x4000) }

    /// Translates in Unicode mode, reading and writing UTF-16.
    ///
    /// - Warning: Reading or writing an odd number of bytes in this mode is a
    ///   C runtime parameter validation error, which terminates the process
    ///   by default.
    ///
    /// The corresponding C constant is `_O_WTEXT`.
    @_alwaysEmitIntoClient
    public static var wideText: TranslationMode { TranslationMode(rawValue: 0x10000) }
  }
}

@available(System 199, *)
extension FileDescriptor {
  /// The synchronous handle behind this descriptor, or `nil`.
  @usableFromInline
  internal func _win32HandleIfAvailable() -> HANDLE? {
    // `_get_osfhandle` on an invalid descriptor calls the C runtime's
    // invalid parameter handler, which terminates the process by default.
    // With a handler that returns, it fails with EBADF instead.
    let previous = _set_thread_local_invalid_parameter_handler { _, _, _, _, _ in }
    let raw = system__get_osfhandle(rawValue)
    _ = _set_thread_local_invalid_parameter_handler(previous)
    // INVALID_HANDLE_VALUE, and the C runtime's _NO_CONSOLE_FILENO for a
    // standard descriptor with no console.
    guard raw != -1, raw != -2, let handle = HANDLE(bitPattern: raw) else {
      return nil
    }
    // The synchronous I/O on Win32.FileHandle isn't memory-safe on an
    // overlapped handle, such as a socket.
    guard Win32._isSynchronous(handle) else { return nil }
    return handle
  }

  /// Whether the descriptor is a pipe, a socket, or a character device such
  /// as a console: a file with no position, which POSIX's seeks reject with
  /// ESPIPE. `false` for a descriptor with no handle.
  internal func _hasNoPosition() -> Bool {
    let raw = _withReturningInvalidParameterHandler { system__get_osfhandle(rawValue) }
    guard raw != -1, raw != -2, let handle = HANDLE(bitPattern: raw) else { return false }
    let type = Win32.FileType(rawValue: system_GetFileType(handle))
    return type == .pipe || type == .character
  }

  @usableFromInline
  internal static func _adopt(
    _ handle: HANDLE, translation: CInt, append: Bool
  ) -> Result<CInt, Errno> {
    // `_open_osfhandle` fails for FILE_TYPE_UNKNOWN, leaving whatever errno
    // the last error maps to.
    guard system_GetFileType(handle) != _FILE_TYPE_UNKNOWN else {
      _ = system_CloseHandle(handle)
      return .failure(.invalidArgument)
    }
    // `_open_osfhandle` reads only _O_TEXT, _O_APPEND, and _O_NOINHERIT, so
    // it makes a binary descriptor for _O_WTEXT. The Unicode modes are set
    // afterward with `_setmode`.
    let setsMode = translation != _O_TEXT && translation != _O_BINARY
    var flags = setsMode ? _O_BINARY : translation
    if append { flags |= _O_APPEND }
    let descriptor = system__open_osfhandle(Int(bitPattern: handle), flags)
    guard descriptor != -1 else {
      let error = Errno.current
      _ = system_CloseHandle(handle)
      return .failure(error)
    }
    if setsMode {
      guard system__setmode(descriptor, translation) != -1 else {
        let error = Errno.current
        // The descriptor owns the handle now, so closing it closes both.
        _ = system_close(descriptor)
        return .failure(error)
      }
    }
    return .success(descriptor)
  }
}

@available(System 199, *)
extension Win32 {
  /// The signature of `NtQueryInformationFile`, which `ntdll.dll` exports.
  internal typealias _NtQueryInformationFile = @convention(c) (
    HANDLE?, UnsafeMutablePointer<IO_STATUS_BLOCK>?, UnsafeMutableRawPointer?,
    ULONG, FILE_INFORMATION_CLASS
  ) -> NTSTATUS

  /// Whether `handle` is a file object opened for synchronous I/O, that is,
  /// without `FILE_FLAG_OVERLAPPED`.
  ///
  /// Returns `false` if the query fails, as it does for a handle that isn't
  /// a file object.
  internal static func _isSynchronous(_ handle: HANDLE) -> Bool {
    // Win32 has no query for this, so it takes the NT API, which is looked
    // up at run time rather than linked. ntdll is loaded in every process.
    let ntdll = "ntdll.dll".withCString(encodedAs: UTF16.self) { name in
      system_GetModuleHandleW(name)
    }
    guard let ntdll,
      let query = unsafeBitCast(
        system_GetProcAddress(ntdll, "NtQueryInformationFile"),
        to: Optional<_NtQueryInformationFile>.self)
    else { return false }
    var status = IO_STATUS_BLOCK()
    // FILE_MODE_INFORMATION is a ULONG of the handle's mode flags. Its
    // information class, FileModeInformation (16), is declared only in the
    // driver kit's headers.
    var mode: ULONG = 0
    let result = query(
      handle, &status, &mode, ULONG(MemoryLayout<ULONG>.size),
      FILE_INFORMATION_CLASS(rawValue: 16))
    // NT_SUCCESS
    guard result >= 0 else { return false }
    return mode & (_FILE_SYNCHRONOUS_IO_ALERT | _FILE_SYNCHRONOUS_IO_NONALERT) != 0
  }
}

#endif // os(Windows)
