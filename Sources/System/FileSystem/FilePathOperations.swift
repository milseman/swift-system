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

// MARK: - renamex_np, renameatx_np, renameat2

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
@available(System 199, *)
extension FilePath {
  /// Options that change how a file is renamed.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
  @frozen
  public struct RenameOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: CUnsignedInt

    /// Creates a strongly-typed `FilePath.RenameOptions` from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }

    /// Throws ``Errno/fileExists`` if a file exists at the new path,
    /// rather than replacing it.
    ///
    /// The corresponding C constant is `RENAME_EXCL` on Darwin,
    /// and `RENAME_NOREPLACE` on Linux and Android.
    @_alwaysEmitIntoClient
    public static var exclusive: RenameOptions {
      #if SYSTEM_PACKAGE_DARWIN
      RenameOptions(rawValue: _RENAME_EXCL)
      #else
      RenameOptions(rawValue: _RENAME_NOREPLACE)
      #endif
    }

    /// Atomically exchanges the files at the two paths,
    /// which must both exist.
    ///
    /// The corresponding C constant is `RENAME_SWAP` on Darwin,
    /// and `RENAME_EXCHANGE` on Linux and Android.
    @_alwaysEmitIntoClient
    public static var swap: RenameOptions {
      #if SYSTEM_PACKAGE_DARWIN
      RenameOptions(rawValue: _RENAME_SWAP)
      #else
      RenameOptions(rawValue: _RENAME_EXCHANGE)
      #endif
    }
  }

  /// Renames the file at this path, with options.
  ///
  /// - Parameters:
  ///   - newPath: The new location of the file.
  ///   - options: Options that change how the file is renamed.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Both paths must be on the same file system.
  /// Not every file system supports every option;
  /// one that doesn't throws an error, such as ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `renamex_np` on Darwin,
  /// and `renameat2` on Linux and Android.
  /// - Note: Only available on Darwin, Linux, and Android.
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @_alwaysEmitIntoClient
  public func rename(
    to newPath: FilePath,
    options: RenameOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { old in
      newPath.withPlatformString { new in
        FilePath._rename(
          old, to: new, options: options, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Renames the file at the given path, with options.
  ///
  /// - Parameters:
  ///   - oldPath: The current location of the file.
  ///   - newPath: The new location of the file.
  ///   - options: Options that change how the file is renamed.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Both paths must be on the same file system.
  /// Not every file system supports every option;
  /// one that doesn't throws an error, such as ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `renamex_np` on Darwin,
  /// and `renameat2` on Linux and Android.
  /// - Note: Only available on Darwin, Linux, and Android.
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @_alwaysEmitIntoClient
  public static func rename(
    _ oldPath: UnsafePointer<CChar>,
    to newPath: UnsafePointer<CChar>,
    options: RenameOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _rename(
      oldPath, to: newPath, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @usableFromInline
  internal static func _rename(
    _ oldPath: UnsafePointer<CChar>,
    to newPath: UnsafePointer<CChar>,
    options: RenameOptions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      #if SYSTEM_PACKAGE_DARWIN
      system_renamex_np(oldPath, newPath, options.rawValue)
      #else
      system_renameat2(_AT_FDCWD, oldPath, _AT_FDCWD, newPath, options.rawValue)
      #endif
    }
  }

  /// Renames the file at this path, with options,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - fd: The directory against which this path is resolved, if relative.
  ///   - newPath: The new location of the file.
  ///   - newFD: The directory against which `newPath` is resolved, if relative.
  ///   - options: Options that change how the file is renamed.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Both paths must be on the same file system.
  /// Not every file system supports every option;
  /// one that doesn't throws an error, such as ``Errno/invalidArgument``.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `renameatx_np` on Darwin,
  /// and `renameat2` on Linux and Android.
  /// - Note: Only available on Darwin, Linux, and Android.
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @_alwaysEmitIntoClient
  public func rename(
    relativeTo fd: FileDescriptor,
    to newPath: FilePath,
    relativeTo newFD: FileDescriptor,
    options: RenameOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { old in
      newPath.withPlatformString { new in
        FilePath._rename(
          old, relativeTo: fd, to: new, relativeTo: newFD, options: options,
          retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Renames the file at the given path, with options,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - oldPath: The current location of the file.
  ///   - fd: The directory against which `oldPath` is resolved, if relative.
  ///   - newPath: The new location of the file.
  ///   - newFD: The directory against which `newPath` is resolved, if relative.
  ///   - options: Options that change how the file is renamed.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Both paths must be on the same file system.
  /// Not every file system supports every option;
  /// one that doesn't throws an error, such as ``Errno/invalidArgument``.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `renameatx_np` on Darwin,
  /// and `renameat2` on Linux and Android.
  /// - Note: Only available on Darwin, Linux, and Android.
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @_alwaysEmitIntoClient
  public static func rename(
    _ oldPath: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to newPath: UnsafePointer<CChar>,
    relativeTo newFD: FileDescriptor,
    options: RenameOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _rename(
      oldPath, relativeTo: fd, to: newPath, relativeTo: newFD, options: options,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @usableFromInline
  internal static func _rename(
    _ oldPath: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to newPath: UnsafePointer<CChar>,
    relativeTo newFD: FileDescriptor,
    options: RenameOptions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      #if SYSTEM_PACKAGE_DARWIN
      system_renameatx_np(
        fd.rawValue, oldPath, newFD.rawValue, newPath, options.rawValue)
      #else
      system_renameat2(
        fd.rawValue, oldPath, newFD.rawValue, newPath, options.rawValue)
      #endif
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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

// MARK: - truncate

@available(System 199, *)
extension FilePath {
  /// Truncates or extends the file at this path.
  ///
  /// - Parameters:
  ///   - newSize: The length in bytes to resize the file to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the current size of the file exceeds `newSize`, any extra data is discarded.
  /// If the current size of the file is smaller than `newSize`,
  /// the file is extended and filled with zeros to the provided size.
  ///
  /// The file must be writable by the calling process.
  ///
  /// The corresponding C function is `truncate`.
  @_alwaysEmitIntoClient
  public func resize(
    to newSize: Int64,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._resize($0, to: newSize, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Truncates or extends the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - newSize: The length in bytes to resize the file to.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the current size of the file exceeds `newSize`, any extra data is discarded.
  /// If the current size of the file is smaller than `newSize`,
  /// the file is extended and filled with zeros to the provided size.
  ///
  /// The file must be writable by the calling process.
  ///
  /// The corresponding C function is `truncate`.
  @_alwaysEmitIntoClient
  public static func resize(
    _ path: UnsafePointer<CChar>,
    to newSize: Int64,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _resize(path, to: newSize, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _resize(
    _ path: UnsafePointer<CChar>,
    to newSize: Int64,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_truncate(path, _COffT(newSize))
    }
  }
}

// MARK: - access, faccessat

@available(System 199, *)
extension FilePath {
  /// The kinds of access to a file that can be checked.
  ///
  /// The empty set checks only that the file exists.
  /// The corresponding C constant is `F_OK`.
  @frozen
  public struct Access: OptionSet, Sendable, Hashable, Codable {
    /// The raw C access mode.
    @_alwaysEmitIntoClient
    public let rawValue: CInt

    /// Creates a strongly-typed `FilePath.Access` from a raw C access mode.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Permission to read the file.
    ///
    /// The corresponding C constant is `R_OK`.
    @_alwaysEmitIntoClient
    public static var read: Access { Access(rawValue: _R_OK) }

    /// Permission to write to the file.
    ///
    /// The corresponding C constant is `W_OK`.
    @_alwaysEmitIntoClient
    public static var write: Access { Access(rawValue: _W_OK) }

    /// Permission to execute the file or, for a directory, to search it.
    ///
    /// The corresponding C constant is `X_OK`.
    @_alwaysEmitIntoClient
    public static var execute: Access { Access(rawValue: _X_OK) }
  }

  /// Checks whether the calling process can access the file at this path.
  ///
  /// - Parameters:
  ///   - access: The kinds of access to check for.
  ///     The default, an empty set, checks only that the file exists.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method returns normally if every requested kind of access
  /// is allowed, and otherwise throws the reason it isn't,
  /// such as ``Errno/permissionDenied`` or ``Errno/noSuchFileOrDirectory``.
  ///
  /// The check uses the process's real user and group IDs,
  /// not its effective ones.
  /// The result can be out of date as soon as this method returns;
  /// to avoid a race, attempt the operation itself and handle its error.
  ///
  /// The corresponding C function is `access`.
  @_alwaysEmitIntoClient
  public func checkAccess(
    _ access: FilePath.Access = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._checkAccess($0, access, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Checks whether the calling process can access the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - access: The kinds of access to check for.
  ///     The default, an empty set, checks only that the file exists.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method returns normally if every requested kind of access
  /// is allowed, and otherwise throws the reason it isn't,
  /// such as ``Errno/permissionDenied`` or ``Errno/noSuchFileOrDirectory``.
  ///
  /// The check uses the process's real user and group IDs,
  /// not its effective ones.
  /// The result can be out of date as soon as this method returns;
  /// to avoid a race, attempt the operation itself and handle its error.
  ///
  /// The corresponding C function is `access`.
  @_alwaysEmitIntoClient
  public static func checkAccess(
    _ path: UnsafePointer<CChar>,
    _ access: FilePath.Access = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _checkAccess(path, access, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _checkAccess(
    _ path: UnsafePointer<CChar>,
    _ access: FilePath.Access,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_access(path, access.rawValue)
    }
  }

  /// Checks whether the calling process can access the file at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - access: The kinds of access to check for.
  ///     The default, an empty set, checks only that the file exists.
  ///   - fd: The directory against which a relative path is resolved.
  ///   - flags: Options that control how the path is resolved.
  ///   - useEffectiveIDs: Whether to check using the process's
  ///     effective user and group IDs, rather than its real ones.
  ///     The default is `false`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method returns normally if every requested kind of access
  /// is allowed, and otherwise throws the reason it isn't,
  /// such as ``Errno/permissionDenied`` or ``Errno/noSuchFileOrDirectory``.
  ///
  /// The result can be out of date as soon as this method returns;
  /// to avoid a race, attempt the operation itself and handle its error.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `faccessat`.
  /// The corresponding C flag is `AT_EACCESS`,
  /// which it passes when `useEffectiveIDs` is `true`.
  @_alwaysEmitIntoClient
  public func checkAccess(
    _ access: FilePath.Access = [],
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    useEffectiveIDs: Bool = false,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._checkAccess(
        $0, access, relativeTo: fd, flags: flags, useEffectiveIDs: useEffectiveIDs,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Checks whether the calling process can access the file at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - access: The kinds of access to check for.
  ///     The default, an empty set, checks only that the file exists.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - flags: Options that control how `path` is resolved.
  ///   - useEffectiveIDs: Whether to check using the process's
  ///     effective user and group IDs, rather than its real ones.
  ///     The default is `false`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method returns normally if every requested kind of access
  /// is allowed, and otherwise throws the reason it isn't,
  /// such as ``Errno/permissionDenied`` or ``Errno/noSuchFileOrDirectory``.
  ///
  /// The result can be out of date as soon as this method returns;
  /// to avoid a race, attempt the operation itself and handle its error.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `faccessat`.
  /// The corresponding C flag is `AT_EACCESS`,
  /// which it passes when `useEffectiveIDs` is `true`.
  @_alwaysEmitIntoClient
  public static func checkAccess(
    _ path: UnsafePointer<CChar>,
    _ access: FilePath.Access = [],
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    useEffectiveIDs: Bool = false,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _checkAccess(
      path, access, relativeTo: fd, flags: flags, useEffectiveIDs: useEffectiveIDs,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _checkAccess(
    _ path: UnsafePointer<CChar>,
    _ access: FilePath.Access,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags,
    useEffectiveIDs: Bool,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    let flag = useEffectiveIDs ? flags.rawValue | _AT_EACCESS : flags.rawValue
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_faccessat(fd.rawValue, path, access.rawValue, flag)
    }
  }
}

// MARK: - getcwd, chdir, fchdir

@available(System 199, *)
extension FilePath {
  /// Returns the current working directory of the calling process.
  ///
  /// - Returns: The absolute path of the current working directory.
  ///
  /// The current working directory belongs to the whole process,
  /// so another thread can change it at any time.
  ///
  /// The corresponding C function is `getcwd`.
  @_alwaysEmitIntoClient
  public static func currentWorkingDirectory() throws(Errno) -> FilePath {
    try _currentWorkingDirectory().get()
  }

  /// The buffer capacity for the first attempt to get the working directory.
  internal static var _initialWorkingDirectoryCapacity: Int { 1024 }

  @usableFromInline
  internal static func _currentWorkingDirectory() -> Result<FilePath, Errno> {
    // Grow the buffer while getcwd reports that it's too small.
    var capacity = _initialWorkingDirectoryCapacity
    while true {
      var result: Result<(), Errno> = .success(())
      let chars = SystemString.Storage(
        unsafeUninitializedCapacity: capacity
      ) { buffer, initializedCount in
        let length: Int? = buffer.withMemoryRebound(
          to: CInterop.PlatformChar.self
        ) { buffer in
          guard system_getcwd(buffer.baseAddress!, buffer.count) != nil else {
            return nil
          }
          return system_platform_strlen(buffer.baseAddress!)
        }
        guard let length else {
          result = .failure(Errno.current)
          initializedCount = 0
          return
        }
        // getcwd initialized the path and its null terminator.
        initializedCount = length + 1
      }

      switch result {
      case .success:
        return .success(FilePath(SystemString(nullTerminated: chars)))
      case .failure(.outOfRange):
        capacity *= 2
      case .failure(let error):
        return .failure(error)
      }
    }
  }

  /// Changes the current working directory of the calling process.
  ///
  /// - Parameters:
  ///   - path: The new current working directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The current working directory belongs to the whole process,
  /// so the change affects every thread's relative paths.
  ///
  /// The corresponding C function is `chdir`.
  @_alwaysEmitIntoClient
  public static func setCurrentWorkingDirectory(
    _ path: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try path.withPlatformString {
      FilePath._setCurrentWorkingDirectory($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the current working directory of the calling process.
  ///
  /// - Parameters:
  ///   - path: The new current working directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The current working directory belongs to the whole process,
  /// so the change affects every thread's relative paths.
  ///
  /// The corresponding C function is `chdir`.
  @_alwaysEmitIntoClient
  public static func setCurrentWorkingDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setCurrentWorkingDirectory(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _setCurrentWorkingDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_chdir(path)
    }
  }

  #if !os(WASI)
  /// Changes the current working directory of the calling process
  /// to an open directory.
  ///
  /// - Parameters:
  ///   - fd: A file descriptor for the new current working directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The current working directory belongs to the whole process,
  /// so the change affects every thread's relative paths.
  ///
  /// The corresponding C function is `fchdir`.
  /// - Note: Not available on WASI.
  @_alwaysEmitIntoClient
  public static func setCurrentWorkingDirectory(
    _ fd: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setCurrentWorkingDirectory(fd, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _setCurrentWorkingDirectory(
    _ fd: FileDescriptor,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchdir(fd.rawValue)
    }
  }
  #endif // !os(WASI)
}

// MARK: - chmod, lchmod, fchmodat

#if !os(WASI)
@available(System 199, *)
extension FilePath {
  /// Changes the permissions of the file at this path.
  ///
  /// - Parameters:
  ///   - permissions: The new permissions for the file.
  ///   - followTargetSymlink: Whether to change the permissions
  ///     of a symbolic link's target, if this path names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the permissions of the link itself,
  ///     which not every platform supports.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `chmod`,
  /// or `lchmod` if `followTargetSymlink` is `false`.
  @_alwaysEmitIntoClient
  public func setPermissions(
    _ permissions: FilePermissions,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setPermissions(
        $0, permissions, followTargetSymlink: followTargetSymlink,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the permissions of the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - permissions: The new permissions for the file.
  ///   - followTargetSymlink: Whether to change the permissions
  ///     of a symbolic link's target, if `path` names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the permissions of the link itself,
  ///     which not every platform supports.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `chmod`,
  /// or `lchmod` if `followTargetSymlink` is `false`.
  @_alwaysEmitIntoClient
  public static func setPermissions(
    _ path: UnsafePointer<CChar>,
    _ permissions: FilePermissions,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setPermissions(
      path, permissions, followTargetSymlink: followTargetSymlink,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setPermissions(
    _ path: UnsafePointer<CChar>,
    _ permissions: FilePermissions,
    followTargetSymlink: Bool,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if followTargetSymlink {
        system_chmod(path, permissions.rawValue)
      } else {
        system_lchmod(path, permissions.rawValue)
      }
    }
  }

  /// Changes the permissions of the file at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - permissions: The new permissions for the file.
  ///   - fd: The directory against which a relative path is resolved.
  ///   - flags: Options that control how the path is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow`` to change the permissions
  ///     of a symbolic link itself, which not every platform supports.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `fchmodat`.
  @_alwaysEmitIntoClient
  public func setPermissions(
    _ permissions: FilePermissions,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setPermissions(
        $0, permissions, relativeTo: fd, flags: flags,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the permissions of the file at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - permissions: The new permissions for the file.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - flags: Options that control how `path` is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow`` to change the permissions
  ///     of a symbolic link itself, which not every platform supports.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `fchmodat`.
  @_alwaysEmitIntoClient
  public static func setPermissions(
    _ path: UnsafePointer<CChar>,
    _ permissions: FilePermissions,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setPermissions(
      path, permissions, relativeTo: fd, flags: flags,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setPermissions(
    _ path: UnsafePointer<CChar>,
    _ permissions: FilePermissions,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchmodat(fd.rawValue, path, permissions.rawValue, flags.rawValue)
    }
  }
}
#endif // !os(WASI)

// MARK: - chown, lchown, fchownat

#if !os(WASI)
@available(System 199, *)
extension FilePath {
  /// Changes the owner and group of the file at this path.
  ///
  /// - Parameters:
  ///   - user: The new owner of the file,
  ///     or `nil` to leave the owner unchanged.
  ///   - group: The new group of the file,
  ///     or `nil` to leave the group unchanged.
  ///   - followTargetSymlink: Whether to change the owner and group
  ///     of a symbolic link's target, if this path names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the owner and group of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Changing the owner typically requires appropriate privileges.
  /// The owner of a file can change its group
  /// to any group that the owner is a member of.
  ///
  /// The corresponding C function is `chown`,
  /// or `lchown` if `followTargetSymlink` is `false`.
  @_alwaysEmitIntoClient
  public func setOwner(
    user: UserID? = nil,
    group: GroupID? = nil,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setOwner(
        $0, user: user, group: group, followTargetSymlink: followTargetSymlink,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the owner and group of the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - user: The new owner of the file,
  ///     or `nil` to leave the owner unchanged.
  ///   - group: The new group of the file,
  ///     or `nil` to leave the group unchanged.
  ///   - followTargetSymlink: Whether to change the owner and group
  ///     of a symbolic link's target, if `path` names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the owner and group of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Changing the owner typically requires appropriate privileges.
  /// The owner of a file can change its group
  /// to any group that the owner is a member of.
  ///
  /// The corresponding C function is `chown`,
  /// or `lchown` if `followTargetSymlink` is `false`.
  @_alwaysEmitIntoClient
  public static func setOwner(
    _ path: UnsafePointer<CChar>,
    user: UserID? = nil,
    group: GroupID? = nil,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setOwner(
      path, user: user, group: group, followTargetSymlink: followTargetSymlink,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setOwner(
    _ path: UnsafePointer<CChar>,
    user: UserID?,
    group: GroupID?,
    followTargetSymlink: Bool,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    // An ID of -1 leaves the corresponding value unchanged.
    let uid = user?.rawValue ?? CInterop.UserID(truncatingIfNeeded: -1)
    let gid = group?.rawValue ?? CInterop.GroupID(truncatingIfNeeded: -1)
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if followTargetSymlink {
        system_chown(path, uid, gid)
      } else {
        system_lchown(path, uid, gid)
      }
    }
  }

  /// Changes the owner and group of the file at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - user: The new owner of the file,
  ///     or `nil` to leave the owner unchanged.
  ///   - group: The new group of the file,
  ///     or `nil` to leave the group unchanged.
  ///   - flags: Options that control how the path is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to change the owner and group of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Changing the owner typically requires appropriate privileges.
  /// The owner of a file can change its group
  /// to any group that the owner is a member of.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `fchownat`.
  @_alwaysEmitIntoClient
  public func setOwner(
    relativeTo fd: FileDescriptor,
    user: UserID? = nil,
    group: GroupID? = nil,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setOwner(
        $0, relativeTo: fd, user: user, group: group, flags: flags,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the owner and group of the file at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - user: The new owner of the file,
  ///     or `nil` to leave the owner unchanged.
  ///   - group: The new group of the file,
  ///     or `nil` to leave the group unchanged.
  ///   - flags: Options that control how `path` is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to change the owner and group of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Changing the owner typically requires appropriate privileges.
  /// The owner of a file can change its group
  /// to any group that the owner is a member of.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `fchownat`.
  @_alwaysEmitIntoClient
  public static func setOwner(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    user: UserID? = nil,
    group: GroupID? = nil,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setOwner(
      path, relativeTo: fd, user: user, group: group, flags: flags,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setOwner(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    user: UserID?,
    group: GroupID?,
    flags: FilePath.ResolutionFlags,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    // An ID of -1 leaves the corresponding value unchanged.
    let uid = user?.rawValue ?? CInterop.UserID(truncatingIfNeeded: -1)
    let gid = group?.rawValue ?? CInterop.GroupID(truncatingIfNeeded: -1)
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchownat(fd.rawValue, path, uid, gid, flags.rawValue)
    }
  }
}
#endif // !os(WASI)

// MARK: - mkfifo, mkfifoat

#if !os(WASI)
@available(System 199, *)
extension FilePath {
  /// Creates a FIFO special file, or named pipe, at this path.
  ///
  /// - Parameters:
  ///   - permissions: The permissions for the new FIFO.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `mkfifo`.
  @_alwaysEmitIntoClient
  public func makeFIFO(
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._makeFIFO(
        $0, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a FIFO special file, or named pipe, at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the new FIFO.
  ///   - permissions: The permissions for the new FIFO.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `mkfifo`.
  @_alwaysEmitIntoClient
  public static func makeFIFO(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeFIFO(
      path, permissions: permissions, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeFIFO(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_mkfifo(path, permissions.rawValue)
    }
  }

  /// Creates a FIFO special file, or named pipe, at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - permissions: The permissions for the new FIFO.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkfifoat`.
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @_alwaysEmitIntoClient
  public func makeFIFO(
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._makeFIFO(
        $0, relativeTo: fd, permissions: permissions,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a FIFO special file, or named pipe, at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the new FIFO.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - permissions: The permissions for the new FIFO.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkfifoat`.
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @_alwaysEmitIntoClient
  public static func makeFIFO(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeFIFO(
      path, relativeTo: fd, permissions: permissions,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @usableFromInline
  internal static func _makeFIFO(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_mkfifoat(fd.rawValue, path, permissions.rawValue)
    }
  }
}
#endif // !os(WASI)

// MARK: - chflags, lchflags, chflagsat

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension FilePath {
  /// Replaces the flags of the file at this path.
  ///
  /// - Parameters:
  ///   - fileFlags: The new flags for the file.
  ///   - followTargetSymlink: Whether to change the flags
  ///     of a symbolic link's target, if this path names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the flags of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method sets all of the file's flags at once.
  /// To change individual flags,
  /// start from the file's current flags, given by ``Stat/flags``.
  /// Some flags can only be changed by the superuser,
  /// and some can't be changed at all;
  /// see the documentation for each flag in ``FileFlags``.
  ///
  /// The corresponding C function is `chflags`,
  /// or `lchflags` if `followTargetSymlink` is `false`.
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public func setFileFlags(
    _ fileFlags: FileFlags,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setFileFlags(
        $0, fileFlags, followTargetSymlink: followTargetSymlink,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Replaces the flags of the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - fileFlags: The new flags for the file.
  ///   - followTargetSymlink: Whether to change the flags
  ///     of a symbolic link's target, if `path` names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to change the flags of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method sets all of the file's flags at once.
  /// To change individual flags,
  /// start from the file's current flags, given by ``Stat/flags``.
  /// Some flags can only be changed by the superuser,
  /// and some can't be changed at all;
  /// see the documentation for each flag in ``FileFlags``.
  ///
  /// The corresponding C function is `chflags`,
  /// or `lchflags` if `followTargetSymlink` is `false`.
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static func setFileFlags(
    _ path: UnsafePointer<CChar>,
    _ fileFlags: FileFlags,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setFileFlags(
      path, fileFlags, followTargetSymlink: followTargetSymlink,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setFileFlags(
    _ path: UnsafePointer<CChar>,
    _ fileFlags: FileFlags,
    followTargetSymlink: Bool,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if followTargetSymlink {
        system_chflags(path, fileFlags.rawValue)
      } else {
        system_lchflags(path, fileFlags.rawValue)
      }
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension FilePath {
  /// Replaces the flags of the file at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fileFlags: The new flags for the file.
  ///   - fd: The directory against which a relative path is resolved.
  ///   - flags: Options that control how the path is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to change the flags of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method sets all of the file's flags at once.
  /// To change individual flags,
  /// start from the file's current flags, given by ``Stat/flags``.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `chflagsat`.
  /// - Note: Only available on FreeBSD and OpenBSD.
  @_alwaysEmitIntoClient
  public func setFileFlags(
    _ fileFlags: FileFlags,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setFileFlags(
        $0, fileFlags, relativeTo: fd, flags: flags,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Replaces the flags of the file at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - fileFlags: The new flags for the file.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - flags: Options that control how `path` is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to change the flags of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method sets all of the file's flags at once.
  /// To change individual flags,
  /// start from the file's current flags, given by ``Stat/flags``.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `chflagsat`.
  /// - Note: Only available on FreeBSD and OpenBSD.
  @_alwaysEmitIntoClient
  public static func setFileFlags(
    _ path: UnsafePointer<CChar>,
    _ fileFlags: FileFlags,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setFileFlags(
      path, fileFlags, relativeTo: fd, flags: flags,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setFileFlags(
    _ path: UnsafePointer<CChar>,
    _ fileFlags: FileFlags,
    relativeTo fd: FileDescriptor,
    flags: FilePath.ResolutionFlags,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_chflagsat(fd.rawValue, path, fileFlags.rawValue, flags.rawValue)
    }
  }
}
#endif // os(FreeBSD) || os(OpenBSD)

#endif // !os(Windows)
