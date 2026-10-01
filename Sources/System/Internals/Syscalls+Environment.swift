/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The process's environment: setenv, unsetenv, and the environ array.
// getenv's wrapper, system_getenv, is in Syscalls.swift.

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

internal func system_setenv(
  _ name: UnsafePointer<CChar>, _ value: UnsafePointer<CChar>, _ overwrite: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: name, String(_errorCorrectingPlatformString: value), overwrite)
  }
#endif
  return setenv(name, value, overwrite)
}

internal func system_unsetenv(_ name: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name) }
#endif
  return unsetenv(name)
}

// The environ array, which setenv and unsetenv can reallocate. It can't
// fail, so it has no mock.
internal func system_environ() -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? {
  csystem_environ()
}

#endif // !os(Windows)
