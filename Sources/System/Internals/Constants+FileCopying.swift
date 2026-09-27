/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The file copying and cloning constants: copyfile's flags, state fields,
// and callback values, and clonefile's options. Each is typed as the C
// argument that it goes in.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: copyfile flags

@_alwaysEmitIntoClient
internal var _COPYFILE_ACL: UInt32 { UInt32(COPYFILE_ACL) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STAT: UInt32 { UInt32(COPYFILE_STAT) }

@_alwaysEmitIntoClient
internal var _COPYFILE_XATTR: UInt32 { UInt32(COPYFILE_XATTR) }

@_alwaysEmitIntoClient
internal var _COPYFILE_DATA: UInt32 { UInt32(COPYFILE_DATA) }

@_alwaysEmitIntoClient
internal var _COPYFILE_SECURITY: UInt32 { UInt32(COPYFILE_SECURITY) }

@_alwaysEmitIntoClient
internal var _COPYFILE_METADATA: UInt32 { UInt32(COPYFILE_METADATA) }

@_alwaysEmitIntoClient
internal var _COPYFILE_ALL: UInt32 { UInt32(COPYFILE_ALL) }

@_alwaysEmitIntoClient
internal var _COPYFILE_RECURSIVE: UInt32 { UInt32(COPYFILE_RECURSIVE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_CHECK: UInt32 { UInt32(COPYFILE_CHECK) }

@_alwaysEmitIntoClient
internal var _COPYFILE_EXCL: UInt32 { UInt32(COPYFILE_EXCL) }

@_alwaysEmitIntoClient
internal var _COPYFILE_NOFOLLOW_SRC: UInt32 { UInt32(COPYFILE_NOFOLLOW_SRC) }

@_alwaysEmitIntoClient
internal var _COPYFILE_NOFOLLOW_DST: UInt32 { UInt32(COPYFILE_NOFOLLOW_DST) }

@_alwaysEmitIntoClient
internal var _COPYFILE_NOFOLLOW: UInt32 { UInt32(COPYFILE_NOFOLLOW) }

@_alwaysEmitIntoClient
internal var _COPYFILE_MOVE: UInt32 { UInt32(COPYFILE_MOVE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_UNLINK: UInt32 { UInt32(COPYFILE_UNLINK) }

@_alwaysEmitIntoClient
internal var _COPYFILE_PACK: UInt32 { UInt32(COPYFILE_PACK) }

@_alwaysEmitIntoClient
internal var _COPYFILE_UNPACK: UInt32 { UInt32(COPYFILE_UNPACK) }

@_alwaysEmitIntoClient
internal var _COPYFILE_CLONE: UInt32 { UInt32(COPYFILE_CLONE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_CLONE_FORCE: UInt32 { UInt32(COPYFILE_CLONE_FORCE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_RUN_IN_PLACE: UInt32 { UInt32(COPYFILE_RUN_IN_PLACE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_DATA_SPARSE: UInt32 { UInt32(COPYFILE_DATA_SPARSE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_PRESERVE_DST_TRACKED: UInt32 {
  UInt32(COPYFILE_PRESERVE_DST_TRACKED)
}

@_alwaysEmitIntoClient
internal var _COPYFILE_VERBOSE: UInt32 { UInt32(COPYFILE_VERBOSE) }

// MARK: copyfile state fields

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_STATUS_CB: UInt32 { UInt32(COPYFILE_STATE_STATUS_CB) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_STATUS_CTX: UInt32 { UInt32(COPYFILE_STATE_STATUS_CTX) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_COPIED: UInt32 { UInt32(COPYFILE_STATE_COPIED) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_XATTRNAME: UInt32 { UInt32(COPYFILE_STATE_XATTRNAME) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_WAS_CLONED: UInt32 { UInt32(COPYFILE_STATE_WAS_CLONED) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_SRC_BSIZE: UInt32 { UInt32(COPYFILE_STATE_SRC_BSIZE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_DST_BSIZE: UInt32 { UInt32(COPYFILE_STATE_DST_BSIZE) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_FORBID_CROSS_MOUNT: UInt32 {
  UInt32(COPYFILE_STATE_FORBID_CROSS_MOUNT)
}

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_NOCPROTECT: UInt32 { UInt32(COPYFILE_STATE_NOCPROTECT) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_PRESERVE_SUID: UInt32 { UInt32(COPYFILE_STATE_PRESERVE_SUID) }

@_alwaysEmitIntoClient
internal var _COPYFILE_STATE_FORBID_DST_EXISTING_SYMLINKS: UInt32 {
  UInt32(COPYFILE_STATE_FORBID_DST_EXISTING_SYMLINKS)
}

// MARK: copyfile callback values

@_alwaysEmitIntoClient
internal var _COPYFILE_RECURSE_ERROR: CInt { COPYFILE_RECURSE_ERROR }

@_alwaysEmitIntoClient
internal var _COPYFILE_RECURSE_FILE: CInt { COPYFILE_RECURSE_FILE }

@_alwaysEmitIntoClient
internal var _COPYFILE_RECURSE_DIR: CInt { COPYFILE_RECURSE_DIR }

@_alwaysEmitIntoClient
internal var _COPYFILE_RECURSE_DIR_CLEANUP: CInt { COPYFILE_RECURSE_DIR_CLEANUP }

@_alwaysEmitIntoClient
internal var _COPYFILE_COPY_DATA: CInt { COPYFILE_COPY_DATA }

@_alwaysEmitIntoClient
internal var _COPYFILE_COPY_XATTR: CInt { COPYFILE_COPY_XATTR }

@_alwaysEmitIntoClient
internal var _COPYFILE_START: CInt { COPYFILE_START }

@_alwaysEmitIntoClient
internal var _COPYFILE_FINISH: CInt { COPYFILE_FINISH }

@_alwaysEmitIntoClient
internal var _COPYFILE_ERR: CInt { COPYFILE_ERR }

@_alwaysEmitIntoClient
internal var _COPYFILE_PROGRESS: CInt { COPYFILE_PROGRESS }

@_alwaysEmitIntoClient
internal var _COPYFILE_CONTINUE: CInt { COPYFILE_CONTINUE }

@_alwaysEmitIntoClient
internal var _COPYFILE_SKIP: CInt { COPYFILE_SKIP }

@_alwaysEmitIntoClient
internal var _COPYFILE_QUIT: CInt { COPYFILE_QUIT }

// MARK: clonefile options

@_alwaysEmitIntoClient
internal var _CLONE_NOFOLLOW: UInt32 { UInt32(CLONE_NOFOLLOW) }

@_alwaysEmitIntoClient
internal var _CLONE_NOOWNERCOPY: UInt32 { UInt32(CLONE_NOOWNERCOPY) }

@_alwaysEmitIntoClient
internal var _CLONE_ACL: UInt32 { UInt32(CLONE_ACL) }

@_alwaysEmitIntoClient
internal var _CLONE_NOFOLLOW_ANY: UInt32 { UInt32(CLONE_NOFOLLOW_ANY) }

// The macOS 26 SDK added it.
#if canImport(Darwin, _version: 346)
@_alwaysEmitIntoClient
internal var _CLONE_RESOLVE_BENEATH: UInt32 { UInt32(CLONE_RESOLVE_BENEATH) }
#endif

#endif // SYSTEM_PACKAGE_DARWIN
