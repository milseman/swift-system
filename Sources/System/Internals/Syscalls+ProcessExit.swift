/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Ending the calling process: exit, _exit, abort, and atexit.

#if !os(Windows)

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

// exit, _exit and abort never return, so they have no mock hook.

@usableFromInline
internal func system_exit(_ status: CInt) -> Never {
  exit(status)
}

@usableFromInline
internal func system__exit(_ status: CInt) -> Never {
  _exit(status)
}

@usableFromInline
internal func system_abort() -> Never {
  abort()
}

// atexit returns a nonzero value, not necessarily -1, when it fails, and
// POSIX doesn't say that it sets errno.
internal func system_atexit(_ function: @convention(c) () -> Void) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return atexit(function)
}

#endif // !os(Windows)
