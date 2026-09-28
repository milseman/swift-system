/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Groups: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "groups",
    abstract: "Print a user's groups, as groups(1) does, and whether the process is set-user-ID"
  )

  @Argument(help: "The user whose groups to print; the effective user if omitted")
  var user: String?

  @Flag(name: .shortAndLong, help: "Print group IDs rather than names")
  var numeric = false

  func run() throws {
    let entry: UserEntry?
    if let user {
      entry = try UserEntry(name: user)
    } else {
      entry = try UserEntry(userID: .effective)
    }
    guard let entry else {
      complain("\(user ?? "The effective user") isn't in the user database")
      throw ExitCode.failure
    }

    // The groups that initgroups would give the user: the group database's,
    // and the user's primary group first.
    let groups = try GroupID.supplementary(forUser: entry.name, including: entry.groupID)
    let names = try groups.map { group in
      numeric ? "\(group.rawValue)" : (try GroupEntry(groupID: group)?.name ?? "\(group.rawValue)")
    }
    print("\(entry.name): \(names.joined(separator: " "))")

    guard user == nil else { return }
    print("set-user-ID or set-group-ID: \(ProcessID.isSetUserOrGroupID ? "yes" : "no")")
    #if SYSTEM_PACKAGE_DARWIN
    if let (threadUser, threadGroup) = try PThread.credentials() {
      print("this thread acts as user \(threadUser.rawValue), group \(threadGroup.rawValue)")
    } else {
      print("this thread acts as its process")
    }
    #endif
  }
}

#else
struct Groups: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "groups",
    abstract: "Unavailable: System has no group database on Windows or WASI"
  )

  func run() throws {
    complain("groups isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
