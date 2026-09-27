/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Entropy")
private struct EntropyTests {
  @available(System 199, *)
  @Test func bytesAreRandom() throws {
    let first = try Entropy.bytes(count: 32)
    let second = try Entropy.bytes(count: 32)
    #expect(first.count == 32)
    // Each check fails by chance with a probability of 2^-256.
    #expect(first != [UInt8](repeating: 0, count: 32))
    #expect(first != second)
    #expect(try Entropy.bytes(count: 0) == [])
  }

  /// More than one call's worth, the most being 256 bytes.
  @available(System 199, *)
  @Test func fillsMoreThanOneCallsWorth() throws {
    var buffer = [UInt8](repeating: 0, count: 1000)
    try buffer.withUnsafeMutableBytes { try Entropy.fill($0) }
    for chunk in stride(from: 0, to: 1000, by: 256) {
      #expect(buffer[chunk..<min(chunk + 256, 1000)].contains { $0 != 0 }, "chunk at \(chunk)")
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func fillsASpan() throws {
    var bytes = ContiguousArray<UInt8>(repeating: 0, count: 64)
    do {
      var span = bytes.mutableSpan
      var raw = span.mutableBytes
      try Entropy.fill(&raw)
    }
    #expect(bytes.contains { $0 != 0 })
  }
}

#endif // !os(Windows) && !os(WASI)
