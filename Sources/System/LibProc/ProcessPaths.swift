/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A process's executable, name, and directories: proc_pidpath, proc_name,
// and proc_pidinfo's PROC_PIDVNODEPATHINFO.

// libproc is only in the macOS SDK.
#if os(macOS)

// Must import here to use the C types in @_alwaysEmitIntoClient APIs.
import Darwin

@available(System 199, *)
extension ProcessID {
  /// Returns the path of the process's executable.
  ///
  /// The path is the one the kernel resolved when the process started,
  /// and can name a file that has since moved or been removed.
  /// Any user can read the path of any process.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidpath`.
  /// - Note: Only available on macOS, Linux, Android, and FreeBSD.
  @_alwaysEmitIntoClient
  public func executablePath() throws(Errno) -> FilePath {
    try _executablePath().get()
  }

  @usableFromInline
  internal func _executablePath() -> Result<FilePath, Errno> {
    // The call fails with ENOMEM for a buffer smaller than the most it
    // could return.
    _nullTerminatedString(capacity: _PROC_PIDPATHINFO_MAXSIZE) { buffer, size in
      system_proc_pidpath(rawValue, buffer, UInt32(size))
    }.map { FilePath(platformString: $0) }
  }

  /// Returns the process's name.
  ///
  /// The name is the one the process registered,
  /// or else the first 16 bytes of its executable's name.
  /// Getting the name of a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_name`.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func name() throws(Errno) -> String {
    try _name().get()
  }

  @usableFromInline
  internal func _name() -> Result<String, Errno> {
    // Room for the longest name, 2 * MAXCOMLEN bytes, and a null.
    _nullTerminatedString(capacity: 2 * Int(MAXCOMLEN) + 1) { buffer, size in
      system_proc_name(rawValue, buffer, UInt32(size))
    }.map { String(platformString: $0) }
  }

  /// Returns the process's current working directory.
  ///
  /// Getting the directory of a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidinfo`,
  /// with the `PROC_PIDVNODEPATHINFO` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func currentDirectory() throws(Errno) -> FilePath {
    try _directories().get().current
  }

  /// Returns the process's root directory,
  /// which is `/` unless the process has changed it, as with `chroot`.
  ///
  /// Getting the directory of a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidinfo`,
  /// with the `PROC_PIDVNODEPATHINFO` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func rootDirectory() throws(Errno) -> FilePath {
    try _directories().get().root
  }

  @usableFromInline
  internal func _directories() -> Result<(current: FilePath, root: FilePath), Errno> {
    var info = proc_vnodepathinfo()
    let size = CInt(MemoryLayout<proc_vnodepathinfo>.size)
    // proc_pidinfo returns the number of bytes it fills, or 0 on failure.
    let filled = withUnsafeMutableBytes(of: &info) { buffer in
      system_proc_pidinfo(rawValue, _PROC_PIDVNODEPATHINFO, 0, buffer.baseAddress!, size)
    }
    if filled == 0 { return .failure(.current) }
    // A partial structure isn't the information, and shouldn't happen.
    guard filled == size else { return .failure(.ioError) }
    func path<T>(_ field: T) -> FilePath {
      withUnsafeBytes(of: field) { bytes in
        FilePath(
          platformString: bytes.prefix { $0 != 0 }.map { CInterop.PlatformChar(bitPattern: $0) }
            + [0])
      }
    }
    // The kernel reports no root directory for a process that hasn't
    // changed it.
    let root = path(info.pvi_rdir.vip_path)
    return .success((path(info.pvi_cdir.vip_path), root.isEmpty ? "/" : root))
  }
}

// Calls `body` with a buffer of `capacity` bytes, which returns the length
// of the null-terminated string it fills, or 0 with errno set on failure.
@available(System 199, *)
private func _nullTerminatedString(
  capacity: Int,
  _ body: (UnsafeMutableRawPointer, Int) -> CInt
) -> Result<[CInterop.PlatformChar], Errno> {
  var buffer = [CInterop.PlatformChar](repeating: 0, count: capacity + 1)
  let length = buffer.withUnsafeMutableBytes { body($0.baseAddress!, capacity) }
  guard length > 0 else { return .failure(.current) }
  // Keep the null terminator, which the String and FilePath
  // initializers need.
  buffer.removeLast(buffer.count - min(Int(length), capacity) - 1)
  buffer[buffer.count - 1] = 0
  return .success(buffer)
}

#endif // os(macOS)
