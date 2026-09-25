/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// STAND-IN, simulated configuration only. The bridges between
// FileDescriptor and Win32.FileHandle that SYS-0011 drafts. On Windows, a
// FileDescriptor is a C runtime descriptor over a handle; in the simulation,
// both are the same POSIX descriptor.

import SystemPackage

extension FileDescriptor {
  /// Calls `body` with the Win32 handle backing this descriptor, if it maps
  /// to a usable handle.
  ///
  /// The handle is borrowed from the C runtime descriptor, which owns it and
  /// closes it when the descriptor is closed. `body` isn't called for an
  /// invalid descriptor, for one with no underlying handle, or for one over
  /// an overlapped handle, such as a socket.
  ///
  /// - Returns: The return value of `body`, or `nil` if it wasn't called.
  ///
  /// The corresponding C function is `_get_osfhandle`.
  func withWin32HandleIfAvailable<R: ~Copyable, E: Error>(
    _ body: (borrowing Win32.FileHandle) throws(E) -> R
  ) throws(E) -> R? {
    // Sockets are overlapped handles on Windows.
    guard let status = try? stat(), status.type != .socket else { return nil }
    // A FileHandle that the C runtime owns: relinquished on every path, so
    // its deinit never closes the descriptor.
    let lent = Win32.FileHandle(_simulated: rawValue)
    let result: R
    do {
      result = try body(lent)
    } catch {
      _ = lent._lend()
      throw error
    }
    _ = lent._lend()
    return result
  }

  /// Wraps a Win32 handle in a C runtime file descriptor, consuming the
  /// handle. On failure, this initializer closes the handle before throwing.
  ///
  /// The corresponding C function is `_open_osfhandle`.
  init(
    adopting handle: consuming Win32.FileHandle,
    translation: TranslationMode = .binary,
    append: Bool = false
  ) throws(Errno) {
    // `_open_osfhandle` rejects a handle whose type is FILE_TYPE_UNKNOWN.
    guard (try? handle.fileType()) != .unknown else {
      _ = try? handle.close()
      throw .invalidArgument
    }
    let descriptor = FileDescriptor(
      rawValue: Win32Simulation.descriptor(of: handle.relinquish())!)
    if append {
      let flags = try descriptor.statusFlags()
      try descriptor.setStatusFlags(flags.union(.append))
    }
    // The simulation has no text translation; every descriptor is binary.
    self = descriptor
  }

  /// The C runtime's translation mode for a file descriptor.
  struct TranslationMode: RawRepresentable, Sendable, Hashable, Codable {
    var rawValue: CInt
    init(rawValue: CInt) { self.rawValue = rawValue }

    static var binary: TranslationMode { TranslationMode(rawValue: 0x8000) }    // _O_BINARY
    static var text: TranslationMode { TranslationMode(rawValue: 0x4000) }      // _O_TEXT
    static var wideText: TranslationMode { TranslationMode(rawValue: 0x10000) } // _O_WTEXT
  }
}

#endif // SIMULATE_PLATFORMS
