/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Replaces this process with a command, after preparing the process as
// SwiftPM's safeExec does before it runs a debugger or a built product:
// every signal gets its default action back, none stays blocked, and every
// descriptor but the standard ones is marked close-on-exec, so that the
// command inherits a clean process. If the exec fails, the process state is
// gone, so it exits rather than returning.
//
// On Darwin, --spawn-exec does all of that in one call instead: posix_spawn
// with POSIX_SPAWN_SETEXEC, POSIX_SPAWN_CLOEXEC_DEFAULT, an empty signal
// mask, and every signal's default action, inheriting only the standard
// descriptors.
//
//     $ swift run system-samples process-exec -- sh -c 'echo "I am $$"; ls /dev/fd'
//     preparing process 81260 to run sh
//     I am 81260
//     0 1 2 3

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

struct ProcessExec: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-exec",
    abstract: "Replace this process with a command, after resetting its signals and descriptors"
  )

  #if SYSTEM_PACKAGE_DARWIN
  @Flag(help: "Use posix_spawn's exec flag, which prepares the process in one call")
  var spawnExec = false
  #endif

  @Argument(parsing: .captureForPassthrough, help: "The command and its arguments")
  var arguments: [String]

  // The arguments keep a "--" that separates them from the options.
  var command: [String] {
    arguments.first == "--" ? Array(arguments.dropFirst()) : arguments
  }

  func validate() throws {
    guard !command.isEmpty else { throw ValidationError("Give a command to run") }
  }

  func run() throws {
    print("preparing process \(ProcessID.current.rawValue) to run \(command[0])")
    #if SYSTEM_PACKAGE_DARWIN
    if spawnExec {
      // /usr/bin/env searches PATH, which posix_spawn doesn't.
      try ProcessID.execute(
        "/usr/bin/env", arguments: ["env"] + command,
        fileActions: [.inherit(.standardInput), .inherit(.standardOutput), .inherit(.standardError)],
        // The attributes' defaults empty the signal mask
        // and reset every signal's action.
        attributes: SpawnAttributes(flags: .closeOnExecByDefault))
    }
    #endif

    // Every signal's default action. SignalSet.all leaves out the numbers
    // that the C library reserves, such as glibc's 32 and 33, and kill and
    // stop can't have another action.
    for signal in SignalSet.all where signal != .kill && signal != .stop {
      try signal.setAction(.default)
    }
    PThread.setCurrentSignalMask([])

    #if os(Linux) || os(Android) || os(FreeBSD) || os(macOS)
    // Mark rather than close, so that the descriptors still work if the
    // exec fails. Linux before 5.11 has no CLOSE_RANGE_CLOEXEC.
    do {
      try FileDescriptor.setCloseOnExecForAll(from: FileDescriptor(rawValue: 3))
    } catch {
      complain("warning: descriptors from 3 up stay open: \(error)")
    }
    #endif

    do {
      try ProcessID.execute(searchingPathFor: FilePath(command[0]), arguments: command)
    } catch {
      complain("Error: couldn't run \(command[0]): \(error)")
      // The signal table was reset, so don't go back to running Swift code
      // that may depend on it.
      _exit(127)
    }
  }
}

#else

import ArgumentParser

struct ProcessExec: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-exec",
    abstract: "Unavailable: this platform has no exec wrapper"
  )

  func run() throws {
    complain("Error: process-exec needs execve, which System doesn't wrap here")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
