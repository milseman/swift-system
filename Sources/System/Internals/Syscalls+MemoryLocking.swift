/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Memory locking: mlock, munlock, and off Darwin, mlockall and munlockall.

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

// mlock
internal func system_mlock(_ start: UnsafeRawPointer?, _ length: Int) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start.map { Int(bitPattern: $0) } ?? 0, length) }
#endif
  return mlock(start, length)
}

// munlock
internal func system_munlock(_ start: UnsafeRawPointer?, _ length: Int) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start.map { Int(bitPattern: $0) } ?? 0, length) }
#endif
  return munlock(start, length)
}

#if !SYSTEM_PACKAGE_DARWIN
// mlockall
internal func system_mlockall(_ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(flags) }
#endif
  return mlockall(flags)
}

// munlockall
internal func system_munlockall() -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return munlockall()
}
#endif // !SYSTEM_PACKAGE_DARWIN

#endif // !os(Windows) && !os(WASI)
