/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Dynamic loading: dlopen, dlsym, dlclose and dlerror. These report
// failure through dlerror rather than errno, so they have no mock hooks.

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

// A null path opens the program itself.
internal func system_dlopen(
  _ path: UnsafePointer<CChar>?, _ mode: CInt
) -> UnsafeMutableRawPointer? {
  dlopen(path, mode)
}

internal func system_dlsym(
  _ handle: UnsafeMutableRawPointer, _ symbol: UnsafePointer<CChar>
) -> UnsafeMutableRawPointer? {
  dlsym(handle, symbol)
}

internal func system_dlclose(_ handle: UnsafeMutableRawPointer) -> CInt {
  dlclose(handle)
}

// The calling thread's last dynamic linking error, which reading clears.
internal func system_dlerror() -> UnsafeMutablePointer<CChar>? {
  dlerror()
}

#endif // !os(Windows) && !os(WASI)
