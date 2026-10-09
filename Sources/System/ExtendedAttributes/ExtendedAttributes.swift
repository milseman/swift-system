/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Extended attributes: named values that a file system keeps with a file,
// beside its contents. One API over Darwin's and Linux's calls, whose
// signatures differ, and FreeBSD's extattr calls, which differ more: they
// take a namespace, which here is always the user namespace, and no
// options. OpenBSD has no extended attributes.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)

/// Options for setting an extended attribute.
///
/// FreeBSD's calls take no options: setting an attribute there creates it
/// or replaces it, and a set with options throws
/// ``Errno/invalidArgument``.
@frozen
@available(System 199, *)
public struct ExtendedAttributeOptions: OptionSet, Hashable, Sendable {
  /// The raw C options.
  @_alwaysEmitIntoClient
  public var rawValue: CInt

  /// Creates a strongly-typed set of options from raw C options.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }

  #if !os(FreeBSD)
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
  #endif
}

#if SYSTEM_PACKAGE_DARWIN
/// The names of the extended attributes that Darwin itself keeps.
///
///     let info = try path.extendedAttribute(ExtendedAttributeName.finderInfo)
///
/// - Note: Only available on Darwin.
@available(System 199, *)
public enum ExtendedAttributeName {
  /// The attribute that holds a file's Finder information:
  /// 32 bytes of type and creator codes, flags, and positions.
  ///
  /// The corresponding C constant is `XATTR_FINDERINFO_NAME`.
  @_alwaysEmitIntoClient
  public static var finderInfo: String { _XATTR_FINDERINFO_NAME }

  /// The attribute that holds a file's resource fork.
  ///
  /// The corresponding C constant is `XATTR_RESOURCEFORK_NAME`.
  @_alwaysEmitIntoClient
  public static var resourceFork: String { _XATTR_RESOURCEFORK_NAME }
}
#endif

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
  /// On FreeBSD, these are the attributes of the user namespace,
  /// whose names have no prefix.
  ///
  /// The corresponding C function is `listxattr`,
  /// or on Linux `llistxattr` for a link itself,
  /// or on FreeBSD `extattr_list_file`, and `extattr_list_link` for a link itself,
  /// with `EXTATTR_NAMESPACE_USER`.
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
  /// The corresponding C function is `listxattr`,
  /// or on FreeBSD `extattr_list_file`.
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
  /// A missing attribute is `ENOATTR` on Darwin and FreeBSD
  /// and `ENODATA` on Linux, which this method returns as `nil` on each.
  /// On FreeBSD, the attribute is in the user namespace.
  ///
  /// The corresponding C function is `getxattr`,
  /// or on Linux `lgetxattr` for a link itself,
  /// or on FreeBSD `extattr_get_file`, and `extattr_get_link` for a link itself,
  /// with `EXTATTR_NAMESPACE_USER`.
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
  /// The corresponding C function is `getxattr`,
  /// or on FreeBSD `extattr_get_file`.
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

  /// Returns the size of one of the file's extended attributes,
  /// without reading its value.
  ///
  /// - Parameters:
  ///   - name: The attribute's name, such as `"user.origin"` on Linux.
  ///   - followTargetSymlink: Whether to measure the attribute of the file
  ///     that a symbolic link at this path points to,
  ///     rather than that of the link itself. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The size of the attribute's value in bytes,
  ///   or `nil` if the file doesn't have it.
  ///
  /// The value can change before you read it;
  /// ``extendedAttribute(_:followTargetSymlink:retryOnInterrupt:)``
  /// reads it whatever its size.
  ///
  /// The corresponding C function is `getxattr`, with no buffer,
  /// or on Linux `lgetxattr` for a link itself,
  /// or on FreeBSD `extattr_get_file`, and `extattr_get_link` for a link itself.
  @_alwaysEmitIntoClient
  public func extendedAttributeSize(
    _ name: String, followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int? {
    try withPlatformString {
      FilePath._extendedAttributeSize(
        $0, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns the size of one of the extended attributes of the file
  /// at a path, without reading its value.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - name: The attribute's name.
  ///   - followTargetSymlink: Whether to measure the attribute of the file
  ///     that a symbolic link at `path` points to. The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The size of the attribute's value in bytes,
  ///   or `nil` if the file doesn't have it.
  ///
  /// The corresponding C function is `getxattr`, with no buffer,
  /// or on FreeBSD `extattr_get_file`.
  @_alwaysEmitIntoClient
  public static func extendedAttributeSize(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool = true, retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int? {
    try _extendedAttributeSize(
      path, name, followTargetSymlink: followTargetSymlink, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _extendedAttributeSize(
    _ path: UnsafePointer<CChar>, _ name: String,
    followTargetSymlink: Bool, retryOnInterrupt: Bool
  ) -> Result<Int?, Errno> {
    name.withCString { name in
      _readAttributeSize(retryOnInterrupt: retryOnInterrupt) {
        system_getxattr(path, name, nil, 0, noFollow: !followTargetSymlink)
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
  /// On FreeBSD, the attribute is in the user namespace,
  /// and `options` must be empty.
  ///
  /// The corresponding C function is `setxattr`,
  /// or on Linux `lsetxattr` for a link itself,
  /// or on FreeBSD `extattr_set_file`, and `extattr_set_link` for a link itself,
  /// with `EXTATTR_NAMESPACE_USER`.
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
  /// The corresponding C function is `setxattr`,
  /// or on FreeBSD `extattr_set_file`.
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
  /// On FreeBSD, the attribute is in the user namespace.
  ///
  /// The corresponding C function is `removexattr`,
  /// or on Linux `lremovexattr` for a link itself,
  /// or on FreeBSD `extattr_delete_file`, and `extattr_delete_link` for a link itself,
  /// with `EXTATTR_NAMESPACE_USER`.
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
  /// The corresponding C function is `removexattr`,
  /// or on FreeBSD `extattr_delete_file`.
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
  /// The corresponding C function is `flistxattr`,
  /// or on FreeBSD `extattr_list_fd`.
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
  /// The corresponding C function is `fgetxattr`,
  /// or on FreeBSD `extattr_get_fd`.
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

  /// Returns the size of one of the extended attributes of the file
  /// that this descriptor refers to, without reading its value.
  ///
  /// - Parameters:
  ///   - name: The attribute's name.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``. The default is `true`.
  /// - Returns: The size of the attribute's value in bytes,
  ///   or `nil` if the file doesn't have it.
  ///
  /// The corresponding C function is `fgetxattr`, with no buffer,
  /// or on FreeBSD `extattr_get_fd`.
  @_alwaysEmitIntoClient
  public func extendedAttributeSize(
    _ name: String, retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int? {
    try _extendedAttributeSize(name, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _extendedAttributeSize(
    _ name: String, retryOnInterrupt: Bool
  ) -> Result<Int?, Errno> {
    name.withCString { name in
      _readAttributeSize(retryOnInterrupt: retryOnInterrupt) {
        system_fgetxattr(rawValue, name, nil, 0)
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
  /// The corresponding C function is `fsetxattr`,
  /// or on FreeBSD `extattr_set_fd`.
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
  /// The corresponding C function is `fremovexattr`,
  /// or on FreeBSD `extattr_delete_fd`.
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
/// the two calls fails with ERANGE, which reads it again. FreeBSD's calls
/// truncate the value instead, so there the buffer has a byte to spare, and
/// a read that fills it reads again.
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
    var value = [UInt8](repeating: 0, count: size + _attributeSpareByteCount)
    let result = value.withUnsafeMutableBytes { buffer in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) { read(buffer.baseAddress, buffer.count) }
    }
    switch result {
    case .success(let count):
      if _attributeSpareByteCount > 0 && count == value.count { continue }
      value.removeLast(value.count - min(count, value.count))
      return .success(value)
    case .failure(.outOfRange):
      continue
    case .failure(let error):
      return error == .attributeNotFound ? .success(nil) : .failure(error)
    }
  }
}

/// Returns the size that `size` returns, a getxattr call with no buffer,
/// or `nil` for a missing attribute, as `_readAttributeValue` does.
@available(System 199, *)
internal func _readAttributeSize(
  retryOnInterrupt: Bool, _ size: () -> Int
) -> Result<Int?, Errno> {
  switch valueOrErrno(retryOnInterrupt: retryOnInterrupt, size) {
  case .success(let count): return .success(count)
  case .failure(let error):
    return error == .attributeNotFound ? .success(nil) : .failure(error)
  }
}

/// The bytes that `_readAttributeValue` and `_readAttributeNames` ask for
/// beyond the size, which FreeBSD's calls truncate a growing value to.
internal var _attributeSpareByteCount: Int {
  #if os(FreeBSD)
  return 1
  #else
  return 0
  #endif
}

/// Reads the attribute names that `list` writes, as `_readAttributeValue`
/// reads a value: null-separated, or on FreeBSD each after a length byte.
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
    var names = [CChar](repeating: 0, count: size + _attributeSpareByteCount)
    let result = names.withUnsafeMutableBufferPointer { buffer in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) { list(buffer.baseAddress, buffer.count) }
    }
    switch result {
    case .success(let count):
      if _attributeSpareByteCount > 0 && count == names.count { continue }
      let bytes = names.prefix(count).map { UInt8(bitPattern: $0) }
      #if os(FreeBSD)
      return .success(_attributeNames(lengthPrefixed: bytes))
      #else
      return .success(_attributeNames(nullSeparated: bytes))
      #endif
    case .failure(.outOfRange):
      continue
    case .failure(let error):
      return .failure(error)
    }
  }
}

/// The names in a list that listxattr wrote, null-separated.
internal func _attributeNames(nullSeparated bytes: [UInt8]) -> [String] {
  bytes.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
}

/// The names in a list that FreeBSD's extattr_list wrote: each after a byte
/// that gives its length, without a terminator. Built everywhere, so that
/// the tests can check it.
internal func _attributeNames(lengthPrefixed bytes: [UInt8]) -> [String] {
  var names: [String] = []
  var index = 0
  while index < bytes.count {
    let end = min(index + 1 + Int(bytes[index]), bytes.count)
    names.append(String(decoding: bytes[(index + 1)..<end], as: UTF8.self))
    index = end
  }
  return names
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
