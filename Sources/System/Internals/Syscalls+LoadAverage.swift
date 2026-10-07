/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The system's load averages: getloadavg. Bionic has it only from API
// level 29, so Android is left out, as WASI and Windows, which have none.
//
// It has no mock hook: a mocked call would fill no samples, so a mock test
// of it would test nothing.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

internal func system_getloadavg(_ samples: UnsafeMutablePointer<Double>, _ count: CInt) -> CInt {
  getloadavg(samples, count)
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)
