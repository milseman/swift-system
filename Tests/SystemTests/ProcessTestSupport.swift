/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: helpers for the tests that spawn processes.
//
// Those tests are XCTest tests, which run one at a time in a process of
// their own. A child inherits every descriptor that isn't close-on-exec, so
// a child spawned while swift-testing runs other tests in parallel could
// hold another test's pipe open, and a wait for any child could reap
// another test's.

#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

internal let shell: FilePath = "/bin/sh"

/// Reads from a descriptor until the end of the file.
@available(System 199, *)
internal func readAll(_ fd: FileDescriptor) throws -> String {
  var bytes: [UInt8] = []
  var buffer = [UInt8](repeating: 0, count: 4096)
  while true {
    let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
    if count == 0 { break }
    bytes += buffer[..<count]
  }
  return String(decoding: bytes, as: UTF8.self)
}

/// Runs `sh -c script` with its standard output on a pipe,
/// waits for it, and returns how it ended and what it wrote.
@available(System 199, *)
internal func runShell(
  _ script: String,
  _ arguments: [String] = [],
  environment: [String]? = nil,
  fileActions: [SpawnFileAction] = [],
  attributes: SpawnAttributes = SpawnAttributes()
) throws -> (status: ExitStatus, output: String) {
  let pipe = try FileDescriptor.pipe()
  let child: ProcessID
  do {
    defer { try? pipe.writeEnd.close() }
    child = try ProcessID.spawn(
      shell, arguments: ["sh", "-c", script] + arguments, environment: environment,
      fileActions: fileActions + [
        .duplicate(pipe.writeEnd, as: .standardOutput),
        .close(pipe.writeEnd),
        .close(pipe.readEnd),
      ],
      attributes: attributes)
  } catch {
    try? pipe.readEnd.close()
    throw error
  }
  let output = try pipe.readEnd.closeAfter { try readAll(pipe.readEnd) }
  return (try child.wait(), output)
}

#endif
