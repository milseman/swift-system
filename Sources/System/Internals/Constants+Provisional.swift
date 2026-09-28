/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library constants that System's provisional API uses (see
// Sources/System/Provisional): stdio's buffering modes.

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

@_alwaysEmitIntoClient
internal var __IOFBF: CInt { _IOFBF }

@_alwaysEmitIntoClient
internal var __IOLBF: CInt { _IOLBF }

@_alwaysEmitIntoClient
internal var __IONBF: CInt { _IONBF }

// The standard streams, which only Darwin declares as non-optional.
@_alwaysEmitIntoClient
internal var _stdin: UnsafeMutablePointer<FILE> {
#if SYSTEM_PACKAGE_DARWIN
  stdin
#else
  stdin!
#endif
}

@_alwaysEmitIntoClient
internal var _stdout: UnsafeMutablePointer<FILE> {
#if SYSTEM_PACKAGE_DARWIN
  stdout
#else
  stdout!
#endif
}

@_alwaysEmitIntoClient
internal var _stderr: UnsafeMutablePointer<FILE> {
#if SYSTEM_PACKAGE_DARWIN
  stderr
#else
  stderr!
#endif
}

#endif // !os(Windows)
