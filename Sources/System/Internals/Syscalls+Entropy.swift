/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Random bytes: getentropy.

#if !os(Windows) && !os(WASI)

import CSystem
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

// Fills at most 256 bytes. Bionic declares getentropy only from API level
// 28, below which CSystem's shim fails with ENOSYS.
internal func system_getentropy(_ buffer: UnsafeMutableRawPointer, _ length: Int) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(length) }
#endif
#if os(Android)
  return csystem_getentropy(buffer, length)
#else
  return getentropy(buffer, length)
#endif
}

#endif // !os(Windows) && !os(WASI)
