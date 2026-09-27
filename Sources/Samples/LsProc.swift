/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

// libproc is only in the macOS SDK.
#if os(macOS)

struct LsProc: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lsproc",
    abstract: "List processes with libproc, as ps does, or show one's directories and open files, as lsof does"
  )

  @Argument(help: "Processes to show in detail, rather than listing this user's")
  var processes: [Int32] = []

  @Flag(help: "List every process, rather than this user's")
  var all = false

  func run() throws {
    guard processes.isEmpty else {
      for id in processes.map({ ProcessID(rawValue: $0) }) { detail(id) }
      return
    }
    let ids = try all ? ProcessID.all() : ProcessID.all(ofUser: .effective)
    var rows = [["PID", "PPID", "UID", "STATE", "PATH"]]
    var hidden = 0
    for id in ids.sorted(by: { $0.rawValue < $1.rawValue }) {
      // Any user can read a process's path; the rest of another user's
      // process's information needs privileges.
      let path = (try? id.executablePath()).map { "\($0)" } ?? "?"
      guard let info = try? id.bsdInfo() else {
        hidden += 1
        rows.append(["\(id.rawValue)", "", "", "", path])
        continue
      }
      rows.append([
        "\(id.rawValue)", "\(info.parent.rawValue)", "\(info.effectiveUser.rawValue)",
        "\(info.status)", path,
      ])
    }
    printTable(rows)
    print("\(ids.count) processes"
      + (hidden > 0 ? ", \(hidden) of them another user's or since exited" : ""))
  }

  private func detail(_ id: ProcessID) {
    print("Process \(id.rawValue):")
    do {
      let info = try id.bsdInfo()
      printTable([
        ["name", "\(try id.name())"],
        ["executable", "\(try id.executablePath())"],
        ["parent", "\(info.parent.rawValue)"],
        ["children", try id.children().map { "\($0.rawValue)" }.joined(separator: " ")],
        ["users", "effective \(info.effectiveUser.rawValue), real \(info.realUser.rawValue), "
          + "saved \(info.savedUser.rawValue)"],
        ["state", "\(info.status) \(info.flags)"],
        ["terminal", info.controllingTerminal.map { "device \($0.rawValue)" } ?? "none"],
        ["directory", "\(try id.currentDirectory())"],
        ["root", "\(try id.rootDirectory())"],
      ])
      print("  Open file descriptors:")
      printTable(try id.openFileDescriptors().map {
        ["  \($0.fileDescriptor.rawValue)", "\($0.kind)"]
      })
    } catch {
      // Another user's process needs privileges.
      print("  \(error)")
    }
  }
}

#else

struct LsProc: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lsproc",
    abstract: "Unavailable: this platform has no libproc"
  )

  func run() throws {
    complain("Error: lsproc needs macOS's libproc")
    throw ExitCode.failure
  }
}

#endif // os(macOS)
