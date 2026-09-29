/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)

import Darwin

// MARK: - Type kinds

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_KIND_V0_OTHER: UInt32 { MALLOC_TYPE_KIND_V0_OTHER.rawValue }

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_KIND_V0_OBJC: UInt32 { MALLOC_TYPE_KIND_V0_OBJC.rawValue }

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_KIND_V0_SWIFT: UInt32 { MALLOC_TYPE_KIND_V0_SWIFT.rawValue }

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_KIND_V0_CXX: UInt32 { MALLOC_TYPE_KIND_V0_CXX.rawValue }

// MARK: - Call-site flags

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_CALLSITE_FLAGS_V0_FIXED_SIZE: UInt32 {
  MALLOC_TYPE_CALLSITE_FLAGS_V0_FIXED_SIZE.rawValue
}

@_alwaysEmitIntoClient
internal var _MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY: UInt32 {
  MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY.rawValue
}

#endif // SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)
