/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Linux's sendfile, which sends from a file to any descriptor. Darwin's
// sends only to a socket; SystemSockets wraps both for sockets.

#if os(Linux) || os(Android)

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

internal func system_sendfile(
  _ outFD: CInt,
  _ inFD: CInt,
  _ offset: UnsafeMutablePointer<_COffT>,
  _ count: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(outFD, inFD, offset.pointee, count) }
#endif
  return sendfile(outFD, inFD, offset, count)
}

#endif // os(Linux) || os(Android)
