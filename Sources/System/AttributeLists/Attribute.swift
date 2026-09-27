/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The attributes that getattrlist, fgetattrlist, getattrlistat, and
// getattrlistbulk can return, and the layout of each in the buffer they
// fill.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: - Attributes

@available(System 199, *)
extension FilePath {
  /// A file system attribute: a piece of a file system object's metadata
  /// that ``FilePath/attributes(_:options:)`` can get.
  ///
  /// Attributes come in groups, as the C API divides them:
  /// common attributes, which any object has,
  /// such as ``name`` and ``fullPath``;
  /// volume attributes, which describe the volume the object is on,
  /// such as ``volumeCapabilities``;
  /// directory attributes and file attributes,
  /// which only a directory or a file has;
  /// and extended common attributes, such as ``cloneID``.
  /// A request can't mix volume attributes
  /// with directory, file, or extended common attributes,
  /// or with some common attributes, such as ``fileID``;
  /// one that does throws ``Errno/invalidArgument``.
  ///
  /// Not every volume supports every attribute.
  /// The values that an object's ``FilePath/Attributes`` holds
  /// are the ones its volume supports.
  ///
  /// The corresponding C type is `attrgroup_t`, one bit of one group
  /// of `struct attrlist`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Attribute: Hashable, Sendable {
    // The index of the attribute's group in `struct attrlist` and
    // `attribute_set_t`: common, volume, directory, file, and fork, which
    // the extended common attributes use.
    @usableFromInline
    internal var _group: UInt8

    // The attribute's bit in its group.
    @usableFromInline
    internal var _bit: UInt32

    @_alwaysEmitIntoClient
    internal init(_group: UInt8, bit: UInt32) {
      self._group = _group
      self._bit = bit
    }
  }
}

@available(System 199, *)
extension FilePath.Attribute {
  // MARK: Common attributes

  /// The object's name, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_CMN_NAME`.
  @_alwaysEmitIntoClient
  public static var name: Self { Self(_group: 0, bit: _ATTR_CMN_NAME) }

  /// The device that holds the object's volume: a `dev_t`, as `stat` reports in `st_dev`.
  ///
  /// The corresponding C constant is `ATTR_CMN_DEVID`.
  @_alwaysEmitIntoClient
  public static var deviceID: Self { Self(_group: 0, bit: _ATTR_CMN_DEVID) }

  /// The object's volume's file system identifier: an `fsid_t`, as `statfs` reports in `f_fsid`.
  ///
  /// The corresponding C constant is `ATTR_CMN_FSID`.
  @_alwaysEmitIntoClient
  public static var fileSystemID: Self { Self(_group: 0, bit: _ATTR_CMN_FSID) }

  /// The object's type: an `fsobj_type_t`, one of the `vtype` values, such as `VREG`.
  ///
  /// The corresponding C constant is `ATTR_CMN_OBJTYPE`.
  @_alwaysEmitIntoClient
  public static var objectType: Self { Self(_group: 0, bit: _ATTR_CMN_OBJTYPE) }

  /// The type of the object's file system: an `fsobj_tag_t`, one of the `vtagtype` values.
  ///
  /// The corresponding C constant is `ATTR_CMN_OBJTAG`.
  @_alwaysEmitIntoClient
  public static var objectTag: Self { Self(_group: 0, bit: _ATTR_CMN_OBJTAG) }

  /// An `fsobj_id_t` that identifies the object while its volume is mounted.
  ///
  /// The system deprecates this attribute in favor of ``linkID``.
  ///
  /// The corresponding C constant is `ATTR_CMN_OBJID`.
  @_alwaysEmitIntoClient
  public static var objectID: Self { Self(_group: 0, bit: _ATTR_CMN_OBJID) }

  /// An `fsobj_id_t` that identifies the object on its volume, across mounts.
  ///
  /// The corresponding C constant is `ATTR_CMN_OBJPERMANENTID`.
  @_alwaysEmitIntoClient
  public static var permanentObjectID: Self { Self(_group: 0, bit: _ATTR_CMN_OBJPERMANENTID) }

  /// An `fsobj_id_t` that identifies the object's parent directory while its volume is mounted.
  ///
  /// The corresponding C constant is `ATTR_CMN_PAROBJID`.
  @_alwaysEmitIntoClient
  public static var parentObjectID: Self { Self(_group: 0, bit: _ATTR_CMN_PAROBJID) }

  /// A `text_encoding_t` hint for the encoding of the object's name.
  ///
  /// The corresponding C constant is `ATTR_CMN_SCRIPT`.
  @_alwaysEmitIntoClient
  public static var script: Self { Self(_group: 0, bit: _ATTR_CMN_SCRIPT) }

  /// The time the object was created: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_CRTIME`.
  @_alwaysEmitIntoClient
  public static var creationTime: Self { Self(_group: 0, bit: _ATTR_CMN_CRTIME) }

  /// The time the object's data was last modified: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_MODTIME`.
  @_alwaysEmitIntoClient
  public static var modificationTime: Self { Self(_group: 0, bit: _ATTR_CMN_MODTIME) }

  /// The time the object's attributes were last changed: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_CHGTIME`.
  @_alwaysEmitIntoClient
  public static var changeTime: Self { Self(_group: 0, bit: _ATTR_CMN_CHGTIME) }

  /// The time the object was last accessed: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_ACCTIME`.
  @_alwaysEmitIntoClient
  public static var accessTime: Self { Self(_group: 0, bit: _ATTR_CMN_ACCTIME) }

  /// The time the object was last backed up: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_BKUPTIME`.
  @_alwaysEmitIntoClient
  public static var backupTime: Self { Self(_group: 0, bit: _ATTR_CMN_BKUPTIME) }

  /// The object's 32 bytes of Finder information.
  ///
  /// The corresponding C constant is `ATTR_CMN_FNDRINFO`.
  @_alwaysEmitIntoClient
  public static var finderInfo: Self { Self(_group: 0, bit: _ATTR_CMN_FNDRINFO) }

  /// The object's owner: a `uid_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_OWNERID`.
  @_alwaysEmitIntoClient
  public static var owner: Self { Self(_group: 0, bit: _ATTR_CMN_OWNERID) }

  /// The object's group: a `gid_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_GRPID`.
  @_alwaysEmitIntoClient
  public static var group: Self { Self(_group: 0, bit: _ATTR_CMN_GRPID) }

  /// The object's type and permission bits, as `stat` reports in `st_mode`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_ACCESSMASK`.
  @_alwaysEmitIntoClient
  public static var accessMask: Self { Self(_group: 0, bit: _ATTR_CMN_ACCESSMASK) }

  /// The object's flags, as `chflags` sets: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_FLAGS`.
  @_alwaysEmitIntoClient
  public static var flags: Self { Self(_group: 0, bit: _ATTR_CMN_FLAGS) }

  /// A `u_int32_t` that increases each time the object is modified, or 0 if the file system doesn't count.
  ///
  /// The corresponding C constant is `ATTR_CMN_GEN_COUNT`.
  @_alwaysEmitIntoClient
  public static var generationCount: Self { Self(_group: 0, bit: _ATTR_CMN_GEN_COUNT) }

  /// The object's document identifier, which follows the document across safe saves: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_DOCUMENT_ID`.
  @_alwaysEmitIntoClient
  public static var documentID: Self { Self(_group: 0, bit: _ATTR_CMN_DOCUMENT_ID) }

  /// The process's effective permissions for the object, as a `u_int32_t` of `R_OK`, `W_OK`, and `X_OK`.
  ///
  /// The corresponding C constant is `ATTR_CMN_USERACCESS`.
  @_alwaysEmitIntoClient
  public static var userAccess: Self { Self(_group: 0, bit: _ATTR_CMN_USERACCESS) }

  /// The object's access control list, as a `kauth_filesec` structure.
  ///
  /// The corresponding C constant is `ATTR_CMN_EXTENDED_SECURITY`.
  @_alwaysEmitIntoClient
  public static var extendedSecurity: Self { Self(_group: 0, bit: _ATTR_CMN_EXTENDED_SECURITY) }

  /// The UUID of the object's owner: a `guid_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_UUID`.
  @_alwaysEmitIntoClient
  public static var ownerUUID: Self { Self(_group: 0, bit: _ATTR_CMN_UUID) }

  /// The UUID of the object's group: a `guid_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_GRPUUID`.
  @_alwaysEmitIntoClient
  public static var groupUUID: Self { Self(_group: 0, bit: _ATTR_CMN_GRPUUID) }

  /// The object's 64-bit file identifier, as `stat` reports in `st_ino`: a `u_int64_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_FILEID`.
  @_alwaysEmitIntoClient
  public static var fileID: Self { Self(_group: 0, bit: _ATTR_CMN_FILEID) }

  /// The file identifier of the object's parent directory: a `u_int64_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_PARENTID`.
  @_alwaysEmitIntoClient
  public static var parentID: Self { Self(_group: 0, bit: _ATTR_CMN_PARENTID) }

  /// The object's absolute path, with symbolic links resolved, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_CMN_FULLPATH`.
  @_alwaysEmitIntoClient
  public static var fullPath: Self { Self(_group: 0, bit: _ATTR_CMN_FULLPATH) }

  /// The time the object was added to its parent directory: a `timespec`.
  ///
  /// The corresponding C constant is `ATTR_CMN_ADDEDTIME`.
  @_alwaysEmitIntoClient
  public static var addedTime: Self { Self(_group: 0, bit: _ATTR_CMN_ADDEDTIME) }

  /// The object's data protection class: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_CMN_DATA_PROTECT_FLAGS`.
  @_alwaysEmitIntoClient
  public static var dataProtectionClass: Self { Self(_group: 0, bit: _ATTR_CMN_DATA_PROTECT_FLAGS) }

  // MARK: Volume attributes

  /// The volume's file system type number, as `statfs` reports in `f_type`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_FSTYPE`.
  @_alwaysEmitIntoClient
  public static var volumeFileSystemType: Self { Self(_group: 1, bit: _ATTR_VOL_FSTYPE) }

  /// The volume's signature: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_SIGNATURE`.
  @_alwaysEmitIntoClient
  public static var volumeSignature: Self { Self(_group: 1, bit: _ATTR_VOL_SIGNATURE) }

  /// The volume's size in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_SIZE`.
  @_alwaysEmitIntoClient
  public static var volumeSize: Self { Self(_group: 1, bit: _ATTR_VOL_SIZE) }

  /// The number of free bytes on the volume: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_SPACEFREE`.
  @_alwaysEmitIntoClient
  public static var volumeFreeSpace: Self { Self(_group: 1, bit: _ATTR_VOL_SPACEFREE) }

  /// The number of bytes available to the process on the volume: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_SPACEAVAIL`.
  @_alwaysEmitIntoClient
  public static var volumeAvailableSpace: Self { Self(_group: 1, bit: _ATTR_VOL_SPACEAVAIL) }

  /// The number of bytes the volume uses, which differs from its size less its free space where volumes share space: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_SPACEUSED`.
  @_alwaysEmitIntoClient
  public static var volumeUsedSpace: Self { Self(_group: 1, bit: _ATTR_VOL_SPACEUSED) }

  /// The volume's smallest allocation, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_MINALLOCATION`.
  @_alwaysEmitIntoClient
  public static var volumeMinimumAllocation: Self { Self(_group: 1, bit: _ATTR_VOL_MINALLOCATION) }

  /// The volume's allocation clump size, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_ALLOCATIONCLUMP`.
  @_alwaysEmitIntoClient
  public static var volumeAllocationClump: Self { Self(_group: 1, bit: _ATTR_VOL_ALLOCATIONCLUMP) }

  /// The volume's optimal I/O size, in bytes: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_IOBLOCKSIZE`.
  @_alwaysEmitIntoClient
  public static var volumeIOBlockSize: Self { Self(_group: 1, bit: _ATTR_VOL_IOBLOCKSIZE) }

  /// The number of files and directories on the volume: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_OBJCOUNT`.
  @_alwaysEmitIntoClient
  public static var volumeObjectCount: Self { Self(_group: 1, bit: _ATTR_VOL_OBJCOUNT) }

  /// The number of files on the volume: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_FILECOUNT`.
  @_alwaysEmitIntoClient
  public static var volumeFileCount: Self { Self(_group: 1, bit: _ATTR_VOL_FILECOUNT) }

  /// The number of directories on the volume: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_DIRCOUNT`.
  @_alwaysEmitIntoClient
  public static var volumeDirectoryCount: Self { Self(_group: 1, bit: _ATTR_VOL_DIRCOUNT) }

  /// The most files and directories the volume can hold: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_MAXOBJCOUNT`.
  @_alwaysEmitIntoClient
  public static var volumeMaxObjectCount: Self { Self(_group: 1, bit: _ATTR_VOL_MAXOBJCOUNT) }

  /// The path where the volume is mounted, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_VOL_MOUNTPOINT`.
  @_alwaysEmitIntoClient
  public static var volumeMountPoint: Self { Self(_group: 1, bit: _ATTR_VOL_MOUNTPOINT) }

  /// The volume's name, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_VOL_NAME`.
  @_alwaysEmitIntoClient
  public static var volumeName: Self { Self(_group: 1, bit: _ATTR_VOL_NAME) }

  /// The volume's mount flags, as `statfs` reports in `f_flags`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_MOUNTFLAGS`.
  @_alwaysEmitIntoClient
  public static var volumeMountFlags: Self { Self(_group: 1, bit: _ATTR_VOL_MOUNTFLAGS) }

  /// The device the volume is mounted from, as `statfs` reports in `f_mntfromname`, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_VOL_MOUNTEDDEVICE`.
  @_alwaysEmitIntoClient
  public static var volumeMountedDevice: Self { Self(_group: 1, bit: _ATTR_VOL_MOUNTEDDEVICE) }

  /// A bitmap of the text encodings used on the volume: an `unsigned long long`.
  ///
  /// The corresponding C constant is `ATTR_VOL_ENCODINGSUSED`.
  @_alwaysEmitIntoClient
  public static var volumeEncodingsUsed: Self { Self(_group: 1, bit: _ATTR_VOL_ENCODINGSUSED) }

  /// What the volume's format and implementation support: a `vol_capabilities_attr_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_CAPABILITIES`.
  @_alwaysEmitIntoClient
  public static var volumeCapabilities: Self { Self(_group: 1, bit: _ATTR_VOL_CAPABILITIES) }

  /// The volume's UUID: a `uuid_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_UUID`.
  @_alwaysEmitIntoClient
  public static var volumeUUID: Self { Self(_group: 1, bit: _ATTR_VOL_UUID) }

  /// The volume's extended mount flags, as `statfs` reports in `f_flags_ext`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_MOUNTEXTFLAGS`.
  @_alwaysEmitIntoClient
  public static var volumeMountExtendedFlags: Self { Self(_group: 1, bit: _ATTR_VOL_MOUNTEXTFLAGS) }

  /// The most bytes the volume can grow to: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_QUOTA_SIZE`.
  @_alwaysEmitIntoClient
  public static var volumeQuotaSize: Self { Self(_group: 1, bit: _ATTR_VOL_QUOTA_SIZE) }

  /// The number of bytes reserved for the volume: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_RESERVED_SIZE`.
  @_alwaysEmitIntoClient
  public static var volumeReservedSize: Self { Self(_group: 1, bit: _ATTR_VOL_RESERVED_SIZE) }

  /// The attributes the volume supports: a `vol_attributes_attr_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_ATTRIBUTES`.
  @_alwaysEmitIntoClient
  public static var volumeAttributes: Self { Self(_group: 1, bit: _ATTR_VOL_ATTRIBUTES) }

  /// The volume's file system type name, such as `apfs`, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_VOL_FSTYPENAME`.
  @_alwaysEmitIntoClient
  public static var volumeFileSystemTypeName: Self { Self(_group: 1, bit: _ATTR_VOL_FSTYPENAME) }

  /// The volume's file system subtype: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_FSSUBTYPE`.
  @_alwaysEmitIntoClient
  public static var volumeFileSystemSubtype: Self { Self(_group: 1, bit: _ATTR_VOL_FSSUBTYPE) }

  #if canImport(Darwin, _version: 346)
  /// The user that mounted the volume, as `statfs` reports in `f_owner`: a `uid_t`.
  ///
  /// The corresponding C constant is `ATTR_VOL_OWNER`.
  /// - Note: Only available when building with the macOS 26 SDK or later.
  @_alwaysEmitIntoClient
  public static var volumeOwner: Self { Self(_group: 1, bit: _ATTR_VOL_OWNER) }
  #endif

  // MARK: Directory attributes

  /// The number of hard links to the directory: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_DIR_LINKCOUNT`.
  @_alwaysEmitIntoClient
  public static var directoryLinkCount: Self { Self(_group: 2, bit: _ATTR_DIR_LINKCOUNT) }

  /// The number of entries in the directory, not counting `.` and `..`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_DIR_ENTRYCOUNT`.
  @_alwaysEmitIntoClient
  public static var directoryEntryCount: Self { Self(_group: 2, bit: _ATTR_DIR_ENTRYCOUNT) }

  /// Whether the directory is a mount point, as a `u_int32_t` of `DIR_MNTSTATUS_MNTPOINT` and `DIR_MNTSTATUS_TRIGGER`.
  ///
  /// The corresponding C constant is `ATTR_DIR_MOUNTSTATUS`.
  @_alwaysEmitIntoClient
  public static var directoryMountStatus: Self { Self(_group: 2, bit: _ATTR_DIR_MOUNTSTATUS) }

  /// The number of bytes allocated to the directory: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_DIR_ALLOCSIZE`.
  @_alwaysEmitIntoClient
  public static var directoryAllocatedSize: Self { Self(_group: 2, bit: _ATTR_DIR_ALLOCSIZE) }

  /// The directory's optimal I/O size, in bytes: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_DIR_IOBLOCKSIZE`.
  @_alwaysEmitIntoClient
  public static var directoryIOBlockSize: Self { Self(_group: 2, bit: _ATTR_DIR_IOBLOCKSIZE) }

  /// The logical size of the directory, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_DIR_DATALENGTH`.
  @_alwaysEmitIntoClient
  public static var directoryDataLength: Self { Self(_group: 2, bit: _ATTR_DIR_DATALENGTH) }

  // MARK: File attributes

  /// The number of hard links to the file: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_LINKCOUNT`.
  @_alwaysEmitIntoClient
  public static var fileLinkCount: Self { Self(_group: 3, bit: _ATTR_FILE_LINKCOUNT) }

  /// The logical size of all of the file's forks, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_TOTALSIZE`.
  @_alwaysEmitIntoClient
  public static var fileTotalSize: Self { Self(_group: 3, bit: _ATTR_FILE_TOTALSIZE) }

  /// The number of bytes allocated to all of the file's forks: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_ALLOCSIZE`.
  @_alwaysEmitIntoClient
  public static var fileAllocatedSize: Self { Self(_group: 3, bit: _ATTR_FILE_ALLOCSIZE) }

  /// The file's optimal I/O size, in bytes: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_IOBLOCKSIZE`.
  @_alwaysEmitIntoClient
  public static var fileIOBlockSize: Self { Self(_group: 3, bit: _ATTR_FILE_IOBLOCKSIZE) }

  /// For a device, its device number, as `stat` reports in `st_rdev`: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_DEVTYPE`.
  @_alwaysEmitIntoClient
  public static var fileDeviceType: Self { Self(_group: 3, bit: _ATTR_FILE_DEVTYPE) }

  /// The logical size of the file's data fork, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_DATALENGTH`.
  @_alwaysEmitIntoClient
  public static var fileDataLength: Self { Self(_group: 3, bit: _ATTR_FILE_DATALENGTH) }

  /// The number of bytes allocated to the file's data fork: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_DATAALLOCSIZE`.
  @_alwaysEmitIntoClient
  public static var fileDataAllocatedSize: Self { Self(_group: 3, bit: _ATTR_FILE_DATAALLOCSIZE) }

  /// The logical size of the file's resource fork, in bytes: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_RSRCLENGTH`.
  @_alwaysEmitIntoClient
  public static var fileResourceForkLength: Self { Self(_group: 3, bit: _ATTR_FILE_RSRCLENGTH) }

  /// The number of bytes allocated to the file's resource fork: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_FILE_RSRCALLOCSIZE`.
  @_alwaysEmitIntoClient
  public static var fileResourceForkAllocatedSize: Self { Self(_group: 3, bit: _ATTR_FILE_RSRCALLOCSIZE) }

  // MARK: Extended common attributes

  /// The object's path relative to its volume's mount point, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_RELPATH`.
  @_alwaysEmitIntoClient
  public static var relativePath: Self { Self(_group: 4, bit: _ATTR_CMNEXT_RELPATH) }

  /// The number of bytes of the object's data that no clone or snapshot shares: an `off_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_PRIVATESIZE`.
  @_alwaysEmitIntoClient
  public static var privateSize: Self { Self(_group: 4, bit: _ATTR_CMNEXT_PRIVATESIZE) }

  /// A `u_int64_t` that identifies this hard link to the object on its volume.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_LINKID`.
  @_alwaysEmitIntoClient
  public static var linkID: Self { Self(_group: 4, bit: _ATTR_CMNEXT_LINKID) }

  /// The object's absolute path without firmlinks, as a null-terminated UTF-8 string.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_NOFIRMLINKPATH`.
  @_alwaysEmitIntoClient
  public static var noFirmlinkPath: Self { Self(_group: 4, bit: _ATTR_CMNEXT_NOFIRMLINKPATH) }

  /// The device of the object's physical volume, in a volume group: a `dev_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_REALDEVID`.
  @_alwaysEmitIntoClient
  public static var realDeviceID: Self { Self(_group: 4, bit: _ATTR_CMNEXT_REALDEVID) }

  /// The file system identifier of the object's physical volume, in a volume group: an `fsid_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_REALFSID`.
  @_alwaysEmitIntoClient
  public static var realFileSystemID: Self { Self(_group: 4, bit: _ATTR_CMNEXT_REALFSID) }

  /// A `u_int64_t` that files which are clones of each other share.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_CLONEID`.
  @_alwaysEmitIntoClient
  public static var cloneID: Self { Self(_group: 4, bit: _ATTR_CMNEXT_CLONEID) }

  /// The object's extended flags, such as `EF_MAY_SHARE_BLOCKS`: a `u_int64_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_EXT_FLAGS`.
  @_alwaysEmitIntoClient
  public static var extendedFlags: Self { Self(_group: 4, bit: _ATTR_CMNEXT_EXT_FLAGS) }

  /// A `u_int64_t` that increases each time the object or, for a directory, anything in it changes.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_RECURSIVE_GENCOUNT`.
  @_alwaysEmitIntoClient
  public static var recursiveGenerationCount: Self { Self(_group: 4, bit: _ATTR_CMNEXT_RECURSIVE_GENCOUNT) }

  /// The object's attribution tag: a `u_int64_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_ATTRIBUTION_TAG`.
  @_alwaysEmitIntoClient
  public static var attributionTag: Self { Self(_group: 4, bit: _ATTR_CMNEXT_ATTRIBUTION_TAG) }

  /// The number of clones that share the file's data: a `u_int32_t`.
  ///
  /// The corresponding C constant is `ATTR_CMNEXT_CLONE_REFCNT`.
  @_alwaysEmitIntoClient
  public static var cloneReferenceCount: Self { Self(_group: 4, bit: _ATTR_CMNEXT_CLONE_REFCNT) }
}

// MARK: - Options

@available(System 199, *)
extension FilePath {
  /// Options that change how attributes are read.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct AttributeOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates strongly-typed options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// If the path ends with a symbolic link, read the link's attributes.
    ///
    /// The corresponding C constant is `FSOPT_NOFOLLOW`.
    @_alwaysEmitIntoClient
    public static var noFollow: AttributeOptions { AttributeOptions(rawValue: _FSOPT_NOFOLLOW) }

    /// Read the link's attributes if the path ends with a symbolic link,
    /// and throw ``Errno/tooManySymbolicLinkLevels``
    /// if resolving it encounters one before its last component.
    ///
    /// The corresponding C constant is `FSOPT_NOFOLLOW_ANY`.
    @_alwaysEmitIntoClient
    public static var noFollowAny: AttributeOptions {
      AttributeOptions(rawValue: _FSOPT_NOFOLLOW_ANY)
    }

    /// Report the device and file system identifiers
    /// of the object's physical volume, rather than of its volume group.
    ///
    /// The corresponding C constant is `FSOPT_RETURN_REALDEV`.
    @_alwaysEmitIntoClient
    public static var returnRealDevice: AttributeOptions {
      AttributeOptions(rawValue: _FSOPT_RETURN_REALDEV)
    }
  }
}

// MARK: - Layout

// An attribute's place in the buffer: its size, and whether it's an
// attrreference_t to data elsewhere in the buffer.
internal struct _AttributeLayout {
  internal var bit: UInt32
  internal var size: Int
  internal var isReference: Bool
}

// Each group's attributes, in the order that the kernel packs them into
// the buffer, which is the order that getattrlist(2) describes them in.
// It isn't bit order: ATTR_VOL_SPACEUSED follows ATTR_VOL_SPACEAVAIL, and
// ATTR_VOL_QUOTA_SIZE, _RESERVED_SIZE and _ATTRIBUTES precede
// ATTR_VOL_FSTYPENAME. ATTR_CMN_RETURNED_ATTRS always comes first, and
// ATTR_CMN_ERROR second, so they aren't here. Every attribute is aligned to
// 4 bytes, which every size here is a multiple of.
internal let _attributeLayouts: [[_AttributeLayout]] = [
  // common
  [
    _AttributeLayout(bit: _ATTR_CMN_NAME, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_CMN_DEVID, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_FSID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_OBJTYPE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_OBJTAG, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_OBJID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_OBJPERMANENTID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_PAROBJID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_SCRIPT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_CRTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_MODTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_CHGTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_ACCTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_BKUPTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_FNDRINFO, size: 32, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_OWNERID, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_GRPID, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_ACCESSMASK, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_FLAGS, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_GEN_COUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_DOCUMENT_ID, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_USERACCESS, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_EXTENDED_SECURITY, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_CMN_UUID, size: 16, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_GRPUUID, size: 16, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_FILEID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_PARENTID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_FULLPATH, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_CMN_ADDEDTIME, size: MemoryLayout<timespec>.size, isReference: false),
    _AttributeLayout(bit: _ATTR_CMN_DATA_PROTECT_FLAGS, size: 4, isReference: false),
  ],
  // volume
  [
    _AttributeLayout(bit: _ATTR_VOL_FSTYPE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_SIGNATURE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_SIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_SPACEFREE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_SPACEAVAIL, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_SPACEUSED, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_MINALLOCATION, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_ALLOCATIONCLUMP, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_IOBLOCKSIZE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_OBJCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_FILECOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_DIRCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_MAXOBJCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_MOUNTPOINT, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_VOL_NAME, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_VOL_MOUNTFLAGS, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_MOUNTEDDEVICE, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_VOL_ENCODINGSUSED, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_CAPABILITIES, size: 32, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_UUID, size: 16, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_MOUNTEXTFLAGS, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_QUOTA_SIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_RESERVED_SIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_ATTRIBUTES, size: 40, isReference: false),
    _AttributeLayout(bit: _ATTR_VOL_FSTYPENAME, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_VOL_FSSUBTYPE, size: 4, isReference: false),
    // ATTR_VOL_OWNER, which the macOS 26 SDK added, is a uid_t.
    _AttributeLayout(bit: 0x0040_0000, size: 4, isReference: false),
  ],
  // directory
  [
    _AttributeLayout(bit: _ATTR_DIR_LINKCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_DIR_ENTRYCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_DIR_MOUNTSTATUS, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_DIR_ALLOCSIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_DIR_IOBLOCKSIZE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_DIR_DATALENGTH, size: 8, isReference: false),
  ],
  // file
  [
    _AttributeLayout(bit: _ATTR_FILE_LINKCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_TOTALSIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_ALLOCSIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_IOBLOCKSIZE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_CLUMPSIZE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_DEVTYPE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_FILETYPE, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_FORKCOUNT, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_FORKLIST, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_FILE_DATALENGTH, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_DATAALLOCSIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_DATAEXTENTS, size: 64, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_RSRCLENGTH, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_RSRCALLOCSIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_FILE_RSRCEXTENTS, size: 64, isReference: false),
  ],
  // extendedCommon
  [
    _AttributeLayout(bit: _ATTR_CMNEXT_RELPATH, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_CMNEXT_PRIVATESIZE, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_LINKID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_NOFIRMLINKPATH, size: 8, isReference: true),
    _AttributeLayout(bit: _ATTR_CMNEXT_REALDEVID, size: 4, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_REALFSID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_CLONEID, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_EXT_FLAGS, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_RECURSIVE_GENCOUNT, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_ATTRIBUTION_TAG, size: 8, isReference: false),
    _AttributeLayout(bit: _ATTR_CMNEXT_CLONE_REFCNT, size: 4, isReference: false),
  ],
]

@available(System 199, *)
extension FilePath.Attribute {
  // The attribute's layout, or nil if the layout table doesn't have it.
  internal var _layout: _AttributeLayout? {
    guard Int(_group) < _attributeLayouts.count else { return nil }
    return _attributeLayouts[Int(_group)].first { $0.bit == _bit }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
