/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unique files with a suffix, or relative to a directory (mkostemps,
// mkostempsat_np), or with permissions (mktemp, then open), a signal's
// description (strsignal), a passphrase (readpassphrase), and C spawn
// attributes' flags (posix_spawnattr_getflags).

#if !os(Windows) && !os(WASI)

#if os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
import CSystem
#endif
#if SYSTEM_PACKAGE_DARWIN
import CSystem
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

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
// mkostemps, which glibc and Musl declare only with _GNU_SOURCE, and Bionic
// only from API level 23, so it's a CSystem shim there.
internal func system_mkostemps(
  _ template: UnsafeMutablePointer<CChar>, _ suffixLength: CInt, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: template, suffixLength, flags) }
#endif
#if os(Linux) || os(Android)
  return csystem_mkostemps(template, suffixLength, flags)
#else
  return mkostemps(template, suffixLength, flags)
#endif
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

// mktemp, through CSystem, since the SDK deprecates it. A mocked call that
// succeeds leaves the template as it is.
internal func system_mktemp(_ template: UnsafeMutablePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  if mockingEnabled {
    if _mock(path: template) != 0 { return nil }
    return template
  }
#endif
  return csystem_mktemp(template)
}
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
// readpassphrase, whose prompt is recorded by value. A mocked call that
// succeeds reads an empty passphrase. On the BSDs it's CSystem's shim,
// since their Swift modules may not include <readpassphrase.h>.
internal func system_readpassphrase(
  _ prompt: UnsafePointer<CChar>, _ buffer: UnsafeMutablePointer<CChar>, _ size: Int, _ flags: CInt
) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  if mockingEnabled {
    if _mock(path: prompt, size, flags) != 0 { return nil }
    if size > 0 { buffer.pointee = 0 }
    return buffer
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return readpassphrase(prompt, buffer, size, flags)
#else
  return csystem_readpassphrase(prompt, buffer, UInt(size), flags)
#endif
}
#endif

#if !os(watchOS) && !os(tvOS)
// posix_spawnattr_getflags, which returns an error number. Like the
// posix_spawnattr setters in Syscalls+Processes.swift, it has no mock hook,
// and on Android it's a CSystem shim.
internal func system_posix_spawnattr_getflags(
  _ attributes: UnsafePointer<_SpawnAttributesStorage>, _ flags: UnsafeMutablePointer<CShort>
) -> CInt {
#if os(Android)
  csystem_posix_spawnattr_getflags(attributes, flags)
#else
  posix_spawnattr_getflags(attributes, flags)
#endif
}
#endif

// strsignal, which can't fail, so it has no mock hook.
internal func system_strsignal(_ signal: CInt) -> UnsafeMutablePointer<CChar>? {
  strsignal(signal)
}

// The C library's table of signal names: sys_signame, which Swift imports as
// a tuple of NSIG names, lowercase and without SIG; and glibc's
// sigabbrev_np, uppercase. Neither can fail, so they have no mock hooks.
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)
internal func system_sys_signame(_ signal: CInt) -> UnsafePointer<CChar>? {
  withUnsafeBytes(of: sys_signame) { table in
    let names = table.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
    return signal > 0 && Int(signal) < names.count ? names[Int(signal)] : nil
  }
}
#elseif os(Linux) && canImport(Glibc)
internal func system_sigabbrev_np(_ signal: CInt) -> UnsafePointer<CChar>? {
  csystem_sigabbrev_np(signal)
}

internal func system_has_sigabbrev_np() -> Bool {
  csystem_has_sigabbrev_np() != 0
}
#endif

#endif // !os(Windows) && !os(WASI)
