/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Runs a pipeline, as a shell does: each stage's standard output goes to the
// next stage's standard input through a pipe, and every stage joins one
// process group, which the first stage leads, so that one signal reaches the
// whole job. Reports how each stage ended, like a shell's PIPESTATUS.
//
//     $ swift run system-samples process-pipeline "ls /usr/bin" "grep swift" "wc -l"
//            4
//     process group 81240
//       ls /usr/bin: exited with status 0
//       grep swift: exited with status 0
//       wc -l: exited with status 0
//
// An Array can't hold noncopyable values, so the stages are kept as the
// ProcessIDs that ChildProcess.relinquish() returns, and reaped by ID.

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

struct ProcessPipeline: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-pipeline",
    abstract: "Run commands as a pipeline, in a process group of their own"
  )

  @Option(help: "Send SIGTERM to the pipeline's process group after this many seconds")
  var terminateAfter: Int?

  @Argument(help: "The stages, each a command and its arguments separated by spaces")
  var stages: [String]

  func validate() throws {
    guard !stages.isEmpty else { throw ValidationError("Give at least one stage") }
  }

  func run() throws {
    let commands = stages.map { $0.split(separator: " ").map(String.init) }
    guard commands.allSatisfy({ !$0.isEmpty }) else {
      throw ValidationError("A stage can't be empty")
    }

    var children: [ProcessID] = []
    do {
      try startStages(commands, into: &children)
    } catch {
      // Owners would end and reap the stages already started;
      // IDs are cleaned up by hand.
      for child in children {
        try? child.sendSignal(.kill)
        _ = try? child.wait()
      }
      throw error
    }

    let leader = children[0]
    if let terminateAfter {
      sleep(UInt32(terminateAfter))
      // Any stage still running ends. Ones that ended are zombies until
      // they're reaped below, which keeps the group's ID reserved.
      try? leader.sendSignalToProcessGroup(.terminate)
    }

    var failed = false
    var statuses: [String] = []
    for (stage, child) in zip(stages, children) {
      let status = try child.wait()
      failed = failed || !status.isSuccess
      statuses.append("  \(stage): \(status)")
    }
    print("process group \(leader.rawValue)")
    statuses.forEach { print($0) }
    if failed { throw ExitCode.failure }
  }

  // Starts each stage, appending its ID to `children` as it starts.
  private func startStages(_ commands: [[String]], into children: inout [ProcessID]) throws {
    var input: FileDescriptor? = nil
    defer { if let input { try? input.close() } }
    for (index, command) in commands.enumerated() {
      let pipe = index == commands.count - 1 ? nil : try FileDescriptor.pipe()
      var actions: [SpawnFileAction] = []
      if let input { actions += [.duplicate(input, as: .standardInput), .close(input)] }
      if let pipe {
        actions += [
          .duplicate(pipe.writeEnd, as: .standardOutput),
          .close(pipe.writeEnd), .close(pipe.readEnd),
        ]
      }
      // The first stage leads a new group; the rest join it.
      let group: SpawnAttributes.ProcessGroup = children.first.map { .existing($0) } ?? .new
      do {
        let child = try ChildProcess.spawn(
          searchingPathFor: FilePath(command[0]), arguments: command,
          fileActions: actions, attributes: SpawnAttributes(processGroup: group))
        children.append(child.relinquish())
      } catch {
        if let pipe {
          try? pipe.readEnd.close()
          try? pipe.writeEnd.close()
        }
        throw error
      }
      // The parent keeps no pipe ends: each belongs to its stages.
      if let input { try input.close() }
      if let pipe { try pipe.writeEnd.close() }
      input = pipe?.readEnd
    }
  }
}

#else

import ArgumentParser

struct ProcessPipeline: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-pipeline",
    abstract: "Unavailable: this platform has no posix_spawn wrapper"
  )

  func run() throws {
    complain("Error: process-pipeline needs posix_spawn, which System doesn't wrap here")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
