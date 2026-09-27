/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin

struct MachTime: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mach-time",
    abstract: "Show the Mach clocks: the timebase, time awake and asleep since boot, and this process's age"
  )

  @Option(help: "Milliseconds to sleep, measured with both clocks")
  var sleep: Int = 100

  func run() throws {
    // Durations need macOS 13.
    guard #available(macOS 13, *) else {
      complain("Error: mach-time needs macOS 13 or later")
      throw ExitCode.failure
    }
    let timebase = Mach.Timebase.current
    let tick = Double(timebase.numerator) / Double(timebase.denominator)
    print("Timebase: \(timebase.numerator)/\(timebase.denominator), "
      + "so a tick is \((tick * 1000).rounded() / 1000) ns")

    // The absolute clock stops while the system sleeps; the continuous one
    // doesn't, so their difference is the time spent asleep.
    let awake = timebase.duration(ofTicks: Mach.AbsoluteTime.now.rawValue)
    let sinceBoot = timebase.duration(ofTicks: Mach.ContinuousTime.now.rawValue)
    printTable([
      ["since boot", describe(sinceBoot)],
      ["awake", describe(awake)],
      ["asleep", describe(sinceBoot - awake)],
    ])

    #if os(macOS)
    // The kernel reports when a process started, in absolute time.
    let started = try ProcessID.current.resourceUsageInfo().startAbsoluteTime
    print("This process started \(Mach.AbsoluteTime(rawValue: started).duration(to: .now)) ago")
    #endif

    let start = Mach.AbsoluteTime.now
    let approximateStart = Mach.AbsoluteTime.approximateNow
    usleep(UInt32(sleep) * 1000)
    let precise = start.duration(to: .now)
    let approximate = approximateStart.duration(to: .approximateNow)
    print("Slept \(sleep) ms: \(precise) by mach_absolute_time, "
      + "\(approximate) by mach_approximate_time")
  }
}

/// Formats a duration in days, hours, minutes, and seconds.
@available(macOS 13, *)
private func describe(_ duration: Duration) -> String {
  let seconds = duration.components.seconds
  let days = seconds / 86400
  return (days > 0 ? "\(days)d " : "")
    + "\(seconds / 3600 % 24)h \(seconds / 60 % 60)m \(seconds % 60)s"
}

#else

struct MachTime: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mach-time",
    abstract: "Unavailable: this platform has no Mach clocks"
  )

  func run() throws {
    complain("Error: mach-time needs Darwin's Mach clocks")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
