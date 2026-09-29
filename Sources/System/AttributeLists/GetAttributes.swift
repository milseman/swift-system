/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Reading attributes: getattrlist and getattrlistat for paths, fgetattrlist
// for a file descriptor, and getattrlistbulk for a directory's entries.
//
// getattrlist silently truncates what doesn't fit in its buffer. Every
// request passes FSOPT_REPORT_FULLSIZE, so the length field says how much
// room the attributes need, and a request that didn't fit is made again
// with that much. Every request also passes FSOPT_ATTR_CMN_EXTENDED, which
// the extended common attributes and a few common ones need, and which
// changes nothing for the rest.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: - getattrlist, getattrlistat

@available(System 199, *)
extension FilePath {
  /// Returns attributes of the file system object at this path.
  ///
  /// - Parameters:
  ///   - attributes: The attributes to read.
  ///   - options: Options that change how the attributes are read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The object's attributes,
  ///   from which any that its volume doesn't support are missing.
  ///
  /// If the path ends with a symbolic link,
  /// this method reads the attributes of its target,
  /// unless `options` includes ``AttributeOptions/noFollow``.
  /// Reading the attributes doesn't require permission to read the object,
  /// only to search the directories on its path.
  /// Requesting volume attributes together with directory, file,
  /// or extended common attributes
  /// throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `getattrlist`.
  /// The corresponding C constant is `ATTR_BIT_MAP_COUNT`, the number of attribute groups it passes.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func attributes(
    _ attributes: [Attribute],
    options: AttributeOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Attributes {
    try withPlatformString {
      FilePath._attributes(
        $0, relativeTo: nil, attributes, options: options, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns attributes of the file system object at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the object.
  ///   - attributes: The attributes to read.
  ///   - options: Options that change how the attributes are read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The object's attributes,
  ///   from which any that its volume doesn't support are missing.
  ///
  /// If `path` ends with a symbolic link,
  /// this method reads the attributes of its target,
  /// unless `options` includes ``AttributeOptions/noFollow``.
  /// Requesting volume attributes together with directory, file,
  /// or extended common attributes
  /// throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `getattrlist`.
  /// The corresponding C constant is `ATTR_BIT_MAP_COUNT`, the number of attribute groups it passes.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func attributes(
    _ path: UnsafePointer<CChar>,
    _ attributes: [Attribute],
    options: AttributeOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Attributes {
    try _attributes(
      path, relativeTo: nil, attributes, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Returns attributes of the file system object at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - attributes: The attributes to read.
  ///   - options: Options that change how the attributes are read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The object's attributes,
  ///   from which any that its volume doesn't support are missing.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `getattrlistat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func attributes(
    relativeTo fd: FileDescriptor,
    _ attributes: [Attribute],
    options: AttributeOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Attributes {
    try withPlatformString {
      FilePath._attributes(
        $0, relativeTo: fd, attributes, options: options, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns attributes of the file system object at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the object.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - attributes: The attributes to read.
  ///   - options: Options that change how the attributes are read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The object's attributes,
  ///   from which any that its volume doesn't support are missing.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `getattrlistat`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func attributes(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    _ attributes: [Attribute],
    options: AttributeOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Attributes {
    try _attributes(
      path, relativeTo: fd, attributes, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  // Calls getattrlistat if `fd` is non-nil, and getattrlist otherwise.
  @usableFromInline
  internal static func _attributes(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor?,
    _ attributes: [Attribute],
    options: AttributeOptions,
    retryOnInterrupt: Bool
  ) -> Result<Attributes, Errno> {
    _readAttributes(attributes, options: options, retryOnInterrupt: retryOnInterrupt) {
      list, buffer, size, options in
      if let fd {
        return system_getattrlistat(fd.rawValue, path, list, buffer, size, UInt(options))
      }
      return system_getattrlist(path, list, buffer, size, options)
    }
  }
}

// MARK: - fgetattrlist, getattrlistbulk

@available(System 199, *)
extension FileDescriptor {
  /// Returns attributes of the file system object
  /// that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - attributes: The attributes to read.
  ///   - options: Options that change how the attributes are read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The object's attributes,
  ///   from which any that its volume doesn't support are missing.
  ///
  /// Requesting volume attributes together with directory, file,
  /// or extended common attributes
  /// throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `fgetattrlist`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func attributes(
    _ attributes: [FilePath.Attribute],
    options: FilePath.AttributeOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FilePath.Attributes {
    try _attributes(attributes, options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _attributes(
    _ attributes: [FilePath.Attribute],
    options: FilePath.AttributeOptions,
    retryOnInterrupt: Bool
  ) -> Result<FilePath.Attributes, Errno> {
    _readAttributes(attributes, options: options, retryOnInterrupt: retryOnInterrupt) {
      list, buffer, size, options in
      system_fgetattrlist(self.rawValue, list, buffer, size, options)
    }
  }

  /// Reads attributes of the next entries in the directory
  /// that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - attributes: The attributes to read for each entry,
  ///     which can't include volume attributes.
  ///     Each entry's ``FilePath/Attributes/name`` is always read.
  ///   - options: Options that change how the attributes are read.
  ///   - capacity: The number of bytes to read the attributes into,
  ///     which limits how many entries one call returns.
  ///     The default is 64 KiB.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The attributes of the next entries,
  ///   in an order that depends on the file system,
  ///   or an empty array once every entry has been read.
  ///
  /// The file descriptor must be open for reading a directory.
  /// Call this method until it returns an empty array
  /// to read every entry;
  /// to read them again, seek the file descriptor back to its start.
  /// Don't mix calls with `readdir` on the same file descriptor.
  /// The attributes of a symbolic link are the link's own.
  /// An entry whose attributes the system couldn't read
  /// has an ``FilePath/Attributes/error``.
  ///
  /// The corresponding C function is `getattrlistbulk`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func readEntryAttributes(
    _ attributes: [FilePath.Attribute],
    options: FilePath.AttributeOptions = [],
    capacity: Int = 1 << 16,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> [FilePath.Attributes] {
    try _readEntryAttributes(
      attributes, options: options, capacity: capacity, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _readEntryAttributes(
    _ attributes: [FilePath.Attribute],
    options: FilePath.AttributeOptions,
    capacity: Int,
    retryOnInterrupt: Bool
  ) -> Result<[FilePath.Attributes], Errno> {
    // getattrlistbulk requires the name and the returned attributes, and
    // the error reports an entry whose attributes it couldn't read.
    var list = _attributeList(attributes, adding: _ATTR_CMN_NAME | _ATTR_CMN_ERROR)
    let options = UInt64(options.rawValue | _FSOPT_ATTR_CMN_EXTENDED)
    var buffer = [UInt8](repeating: 0, count: capacity)
    return buffer.withUnsafeMutableBytes { buffer in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_getattrlistbulk(self.rawValue, &list, buffer.baseAddress, buffer.count, options)
      }.map { count in
        // Each entry starts with its length, which includes any padding
        // before the next.
        var entries: [FilePath.Attributes] = []
        var offset = 0
        for _ in 0..<Int(count) {
          guard offset + 4 <= buffer.count else { break }
          let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
          guard length >= 4, offset + length <= buffer.count else { break }
          entries.append(
            FilePath.Attributes(UnsafeRawBufferPointer(rebasing: buffer[offset..<(offset + length)])))
          offset += length
        }
        return entries
      }
    }
  }
}

// MARK: - Requests

// The C list for a request: the attributes' groups, with the returned
// attributes, which the parsing needs, and ATTR_VOL_INFO, which any volume
// attribute needs.
@available(System 199, *)
internal func _attributeList(
  _ attributes: [FilePath.Attribute], adding common: UInt32 = 0
) -> attrlist {
  var groups = [UInt32](repeating: 0, count: Int(_ATTR_BIT_MAP_COUNT))
  for attribute in attributes where Int(attribute._group) < groups.count {
    groups[Int(attribute._group)] |= attribute._bit
  }
  groups[0] |= _ATTR_CMN_RETURNED_ATTRS | common
  if groups[1] != 0 { groups[1] |= _ATTR_VOL_INFO }
  var list = attrlist()
  list.bitmapcount = u_short(_ATTR_BIT_MAP_COUNT)
  list.commonattr = groups[0]
  list.volattr = groups[1]
  list.dirattr = groups[2]
  list.fileattr = groups[3]
  list.forkattr = groups[4]
  return list
}

// Calls `get` with a list for the request and a buffer, growing the buffer
// until the attributes fit.
@available(System 199, *)
internal func _readAttributes(
  _ attributes: [FilePath.Attribute],
  options: FilePath.AttributeOptions,
  retryOnInterrupt: Bool,
  _ get: (UnsafeMutablePointer<attrlist>, UnsafeMutableRawPointer, Int, UInt32) -> CInt
) -> Result<FilePath.Attributes, Errno> {
  var list = _attributeList(attributes)
  let options = options.rawValue | _FSOPT_ATTR_CMN_EXTENDED | _FSOPT_REPORT_FULLSIZE
  // Room for the fixed-size values, and for a path for each value of
  // varying size, which the full size corrects if it's too little.
  let layouts = attributes.compactMap { $0._layout }
  var capacity = 64 + layouts.reduce(0) {
    $0 + $1.size + ($1.isReference ? Int(MAXPATHLEN) : 0)
  }
  while true {
    var buffer = [UInt8](repeating: 0, count: capacity)
    let result = buffer.withUnsafeMutableBytes { buffer in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        get(&list, buffer.baseAddress!, buffer.count, options)
      }
    }
    if case .failure(let error) = result { return .failure(error) }
    let length = Int(buffer.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
    guard length <= capacity else {
      capacity = length
      continue
    }
    return .success(buffer.withUnsafeBytes {
      FilePath.Attributes(UnsafeRawBufferPointer(rebasing: $0[..<length]))
    })
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
