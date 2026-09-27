/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: posix_spawn, its file actions and attributes, and exec, with
// real children. These are XCTest tests; see ProcessTestSupport.swift.

#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SpawnTests: XCTestCase {
  func testExitStatus() throws {
    XCTAssertEqual(try runShell("exit 3").status, .exited(3))
    let success = try runShell("exit 0").status
    XCTAssertTrue(success.isSuccess)
    XCTAssertEqual(success.description, "exited with status 0")
  }

  func testASignalEndsTheChild() throws {
    let status = try runShell("kill -TERM $$").status
    XCTAssertEqual(status, .signaled(.terminate, coreDumped: false))
    XCTAssertEqual(status.description, "ended by SIGTERM")
  }

  func testArgumentsIncludeTheProgramsName() throws {
    // sh -c takes the arguments after the script as $0, $1, and so on.
    let output = try runShell(#"echo "$0 $1""#, ["zero", "one"]).output
    XCTAssertEqual(output, "zero one\n")
  }

  func testEnvironment() throws {
    let explicit = try runShell("echo $GREETING", environment: ["GREETING=hello"])
    XCTAssertEqual(explicit.output, "hello\n")
    let empty = try runShell("echo ${HOME-unset}", environment: [])
    XCTAssertEqual(empty.output, "unset\n")

    // A nil environment is the calling process's.
    setenv("SYSTEM_SPAWN_TEST", "inherited", 1)
    defer { unsetenv("SYSTEM_SPAWN_TEST") }
    XCTAssertEqual(try runShell("echo $SYSTEM_SPAWN_TEST").output, "inherited\n")
  }

  func testSearchingThePath() throws {
    let child = try ProcessID.spawn(
      searchingPathFor: "sh", arguments: ["sh", "-c", "exit 5"])
    XCTAssertEqual(try child.wait(), .exited(5))
  }

  func testAMissingProgramThrowsAndLeavesNoChild() throws {
    XCTAssertThrowsError(
      try ProcessID.spawn("/nonexistent/program", arguments: ["program"])
    ) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(
      try ProcessID.spawn(searchingPathFor: "nonexistent-program", arguments: ["program"])
    ) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(try ProcessID.tryWaitForAnyChild()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testRawCArguments() throws {
    let strings: [String] = ["sh", "-c", "exit 6"]
    let arguments: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) } + [nil]
    defer { arguments.forEach { free($0) } }
    let child = try "/bin/sh".withCString { path in
      try arguments.withUnsafeBufferPointer {
        try ProcessID.spawn(path, arguments: $0.baseAddress!, environment: nil)
      }
    }
    XCTAssertEqual(try child.wait(), .exited(6))
  }

  func testOpenAction() throws {
    try withTemporaryFilePath(basename: "testOpenAction") { directory in
      let file = directory.appending("out.txt")
      let child = try ProcessID.spawn(
        shell, arguments: ["sh", "-c", "echo written; read line; echo read $?"],
        fileActions: [
          .open("/dev/null", .readOnly, as: .standardInput),
          .open(
            file, .writeOnly, options: [.create, .truncate], permissions: [.ownerReadWrite],
            as: .standardOutput),
        ])
      XCTAssertEqual(try child.wait(), .exited(0))
      let fd = try FileDescriptor.open(file, .readOnly)
      let output = try fd.closeAfter { try readAll(fd) }
      XCTAssertEqual(output, "written\nread 1\n")
    }
  }

  func testCloseAction() throws {
    // A descriptor without close-on-exec is inherited, unless closed.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let script = "echo x >&\(pipe.writeEnd.rawValue) 2>/dev/null; echo $?"
    XCTAssertEqual(try runShell(script).output, "0\n")
    let closed = try runShell(script, fileActions: [.close(pipe.writeEnd)])
    XCTAssertNotEqual(closed.output, "0\n")
  }

  func testWorkingDirectory() throws {
    try withTemporaryFilePath(basename: "testWorkingDirectory") { directory in
      let expected = try runShell("cd \"$0\" && pwd -P", [directory.string]).output
      do {
        let result = try runShell("pwd -P", fileActions: [.setWorkingDirectory(directory)])
        XCTAssertEqual(result.output, expected)
      } catch Errno.noFunction {
        throw XCTSkip("This platform has no posix_spawn chdir action")
      }
      let fd = try FileDescriptor.open(directory, .readOnly, options: .directory)
      try fd.closeAfter {
        let result = try runShell("pwd -P", fileActions: [.setWorkingDirectory(fd)])
        XCTAssertEqual(result.output, expected)
      }
    }
  }

  func testNewProcessGroup() throws {
    let leader = try ProcessID.spawn(
      "/bin/sleep", arguments: ["sleep", "10"],
      attributes: SpawnAttributes(processGroup: .new))
    defer {
      try? leader.sendSignal(.kill)
      _ = try? leader.wait()
    }
    XCTAssertEqual(try leader.processGroup(), leader)
    XCTAssertNotEqual(try leader.processGroup(), ProcessID.currentProcessGroup)

    let member = try ProcessID.spawn(
      "/bin/sleep", arguments: ["sleep", "10"],
      attributes: SpawnAttributes(processGroup: .existing(leader)))
    defer {
      try? member.sendSignal(.kill)
      _ = try? member.wait()
    }
    XCTAssertEqual(try member.processGroup(), leader)

    // Signaling the group reaches both.
    try leader.sendSignalToProcessGroup(.terminate)
    XCTAssertEqual(try leader.wait(), .signaled(.terminate, coreDumped: false))
    XCTAssertEqual(try member.wait(), .signaled(.terminate, coreDumped: false))
  }

  func testTheChildStaysInTheParentsGroupByDefault() throws {
    let child = try ProcessID.spawn("/bin/sleep", arguments: ["sleep", "10"])
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    XCTAssertEqual(try child.processGroup(), ProcessID.currentProcessGroup)
    XCTAssertEqual(try child.sessionID(), try ProcessID.current.sessionID())
  }

  #if SYSTEM_PACKAGE_DARWIN || os(Linux)
  func testNewSession() throws {
    let child: ProcessID
    do {
      child = try ProcessID.spawn(
        "/bin/sleep", arguments: ["sleep", "10"],
        attributes: SpawnAttributes(flags: .createSession))
    } catch Errno.invalidArgument {
      throw XCTSkip("This C library has no POSIX_SPAWN_SETSID")
    }
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    XCTAssertEqual(try child.sessionID(), child)
    XCTAssertEqual(try child.processGroup(), child)
  }
  #endif

  func testSignalMask() throws {
    // A blocked signal stays pending, and the child exits normally.
    let script = "kill -USR1 $$; exit 0"
    XCTAssertEqual(
      try runShell(script, attributes: SpawnAttributes(signalMask: [.userDefined1])).status,
      .exited(0))
    XCTAssertEqual(
      try runShell(script, attributes: SpawnAttributes(signalMask: [])).status,
      .signaled(.userDefined1, coreDumped: false))
  }

  func testByDefaultAChildBlocksNothing() throws {
    // C passes on the spawning thread's mask; SpawnAttributes() doesn't,
    // unless its signalMask is nil.
    let previous = PThread.blockSignals([.userDefined1])
    defer { PThread.setCurrentSignalMask(previous) }
    let script = "kill -USR1 $$; exit 0"
    XCTAssertEqual(
      try runShell(script).status, .signaled(.userDefined1, coreDumped: false))
    XCTAssertEqual(
      try runShell(script, attributes: SpawnAttributes(signalMask: nil)).status, .exited(0))
  }

  func testDefaultSignals() throws {
    // C passes on the signals the parent ignores; SpawnAttributes()
    // resets them, unless its defaultSignals is nil.
    let previous = try Signal.userDefined1.setAction(.ignore)
    defer { _ = try? Signal.userDefined1.setAction(previous) }
    let script = "kill -USR1 $$; exit 0"
    XCTAssertEqual(
      try runShell(script).status, .signaled(.userDefined1, coreDumped: false))
    XCTAssertEqual(
      try runShell(script, attributes: SpawnAttributes(defaultSignals: nil)).status,
      .exited(0))
    XCTAssertEqual(
      try runShell(script, attributes: SpawnAttributes(defaultSignals: [.userDefined1])).status,
      .signaled(.userDefined1, coreDumped: false))
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testCloseOnExecByDefault() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let script = "echo x >&\(pipe.writeEnd.rawValue) 2>/dev/null; echo $?"
    let attributes = SpawnAttributes(flags: .closeOnExecByDefault)
    // Only the descriptors that file actions name reach the child.
    XCTAssertNotEqual(try runShell(script, attributes: attributes).output, "0\n")
    let inherited = try runShell(
      script, fileActions: [.inherit(pipe.writeEnd)], attributes: attributes)
    XCTAssertEqual(inherited.output, "0\n")
  }

  func testStartSuspended() throws {
    var child = ChildProcess(taking: try ProcessID.spawn(
      shell, arguments: ["sh", "-c", "exit 7"],
      attributes: SpawnAttributes(flags: .startSuspended)))
    usleep(100_000)
    let early = try child.tryWait()
    XCTAssertNil(early)
    try child.sendSignal(.continue)
    let status = try child.wait()
    XCTAssertEqual(status, .exited(7))
  }

  func testQualityOfService() throws {
    var attributes = SpawnAttributes()
    attributes.qualityOfService = .utility
    XCTAssertEqual(try runShell("exit 0", attributes: attributes).status, .exited(0))
    // Darwin accepts only utility and background.
    attributes.qualityOfService = .userInteractive
    XCTAssertThrowsError(try runShell("exit 0", attributes: attributes)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }
  #endif

  func testExecutingAMissingProgramThrows() {
    XCTAssertThrowsError(try ProcessID.execute("/nonexistent/program", arguments: ["x"])) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(
      try ProcessID.execute(searchingPathFor: "nonexistent-program", arguments: ["x"])
    ) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertThrowsError(
      try ProcessID.execute(
        "/nonexistent/program", arguments: ["x"],
        attributes: SpawnAttributes(flags: .closeOnExecByDefault))
    ) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    #endif
  }
}

#if ENABLE_MOCKING
@available(System 199, *)
final class SpawnMockTests: XCTestCase {
  func testSpawn() {
    let cases: [MockTestCase] = [
      MockTestCase(
        name: "posix_spawn", .noInterrupt, "/bin/sh", ["sh", "-c", "true"], ["A=1"]
      ) { _ in
        _ = try ProcessID.spawn(shell, arguments: ["sh", "-c", "true"], environment: ["A=1"])
      },
      MockTestCase(name: "posix_spawn", .noInterrupt, "/bin/sh", ["sh"], Wildcard()) { _ in
        _ = try ProcessID.spawn(shell, arguments: ["sh"])
      },
      MockTestCase(name: "posix_spawnp", .noInterrupt, "sh", [String](), [String]()) { _ in
        _ = try ProcessID.spawn(searchingPathFor: "sh", arguments: [], environment: [])
      },
    ]
    cases.forEach { $0.runAllTests() }
  }

  func testAMockedChildIsNoProcess() throws {
    try MockingDriver.withMockingEnabled { _ in
      let child = try ProcessID.spawn(shell, arguments: ["sh"])
      XCTAssertEqual(child, ProcessID(rawValue: .max))
    }
  }

  func testExecute() throws {
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertThrowsError(try ProcessID.execute(shell, arguments: ["sh"], environment: [])) {
        XCTAssertEqual($0 as? Errno, .execFormatError)
      }
      XCTAssertEqual(
        mocking.trace.dequeue()?.matches(
          Trace.Entry(name: "execve", ["/bin/sh", ["sh"], [String]()])), true)
      mocking.forceErrno = .always(errno: EACCES)
      XCTAssertThrowsError(try ProcessID.execute(searchingPathFor: "sh", arguments: ["sh"])) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
      XCTAssertEqual(
        mocking.trace.dequeue()?.matches(Trace.Entry(name: "execvp", ["sh", ["sh"]])), true)
    }
  }
}
#endif // ENABLE_MOCKING

#endif
