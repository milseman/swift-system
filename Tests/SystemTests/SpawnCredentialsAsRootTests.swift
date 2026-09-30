/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Spawning as another user and groups, which takes root: the Linux
// containers run tests as root, and other runs skip these. XCTest, as
// SpawnCredentialsTest is: the children are the process's own.

#if SYSTEM_PACKAGE_DARWIN || os(Linux)

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

@available(System 199, *)
final class SpawnCredentialsAsRootTest: XCTestCase {
  /// The calling thread's supplementary groups.
  private func groups() -> [gid_t] {
    let count = getgroups(0, nil)
    var groups = [gid_t](repeating: 0, count: Int(max(count, 0)))
    let read = getgroups(count, &groups)
    return Array(groups.prefix(Int(max(read, 0))))
  }

  /// The child runs as the user and groups asked for, and the calling
  /// process keeps its own; on Linux, whose spawn sets them on a thread of
  /// its own, that means every other thread's too.
  func testAnotherUsersChild() throws {
    try XCTSkipUnless(getuid() == 0, "only root can give a child another user")
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    try writer.setDescriptorFlags(.closeOnExec)
    let before = (getuid(), geteuid(), getgid(), groups())
    let child = try ProcessID.spawn(
      "/bin/sh", arguments: ["sh", "-c", "id -u; id -g; id -G"],
      environment: ["PATH=/usr/bin:/bin"],
      fileActions: [.duplicate(writer, as: .standardOutput)],
      credentials: SpawnCredentials(
        user: UserID(rawValue: 1234), group: GroupID(rawValue: 5678),
        supplementaryGroups: [GroupID(rawValue: 4242)]))
    try writer.close()
    var output: [UInt8] = []
    var byte: UInt8 = 0
    while try withUnsafeMutableBytes(of: &byte, { try reader.read(into: $0) }) == 1 {
      output.append(byte)
    }
    XCTAssertEqual(try child.wait(), .exited(0))
    let lines = String(decoding: output, as: UTF8.self).split(separator: "\n")
    XCTAssertEqual(lines.first, "1234")
    XCTAssertEqual(lines.dropFirst().first, "5678")
    XCTAssertEqual(Set(lines.last?.split(separator: " ") ?? []), ["5678", "4242"])
    let after = (getuid(), geteuid(), getgid(), groups())
    XCTAssertTrue(before == after, "\(before) != \(after)")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux)
