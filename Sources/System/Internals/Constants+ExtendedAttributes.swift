/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@_alwaysEmitIntoClient
internal var _XATTR_CREATE: CInt { XATTR_CREATE }

@_alwaysEmitIntoClient
internal var _XATTR_REPLACE: CInt { XATTR_REPLACE }

@_alwaysEmitIntoClient
internal var _XATTR_FINDERINFO_NAME: String { XATTR_FINDERINFO_NAME }

@_alwaysEmitIntoClient
internal var _XATTR_RESOURCEFORK_NAME: String { XATTR_RESOURCEFORK_NAME }
#else
// Linux's values, the same on every architecture. glibc declares them in an
// enum that its Swift module doesn't include.
@_alwaysEmitIntoClient
internal var _XATTR_CREATE: CInt { 1 }

@_alwaysEmitIntoClient
internal var _XATTR_REPLACE: CInt { 2 }
#endif

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
