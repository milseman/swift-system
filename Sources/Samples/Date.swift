/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct DateSample: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "date",
    abstract: "Print the time as date(1) does, in UTC or local time, and do calendar arithmetic with it"
  )

  @Flag(name: .shortAndLong, help: "Use UTC rather than the local time zone")
  var utc = false

  @Option(name: .shortAndLong, help: "The time to print, in seconds since the epoch, rather than now")
  var seconds: Int?

  @Option(name: .shortAndLong, help: "Days to add to the date, keeping the time of day")
  var days: Int = 0

  @Argument(help: "A strftime format, which begins with +, as date(1)'s does")
  var format: String = "+%a %b %e %H:%M:%S %Z %Y"

  func validate() throws {
    guard format.hasPrefix("+") else {
      throw ValidationError("The format must begin with +, as in +%Y-%m-%d")
    }
  }

  func run() throws {
    let zone: BrokenDownTime.Zone = utc ? .utc : .local
    var time = try BrokenDownTime(secondsSinceEpoch: try seconds ?? now(), in: zone)
    if days != 0 {
      // Add days to the date, and let the conversion carry them into the
      // month and year. The old daylight saving flag may be wrong for the
      // new date, so it's left to the system.
      time.day += days
      time.isDaylightSavingTime = nil
      time = try time.normalized(in: zone)
    }
    print(time.formatted(String(format.dropFirst())))
  }

  private func now() throws -> Int {
    guard #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) else {
      complain("date reads the clock as a Duration, which requires macOS 13 or later; pass --seconds")
      throw ExitCode.failure
    }
    return Int(try ClockID.realtime.currentTime().components.seconds)
  }
}

#else
struct DateSample: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "date",
    abstract: "Unavailable: System has no broken-down time on Windows or WASI"
  )

  func run() throws {
    complain("date isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
