/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library's call-stack functions, <execinfo.h>.
//
// System wraps backtrace and backtrace_symbols provisionally. They're the C
// library's, not operating-system interfaces, and the standard library's
// runtime has a backtracer of its own, which is where these would belong.
// Until then, code that reports its own call stack, as Foundation's
// Thread.callStackReturnAddresses and callStackSymbols do, can do it
// without importing the C library. Darwin only for now: glibc has them
// too, and musl doesn't.

#if SYSTEM_PACKAGE_DARWIN

import Darwin

/// A namespace for the C library's call-stack functions:
/// the return addresses of the calling thread's frames, and their symbols.
///
///     let addresses = CallStack.returnAddresses()
///     for line in try CallStack.symbols(for: addresses) { print(line) }
///
/// - Note: Provisional: call-stack functions may move to the Swift standard library.
/// - Note: Only available on Darwin.
@available(System 199, *)
public enum CallStack {}

@available(System 199, *)
extension CallStack {
  /// Returns the return addresses of the calling thread's stack frames,
  /// innermost first.
  ///
  /// - Parameter maxCount: The most frames to return.
  ///   The default is 128.
  /// - Returns: An address in each frame's code, from this method's own
  ///   frame outward, for up to `maxCount` frames.
  ///
  /// The corresponding C function is `backtrace`.
  ///
  /// - Note: Provisional: call-stack functions may move to the Swift standard library.
  @inline(never)
  public static func returnAddresses(maxCount: Int = 128) -> [UnsafeRawPointer] {
    precondition(maxCount >= 0, "CallStack.returnAddresses(maxCount:): 'maxCount' must not be negative")
    let count = CInt(clamping: maxCount)
    let buffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(count))
    defer { buffer.deallocate() }
    let found = system_backtrace(buffer, count)
    return UnsafeBufferPointer(start: buffer, count: Int(max(found, 0))).compactMap {
      $0.map(UnsafeRawPointer.init)
    }
  }

  /// Returns a line describing each of a list of code addresses:
  /// its frame's number, the image that contains it, the address,
  /// and its symbol and offset, as the C library formats them.
  ///
  /// - Parameter addresses: Addresses in code, such as the ones
  ///   ``returnAddresses(maxCount:)`` returns.
  /// - Returns: A line for each address, in order.
  ///
  /// If there isn't enough memory for the lines, this method throws
  /// ``Errno/noMemory``.
  ///
  /// The corresponding C function is `backtrace_symbols`.
  ///
  /// - Note: Provisional: call-stack functions may move to the Swift standard library.
  public static func symbols(for addresses: [UnsafeRawPointer]) throws(Errno) -> [String] {
    guard !addresses.isEmpty else { return [] }
    var frames = addresses.map { UnsafeMutableRawPointer(mutating: $0) as UnsafeMutableRawPointer? }
    guard let lines = frames.withUnsafeMutableBufferPointer({
      system_backtrace_symbols($0.baseAddress!, CInt(clamping: $0.count))
    }) else {
      throw .noMemory
    }
    defer { system_free(lines) }
    return (0..<addresses.count).map { lines[$0].map { String(cString: $0) } ?? "" }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
