//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// File system operations that take a path.
//
// Each operation is a `FilePath` method, as `FilePath.stat()` is. Each also
// has a static `FilePath` method of the same name that takes its paths as
// `UnsafePointer<CChar>`, for paths that are already C strings.
//
// The `*at` forms take a `relativeTo:` directory, placed right after the path
// it applies to.

#if !os(Windows)

// MARK: - Resolution Flags

@available(System 199, *)
extension FilePath {
  /// Options that control how a path operation resolves its path.
  ///
  /// These are the flags that the C `*at` functions,
  /// such as `fchmodat` and `unlinkat`, take in their `flag` parameter.
  /// Which flags an operation accepts varies by operation and platform;
  /// an operation typically throws ``Errno/invalidArgument``
  /// for a flag it doesn't accept.
  ///
  /// The `*at` flags that select a different operation
  /// aren't resolution flags, and have their own API instead:
  /// ``FilePath/removeDirectory(relativeTo:flags:retryOnInterrupt:)``
  /// passes `AT_REMOVEDIR`.
  @frozen
  public struct ResolutionFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: CInt

    /// Creates a strongly-typed `FilePath.ResolutionFlags` from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// If the path ends with a symbolic link, operate on the link itself.
    ///
    /// The corresponding C constant is `AT_SYMLINK_NOFOLLOW`.
    @_alwaysEmitIntoClient
    public static var symlinkNoFollow: ResolutionFlags {
      ResolutionFlags(rawValue: _AT_SYMLINK_NOFOLLOW)
    }

    /// If the path ends with a symbolic link, operate on the link's target.
    ///
    /// Only operations that don't follow a final symbolic link by default,
    /// such as creating a hard link, accept this flag.
    ///
    /// The corresponding C constant is `AT_SYMLINK_FOLLOW`.
    @_alwaysEmitIntoClient
    public static var symlinkFollow: ResolutionFlags {
      ResolutionFlags(rawValue: _AT_SYMLINK_FOLLOW)
    }

    #if SYSTEM_PACKAGE_DARWIN
    /// If the path ends with a symbolic link, operate on the link itself.
    /// If _any_ symbolic link is encountered during path resolution, return an error.
    ///
    /// The corresponding C constant is `AT_SYMLINK_NOFOLLOW_ANY`.
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var symlinkNoFollowAny: ResolutionFlags {
      ResolutionFlags(rawValue: _AT_SYMLINK_NOFOLLOW_ANY)
    }
    #endif

    #if canImport(Darwin, _version: 346) || os(FreeBSD)
    /// If the path does not reside in the hierarchy beneath the starting directory, return an error.
    ///
    /// The corresponding C constant is `AT_RESOLVE_BENEATH`.
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var resolveBeneath: ResolutionFlags {
      ResolutionFlags(rawValue: _AT_RESOLVE_BENEATH)
    }
    #endif
  }
}

// MARK: - mkdir

@available(System 199, *)
extension FilePath {
  /// Creates a directory at this path.
  ///
  /// - Parameters:
  ///   - permissions: The permissions for the new directory.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `mkdir`.
  @_alwaysEmitIntoClient
  public func makeDirectory(
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._makeDirectory(
        $0, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a directory at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the new directory.
  ///   - permissions: The permissions for the new directory.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `mkdir`.
  @_alwaysEmitIntoClient
  public static func makeDirectory(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeDirectory(
      path, permissions: permissions, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeDirectory(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_mkdir(path, permissions.rawValue)
    }
  }

  /// Creates a directory at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - permissions: The permissions for the new directory.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkdirat`.
  @_alwaysEmitIntoClient
  public func makeDirectory(
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._makeDirectory(
        $0, relativeTo: fd, permissions: permissions,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a directory at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the new directory.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - permissions: The permissions for the new directory.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkdirat`.
  @_alwaysEmitIntoClient
  public static func makeDirectory(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeDirectory(
      path, relativeTo: fd, permissions: permissions,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeDirectory(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_mkdirat(fd.rawValue, path, permissions.rawValue)
    }
  }
}

// MARK: - rmdir, unlink, unlinkat

@available(System 199, *)
extension FilePath {
  /// Removes the directory at this path.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The directory must be empty.
  ///
  /// The corresponding C function is `rmdir`.
  @_alwaysEmitIntoClient
  public func removeDirectory(retryOnInterrupt: Bool = true) throws(Errno) {
    try withPlatformString {
      FilePath._removeDirectory($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes the directory at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to remove.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The directory must be empty.
  ///
  /// The corresponding C function is `rmdir`.
  @_alwaysEmitIntoClient
  public static func removeDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _removeDirectory(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _removeDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_rmdir(path)
    }
  }

  /// Removes the directory at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - flags: Options that control how the path is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The directory must be empty.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `unlinkat`, with the `AT_REMOVEDIR` flag.
  @_alwaysEmitIntoClient
  public func removeDirectory(
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._unlink(
        $0, relativeTo: fd, flags: flags.rawValue | _AT_REMOVEDIR,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes the directory at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to remove.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - flags: Options that control how `path` is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The directory must be empty.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `unlinkat`, with the `AT_REMOVEDIR` flag.
  @_alwaysEmitIntoClient
  public static func removeDirectory(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _unlink(
      path, relativeTo: fd, flags: flags.rawValue | _AT_REMOVEDIR,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Removes the directory entry at this path.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the entry is the file's last link, and no process has the file open,
  /// the file is deleted.
  /// If this path names a symbolic link, the link itself is removed.
  /// To remove a directory, call ``removeDirectory(retryOnInterrupt:)`` instead.
  ///
  /// The corresponding C function is `unlink`.
  @_alwaysEmitIntoClient
  public func unlink(retryOnInterrupt: Bool = true) throws(Errno) {
    try withPlatformString {
      FilePath._unlink($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes the directory entry at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the directory entry to remove.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the entry is the file's last link, and no process has the file open,
  /// the file is deleted.
  /// If `path` names a symbolic link, the link itself is removed.
  /// To remove a directory, call ``removeDirectory(_:retryOnInterrupt:)`` instead.
  ///
  /// The corresponding C function is `unlink`.
  @_alwaysEmitIntoClient
  public static func unlink(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _unlink(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _unlink(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_unlink(path)
    }
  }

  /// Removes the directory entry at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - flags: Options that control how the path is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the entry is the file's last link, and no process has the file open,
  /// the file is deleted.
  /// If this path names a symbolic link, the link itself is removed.
  /// To remove a directory,
  /// call ``removeDirectory(relativeTo:flags:retryOnInterrupt:)`` instead.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `unlinkat`.
  @_alwaysEmitIntoClient
  public func unlink(
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._unlink(
        $0, relativeTo: fd, flags: flags.rawValue,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes the directory entry at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the directory entry to remove.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - flags: Options that control how `path` is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the entry is the file's last link, and no process has the file open,
  /// the file is deleted.
  /// If `path` names a symbolic link, the link itself is removed.
  /// To remove a directory,
  /// call ``removeDirectory(_:relativeTo:flags:retryOnInterrupt:)`` instead.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `unlinkat`.
  @_alwaysEmitIntoClient
  public static func unlink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _unlink(
      path, relativeTo: fd, flags: flags.rawValue,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _unlink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    flags: CInt,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_unlinkat(fd.rawValue, path, flags)
    }
  }
}

// MARK: - rename, renameat

@available(System 199, *)
extension FilePath {
  /// Renames the file at this path.
  ///
  /// - Parameters:
  ///   - newPath: The new location of the file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If a file already exists at `newPath`, it is replaced.
  /// Both paths must be on the same file system.
  ///
  /// The corresponding C function is `rename`.
  @_alwaysEmitIntoClient
  public func rename(
    to newPath: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { old in
      newPath.withPlatformString { new in
        FilePath._rename(old, to: new, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Renames the file at the given path.
  ///
  /// - Parameters:
  ///   - oldPath: The current location of the file.
  ///   - newPath: The new location of the file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If a file already exists at `newPath`, it is replaced.
  /// Both paths must be on the same file system.
  ///
  /// The corresponding C function is `rename`.
  @_alwaysEmitIntoClient
  public static func rename(
    _ oldPath: UnsafePointer<CChar>,
    to newPath: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _rename(oldPath, to: newPath, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _rename(
    _ oldPath: UnsafePointer<CChar>,
    to newPath: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_rename(oldPath, newPath)
    }
  }

  /// Renames the file at this path,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - fd: The directory against which this path is resolved, if relative.
  ///   - newPath: The new location of the file.
  ///   - newFD: The directory against which `newPath` is resolved, if relative.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If a file already exists at `newPath`, it is replaced.
  /// Both paths must be on the same file system.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `renameat`.
  @_alwaysEmitIntoClient
  public func rename(
    relativeTo fd: FileDescriptor,
    to newPath: FilePath,
    relativeTo newFD: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { old in
      newPath.withPlatformString { new in
        FilePath._rename(
          old, relativeTo: fd, to: new, relativeTo: newFD,
          retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Renames the file at the given path,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - oldPath: The current location of the file.
  ///   - fd: The directory against which `oldPath` is resolved, if relative.
  ///   - newPath: The new location of the file.
  ///   - newFD: The directory against which `newPath` is resolved, if relative.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If a file already exists at `newPath`, it is replaced.
  /// Both paths must be on the same file system.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `renameat`.
  @_alwaysEmitIntoClient
  public static func rename(
    _ oldPath: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to newPath: UnsafePointer<CChar>,
    relativeTo newFD: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _rename(
      oldPath, relativeTo: fd, to: newPath, relativeTo: newFD,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _rename(
    _ oldPath: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to newPath: UnsafePointer<CChar>,
    relativeTo newFD: FileDescriptor,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_renameat(fd.rawValue, oldPath, newFD.rawValue, newPath)
    }
  }
}

// MARK: - link, linkat

@available(System 199, *)
extension FilePath {
  /// Creates a hard link at this path to an existing file.
  ///
  /// - Parameters:
  ///   - existingPath: The file to link to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The new link and the existing file must be on the same file system,
  /// and the existing file must not be a directory.
  /// If `existingPath` names a symbolic link,
  /// Darwin links to the symbolic link's target
  /// and Linux links to the symbolic link itself.
  /// To choose, call
  /// ``makeHardLink(relativeTo:to:relativeTo:flags:retryOnInterrupt:)``
  /// with or without ``ResolutionFlags/symlinkFollow``.
  ///
  /// The corresponding C function is `link`.
  @_alwaysEmitIntoClient
  public func makeHardLink(
    to existingPath: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { new in
      existingPath.withPlatformString { existing in
        FilePath._makeHardLink(new, to: existing, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Creates a hard link at the given path to an existing file.
  ///
  /// - Parameters:
  ///   - path: The location of the new link.
  ///   - existingPath: The file to link to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The new link and the existing file must be on the same file system,
  /// and the existing file must not be a directory.
  /// If `existingPath` names a symbolic link,
  /// Darwin links to the symbolic link's target
  /// and Linux links to the symbolic link itself.
  /// To choose, call
  /// ``makeHardLink(_:relativeTo:to:relativeTo:flags:retryOnInterrupt:)``
  /// with or without ``ResolutionFlags/symlinkFollow``.
  ///
  /// The corresponding C function is `link`.
  @_alwaysEmitIntoClient
  public static func makeHardLink(
    _ path: UnsafePointer<CChar>,
    to existingPath: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeHardLink(path, to: existingPath, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _makeHardLink(
    _ path: UnsafePointer<CChar>,
    to existingPath: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_link(existingPath, path)
    }
  }

  /// Creates a hard link at this path to an existing file,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - fd: The directory against which this path is resolved, if relative.
  ///   - existingPath: The file to link to.
  ///   - existingFD: The directory against which `existingPath` is resolved,
  ///     if relative.
  ///   - flags: Options that control how `existingPath` is resolved.
  ///     Pass ``ResolutionFlags/symlinkFollow`` to link to the target
  ///     of a symbolic link at `existingPath`, rather than to the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The new link and the existing file must be on the same file system,
  /// and the existing file must not be a directory.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `linkat`.
  @_alwaysEmitIntoClient
  public func makeHardLink(
    relativeTo fd: FileDescriptor,
    to existingPath: FilePath,
    relativeTo existingFD: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { new in
      existingPath.withPlatformString { existing in
        FilePath._makeHardLink(
          new, relativeTo: fd, to: existing, relativeTo: existingFD,
          flags: flags, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Creates a hard link at the given path to an existing file,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - path: The location of the new link.
  ///   - fd: The directory against which `path` is resolved, if relative.
  ///   - existingPath: The file to link to.
  ///   - existingFD: The directory against which `existingPath` is resolved,
  ///     if relative.
  ///   - flags: Options that control how `existingPath` is resolved.
  ///     Pass ``ResolutionFlags/symlinkFollow`` to link to the target
  ///     of a symbolic link at `existingPath`, rather than to the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The new link and the existing file must be on the same file system,
  /// and the existing file must not be a directory.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `linkat`.
  @_alwaysEmitIntoClient
  public static func makeHardLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to existingPath: UnsafePointer<CChar>,
    relativeTo existingFD: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeHardLink(
      path, relativeTo: fd, to: existingPath, relativeTo: existingFD,
      flags: flags, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeHardLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to existingPath: UnsafePointer<CChar>,
    relativeTo existingFD: FileDescriptor,
    flags: FilePath.ResolutionFlags,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_linkat(
        existingFD.rawValue, existingPath, fd.rawValue, path, flags.rawValue)
    }
  }
}

// MARK: - symlink, symlinkat

@available(System 199, *)
extension FilePath {
  /// Creates a symbolic link at this path that points to the given target.
  ///
  /// - Parameters:
  ///   - target: The path the new link points to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The link stores `target` as is. The target doesn't need to exist.
  /// A relative target is resolved when the link is followed,
  /// relative to the directory that contains the link.
  ///
  /// The corresponding C function is `symlink`.
  @_alwaysEmitIntoClient
  public func makeSymbolicLink(
    to target: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { path in
      target.withPlatformString { target in
        FilePath._makeSymbolicLink(path, to: target, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Creates a symbolic link at the given path that points to the given target.
  ///
  /// - Parameters:
  ///   - path: The location of the new link.
  ///   - target: The path the new link points to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The link stores `target` as is. The target doesn't need to exist.
  /// A relative target is resolved when the link is followed,
  /// relative to the directory that contains the link.
  ///
  /// The corresponding C function is `symlink`.
  @_alwaysEmitIntoClient
  public static func makeSymbolicLink(
    _ path: UnsafePointer<CChar>,
    to target: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeSymbolicLink(path, to: target, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _makeSymbolicLink(
    _ path: UnsafePointer<CChar>,
    to target: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_symlink(target, path)
    }
  }

  /// Creates a symbolic link at this path that points to the given target,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which this path is resolved, if relative.
  ///   - target: The path the new link points to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The link stores `target` as is; `fd` doesn't apply to it.
  /// The target doesn't need to exist.
  /// A relative target is resolved when the link is followed,
  /// relative to the directory that contains the link.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `symlinkat`.
  @_alwaysEmitIntoClient
  public func makeSymbolicLink(
    relativeTo fd: FileDescriptor,
    to target: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { path in
      target.withPlatformString { target in
        FilePath._makeSymbolicLink(
          path, relativeTo: fd, to: target, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Creates a symbolic link at the given path that points to the given target,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the new link.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - target: The path the new link points to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The link stores `target` as is; `fd` doesn't apply to it.
  /// The target doesn't need to exist.
  /// A relative target is resolved when the link is followed,
  /// relative to the directory that contains the link.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `symlinkat`.
  @_alwaysEmitIntoClient
  public static func makeSymbolicLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to target: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeSymbolicLink(
      path, relativeTo: fd, to: target, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeSymbolicLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to target: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_symlinkat(target, fd.rawValue, path)
    }
  }
}

// MARK: - readlink, readlinkat

@available(System 199, *)
extension FilePath {
  /// Returns the target of the symbolic link at this path.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The path stored in the link, which may be relative.
  ///
  /// If this path doesn't name a symbolic link,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `readlink`.
  @_alwaysEmitIntoClient
  public func readSymbolicLink(
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FilePath {
    try withPlatformString {
      FilePath._readSymbolicLink(
        $0, relativeTo: nil, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns the target of the symbolic link at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the symbolic link.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The path stored in the link, which may be relative.
  ///
  /// If `path` doesn't name a symbolic link,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `readlink`.
  @_alwaysEmitIntoClient
  public static func readSymbolicLink(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FilePath {
    try _readSymbolicLink(
      path, relativeTo: nil, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Returns the target of the symbolic link at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The path stored in the link, which may be relative.
  ///
  /// If this path doesn't name a symbolic link,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `readlinkat`.
  @_alwaysEmitIntoClient
  public func readSymbolicLink(
    relativeTo fd: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FilePath {
    try withPlatformString {
      FilePath._readSymbolicLink(
        $0, relativeTo: fd, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns the target of the symbolic link at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the symbolic link.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The path stored in the link, which may be relative.
  ///
  /// If `path` doesn't name a symbolic link,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `readlinkat`.
  @_alwaysEmitIntoClient
  public static func readSymbolicLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FilePath {
    try _readSymbolicLink(
      path, relativeTo: fd, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// The buffer capacity for the first attempt to read a symbolic link.
  internal static var _initialSymbolicLinkCapacity: Int { 256 }

  // Calls readlinkat if `fd` is non-nil, and readlink otherwise.
  @usableFromInline
  internal static func _readSymbolicLink(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor?,
    retryOnInterrupt: Bool
  ) -> Result<FilePath, Errno> {
    // The link's contents aren't null-terminated, and a buffer that's too
    // small silently truncates them. Grow the buffer until they fit
    // with room left over for the null terminator.
    var capacity = _initialSymbolicLinkCapacity
    while true {
      var result: Result<Int, Errno> = .success(0)
      let chars = SystemString.Storage(
        unsafeUninitializedCapacity: capacity
      ) { buffer, initializedCount in
        result = buffer.withMemoryRebound(to: CInterop.PlatformChar.self) { buffer in
          valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
            if let fd {
              system_readlinkat(fd.rawValue, path, buffer.baseAddress!, buffer.count)
            } else {
              system_readlink(path, buffer.baseAddress!, buffer.count)
            }
          }
        }
        guard case .success(let length) = result, length < capacity else {
          initializedCount = 0
          return
        }
        (buffer.baseAddress! + length).initialize(to: .null)
        initializedCount = length + 1
      }

      switch result {
      case .failure(let error):
        return .failure(error)
      case .success(let length) where length < capacity:
        return .success(FilePath(SystemString(nullTerminated: chars)))
      case .success:
        capacity *= 2
      }
    }
  }
}

#endif // !os(Windows)
