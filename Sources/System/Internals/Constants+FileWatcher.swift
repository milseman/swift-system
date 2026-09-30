/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// inotify's flags, for FileWatcher.swift. glibc declares IN_NONBLOCK and
// IN_CLOEXEC in an anonymous enum, which Swift imports as Int.

#if os(Linux) || os(Android)

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var _IN_NONBLOCK: CInt { CInt(IN_NONBLOCK) }

@_alwaysEmitIntoClient
internal var _IN_CLOEXEC: CInt { CInt(IN_CLOEXEC) }

@_alwaysEmitIntoClient
internal var _IN_ACCESS: UInt32 { UInt32(IN_ACCESS) }

@_alwaysEmitIntoClient
internal var _IN_MODIFY: UInt32 { UInt32(IN_MODIFY) }

@_alwaysEmitIntoClient
internal var _IN_ATTRIB: UInt32 { UInt32(IN_ATTRIB) }

@_alwaysEmitIntoClient
internal var _IN_CLOSE_WRITE: UInt32 { UInt32(IN_CLOSE_WRITE) }

@_alwaysEmitIntoClient
internal var _IN_CLOSE_NOWRITE: UInt32 { UInt32(IN_CLOSE_NOWRITE) }

@_alwaysEmitIntoClient
internal var _IN_OPEN: UInt32 { UInt32(IN_OPEN) }

@_alwaysEmitIntoClient
internal var _IN_MOVED_FROM: UInt32 { UInt32(IN_MOVED_FROM) }

@_alwaysEmitIntoClient
internal var _IN_MOVED_TO: UInt32 { UInt32(IN_MOVED_TO) }

@_alwaysEmitIntoClient
internal var _IN_CREATE: UInt32 { UInt32(IN_CREATE) }

@_alwaysEmitIntoClient
internal var _IN_DELETE: UInt32 { UInt32(IN_DELETE) }

@_alwaysEmitIntoClient
internal var _IN_DELETE_SELF: UInt32 { UInt32(IN_DELETE_SELF) }

@_alwaysEmitIntoClient
internal var _IN_MOVE_SELF: UInt32 { UInt32(IN_MOVE_SELF) }

@_alwaysEmitIntoClient
internal var _IN_UNMOUNT: UInt32 { UInt32(IN_UNMOUNT) }

@_alwaysEmitIntoClient
internal var _IN_Q_OVERFLOW: UInt32 { UInt32(IN_Q_OVERFLOW) }

@_alwaysEmitIntoClient
internal var _IN_IGNORED: UInt32 { UInt32(IN_IGNORED) }

@_alwaysEmitIntoClient
internal var _IN_ISDIR: UInt32 { UInt32(IN_ISDIR) }

@_alwaysEmitIntoClient
internal var _IN_ONLYDIR: UInt32 { UInt32(IN_ONLYDIR) }

@_alwaysEmitIntoClient
internal var _IN_DONT_FOLLOW: UInt32 { UInt32(IN_DONT_FOLLOW) }

@_alwaysEmitIntoClient
internal var _IN_EXCL_UNLINK: UInt32 { UInt32(IN_EXCL_UNLINK) }

@_alwaysEmitIntoClient
internal var _IN_MASK_ADD: UInt32 { UInt32(IN_MASK_ADD) }

@_alwaysEmitIntoClient
internal var _IN_ONESHOT: UInt32 { UInt32(IN_ONESHOT) }

#endif // os(Linux) || os(Android)
