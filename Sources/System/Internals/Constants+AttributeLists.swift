/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/
// The attribute list constants: getattrlist's attributes, options, and
// volume capabilities, and the vnode types it reports.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
// MARK: Attributes
@_alwaysEmitIntoClient
internal var _ATTR_BIT_MAP_COUNT: UInt32 { UInt32(ATTR_BIT_MAP_COUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_RETURNED_ATTRS: UInt32 { UInt32(ATTR_CMN_RETURNED_ATTRS) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_ERROR: UInt32 { UInt32(ATTR_CMN_ERROR) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_INFO: UInt32 { UInt32(ATTR_VOL_INFO) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_NAME: UInt32 { UInt32(ATTR_CMN_NAME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_DEVID: UInt32 { UInt32(ATTR_CMN_DEVID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_FSID: UInt32 { UInt32(ATTR_CMN_FSID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_OBJTYPE: UInt32 { UInt32(ATTR_CMN_OBJTYPE) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_OBJTAG: UInt32 { UInt32(ATTR_CMN_OBJTAG) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_OBJID: UInt32 { UInt32(ATTR_CMN_OBJID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_OBJPERMANENTID: UInt32 { UInt32(ATTR_CMN_OBJPERMANENTID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_PAROBJID: UInt32 { UInt32(ATTR_CMN_PAROBJID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_SCRIPT: UInt32 { UInt32(ATTR_CMN_SCRIPT) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_CRTIME: UInt32 { UInt32(ATTR_CMN_CRTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_MODTIME: UInt32 { UInt32(ATTR_CMN_MODTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_CHGTIME: UInt32 { UInt32(ATTR_CMN_CHGTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_ACCTIME: UInt32 { UInt32(ATTR_CMN_ACCTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_BKUPTIME: UInt32 { UInt32(ATTR_CMN_BKUPTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_FNDRINFO: UInt32 { UInt32(ATTR_CMN_FNDRINFO) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_OWNERID: UInt32 { UInt32(ATTR_CMN_OWNERID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_GRPID: UInt32 { UInt32(ATTR_CMN_GRPID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_ACCESSMASK: UInt32 { UInt32(ATTR_CMN_ACCESSMASK) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_FLAGS: UInt32 { UInt32(ATTR_CMN_FLAGS) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_GEN_COUNT: UInt32 { UInt32(ATTR_CMN_GEN_COUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_DOCUMENT_ID: UInt32 { UInt32(ATTR_CMN_DOCUMENT_ID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_USERACCESS: UInt32 { UInt32(ATTR_CMN_USERACCESS) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_EXTENDED_SECURITY: UInt32 { UInt32(ATTR_CMN_EXTENDED_SECURITY) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_UUID: UInt32 { UInt32(ATTR_CMN_UUID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_GRPUUID: UInt32 { UInt32(ATTR_CMN_GRPUUID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_FILEID: UInt32 { UInt32(ATTR_CMN_FILEID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_PARENTID: UInt32 { UInt32(ATTR_CMN_PARENTID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_FULLPATH: UInt32 { UInt32(ATTR_CMN_FULLPATH) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_ADDEDTIME: UInt32 { UInt32(ATTR_CMN_ADDEDTIME) }

@_alwaysEmitIntoClient
internal var _ATTR_CMN_DATA_PROTECT_FLAGS: UInt32 { UInt32(ATTR_CMN_DATA_PROTECT_FLAGS) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_FSTYPE: UInt32 { UInt32(ATTR_VOL_FSTYPE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_SIGNATURE: UInt32 { UInt32(ATTR_VOL_SIGNATURE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_SIZE: UInt32 { UInt32(ATTR_VOL_SIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_SPACEFREE: UInt32 { UInt32(ATTR_VOL_SPACEFREE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_SPACEAVAIL: UInt32 { UInt32(ATTR_VOL_SPACEAVAIL) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_SPACEUSED: UInt32 { UInt32(ATTR_VOL_SPACEUSED) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MINALLOCATION: UInt32 { UInt32(ATTR_VOL_MINALLOCATION) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_ALLOCATIONCLUMP: UInt32 { UInt32(ATTR_VOL_ALLOCATIONCLUMP) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_IOBLOCKSIZE: UInt32 { UInt32(ATTR_VOL_IOBLOCKSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_OBJCOUNT: UInt32 { UInt32(ATTR_VOL_OBJCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_FILECOUNT: UInt32 { UInt32(ATTR_VOL_FILECOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_DIRCOUNT: UInt32 { UInt32(ATTR_VOL_DIRCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MAXOBJCOUNT: UInt32 { UInt32(ATTR_VOL_MAXOBJCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MOUNTPOINT: UInt32 { UInt32(ATTR_VOL_MOUNTPOINT) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_NAME: UInt32 { UInt32(ATTR_VOL_NAME) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MOUNTFLAGS: UInt32 { UInt32(ATTR_VOL_MOUNTFLAGS) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MOUNTEDDEVICE: UInt32 { UInt32(ATTR_VOL_MOUNTEDDEVICE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_ENCODINGSUSED: UInt32 { UInt32(ATTR_VOL_ENCODINGSUSED) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_CAPABILITIES: UInt32 { UInt32(ATTR_VOL_CAPABILITIES) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_UUID: UInt32 { UInt32(ATTR_VOL_UUID) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_MOUNTEXTFLAGS: UInt32 { UInt32(ATTR_VOL_MOUNTEXTFLAGS) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_QUOTA_SIZE: UInt32 { UInt32(ATTR_VOL_QUOTA_SIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_RESERVED_SIZE: UInt32 { UInt32(ATTR_VOL_RESERVED_SIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_ATTRIBUTES: UInt32 { UInt32(ATTR_VOL_ATTRIBUTES) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_FSTYPENAME: UInt32 { UInt32(ATTR_VOL_FSTYPENAME) }

@_alwaysEmitIntoClient
internal var _ATTR_VOL_FSSUBTYPE: UInt32 { UInt32(ATTR_VOL_FSSUBTYPE) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_LINKCOUNT: UInt32 { UInt32(ATTR_DIR_LINKCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_ENTRYCOUNT: UInt32 { UInt32(ATTR_DIR_ENTRYCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_MOUNTSTATUS: UInt32 { UInt32(ATTR_DIR_MOUNTSTATUS) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_ALLOCSIZE: UInt32 { UInt32(ATTR_DIR_ALLOCSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_IOBLOCKSIZE: UInt32 { UInt32(ATTR_DIR_IOBLOCKSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_DIR_DATALENGTH: UInt32 { UInt32(ATTR_DIR_DATALENGTH) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_LINKCOUNT: UInt32 { UInt32(ATTR_FILE_LINKCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_TOTALSIZE: UInt32 { UInt32(ATTR_FILE_TOTALSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_ALLOCSIZE: UInt32 { UInt32(ATTR_FILE_ALLOCSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_IOBLOCKSIZE: UInt32 { UInt32(ATTR_FILE_IOBLOCKSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_CLUMPSIZE: UInt32 { UInt32(ATTR_FILE_CLUMPSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_DEVTYPE: UInt32 { UInt32(ATTR_FILE_DEVTYPE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_FILETYPE: UInt32 { UInt32(ATTR_FILE_FILETYPE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_FORKCOUNT: UInt32 { UInt32(ATTR_FILE_FORKCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_FORKLIST: UInt32 { UInt32(ATTR_FILE_FORKLIST) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_DATALENGTH: UInt32 { UInt32(ATTR_FILE_DATALENGTH) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_DATAALLOCSIZE: UInt32 { UInt32(ATTR_FILE_DATAALLOCSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_DATAEXTENTS: UInt32 { UInt32(ATTR_FILE_DATAEXTENTS) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_RSRCLENGTH: UInt32 { UInt32(ATTR_FILE_RSRCLENGTH) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_RSRCALLOCSIZE: UInt32 { UInt32(ATTR_FILE_RSRCALLOCSIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_FILE_RSRCEXTENTS: UInt32 { UInt32(ATTR_FILE_RSRCEXTENTS) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_RELPATH: UInt32 { UInt32(ATTR_CMNEXT_RELPATH) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_PRIVATESIZE: UInt32 { UInt32(ATTR_CMNEXT_PRIVATESIZE) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_LINKID: UInt32 { UInt32(ATTR_CMNEXT_LINKID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_NOFIRMLINKPATH: UInt32 { UInt32(ATTR_CMNEXT_NOFIRMLINKPATH) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_REALDEVID: UInt32 { UInt32(ATTR_CMNEXT_REALDEVID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_REALFSID: UInt32 { UInt32(ATTR_CMNEXT_REALFSID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_CLONEID: UInt32 { UInt32(ATTR_CMNEXT_CLONEID) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_EXT_FLAGS: UInt32 { UInt32(ATTR_CMNEXT_EXT_FLAGS) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_RECURSIVE_GENCOUNT: UInt32 { UInt32(ATTR_CMNEXT_RECURSIVE_GENCOUNT) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_ATTRIBUTION_TAG: UInt32 { UInt32(ATTR_CMNEXT_ATTRIBUTION_TAG) }

@_alwaysEmitIntoClient
internal var _ATTR_CMNEXT_CLONE_REFCNT: UInt32 { UInt32(ATTR_CMNEXT_CLONE_REFCNT) }
// The macOS 26 SDK added it.
#if canImport(Darwin, _version: 346)
@_alwaysEmitIntoClient
internal var _ATTR_VOL_OWNER: UInt32 { UInt32(ATTR_VOL_OWNER) }
#endif

// MARK: Options
@_alwaysEmitIntoClient
internal var _FSOPT_NOFOLLOW: UInt32 { UInt32(FSOPT_NOFOLLOW) }

@_alwaysEmitIntoClient
internal var _FSOPT_REPORT_FULLSIZE: UInt32 { UInt32(FSOPT_REPORT_FULLSIZE) }

@_alwaysEmitIntoClient
internal var _FSOPT_PACK_INVAL_ATTRS: UInt32 { UInt32(FSOPT_PACK_INVAL_ATTRS) }

@_alwaysEmitIntoClient
internal var _FSOPT_ATTR_CMN_EXTENDED: UInt32 { UInt32(FSOPT_ATTR_CMN_EXTENDED) }

@_alwaysEmitIntoClient
internal var _FSOPT_RETURN_REALDEV: UInt32 { UInt32(FSOPT_RETURN_REALDEV) }

@_alwaysEmitIntoClient
internal var _FSOPT_NOFOLLOW_ANY: UInt32 { UInt32(FSOPT_NOFOLLOW_ANY) }

// MARK: Volume capabilities
@_alwaysEmitIntoClient
internal var _VOL_CAPABILITIES_FORMAT: Int { Int(VOL_CAPABILITIES_FORMAT) }

@_alwaysEmitIntoClient
internal var _VOL_CAPABILITIES_INTERFACES: Int { Int(VOL_CAPABILITIES_INTERFACES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_PERSISTENTOBJECTIDS: UInt32 { UInt32(VOL_CAP_FMT_PERSISTENTOBJECTIDS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_SYMBOLICLINKS: UInt32 { UInt32(VOL_CAP_FMT_SYMBOLICLINKS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_HARDLINKS: UInt32 { UInt32(VOL_CAP_FMT_HARDLINKS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_JOURNAL: UInt32 { UInt32(VOL_CAP_FMT_JOURNAL) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_JOURNAL_ACTIVE: UInt32 { UInt32(VOL_CAP_FMT_JOURNAL_ACTIVE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_NO_ROOT_TIMES: UInt32 { UInt32(VOL_CAP_FMT_NO_ROOT_TIMES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_SPARSE_FILES: UInt32 { UInt32(VOL_CAP_FMT_SPARSE_FILES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_ZERO_RUNS: UInt32 { UInt32(VOL_CAP_FMT_ZERO_RUNS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_CASE_SENSITIVE: UInt32 { UInt32(VOL_CAP_FMT_CASE_SENSITIVE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_CASE_PRESERVING: UInt32 { UInt32(VOL_CAP_FMT_CASE_PRESERVING) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_FAST_STATFS: UInt32 { UInt32(VOL_CAP_FMT_FAST_STATFS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_2TB_FILESIZE: UInt32 { UInt32(VOL_CAP_FMT_2TB_FILESIZE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_OPENDENYMODES: UInt32 { UInt32(VOL_CAP_FMT_OPENDENYMODES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_HIDDEN_FILES: UInt32 { UInt32(VOL_CAP_FMT_HIDDEN_FILES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_PATH_FROM_ID: UInt32 { UInt32(VOL_CAP_FMT_PATH_FROM_ID) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_NO_VOLUME_SIZES: UInt32 { UInt32(VOL_CAP_FMT_NO_VOLUME_SIZES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_DECMPFS_COMPRESSION: UInt32 { UInt32(VOL_CAP_FMT_DECMPFS_COMPRESSION) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_64BIT_OBJECT_IDS: UInt32 { UInt32(VOL_CAP_FMT_64BIT_OBJECT_IDS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_DIR_HARDLINKS: UInt32 { UInt32(VOL_CAP_FMT_DIR_HARDLINKS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_DOCUMENT_ID: UInt32 { UInt32(VOL_CAP_FMT_DOCUMENT_ID) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_WRITE_GENERATION_COUNT: UInt32 { UInt32(VOL_CAP_FMT_WRITE_GENERATION_COUNT) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_NO_IMMUTABLE_FILES: UInt32 { UInt32(VOL_CAP_FMT_NO_IMMUTABLE_FILES) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_NO_PERMISSIONS: UInt32 { UInt32(VOL_CAP_FMT_NO_PERMISSIONS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_SHARED_SPACE: UInt32 { UInt32(VOL_CAP_FMT_SHARED_SPACE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_VOL_GROUPS: UInt32 { UInt32(VOL_CAP_FMT_VOL_GROUPS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_SEALED: UInt32 { UInt32(VOL_CAP_FMT_SEALED) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_FMT_CLONE_MAPPING: UInt32 { UInt32(VOL_CAP_FMT_CLONE_MAPPING) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_SEARCHFS: UInt32 { UInt32(VOL_CAP_INT_SEARCHFS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_ATTRLIST: UInt32 { UInt32(VOL_CAP_INT_ATTRLIST) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_NFSEXPORT: UInt32 { UInt32(VOL_CAP_INT_NFSEXPORT) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_READDIRATTR: UInt32 { UInt32(VOL_CAP_INT_READDIRATTR) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_EXCHANGEDATA: UInt32 { UInt32(VOL_CAP_INT_EXCHANGEDATA) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_COPYFILE: UInt32 { UInt32(VOL_CAP_INT_COPYFILE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_ALLOCATE: UInt32 { UInt32(VOL_CAP_INT_ALLOCATE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_VOL_RENAME: UInt32 { UInt32(VOL_CAP_INT_VOL_RENAME) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_ADVLOCK: UInt32 { UInt32(VOL_CAP_INT_ADVLOCK) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_FLOCK: UInt32 { UInt32(VOL_CAP_INT_FLOCK) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_EXTENDED_SECURITY: UInt32 { UInt32(VOL_CAP_INT_EXTENDED_SECURITY) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_USERACCESS: UInt32 { UInt32(VOL_CAP_INT_USERACCESS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_MANLOCK: UInt32 { UInt32(VOL_CAP_INT_MANLOCK) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_NAMEDSTREAMS: UInt32 { UInt32(VOL_CAP_INT_NAMEDSTREAMS) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_EXTENDED_ATTR: UInt32 { UInt32(VOL_CAP_INT_EXTENDED_ATTR) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_CLONE: UInt32 { UInt32(VOL_CAP_INT_CLONE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_SNAPSHOT: UInt32 { UInt32(VOL_CAP_INT_SNAPSHOT) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_RENAME_SWAP: UInt32 { UInt32(VOL_CAP_INT_RENAME_SWAP) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_RENAME_EXCL: UInt32 { UInt32(VOL_CAP_INT_RENAME_EXCL) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_RENAME_OPENFAIL: UInt32 { UInt32(VOL_CAP_INT_RENAME_OPENFAIL) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_RENAME_SECLUDE: UInt32 { UInt32(VOL_CAP_INT_RENAME_SECLUDE) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_ATTRIBUTION_TAG: UInt32 { UInt32(VOL_CAP_INT_ATTRIBUTION_TAG) }

@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_PUNCHHOLE: UInt32 { UInt32(VOL_CAP_INT_PUNCHHOLE) }
// The macOS 26 SDK added it.
#if canImport(Darwin, _version: 346)
@_alwaysEmitIntoClient
internal var _VOL_CAP_INT_BARRIERFSYNC: UInt32 { UInt32(VOL_CAP_INT_BARRIERFSYNC) }
#endif

// MARK: Directory mount status
@_alwaysEmitIntoClient
internal var _DIR_MNTSTATUS_MNTPOINT: UInt32 { UInt32(DIR_MNTSTATUS_MNTPOINT) }

@_alwaysEmitIntoClient
internal var _DIR_MNTSTATUS_TRIGGER: UInt32 { UInt32(DIR_MNTSTATUS_TRIGGER) }

// MARK: Vnode types
@_alwaysEmitIntoClient
internal var _VNON: UInt32 { VNON.rawValue }

@_alwaysEmitIntoClient
internal var _VREG: UInt32 { VREG.rawValue }

@_alwaysEmitIntoClient
internal var _VDIR: UInt32 { VDIR.rawValue }

@_alwaysEmitIntoClient
internal var _VBLK: UInt32 { VBLK.rawValue }

@_alwaysEmitIntoClient
internal var _VCHR: UInt32 { VCHR.rawValue }

@_alwaysEmitIntoClient
internal var _VLNK: UInt32 { VLNK.rawValue }

@_alwaysEmitIntoClient
internal var _VSOCK: UInt32 { VSOCK.rawValue }

@_alwaysEmitIntoClient
internal var _VFIFO: UInt32 { VFIFO.rawValue }

@_alwaysEmitIntoClient
internal var _VBAD: UInt32 { VBAD.rawValue }

@_alwaysEmitIntoClient
internal var _VSTR: UInt32 { VSTR.rawValue }

@_alwaysEmitIntoClient
internal var _VCPLX: UInt32 { VCPLX.rawValue }

#endif // SYSTEM_PACKAGE_DARWIN
