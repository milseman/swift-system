/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Spawning with other credentials (fork, the credential calls, and
// posix_spawn with POSIX_SPAWN_SETEXEC). XCTest, as for SpawnTests: the
// children are the process's own. A process that isn't root can only keep
// its own user and group, so the real spawns use those, and the errors
// come from asking for more.

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SpawnCredentialsTest: XCTestCase {
  private var ownCredentials: SpawnCredentials {
    SpawnCredentials(user: UserID(rawValue: getuid()), group: GroupID(rawValue: getgid()))
  }

  /// Reads a pipe's read end to its end.
  private func readAll(_ reader: FileDescriptor) throws -> String {
    var output: [UInt8] = []
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 256, alignment: 1)
    defer { buffer.deallocate() }
    while true {
      let count = try reader.read(into: buffer)
      if count == 0 { return String(decoding: output, as: UTF8.self) }
      output += buffer[..<count]
    }
  }

  func testTheChildRunsAsTheUser() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    // Close-on-exec, as a careful caller's descriptors are, which the
    // child's file actions still use.
    try writer.setDescriptorFlags(.closeOnExec)
    try reader.setDescriptorFlags(.closeOnExec)
    let child = try ProcessID.spawn(
      "/bin/sh", arguments: ["sh", "-c", "id -u; id -g; echo $GREETING"],
      environment: ["GREETING=hello", "PATH=/usr/bin:/bin"],
      fileActions: [.duplicate(writer, as: .standardOutput), .close(writer), .close(reader)],
      credentials: ownCredentials)
    try writer.close()
    let output = try readAll(reader)
    XCTAssertEqual(try child.wait(), .exited(0))
    XCTAssertEqual(output, "\(getuid())\n\(getgid())\nhello\n")
  }

  func testSearchingThePath() throws {
    let child = try ProcessID.spawn(
      searchingPathFor: "sh", arguments: ["sh", "-c", "exit 5"], credentials: SpawnCredentials())
    XCTAssertEqual(try child.wait(), .exited(5))
    XCTAssertThrowsError(
      try ProcessID.spawn(
        searchingPathFor: "no-such-program-here", arguments: ["x"], credentials: SpawnCredentials())
    ) { XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory) }
  }

  func testTheChildsErrorsComeBack() throws {
    XCTAssertThrowsError(
      try ProcessID.spawn("/nonexistent/program", arguments: ["program"], credentials: ownCredentials)
    ) { XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory) }
    // A file action's descriptor that isn't open.
    XCTAssertThrowsError(
      try ProcessID.spawn(
        "/bin/sh", arguments: ["sh", "-c", "exit 0"],
        fileActions: [.close(FileDescriptor(rawValue: 1000))], credentials: ownCredentials)
    ) { XCTAssertEqual($0 as? Errno, .badFileDescriptor) }
  }

  func testCredentialsThatNeedRoot() throws {
    try XCTSkipIf(getuid() == 0, "root can change its credentials")
    XCTAssertThrowsError(
      try ProcessID.spawn(
        "/bin/sh", arguments: ["sh", "-c", "exit 0"],
        credentials: SpawnCredentials(supplementaryGroups: []))
    ) { XCTAssertEqual($0 as? Errno, .notPermitted) }
    XCTAssertThrowsError(
      try ProcessID.spawn(
        "/bin/sh", arguments: ["sh", "-c", "exit 0"],
        credentials: SpawnCredentials(user: UserID(rawValue: 0)))
    ) { XCTAssertEqual($0 as? Errno, .notPermitted) }
  }

  /// C values, as Subprocess's configurator leaves them, which keep their
  /// flags: POSIX_SPAWN_SETEXEC is set only on the child's copy.
  func testCValues() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    try writer.setDescriptorFlags(.closeOnExec)
    let actions: [SpawnFileAction] = [.duplicate(writer, as: .standardOutput), .close(writer)]
    let (child, flags) = try SpawnFileAction.withCFileActions(actions) { fileActions in
      try SpawnAttributes().withCAttributes { attributes in
        let child = try ProcessID.spawn(
          "/bin/sh", arguments: ["sh", "-c", "echo raw; exit 6"],
          cFileActions: &fileActions, cAttributes: &attributes,
          credentials: ownCredentials, fileActionDescriptors: [writer])
        return (child, try SpawnAttributes.Flags(of: &attributes))
      }
    }
    try writer.close()
    XCTAssertEqual(try readAll(reader), "raw\n")
    XCTAssertEqual(try child.wait(), .exited(6))
    XCTAssertEqual(flags.rawValue & CShort(POSIX_SPAWN_SETEXEC), 0)

    // Without C values.
    let other = try ProcessID.spawn(
      "/bin/sh", arguments: ["sh", "-c", "exit 2"], cFileActions: nil, cAttributes: nil,
      credentials: SpawnCredentials(), fileActionDescriptors: [])
    XCTAssertEqual(try other.wait(), .exited(2))
  }

  #if ENABLE_MOCKING
  func testCalls() throws {
    let user = UserID(rawValue: 501)
    let group = GroupID(rawValue: 20)
    try MockingDriver.withMockingEnabled { mocking in
      _ = try ProcessID.spawn(
        "/bin/true", arguments: ["true"],
        fileActions: [
          .duplicate(FileDescriptor(rawValue: 5), as: .standardOutput),
          .open("/dev/null", .readOnly, as: .standardInput),
          .close(FileDescriptor(rawValue: 6)),
        ],
        credentials: SpawnCredentials(
          user: user, group: group, supplementaryGroups: [GroupID(rawValue: 12)]))
      _ = try ProcessID.spawn(
        searchingPathFor: "true", arguments: ["true"], credentials: SpawnCredentials())
      mocking.forceErrno = .counted(errno: EPERM, count: 1)
      XCTAssertThrowsError(
        try ProcessID.spawn("/bin/true", arguments: ["true"], credentials: SpawnCredentials())
      ) { XCTAssertEqual($0 as? Errno, .notPermitted) }

      var calls: [(String, [AnyHashable])] = []
      while let entry = mocking.trace.dequeue() { calls.append((entry.name, entry.arguments)) }
      // The mock records the optional credentials as optionals.
      let none: AnyHashable = Optional<UInt32>.none
      let noGroups: AnyHashable = Optional<[UInt32]>.none
      XCTAssertEqual(calls.map(\.0), Array(repeating: "spawn_with_credentials", count: 3))
      XCTAssertEqual(calls.map(\.1), [
        ["/bin/true", false, Optional(user.rawValue), Optional(group.rawValue), Optional([UInt32(12)]),
         [CInt(5), CInt(6)]],
        ["true", true, none, none, noGroups, [CInt]()],
        ["/bin/true", false, none, none, noGroups, [CInt]()],
      ] as [[AnyHashable]])
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN
