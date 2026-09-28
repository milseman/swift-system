/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

@available(System 199, *)
extension FileDescriptor {
  /// Writes bytes from a file to this descriptor,
  /// without copying them through the process.
  ///
  /// - Parameters:
  ///   - file: The file to send from, which must support memory mapping,
  ///     as a regular file does. A pipe or a socket fails,
  ///     with an error that differs by kernel version:
  ///     Linux 6.18 reports a pipe as ``Errno/illegalSeek``.
  ///   - offset: The offset in the file of the first byte to send.
  ///     The file's own offset doesn't change.
  ///   - count: The number of bytes to send, which must not be negative.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before sending anything.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes sent,
  ///   which can be fewer than `count`, as a `write` can be,
  ///   and is 0 at the end of the file.
  ///   A `count` of 0 sends nothing and returns 0.
  ///
  /// This descriptor can be any file, pipe, or socket.
  /// Linux sends at most 2,147,479,552 (0x7ffff000) bytes a call.
  /// On Darwin, `sendfile` sends only to a socket;
  /// use `SocketDescriptor`'s `sendFile(_:fromAbsoluteOffset:count:retryOnInterrupt:)`,
  /// in SystemSockets, which works on both.
  ///
  /// The corresponding C function is `sendfile`.
  ///
  /// - Note: Only available on Linux and Android.
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
    var offset = _COffT(offset)
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_sendfile(self.rawValue, file.rawValue, &offset, count)
    }
  }
}

#endif // os(Linux) || os(Android)
