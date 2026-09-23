/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct SetAttributes: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set-attributes",
    abstract: "Change a file's permissions, owner, group, or flags through one descriptor"
  )

  @Argument(help: "The file to change")
  var path: String

  @Option(name: .shortAndLong, help: "The new permissions, in octal")
  var permissions: String?

  @Option(name: .shortAndLong, help: "The new owner's user ID")
  var user: CInterop.UserID?

  @Option(name: .shortAndLong, help: "The new group ID")
  var group: CInterop.GroupID?

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// A file flag, by its chflags(1) name.
  enum Flag: String, CaseIterable, ExpressibleByArgument {
    case nodump, uchg, uappnd

    var fileFlags: FileFlags {
      switch self {
      case .nodump: return .noDump
      case .uchg: return .userImmutable
      case .uappnd: return .userAppend
      }
    }
  }

  @Option(name: .customLong("set-flag"), help: "A flag to set")
  var flagsToSet: [Flag] = []

  @Option(name: .customLong("clear-flag"), help: "A flag to clear")
  var flagsToClear: [Flag] = []
  #endif

  func validate() throws {
    if let permissions, CInterop.Mode(permissions, radix: 8).map({ $0 > 0o7777 }) ?? true {
      throw ValidationError("'\(permissions)' isn't an octal file mode")
    }
  }

  func run() throws {
    // A read-only descriptor is enough: these calls need ownership of the
    // file, not write access to it.
    let fd = try FileDescriptor.open(FilePath(path), .readOnly)
    try fd.closeAfter {
      print("before: \(describe(try fd.stat()))")

      if let permissions {
        try fd.setPermissions(FilePermissions(rawValue: CInterop.Mode(permissions, radix: 8)!))
      }
      if user != nil || group != nil {
        // A nil ID leaves that ID unchanged.
        try fd.setOwner(user: user.map { UserID($0) }, group: group.map { GroupID($0) })
      }
      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
      if !flagsToSet.isEmpty || !flagsToClear.isEmpty {
        // setFileFlags replaces all of the flags, so start from the current ones.
        var flags = try fd.stat().flags
        for flag in flagsToSet { flags.insert(flag.fileFlags) }
        for flag in flagsToClear { flags.remove(flag.fileFlags) }
        try fd.setFileFlags(flags)
      }
      #endif

      print("after:  \(describe(try fd.stat()))")
    }
  }
}

private func describe(_ status: Stat) -> String {
  var text = "mode \(String(status.permissions.rawValue, radix: 8))"
    + ", owner \(status.userID.rawValue), group \(status.groupID.rawValue)"
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  var others = status.flags
  var names: [String] = []
  for flag in SetAttributes.Flag.allCases where others.contains(flag.fileFlags) {
    names.append(flag.rawValue)
    others.remove(flag.fileFlags)
  }
  if !others.isEmpty { names.append("0x\(String(others.rawValue, radix: 16))") }
  text += ", flags \(names.isEmpty ? "none" : names.joined(separator: ","))"
  #endif
  return text
}
