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

  // glibc declares posix_openpt(3) and friends only under _XOPEN_SOURCE,
  // which Swift's Glibc module doesn't define.
  #if !(os(Linux) && canImport(Glibc))
  @Test func checkedConversionFromTerminal() throws {
    try withPseudoterminal { terminal in
      let converted = try TerminalDescriptor(terminal)
      #expect(converted.fileDescriptor == terminal)
      #expect(converted == TerminalDescriptor(unchecked: terminal))
    }
  }
  #endif

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

  @Test func checkedConversionFromInvalidDescriptor() {
    #expect(throws: Errno.badFileDescriptor) {
      try TerminalDescriptor(FileDescriptor(rawValue: -1))
    }
  }

  // Whatever stdin is, converting it either succeeds or throws
  // without disturbing the descriptor.
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

#if !(os(Linux) && canImport(Glibc))
/// Opens a pseudoterminal and calls `body` with its terminal end.
private func withPseudoterminal(_ body: (FileDescriptor) throws -> Void) throws {
  let controller = FileDescriptor(rawValue: posix_openpt(O_RDWR | O_NOCTTY))
  guard controller.rawValue != -1 else { throw Errno(rawValue: errno) }
  defer { try? controller.close() }

  guard grantpt(controller.rawValue) == 0,
        unlockpt(controller.rawValue) == 0,
        let path = ptsname(controller.rawValue)
  else { throw Errno(rawValue: errno) }

  let terminal = try FileDescriptor.open(
    path, .readWrite, options: FileDescriptor.OpenOptions(rawValue: O_NOCTTY))
  defer { try? terminal.close() }
  try body(terminal)
}
#endif

#endif
