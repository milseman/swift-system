/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// VARIANT, simulated configuration only: a copyable Windows handle. The
// drafts reject this ("A copyable RawFileHandle beneath FileHandle", in
// SYS-0011's alternatives). It's here so the samples can compare the two
// Windows models. `Win32.RawFileHandle` mirrors FileDescriptor: a copyable
// name with a non-consuming `close()`, which hosts operations. The owned
// `Win32.FileHandle` then vends it, as OwnedFD vends a FileDescriptor.
//
// Only what the `platform variants` sample uses is here. The rest of the
// surface would duplicate FileHandle's, as SYS-0011 warns.

import SystemPackage

extension Win32 {
  /// A copyable Win32 file handle, which doesn't own the handle it names.
  ///
  /// After the handle is closed, Windows can reuse its value for any new
  /// object, including an overlapped handle, on which synchronous I/O isn't
  /// memory-safe. So a real one's operations would be `@unsafe`.
  struct RawFileHandle: RawRepresentable, Hashable {
    let rawValue: HANDLE
    init(rawValue: HANDLE) { self.rawValue = rawValue }

    var _descriptor: CInt { Win32Simulation.descriptor(of: rawValue)! }

    /// Opens a file, returning a name that the caller must close.
    ///
    /// The corresponding C function is `CreateFileW`.
    static func open(
      _ path: FilePath,
      access: Win32.AccessMask,
      shareMode: Win32.ShareMode = [.read, .write, .delete],
      disposition: Win32.CreationDisposition = .openExisting,
      inheritable: Bool = false
    ) throws(Win32.Error) -> RawFileHandle {
      let opened = try Win32Simulation.open(
        path, access: access, shareMode: shareMode, disposition: disposition, flags: [],
        inheritable: inheritable, directory: false)
      return RawFileHandle(rawValue: Win32Simulation.handle(for: opened.descriptor))
    }

    /// Closes the handle. Any other copy of this value is now stale.
    ///
    /// The corresponding C function is `CloseHandle`.
    func close() throws(Win32.Error) {
      try Win32Simulation.closeHandle(_descriptor)
    }

    func setInheritable(_ value: Bool) throws(Win32.Error) {
      try Win32Simulation.setInheritable(_descriptor, value)
    }

    @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
    func write(_ span: RawSpan, toAbsoluteOffset offset: Int64? = nil) throws(Win32.Error) {
      try Win32Simulation.write(_descriptor, span, toAbsoluteOffset: offset)
    }

    func flush() throws(Win32.Error) {
      try Win32Simulation.flush(_descriptor)
    }
  }
}

extension Win32.FileHandle {
  /// Takes ownership of a copyable handle.
  init(taking raw: Win32.RawFileHandle) {
    self.init(_simulated: raw._descriptor)
  }

  /// The copyable handle, for operations the owner doesn't provide. Valid
  /// only while this owner is alive, like `OwnedFD.fileDescriptor`.
  var rawHandle: Win32.RawFileHandle {
    Win32.RawFileHandle(rawValue: Win32Simulation.handle(for: _descriptor))
  }
}

#endif // SIMULATE_PLATFORMS
