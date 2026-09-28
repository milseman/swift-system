/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Mach kernel return codes, from <mach/kern_return.h>, and the virtual
// memory allocation flag, from <mach/vm_statistics.h>.

#if SYSTEM_PACKAGE_DARWIN

import Darwin.Mach

@_alwaysEmitIntoClient
internal var _KERN_SUCCESS: kern_return_t { KERN_SUCCESS }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_ADDRESS: kern_return_t { KERN_INVALID_ADDRESS }

@_alwaysEmitIntoClient
internal var _KERN_PROTECTION_FAILURE: kern_return_t { KERN_PROTECTION_FAILURE }

@_alwaysEmitIntoClient
internal var _KERN_NO_SPACE: kern_return_t { KERN_NO_SPACE }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_ARGUMENT: kern_return_t { KERN_INVALID_ARGUMENT }

@_alwaysEmitIntoClient
internal var _KERN_FAILURE: kern_return_t { KERN_FAILURE }

@_alwaysEmitIntoClient
internal var _KERN_RESOURCE_SHORTAGE: kern_return_t { KERN_RESOURCE_SHORTAGE }

@_alwaysEmitIntoClient
internal var _KERN_NOT_RECEIVER: kern_return_t { KERN_NOT_RECEIVER }

@_alwaysEmitIntoClient
internal var _KERN_NO_ACCESS: kern_return_t { KERN_NO_ACCESS }

@_alwaysEmitIntoClient
internal var _KERN_MEMORY_FAILURE: kern_return_t { KERN_MEMORY_FAILURE }

@_alwaysEmitIntoClient
internal var _KERN_MEMORY_ERROR: kern_return_t { KERN_MEMORY_ERROR }

@_alwaysEmitIntoClient
internal var _KERN_ABORTED: kern_return_t { KERN_ABORTED }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_NAME: kern_return_t { KERN_INVALID_NAME }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_TASK: kern_return_t { KERN_INVALID_TASK }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_RIGHT: kern_return_t { KERN_INVALID_RIGHT }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_VALUE: kern_return_t { KERN_INVALID_VALUE }

@_alwaysEmitIntoClient
internal var _KERN_INVALID_CAPABILITY: kern_return_t { KERN_INVALID_CAPABILITY }

@_alwaysEmitIntoClient
internal var _KERN_NOT_SUPPORTED: kern_return_t { KERN_NOT_SUPPORTED }

@_alwaysEmitIntoClient
internal var _KERN_OPERATION_TIMED_OUT: kern_return_t { KERN_OPERATION_TIMED_OUT }

@_alwaysEmitIntoClient
internal var _KERN_DENIED: kern_return_t { KERN_DENIED }

@_alwaysEmitIntoClient
internal var _KERN_NOT_FOUND: kern_return_t { KERN_NOT_FOUND }

@_alwaysEmitIntoClient
internal var _VM_FLAGS_ANYWHERE: CInt { VM_FLAGS_ANYWHERE }

#endif // SYSTEM_PACKAGE_DARWIN
