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

#endif // !os(Windows)
