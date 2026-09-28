/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// MARK: - umask

@available(System 199, *)
extension FilePermissions {
  /// Sets the process's file creation mask, and returns the mask it replaces.
  ///
  /// - Parameter mask: The permissions that creating a file or a directory
  ///   should leave off, such as `[.groupWrite, .otherWrite]`.
  /// - Returns: The previous mask.
  ///
  /// Calls that create a file or a directory, such as
  /// ``FileDescriptor/open(_:_:options:permissions:retryOnInterrupt:)-(FilePath,_,_,_,_)``
  /// and ``FilePath/makeDirectory(permissions:retryOnInterrupt:)``,
  /// clear the mask's permissions from the ones they're given:
  /// with the common mask of `0o022`, a file created with `0o666`
  /// gets `0o644`.
  /// Changing a file's permissions afterward, as
  /// ``FileDescriptor/setPermissions(_:retryOnInterrupt:)`` does,
  /// doesn't apply the mask.
  ///
  /// - Important: The mask belongs to the whole process.
  ///   Changing it changes the permissions of files that other threads create,
  ///   and C has no call that only reads it:
  ///   reading it means setting it and setting it back,
  ///   which another thread can see in between.
  ///
  /// The corresponding C function is `umask`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func setCreationMask(_ mask: FilePermissions) -> FilePermissions {
    FilePermissions(rawValue: _setCreationMask(mask.rawValue))
  }

  @usableFromInline
  internal static func _setCreationMask(_ mask: CModeT) -> CModeT {
    // umask can't fail.
    _umask(mask)
  }
}

// MARK: - AT_FDCWD

@available(System 199, *)
extension FileDescriptor {
  /// A value that stands for the current working directory,
  /// for the calls that resolve a relative path against a directory.
  ///
  /// Pass it as the `relativeTo` argument of such a call
  /// to resolve a relative path as the call without it would:
  ///
  ///     let fd = try FileDescriptor.open(
  ///       "notes.txt", relativeTo: .currentWorkingDirectory, .readOnly)
  ///
  /// It isn't an open file descriptor.
  /// Other calls, such as ``read(into:retryOnInterrupt:)-(UnsafeMutableRawBufferPointer,_)``
  /// or ``close()``, fail with ``Errno/badFileDescriptor``.
  ///
  /// The corresponding C constant is `AT_FDCWD`.
  @_alwaysEmitIntoClient
  public static var currentWorkingDirectory: FileDescriptor {
    FileDescriptor(rawValue: _AT_FDCWD)
  }
}

#endif // !os(Windows) && !os(WASI)
