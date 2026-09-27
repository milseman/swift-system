/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The kernel state constants: the parts of sysctl identifiers that the
// typed names build, which have no string names.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@_alwaysEmitIntoClient
internal var _CTL_MAXNAME: Int { Int(CTL_MAXNAME) }

@_alwaysEmitIntoClient
internal var _CTL_KERN: CInt { CTL_KERN }

@_alwaysEmitIntoClient
internal var _KERN_PROC: CInt { KERN_PROC }

@_alwaysEmitIntoClient
internal var _KERN_PROC_ALL: CInt { KERN_PROC_ALL }

@_alwaysEmitIntoClient
internal var _KERN_PROC_PID: CInt { KERN_PROC_PID }

@_alwaysEmitIntoClient
internal var _KERN_PROC_PGRP: CInt { KERN_PROC_PGRP }

@_alwaysEmitIntoClient
internal var _KERN_PROC_UID: CInt { KERN_PROC_UID }

@_alwaysEmitIntoClient
internal var _KERN_PROC_RUID: CInt { KERN_PROC_RUID }

@_alwaysEmitIntoClient
internal var _KERN_PROCARGS2: CInt { KERN_PROCARGS2 }

#endif // SYSTEM_PACKAGE_DARWIN
