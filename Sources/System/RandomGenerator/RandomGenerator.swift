/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)

// The C library's random number generator, arc4random's: a
// cryptographically secure generator in the process, which the system's
// generator seeds and reseeds. Unlike getentropy's calls, which read the
// system's generator directly, its calls can't fail and have no size
// limit. The standard library's SystemRandomNumberGenerator reads it on
// these platforms.

@available(System 199, *)
extension Entropy {
  /// Returns a random 32-bit number
  /// from the C library's random number generator.
  ///
  /// The C library's generator is cryptographically secure,
  /// and the system's generator seeds it;
  /// unlike the methods that call `getentropy`, it can't fail.
  ///
  /// The corresponding C function is `arc4random`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, OpenBSD, and Android.
  @_alwaysEmitIntoClient
  public static func generate() -> UInt32 {
    _generate()
  }

  @usableFromInline
  internal static func _generate() -> UInt32 {
    system_arc4random()
  }

  /// Returns a random number less than an upper bound,
  /// with every value from zero up to the bound equally likely,
  /// from the C library's random number generator.
  ///
  /// - Parameter upperBound: The bound. A bound of 0 or 1 returns 0.
  ///
  /// Taking a random number modulo the bound would make the smaller values
  /// more likely; this method doesn't.
  ///
  /// The corresponding C function is `arc4random_uniform`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, OpenBSD, and Android.
  @_alwaysEmitIntoClient
  public static func generate(below upperBound: UInt32) -> UInt32 {
    _generate(below: upperBound)
  }

  @usableFromInline
  internal static func _generate(below upperBound: UInt32) -> UInt32 {
    system_arc4random_uniform(upperBound)
  }

  /// Fills a buffer with random bytes
  /// from the C library's random number generator.
  ///
  /// - Parameter buffer: The buffer to fill, of any size.
  ///
  /// Unlike ``fill(_:)-(UnsafeMutableRawBufferPointer)``,
  /// which reads the system's generator,
  /// this method can't fail, and needs only one call for any size.
  ///
  /// The corresponding C function is `arc4random_buf`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, OpenBSD, and Android.
  @_alwaysEmitIntoClient
  public static func generate(into buffer: UnsafeMutableRawBufferPointer) {
    _generate(into: buffer)
  }

  @usableFromInline
  internal static func _generate(into buffer: UnsafeMutableRawBufferPointer) {
    system_arc4random_buf(buffer.baseAddress, buffer.count)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)
