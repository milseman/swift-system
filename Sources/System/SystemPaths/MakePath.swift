/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Making a directory and any missing directories before it, as `mkdir -p`
// does: mkpath_np and mkpathat_np.
//
// These return a Bool rather than throwing EEXIST: mkpath_np returns EEXIST
// only when a directory is already at the path, which is the result that a
// caller asks for, so every caller would otherwise need the same catch. A
// file of another kind at the path throws ENOTDIR.

#if SYSTEM_PACKAGE_DARWIN

@available(System 199, *)
extension FilePath {
  /// Creates a directory at this path,
  /// along with any directories before it that don't exist,
  /// as `mkdir -p` does.
  ///
  /// - Parameters:
  ///   - permissions: The permissions for the directory at this path.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if this method created the directory at this path,
  ///   or `false` if a directory was already there,
  ///   whatever its permissions.
  ///
  /// The directories before the last get the permissions `0o777`,
  /// with the file creation mask applied,
  /// plus write and search permission for their owner.
  /// If a file other than a directory is at this path or before it,
  /// this method throws ``Errno/notDirectory``.
  ///
  /// The corresponding C function is `mkpath_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func makeDirectories(
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try withPlatformString {
      FilePath._makeDirectories($0, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a directory at the given path,
  /// along with any directories before it that don't exist,
  /// as `mkdir -p` does.
  ///
  /// - Parameters:
  ///   - path: The location of the directory.
  ///   - permissions: The permissions for the directory at `path`.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if this method created the directory at `path`,
  ///   or `false` if a directory was already there,
  ///   whatever its permissions.
  ///
  /// The directories before the last get the permissions `0o777`,
  /// with the file creation mask applied,
  /// plus write and search permission for their owner.
  /// If a file other than a directory is at `path` or before it,
  /// this method throws ``Errno/notDirectory``.
  ///
  /// The corresponding C function is `mkpath_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func makeDirectories(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try _makeDirectories(path, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
      .get()
  }

  @usableFromInline
  internal static func _makeDirectories(
    _ path: UnsafePointer<CChar>,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<Bool, Errno> {
    _madeOrExisted(
      nothingOrReturnedErrno(retryOnInterrupt: retryOnInterrupt) {
        system_mkpath_np(path, permissions.rawValue)
      })
  }
}

// The call needs a newer OS than System 199 means in the default build, so
// this extension carries both.
@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension FilePath {
  /// Creates a directory at this path,
  /// along with any directories before it that don't exist,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - permissions: The permissions for the directory at this path.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if this method created the directory at this path,
  ///   or `false` if a directory was already there,
  ///   whatever its permissions.
  ///
  /// The directories before the last get the permissions `0o777`,
  /// with the file creation mask applied,
  /// plus write and search permission for their owner.
  /// If a file other than a directory is at this path or before it,
  /// this method throws ``Errno/notDirectory``.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkpathat_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func makeDirectories(
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try withPlatformString {
      FilePath._makeDirectories(
        $0, relativeTo: fd, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a directory at the given path,
  /// along with any directories before it that don't exist,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the directory.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - permissions: The permissions for the directory at `path`.
  ///     The process's file creation mask is applied to these permissions.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if this method created the directory at `path`,
  ///   or `false` if a directory was already there,
  ///   whatever its permissions.
  ///
  /// The directories before the last get the permissions `0o777`,
  /// with the file creation mask applied,
  /// plus write and search permission for their owner.
  /// If a file other than a directory is at `path` or before it,
  /// this method throws ``Errno/notDirectory``.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `mkpathat_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func makeDirectories(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try _makeDirectories(
      path, relativeTo: fd, permissions: permissions, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _makeDirectories(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<Bool, Errno> {
    _madeOrExisted(
      nothingOrReturnedErrno(retryOnInterrupt: retryOnInterrupt) {
        system_mkpathat_np(fd.rawValue, path, permissions.rawValue)
      })
  }
}

// mkpath_np returns EEXIST only if a directory is already at the path.
@available(System 199, *)
@usableFromInline
internal func _madeOrExisted(_ result: Result<(), Errno>) -> Result<Bool, Errno> {
  switch result {
  case .success: return .success(true)
  case .failure(.fileExists): return .success(false)
  case .failure(let error): return .failure(error)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
