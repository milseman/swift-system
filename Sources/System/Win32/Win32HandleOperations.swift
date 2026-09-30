/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32.FileHandle {
  /// Duplicates this handle within the current process.
  ///
  /// The duplicate refers to the same file object, so it shares this
  /// handle's file pointer. For an independent one, use
  /// ``reopen(access:shareMode:flags:)``.
  ///
  /// - Parameters:
  ///   - access: The duplicate's access rights. `nil` requests the same
  ///     rights this handle has.
  ///   - inheritable: Whether child processes created with handle inheritance
  ///     enabled receive a copy of the duplicate.
  ///
  /// - Returns: A new owned handle. The caller must close it.
  ///
  /// The corresponding C function is `DuplicateHandle`.
  @_alwaysEmitIntoClient
  public borrowing func duplicate(
    access: Win32.AccessMask? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.FileHandle {
    let handle = try Win32._duplicateHandle(
      _handle, access: access?.rawValue, inheritable: inheritable
    ).get()
    return Win32.FileHandle(_owning: handle)
  }

  /// Re-opens this handle's file as a new file object, with its own file
  /// pointer, access rights, share mode, and flags.
  ///
  /// Unlike ``open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``,
  /// this doesn't resolve a path, so it reaches the same file even if that
  /// file was renamed or its path now names a different file. Unlike
  /// ``duplicate(access:inheritable:)``, the result doesn't share this
  /// handle's file pointer.
  ///
  /// Like any open, the request must be compatible with the share modes of
  /// the file's other open handles, including this one.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `flags` contains
  /// `FILE_FLAG_OVERLAPPED`.
  ///
  /// The corresponding C function is `ReOpenFile`.
  @_alwaysEmitIntoClient
  public borrowing func reopen(
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    flags: Win32.FileFlags = []
  ) throws(Win32.Error) -> Win32.FileHandle {
    let handle = try Win32._reopenFile(
      _handle, access: access.rawValue, shareMode: shareMode.rawValue,
      flags: flags.rawValue
    ).get()
    return Win32.FileHandle(_owning: handle)
  }

  /// Whether child processes created with handle inheritance enabled receive
  /// a copy of this handle.
  ///
  /// The corresponding C function is `GetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func isInheritable() throws(Win32.Error) -> Bool {
    try Win32._isInheritable(_handle).get()
  }

  /// Sets whether child processes created with handle inheritance enabled
  /// receive a copy of this handle.
  ///
  /// The corresponding C function is `SetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func setInheritable(_ value: Bool) throws(Win32.Error) {
    try Win32._setInheritable(_handle, value).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// Duplicates this handle within the current process.
  ///
  /// - Parameters:
  ///   - access: The duplicate's access rights. `nil` requests the same
  ///     rights this handle has.
  ///   - inheritable: Whether child processes created with handle inheritance
  ///     enabled receive a copy of the duplicate.
  ///
  /// - Returns: A new owned handle. The caller must close it.
  ///
  /// The corresponding C function is `DuplicateHandle`.
  @_alwaysEmitIntoClient
  public borrowing func duplicate(
    access: Win32.AccessMask? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.DirectoryHandle {
    let handle = try Win32._duplicateHandle(
      _handle, access: access?.rawValue, inheritable: inheritable
    ).get()
    return Win32.DirectoryHandle(_owning: handle)
  }

  /// Re-opens this handle's directory as a new file object, with its own
  /// access rights, share mode, and flags.
  ///
  /// `FILE_FLAG_BACKUP_SEMANTICS` is added to `flags` automatically. Throws
  /// ``Win32/Error/invalidParameter`` if `flags` contains
  /// `FILE_FLAG_OVERLAPPED`.
  ///
  /// The corresponding C function is `ReOpenFile`.
  @_alwaysEmitIntoClient
  public borrowing func reopen(
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    flags: Win32.FileFlags = []
  ) throws(Win32.Error) -> Win32.DirectoryHandle {
    let handle = try Win32._reopenFile(
      _handle, access: access.rawValue, shareMode: shareMode.rawValue,
      flags: flags.union(.backupSemantics).rawValue
    ).get()
    return Win32.DirectoryHandle(_owning: handle)
  }

  /// Whether child processes created with handle inheritance enabled receive
  /// a copy of this handle.
  ///
  /// The corresponding C function is `GetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func isInheritable() throws(Win32.Error) -> Bool {
    try Win32._isInheritable(_handle).get()
  }

  /// Sets whether child processes created with handle inheritance enabled
  /// receive a copy of this handle.
  ///
  /// The corresponding C function is `SetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func setInheritable(_ value: Bool) throws(Win32.Error) {
    try Win32._setInheritable(_handle, value).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _duplicateHandle(
    _ handle: HANDLE, access: DWORD?, inheritable: Bool
  ) -> Result<HANDLE, Win32.Error> {
    var duplicate: HANDLE? = nil
    let process = system_GetCurrentProcess()
    guard system_DuplicateHandle(
      process, handle, process, &duplicate, access ?? 0, inheritable,
      access == nil ? _DUPLICATE_SAME_ACCESS : 0
    ), let duplicate else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(duplicate)
  }

  @usableFromInline
  internal static func _reopenFile(
    _ handle: HANDLE, access: DWORD, shareMode: DWORD, flags: DWORD
  ) -> Result<HANDLE, Win32.Error> {
    guard flags & _FILE_FLAG_OVERLAPPED == 0 else {
      return .failure(.invalidParameter)
    }
    let reopened = system_ReOpenFile(handle, access, shareMode, flags)
    guard let reopened, reopened != INVALID_HANDLE_VALUE else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(reopened)
  }

  @usableFromInline
  internal static func _isInheritable(_ handle: HANDLE) -> Result<Bool, Win32.Error> {
    var flags: DWORD = 0
    guard system_GetHandleInformation(handle, &flags) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(flags & _HANDLE_FLAG_INHERIT != 0)
  }

  @usableFromInline
  internal static func _setInheritable(
    _ handle: HANDLE, _ value: Bool
  ) -> Result<Void, Win32.Error> {
    guard system_SetHandleInformation(
      handle, _HANDLE_FLAG_INHERIT, value ? _HANDLE_FLAG_INHERIT : 0
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
