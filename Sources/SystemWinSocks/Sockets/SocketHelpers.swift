/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// SystemSockets' helpers, which go through fileDescriptor there; a Winsock
// socket isn't one, so these use send and closesocket.

@available(System 199, *)
extension SocketDescriptor {
  /// Writes a sequence of bytes to the socket
  ///
  /// This sends until every byte is sent, as `FileDescriptor.writeAll(_:)`
  /// writes on POSIX systems.
  ///
  /// - Parameter sequence: The bytes to write.
  /// - Returns: The number of bytes written, equal to the number of elements in `sequence`.
  ///
  /// The corresponding C function is `send`, called in a loop.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll<S: Sequence>(
    _ sequence: S
  ) throws(Win32.Error) -> Int where S.Element == UInt8 {
    try _writeAll(sequence).get()
  }

  @usableFromInline
  internal func _writeAll<S: Sequence>(
    _ sequence: S
  ) -> Result<Int, Win32.Error> where S.Element == UInt8 {
    let bytes = Array(sequence)
    return bytes.withUnsafeBytes { buffer in
      var sent = 0
      while sent < buffer.count {
        let remaining = UnsafeRawBufferPointer(rebasing: buffer[sent...])
        switch _send(remaining, flags: .none, retryOnInterrupt: true) {
        case .success(let count):
          // A stream send that succeeds sends at least a byte.
          sent += count
        case .failure(let error):
          return .failure(error)
        }
      }
      return .success(sent)
    }
  }

  /// Runs a closure and then closes the socket, even if an error occurs.
  ///
  /// - Parameter body: The closure to run.
  ///   If the closure throws an error,
  ///   this method closes the socket before it rethrows that error.
  ///
  /// - Returns: The value returned by the closure.
  ///
  /// If `body` throws an error
  /// or an error occurs while closing the socket,
  /// this method rethrows that error.
  ///
  /// The corresponding C function is `closesocket`.
  @_alwaysEmitIntoClient
  public func closeAfter<R>(_ body: () throws -> R) throws -> R {
    let result: R
    do {
      result = try body()
    } catch {
      _ = try? self.close() // Squash close error and throw closure's
      throw error
    }
    try self.close()
    return result
  }
}

#endif // os(Windows)
