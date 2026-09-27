/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The kernel state calls: sysctl, sysctlbyname, and sysctlnametomib.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// sysctl
internal func system_sysctl(
  _ name: UnsafeMutablePointer<CInt>,
  _ nameCount: CUnsignedInt,
  _ old: UnsafeMutableRawPointer?,
  _ oldLength: UnsafeMutablePointer<Int>?,
  _ new: UnsafeMutableRawPointer?,
  _ newLength: Int
) -> CInt {
#if ENABLE_MOCKING
  // Records the identifier, the size of the buffer for the old value
  // (-1 for none), and the size of the new value.
  if mockingEnabled {
    return _mock(
      Array(UnsafeBufferPointer(start: name, count: Int(nameCount))),
      oldLength?.pointee ?? -1, newLength)
  }
#endif
  return sysctl(name, nameCount, old, oldLength, new, newLength)
}

// sysctlbyname
internal func system_sysctlbyname(
  _ name: UnsafePointer<CChar>,
  _ old: UnsafeMutableRawPointer?,
  _ oldLength: UnsafeMutablePointer<Int>?,
  _ new: UnsafeMutableRawPointer?,
  _ newLength: Int
) -> CInt {
#if ENABLE_MOCKING
  // Records the size of the buffer for the old value (-1 for none), and
  // the size of the new value.
  if mockingEnabled { return _mock(path: name, oldLength?.pointee ?? -1, newLength) }
#endif
  return sysctlbyname(name, old, oldLength, new, newLength)
}

// sysctlnametomib
internal func system_sysctlnametomib(
  _ name: UnsafePointer<CChar>,
  _ identifier: UnsafeMutablePointer<CInt>,
  _ count: UnsafeMutablePointer<Int>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name, count.pointee) }
#endif
  return sysctlnametomib(name, identifier, count)
}

#endif // SYSTEM_PACKAGE_DARWIN
