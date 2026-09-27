/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Cloning files: clonefile and clonefileat for paths, and fclonefileat for
// a file descriptor.

#if SYSTEM_PACKAGE_DARWIN

// MARK: - Clone options

@available(System 199, *)
extension FilePath {
  /// Options that change how a file is cloned.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct CloneOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates a strongly-typed `FilePath.CloneOptions` from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// If the source is a symbolic link, clone the link itself.
    ///
    /// The corresponding C constant is `CLONE_NOFOLLOW`.
    @_alwaysEmitIntoClient
    public static var noFollow: CloneOptions { CloneOptions(rawValue: _CLONE_NOFOLLOW) }

    /// Give the clone the owner that a new file would get,
    /// even if the process has the privileges to copy the source's.
    ///
    /// The corresponding C constant is `CLONE_NOOWNERCOPY`.
    @_alwaysEmitIntoClient
    public static var noOwnerCopy: CloneOptions {
      CloneOptions(rawValue: _CLONE_NOOWNERCOPY)
    }

    /// Copy the source's access control list,
    /// as well as applying the ones the destination directory passes on.
    ///
    /// The corresponding C constant is `CLONE_ACL`.
    @_alwaysEmitIntoClient
    public static var accessControlList: CloneOptions { CloneOptions(rawValue: _CLONE_ACL) }

    /// Throw ``Errno/tooManySymbolicLinkLevels`` if resolving either path
    /// encounters a symbolic link before its last component.
    ///
    /// The corresponding C constant is `CLONE_NOFOLLOW_ANY`.
    @_alwaysEmitIntoClient
    public static var noFollowAny: CloneOptions {
      CloneOptions(rawValue: _CLONE_NOFOLLOW_ANY)
    }

    #if canImport(Darwin, _version: 346)
    /// Throw ``Errno/notCapable`` if either path doesn't resolve
    /// to a location beneath its starting directory.
    ///
    /// A system that doesn't support this option
    /// throws ``Errno/invalidArgument`` for it.
    ///
    /// The corresponding C constant is `CLONE_RESOLVE_BENEATH`.
    /// - Note: Only available when building with the macOS 26 SDK or later.
    @_alwaysEmitIntoClient
    public static var resolveBeneath: CloneOptions {
      CloneOptions(rawValue: _CLONE_RESOLVE_BENEATH)
    }
    #endif
  }
}

@available(System 199, *)
extension FilePath.CloneOptions: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the options.
  @inline(never)
  public var description: String {
    #if canImport(Darwin, _version: 346)
    let descriptions: [(Element, StaticString)] = [
      (.noFollow, ".noFollow"),
      (.noOwnerCopy, ".noOwnerCopy"),
      (.accessControlList, ".accessControlList"),
      (.noFollowAny, ".noFollowAny"),
      (.resolveBeneath, ".resolveBeneath"),
    ]
    #else
    let descriptions: [(Element, StaticString)] = [
      (.noFollow, ".noFollow"),
      (.noOwnerCopy, ".noOwnerCopy"),
      (.accessControlList, ".accessControlList"),
      (.noFollowAny, ".noFollowAny"),
    ]
    #endif
    return _buildDescription(descriptions)
  }

  /// A textual representation of the options, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - clonefile, clonefileat

// The calls need a newer OS than System 199 means in the default build, so
// these declarations carry both.

@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension FilePath {
  /// Clones the file at this path to a new path.
  ///
  /// - Parameters:
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written,
  /// so writing either one can throw ``Errno/noSpace``.
  /// It has its own copy of the file's attributes and extended attributes,
  /// except that it gets the owner a new file would get
  /// unless the process has the privileges to copy the source's,
  /// it has no set-user-ID or set-group-ID bits,
  /// and it gets the access control lists that the destination directory
  /// passes on.
  ///
  /// Both paths must be on the same file system,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  /// Cloning a directory clones everything in it,
  /// but the system discourages it:
  /// to clone a directory's files, call ``copy(to:options:)``
  /// with ``CopyOptions/clone`` and ``CopyOptions/recursive`` instead.
  ///
  /// The corresponding C function is `clonefile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    to destination: FilePath,
    options: CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { source in
      destination.withPlatformString { destination in
        FilePath._clone(
          source, to: destination, options: options, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Clones the file at the given path to a new path.
  ///
  /// - Parameters:
  ///   - source: The file to clone.
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written,
  /// so writing either one can throw ``Errno/noSpace``.
  /// It has its own copy of the file's attributes and extended attributes,
  /// except that it gets the owner a new file would get
  /// unless the process has the privileges to copy the source's,
  /// it has no set-user-ID or set-group-ID bits,
  /// and it gets the access control lists that the destination directory
  /// passes on.
  ///
  /// Both paths must be on the same file system,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// The corresponding C function is `clonefile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func clone(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _clone(
      source, to: destination, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _clone(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CloneOptions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_clonefile(source, destination, options.rawValue)
    }
  }

  /// Clones the file at this path to a new path,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - fd: The directory against which this path is resolved, if relative.
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - destinationFD: The directory against which `destination`
  ///     is resolved, if relative.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// Both paths must be on the same file system,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `clonefileat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    relativeTo fd: FileDescriptor,
    to destination: FilePath,
    relativeTo destinationFD: FileDescriptor,
    options: CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString { source in
      destination.withPlatformString { destination in
        FilePath._clone(
          source, relativeTo: fd, to: destination, relativeTo: destinationFD,
          options: options, retryOnInterrupt: retryOnInterrupt)
      }
    }.get()
  }

  /// Clones the file at the given path to a new path,
  /// resolving relative paths against directories.
  ///
  /// - Parameters:
  ///   - source: The file to clone.
  ///   - fd: The directory against which `source` is resolved, if relative.
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - destinationFD: The directory against which `destination`
  ///     is resolved, if relative.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// Both paths must be on the same file system,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// An absolute path ignores its directory argument.
  ///
  /// The corresponding C function is `clonefileat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func clone(
    _ source: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to destination: UnsafePointer<CChar>,
    relativeTo destinationFD: FileDescriptor,
    options: CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _clone(
      source, relativeTo: fd, to: destination, relativeTo: destinationFD,
      options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _clone(
    _ source: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    to destination: UnsafePointer<CChar>,
    relativeTo destinationFD: FileDescriptor,
    options: CloneOptions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_clonefileat(
        fd.rawValue, source, destinationFD.rawValue, destination, options.rawValue)
    }
  }
}

// MARK: - fclonefileat

@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension FileDescriptor {
  /// Clones the file that this descriptor refers to, to a new path.
  ///
  /// - Parameters:
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// The destination must be on the same file system as the file,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// The corresponding C function is `fclonefileat`,
  /// with the `AT_FDCWD` directory.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    to destination: FilePath,
    options: FilePath.CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try destination.withPlatformString {
      _clone(to: $0, relativeTo: nil, options: options, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Clones the file that this descriptor refers to, to a new path.
  ///
  /// - Parameters:
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// The destination must be on the same file system as the file,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// The corresponding C function is `fclonefileat`,
  /// with the `AT_FDCWD` directory.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    to destination: UnsafePointer<CChar>,
    options: FilePath.CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _clone(
      to: destination, relativeTo: nil, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Clones the file that this descriptor refers to, to a new path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - destinationFD: The directory against which `destination`
  ///     is resolved, if relative.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// The destination must be on the same file system as the file,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// If `destination` is absolute, `destinationFD` is ignored.
  ///
  /// The corresponding C function is `fclonefileat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    to destination: FilePath,
    relativeTo destinationFD: FileDescriptor,
    options: FilePath.CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try destination.withPlatformString {
      _clone(
        to: $0, relativeTo: destinationFD, options: options,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Clones the file that this descriptor refers to, to a new path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - destination: The location of the clone,
  ///     where no file may exist.
  ///   - destinationFD: The directory against which `destination`
  ///     is resolved, if relative.
  ///   - options: Options that change how the file is cloned.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The clone shares the file's data until one of them is written.
  /// The destination must be on the same file system as the file,
  /// or this method throws ``Errno/improperLink``;
  /// a file system that can't clone throws ``Errno/notSupported``.
  ///
  /// If `destination` is absolute, `destinationFD` is ignored.
  ///
  /// The corresponding C function is `fclonefileat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func clone(
    to destination: UnsafePointer<CChar>,
    relativeTo destinationFD: FileDescriptor,
    options: FilePath.CloneOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _clone(
      to: destination, relativeTo: destinationFD, options: options,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  // Resolves against the working directory if `destinationFD` is nil.
  @usableFromInline
  internal func _clone(
    to destination: UnsafePointer<CChar>,
    relativeTo destinationFD: FileDescriptor?,
    options: FilePath.CloneOptions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fclonefileat(
        self.rawValue, destinationFD?.rawValue ?? _AT_FDCWD, destination, options.rawValue)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
