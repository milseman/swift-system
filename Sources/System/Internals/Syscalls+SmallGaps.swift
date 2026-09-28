/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unique files with a suffix, or relative to a directory (mkostemps,
// mkostempsat_np), and a signal's description (strsignal).

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

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
// mkostemps
internal func system_mkostemps(
  _ template: UnsafeMutablePointer<CChar>, _ suffixLength: CInt, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: template, suffixLength, flags) }
#endif
  return mkostemps(template, suffixLength, flags)
}
#endif

#if SYSTEM_PACKAGE_DARWIN
// mkostempsat_np
internal func system_mkostempsat_np(
  _ fd: CInt, _ template: UnsafeMutablePointer<CChar>, _ suffixLength: CInt, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: template), suffixLength, flags)
  }
#endif
  return mkostempsat_np(fd, template, suffixLength, flags)
}
#endif

// strsignal, which can't fail, so it has no mock hook.
internal func system_strsignal(_ signal: CInt) -> UnsafeMutablePointer<CChar>? {
  strsignal(signal)
}

#endif // !os(Windows) && !os(WASI)
