/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) && canImport(Glibc)

import CSystem

// MARK: - mallopt parameters

// glibc declares these in <malloc.h>, which its Swift module doesn't
// include, so they come from CSystem, which checks them against it.

@_alwaysEmitIntoClient
internal var _M_MXFAST: CInt { CSYSTEM_M_MXFAST }

@_alwaysEmitIntoClient
internal var _M_TRIM_THRESHOLD: CInt { CSYSTEM_M_TRIM_THRESHOLD }

@_alwaysEmitIntoClient
internal var _M_TOP_PAD: CInt { CSYSTEM_M_TOP_PAD }

@_alwaysEmitIntoClient
internal var _M_MMAP_THRESHOLD: CInt { CSYSTEM_M_MMAP_THRESHOLD }

@_alwaysEmitIntoClient
internal var _M_MMAP_MAX: CInt { CSYSTEM_M_MMAP_MAX }

@_alwaysEmitIntoClient
internal var _M_CHECK_ACTION: CInt { CSYSTEM_M_CHECK_ACTION }

@_alwaysEmitIntoClient
internal var _M_PERTURB: CInt { CSYSTEM_M_PERTURB }

@_alwaysEmitIntoClient
internal var _M_ARENA_TEST: CInt { CSYSTEM_M_ARENA_TEST }

@_alwaysEmitIntoClient
internal var _M_ARENA_MAX: CInt { CSYSTEM_M_ARENA_MAX }

#endif // os(Linux) && canImport(Glibc)
