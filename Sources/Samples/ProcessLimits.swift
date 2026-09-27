/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Shows the process's resource limits, as `ulimit -a` does, and optionally
// raises its soft limit on open files to its hard limit, as a server or a
// test runner that opens many descriptors does. Older releases of macOS
// reject a soft limit above OPEN_MAX, so there it falls back to OPEN_MAX.
//
//     $ swift run system-samples process-limits --raise-open-files
//       resource           soft       hard
//       cpu time           unlimited  unlimited
//       ...
//       open files         256        unlimited
//       ...
//     raised the soft limit on open files from 256 to unlimited

#if !os(Windows) && !os(WASI)

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#endif

struct ProcessLimits: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-limits",
    abstract: "Show resource limits, and raise the soft limit on open files"
  )

  @Flag(help: "Raise the soft limit on open files to the hard limit")
  var raiseOpenFiles = false

  func run() throws {
    var resources: [(String, ResourceLimit.Resource)] = [
      ("cpu time", .cpuTime), ("file size", .fileSize), ("data size", .dataSize),
      ("stack size", .stackSize), ("core file size", .coreFileSize),
      ("resident set size", .residentSetSize), ("processes", .processes),
      ("open files", .openFiles), ("locked memory", .lockedMemory),
      ("address space", .addressSpace),
    ]
    #if os(Linux) || os(Android)
    resources += [
      ("file locks", .fileLocks), ("pending signals", .pendingSignals),
      ("message queue bytes", .messageQueueBytes), ("nice ceiling", .niceCeiling),
      ("real-time priority", .realTimePriority), ("real-time cpu time", .realTimeCPUTime),
    ]
    #endif
    var rows = [["resource", "soft", "hard"]]
    for (name, resource) in resources {
      let limit = try ResourceLimit.current(for: resource)
      rows.append([name, limit.soft.description, limit.hard.description])
    }
    printTable(rows)

    guard raiseOpenFiles else { return }
    var limit = try ResourceLimit.current(for: .openFiles)
    let previous = limit.soft
    guard previous < limit.hard else {
      print("the soft limit on open files is already the hard limit, \(previous)")
      return
    }
    limit.soft = limit.hard
    do {
      try ResourceLimit.setCurrent(limit, for: .openFiles)
    } catch Errno.invalidArgument {
      #if SYSTEM_PACKAGE_DARWIN
      // Older releases of macOS reject a soft limit above OPEN_MAX.
      limit.soft = ResourceLimit.Value(rawValue: rlim_t(OPEN_MAX))
      guard previous < limit.soft else { return }
      try ResourceLimit.setCurrent(limit, for: .openFiles)
      #else
      throw Errno.invalidArgument
      #endif
    }
    print("raised the soft limit on open files from \(previous) to \(limit.soft)")
  }
}

#else

import ArgumentParser

struct ProcessLimits: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-limits",
    abstract: "Unavailable: this platform has no resource limits"
  )

  func run() throws {
    complain("Error: process-limits needs getrlimit, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI)
