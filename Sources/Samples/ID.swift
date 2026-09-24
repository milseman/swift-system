/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct ID: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "id",
    abstract: "Show user and group IDs and names, as id(1) does"
  )

  @Argument(help: "A user name or ID to look up, rather than this process's user")
  var user: String?

  @Flag(name: .shortAndLong, help: "Also show the user's real name, home directory, and shell")
  var long = false

  func run() throws {
    guard let user else {
      try showProcess()
      return
    }
    // Like id(1), try the argument as a name first, then as an ID.
    var entry = try UserEntry(name: user)
    if entry == nil, let id = CInterop.UserID(user) {
      entry = try UserEntry(userID: UserID(id))
    }
    guard let entry else {
      complain("Error: no such user: \(user)")
      throw ExitCode.failure
    }
    // A user's groups other than the primary one come from getgrouplist,
    // which System doesn't wrap.
    print("uid=\(try withName(entry.userID)) gid=\(try withName(entry.groupID))")
    if long { show(entry) }
  }

  /// Shows this process's real IDs, its effective IDs if they differ,
  /// as they do in a set-user-ID or set-group-ID program,
  /// and its supplementary groups.
  private func showProcess() throws {
    var line = "uid=\(try withName(UserID.real)) gid=\(try withName(GroupID.real))"
    if UserID.effective != UserID.real {
      line += " euid=\(try withName(UserID.effective))"
    }
    if GroupID.effective != GroupID.real {
      line += " egid=\(try withName(GroupID.effective))"
    }
    line += " groups=" + (try GroupID.supplementary().map(withName)).joined(separator: ",")
    print(line)
    if long, let entry = try UserEntry(userID: .real) { show(entry) }
  }

  private func show(_ entry: UserEntry) {
    print("login: \(entry.name)")
    #if !os(Android) || _pointerBitWidth(_64)
    print("name:  \(entry.realName)")
    #endif
    print("home:  \(entry.homeDirectory)")
    print("shell: \(entry.shell)")
  }
}

/// A user ID, followed by its user name in parentheses if it has one.
private func withName(_ id: UserID) throws -> String {
  guard let entry = try UserEntry(userID: id) else { return "\(id.rawValue)" }
  return "\(id.rawValue)(\(entry.name))"
}

/// A group ID, followed by its group name in parentheses if it has one.
private func withName(_ id: GroupID) throws -> String {
  guard let entry = try GroupEntry(groupID: id) else { return "\(id.rawValue)" }
  return "\(id.rawValue)(\(entry.name))"
}
