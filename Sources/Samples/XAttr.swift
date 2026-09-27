/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

struct XAttr: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "xattr",
    abstract: "List, print, write or delete a file's extended attributes, as xattr(1) does"
  )

  @Option(name: .short, help: "Print this attribute's value")
  var print: String?

  @Option(name: .short, help: "Write an attribute, given as NAME=VALUE")
  var write: String?

  @Option(name: .short, help: "Delete this attribute")
  var delete: String?

  @Flag(name: .short, help: "Act on a symbolic link itself, not the file it points to")
  var noFollow = false

  @Argument(help: "The file")
  var file: String

  func validate() throws {
    guard write.map({ $0.contains("=") }) ?? true else {
      throw ValidationError("-w takes NAME=VALUE")
    }
  }

  func run() throws {
    let path = FilePath(file)
    let follow = !noFollow
    if let write {
      let equals = write.firstIndex(of: "=")!
      try path.setExtendedAttribute(
        String(write[..<equals]), to: write[write.index(after: equals)...].utf8,
        followTargetSymlink: follow)
    }
    if let delete {
      try path.removeExtendedAttribute(delete, followTargetSymlink: follow)
    }
    if let print {
      // A missing attribute is nil, whichever errno the platform uses.
      guard let value = try path.extendedAttribute(print, followTargetSymlink: follow) else {
        complain("\(file) has no attribute \(print)")
        throw ExitCode.failure
      }
      Swift.print(describe(value))
      return
    }
    guard write == nil && delete == nil else { return }
    let names = try path.extendedAttributeNames(followTargetSymlink: follow)
    if names.isEmpty { Swift.print("\(file) has no extended attributes") }
    for name in names.sorted() {
      let value = try path.extendedAttribute(name, followTargetSymlink: follow) ?? []
      Swift.print("\(name): \(describe(value))")
    }
  }

  /// Text for a value that's printable UTF-8, and a byte count and hex bytes
  /// otherwise.
  private func describe(_ value: [UInt8]) -> String {
    // Decoding repairs bytes that aren't UTF-8, so a round trip checks.
    let text = String(decoding: value, as: UTF8.self)
    if Array(text.utf8) == value && !text.contains(where: \.isNewline) && !text.isEmpty
      && text.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control }) {
      return text
    }
    let hex = value.prefix(32).map { String($0, radix: 16).count == 1 ? "0" + String($0, radix: 16) : String($0, radix: 16) }
    return "\(value.count) bytes: " + hex.joined(separator: " ") + (value.count > 32 ? " ..." : "")
  }
}

#else
struct XAttr: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "xattr",
    abstract: "Unavailable: System has extended attributes only on Darwin, Linux and Android"
  )

  func run() throws {
    complain("xattr isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
