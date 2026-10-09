/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// FileDescriptor.isTerminal on WASI, whose C library has isatty but none of
// the terminal calls that TerminalDescriptor.swift wraps.

#if os(WASI)

@available(System 199, *)
extension FileDescriptor {
  /// Returns whether this file descriptor refers to a terminal device.
  ///
  /// On WASI, a terminal is what the runtime reports as a character device
  /// that can't seek, as it does a terminal that the host gives the
  /// program for its standard streams.
  ///
  /// The corresponding C function is `isatty`.
  @_alwaysEmitIntoClient
  public var isTerminal: Bool {
    _isTerminal
  }

  @usableFromInline
  internal var _isTerminal: Bool {
    system_isatty(rawValue) != 0
  }
}

#endif // os(WASI)
