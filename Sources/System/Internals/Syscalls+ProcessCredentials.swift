/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Credential queries: getgrouplist, and Darwin's pthread_getugid_np.
// issetugid is system_isSecureExecution, in Syscalls+PathsAndFiles.swift.

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

// Returns -1 when the groups don't fit, and otherwise leaves their number in
// count. Darwin's getgrouplist takes int groups, and returns 0 on success;
// the others take gid_t groups, and glibc returns their number.
internal func system_getgrouplist(
  _ user: UnsafePointer<CChar>, _ group: gid_t,
  _ groups: UnsafeMutablePointer<gid_t>, _ count: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  // A mocked success finds no groups.
  if mockingEnabled {
    let result = _mock(path: user, group)
    if result == 0 { count.pointee = 0 }
    return result
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return groups.withMemoryRebound(to: CInt.self, capacity: Int(count.pointee)) {
    getgrouplist(user, CInt(bitPattern: group), $0, count)
  }
#else
  return getgrouplist(user, group, groups, count)
#endif
}

#if SYSTEM_PACKAGE_DARWIN
internal func system_pthread_getugid_np(
  _ user: UnsafeMutablePointer<uid_t>, _ group: UnsafeMutablePointer<gid_t>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return pthread_getugid_np(user, group)
}
#endif

#endif // !os(Windows) && !os(WASI)
