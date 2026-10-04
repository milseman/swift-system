/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(WASI)

import SystemPackage

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

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

@available(System 199, *)
extension SocketDescriptor {
  /// Sends bytes from a file on the socket,
  /// without copying them through the process.
  ///
  ///     var offset: Int64 = 0
  ///     while offset < size {
  ///       offset += Int64(try socket.sendFile(
  ///         file, fromAbsoluteOffset: offset, count: Int(size - offset)))
  ///     }
  ///
  /// - Parameters:
  ///   - file: The file to send from, which must be a regular file.
  ///   - offset: The offset in the file of the first byte to send.
  ///     The file's own offset doesn't change.
  ///   - count: The number of bytes to send, which must not be negative.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before sending anything.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes sent,
  ///   which can be fewer than `count`, as a `write` can be,
  ///   for example when a nonblocking socket's buffer fills,
  ///   or at the end of the file.
  ///   A `count` of 0 sends nothing and returns 0.
  ///
  /// A socket that can't take any bytes without blocking,
  /// because it's nonblocking and its buffer is full,
  /// throws ``Errno/wouldBlock`` before sending anything.
  /// Darwin's `sendfile` fails with that error even when it sent some bytes,
  /// and reports the count; this method returns the count then, instead,
  /// as it does for an interruption after some bytes,
  /// so a caller never loses track of what it sent.
  ///
  /// On Darwin, the socket must be a stream socket, such as a TCP socket
  /// or a `.local` stream socket.
  /// On Linux, it can be any socket, and ``FileDescriptor``'s
  /// `sendFile(_:fromAbsoluteOffset:count:retryOnInterrupt:)`
  /// sends to any descriptor.
  /// Linux sends at most 2,147,479,552 (0x7ffff000) bytes a call.
  /// Darwin's `sendfile` sends the rest of the file when its count is 0;
  /// this method never passes it 0.
  ///
  /// The corresponding C function is `sendfile`.
  @_alwaysEmitIntoClient
  public func sendFile(
    _ file: FileDescriptor,
    fromAbsoluteOffset offset: Int64,
    count: Int,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _sendFile(
      file, fromAbsoluteOffset: offset, count: count, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _sendFile(
    _ file: FileDescriptor,
    fromAbsoluteOffset offset: Int64,
    count: Int,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    precondition(count >= 0, "sendFile: 'count' must not be negative")
    guard count > 0 else { return .success(0) }
    #if SYSTEM_PACKAGE_DARWIN
    while true {
      var sent = off_t(count)
      if system_sendfile(file.rawValue, self.rawValue, off_t(offset), &sent) == 0 {
        return .success(Int(sent))
      }
      let error = Errno.current
      // Darwin sets `sent` even when it fails: report the bytes it sent
      // before it would block, or before a signal interrupted it.
      if sent > 0 && (error == .wouldBlock || error == .interrupted) {
        return .success(Int(sent))
      }
      guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
    }
    #else
    var offset = off_t(offset)
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_sendfile(self.rawValue, file.rawValue, &offset, count)
    }
    #endif
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#endif // !os(WASI)
