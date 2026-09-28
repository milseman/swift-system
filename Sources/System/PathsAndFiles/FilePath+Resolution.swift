/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// MARK: - realpath

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
  /// this method looks up each component in the file system,
  /// so the file must exist:
  /// if it doesn't, this method throws ``Errno/noSuchFileOrDirectory``.
  /// A relative path is resolved against the current working directory.
  ///
  /// The corresponding C function is `realpath`.
  @_alwaysEmitIntoClient
  public func canonicalized() throws(Errno) -> FilePath {
    try withPlatformString { FilePath._canonicalized($0) }.get()
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
  ///
  /// The corresponding C function is `realpath`.
  @_alwaysEmitIntoClient
  public static func canonicalized(_ path: UnsafePointer<CChar>) throws(Errno) -> FilePath {
    try _canonicalized(path).get()
  }

  @usableFromInline
  internal static func _canonicalized(_ path: UnsafePointer<CChar>) -> Result<FilePath, Errno> {
    guard let resolved = system_realpath(path) else { return .failure(.current) }
    defer { system_free(resolved) }
    return .success(FilePath(SystemString(platformString: resolved)))
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
  /// as ``removeDirectory(retryOnInterrupt:)`` does,
  /// and anything else, including a symbolic link, as ``unlink(retryOnInterrupt:)`` does.
  /// Which error it throws for a path that neither can remove differs by platform:
  /// Darwin's C library checks what the path names first,
  /// and glibc's tries to unlink it first.
  ///
  /// The corresponding C function is `remove`.
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
  /// This method removes a directory, which must be empty,
  /// as ``removeDirectory(_:retryOnInterrupt:)`` does,
  /// and anything else, including a symbolic link, as ``unlink(_:retryOnInterrupt:)`` does.
  ///
  /// The corresponding C function is `remove`.
  @_alwaysEmitIntoClient
  public static func remove(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _remove(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _remove(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_remove(path)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
