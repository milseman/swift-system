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

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

internal let shell: FilePath = "/bin/sh"

/// A pipe that no process writes to, whose read end is the standard input
/// of the children that `spawnWaitingChild` starts. Only this process holds
/// the write end, close-on-exec, so the pipe ends when this process does.
private let keepAlive: (readEnd: CInt, writeEnd: CInt) = {
  var ends: [CInt] = [-1, -1]
  precondition(pipe(&ends) == 0, "pipe: \(errno)")
  for end in ends { _ = fcntl(end, F_SETFD, FD_CLOEXEC) }
  return (ends[0], ends[1])
}()

/// The arguments and file actions of a child that runs until it's signaled:
/// `sh -c 'read line'`, reading a line that never comes, with its output
/// going nowhere. It ends by itself only after this process ends.
///
/// A test that needs a running child uses one rather than `sleep`, which a
/// busy machine can let finish before the test is done with it.
internal let waitingChildArguments = ["sh", "-c", "read line"]

@available(System 199, *)
internal var waitingChildFileActions: [SpawnFileAction] {
  [
    .duplicate(FileDescriptor(rawValue: keepAlive.readEnd), as: .standardInput),
    .open("/dev/null", .writeOnly, as: .standardOutput),
    .open("/dev/null", .writeOnly, as: .standardError),
  ]
}

/// Spawns a child that runs until it's signaled.
@available(System 199, *)
internal func spawnWaitingChild(attributes: SpawnAttributes = SpawnAttributes()) throws -> ProcessID {
  try ProcessID.spawn(
    shell, arguments: waitingChildArguments, fileActions: waitingChildFileActions,
    attributes: attributes)
}

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
