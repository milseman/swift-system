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

#endif // !os(Windows)
