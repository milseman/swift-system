/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Pseudoterminals")
private struct PseudoterminalTests {
  /// Calls `body` with a new pseudoterminal's two ends, and closes them after.
  @available(System 199, *)
  private func withPseudoterminal<R>(
    attributes: TerminalAttributes? = nil,
    windowSize: TerminalDescriptor.WindowSize? = nil,
    closeOnExec: Bool = true,
    _ body: (FileDescriptor, TerminalDescriptor) throws -> R
  ) throws -> R {
    let (controller, terminal) = try TerminalDescriptor.openPseudoterminal(
      attributes: attributes, windowSize: windowSize, closeOnExec: closeOnExec)
    defer {
      try? terminal.fileDescriptor.close()
      try? controller.close()
    }
    return try body(controller, terminal)
  }

  @available(System 199, *)
  @Test func theEndsAreConnected() throws {
    try withPseudoterminal { controller, terminal throws in
      #expect(terminal.fileDescriptor.isTerminal)
      // In raw mode, bytes pass through unchanged, and aren't echoed.
      try terminal.setAttributes(terminal.attributes().raw(), when: .now)
      _ = try controller.writeAll("to the terminal".utf8)
      #expect(try readBytes(from: terminal.fileDescriptor, count: 15) == Array("to the terminal".utf8))
      _ = try terminal.fileDescriptor.writeAll("to the controller".utf8)
      #expect(try readBytes(from: controller, count: 17) == Array("to the controller".utf8))
    }
  }

  /// A new terminal is in canonical mode with echo, so the controller
  /// reads back what it writes, and the terminal reads a line at a time.
  @available(System 199, *)
  @Test func theDefaultsAreCanonicalModeWithEcho() throws {
    try withPseudoterminal { controller, terminal throws in
      let attributes = try terminal.attributes()
      #expect(attributes.localFlags.contains(.canonical))
      #expect(attributes.localFlags.contains(.echo))
      _ = try controller.writeAll("line\n".utf8)
      // The echo turns the newline into a carriage return and a newline.
      #expect(try readBytes(from: controller, count: 6) == Array("line\r\n".utf8))
      #expect(try readBytes(from: terminal.fileDescriptor, count: 5) == Array("line\n".utf8))
    }
  }

  @available(System 199, *)
  @Test func attributesAndWindowSizeApply() throws {
    let raw = try withPseudoterminal { _, terminal in try terminal.attributes().raw() }
    let size = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
    try withPseudoterminal(attributes: raw, windowSize: size) { controller, terminal throws in
      #expect(try terminal.attributes() == raw)
      #expect(try terminal.windowSize() == size)
      // Both ends share the window size.
      #expect(try TerminalDescriptor(unchecked: controller).windowSize() == size)
    }
    // Without a size, a new terminal has none.
    try withPseudoterminal { _, terminal throws in
      #expect(try terminal.windowSize() == TerminalDescriptor.WindowSize(rows: 0, columns: 0))
    }
  }

  @available(System 199, *)
  @Test func bothEndsCloseOnExecByDefault() throws {
    try withPseudoterminal { controller, terminal throws in
      #expect(try controller.descriptorFlags().contains(.closeOnExec))
      #expect(try terminal.fileDescriptor.descriptorFlags().contains(.closeOnExec))
    }
    try withPseudoterminal(closeOnExec: false) { controller, terminal throws in
      #expect(try !controller.descriptorFlags().contains(.closeOnExec))
      #expect(try !terminal.fileDescriptor.descriptorFlags().contains(.closeOnExec))
    }
  }

  @available(System 199, *)
  @Test func thePathNamesTheTerminal() throws {
    try withPseudoterminal { controller, terminal throws in
      let path = try controller.pseudoterminalPath()
      #if SYSTEM_PACKAGE_DARWIN
      #expect(path.string.hasPrefix("/dev/ttys"))
      #else
      #expect(path.string.hasPrefix("/dev/pts/"))
      #endif
      #expect(try path.stat().specialDeviceID == terminal.fileDescriptor.stat().specialDeviceID)
      #expect(String(cString: ttyname(terminal.rawValue)) == path.string)
    }
  }

  @available(System 199, *)
  @Test func onlyAControllerHasATerminalPath() throws {
    let null = try FileDescriptor.open("/dev/null", .readWrite)
    defer { try? null.close() }
    #expect(throws: Errno.self) { try null.pseudoterminalPath() }
    try withPseudoterminal { _, terminal throws in
      #expect(throws: Errno.self) { try terminal.fileDescriptor.pseudoterminalPath() }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
