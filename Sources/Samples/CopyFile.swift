/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN

struct CopyFile: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "copyfile",
    abstract: "Copy or clone files with copyfile or clonefile, reporting what each one did"
  )

  @Argument(help: "The file or directory to copy")
  var source: String

  @Argument(help: "Where to copy it, which mustn't exist")
  var destination: String

  @Flag(help: "Copy a directory and everything in it")
  var recursive = false

  @Flag(help: "Clone files where the file system can, and copy the rest")
  var clone = false

  @Flag(help: "Clone with clonefile, which fails where the file system can't clone")
  var clonefile = false

  @Option(help: "Stop the copy once it has copied this many bytes of data")
  var limit: Int64?

  func validate() throws {
    if clonefile && (clone || recursive || limit != nil) {
      throw ValidationError("--clonefile can't be combined with other options")
    }
  }

  func run() throws {
    let source = FilePath(source)
    let destination = FilePath(destination)
    if clonefile {
      do {
        try source.clone(to: destination)
      } catch Errno.notSupported {
        complain("Error: the file system can't clone \(source); try --clone, which copies instead")
        throw ExitCode.failure
      }
      print("Cloned \(source) to \(destination) with clonefile")
      return
    }

    // Everything, without replacing anything.
    var options: FilePath.CopyOptions = [.all, .exclusive]
    if recursive { options.insert(.recursive) }
    if clone { options.insert(.clone) }

    var state = FilePath.CopyState()
    var tally = Tally()
    do {
      try source.copy(to: destination, options: options, state: &state) { progress in
        tally.record(progress, limit: limit)
      }
    } catch Errno.canceled {
      complain("Stopped after copying \(amount(tally.bytes)) of data, leaving what was copied")
      throw ExitCode.failure
    } catch Errno.fileExists {
      complain("Error: \(destination) exists, and copyfile won't replace it")
      throw ExitCode.failure
    }

    if recursive {
      // A recursive copy reports each file; the state describes none of them.
      print("Copied \(tally.files) files and \(tally.directories) directories: "
        + "\(tally.cloned) cloned, \(amount(tally.bytes)) of data copied")
    } else if state.wasCloned {
      print("Cloned \(source) to \(destination)")
    } else {
      print("Copied \(source) to \(destination): \(amount(state.copiedByteCount)) of data, "
        + "reported \(tally.dataReports) times as it went")
    }
  }
}

/// What a copy has reported so far.
private struct Tally {
  var files = 0
  var directories = 0
  var cloned = 0
  var dataReports = 0
  var bytes: Int64 = 0
  // Bytes from files that have finished, since a file's count restarts at 0.
  var finishedBytes: Int64 = 0

  mutating func record(
    _ progress: FilePath.CopyProgress, limit: Int64?
  ) -> FilePath.CopyProgress.Action {
    switch (progress.kind, progress.stage) {
    case (.file, .finish):
      files += 1
      finishedBytes += progress.copiedByteCount
      bytes = finishedBytes
      if progress.wasCloned { cloned += 1 }
      let how = progress.wasCloned ? "cloned" : "copied \(amount(progress.copiedByteCount))"
      print("  \(how): \(progress.source.map { "\($0)" } ?? "?")")
    case (.directory, .start):
      directories += 1
    case (.data, .progress):
      dataReports += 1
      bytes = finishedBytes + progress.copiedByteCount
    case (_, .error):
      print("  error: \(progress.source.map { "\($0)" } ?? "?"): "
        + "\(progress.error.map { "\($0)" } ?? "unknown")")
    default:
      break
    }
    if let limit, bytes > limit { return .quit }
    return .continue
  }
}

#else

struct CopyFile: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "copyfile",
    abstract: "Unavailable: this platform has no copyfile or clonefile"
  )

  func run() throws {
    complain("Error: copyfile needs Darwin's copyfile and clonefile")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
