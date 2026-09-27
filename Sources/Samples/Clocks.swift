/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Clocks: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clocks",
    abstract: "Read each of the system's clocks, and time a sleep and some work with them"
  )

  @Option(name: .shortAndLong, help: "How long to sleep, in milliseconds")
  var milliseconds: Int = 50

  func run() throws {
    guard #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) else {
      complain("clocks uses Duration, which requires macOS 13 or later")
      throw ExitCode.failure
    }
    try readClocks()
    try timeASleep()
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private func readClocks() throws {
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

    var rows = [["clock", "time", "resolution"]]
    for (name, clock) in clocks {
      do {
        rows.append([name, format(try clock.currentTime()), format(try clock.resolution())])
      } catch {
        rows.append([name, "\(error)", ""])
      }
    }
    printTable(rows)
    // The wall clock counts from 1970; the others count from a moment
    // of their own, such as when the system started.
    let uptime = try ClockID.monotonic.currentTime()
    print("The monotonic clock started \(format(uptime, units: true)) ago")
    #if SYSTEM_PACKAGE_DARWIN
    // Darwin's monotonic clock counts while the system sleeps,
    // and its uptime clock doesn't.
    let asleep = uptime - (try ClockID.uptimeRaw.currentTime())
    print("The system has been asleep for \(format(asleep, units: true)) of that")
    #endif
  }

  /// Sleeps, then spins, measuring each with the monotonic clock
  /// and the process's processor time: a sleep takes no processor time.
  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private func timeASleep() throws {
    let requested = Duration.milliseconds(milliseconds)
    var (elapsed, cpu) = try measure { try PThread.sleep(for: requested) }
    print("Slept for \(format(requested, units: true)):"
      + " \(format(elapsed, units: true)) passed, using \(format(cpu, units: true)) of processor time")

    var sum = 0
    (elapsed, cpu) = try measure {
      let end = try ClockID.monotonic.currentTime() + requested
      while try ClockID.monotonic.currentTime() < end { sum &+= 1 }
    }
    print("Spun for \(format(requested, units: true)):"
      + " \(format(elapsed, units: true)) passed, using \(format(cpu, units: true)) of processor time"
      + " (\(sum) reads of the clock)")
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private func measure(_ body: () throws -> Void) throws -> (elapsed: Duration, cpu: Duration) {
    let (start, startCPU) = (try ClockID.monotonic.currentTime(), try ClockID.processCPUTime.currentTime())
    try body()
    return (try ClockID.monotonic.currentTime() - start,
            try ClockID.processCPUTime.currentTime() - startCPU)
  }
}

/// Formats a duration as seconds with nine decimal places,
/// or, with `units`, in the largest unit that keeps it above one.
@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
private func format(_ duration: Duration, units: Bool = false) -> String {
  let (seconds, attoseconds) = duration.components
  let nanoseconds = attoseconds / 1_000_000_000
  guard units else {
    let fraction = String(nanoseconds)
    return "\(seconds).\(String(repeating: "0", count: 9 - fraction.count))\(fraction)"
  }
  let total = Double(seconds) + Double(nanoseconds) / 1e9
  for (unit, scale) in [("s", 1.0), ("ms", 1e-3), ("µs", 1e-6)] where total >= scale {
    return "\((total / scale * 10).rounded() / 10) \(unit)"
  }
  return "\(nanoseconds) ns"
}

#else
struct Clocks: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clocks",
    abstract: "Unavailable: System has no clock API on Windows or WASI"
  )

  func run() throws {
    complain("clocks isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
