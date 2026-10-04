/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// System call wrappers for sendfile, whose Darwin and Linux forms differ.

#if !os(WASI)

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

#if SYSTEM_PACKAGE_DARWIN
// Darwin's sendfile(fd, s, offset, len, hdtr, flags) sends from the file `fd`
// to the stream socket `s`, and sets *len to the bytes it sent, even when it
// fails with EAGAIN or EINTR. A mocked call sends the next of the driver's
// byte counts, or else all of *len when it succeeds and none when it fails.
internal func system_sendfile(
  _ fd: CInt,
  _ socket: CInt,
  _ offset: off_t,
  _ length: UnsafeMutablePointer<off_t>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mock(fd, socket, offset, length.pointee)
    if let driver = currentMockingDriver, !driver.byteCounts.isEmpty {
      length.pointee = off_t(driver.byteCounts.removeFirst())
    } else if result == -1 {
      length.pointee = 0
    }
    return result
  }
#endif
  return sendfile(fd, socket, offset, length, nil, 0)
}
#elseif os(Linux) || os(Android)
// Linux's sendfile(out_fd, in_fd, offset, count) returns the bytes it sent,
// and advances *offset by them rather than the file's own offset.
internal func system_sendfile(
  _ outFD: CInt,
  _ inFD: CInt,
  _ offset: UnsafeMutablePointer<off_t>,
  _ count: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(outFD, inFD, offset.pointee, count) }
#endif
  return sendfile(outFD, inFD, offset, count)
}
#endif

#endif // !os(WASI)
