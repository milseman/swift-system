/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 2: cross-platform code that needs platform-specific
// operations, and so switches over a Platform.File.
//
// Two of them:
// - Keeping a file from child processes: FD_CLOEXEC on Unix, the
//   HANDLE_FLAG_INHERIT flag on Windows. One concept, two spellings, so
//   the arms are one line each, and this could join the common subset.
// - An exclusive lock while appending to a shared log. The arms differ in
//   shape, not just name: Unix places and removes a lock in two calls,
//   and Windows scopes one to a closure. The locks also mean different
//   things: Unix's are advisory, and Windows' are mandatory, which
//   `--contend` shows by writing through a second open while the lock is
//   held.

import ArgumentParser
import SystemPackage

struct PlatformLock: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lock",
    abstract: "Append to a shared log under an exclusive lock, switching over Platform.File"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "The log, which is created if needed")
  var path: String

  @Option(help: "The line to append")
  var message = "a record"

  @Flag(help: "While the lock is held, write through a second open of the log")
  var contend = false

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let log = try Platform.File.open(FilePath(path), .readWrite, .openOrCreate)
    print("log: \(log.summary)")

    try keepFromChildren(log)
    print("inheritable by child processes: \(try isInheritable(log) ? "yes" : "no")")

    let record = Array("\(message)\n".utf8)
    if contend {
      let other = try Platform.File.open(FilePath(path), .readWrite)
      print("second open: \(other.summary)")
      try withExclusiveLock(on: log) {
        try log.seek(offset: 0, from: .end)
        try withSpan(of: record) { try log.write($0) }
        do {
          try other.seek(offset: 0, from: .end)
          try withSpan(of: "written by the second open, during the lock\n") { try other.write($0) }
          print("The second open's write succeeded during the lock: the lock is advisory")
        } catch {
          print("The second open's write failed during the lock: \(describe(error))")
          print("  (the lock is mandatory)")
        }
      }
      try other.close()
    } else {
      try appendRecord(record, to: log)
    }
    print("Appended \(record.count) bytes under an exclusive lock")
    try log.close()
  }
}

// MARK: - One concept, two spellings

/// Keeps child processes from inheriting `file`.
func keepFromChildren(_ file: borrowing Platform.File) throws {
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    try owner.fileDescriptor.setDescriptorFlags(.closeOnExec)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    try handle.setInheritable(false)
  #endif
  }
}

/// Whether child processes inherit `file`.
func isInheritable(_ file: borrowing Platform.File) throws -> Bool {
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    return !(try owner.fileDescriptor.descriptorFlags().contains(.closeOnExec))
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    return try handle.isInheritable()
  #endif
  }
}

// MARK: - One concept, two shapes

/// Appends `record` to `log` while holding an exclusive lock on the whole
/// file, written as the switch comes out first: each arm locks and writes
/// in its platform's own way.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func appendRecord(_ record: [UInt8], to log: borrowing Platform.File) throws {
  switch log {
  #if !os(Windows)
  case .fd(let owner):
    // Advisory: it excludes only others that lock too. Two calls, so a
    // failed write has to unlock before it propagates; `defer` would drop
    // the unlock's error, and can't be used to report it.
    try owner.fileDescriptor.lock(.write, wait: true)
    do {
      try owner.seek(offset: 0, from: .end)
      try owner.writeAll(record)
    } catch {
      try? owner.fileDescriptor.unlock()
      throw error
    }
    try owner.fileDescriptor.unlock()
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    // Mandatory: the kernel refuses other handles' reads and writes in the
    // range. Scoped: withLock unlocks when the closure returns or throws,
    // and unlocks exactly the range it locked, as UnlockFileEx requires.
    try handle.withLock {
      try withSpan(of: record) { try handle.append($0) }
    }
  #endif
  }
}

/// Runs `body` while holding an exclusive lock on all of `file`: the switch
/// written once, so that callers' bodies can use the common subset.
///
/// This is where the arms' shapes meet. Windows' lock is a closure, so the
/// Unix arm takes one too. What differs is what the lock means:
/// - Unix: an advisory open file description lock. Others that don't lock
///   aren't stopped, and another open in this process that locks is.
/// - Windows: a mandatory lock. Reads and writes of the range through any
///   other handle fail with lockViolation, in this process or another.
///   A shared lock would even deny this handle's own writes.
/// So a body that's correct under one can fail under the other.
func withExclusiveLock<R>(
  on file: borrowing Platform.File, _ body: () throws -> R
) throws -> R {
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    try owner.fileDescriptor.lock(.write, wait: true)
    let result: R
    do {
      result = try body()
    } catch {
      try? owner.fileDescriptor.unlock()
      throw error
    }
    try owner.fileDescriptor.unlock()
    return result
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    return try handle.withLock(body)
  #endif
  }
}
