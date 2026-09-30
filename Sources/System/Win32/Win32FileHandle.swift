/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// A HANDLE is an unsafe pointer, which isn't Sendable. The handle types own
// theirs uniquely, and Windows allows a handle's use from any thread, so
// they conform with @unchecked.

@available(System 199, *)
extension Win32 {
  /// An open file, device, or pipe.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope and
  /// discards the error.
  ///
  /// A `FileHandle` is synchronous: opening one rejects
  /// `FILE_FLAG_OVERLAPPED`, because the synchronous I/O it provides isn't
  /// memory-safe on an overlapped handle.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct FileHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw handle, taking ownership of it.
    ///
    /// - Warning: Do not pass a socket, which must be closed with
    ///   `closesocket`, not `CloseHandle`, or an overlapped handle, on which
    ///   this type's synchronous I/O isn't memory-safe. This initializer
    ///   doesn't check for either.
    ///
    /// Returns `nil` if `raw` is `NULL` or `INVALID_HANDLE_VALUE`.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw, raw != INVALID_HANDLE_VALUE else { return nil }
      self._handle = raw
    }

    /// The raw C handle. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawHandle: HANDLE { _handle }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> HANDLE {
      let handle = _handle
      discard self
      return handle
    }

    /// Closes this handle.
    ///
    /// The handle is closed whether this method returns or throws: a failed
    /// `CloseHandle` leaves nothing safe to retry. The exception is a handle
    /// marked `HANDLE_FLAG_PROTECT_FROM_CLOSE`, which `CloseHandle` leaves
    /// open, so consuming one leaks it, as the flag intends.
    ///
    /// Closing doesn't wait for cached data to reach the device, and can't
    /// report a failure to write it. Call `flush()` first to see one.
    ///
    /// The corresponding C function is `CloseHandle`.
    @_alwaysEmitIntoClient
    public consuming func close() throws(Win32.Error) {
      let handle = _handle
      discard self
      try Win32._closeHandle(handle).get()
    }

    deinit {
      // A deinit can't throw, so an error from closing is dropped here.
      _ = system_CloseHandle(_handle)
    }
  }

  /// An open directory.
  ///
  /// Opening one applies `FILE_FLAG_BACKUP_SEMANTICS`. This type has no read
  /// or write surface, because `ReadFile` and `WriteFile` fail on a directory
  /// handle.
  ///
  /// Like ``Win32/FileHandle``, this type owns its handle, and `deinit`
  /// closes it and discards any error.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct DirectoryHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw directory handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL` or `INVALID_HANDLE_VALUE`. This
    /// initializer doesn't check that `raw` refers to a directory.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw, raw != INVALID_HANDLE_VALUE else { return nil }
      self._handle = raw
    }

    /// The raw C handle. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawHandle: HANDLE { _handle }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> HANDLE {
      let handle = _handle
      discard self
      return handle
    }

    /// Closes this handle.
    ///
    /// The handle is closed whether this method returns or throws.
    ///
    /// The corresponding C function is `CloseHandle`.
    @_alwaysEmitIntoClient
    public consuming func close() throws(Win32.Error) {
      let handle = _handle
      discard self
      try Win32._closeHandle(handle).get()
    }

    deinit {
      _ = system_CloseHandle(_handle)
    }
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _closeHandle(_ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_CloseHandle(handle) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
