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

struct Touch: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Change files' access and modification times, creating files that don't exist"
  )

  @Argument(help: "The files to touch")
  var paths: [String]

  @Flag(name: .customShort("a"), help: "Change only the access time")
  var accessOnly = false

  @Flag(name: .customShort("m"), help: "Change only the modification time")
  var modificationOnly = false

  @Flag(name: .customShort("c"), help: "Don't create files that don't exist")
  var noCreate = false

  @Option(name: .customShort("r"), help: "Use this file's times, rather than the current time")
  var reference: String?

  func run() throws {
    // With neither -a nor -m, change both times.
    let access = accessOnly || !modificationOnly
    let modification = modificationOnly || !accessOnly
    let referenceStatus = try reference.map { try FilePath($0).stat() }
    // A nil time is left unchanged.
    let accessTime = access ? referenceStatus?.st_atim : nil
    let modificationTime = modification ? referenceStatus?.st_mtim : nil

    for path in paths.map({ FilePath($0) }) {
      print(path)
      print("  before: \(describeTimes(of: path))")
      do {
        if referenceStatus != nil {
          try path.setTimes(access: accessTime, modification: modificationTime)
        } else {
          // Setting both times to the current time needs only write access
          // to the file, but any other change needs ownership.
          try path.setTimesToNow(access: access, modification: modification)
        }
      } catch {
        // A guard rather than `catch Errno.noSuchFileOrDirectory`, which
        // Swift 6.3.3 crashes on in a function with a var, which a string
        // interpolation makes
        // (Prototype/LinuxBuild/Verify/LB1_pattern_catch_with_var.swift).
        guard error == .noSuchFileOrDirectory else { throw error }
        // Like touch(1), -c skips a missing file without an error.
        if !noCreate {
          try create(path, access: accessTime, modification: modificationTime)
        }
      }
      print("  after:  \(describeTimes(of: path))")
    }
  }
}

/// Creates a file, and sets whichever of its times are given.
private func create(_ path: FilePath, access: timespec?, modification: timespec?) throws {
  let fd = try FileDescriptor.open(
    path, .writeOnly, options: .create,
    permissions: [.ownerReadWrite, .groupReadWrite, .otherReadWrite])
  try fd.closeAfter {
    // A new file's times start as the current time.
    try fd.setTimes(access: access, modification: modification)
  }
}

private func describeTimes(of path: FilePath) -> String {
  do {
    let status = try path.stat()
    return "accessed \(format(status.st_atim)), modified \(format(status.st_mtim))"
  } catch {
    return "\(error)"
  }
}

/// Formats a time since the Epoch as a local date and time,
/// to the nanosecond.
private func format(_ time: timespec) -> String {
  var seconds = time.tv_sec
  var date = tm()
  localtime_r(&seconds, &date)
  let dateAndTime = withUnsafeTemporaryAllocation(of: CChar.self, capacity: 32) { buffer in
    _ = strftime(buffer.baseAddress!, buffer.count, "%Y-%m-%d %H:%M:%S", &date)
    return String(cString: buffer.baseAddress!)
  }
  let nanoseconds = String(time.tv_nsec)
  return dateAndTime + "." + String(repeating: "0", count: 9 - nanoseconds.count) + nanoseconds
}
