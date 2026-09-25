/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: helpers that the platform samples share.

import SystemPackage

/// Calls `body` with `bytes` as a RawSpan.
///
/// `Array.span` needs macOS 26, and System's span I/O needs macOS 15, so
/// this goes through `withUnsafeBytes`, as System's tests do.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func withSpan<R>(of bytes: [UInt8], _ body: (RawSpan) throws -> R) rethrows -> R {
  try bytes.withUnsafeBytes { try body(RawSpan(_unsafeBytes: $0)) }
}

/// Calls `body` with the UTF-8 bytes of `text` as a RawSpan.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func withSpan<R>(of text: String, _ body: (RawSpan) throws -> R) rethrows -> R {
  try withSpan(of: Array(text.utf8), body)
}

/// A description of an error from either platform, with its code.
func describe(_ error: any Error) -> String {
  #if os(Windows) || SIMULATE_PLATFORMS
  if let error = error as? Win32.Error { return error.debugDescription }
  #endif
  if let error = error as? Errno { return "\(error) (errno \(error.rawValue))" }
  return "\(error)"
}
