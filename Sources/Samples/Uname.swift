/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Uname: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uname",
    abstract: "Print the system's identity, as uname(1) does, with its host name, the login name, and the page size"
  )

  @Flag(name: .short, help: "The operating system's name")
  var systemName = false

  @Flag(name: .short, help: "The node name")
  var nodeName = false

  @Flag(name: .short, help: "The operating system's release")
  var release = false

  @Flag(name: .short, help: "The operating system's version")
  var version = false

  @Flag(name: .short, help: "The hardware")
  var machine = false

  @Flag(name: .short, help: "All of the above, and more")
  var all = false

  func run() throws {
    let system = try SystemIdentity.current()
    let fields: [(Bool, String)] = [
      (systemName, system.systemName), (nodeName, system.nodeName),
      (release, system.release), (version, system.version), (machine, system.machine),
    ]
    let chosen = fields.filter { all || $0.0 }.map(\.1)
    // With no flags, uname(1) prints the system's name.
    print(chosen.isEmpty ? system.systemName : chosen.joined(separator: " "))
    guard all else { return }

    print("host name: \(try SystemIdentity.hostName())")
    do {
      print("login name: \(try SystemIdentity.loginName())")
    } catch {
      // A process that no login started has no login name.
      print("login name: none (\(error))")
    }
    // The page size is sysconf's, through SystemConfig.
    print("page size: \((try SystemConfig.value(.pageSize)).map { "\($0) bytes" } ?? "unknown")")
  }
}

#else
struct Uname: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uname",
    abstract: "Unavailable: System has no uname on Windows or WASI"
  )

  func run() throws {
    complain("uname isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
