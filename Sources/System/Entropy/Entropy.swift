/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

/// A namespace for random bytes from the operating system's
/// cryptographically secure random number generator.
///
///     let key = try Entropy.bytes(count: 32)
///
/// These are the bytes that seed other generators, and that keys and nonces
/// can use directly. The standard library's `SystemRandomNumberGenerator`
/// reads the same kind of source, but traps if it fails;
/// these methods throw instead.
@available(System 199, *)
public enum Entropy {}

@available(System 199, *)
extension Entropy {
  /// Fills a buffer with random bytes.
  ///
  /// - Parameter buffer: The buffer to fill, of any size.
  ///
  /// A single `getentropy` call fills at most 256 bytes,
  /// so this method makes as many calls as `buffer` needs.
  /// The system can wait to answer until its generator is seeded,
  /// early in the life of the system.
  ///
  /// The corresponding C function is `getentropy`.
  @_alwaysEmitIntoClient
  public static func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(Errno) {
    try _fill(buffer).get()
  }

  @usableFromInline
  internal static func _fill(_ buffer: UnsafeMutableRawBufferPointer) -> Result<(), Errno> {
    var offset = 0
    while offset < buffer.count {
      let length = min(buffer.count - offset, 256)
      // getentropy retries its own interruptions.
      let result = nothingOrErrno(retryOnInterrupt: false) {
        system_getentropy(buffer.baseAddress! + offset, length)
      }
      if case .failure = result { return result }
      offset += length
    }
    return .success(())
  }

  /// Returns random bytes.
  ///
  /// - Parameter count: How many bytes to return.
  ///
  /// The corresponding C function is `getentropy`.
  @_alwaysEmitIntoClient
  public static func bytes(count: Int) throws(Errno) -> [UInt8] {
    try _bytes(count: count).get()
  }

  @usableFromInline
  internal static func _bytes(count: Int) -> Result<[UInt8], Errno> {
    var bytes = [UInt8](repeating: 0, count: count)
    return bytes.withUnsafeMutableBytes { _fill($0) }.map { bytes }
  }
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Entropy {
  /// Fills a span with random bytes.
  ///
  /// - Parameter bytes: The bytes to overwrite, of any count.
  ///
  /// The corresponding C function is `getentropy`.
  @_alwaysEmitIntoClient
  public static func fill(_ bytes: inout MutableRawSpan) throws(Errno) {
    try bytes.withUnsafeMutableBytes { _fill($0) }.get()
  }
}

#endif // !os(Windows) && !os(WASI)
