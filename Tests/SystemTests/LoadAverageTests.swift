/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Load average")
private struct LoadAverageTests {
  // Reads the system's averages, which only change.
  @available(System 199, *)
  @Test func theSystemsLoadAverage() throws {
    let load = try LoadAverage.current()
    for average in [load.oneMinute, load.fiveMinutes, load.fifteenMinutes] {
      #expect(average.isFinite && average >= 0)
    }
  }

  @available(System 199, *)
  @Test func averagesInOrder() {
    let load = LoadAverage(oneMinute: 1.5, fiveMinutes: 0.75, fifteenMinutes: 0.25)
    #expect([load.oneMinute, load.fiveMinutes, load.fifteenMinutes] == [1.5, 0.75, 0.25])
    #expect(load == LoadAverage(oneMinute: 1.5, fiveMinutes: 0.75, fifteenMinutes: 0.25))
    #expect(load != LoadAverage(oneMinute: 1.5, fiveMinutes: 0.75, fifteenMinutes: 0))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)
