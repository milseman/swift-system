/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

import XCTest

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
import SystemPackage
#else
import System
#endif

@available(System 199, *)
final class TerminalTests: XCTestCase {

  // MARK: - TerminalDescriptor Initialization Tests

  func testTerminalDescriptorInitWithNonTerminal() throws {
    // Create a pipe - pipes are not terminals
    let fds = try FileDescriptor.pipe()
    defer {
      try? fds.readEnd.close()
      try? fds.writeEnd.close()
    }

    // Should throw for non-terminal file descriptors
    XCTAssertThrowsError(try TerminalDescriptor(fds.readEnd))
    XCTAssertThrowsError(try TerminalDescriptor(fds.writeEnd))
    XCTAssertFalse(fds.readEnd.isTerminal)
    XCTAssertFalse(fds.writeEnd.isTerminal)
  }

  func testTerminalDescriptorUncheckedInit() throws {
    // Unchecked init doesn't validate - just wraps the descriptor
    let fd = FileDescriptor.standardInput
    let terminal = TerminalDescriptor(unchecked: fd)
    XCTAssertEqual(terminal.rawValue, fd.rawValue)
    XCTAssertEqual(terminal.fileDescriptor, fd)
  }

  func testFileDescriptorIsTerminalProperty() throws {
    // Test isTerminal property - may vary depending on test environment
    // Just verify it doesn't crash
    let _ = FileDescriptor.standardInput.isTerminal
    let _ = FileDescriptor.standardOutput.isTerminal
    let _ = FileDescriptor.standardError.isTerminal
  }

  func testFileDescriptorAsTerminalProperty() throws {
    // Create a pipe to ensure we have a non-terminal
    let fds = try FileDescriptor.pipe()
    defer {
      try? fds.readEnd.close()
      try? fds.writeEnd.close()
    }

    XCTAssertNil(fds.readEnd.asTerminal)
    XCTAssertNil(fds.writeEnd.asTerminal)
  }

  // MARK: - TerminalAttributes Basic Tests

  func testTerminalAttributesInit() {
    let attrs = TerminalAttributes()
    // Should create zero-initialized attributes
    XCTAssertNotNil(attrs)
  }

  func testTerminalAttributesEquatable() {
    let attrs1 = TerminalAttributes()
    let attrs2 = TerminalAttributes()

    XCTAssertEqual(attrs1, attrs2)

    var attrs3 = TerminalAttributes()
    attrs3.inputFlags.insert(.breakInterrupt)

    XCTAssertNotEqual(attrs1, attrs3)
  }

  func testTerminalAttributesHashable() {
    let attrs1 = TerminalAttributes()
    let attrs2 = TerminalAttributes()

    XCTAssertEqual(attrs1.hashValue, attrs2.hashValue)

    var set = Set<TerminalAttributes>()
    set.insert(attrs1)
    XCTAssertTrue(set.contains(attrs2))
  }

  // MARK: - Flag Tests

  func testInputFlags() {
    var flags = InputFlags()
    XCTAssertTrue(flags.isEmpty)

    flags.insert(.breakInterrupt)
    XCTAssertTrue(flags.contains(.breakInterrupt))
    XCTAssertFalse(flags.contains(.ignoreCR))

    flags.insert(.mapCRToNL)
    XCTAssertTrue(flags.contains(.breakInterrupt))
    XCTAssertTrue(flags.contains(.mapCRToNL))

    flags.remove(.breakInterrupt)
    XCTAssertFalse(flags.contains(.breakInterrupt))
    XCTAssertTrue(flags.contains(.mapCRToNL))

    // Test set operations
    let flags2: InputFlags = [.ignoreBreak, .ignoreCR]
    let union = flags.union(flags2)
    XCTAssertTrue(union.contains(.mapCRToNL))
    XCTAssertTrue(union.contains(.ignoreBreak))
    XCTAssertTrue(union.contains(.ignoreCR))
  }

  func testOutputFlags() {
    var flags = OutputFlags()
    XCTAssertTrue(flags.isEmpty)

    flags.insert(.postProcess)
    XCTAssertTrue(flags.contains(.postProcess))

    flags.insert(.mapNLToCRNL)
    XCTAssertTrue(flags.contains(.postProcess))
    XCTAssertTrue(flags.contains(.mapNLToCRNL))
  }

  func testControlFlags() {
    var flags = ControlFlags()
    XCTAssertTrue(flags.isEmpty)

    flags.insert(.enableReceiver)
    XCTAssertTrue(flags.contains(.enableReceiver))

    flags.insert(.characterSize8)
    XCTAssertTrue(flags.contains(.characterSize8))
  }

  func testLocalFlags() {
    var flags = LocalFlags()
    XCTAssertTrue(flags.isEmpty)

    flags.insert(.echo)
    XCTAssertTrue(flags.contains(.echo))

    flags.insert(.canonical)
    XCTAssertTrue(flags.contains(.canonical))

    flags.remove(.echo)
    XCTAssertFalse(flags.contains(.echo))
    XCTAssertTrue(flags.contains(.canonical))
  }

  // MARK: - TerminalAttributes Flag Properties

  func testTerminalAttributesFlagProperties() {
    var attrs = TerminalAttributes()

    // Test input flags
    attrs.inputFlags.insert(.breakInterrupt)
    XCTAssertTrue(attrs.inputFlags.contains(.breakInterrupt))

    // Test output flags
    attrs.outputFlags.insert(.postProcess)
    XCTAssertTrue(attrs.outputFlags.contains(.postProcess))

    // Test control flags
    attrs.controlFlags.insert(.enableReceiver)
    XCTAssertTrue(attrs.controlFlags.contains(.enableReceiver))

    // Test local flags
    attrs.localFlags.insert(.echo)
    XCTAssertTrue(attrs.localFlags.contains(.echo))
  }

  // MARK: - Control Character Tests

  func testControlCharacterConstants() {
    // Just verify the constants exist and have distinct values
    XCTAssertNotEqual(ControlCharacter.endOfFile.rawValue, ControlCharacter.interrupt.rawValue)
    XCTAssertNotEqual(ControlCharacter.erase.rawValue, ControlCharacter.kill.rawValue)
  }

  func testControlCharactersSubscript() {
    var cc = ControlCharacters()

    // Test typed subscript
    cc[.interrupt] = 0x03  // Ctrl-C
    XCTAssertEqual(cc[.interrupt], 0x03)

    cc[.endOfFile] = 0x04  // Ctrl-D
    XCTAssertEqual(cc[.endOfFile], 0x04)

    // Test minimum/time for non-canonical mode
    cc[.minimum] = 1
    cc[.time] = 0
    XCTAssertEqual(cc[.minimum], 1)
    XCTAssertEqual(cc[.time], 0)
  }

  func testControlCharactersRawIndexSubscript() {
    var cc = ControlCharacters()

    // Test raw index subscript
    XCTAssertGreaterThan(ControlCharacters.count, 0)

    for i in 0..<ControlCharacters.count {
      cc[rawIndex: i] = UInt8(i)
      XCTAssertEqual(cc[rawIndex: i], UInt8(i))
    }
  }

  func testControlCharactersDisabled() {
    let disabled = ControlCharacters.disabled
    XCTAssertEqual(disabled, 0xFF)  // _POSIX_VDISABLE is typically 0xFF
  }

  func testControlCharactersHashable() {
    var cc1 = ControlCharacters()
    cc1[.interrupt] = 0x03

    var cc2 = ControlCharacters()
    cc2[.interrupt] = 0x03

    XCTAssertEqual(cc1, cc2)
    XCTAssertEqual(cc1.hashValue, cc2.hashValue)

    cc2[.endOfFile] = 0x04
    XCTAssertNotEqual(cc1, cc2)
  }

  // MARK: - Baud Rate Tests

  func testBaudRateConstants() {
    // Test common baud rates
    XCTAssertNotEqual(BaudRate.b9600.rawValue, BaudRate.b19200.rawValue)
    XCTAssertNotEqual(BaudRate.b115200.rawValue, BaudRate.b9600.rawValue)

    // Test special hangUp rate
    XCTAssertNotNil(BaudRate.hangUp)
  }

  func testBaudRateEquatable() {
    XCTAssertEqual(BaudRate.b9600, BaudRate.b9600)
    XCTAssertNotEqual(BaudRate.b9600, BaudRate.b19200)
  }

  func testTerminalAttributesBaudRates() {
    var attrs = TerminalAttributes()

    attrs.inputSpeed = .b9600
    attrs.outputSpeed = .b19200

    // Verify they were set (values might be platform-specific)
    XCTAssertNotNil(attrs.inputSpeed)
    XCTAssertNotNil(attrs.outputSpeed)
  }

  func testTerminalAttributesSetSpeed() {
    var attrs = TerminalAttributes()
    attrs.setSpeed(.b115200)

    // After setSpeed, both input and output should be the same
    XCTAssertEqual(attrs.inputSpeed, attrs.outputSpeed)
  }

  // MARK: - Serial Port Convenience Properties

  func testCharacterSize() {
    var attrs = TerminalAttributes()

    // Test character size get/set
    attrs.characterSize = .bits8
    XCTAssertEqual(attrs.characterSize, .bits8)

    attrs.characterSize = .bits7
    XCTAssertEqual(attrs.characterSize, .bits7)

    // Verify CSIZE mask is being cleared correctly
    attrs.characterSize = .bits5
    XCTAssertEqual(attrs.characterSize, .bits5)
  }

  func testParity() {
    var attrs = TerminalAttributes()

    attrs.parity = .none
    XCTAssertEqual(attrs.parity, .none)

    attrs.parity = .even
    XCTAssertEqual(attrs.parity, .even)

    attrs.parity = .odd
    XCTAssertEqual(attrs.parity, .odd)
  }

  func testStopBits() {
    var attrs = TerminalAttributes()

    attrs.stopBits = .one
    XCTAssertEqual(attrs.stopBits, .one)

    attrs.stopBits = .two
    XCTAssertEqual(attrs.stopBits, .two)
  }

  // MARK: - Raw Mode Tests

  func testMakeRaw() {
    var attrs = TerminalAttributes()

    // Set some flags that makeRaw should clear
    attrs.localFlags.insert([.canonical, .echo, .signals])
    attrs.inputFlags.insert(.breakInterrupt)
    attrs.outputFlags.insert(.postProcess)

    attrs.makeRaw()

    // Verify raw mode flags are set correctly
    XCTAssertFalse(attrs.localFlags.contains(.canonical))
    XCTAssertFalse(attrs.localFlags.contains(.echo))
    XCTAssertFalse(attrs.localFlags.contains(.signals))
    XCTAssertFalse(attrs.inputFlags.contains(.breakInterrupt))
    XCTAssertFalse(attrs.outputFlags.contains(.postProcess))

    // Verify character size is 8 bits
    XCTAssertTrue(attrs.controlFlags.contains(.characterSize8))

    // Verify MIN and TIME are set for immediate single-character reads
    XCTAssertEqual(attrs.controlCharacters[.minimum], 1)
    XCTAssertEqual(attrs.controlCharacters[.time], 0)
  }

  func testRawMethod() {
    var attrs = TerminalAttributes()
    attrs.localFlags.insert(.canonical)

    let rawAttrs = attrs.raw()

    // Original should be unchanged
    XCTAssertTrue(attrs.localFlags.contains(.canonical))

    // New copy should be in raw mode
    XCTAssertFalse(rawAttrs.localFlags.contains(.canonical))
  }

  // MARK: - SetAction Tests

  func testSetActionConstants() {
    XCTAssertNotNil(TerminalAttributes.SetAction.now)
    XCTAssertNotNil(TerminalAttributes.SetAction.afterDrain)
    XCTAssertNotNil(TerminalAttributes.SetAction.afterFlush)

    #if canImport(Darwin)
    XCTAssertNotNil(TerminalAttributes.SetAction.soft)
    #endif
  }

  // MARK: - Queue and FlowAction Tests

  func testQueueConstants() {
    XCTAssertNotNil(TerminalDescriptor.Queue.input)
    XCTAssertNotNil(TerminalDescriptor.Queue.output)
    XCTAssertNotNil(TerminalDescriptor.Queue.both)
  }

  func testFlowActionConstants() {
    XCTAssertNotNil(TerminalDescriptor.FlowAction.suspendOutput)
    XCTAssertNotNil(TerminalDescriptor.FlowAction.resumeOutput)
    XCTAssertNotNil(TerminalDescriptor.FlowAction.sendStop)
    XCTAssertNotNil(TerminalDescriptor.FlowAction.sendStart)
  }

  // MARK: - WindowSize Tests

  func testWindowSizeInit() {
    let size = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
    XCTAssertEqual(size.rows, 24)
    XCTAssertEqual(size.columns, 80)
  }

  func testWindowSizeProperties() {
    var size = TerminalDescriptor.WindowSize(rows: 24, columns: 80)

    size.rows = 40
    size.columns = 120

    XCTAssertEqual(size.rows, 40)
    XCTAssertEqual(size.columns, 120)
  }

  func testWindowSizeEquatable() {
    let size1 = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
    let size2 = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
    let size3 = TerminalDescriptor.WindowSize(rows: 40, columns: 120)

    XCTAssertEqual(size1, size2)
    XCTAssertNotEqual(size1, size3)
  }

  func testWindowSizeHashable() {
    let size1 = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
    let size2 = TerminalDescriptor.WindowSize(rows: 24, columns: 80)

    XCTAssertEqual(size1.hashValue, size2.hashValue)

    var set = Set<TerminalDescriptor.WindowSize>()
    set.insert(size1)
    XCTAssertTrue(set.contains(size2))
  }

  // MARK: - Pseudoterminal Tests
  //
  // These run on a new pseudoterminal rather than on standard input or
  // output, which aren't terminals under `swift test`.

  func testTerminalAttributesRoundtrip() throws {
    try withPseudoterminal { _, fd in
      let terminal = try TerminalDescriptor(fd)
      let original = try terminal.attributes()
      XCTAssertEqual(try terminal.attributes(), original)

      // The attributes are the ones tcgetattr reads.
      var expected = termios()
      XCTAssertEqual(tcgetattr(fd.rawValue, &expected), 0)
      XCTAssertEqual(original.inputFlags.rawValue, expected.c_iflag)
      XCTAssertEqual(original.outputFlags.rawValue, expected.c_oflag)
      XCTAssertEqual(original.controlFlags.rawValue, expected.c_cflag)
      XCTAssertEqual(original.localFlags.rawValue, expected.c_lflag)
      for index in 0..<ControlCharacters.count {
        let byte = withUnsafeBytes(of: expected.c_cc) { $0[index] }
        XCTAssertEqual(original.controlCharacters[rawIndex: index], byte)
      }

      // A new pseudoterminal reads a line at a time, and echoes it.
      XCTAssertTrue(original.localFlags.isSuperset(of: [.canonical, .echo]))
    }
  }

  func testTerminalSetAttributes() throws {
    try withPseudoterminal { _, fd in
      let terminal = try TerminalDescriptor(fd)
      let original = try terminal.attributes()

      var modified = original
      modified.localFlags.insert(.echoNL)
      modified.localFlags.remove(.echo)
      modified.controlCharacters[.erase] = 0x08
      modified.setSpeed(.b38400)
      XCTAssertNotEqual(modified, original)

      // With no input or output pending, each action applies the change.
      for action: TerminalAttributes.SetAction in [.now, .afterDrain, .afterFlush] {
        try terminal.setAttributes(original, when: .now)
        try terminal.setAttributes(modified, when: action)
        let readBack = try terminal.attributes()
        XCTAssertTrue(readBack.localFlags.contains(.echoNL))
        XCTAssertFalse(readBack.localFlags.contains(.echo))
        XCTAssertEqual(readBack.controlCharacters[.erase], 0x08)
        XCTAssertEqual(readBack.inputSpeed, .b38400)
        XCTAssertEqual(readBack.outputSpeed, .b38400)
      }
    }
  }

  func testWithAttributes() throws {
    try withPseudoterminal { _, fd in
      let terminal = try TerminalDescriptor(fd)
      let original = try terminal.attributes()

      // Modify attributes within scope
      let result = try terminal.withAttributes({ attrs in
        attrs.localFlags.insert(.echoNL)
      }) {
        // Inside the block, attributes should be modified
        let current = try terminal.attributes()
        XCTAssertTrue(current.localFlags.contains(.echoNL))
        return 42
      }
      XCTAssertEqual(result, 42)

      // After the block, attributes should be restored
      XCTAssertEqual(try terminal.attributes(), original)

      // Also when the block throws.
      struct BodyError: Error {}
      XCTAssertThrowsError(
        try terminal.withAttributes({ $0.localFlags.insert(.echoNL) }) {
          XCTAssertTrue(try terminal.attributes().localFlags.contains(.echoNL))
          throw BodyError()
        }
      ) {
        XCTAssertTrue($0 is BodyError)
      }
      XCTAssertEqual(try terminal.attributes(), original)
    }
  }

  func testWithRawMode() throws {
    try withPseudoterminal { controller, fd in
      let terminal = try TerminalDescriptor(fd)
      let original = try terminal.attributes()

      try terminal.withRawMode {
        // Inside raw mode
        let current = try terminal.attributes()
        XCTAssertFalse(current.localFlags.contains(.canonical))
        XCTAssertFalse(current.localFlags.contains(.echo))

        // Input can be read a byte at a time, without waiting for a newline.
        try controller.writeAll("x".utf8)
        XCTAssertEqual(try readBytes(from: fd, count: 1), Array("x".utf8))
      }

      // After exiting raw mode. Leaving non-canonical mode can make the driver
      // set PENDIN, which Darwin does, so ignore the state flags it manages.
      let restored = try terminal.attributes()
      let stateFlags: LocalFlags = [.retypePending, .flushingOutput]
      XCTAssertEqual(
        original.localFlags.subtracting(stateFlags),
        restored.localFlags.subtracting(stateFlags))
      XCTAssertEqual(original.inputFlags, restored.inputFlags)
      XCTAssertEqual(original.outputFlags, restored.outputFlags)
      XCTAssertEqual(original.controlFlags, restored.controlFlags)
      XCTAssertEqual(original.controlCharacters, restored.controlCharacters)

      // In canonical mode, a partial line can't be read yet, and with echo
      // restored, the controller reads the input back. Reading it also
      // leaves no output pending, which closing the terminal would wait for.
      try controller.writeAll("y".utf8)
      XCTAssertFalse(try isReadable(fd, timeout: 100))
      XCTAssertEqual(try readBytes(from: controller, count: 1), Array("y".utf8))
    }
  }

  func testWindowSizeOperation() throws {
    try withPseudoterminal { controller, fd in
      let terminal = try TerminalDescriptor(fd)
      let size = TerminalDescriptor.WindowSize(rows: 24, columns: 80)
      try terminal.setWindowSize(size)
      XCTAssertEqual(try terminal.windowSize(), size)

      // Both ends share the size.
      let controllerTerminal = try TerminalDescriptor(controller)
      XCTAssertEqual(try controllerTerminal.windowSize(), size)
      let larger = TerminalDescriptor.WindowSize(rows: 50, columns: 132)
      try controllerTerminal.setWindowSize(larger)
      XCTAssertEqual(try terminal.windowSize(), larger)
    }
  }

  func testTerminalOperations() throws {
    try withPseudoterminal { _, fd in
      let terminal = try TerminalDescriptor(fd)
      // With no output pending, draining returns at once.
      try terminal.drain()
      try terminal.flush(.input)
      try terminal.flush(.output)
      try terminal.flush(.both)
      try terminal.flow(.suspendOutput)
      try terminal.flow(.resumeOutput)
      try terminal.flow(.sendStop)
      try terminal.flow(.sendStart)
      try terminal.sendBreak()
    }
  }

  func testFlushDiscardsPendingData() throws {
    try withPseudoterminal { controller, fd in
      let terminal = try TerminalDescriptor(fd)
      try terminal.setAttributes(Self.withoutEcho(terminal.attributes()), when: .now)

      // Input that the terminal hasn't read. Waiting until the line is
      // readable makes sure it has reached the terminal.
      try controller.writeAll("discarded\n".utf8)
      XCTAssertTrue(try isReadable(fd, timeout: 5_000))
      try terminal.flush(.input)
      try controller.writeAll("kept\n".utf8)
      XCTAssertEqual(try readBytes(from: fd, count: 5), Array("kept\n".utf8))

      #if SYSTEM_PACKAGE_DARWIN
      // Output that the controller hasn't read. On Linux, a pseudoterminal
      // moves output to the controller as it's written, which leaves nothing
      // for the flush to discard once the move is done.
      try fd.writeAll("discarded".utf8)
      try terminal.flush(.output)
      try fd.writeAll("kept".utf8)
      XCTAssertEqual(try readBytes(from: controller, count: 4), Array("kept".utf8))
      #endif
    }
  }

  func testSetAttributesAfterFlushDiscardsPendingInput() throws {
    try withPseudoterminal { controller, fd in
      let terminal = try TerminalDescriptor(fd)
      let attributes = Self.withoutEcho(try terminal.attributes())
      try terminal.setAttributes(attributes, when: .now)

      try controller.writeAll("discarded\n".utf8)
      XCTAssertTrue(try isReadable(fd, timeout: 5_000))
      try terminal.setAttributes(attributes, when: .afterFlush)
      try controller.writeAll("kept\n".utf8)
      XCTAssertEqual(try readBytes(from: fd, count: 5), Array("kept\n".utf8))
    }
  }

  func testOperationsOnANonTerminal() throws {
    let fds = try FileDescriptor.pipe()
    defer {
      try? fds.readEnd.close()
      try? fds.writeEnd.close()
    }
    let pipe = TerminalDescriptor(unchecked: fds.readEnd)
    Self.checkEachOperation(on: pipe, throws: .inappropriateIOCTLForDevice)
  }

  func testOperationsOnAnInvalidDescriptor() {
    let invalid = TerminalDescriptor(rawValue: -1)
    Self.checkEachOperation(on: invalid, throws: .badFileDescriptor)
  }

  func testInvalidActions() throws {
    try withPseudoterminal { _, fd in
      let terminal = try TerminalDescriptor(fd)
      let attributes = try terminal.attributes()
      XCTAssertThrowsError(
        try terminal.setAttributes(attributes, when: .init(rawValue: 99))
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try terminal.flush(.init(rawValue: 99))) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try terminal.flow(.init(rawValue: 99))) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(try terminal.attributes(), attributes)
    }
  }

  /// Returns `attributes` without echo, so that input the controller writes
  /// leaves no output pending.
  private static func withoutEcho(_ attributes: TerminalAttributes) -> TerminalAttributes {
    var attributes = attributes
    attributes.localFlags.subtract([.echo, .echoNL])
    return attributes
  }

  /// Checks that each operation on `terminal` throws `expected`.
  private static func checkEachOperation(
    on terminal: TerminalDescriptor, throws expected: Errno,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let operations: [(String, () throws -> Void)] = [
      ("attributes", { _ = try terminal.attributes() }),
      ("setAttributes", { try terminal.setAttributes(TerminalAttributes(), when: .now) }),
      ("drain", { try terminal.drain() }),
      ("flush", { try terminal.flush(.both) }),
      ("flow", { try terminal.flow(.resumeOutput) }),
      ("sendBreak", { try terminal.sendBreak() }),
      ("windowSize", { _ = try terminal.windowSize() }),
      ("setWindowSize", { try terminal.setWindowSize(.init(rows: 24, columns: 80)) }),
    ]
    for (name, operation) in operations {
      XCTAssertThrowsError(try operation(), name, file: file, line: line) {
        XCTAssertEqual($0 as? Errno, expected, name, file: file, line: line)
      }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
