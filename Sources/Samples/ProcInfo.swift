/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if os(macOS)

struct ProcInfo: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "proc-info",
    abstract: "Measure a workload with the kernel's per-process accounting, or show other processes'"
  )

  @Argument(help: "Processes to show, rather than measuring a workload in this one")
  var processes: [Int32] = []

  func run() throws {
    // The times are Durations, which need macOS 13.
    guard #available(macOS 13, *) else {
      complain("Error: proc-info needs macOS 13 or later")
      throw ExitCode.failure
    }
    guard processes.isEmpty else {
      for id in processes.map({ ProcessID(rawValue: $0) }) {
        do {
          let snapshot = try Snapshot(id)
          print("Process \(id.rawValue):")
          printTable(rows.map { [$0.name, $0.value(snapshot).formatted] })
        } catch {
          // Another user's process needs privileges.
          print("Process \(id.rawValue): \(error)")
        }
      }
      return
    }

    let current = ProcessID.current
    let before = try Snapshot(current)
    let spun = spin(for: .milliseconds(200))
    // Filling the array touches every page, so they count as resident.
    let memory = [UInt8](repeating: 1, count: 64 << 20)
    let null = try FileDescriptor.open("/dev/null", .writeOnly)
    try null.closeAfter {
      for _ in 0..<1000 { _ = try [UInt8(0)].withUnsafeBytes { try null.write($0) } }
    }
    let after = try Snapshot(current)
    withExtendedLifetime(memory) {}

    print("Process \(current.rawValue), around a workload: \(spun) passes of a 200 ms loop, "
      + "64 MiB filled, and 1000 one-byte writes to /dev/null")
    printTable([["", "before", "after", "change"]] + rows.map { row in
      let (old, new) = (row.value(before), row.value(after))
      return [row.name, old.formatted, new.formatted, new.change(from: old)]
    })
  }
}

/// The accounting information for a process at one moment.
@available(macOS 13, *)
private struct Snapshot {
  var task: ProcessID.TaskInfo
  var usage: ProcessID.ResourceUsageInfo

  init(_ id: ProcessID) throws(Errno) {
    task = try id.taskInfo()
    usage = try id.resourceUsageInfo()
  }
}

/// A measurement, which formats itself and its change from another.
@available(macOS 13, *)
private enum Value {
  case time(Duration)
  case bytes(UInt64)
  case count(UInt64)

  var formatted: String {
    switch self {
    case .time(let time): return milliseconds(time)
    case .bytes(let bytes): return mebibytes(Int64(bytes))
    case .count(let count): return "\(count)"
    }
  }

  func change(from old: Value) -> String {
    switch (old, self) {
    case (.time(let old), .time(let new)):
      return (new < old ? "-" : "+") + milliseconds(new < old ? old - new : new - old)
    case (.bytes(let old), .bytes(let new)):
      let change = Int64(bitPattern: new &- old)
      return (change < 0 ? "-" : "+") + mebibytes(change.magnitude)
    case (.count(let old), .count(let new)):
      let change = Int64(bitPattern: new &- old)
      return change < 0 ? "\(change)" : "+\(change)"
    default:
      return ""
    }
  }
}

// The rows come from both kinds of information: proc_pidinfo's task
// information and proc_pid_rusage's resource usage.
@available(macOS 13, *)
private var rows: [(name: String, value: (Snapshot) -> Value)] {
  [
    ("user time", { .time($0.usage.userTime) }),
    ("system time", { .time($0.usage.systemTime) }),
    ("instructions", { .count($0.usage.instructions) }),
    ("cycles", { .count($0.usage.cycles) }),
    ("energy (nJ)", { .count($0.usage.energy) }),
    ("resident size", { .bytes($0.task.residentSize) }),
    ("physical footprint", { .bytes($0.usage.physicalFootprint) }),
    ("peak physical footprint", { .bytes($0.usage.lifetimeMaxPhysicalFootprint) }),
    ("page faults", { .count(UInt64($0.task.faults)) }),
    ("BSD system calls", { .count(UInt64($0.task.unixSystemCalls)) }),
    ("Mach traps", { .count(UInt64($0.task.machSystemCalls)) }),
    ("context switches", { .count(UInt64($0.task.contextSwitches)) }),
    ("threads", { .count(UInt64($0.task.threadCount)) }),
  ]
}

/// Keeps a processor busy for a while, and returns the number of passes.
@available(macOS 13, *)
private func spin(for duration: Duration) -> Int {
  let clock = ContinuousClock()
  let end = clock.now + duration
  var passes = 0
  while clock.now < end { passes += 1 }
  return passes
}

@available(macOS 13, *)
private func milliseconds(_ time: Duration) -> String {
  let (seconds, attoseconds) = time.components
  return "\(seconds * 1000 + attoseconds / 1_000_000_000_000_000) ms"
}

private func mebibytes(_ bytes: some BinaryInteger) -> String {
  let tenths = Int64(bytes) * 10 / (1 << 20)
  return "\(tenths / 10).\(tenths % 10) MiB"
}

#else

struct ProcInfo: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "proc-info",
    abstract: "Unavailable: this platform has no libproc"
  )

  func run() throws {
    complain("Error: proc-info needs proc_pidinfo and proc_pid_rusage, which only macOS has")
    throw ExitCode.failure
  }
}

#endif // os(macOS)
