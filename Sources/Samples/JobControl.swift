/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

struct JobControl: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "job-control",
    abstract: "Show the controlling terminal's foreground process group and session"
  )

  func run() throws {
    // System has no getpgrp or getsid, so this process's own group and
    // session come from C.
    let group = ProcessID(rawValue: getpgrp())
    let session = ProcessID(rawValue: getsid(0))
    print("Process \(ProcessID.current.rawValue), a child of \(ProcessID.parent.rawValue), "
      + "is in process group \(group.rawValue) and session \(session.rawValue)")

    // /dev/tty is the controlling terminal, whatever the standard streams
    // are, and opening it fails if the process has none.
    var foreground: ProcessID? = nil
    do {
      let tty = try FileDescriptor.open("/dev/tty", .readOnly)
      defer { try? tty.close() }
      let terminal = try TerminalDescriptor(tty)
      print("/dev/tty: \(describe(terminal, group: group, session: session))")
      foreground = try? terminal.foregroundProcessGroup()
    } catch {
      print("/dev/tty: \(error), so this process has no controlling terminal")
    }

    let streams: [(name: String, fd: FileDescriptor)] = [
      ("standard input", .standardInput),
      ("standard output", .standardOutput),
      ("standard error", .standardError),
    ]
    for (name, fd) in streams {
      guard let terminal = fd.asTerminal else {
        print("\(name): not a terminal")
        continue
      }
      print("\(name): \(describe(terminal, group: group, session: session))")
    }

    // The controller side of a pseudo-terminal, which a terminal emulator
    // holds, answers for the other side, which no session has taken as its
    // controlling terminal yet: its foreground group is 0, meaning none,
    // and it has no session.
    // O_NOCTTY keeps the open from making the new terminal this process's
    // controlling terminal, as some systems do for a session leader that
    // has none. OpenOptions has no such option, so it comes from C.
    let noControllingTerminal = FileDescriptor.OpenOptions(rawValue: O_NOCTTY)
    let pty = try FileDescriptor.open("/dev/ptmx", .readWrite, options: noControllingTerminal)
    try pty.closeAfter {
      let terminal = try TerminalDescriptor(pty)
      print("a new pseudo-terminal's controller side: "
        + describe(terminal, group: group, session: session))
    }

    guard let foreground else { return }
    if foreground == group {
      print("This process's group is in the foreground, so it can read from the terminal")
    } else {
      print("This process's group is in the background, so reading from the terminal "
        + "would stop it with SIGTTIN")
    }
  }
}

/// Describes a terminal's foreground process group and session,
/// or why they aren't available.
private func describe(
  _ terminal: TerminalDescriptor, group: ProcessID, session: ProcessID
) -> String {
  func mark(_ id: ProcessID, _ own: ProcessID) -> String {
    id == own ? "\(id.rawValue) (this process's)" : "\(id.rawValue)"
  }
  let foreground: String
  do {
    foreground = "foreground process group \(mark(try terminal.foregroundProcessGroup(), group))"
  } catch {
    foreground = "foreground process group: \(error)"
  }
  let terminalSession: String
  do {
    terminalSession = "session \(mark(try terminal.sessionID(), session))"
  } catch {
    terminalSession = "session: \(error)"
  }
  return "\(foreground); \(terminalSession)"
}

#endif // !os(Windows) && !os(WASI)
