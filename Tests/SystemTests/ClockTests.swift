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

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@Suite("Clocks")
private struct ClockTests {
  @available(System 199, *)
  static var clocks: [(String, ClockID)] {
    var clocks: [(String, ClockID)] = [
      ("realtime", .realtime), ("monotonic", .monotonic),
      ("processCPUTime", .processCPUTime), ("threadCPUTime", .threadCPUTime),
    ]
    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
    clocks.append(("monotonicRaw", .monotonicRaw))
    #endif
    #if SYSTEM_PACKAGE_DARWIN
    clocks += [
      ("monotonicRawApproximate", .monotonicRawApproximate),
      ("uptimeRaw", .uptimeRaw), ("uptimeRawApproximate", .uptimeRawApproximate),
    ]
    #endif
    #if os(Linux) || os(Android)
    clocks += [
      ("boottime", .boottime), ("realtimeCoarse", .realtimeCoarse),
      ("monotonicCoarse", .monotonicCoarse), ("tai", .tai),
    ]
    #endif
    return clocks
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func everyClockReads() throws {
    for (name, clock) in Self.clocks {
      let time = try clock.currentTime()
      #expect(time >= .zero, "\(name)")
      let resolution = try clock.resolution()
      #expect(resolution > .zero && resolution <= .seconds(1), "\(name): \(resolution)")
    }
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func realtimeIsTheTimeSinceTheEpoch() throws {
    let before = time(nil)
    let now = try ClockID.realtime.currentTime()
    let after = time(nil)
    #expect(now.components.seconds >= Int64(before))
    #expect(now.components.seconds <= Int64(after))
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func monotonicDoesntGoBackward() throws {
    var previous = try ClockID.monotonic.currentTime()
    for _ in 0..<1000 {
      let next = try ClockID.monotonic.currentTime()
      #expect(next >= previous)
      previous = next
    }
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func threadCPUTimeCountsWork() throws {
    let start = try ClockID.threadCPUTime.currentTime()
    var sum = 0
    // Spin until the clock moves, which it does within a few ticks.
    while try ClockID.threadCPUTime.currentTime() == start {
      for i in 0..<10_000 { sum &+= i }
    }
    #expect(try ClockID.threadCPUTime.currentTime() > start)
    #expect(sum != 1)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func aClockTheSystemDoesntHaveThrows() {
    #if SYSTEM_PACKAGE_DARWIN
    let missing = ClockID(rawValue: clockid_t(rawValue: 9999))
    #else
    let missing = ClockID(rawValue: 9999)
    #endif
    #expect(throws: Errno.invalidArgument) { try missing.currentTime() }
    #expect(throws: Errno.invalidArgument) { try missing.resolution() }
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func sleepLastsAtLeastItsDuration() throws {
    for duration in [Duration.milliseconds(20), .microseconds(1500)] {
      let start = try ClockID.monotonic.currentTime()
      try PThread.sleep(for: duration)
      #expect(try ClockID.monotonic.currentTime() - start >= duration)
    }
    // Nothing to sleep for returns right away.
    try PThread.sleep(for: .zero)
    try PThread.sleep(for: .seconds(-5))
  }
}

#endif // !os(Windows) && !os(WASI)
