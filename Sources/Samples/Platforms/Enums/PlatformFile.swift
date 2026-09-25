/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the multi-platform file enum. Not API. See Platform.swift.

import SystemPackage

extension Platform {
  /// An open file, closed exactly once.
  ///
  /// Each case wraps the platform's owner. Lend it with a `borrowing`
  /// parameter; there's no borrowed form (V16g). An unowned form would need
  /// a copyable Windows handle, which the drafts reject (see
  /// `Platform.UnownedFile`, in Variants.swift).
  ///
  /// Windows has no `.fd` case. A C runtime descriptor there converts with
  /// SYS-0011's bridges instead, so that the enum's Windows code never goes
  /// through the C runtime.
  enum File: ~Copyable, Sendable {
    #if !os(Windows)
    /// A file descriptor, on Unix.
    case fd(OwnedFD)
    #endif

    #if os(Windows) || SIMULATE_PLATFORMS
    /// A file handle, on Windows.
    case handle(Win32.FileHandle)
    #endif
  }
}

// MARK: - Opening

extension Platform.File {
  /// The access a file is opened for.
  enum Access: Sendable {
    case read
    case write
    case readWrite
  }

  /// What opening does when the file exists, or doesn't.
  ///
  /// These are Windows' five creation dispositions, which POSIX spells as
  /// combinations of `O_CREAT`, `O_EXCL`, and `O_TRUNC`: the same concept,
  /// so they can share a name. Windows can also report whether
  /// `.openOrCreate` found the file; POSIX can't, so this can't.
  enum Disposition: Sendable {
    /// Fail if the file doesn't exist.
    case openExisting
    /// Fail if the file exists.
    case createNew
    /// Open the file, or create it if it doesn't exist.
    case openOrCreate
    /// Create the file, or empty it if it exists.
    case createOrTruncate
    /// Empty the file, and fail if it doesn't exist.
    case truncateExisting
  }

  /// Opens a file. Child processes don't inherit it.
  ///
  /// - Unix: `open`, with `O_CLOEXEC`. A new file's permissions are 0666,
  ///   less the umask.
  /// - Windows: `CreateFileW`, sharing reading, writing, and deletion with
  ///   other opens, not inheritable, and with the default security.
  ///
  /// The two differ: Unix opens a directory for reading, and Windows
  /// refuses it (use `Platform.Directory`). Windows shares with other opens
  /// only what `CreateFileW`'s share mode allows, so another program's
  /// exclusive open makes this fail, with a sharing violation.
  static func open(
    _ path: FilePath,
    _ access: Access,
    _ disposition: Disposition = .openExisting
  ) throws(Platform.Error) -> Platform.File {
    #if SIMULATE_PLATFORMS
    if Simulation.platform == .windows {
      return .handle(try openHandle(path, access, disposition))
    }
    #endif
    #if os(Windows)
    return .handle(try openHandle(path, access, disposition))
    #else
    let mode: FileDescriptor.AccessMode
    switch access {
    case .read: mode = .readOnly
    case .write: mode = .writeOnly
    case .readWrite: mode = .readWrite
    }
    var options: FileDescriptor.OpenOptions = [.closeOnExec]
    switch disposition {
    case .openExisting: break
    case .createNew: options.formUnion([.create, .exclusiveCreate])
    case .openOrCreate: options.insert(.create)
    case .createOrTruncate: options.formUnion([.create, .truncate])
    case .truncateExisting: options.insert(.truncate)
    }
    return .fd(try OwnedFD.open(
      path, mode, options: options, permissions: FilePermissions(rawValue: 0o666)))
    #endif
  }

  #if os(Windows) || SIMULATE_PLATFORMS
  private static func openHandle(
    _ path: FilePath, _ access: Access, _ disposition: Disposition
  ) throws(Win32.Error) -> Win32.FileHandle {
    let mask: Win32.AccessMask
    switch access {
    case .read: mask = .genericRead
    case .write: mask = .genericWrite
    case .readWrite: mask = [.genericRead, .genericWrite]
    }
    let creation: Win32.CreationDisposition
    switch disposition {
    case .openExisting: creation = .openExisting
    case .createNew: creation = .createNew
    case .openOrCreate: creation = .openAlways
    case .createOrTruncate: creation = .createAlways
    case .truncateExisting: creation = .truncateExisting
    }
    return try Win32.FileHandle.open(path, access: mask, disposition: creation)
  }
  #endif
}

// MARK: - Standard streams

extension Platform.File {
  /// Standard input, or `nil` if the process has none, as a Windows process
  /// without a console doesn't. On Unix it's never `nil`.
  ///
  /// A static let is never destroyed and can't be consumed, so this never
  /// closes standard input. Borrow it with a `switch`: `if let` and
  /// `if case` would consume it, which a static let forbids (V16c).
  ///
  /// It can't wrap `OwnedFD.standardInput`, which it can't consume either.
  /// It's a second owner of the same descriptor or handle, which is safe
  /// only because neither is ever destroyed.
  static let standardInput: Platform.File? = standardStream(0)

  /// Standard output, or `nil` if the process has none.
  static let standardOutput: Platform.File? = standardStream(1)

  /// Standard error, or `nil` if the process has none.
  static let standardError: Platform.File? = standardStream(2)

  private static func standardStream(_ number: CInt) -> Platform.File? {
    #if SIMULATE_PLATFORMS
    if Simulation.platform == .windows {
      return .handle(Win32.FileHandle(_simulated: number))
    }
    #endif
    #if os(Windows)
    // GetStdHandle's STD_INPUT_HANDLE is (DWORD)-10, then -11 and -12.
    switch Win32.FileHandle(unsafelyAdopting: GetStdHandle(DWORD(bitPattern: -10 - number))) {
    case .some(let handle): return .handle(handle)
    case .none: return nil
    }
    #else
    return .fd(OwnedFD(taking: FileDescriptor(rawValue: number)))
    #endif
  }
}

// MARK: - Reading and writing

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Platform.File {
  /// Reads what's available at the current position, up to the buffer's
  /// free capacity, in one call. Zero means the end of the file.
  ///
  /// On both, a pipe or terminal can return less than was asked for.
  /// - Unix: `read`.
  /// - Windows: `ReadFile`. A console read that Ctrl+C interrupts throws
  ///   `operationAborted`, where Unix would return what it read or retry.
  func read(into buffer: inout OutputRawSpan) throws(Platform.Error) -> Int {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return try owner.read(into: &buffer)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return try handle.read(into: &buffer)
    #endif
    }
  }

  /// Reads at an offset, up to the buffer's free capacity, in one call.
  ///
  /// - Important: The current position differs afterward. Unix's `pread`
  ///   leaves it alone. Windows' `ReadFile` with an offset moves it past the
  ///   bytes read. Code that mixes positional and current-position I/O
  ///   behaves differently on the two.
  func read(
    fromAbsoluteOffset offset: Int64, into buffer: inout OutputRawSpan
  ) throws(Platform.Error) -> Int {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return try owner.read(fromAbsoluteOffset: offset, into: &buffer)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return try handle.read(fromAbsoluteOffset: offset, into: &buffer)
    #endif
    }
  }

  /// Writes all of `data` at the current position.
  ///
  /// - Unix: `write`, in a loop, since `write` can write less.
  /// - Windows: `WriteFile`, which on a synchronous handle writes all of it
  ///   or fails, and a loop for the rare exceptions, as SYS-0013's does.
  /// Writing to a pipe whose reader closed throws `brokenPipe` on Unix,
  /// once the SIGPIPE it raises first is ignored, and `noData` on Windows.
  func write(_ data: RawSpan) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      _ = try owner.writeAll(data)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.write(data)
    #endif
    }
  }

  /// Writes all of `data` at an offset.
  ///
  /// - Important: As with reads, Windows moves the current position and
  ///   Unix's `pwrite` doesn't.
  func write(_ data: RawSpan, toAbsoluteOffset offset: Int64) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      _ = try owner.writeAll(toAbsoluteOffset: offset, data)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.write(data, toAbsoluteOffset: offset)
    #endif
    }
  }
}

// MARK: - Position, size, durability, and closing

extension Platform.File {
  /// Where a seek is measured from.
  enum SeekOrigin: Sendable {
    case start
    case current
    case end
  }

  /// Moves the current position, and returns it.
  ///
  /// On a pipe or terminal, Unix's `lseek` fails with `illegalSeek`, and
  /// Windows' `SetFilePointerEx` succeeds, reporting a position that no
  /// transfer uses.
  @discardableResult
  func seek(offset: Int64, from origin: SeekOrigin) throws(Platform.Error) -> Int64 {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      let whence: FileDescriptor.SeekOrigin
      switch origin {
      case .start: whence = .start
      case .current: whence = .current
      case .end: whence = .end
      }
      return try owner.seek(offset: offset, from: whence)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      let whence: Win32.SeekOrigin
      switch origin {
      case .start: whence = .start
      case .current: whence = .current
      case .end: whence = .end
      }
      return try handle.seek(offset: offset, from: whence)
    #endif
    }
  }

  /// The size of the file, in bytes.
  ///
  /// - Unix: `fstat`'s `st_size`. For a pipe, Darwin reports the bytes
  ///   waiting in it.
  /// - Windows: `GetFileSizeEx`, which fails on a console and reports an
  ///   unspecified value for a pipe.
  func size() throws(Platform.Error) -> Int64 {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return try owner.fileDescriptor.stat().size
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return try handle.size()
    #endif
    }
  }

  /// Truncates or extends the file, leaving the current position alone.
  ///
  /// - Unix: `ftruncate`.
  /// - Windows: `SetFileInformationByHandle` with `FileEndOfFileInfo`,
  ///   which fails while a view of the file is mapped.
  func resize(to newSize: Int64) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      // FileDescriptor's resize(to:) still throws untyped errors.
      try Platform.typed { try owner.fileDescriptor.resize(to: newSize) }
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.resize(to: newSize)
    #endif
    }
  }

  /// Writes the file's data to permanent storage, so that it survives a
  /// power failure.
  ///
  /// Each platform's call for that:
  /// - Darwin: `fcntl(F_FULLFSYNC)`, System's `synchronizeFully()`.
  ///   Darwin's `fsync` returns while the data is still in the drive's cache.
  /// - Linux: `fsync`.
  /// - Windows: `FlushFileBuffers`, which also asks the device to commit its
  ///   cache. On a pipe, it waits until the reader has read everything.
  func flush() throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      #if SYSTEM_PACKAGE_DARWIN
      try owner.fileDescriptor.synchronizeFully()
      #else
      try owner.fileDescriptor.synchronize()
      #endif
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.flush()
    #endif
    }
  }

  /// Closes the file, reporting any error.
  ///
  /// Unix's `close` can report a delayed write failure, such as on NFS.
  /// Windows' `CloseHandle` fails only for an invalid or protected handle;
  /// call `flush()` first to see write-back failures there.
  consuming func close() throws(Platform.Error) {
    switch consume self {
    #if !os(Windows)
    case .fd(let owner):
      try owner.close()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.close()
    #endif
    }
  }

  /// The case and its raw value, for display: `.fd(3)` or `.handle(0x10)`.
  var summary: String {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return ".fd(\(owner.fileDescriptor.rawValue))"
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return ".handle(0x\(String(UInt(bitPattern: handle.unsafeRawHandle), radix: 16)))"
    #endif
    }
  }
}
