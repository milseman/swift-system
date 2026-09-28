/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// System call wrappers for sendmmsg and recvmmsg, which Darwin lacks.

#if os(Linux) || os(Android)

#if canImport(Glibc)
@_implementationOnly import CSystem
import Glibc
#elseif canImport(Musl)
@_implementationOnly import CSystem
import Musl
#elseif canImport(Android)
@_implementationOnly import CSystem
import Android
#endif

import SystemPackage

// The mocked calls return the next of the driver's byte counts as the number
// of messages, or 0.

internal func system_sendmmsg(
  _ socket: CInt,
  _ messages: UnsafeMutableRawPointer?,
  _ count: CUnsignedInt,
  _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return CInt(_mockInt(socket, count, flags)) }
#endif
  return csystem_sendmmsg(socket, messages, count, flags)
}

internal func system_recvmmsg(
  _ socket: CInt,
  _ messages: UnsafeMutableRawPointer?,
  _ count: CUnsignedInt,
  _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return CInt(_mockInt(socket, count, flags)) }
#endif
  return csystem_recvmmsg(socket, messages, count, flags, nil)
}

#endif // os(Linux) || os(Android)
