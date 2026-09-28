/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Runs a command on a new pseudoterminal, as `script` does, and relays what
// it writes. The command sees a terminal of the given size, which is its
// controlling terminal, so it can open /dev/tty.
//
//     $ swift run system-samples pty-run -- sh -c 'tty; stty size'
//     /dev/ttys004
//     24 80
//     exited with status 0

// posix_spawn isn't wrapped on watchOS, tvOS, or Android.
#if (SYSTEM_PACKAGE_DARWIN || os(Linux)) && !os(watchOS) && !os(tvOS)

import ArgumentParser
import SystemPackage

struct PtyRun: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pty-run",
    abstract: "Run a command on a pseudoterminal, relaying what it writes"
  )

  @Option(help: "The terminal's rows")
  var rows: UInt16 = 24

  @Option(help: "The terminal's columns")
  var columns: UInt16 = 80

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
    guard #available(macOS 10.13.4, iOS 11.3, *) else {
      complain("pty-run uses ptsname_r, which requires macOS 10.13.4 or later")
      throw ExitCode.failure
    }
    try runOnPseudoterminal()
  }

  @available(macOS 10.13.4, iOS 11.3, *)
  private func runOnPseudoterminal() throws {
    let (controller, terminal) = try TerminalDescriptor.openPseudoterminal(
      windowSize: .init(rows: rows, columns: columns))
    defer { try? controller.close() }

    // The child opens the terminal by its path, in a session of its own,
    // which makes it the child's controlling terminal.
    let path = try controller.pseudoterminalPath()
    let child: ProcessID
    do {
      // Once the child has the terminal, only its copies should keep the
      // terminal open, so that the controller sees when they close.
      defer { try? terminal.fileDescriptor.close() }
      child = try ProcessID.spawn(
        searchingPathFor: FilePath(command[0]), arguments: command,
        fileActions: [
          .open(path, .readWrite, as: .standardInput),
          .duplicate(.standardInput, as: .standardOutput),
          .duplicate(.standardInput, as: .standardError),
        ],
        attributes: SpawnAttributes(flags: .createSession))
    }

    // Relay until the child's side closes, before waiting for it: on
    // Darwin, its last close blocks until the controller reads its output.
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count: Int
      do {
        count = try buffer.withUnsafeMutableBytes { try controller.read(into: $0) }
      } catch {
        // Linux reports that the terminal's side closed as an I/O error.
        // (A catch-all: Swift 6.3 crashes on a pattern catch here.)
        guard (error as? Errno) == .ioError else { throw error }
        break
      }
      guard count > 0 else { break }
      try buffer[..<count].withUnsafeBytes { _ = try FileDescriptor.standardOutput.writeAll($0) }
    }

    let status = try child.wait()
    print(status)
    if !status.isSuccess { throw ExitCode.failure }
  }
}

#else

import ArgumentParser

struct PtyRun: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pty-run",
    abstract: "Unavailable: pseudoterminals and posix_spawn aren't wrapped on this platform"
  )

  func run() throws {
    complain("pty-run needs pseudoterminals and posix_spawn")
    throw ExitCode.failure
  }
}

#endif
