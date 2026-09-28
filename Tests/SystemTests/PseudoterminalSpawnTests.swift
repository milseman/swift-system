/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A child spawned on a pseudoterminal. An XCTest test, as the other tests
// that spawn processes are; see ProcessTestSupport.swift.

#if (SYSTEM_PACKAGE_DARWIN || os(Linux)) && !os(watchOS) && !os(tvOS)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class PseudoterminalSpawnTests: XCTestCase {
  /// A child in a new session that opens the terminal by its path gets it
  /// as its controlling terminal, as `login_tty` would give it,
  /// so the child can open `/dev/tty`.
  func testAChildInANewSessionGetsTheTerminalAsItsControllingTerminal() throws {
    let (controller, terminal) = try TerminalDescriptor.openPseudoterminal()
    defer { try? controller.close() }
    let path = try controller.pseudoterminalPath()
    let child: ProcessID
    do {
      defer { try? terminal.fileDescriptor.close() }
      child = try ProcessID.spawn(
        shell,
        arguments: [
          "sh", "-c",
          "if (exec </dev/tty) 2>/dev/null; then echo controlling; else echo none; fi",
        ],
        fileActions: [
          .open(path, .readWrite, as: .standardInput),
          .duplicate(.standardInput, as: .standardOutput),
          .duplicate(.standardInput, as: .standardError),
        ],
        attributes: SpawnAttributes(flags: .createSession))
    }
    // Read before waiting: on Darwin, the child's last close of the terminal
    // blocks until the controller reads what it wrote.
    let output = try readBytes(from: controller, count: "controlling\r\n".utf8.count)
    XCTAssertEqual(String(decoding: output, as: UTF8.self), "controlling\r\n")
    XCTAssertEqual(try child.wait(), .exited(0))
  }
}

#endif
