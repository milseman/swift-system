/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 6: processes. Platform.Process has a case every
// platform has, `.id`, and on Linux and Windows a second: a pidfd or a
// handle. Here a platform can have two representations, so its switches
// have two arms even in a real build.
//
// The common subset (id, waitForExit, terminate, close) behaves differently,
// which the output shows:
// - Waiting reaps on Unix, so a second wait fails, and doesn't on Windows,
//   where it reports the same exit code again.
// - terminate() is SIGKILL on Unix, which reports `.signaled(9)`, and
//   TerminateProcess on Windows, which reports the exit code it was given.
//
// The platform-specific operation is a graceful stop: SIGTERM on Unix
// (through `kill` for `.id`, which could hit a reused ID, and through the
// pidfd for `.descriptor`, which can't). Windows has no counterpart for an
// arbitrary process, so its arm has to choose something else, visibly.
//
// Process creation isn't in System, so the sample starts children with C's
// posix_spawn; on Windows it would be CreateProcessW, which returns the
// handle.

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct PlatformProcess: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process",
    abstract: "Stop and wait for child processes through Platform.Process"
  )

  @OptionGroup var simulation: SimulationOptions

  func run() throws {
    simulation.apply()

    // A child that exits with code 3 when asked to stop.
    let child = try spawnChild(["/bin/sh", "-c", "trap 'exit 3' TERM; while :; do sleep 1; done"])
    print("started \(child.summary), process \(child.id.rawValue)")
    sleep(1)  // let the shell set its trap

    let how = try requestStop(child)
    print("asked it to stop, with \(how); it \(try child.waitForExit())")
    print("waiting again: \(waitAgain(child))")
    try child.close()

    // A child that doesn't get a say.
    let sleeper = try spawnChild(["/bin/sleep", "60"])
    print("started \(sleeper.summary), process \(sleeper.id.rawValue)")
    try sleeper.terminate()
    print("terminated it; it \(try sleeper.waitForExit())")
    try sleeper.close()
  }
}

/// Starts a child process, and refers to it as this platform does.
///
/// C: posix_spawn. System has no process creation.
func spawnChild(_ arguments: [String]) throws -> Platform.Process {
  #if os(Windows)
  // CreateProcessW, whose PROCESS_INFORMATION has the handle to adopt.
  fatalError("CreateProcessW isn't sketched here")
  #else
  var pid: pid_t = 0
  var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
  defer { for argument in argv { free(argument) } }
  let result = posix_spawn(&pid, arguments[0], nil, nil, &argv, environ)
  guard result == 0 else { throw Errno(rawValue: result) }
  let id = ProcessID(rawValue: pid)

  #if SIMULATE_PLATFORMS
  switch Simulation.platform {
  case .windows:
    // Stands in for adopting CreateProcessW's hProcess.
    return .handle(try Win32.ProcessHandle.open(id))
  case .linux:
    // pidfd_open; or, at creation, clone3 with CLONE_PIDFD.
    return .descriptor(try ProcessDescriptor(id))
  case .darwin:
    return .id(id)
  }
  #elseif os(Linux)
  return .descriptor(try ProcessDescriptor(id))
  #else
  return .id(id)
  #endif
  #endif
}

/// Asks the process to stop, letting it clean up first: the operation that
/// isn't in the common subset. Returns how it asked.
func requestStop(_ process: borrowing Platform.Process) throws -> String {
  switch process {
  case .id(let id):
    #if os(Windows)
    // No signals. See the `.handle` arm.
    try Win32.ProcessHandle.open(id, access: .terminate).terminate(exitCode: 3)
    return "TerminateProcess"
    #else
    // C: kill, with SIGTERM. If the process was already reaped, its ID may
    // name another process by now.
    guard kill(id.rawValue, SIGTERM) == 0 else { throw Errno(rawValue: errno) }
    return "SIGTERM, through kill"
    #endif
  #if os(Linux) || SIMULATE_PLATFORMS
  case .descriptor(let descriptor):
    // pidfd_send_signal: it can't reach another process.
    try descriptor.sendSignal(SIGTERM)
    return "SIGTERM, through pidfd_send_signal"
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    // Windows has no SIGTERM. A console process in its own process group
    // can get CTRL_BREAK_EVENT from GenerateConsoleCtrlEvent; a GUI process
    // can get WM_CLOSE. For an arbitrary process, there's only
    // TerminateProcess, which lets it clean up nothing. This arm chooses
    // that, with the code the child would have exited with, so the exit
    // status matches Unix's while the child ran none of its own code.
    try handle.terminate(exitCode: 3)
    return "TerminateProcess(3), since Windows has no SIGTERM"
  #endif
  }
}

/// Waits for the process a second time.
func waitAgain(_ process: borrowing Platform.Process) -> String {
  do {
    return "it \(try process.waitForExit()), again"
  } catch {
    // Unix: the first wait reaped the child, so there's no child to wait
    // for. (A catch-all: a pattern catch here can crash Swift 6.2, V16i.)
    return "failed with \(describe(error)): the first wait reaped it"
  }
}
