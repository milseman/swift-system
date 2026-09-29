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

#if SYSTEM_PACKAGE_DARWIN
// dladdr reports no error; it returns 0 when no loaded image contains the
// address. glibc declares it only with _GNU_SOURCE, which its Swift module
// doesn't define, so it's Darwin's for now.
internal func system_dladdr(
  _ address: UnsafeRawPointer
) -> (path: UnsafePointer<CChar>, base: UnsafeRawPointer?,
      symbol: UnsafePointer<CChar>?, symbolAddress: UnsafeRawPointer?)? {
  var info = Dl_info()
  guard dladdr(address, &info) != 0, let path = info.dli_fname else { return nil }
  return (path, info.dli_fbase.map(UnsafeRawPointer.init),
          info.dli_sname, info.dli_saddr.map(UnsafeRawPointer.init))
}
#endif

#endif // !os(Windows) && !os(WASI)
