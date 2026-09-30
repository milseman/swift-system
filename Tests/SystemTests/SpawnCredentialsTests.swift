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

  /// The names of the descriptors that are open in a shell that `spawn`
  /// starts, whose standard output it connects to `writer`, the write end of
  /// a close-on-exec pipe, which is checked as `writer`.
  private func descriptorsOpen(
    among descriptors: KeyValuePairs<String, FileDescriptor>,
    _ spawn: (_ arguments: [String], _ writer: FileDescriptor) throws -> ProcessID
  ) throws -> [String] {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    try reader.setDescriptorFlags(.closeOnExec)
    try writer.setDescriptorFlags(.closeOnExec)
    let named = Array(descriptors) + [(key: "writer", value: writer)]
    let script = named.map {
      "if [ -e /dev/fd/\($0.value.rawValue) ]; then echo \($0.key); fi"
    }.joined(separator: "; ")
    let child: ProcessID
    do {
      child = try spawn(["sh", "-c", script], writer)
    } catch {
      try? writer.close()
      throw error
    }
    try writer.close()
    let output = try readAll(reader)
    XCTAssertEqual(try child.wait(), .exited(0))
    return output.split(separator: "\n").map(String.init)
  }

  /// The child clears close-on-exec on the descriptors that the file actions
  /// use, and the program still gets the descriptors that a spawn without
  /// credentials gives it.
  func testTheProgramGetsTheDescriptorsASpawnWould() throws {
    func open(_ path: FilePath, closeOnExec: Bool = true) throws -> FileDescriptor {
      let descriptor = try FileDescriptor.open(path, .readOnly)
      if closeOnExec { try descriptor.setDescriptorFlags(.closeOnExec) }
      return descriptor
    }
    let directory = try open("/")
    let same = try open("/dev/null")
    let inherited = try open("/dev/null")
    let closed = try open("/dev/null")
    let replaced = try open("/dev/null")
    let plain = try open("/dev/null", closeOnExec: false)
    defer {
      for descriptor in [directory, same, inherited, closed, replaced, plain] {
        try? descriptor.close()
      }
    }
    let descriptors: KeyValuePairs = [
      "directory": directory, "same": same, "inherited": inherited, "closed": closed,
      "replaced": replaced, "plain": plain,
    ]
    // Close-on-exec but `plain`. A close-on-exec descriptor that the actions
    // use only as a source is closed when the program starts: the pipe's
    // write end, a duplicate's source, and a working directory; so is one
    // duplicated onto itself, which on Darwin keeps its flag, where glibc's
    // posix_spawn clears it, as POSIX.1-2024 has it.
    // `inherit` is Darwin's (posix_spawn_file_actions_addinherit_np), so
    // elsewhere `inherited` is closed, as any close-on-exec descriptor is.
    func actions(_ writer: FileDescriptor) -> [SpawnFileAction] {
      var actions: [SpawnFileAction] = [
        .duplicate(writer, as: .standardOutput),
        .setWorkingDirectory(directory),
        .duplicate(same, as: same),
      ]
      #if SYSTEM_PACKAGE_DARWIN
      actions.append(.inherit(inherited))
      #endif
      actions += [
        .close(closed),
        .duplicate(replaced, as: .standardInput),
        .duplicate(plain, as: replaced),
      ]
      return actions
    }
    #if SYSTEM_PACKAGE_DARWIN
    let expected = ["inherited", "replaced", "plain"]
    #else
    let expected = ["same", "replaced", "plain"]
    #endif
    XCTAssertEqual(
      try descriptorsOpen(among: descriptors) { arguments, writer in
        try ProcessID.spawn("/bin/sh", arguments: arguments, fileActions: actions(writer))
      }, expected)
    XCTAssertEqual(
      try descriptorsOpen(among: descriptors) { arguments, writer in
        try ProcessID.spawn(
          "/bin/sh", arguments: arguments, fileActions: actions(writer),
          credentials: ownCredentials)
      }, expected)

    // A pipe's close-on-exec write end as the standard output, the
    // commonest case, alone.
    XCTAssertEqual(
      try descriptorsOpen(among: [:]) { arguments, writer in
        try ProcessID.spawn(
          "/bin/sh", arguments: arguments, fileActions: [.duplicate(writer, as: .standardOutput)],
          credentials: SpawnCredentials())
      }, [])
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// C file actions can't be read, so a close-on-exec descriptor among
  /// `fileActionDescriptors` stays open in the program unless the actions
  /// close it, or the attributes close what the actions don't install.
  /// (On Linux the descriptors are unused, and exec closes them.)
  func testCValuesKeepTheDescriptorsTheyUse() throws {
    func spawn(
      _ arguments: [String], _ writer: FileDescriptor, closing: Bool,
      attributes: SpawnAttributes = SpawnAttributes()
    ) throws -> ProcessID {
      let actions: [SpawnFileAction] =
        [.duplicate(writer, as: .standardOutput)] + (closing ? [.close(writer)] : [])
      return try SpawnFileAction.withCFileActions(actions) { fileActions in
        try attributes.withCAttributes { cAttributes in
          try ProcessID.spawn(
            "/bin/sh", arguments: arguments, cFileActions: &fileActions,
            cAttributes: &cAttributes, credentials: SpawnCredentials(),
            fileActionDescriptors: [writer])
        }
      }
    }
    XCTAssertEqual(try descriptorsOpen(among: [:]) { try spawn($0, $1, closing: false) }, ["writer"])
    XCTAssertEqual(try descriptorsOpen(among: [:]) { try spawn($0, $1, closing: true) }, [])
    XCTAssertEqual(
      try descriptorsOpen(among: [:]) {
        try spawn($0, $1, closing: false, attributes: SpawnAttributes(flags: .closeOnExecByDefault))
      }, [])
  }
  #endif

  /// Arguments and an environment as C arrays, whose bytes needn't be UTF-8,
  /// with System's file actions and with C values.
  func testCArrays() throws {
    let arguments: [[UInt8]] = [Array("sh".utf8), Array("-c".utf8), checksTheByte, Array("sh".utf8), [0xff]]
    let child = try withCStringArray(arguments) { arguments in
      try withCStringArray([Array("BYTE=".utf8) + [0xff]]) { environment in
        try ProcessID.spawn(
          "/bin/sh", arguments: arguments, environment: environment, credentials: ownCredentials)
      }
    }
    XCTAssertEqual(try child.wait(), .exited(0))
    let other = try withCStringArray(arguments) { arguments in
      try ProcessID.spawn(
        "/bin/sh", arguments: arguments, environment: nil, cFileActions: nil, cAttributes: nil,
        credentials: ownCredentials, fileActionDescriptors: [])
    }
    XCTAssertEqual(try other.wait(), .exited(0))
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
    // A file action's descriptor that isn't open. glibc's posix_spawn
    // ignores closing one, so on Linux it's a duplicate's source.
    #if SYSTEM_PACKAGE_DARWIN
    let badAction = SpawnFileAction.close(FileDescriptor(rawValue: 1000))
    #else
    let badAction = SpawnFileAction.duplicate(FileDescriptor(rawValue: 1000), as: .standardInput)
    #endif
    XCTAssertThrowsError(
      try ProcessID.spawn(
        "/bin/sh", arguments: ["sh", "-c", "exit 0"],
        fileActions: [badAction], credentials: ownCredentials)
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
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertEqual(flags.rawValue & CShort(POSIX_SPAWN_SETEXEC), 0)
    #else
    _ = flags
    #endif

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
      _ = try withCStringArray([Array("true".utf8)]) {
        try ProcessID.spawn("/bin/true", arguments: $0, environment: nil, credentials: SpawnCredentials())
      }

      var calls: [(String, [AnyHashable])] = []
      while let entry = mocking.trace.dequeue() { calls.append((entry.name, entry.arguments)) }
      // The mock records the optional credentials as optionals. First, on
      // Darwin, the parent reads the flags of 5, a duplicate's source (the
      // mock's are clear, so no close is added), but not of 6, which an
      // action closes; Linux adds no closes.
      let none: AnyHashable = Optional<UInt32>.none
      let noGroups: AnyHashable = Optional<[UInt32]>.none
      #if SYSTEM_PACKAGE_DARWIN
      let flagReads: [(String, [AnyHashable])] = [("fcntl", [CInt(5), F_GETFD])]
      #else
      let flagReads: [(String, [AnyHashable])] = []
      #endif
      XCTAssertEqual(
        calls.map(\.0), flagReads.map(\.0) + Array(repeating: "spawn_with_credentials", count: 4))
      XCTAssertEqual(calls.map(\.1), flagReads.map(\.1) + [
        ["/bin/true", false, Optional(user.rawValue), Optional(group.rawValue), Optional([UInt32(12)]),
         [CInt(5), CInt(6)]],
        ["true", true, none, none, noGroups, [CInt]()],
        ["/bin/true", false, none, none, noGroups, [CInt]()],
        ["/bin/true", false, none, none, noGroups, [CInt]()],
      ] as [[AnyHashable]])
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux)
