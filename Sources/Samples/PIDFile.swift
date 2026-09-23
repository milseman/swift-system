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
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

struct PIDFile: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pid-file",
    abstract: "Record this process's ID in a PID file, as a daemon does"
  )

  @Argument(help: "The PID file to create")
  var path: String

  @Option(name: .long, help: "Seconds to keep running before removing the file")
  var hold: UInt32 = 0

  func run() throws {
    let current = ProcessID.current
    print("This is process \(current.rawValue), and its parent is \(ProcessID.parent.rawValue)")

    let file = FilePath(path)
    while true {
      do {
        try create(file, recording: current)
        break
      } catch Errno.fileExists {
        // Another process wrote the file. If it's gone, the file is stale.
        let owner = try recordedProcess(in: file)
        guard !isRunning(owner) else {
          complain("\(path) belongs to process \(owner.rawValue), which is still running")
          throw ExitCode.failure
        }
        print("Removing \(path), left by process \(owner.rawValue), which is no longer running")
        try remove(file)
      }
    }
    print("Wrote \(path)")

    guard hold > 0 else { return }
    print("Holding it for \(hold) seconds...")
    sleep(hold)
    // Remove the file only if it's still this process's.
    if try recordedProcess(in: file) == current {
      try remove(file)
      print("Removed \(path)")
    }
  }
}

/// Creates a PID file that records `process`, failing if the file exists.
private func create(_ path: FilePath, recording process: ProcessID) throws {
  let fd = try FileDescriptor.open(
    path, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
  try fd.closeAfter {
    // `open` applies the process's umask to the permissions it's given;
    // `setPermissions` sets them exactly.
    try fd.setPermissions([.ownerReadWrite, .groupRead, .otherRead])
    try fd.writeAll("\(process.rawValue)\n".utf8)
    // Flush the file to storage, so that a crash can't leave it empty.
    try fd.synchronize()
  }
}

/// Reads the process ID recorded in a PID file.
private func recordedProcess(in path: FilePath) throws -> ProcessID {
  let fd = try FileDescriptor.open(path, .readOnly)
  let text = try fd.closeAfter {
    try [UInt8](unsafeUninitializedCapacity: 32) { buffer, count in
      count = try fd.read(into: UnsafeMutableRawBufferPointer(buffer))
    }
  }
  guard let digits = String(decoding: text, as: UTF8.self)
    .split(whereSeparator: \.isWhitespace).first,
    let raw = CInterop.ProcessID(digits)
  else {
    throw ValidationError("\(path) doesn't contain a process ID")
  }
  return ProcessID(rawValue: raw)
}

/// Whether a process with the given ID exists.
private func isRunning(_ process: ProcessID) -> Bool {
  // Signal 0 checks for the process without sending anything. EPERM means
  // the process exists but belongs to someone else.
  kill(process.rawValue, 0) == 0 || errno == EPERM
}

private func remove(_ path: FilePath) throws {
  guard path.withPlatformString({ unlink($0) }) == 0 else {
    throw Errno(rawValue: errno)
  }
}
