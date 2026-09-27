/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Network interfaces: getifaddrs, freeifaddrs, if_nametoindex and
// if_indextoname.

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

// Bionic declares getifaddrs and freeifaddrs only from API level 24, below
// which CSystem's shims fail with ENOSYS.
internal func system_getifaddrs(
  _ list: UnsafeMutablePointer<UnsafeMutablePointer<ifaddrs>?>
) -> CInt {
#if ENABLE_MOCKING
  // A mocked success leaves the list empty.
  if mockingEnabled { return _mock(list) }
#endif
#if os(Android)
  return list.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: 1) {
    csystem_getifaddrs($0)
  }
#else
  return getifaddrs(list)
#endif
}

internal func system_freeifaddrs(_ list: UnsafeMutablePointer<ifaddrs>) {
#if os(Android)
  csystem_freeifaddrs(list)
#else
  freeifaddrs(list)
#endif
}

// Returns 0, not -1, when it fails.
internal func system_if_nametoindex(_ name: UnsafePointer<CChar>) -> CUnsignedInt {
#if ENABLE_MOCKING
  // A mocked success finds index 1.
  if mockingEnabled { return _mock(path: name) == 0 ? 1 : 0 }
#endif
  return if_nametoindex(name)
}

// Returns nil when it fails. The buffer has room for IF_NAMESIZE bytes.
internal func system_if_indextoname(
  _ index: CUnsignedInt, _ name: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  // A mocked success leaves the buffer as it was.
  if mockingEnabled { return _mock(index) == 0 ? name : nil }
#endif
  return if_indextoname(index, name)
}

#endif // !os(Windows) && !os(WASI)
