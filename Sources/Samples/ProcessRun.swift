/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Runs a command with its output on a pipe, as swift-subprocess and
// SwiftPM's AsyncProcess do: the child gets a process group of its own, no
// blocked or ignored signals, and no descriptors but its standard ones, and
// a timeout ends it as SwiftPM's Cancellator does: SIGTERM to its group,
// then SIGKILL after a grace period.
//
//     $ swift run system-samples process-run --timeout 1 -- sh -c 'echo hi; sleep 5'
//     │ hi
//     timed out after 1 s; sent SIGTERM to process group 81234
//     ended by SIGTERM

// posix_spawn isn't wrapped on Windows, WASI, watchOS, tvOS, or Android.
#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

struct ProcessRun: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-run",
    abstract: "Run a command, relaying its output, and end it after a timeout"
  )

  @Option(help: "Seconds to let the command run before ending it")
  var timeout: Int = 10

  @Option(help: "Seconds between SIGTERM and SIGKILL")
  var grace: Int = 2

  @Argument(parsing: .captureForPassthrough, help: "The command and its arguments")
  var arguments: [String]

  // The arguments keep a "--" that separates them from the options.
  var command: [String] {
    arguments.first == "--" ? Array(arguments.dropFirst()) : arguments
  }

  func validate() throws {
    guard !command.isEmpty else { throw ValidationError("Give a command to run") }
    guard timeout > 0, grace > 0 else {
      throw ValidationError("--timeout and --grace must be positive")
    }
  }

  func run() throws {
    guard #available(macOS 13.0, iOS 16.0, *) else {
      complain("process-run uses Duration, which requires macOS 13 or later")
      throw ExitCode.failure
    }
    let status = try runCommand(command, timeout: timeout, grace: grace)
    print(status)
    if !status.isSuccess { throw ExitCode.failure }
  }
}

@available(macOS 13.0, iOS 16.0, *)
private func runCommand(_ command: [String], timeout: Int, grace: Int) throws -> ExitStatus {
  // The child writes its standard output and error to the pipe, and reads
  // standard input from /dev/null.
  let output = try OwnedFD.pipe()
  let actions: [SpawnFileAction] = [
    .open("/dev/null", .readOnly, as: .standardInput),
    .duplicate(output.writeEnd.fileDescriptor, as: .standardOutput),
    .duplicate(output.writeEnd.fileDescriptor, as: .standardError),
  ]
  // Every other descriptor stays behind, even one that another thread opens
  // without close-on-exec while this one spawns.
  #if SYSTEM_PACKAGE_DARWIN
  let flags: SpawnAttributes.Flags = .closeOnExecByDefault
  let closeTheRest: [SpawnFileAction] = []
  #elseif os(Linux)
  let flags: SpawnAttributes.Flags = []
  let closeTheRest: [SpawnFileAction] = [.closeAll(from: FileDescriptor(rawValue: 3))]
  #else
  let flags: SpawnAttributes.Flags = []
  let closeTheRest: [SpawnFileAction] = []
  #endif
  let attributes = SpawnAttributes(
    flags: flags, processGroup: .new, signalMask: [], defaultSignals: .all)

  var child = try spawn(
    command, fileActions: actions, closingTheRest: closeTheRest, attributes: attributes)
  // The child has its own copy of the write end; closing this one lets the
  // read end see the end of the file when the child's closes.
  let reader = output.readEnd
  try output.writeEnd.close()

  let deadline = ContinuousClock.now + .seconds(timeout)
  var signaled = false
  var buffer = [UInt8](repeating: 0, count: 4096)
  var pending: [UInt8] = []
  while true {
    let remaining = deadline - ContinuousClock.now
    let events = try reader.fileDescriptor.poll(
      for: .readable, timeout: remaining > .zero ? remaining : .zero)
    if events.isEmpty {
      guard !signaled else { break }
      // Timed out: ask the whole group to end, then make it.
      print("timed out after \(timeout) s; sent SIGTERM to process group \(child.id.rawValue)")
      try child.id.sendSignalToProcessGroup(.terminate)
      signaled = true
      if try waitForExit(of: &child, within: .seconds(grace)) == nil {
        print("still running after \(grace) s; sent SIGKILL")
        try child.id.sendSignalToProcessGroup(.kill)
      }
      break
    }
    let count = try buffer.withUnsafeMutableBytes { try reader.fileDescriptor.read(into: $0) }
    if count == 0 { break }
    pending += buffer[..<count]
    while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
      print("│ " + String(decoding: pending[..<newline], as: UTF8.self))
      pending.removeSubrange(...newline)
    }
  }
  if !pending.isEmpty { print("│ " + String(decoding: pending, as: UTF8.self)) }
  try reader.close()
  // The child's output ended, or it was signaled: reap it.
  return try child.wait()
}

private func spawn(
  _ command: [String],
  fileActions: [SpawnFileAction],
  closingTheRest closeTheRest: [SpawnFileAction],
  attributes: SpawnAttributes
) throws -> ChildProcess {
  do {
    return try ChildProcess.spawn(
      searchingPathFor: FilePath(command[0]), arguments: command,
      fileActions: fileActions + closeTheRest, attributes: attributes)
  } catch Errno.noFunction where !closeTheRest.isEmpty {
    // A C library without posix_spawn_file_actions_addclosefrom_np.
    return try ChildProcess.spawn(
      searchingPathFor: FilePath(command[0]), arguments: command,
      fileActions: fileActions, attributes: attributes)
  }
}

// Waits up to `limit` for the child to end, reaping it if it does.
@available(macOS 13.0, iOS 16.0, *)
private func waitForExit(
  of child: inout ChildProcess, within limit: Duration
) throws -> ExitStatus? {
  let deadline = ContinuousClock.now + limit
  while ContinuousClock.now < deadline {
    if let status = try child.tryWait() { return status }
    usleep(10_000)
  }
  return nil
}

#else

import ArgumentParser

struct ProcessRun: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-run",
    abstract: "Unavailable: this platform has no posix_spawn wrapper"
  )

  func run() throws {
    complain("Error: process-run needs posix_spawn, which System doesn't wrap here")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
