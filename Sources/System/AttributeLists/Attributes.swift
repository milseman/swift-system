/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A file system object's attribute values, parsed from the buffer that
// getattrlist or getattrlistbulk fills.
//
// The buffer holds only the attributes that the object's volume supports,
// packed one after another, so an attribute's place depends on which
// others came before it. Every request asks for ATTR_CMN_RETURNED_ATTRS,
// which says which ones did, and the values are found from that and each
// attribute's size.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@available(System 199, *)
extension FilePath {
  /// The attributes of a file system object,
  /// as ``FilePath/attributes(_:options:retryOnInterrupt:)`` reads them.
  ///
  /// An attribute that the object's volume doesn't support is missing,
  /// and its value is `nil`.
  /// The common attributes have properties of their own, such as
  /// ``fullPath``;
  /// read any attribute's value with ``value(of:as:)``,
  /// ``string(of:)``, or ``bytes(of:)``:
  ///
  ///     let attributes = try path.attributes([.fullPath, .creationTime])
  ///     let created = attributes.value(of: .creationTime, as: timespec.self)
  ///
  /// - Note: Only available on Darwin.
  public struct Attributes: Sendable {
    // The object's part of the buffer, from its length field on.
    internal var _bytes: [UInt8]

    // Where each returned attribute's value starts in `_bytes`.
    internal var _offsets: [Attribute: Int]
  }
}

// MARK: - Reading values

@available(System 199, *)
extension FilePath.Attributes {
  /// Returns whether the object has the attribute:
  /// whether it was requested, and its volume supports it.
  public func contains(_ attribute: FilePath.Attribute) -> Bool {
    _offsets[attribute] != nil
  }

  /// Returns the value of an attribute of a fixed size.
  ///
  /// - Parameters:
  ///   - attribute: The attribute.
  ///   - type: The attribute's C type, such as `timespec`
  ///     for ``FilePath/Attribute/creationTime``.
  /// - Returns: The attribute's value,
  ///   or `nil` if the object doesn't have it,
  ///   or if its value is an `attrreference_t` to data of varying size,
  ///   which ``bytes(of:)`` and ``string(of:)`` read instead.
  ///
  /// - Precondition: `type` is the attribute's size.
  public func value<T: BitwiseCopyable>(
    of attribute: FilePath.Attribute, as type: T.Type = T.self
  ) -> T? {
    guard let offset = _offsets[attribute], let layout = attribute._layout,
      !layout.isReference
    else {
      return nil
    }
    precondition(
      MemoryLayout<T>.size == layout.size,
      "The attribute's value is \(layout.size) bytes, not \(MemoryLayout<T>.size)")
    guard offset + layout.size <= _bytes.count else { return nil }
    return _bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
  }

  /// Returns the bytes of an attribute's value.
  ///
  /// - Parameter attribute: The attribute.
  /// - Returns: The bytes of the attribute's value:
  ///   for an attribute of varying size, such as ``FilePath/Attribute/name``,
  ///   the data that its `attrreference_t` refers to;
  ///   or `nil` if the object doesn't have the attribute.
  public func bytes(of attribute: FilePath.Attribute) -> [UInt8]? {
    guard let offset = _offsets[attribute], let layout = attribute._layout,
      offset + layout.size <= _bytes.count
    else {
      return nil
    }
    guard layout.isReference else { return Array(_bytes[offset..<(offset + layout.size)]) }
    return _bytes.withUnsafeBytes { buffer -> [UInt8]? in
      let reference = buffer.loadUnaligned(fromByteOffset: offset, as: attrreference_t.self)
      let start = offset + Int(reference.attr_dataoffset)
      let end = start + Int(reference.attr_length)
      // A truncated buffer can refer past its end.
      guard start >= 0, start <= end, end <= buffer.count else { return nil }
      return Array(buffer[start..<end])
    }
  }

  /// Returns the value of an attribute that holds a string,
  /// such as ``FilePath/Attribute/name``.
  ///
  /// - Parameter attribute: The attribute.
  /// - Returns: The string, without its null terminator,
  ///   or `nil` if the object doesn't have the attribute.
  ///
  /// Bytes that aren't valid UTF-8 are repaired,
  /// as `String(decoding:as:)` does.
  public func string(of attribute: FilePath.Attribute) -> String? {
    bytes(of: attribute).map { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
  }

  /// Returns the value of an attribute that holds a path,
  /// such as ``FilePath/Attribute/fullPath``.
  ///
  /// - Parameter attribute: The attribute.
  /// - Returns: The path, or `nil` if the object doesn't have the attribute.
  public func path(of attribute: FilePath.Attribute) -> FilePath? {
    bytes(of: attribute).map { bytes in
      FilePath(
        platformString: bytes.prefix { $0 != 0 }.map { CInterop.PlatformChar(bitPattern: $0) }
          + [0])
    }
  }
}

// MARK: - Common values

@available(System 199, *)
extension FilePath.Attributes {
  /// The object's name.
  ///
  /// The corresponding C constant is `ATTR_CMN_NAME`.
  public var name: String? { string(of: .name) }

  /// The object's absolute path, with symbolic links resolved.
  ///
  /// The corresponding C constant is `ATTR_CMN_FULLPATH`.
  public var fullPath: FilePath? { path(of: .fullPath) }

  /// The object's type, or `nil` if the object doesn't have the attribute
  /// or is of a type that ``FileType`` doesn't name.
  ///
  /// The corresponding C constant is `ATTR_CMN_OBJTYPE`.
  public var objectType: FileType? {
    switch value(of: .objectType, as: UInt32.self) {
    case _VREG: return .regular
    case _VDIR: return .directory
    case _VBLK: return .blockSpecial
    case _VCHR: return .characterSpecial
    case _VLNK: return .symbolicLink
    case _VSOCK: return .socket
    case _VFIFO: return .fifo
    default: return nil
    }
  }

  /// The device that holds the object's volume.
  ///
  /// The corresponding C constant is `ATTR_CMN_DEVID`.
  public var deviceID: DeviceID? {
    value(of: .deviceID, as: CInterop.DeviceID.self).map { DeviceID(rawValue: $0) }
  }

  /// The object's owner.
  ///
  /// The corresponding C constant is `ATTR_CMN_OWNERID`.
  public var owner: UserID? {
    value(of: .owner, as: CInterop.UserID.self).map { UserID(rawValue: $0) }
  }

  /// The object's group.
  ///
  /// The corresponding C constant is `ATTR_CMN_GRPID`.
  public var group: GroupID? {
    value(of: .group, as: CInterop.GroupID.self).map { GroupID(rawValue: $0) }
  }

  /// The object's permissions.
  ///
  /// The corresponding C constant is `ATTR_CMN_ACCESSMASK`.
  public var permissions: FilePermissions? {
    value(of: .accessMask, as: UInt32.self).map {
      FilePermissions(rawValue: CInterop.Mode(truncatingIfNeeded: $0 & 0o7777))
    }
  }

  /// The object's flags, as ``FilePath/setFileFlags(_:retryOnInterrupt:)`` sets.
  ///
  /// The corresponding C constant is `ATTR_CMN_FLAGS`.
  public var flags: FileFlags? {
    value(of: .flags, as: UInt32.self).map { FileFlags(rawValue: $0) }
  }

  /// The object's file identifier, which `stat` reports as its inode.
  ///
  /// The corresponding C constant is `ATTR_CMN_FILEID`.
  public var fileID: Inode? {
    value(of: .fileID, as: UInt64.self).map { Inode(rawValue: CInterop.Inode($0)) }
  }

  /// The file identifier of the object's parent directory.
  ///
  /// The corresponding C constant is `ATTR_CMN_PARENTID`.
  public var parentID: Inode? {
    value(of: .parentID, as: UInt64.self).map { Inode(rawValue: CInterop.Inode($0)) }
  }

  /// The object's data protection class.
  ///
  /// The corresponding C constant is `ATTR_CMN_DATA_PROTECT_FLAGS`.
  public var dataProtectionClass: UInt32? { value(of: .dataProtectionClass) }

  /// The error that reading this directory entry's attributes encountered,
  /// or `nil` if there was none.
  ///
  /// Only ``FileDescriptor/readEntryAttributes(_:options:capacity:retryOnInterrupt:)``
  /// reports an error for an entry.
  ///
  /// The corresponding C constant is `ATTR_CMN_ERROR`.
  public var error: Errno? {
    guard let offset = _offsets[_errorAttribute], offset + 4 <= _bytes.count else { return nil }
    let error = _bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    return error == 0 ? nil : Errno(rawValue: CInt(bitPattern: error))
  }
}

// MARK: - Volume and file values

@available(System 199, *)
extension FilePath.Attributes {
  /// What the object's volume supports.
  ///
  /// The corresponding C constant is `ATTR_VOL_CAPABILITIES`.
  public var volumeCapabilities: FilePath.VolumeCapabilities? {
    value(of: .volumeCapabilities, as: vol_capabilities_attr_t.self).map {
      FilePath.VolumeCapabilities($0)
    }
  }

  /// The name of the volume's file system type, such as `apfs`.
  ///
  /// The corresponding C constant is `ATTR_VOL_FSTYPENAME`.
  public var volumeFileSystemTypeName: String? { string(of: .volumeFileSystemTypeName) }

  /// The volume's name.
  ///
  /// The corresponding C constant is `ATTR_VOL_NAME`.
  public var volumeName: String? { string(of: .volumeName) }

  /// The path where the volume is mounted.
  ///
  /// The corresponding C constant is `ATTR_VOL_MOUNTPOINT`.
  public var volumeMountPoint: FilePath? { path(of: .volumeMountPoint) }

  /// The number of entries in the directory, not counting `.` and `..`.
  ///
  /// The corresponding C constant is `ATTR_DIR_ENTRYCOUNT`.
  public var directoryEntryCount: Int? {
    value(of: .directoryEntryCount, as: UInt32.self).map { Int($0) }
  }

  /// The number of hard links to the file.
  ///
  /// The corresponding C constant is `ATTR_FILE_LINKCOUNT`.
  public var fileLinkCount: Int? { value(of: .fileLinkCount, as: UInt32.self).map { Int($0) } }

  /// The logical size of the file's data, in bytes.
  ///
  /// The corresponding C constant is `ATTR_FILE_DATALENGTH`.
  public var fileDataLength: Int64? { value(of: .fileDataLength) }

  /// The number of bytes allocated to the file.
  ///
  /// The corresponding C constant is `ATTR_FILE_ALLOCSIZE`.
  public var fileAllocatedSize: Int64? { value(of: .fileAllocatedSize) }

  /// A number that files which are clones of each other share.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_CLONEID`.
  public var cloneID: UInt64? { value(of: .cloneID) }

  /// The number of bytes of the object's data that no clone
  /// or snapshot shares.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_PRIVATESIZE`.
  public var privateSize: Int64? { value(of: .privateSize) }
}

// MARK: - Parsing

@available(System 199, *)
private var _errorAttribute: FilePath.Attribute {
  FilePath.Attribute(_group: 0, bit: _ATTR_CMN_ERROR)
}

@available(System 199, *)
extension FilePath.Attributes {
  // Parses one object's attributes: its length field, the attribute_set_t
  // of returned attributes, and the values in order. An attribute that the
  // layout table doesn't have ends the parsing, since the ones after it
  // can't be found; they're missing.
  internal init(_ bytes: UnsafeRawBufferPointer) {
    self._bytes = Array(bytes)
    self._offsets = [:]
    let header = MemoryLayout<UInt32>.size + MemoryLayout<attribute_set_t>.size
    guard bytes.count >= header else { return }
    var returned = (0..<Int(_ATTR_BIT_MAP_COUNT)).map {
      bytes.loadUnaligned(fromByteOffset: 4 + 4 * $0, as: UInt32.self)
    }
    // These have no values of their own in the list.
    returned[0] &= ~_ATTR_CMN_RETURNED_ATTRS
    returned[1] &= ~_ATTR_VOL_INFO
    var offset = header
    // ATTR_CMN_ERROR comes right after the returned attributes.
    if returned[0] & _ATTR_CMN_ERROR != 0 {
      _offsets[_errorAttribute] = offset
      offset += 4
      returned[0] &= ~_ATTR_CMN_ERROR
    }
    for (group, layouts) in _attributeLayouts.enumerated() {
      var remaining = returned[group]
      for layout in layouts where remaining & layout.bit != 0 {
        _offsets[FilePath.Attribute(_group: UInt8(group), bit: layout.bit)] = offset
        offset += layout.size
        remaining &= ~layout.bit
      }
      guard remaining == 0 else { return }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
