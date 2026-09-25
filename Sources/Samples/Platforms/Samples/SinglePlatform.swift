/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 3: single-platform code, which uses each platform's own
// types and never touches the multi-platform enums. Neither sample below
// mentions `Platform`. The enum layer costs code that ignores it nothing: no
// switch, no escape hatch, and every platform-only operation is a method
// call away.
//
// - `darwin-only` is real: OwnedFD and FileDescriptor, with Darwin-only
//   operations (F_GETPATH, F_FULLFSYNC, F_NOCACHE).
// - `windows-only` is Win32.FileHandle as the drafts propose it, which
//   compiles here only in the simulated build. It uses operations Unix has
//   no counterpart for: an exclusive share mode and the sharing violation
//   it causes, `openOrCreate`'s report of whether the file existed, scoped
//   mandatory locks, and volume information.

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN

struct PlatformDarwinOnly: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "darwin-only",
    abstract: "Append to a journal with Darwin's own API: OwnedFD and FileDescriptor, no enum"
  )

  @Argument(help: "The journal, which is created if needed")
  var path: String

  func run() throws {
    let journal = try OwnedFD.open(
      FilePath(path), .readWrite, options: [.create, .append, .closeOnExec],
      permissions: .ownerReadWrite)
    let descriptor = journal.fileDescriptor

    // Darwin-only: don't keep the journal's pages in the buffer cache.
    try descriptor.setNoCache(true)

    // An open file description lock: advisory, and released with unlock()
    // or when the last descriptor for the open file closes.
    try descriptor.lock(.write, wait: true)
    do {
      try journal.writeAll("entry from process \(ProcessID.current.rawValue)\n".utf8)
      // Darwin-only: F_FULLFSYNC, which fsync isn't.
      try descriptor.synchronizeFully()
    } catch {
      try? descriptor.unlock()
      throw error
    }
    try descriptor.unlock()

    let status = try descriptor.stat()
    // Darwin-only: F_GETPATH, the path as it is now, after any rename.
    print("\(try descriptor.path()): inode \(status.inode.rawValue), \(status.size) bytes")
    print("standard input is \(FileDescriptor.standardInput.isTerminal ? "" : "not ")a terminal")
    try journal.close()
  }
}

#else

struct PlatformDarwinOnly: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "darwin-only",
    abstract: "Unavailable: this sample uses Darwin-only file API"
  )

  @Argument(help: "The journal")
  var path: String

  func run() throws {
    complain("Error: darwin-only uses F_GETPATH, F_FULLFSYNC, and F_NOCACHE, which only Darwin has")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN

#if os(Windows) || SIMULATE_PLATFORMS

struct PlatformWindowsOnly: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "windows-only",
    abstract: "Append to a journal with the Win32 drafts' own API: Win32.FileHandle, no enum"
  )

  @Argument(help: "The journal, which is created if needed")
  var path: String

  func run() throws {
    print("[simulated build: Win32 is the stand-ins in Platforms/StandIns]")
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    try appendEntry()
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func appendEntry() throws {
    // Exclusive access: no other open may read, write, or delete the file
    // while this handle is alive. Windows-only; POSIX open has no share mode.
    let opened = try Win32.FileHandle.openOrCreate(
      FilePath(path), access: [.genericRead, .genericWrite], shareMode: [])
    print(opened.existed ? "Opened the existing journal" : "Created the journal")
    let journal = opened.handle

    // Another open is refused, with a code that's worth retrying later.
    if try secondOpenIsRefused() {
      print("A second open failed with \(Win32.Error.sharingViolation.debugDescription): retry later")
    } else {
      print("A second open succeeded")
    }

    // A scoped, mandatory lock, and an append that is one WriteFile.
    try journal.withLock {
      try withSpan(of: "entry from process \(ProcessID.current.rawValue)\n") {
        try journal.append($0)
      }
    }
    // FlushFileBuffers: the device commits its cache too.
    try journal.flush()

    let volume = try journal.volumeInformation()
    print("\(try journal.finalPath()): \(try journal.size()) bytes, a \(try journal.fileType()) file")
    print("on a volume formatted \(volume.fileSystemName), which "
      + (volume.flags.contains(.supportsHardLinks) ? "supports" : "doesn't support") + " hard links")

    // A duplicate for a child process to inherit shares the file pointer.
    let forChild = try journal.duplicate(inheritable: true)
    print("the duplicate is \(try forChild.isInheritable() ? "" : "not ")inheritable")
    try forChild.close()
    try journal.close()
  }

  /// Whether another open of the journal fails with a sharing violation.
  ///
  /// A helper, because Swift 6.2 crashes (V16i) compiling a pattern catch
  /// such as `catch Win32.Error.sharingViolation` in a function that goes
  /// on to use an owner with a deinit, as `appendEntry` does.
  private func secondOpenIsRefused() throws -> Bool {
    do {
      let reader = try Win32.FileHandle.open(FilePath(path), access: .genericRead)
      try reader.close()
      return false
    } catch Win32.Error.sharingViolation {
      return true
    }
  }
}

#else

struct PlatformWindowsOnly: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "windows-only",
    abstract: "Unavailable: this sample uses the Win32 drafts' API, which needs Windows or a simulated build"
  )

  @Argument(help: "The journal")
  var path: String

  func run() throws {
    complain("Error: windows-only uses Win32.FileHandle. Build with -Xswiftc -DSIMULATE_PLATFORMS"
      + " to run it over the stand-ins (see Sources/Samples/Platforms/Simulation.swift)")
    throw ExitCode.failure
  }
}

#endif // os(Windows) || SIMULATE_PLATFORMS
