/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// MARK: - chroot

@available(System 199, *)
extension FilePath {
  /// Changes the root directory of the calling process:
  /// the directory that its absolute paths start from.
  ///
  /// - Parameters:
  ///   - path: The new root directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The root directory belongs to the whole process,
  /// and the processes it creates inherit it.
  /// Changing it needs privileges;
  /// without them, this method throws ``Errno/notPermitted``.
  /// It doesn't change the current working directory,
  /// which can stay outside the new root:
  /// change it too, with ``setCurrentWorkingDirectory(_:retryOnInterrupt:)-(FilePath,_)``,
  /// to confine the process.
  ///
  /// The corresponding C function is `chroot`.
  @_alwaysEmitIntoClient
  public static func setRootDirectory(
    _ path: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try path.withPlatformString {
      FilePath._setRootDirectory($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the root directory of the calling process:
  /// the directory that its absolute paths start from.
  ///
  /// - Parameters:
  ///   - path: The new root directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// See ``setRootDirectory(_:retryOnInterrupt:)-(FilePath,_)``.
  ///
  /// The corresponding C function is `chroot`.
  @_alwaysEmitIntoClient
  public static func setRootDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setRootDirectory(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _setRootDirectory(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) { system_chroot(path) }
  }
}

// MARK: - sync

@available(System 199, *)
extension FileDescriptor {
  /// Starts writing every file system's changed data and metadata
  /// to its storage.
  ///
  /// This is the system-wide ``synchronize(retryOnInterrupt:)``,
  /// with a difference: it can return before the writes finish,
  /// as it does on Darwin.
  /// To wait until one file's changes are stored,
  /// call `synchronize(retryOnInterrupt:)` on its descriptor.
  ///
  /// The corresponding C function is `sync`.
  @_alwaysEmitIntoClient
  public static func synchronizeAllFileSystems() {
    _synchronizeAllFileSystems()
  }

  @usableFromInline
  internal static func _synchronizeAllFileSystems() {
    system_sync()
  }
}

#endif // !os(Windows) && !os(WASI)
