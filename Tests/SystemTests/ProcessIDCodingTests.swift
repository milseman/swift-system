//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows) && canImport(Foundation)

import Foundation
import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// ProcessID gets its Codable conformance from the standard library's
// RawRepresentable defaults, so it encodes as its raw value alone.
// These tests pin that format.
@Suite("ProcessID coding")
private struct ProcessIDCodingTests {

  @Test func encodesAsABareInteger() throws {
    let single = try JSONEncoder().encode(ProcessID(42))
    #expect(String(decoding: single, as: UTF8.self) == "42")

    let array = try JSONEncoder().encode([ProcessID(1), ProcessID(-1)])
    #expect(String(decoding: array, as: UTF8.self) == "[1,-1]")
  }

  @Test func decodesFromABareInteger() throws {
    #expect(try JSONDecoder().decode(ProcessID.self, from: Data("-7".utf8)) == ProcessID(-7))
    #expect(
      try JSONDecoder().decode([ProcessID].self, from: Data("[2,3]".utf8))
        == [ProcessID(2), ProcessID(3)])
  }

  @Test func roundTripsTheFullRange() throws {
    let values = [CInterop.ProcessID.min, -1, 0, 1, CInterop.ProcessID.max].map { ProcessID($0) }
    let data = try JSONEncoder().encode(values)
    #expect(try JSONDecoder().decode([ProcessID].self, from: data) == values)
  }

  @Test func rejectsValuesOutsideTheRawType() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProcessID.self, from: Data("4294967296".utf8))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProcessID.self, from: Data("1.5".utf8))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProcessID.self, from: Data(#"{"rawValue":42}"#.utf8))
    }
  }

  #if !os(WASI)
  @Test func currentRoundTrips() throws {
    let data = try JSONEncoder().encode(ProcessID.current)
    #expect(String(decoding: data, as: UTF8.self) == "\(ProcessID.current.rawValue)")
    #expect(try JSONDecoder().decode(ProcessID.self, from: data) == .current)
  }
  #endif // !os(WASI)
}

#endif // !os(Windows) && canImport(Foundation)
