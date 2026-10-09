/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Paths and files: realpath and free, remove, mkostemp, mkdtemp, and whether
// the process is a set-user-ID one. Windows has its own, in Win32Syscalls.swift. umask's wrapper, system_umask, and
// confstr's, system_confstr, are in Syscalls.swift.

#if !os(Windows)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// The result is allocated, and the caller frees it.
internal func system_realpath(
  _ path: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  // A mocked success resolves the path to itself.
  if mockingEnabled { return _mock(path: path) == 0 ? strdup(path) : nil }
#endif
  return realpath(path, nil)
}

internal func system_remove(_ path: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path) }
#endif
  return remove(path)
}

// WASI's C library has no mkostemp, mkdtemp or issetugid.
#if !os(WASI)

// Replaces the X's at the end of the template in place.
internal func system_mkostemp(
  _ template: UnsafeMutablePointer<CChar>, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: template, flags) }
#endif
#if os(Linux) || os(Android)
  return csystem_mkostemp(template, flags)
#else
  return mkostemp(template, flags)
#endif
}

// Replaces the X's at the end of the template in place.
internal func system_mkdtemp(
  _ template: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: template) == 0 ? template : nil }
#endif
  return mkdtemp(template)
}

// Whether the process runs with privileges it didn't start with, as a
// set-user-ID program does, and so shouldn't trust its environment.
internal func system_isSecureExecution() -> Bool {
#if os(Linux) || os(Android)
  return csystem_is_secure_execution() != 0
#else
  return issetugid() != 0
#endif
}

#endif // !os(WASI)

#endif // !os(Windows)
