/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// removefile's flags, state keys, and callback results. <removefile.h>
// declares them in anonymous enums, which import as Int.

#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin

@_alwaysEmitIntoClient
internal var _REMOVEFILE_RECURSIVE: UInt32 { UInt32(REMOVEFILE_RECURSIVE) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_KEEP_PARENT: UInt32 { UInt32(REMOVEFILE_KEEP_PARENT) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_CROSS_MOUNT: UInt32 { UInt32(REMOVEFILE_CROSS_MOUNT) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_ALLOW_LONG_PATHS: UInt32 { UInt32(REMOVEFILE_ALLOW_LONG_PATHS) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_CONFIRM_CALLBACK: UInt32 { UInt32(REMOVEFILE_STATE_CONFIRM_CALLBACK) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_CONFIRM_CONTEXT: UInt32 { UInt32(REMOVEFILE_STATE_CONFIRM_CONTEXT) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_ERROR_CALLBACK: UInt32 { UInt32(REMOVEFILE_STATE_ERROR_CALLBACK) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_ERROR_CONTEXT: UInt32 { UInt32(REMOVEFILE_STATE_ERROR_CONTEXT) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_ERRNO: UInt32 { UInt32(REMOVEFILE_STATE_ERRNO) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_STATUS_CALLBACK: UInt32 { UInt32(REMOVEFILE_STATE_STATUS_CALLBACK) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STATE_STATUS_CONTEXT: UInt32 { UInt32(REMOVEFILE_STATE_STATUS_CONTEXT) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_PROCEED: CInt { CInt(REMOVEFILE_PROCEED) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_SKIP: CInt { CInt(REMOVEFILE_SKIP) }

@_alwaysEmitIntoClient
internal var _REMOVEFILE_STOP: CInt { CInt(REMOVEFILE_STOP) }

#endif // SYSTEM_PACKAGE_DARWIN
