/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: OwnedFD sample. A `dup2` redirect of standard output.

import ArgumentParser
import SystemPackage

struct OwnedRedirect: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-redirect",
    abstract: "Temporarily redirect standard output into a file using OwnedFD"
  )

  @Argument(help: "The file that receives the redirected output")
  var path: String

  @Option(name: .shortAndLong, help: "The message to write while redirected")
  var message: String = "Hello from a redirected standard output"

  func run() throws {
    let file = try OwnedFD.open(
      FilePath(path), .writeOnly,
      options: [.create, .truncate], permissions: [.ownerReadWrite, .groupRead, .otherRead])

    // Keep a duplicate of the current standard output, to restore it later.
    // OwnedFD doesn't forward `duplicate()`, which returns a FileDescriptor
    // that has to be adopted.
    let saved = try OwnedFD.standardOutput.withDescriptor { OwnedFD(taking: try $0.duplicate()) }

    try redirect(OwnedFD.standardOutput, to: file)
    try report(to: OwnedFD.standardOutput, "\(message)\n")

    try redirect(OwnedFD.standardOutput, to: saved)
    try saved.close()
    try file.close()
    try report(to: OwnedFD.standardOutput, "Wrote \"\(message)\" to \(path)\n")
  }
}

/// Makes `target` refer to the same open file as `source`.
///
/// The open file that `target` referred to is closed, if nothing else
/// refers to it.
///
/// The corresponding C function is `dup2`.
func redirect(_ target: borrowing OwnedFD, to source: borrowing OwnedFD) throws {
  // `duplicate(as:)` needs both descriptors as FileDescriptor values.
  try source.withDescriptor { source in
    try target.withDescriptor { target in
      _ = try source.duplicate(as: target)
    }
  }
}

func report(to fd: borrowing OwnedFD, _ text: String) throws(Errno) {
  try fd.writeAll(text.utf8)
}
