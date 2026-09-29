/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Extended attributes: named values that a file system keeps with a file,
// beside its contents. One API over Darwin's and Linux's calls, whose
// signatures differ; FreeBSD's and OpenBSD's extattr calls, which differ
// more, aren't wrapped.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

/// Options for setting an extended attribute.
@frozen
@available(System 199, *)
public struct ExtendedAttributeOptions: OptionSet, Hashable, Sendable {
  /// The raw C options.
  @_alwaysEmitIntoClient
  public var rawValue: CInt

  /// Creates a strongly-typed set of options from raw C options.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }

  /// Fails with ``Errno/fileExists`` if the file already has the attribute.
  ///
  /// The corresponding C constant is `XATTR_CREATE`.
  @_alwaysEmitIntoClient
  public static var create: Self { Self(rawValue: _XATTR_CREATE) }

  /// Fails with ``Errno/attributeNotFound`` if the file doesn't have
  /// the attribute yet.
  ///
  /// The corresponding C constant is `XATTR_REPLACE`.
  @_alwaysEmitIntoClient
  public static var replace: Self { Self(rawValue: _XATTR_REPLACE) }
}

#if os(Linux) || os(Android)
@available(System 199, *)
extension Errno {
  /// Attribute not found.
  ///
  /// The error for an extended attribute that a file doesn't have.
  /// Linux reports it as `ENODATA`, which its attribute library
  /// also names `ENOATTR`, and Darwin as `ENOATTR`:
  /// this name is that error on each.
  ///
  /// The corresponding C error is `ENODATA`.
  @_alwaysEmitIntoClient
  public static var attributeNotFound: Errno { .init(rawValue: _ENODATA) }
}
#endif

// MARK: - Paths

@available(System 199, *)
extension FilePath {
  /// Returns the names of the file's extended attributes.
  ///
  /// - Parameters:
  ///   - followTargetSymlink: Whether to read the attributes of the file
  ///     that a symbolic link at this path points to,
  ///     rather than those of the link itself. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The names, in no particular order.
  ///
  /// Linux puts each name in a namespace, such as `user.` for the ones
  /// that a file's owner can set, and lists only those that the process
  /// may read; Darwin's names have no namespace.
  ///
  /// The corresponding C function is `listxattr`,
  /// or on Linux `llistxattr` for a link itself.
  /// The corresponding C constant is `XATTR_NOFOLLOW`,
  /// which Darwin's call takes for a link itself.
  @_alwaysEmitIntoClient
  public func extendedAttributeNames(
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> [String] {
    try withPlatformString {
      FilePath._extendedAttributeNames(
        $0, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns the names of the extended attributes of the file at a path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - followTargetSymlink: Whether to read the attributes of the file
  ///     that a symbolic link at `path` points to. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The names, in no particular order.
  ///
  /// The corresponding C function is `listxattr`.
  @_alwaysEmitIntoClient
  public static func extendedAttributeNames(
    _ path: UnsafePointer<CChar>,
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> [String] {
    try _extendedAttributeNames(
      path, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _extendedAttributeNames(
    _ path: UnsafePointer<CChar>, followTargetSymlink: Bool, retryOnInterrupt: Bool
  ) -> Result<[String], Errno> {
    _readAttributeNames(retryOnInterrupt: retryOnInterrupt) {
      system_listxattr(path, $0, $1, noFollow: !followTargetSymlink)
    }
  }

  /// Returns the value of one of the file's extended attributes.
  ///
  /// - Parameters:
  ///   - name: The attribute's name, such as `"user.origin"` on Linux.
  ///   - followTargetSymlink: Whether to read the attribute of the file
  ///     that a symbolic link at this path points to,
  ///     rather than that of the link itself. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The attribute's value, or `nil` if the file doesn't have it.
  ///
  /// A missing attribute is `ENOATTR` on Darwin and `ENODATA` on Linux,
  /// which this method returns as `nil` on both.
  ///
  /// The corresponding C function is `getxattr`,
  /// or on Linux `lgetxattr` for a link itself.
  /// The corresponding C constant is `XATTR_NOFOLLOW`,
  /// which Darwin's call takes for a link itself.
  @_alwaysEmitIntoClient
  public func extendedAttribute(
    _ name: String, followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> [UInt8]? {
    try withPlatformString {
      FilePath._extendedAttribute(
        $0, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns the value of one of the extended attributes of the file at a path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - name: The attribute's name.
  ///   - followTargetSymlink: Whether to read the attribute of the file
  ///     that a symbolic link at `path` points to. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The attribute's value, or `nil` if the file doesn't have it.
  ///
  /// The corresponding C function is `getxattr`.
  @_alwaysEmitIntoClient
  public static func extendedAttribute(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> [UInt8]? {
    try _extendedAttribute(
      path, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _extendedAttribute(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool, retryOnInterrupt: Bool
  ) -> Result<[UInt8]?, Errno> {
    name.withCString { name in
      _readAttributeValue(retryOnInterrupt: retryOnInterrupt) {
        system_getxattr(path, name, $0, $1, noFollow: !followTargetSymlink)
      }
    }
  }

  /// Sets one of the file's extended attributes.
  ///
  /// - Parameters:
  ///   - name: The attribute's name, such as `"user.origin"` on Linux,
  ///     where it must start with a namespace.
  ///   - value: The attribute's new value.
  ///   - options: Whether the attribute must be new, or must already exist.
  ///     The default is neither: the method creates or replaces it.
  ///   - followTargetSymlink: Whether to set the attribute of the file
  ///     that a symbolic link at this path points to,
  ///     rather than that of the link itself,
  ///     which Linux allows only for some namespaces. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A file system that doesn't support extended attributes throws
  /// ``Errno/notSupported``.
  ///
  /// The corresponding C function is `setxattr`,
  /// or on Linux `lsetxattr` for a link itself.
  /// The corresponding C constant is `XATTR_NOFOLLOW`,
  /// which Darwin's call takes for a link itself.
  @_alwaysEmitIntoClient
  public func setExtendedAttribute(
    _ name: String, to value: some Sequence<UInt8>,
    options: ExtendedAttributeOptions = [],
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setExtendedAttribute(
        $0, name, value, options: options,
        followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Sets one of the extended attributes of the file at a path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - name: The attribute's name.
  ///   - value: The attribute's new value.
  ///   - options: Whether the attribute must be new, or must already exist.
  ///     The default is neither.
  ///   - followTargetSymlink: Whether to set the attribute of the file
  ///     that a symbolic link at `path` points to. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  ///
  /// The corresponding C function is `setxattr`.
  @_alwaysEmitIntoClient
  public static func setExtendedAttribute(
    _ path: UnsafePointer<CChar>, _ name: String, to value: some Sequence<UInt8>,
    options: ExtendedAttributeOptions = [],
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setExtendedAttribute(
      path, name, value, options: options,
      followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _setExtendedAttribute<Value: Sequence<UInt8>>(
    _ path: UnsafePointer<CChar>, _ name: String, _ value: Value,
    options: ExtendedAttributeOptions, followTargetSymlink: Bool, retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    value._withRawBufferPointer { value in
      name.withCString { name in
        nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
          system_setxattr(
            path, name, value.baseAddress, value.count, options.rawValue,
            noFollow: !followTargetSymlink)
        }
      }
    }
  }

  /// Removes one of the file's extended attributes.
  ///
  /// - Parameters:
  ///   - name: The attribute's name.
  ///   - followTargetSymlink: Whether to remove the attribute of the file
  ///     that a symbolic link at this path points to,
  ///     rather than that of the link itself. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the file doesn't have the attribute,
  /// this method throws ``Errno/attributeNotFound``.
  ///
  /// The corresponding C function is `removexattr`,
  /// or on Linux `lremovexattr` for a link itself.
  /// The corresponding C constant is `XATTR_NOFOLLOW`,
  /// which Darwin's call takes for a link itself.
  @_alwaysEmitIntoClient
  public func removeExtendedAttribute(
    _ name: String, followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._removeExtendedAttribute(
        $0, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Removes one of the extended attributes of the file at a path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - name: The attribute's name.
  ///   - followTargetSymlink: Whether to remove the attribute of the file
  ///     that a symbolic link at `path` points to. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  ///
  /// The corresponding C function is `removexattr`.
  @_alwaysEmitIntoClient
  public static func removeExtendedAttribute(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _removeExtendedAttribute(
      path, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _removeExtendedAttribute(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool, retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    name.withCString { name in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_removexattr(path, name, noFollow: !followTargetSymlink)
      }
    }
  }
}

// MARK: - Descriptors

@available(System 199, *)
extension FileDescriptor {
  /// Returns the names of the extended attributes of the file
  /// that this descriptor refers to.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the operation
  ///   if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The names, in no particular order.
  ///
  /// The corresponding C function is `flistxattr`.
  @_alwaysEmitIntoClient
  public func extendedAttributeNames(retryOnInterrupt: Bool = true) throws(Errno) -> [String] {
    try _extendedAttributeNames(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _extendedAttributeNames(retryOnInterrupt: Bool) -> Result<[String], Errno> {
    _readAttributeNames(retryOnInterrupt: retryOnInterrupt) {
      system_flistxattr(rawValue, $0, $1)
    }
  }

  /// Returns the value of one of the extended attributes of the file
  /// that this descriptor refers to.
  ///
  /// - Parameters:
  ///   - name: The attribute's name.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The attribute's value, or `nil` if the file doesn't have it.
  ///
  /// The corresponding C function is `fgetxattr`.
  @_alwaysEmitIntoClient
  public func extendedAttribute(
    _ name: String, retryOnInterrupt: Bool = true
  ) throws(Errno) -> [UInt8]? {
    try _extendedAttribute(name, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _extendedAttribute(
    _ name: String, retryOnInterrupt: Bool
  ) -> Result<[UInt8]?, Errno> {
    name.withCString { name in
      _readAttributeValue(retryOnInterrupt: retryOnInterrupt) {
        system_fgetxattr(rawValue, name, $0, $1)
      }
    }
  }

  /// Sets one of the extended attributes of the file
  /// that this descriptor refers to.
  ///
  /// - Parameters:
  ///   - name: The attribute's name.
  ///   - value: The attribute's new value.
  ///   - options: Whether the attribute must be new, or must already exist.
  ///     The default is neither.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  ///
  /// The corresponding C function is `fsetxattr`.
  @_alwaysEmitIntoClient
  public func setExtendedAttribute(
    _ name: String, to value: some Sequence<UInt8>,
    options: ExtendedAttributeOptions = [], retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setExtendedAttribute(name, value, options: options, retryOnInterrupt: retryOnInterrupt)
      .get()
  }

  @usableFromInline
  internal func _setExtendedAttribute<Value: Sequence<UInt8>>(
    _ name: String, _ value: Value,
    options: ExtendedAttributeOptions, retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    value._withRawBufferPointer { value in
      name.withCString { name in
        nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
          system_fsetxattr(rawValue, name, value.baseAddress, value.count, options.rawValue)
        }
      }
    }
  }

  /// Removes one of the extended attributes of the file
  /// that this descriptor refers to.
  ///
  /// - Parameters:
  ///   - name: The attribute's name.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  ///
  /// If the file doesn't have the attribute,
  /// this method throws ``Errno/attributeNotFound``.
  ///
  /// The corresponding C function is `fremovexattr`.
  @_alwaysEmitIntoClient
  public func removeExtendedAttribute(_ name: String, retryOnInterrupt: Bool = true) throws(Errno) {
    try _removeExtendedAttribute(name, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _removeExtendedAttribute(
    _ name: String, retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    name.withCString { name in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_fremovexattr(rawValue, name)
      }
    }
  }
}

// MARK: - Reading

/// Reads an attribute's value with `read`, which returns its size when
/// given no buffer, and fills a buffer otherwise. A value that grows between
/// the two calls fails with ERANGE, which reads it again.
@available(System 199, *)
internal func _readAttributeValue(
  retryOnInterrupt: Bool, _ read: (UnsafeMutableRawPointer?, Int) -> Int
) -> Result<[UInt8]?, Errno> {
  while true {
    let size: Int
    switch valueOrErrno(retryOnInterrupt: retryOnInterrupt, { read(nil, 0) }) {
    case .success(let count): size = count
    case .failure(let error):
      return error == .attributeNotFound ? .success(nil) : .failure(error)
    }
    var value = [UInt8](repeating: 0, count: size)
    let result = value.withUnsafeMutableBytes { buffer in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) { read(buffer.baseAddress, buffer.count) }
    }
    switch result {
    case .success(let count):
      value.removeLast(value.count - min(count, value.count))
      return .success(value)
    case .failure(.outOfRange):
      continue
    case .failure(let error):
      return error == .attributeNotFound ? .success(nil) : .failure(error)
    }
  }
}

/// Reads the null-separated attribute names that `list` writes,
/// as `_readAttributeValue` reads a value.
@available(System 199, *)
internal func _readAttributeNames(
  retryOnInterrupt: Bool, _ list: (UnsafeMutablePointer<CChar>?, Int) -> Int
) -> Result<[String], Errno> {
  while true {
    let size: Int
    switch valueOrErrno(retryOnInterrupt: retryOnInterrupt, { list(nil, 0) }) {
    case .success(let count): size = count
    case .failure(let error): return .failure(error)
    }
    var names = [CChar](repeating: 0, count: size)
    let result = names.withUnsafeMutableBufferPointer { buffer in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) { list(buffer.baseAddress, buffer.count) }
    }
    switch result {
    case .success(let count):
      return .success(names.prefix(count).split(separator: 0).map {
        String(decoding: $0.map { UInt8(bitPattern: $0) }, as: UTF8.self)
      })
    case .failure(.outOfRange):
      continue
    case .failure(let error):
      return .failure(error)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
