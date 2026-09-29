/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Interval timers and scheduling priorities: ITIMER_* and PRIO_*.

#if !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if os(Linux) || os(Android)
// glibc declares these in named enums, whose types aren't the calls'
// parameters' without _GNU_SOURCE, so they're spelled out, as the kernel's
// values, which are the same on every architecture.
@_alwaysEmitIntoClient
internal var _ITIMER_REAL: CInt { 0 }

@_alwaysEmitIntoClient
internal var _ITIMER_VIRTUAL: CInt { 1 }

@_alwaysEmitIntoClient
internal var _ITIMER_PROF: CInt { 2 }

@_alwaysEmitIntoClient
internal var _PRIO_PROCESS: CInt { 0 }

@_alwaysEmitIntoClient
internal var _PRIO_PGRP: CInt { 1 }

@_alwaysEmitIntoClient
internal var _PRIO_USER: CInt { 2 }
#else
@_alwaysEmitIntoClient
internal var _ITIMER_REAL: CInt { ITIMER_REAL }

@_alwaysEmitIntoClient
internal var _ITIMER_VIRTUAL: CInt { ITIMER_VIRTUAL }

@_alwaysEmitIntoClient
internal var _ITIMER_PROF: CInt { ITIMER_PROF }

@_alwaysEmitIntoClient
internal var _PRIO_PROCESS: CInt { PRIO_PROCESS }

@_alwaysEmitIntoClient
internal var _PRIO_PGRP: CInt { PRIO_PGRP }

@_alwaysEmitIntoClient
internal var _PRIO_USER: CInt { PRIO_USER }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_DISK: CInt { IOPOL_TYPE_DISK }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_ATIME_UPDATES: CInt { IOPOL_TYPE_VFS_ATIME_UPDATES }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES: CInt { IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_STATFS_NO_DATA_VOLUME: CInt { IOPOL_TYPE_VFS_STATFS_NO_DATA_VOLUME }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_TRIGGER_RESOLVE: CInt { IOPOL_TYPE_VFS_TRIGGER_RESOLVE }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_IGNORE_CONTENT_PROTECTION: CInt { IOPOL_TYPE_VFS_IGNORE_CONTENT_PROTECTION }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_IGNORE_PERMISSIONS: CInt { IOPOL_TYPE_VFS_IGNORE_PERMISSIONS }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_SKIP_MTIME_UPDATE: CInt { IOPOL_TYPE_VFS_SKIP_MTIME_UPDATE }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_ALLOW_LOW_SPACE_WRITES: CInt { IOPOL_TYPE_VFS_ALLOW_LOW_SPACE_WRITES }

@_alwaysEmitIntoClient
internal var _IOPOL_TYPE_VFS_DISALLOW_RW_FOR_O_EVTONLY: CInt { IOPOL_TYPE_VFS_DISALLOW_RW_FOR_O_EVTONLY }

@_alwaysEmitIntoClient
internal var _IOPOL_SCOPE_PROCESS: CInt { IOPOL_SCOPE_PROCESS }

@_alwaysEmitIntoClient
internal var _IOPOL_SCOPE_THREAD: CInt { IOPOL_SCOPE_THREAD }

@_alwaysEmitIntoClient
internal var _IOPOL_SCOPE_DARWIN_BG: CInt { IOPOL_SCOPE_DARWIN_BG }
#endif

#endif // !os(Windows) && !os(WASI)
