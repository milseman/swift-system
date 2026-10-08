/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// FilePath.canonicalized() and remove() on Windows. FilePath+Resolution.swift
// declares them for the other platforms, over realpath and remove.

@available(System 199, *)
extension FilePath {
  /// Returns the canonical form of this path:
  /// absolute, with every symbolic link resolved,
  /// and without `.` or `..` components or repeated separators.
  ///
  /// - Returns: The canonical path of the file or directory
  ///   that this path names.
  ///
  /// Unlike ``lexicallyNormalized()``, which works on the path's text,
  /// this method looks up the file, so it must exist:
  /// if it doesn't, this method throws ``Errno/noSuchFileOrDirectory``.
  /// A relative path is resolved against the current working directory.
  ///
  /// On Windows, this opens the file or directory, with no access rights,
  /// and returns the path that Windows resolved: with symbolic links,
  /// directory junctions and volume mount points resolved, and each
  /// component spelled as the file system stores it, so its case can differ
  /// from this path's. Windows removes `.` and `..` components before it
  /// looks the path up, where POSIX resolves each component in turn, so
  /// `link\..` names the directory that holds `link`, not its target's
  /// parent, and the directory before a `..` needn't exist. A file on a
  /// network share gets a UNC path, such as `\\server\share\file`, even
  /// through a drive letter mapped to the share. The path has no `\\?\`
  /// prefix unless it's too long to work without one, as
  /// ``Win32/ExtendedLengthPrefix/whenNeeded`` describes. A file on a
  /// volume with no drive letter has no such path, so it throws
  /// ``Errno/noSuchFileOrDirectory`` too. Other Windows errors are reported
  /// as their approximations, as by ``Errno/init(approximating:)``.
  ///
  /// The corresponding C function is `GetFinalPathNameByHandleW`.
  @_alwaysEmitIntoClient
  public func canonicalized() throws(Errno) -> FilePath {
    try FilePath._canonicalized(self).get()
  }

  /// Returns the canonical form of the given path:
  /// absolute, with every symbolic link resolved,
  /// and without `.` or `..` components or repeated separators.
  ///
  /// - Parameter path: The path of a file or directory.
  /// - Returns: The canonical path of the file or directory
  ///   that `path` names.
  ///
  /// The file must exist:
  /// if it doesn't, this method throws ``Errno/noSuchFileOrDirectory``.
  /// A relative path is resolved against the current working directory.
  /// See ``canonicalized()`` for what Windows returns.
  ///
  /// The corresponding C function is `GetFinalPathNameByHandleW`.
  @_alwaysEmitIntoClient
  public static func canonicalized(
    _ path: UnsafePointer<CInterop.PlatformChar>
  ) throws(Errno) -> FilePath {
    try _canonicalized(FilePath(platformString: path)).get()
  }

  @usableFromInline
  internal static func _canonicalized(_ path: FilePath) -> Result<FilePath, Errno> {
    // No access rights, so a file the caller can't read resolves too, and
    // backup semantics, so a directory opens.
    let handle: HANDLE
    switch Win32._createFile(
      path,
      access: 0,
      shareMode: Win32.ShareMode([.read, .write, .delete]).rawValue,
      disposition: Win32.CreationDisposition.openExisting.rawValue,
      flagsAndAttributes: Win32.FileFlags.backupSemantics.rawValue,
      inheritable: false,
      securityDescriptor: nil,
      templateFile: nil
    ) {
    case .success(let opened): handle = opened.handle
    case .failure(let error): return .failure(Errno(approximating: error))
    }
    defer { _ = system_CloseHandle(handle) }
    switch Win32._finalPath(handle, flags: Win32._finalPathFlags(.dos, normalized: true)) {
    case .success(let resolved):
      return .success(Win32._removingUnneededExtendedLengthPrefix(resolved))
    case .failure(let error):
      return .failure(Errno(approximating: error))
    }
  }
}

// MARK: - remove

@available(System 199, *)
extension FilePath {
  /// Removes the file or empty directory at this path.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method removes a directory, which must be empty,
  /// and anything else, including a symbolic link.
  ///
  /// On Windows, the C runtime's `_wremove` removes only files,
  /// so a directory, which it can't remove, is removed with `_wrmdir`,
  /// which removes a directory symbolic link or a junction itself,
  /// not its target.
  /// A read-only file, and a file that's open without sharing deletion,
  /// can't be removed: this method throws ``Errno/permissionDenied``.
  ///
  /// The corresponding C function is `remove`, or on Windows `_wremove`,
  /// with `_wrmdir` for a directory.
  @_alwaysEmitIntoClient
  public func remove(retryOnInterrupt: Bool = true) throws(Errno) {
    try withPlatformString {
      FilePath._remove($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes the file or empty directory at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file or directory to remove.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// See ``remove(retryOnInterrupt:)`` for what Windows removes.
  ///
  /// The corresponding C function is `remove`, or on Windows `_wremove`,
  /// with `_wrmdir` for a directory.
  @_alwaysEmitIntoClient
  public static func remove(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _remove(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _remove(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    let removed = nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system__wremove(path)
    }
    // _wremove is DeleteFileW, which a directory fails with EACCES. glibc's
    // remove tries unlink first in the same way.
    guard case .failure(let error) = removed, error == .permissionDenied else { return removed }
    let attributes = system_GetFileAttributesW(path)
    guard attributes != INVALID_FILE_ATTRIBUTES, attributes & Win32.FileAttributes.directory.rawValue != 0 else {
      return removed
    }
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system__wrmdir(path)
    }
  }
}

#endif // os(Windows)
