/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Terminal Descriptor")
private struct TerminalDescriptorTests {

  @available(System 199, *)
  @Test func checkedConversionFromTerminal() throws {
    try withPseudoterminal { controller, terminal in
      let converted = try TerminalDescriptor(terminal)
      #expect(converted.fileDescriptor == terminal)
      #expect(converted == TerminalDescriptor(unchecked: terminal))
      #expect(terminal.isTerminal)
      #expect(terminal.asTerminal == converted)

      // The controller is a terminal too.
      #expect(try TerminalDescriptor(controller).fileDescriptor == controller)
    }
  }

  @available(System 199, *)
  @Test func checkedConversionFromNonTerminal() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    #expect(throws: Errno.inappropriateIOCTLForDevice) {
      try TerminalDescriptor(pipe.readEnd)
    }
    #expect(throws: Errno.inappropriateIOCTLForDevice) {
      try TerminalDescriptor(pipe.writeEnd)
    }

    // A character device isn't necessarily a terminal.
    let devNull = try FileDescriptor.open("/dev/null", .readWrite)
    defer { try? devNull.close() }
    #expect(throws: Errno.inappropriateIOCTLForDevice) {
      try TerminalDescriptor(devNull)
    }
  }

  @available(System 199, *)
  @Test func checkedConversionFromInvalidDescriptor() {
    #expect(throws: Errno.badFileDescriptor) {
      try TerminalDescriptor(FileDescriptor(rawValue: -1))
    }
  }

  // Whatever stdin is, converting it either succeeds or throws
  // without disturbing the descriptor.
  @available(System 199, *)
  @Test func standardInput() throws {
    // Ask the terminal driver directly, rather than through isatty.
    // Only success is compared: tcgetattr's errno can differ from isatty's,
    // such as ENODEV for /dev/null on Darwin.
    var attributes = termios()
    let isTerminal = tcgetattr(STDIN_FILENO, &attributes) == 0
    let isOpen = fcntl(STDIN_FILENO, F_GETFD) != -1

    if isTerminal {
      let terminal = try TerminalDescriptor(.standardInput)
      #expect(terminal.fileDescriptor == .standardInput)
    } else {
      let expected: Errno = isOpen ? .inappropriateIOCTLForDevice : .badFileDescriptor
      #expect(throws: expected) {
        try TerminalDescriptor(.standardInput)
      }
    }
    #expect((fcntl(STDIN_FILENO, F_GETFD) != -1) == isOpen)
  }
}

#endif
