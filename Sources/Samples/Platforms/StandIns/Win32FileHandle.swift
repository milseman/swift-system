/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// STAND-IN, simulated configuration only. `Win32.FileHandle` and
// `Win32.DirectoryHandle` as drafted in SYS-0011, with the operations that
// SYS-0012 (file type), SYS-0013 (I/O), SYS-0014 (locking), SYS-0015
// (volume information), and SYS-0016 (final path) add. The signatures are
// the drafts'; the bodies call Win32Simulation, which runs them over POSIX.
// Left out: the MutableRawSpan and typed-span overloads of the reads, and
// `write(draining:)`/`append(draining:)`. No sample needs them.

import SystemPackage

extension Win32 {
  /// An open file, device, or pipe.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope and
  /// discards the error.
  ///
  /// The corresponding C type is `HANDLE`.
  @safe
  struct FileHandle: ~Copyable, Sendable {
    // Simulation: the descriptor that the HANDLE names.
    let _descriptor: CInt

    init(_simulated descriptor: CInt) { _descriptor = descriptor }

    /// Adopts a raw handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL` or `INVALID_HANDLE_VALUE`.
    @unsafe
    init?(unsafelyAdopting raw: HANDLE?) {
      guard let descriptor = Win32Simulation.descriptor(of: raw) else { return nil }
      _descriptor = descriptor
    }

    /// The raw C handle. Valid only while this value is alive.
    @unsafe
    var unsafeRawHandle: HANDLE { Win32Simulation.handle(for: _descriptor) }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @unsafe
    consuming func relinquish() -> HANDLE {
      let descriptor = _descriptor
      discard self
      Win32Simulation.unregister(descriptor)
      return Win32Simulation.handle(for: descriptor)
    }

    /// Closes this handle.
    ///
    /// The corresponding C function is `CloseHandle`.
    consuming func close() throws(Win32.Error) {
      let descriptor = _descriptor
      discard self
      try Win32Simulation.closeHandle(descriptor)
    }

    deinit {
      try? Win32Simulation.closeHandle(_descriptor)
    }

    /// Simulation: ends a lent handle's lifetime without closing it or
    /// forgetting its share mode, which belong to the descriptor it was lent
    /// from (`FileDescriptor.withWin32HandleIfAvailable`).
    consuming func _lend() -> CInt {
      let descriptor = _descriptor
      discard self
      return descriptor
    }
  }

  /// An open directory.
  ///
  /// Opening one applies `FILE_FLAG_BACKUP_SEMANTICS`. This type has no read
  /// or write surface, because `ReadFile` and `WriteFile` fail on a
  /// directory handle.
  ///
  /// The corresponding C type is `HANDLE`.
  @safe
  struct DirectoryHandle: ~Copyable, Sendable {
    let _descriptor: CInt

    @unsafe
    init?(unsafelyAdopting raw: HANDLE?) {
      guard let descriptor = Win32Simulation.descriptor(of: raw) else { return nil }
      _descriptor = descriptor
    }

    init(_simulated descriptor: CInt) { _descriptor = descriptor }

    @unsafe
    var unsafeRawHandle: HANDLE { Win32Simulation.handle(for: _descriptor) }

    @unsafe
    consuming func relinquish() -> HANDLE {
      let descriptor = _descriptor
      discard self
      Win32Simulation.unregister(descriptor)
      return Win32Simulation.handle(for: descriptor)
    }

    consuming func close() throws(Win32.Error) {
      let descriptor = _descriptor
      discard self
      try Win32Simulation.closeHandle(descriptor)
    }

    deinit {
      try? Win32Simulation.closeHandle(_descriptor)
    }
  }
}

// MARK: - Opening (SYS-0011)

extension Win32.FileHandle {
  /// Opens or creates a file, device, or pipe.
  ///
  /// `shareMode` defaults to read, write, and delete, matching POSIX `open`.
  /// `inheritable` defaults to `false`, unlike `FileDescriptor.open`.
  /// Throws ``Win32/Error/invalidParameter`` if `flags` contains
  /// `FILE_FLAG_OVERLAPPED`.
  ///
  /// The corresponding C function is `CreateFileW`.
  static func open(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    disposition: Win32.CreationDisposition = .openExisting,
    attributes: Win32.FileAttributes = [],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil,
    templateFile: borrowing Win32.FileHandle? = nil
  ) throws(Win32.Error) -> Win32.FileHandle {
    let opened = try Win32Simulation.open(
      path, access: access, shareMode: shareMode, disposition: disposition, flags: flags,
      inheritable: inheritable, directory: false)
    return Win32.FileHandle(_simulated: opened.descriptor)
  }

  /// The result of `openOrCreate`.
  struct OpenOrCreateResult: ~Copyable, Sendable {
    /// The open handle.
    let handle: Win32.FileHandle

    /// Whether the file already existed.
    let existed: Bool
  }

  /// Opens a file, creating it if it does not exist, and reports whether it
  /// already existed.
  ///
  /// The corresponding C function is `CreateFileW`, with `OPEN_ALWAYS`, or
  /// `CREATE_ALWAYS` if `overwriteExisting` is `true`.
  static func openOrCreate(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    overwriteExisting: Bool = false,
    attributes: Win32.FileAttributes = [],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil,
    templateFile: borrowing Win32.FileHandle? = nil
  ) throws(Win32.Error) -> OpenOrCreateResult {
    let opened = try Win32Simulation.open(
      path, access: access, shareMode: shareMode,
      disposition: overwriteExisting ? .createAlways : .openAlways, flags: flags,
      inheritable: inheritable, directory: false)
    return OpenOrCreateResult(
      handle: Win32.FileHandle(_simulated: opened.descriptor), existed: opened.existed)
  }
}

extension Win32.DirectoryHandle {
  /// Opens a directory.
  ///
  /// `FILE_FLAG_BACKUP_SEMANTICS` is added to `flags` automatically. Throws
  /// ``Win32/Error/notADirectory`` if `path` is not a directory.
  ///
  /// The corresponding C function is `CreateFileW`.
  static func open(
    _ path: FilePath,
    access: Win32.AccessMask = .listDirectory,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.DirectoryHandle {
    let opened = try Win32Simulation.open(
      path, access: access, shareMode: shareMode, disposition: .openExisting,
      flags: flags.union(.backupSemantics), inheritable: inheritable, directory: true)
    return Win32.DirectoryHandle(_simulated: opened.descriptor)
  }
}

// MARK: - Duplication, reopening, and inheritance (SYS-0011)

extension Win32.FileHandle {
  /// Duplicates this handle within the current process. The duplicate shares
  /// this handle's file pointer.
  ///
  /// The corresponding C function is `DuplicateHandle`.
  borrowing func duplicate(
    access: Win32.AccessMask? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.FileHandle {
    Win32.FileHandle(
      _simulated: try Win32Simulation.duplicate(_descriptor, inheritable: inheritable))
  }

  /// Re-opens this handle's file as a new file object, with its own file
  /// pointer, access rights, share mode, and flags.
  ///
  /// The corresponding C function is `ReOpenFile`.
  borrowing func reopen(
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    flags: Win32.FileFlags = []
  ) throws(Win32.Error) -> Win32.FileHandle {
    let path = try Win32Simulation.finalPath(_descriptor)
    let opened = try Win32Simulation.open(
      path, access: access, shareMode: shareMode, disposition: .openExisting, flags: flags,
      inheritable: false, directory: false)
    return Win32.FileHandle(_simulated: opened.descriptor)
  }

  /// Whether child processes created with handle inheritance enabled receive
  /// a copy of this handle.
  ///
  /// The corresponding C functions are `GetHandleInformation` and
  /// `SetHandleInformation` with `HANDLE_FLAG_INHERIT`.
  borrowing func isInheritable() throws(Win32.Error) -> Bool {
    try Win32Simulation.isInheritable(_descriptor)
  }

  borrowing func setInheritable(_ value: Bool) throws(Win32.Error) {
    try Win32Simulation.setInheritable(_descriptor, value)
  }
}

extension Win32.DirectoryHandle {
  borrowing func duplicate(
    access: Win32.AccessMask? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.DirectoryHandle {
    Win32.DirectoryHandle(
      _simulated: try Win32Simulation.duplicate(_descriptor, inheritable: inheritable))
  }

  borrowing func isInheritable() throws(Win32.Error) -> Bool {
    try Win32Simulation.isInheritable(_descriptor)
  }

  borrowing func setInheritable(_ value: Bool) throws(Win32.Error) {
    try Win32Simulation.setInheritable(_descriptor, value)
  }
}

// MARK: - File type (SYS-0012)

extension Win32.FileHandle {
  /// The type of device this handle refers to.
  ///
  /// The corresponding C function is `GetFileType`.
  func fileType() throws(Win32.Error) -> Win32.FileType {
    try Win32Simulation.fileType(_descriptor)
  }
}

// MARK: - I/O (SYS-0013)

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Win32.FileHandle {
  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, into `span`'s free capacity.
  ///
  /// Calls `ReadFile` once.
  ///
  /// - Important: Reading from a non-`nil` `offset` also updates the file
  ///   pointer, unlike POSIX `pread`.
  ///
  /// - Returns: The number of bytes read. Zero indicates end of file, or no
  ///   free capacity.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED` offset
  /// when `offset` is non-`nil`.
  @discardableResult
  func read(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    try Win32Simulation.read(_descriptor, fromAbsoluteOffset: offset, into: &span)
  }

  /// Reads bytes until `span` has no free capacity or the file ends.
  ///
  /// A short read ends the transfer only for a disk file. On a pipe or
  /// console, this blocks until the span fills.
  ///
  /// The corresponding C function is `ReadFile`, called in a loop.
  @discardableResult
  func readFully(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    try Win32Simulation.readFully(_descriptor, fromAbsoluteOffset: offset, into: &span)
  }

  /// Writes the contents of `span` to the specified `offset`, or the current
  /// file pointer when `offset` is `nil`. Loops until the span is exhausted.
  ///
  /// - Important: Writing to a non-`nil` `offset` also updates the file
  ///   pointer, unlike POSIX `pwrite`.
  ///
  /// The corresponding C function is `WriteFile`, called in a loop.
  func write(
    _ span: RawSpan,
    toAbsoluteOffset offset: Int64? = nil
  ) throws(Win32.Error) {
    try Win32Simulation.write(_descriptor, span, toAbsoluteOffset: offset)
  }

  /// Writes the contents of `span` to the end of the file, in one
  /// `WriteFile`, or throws.
  ///
  /// The corresponding C function is `WriteFile` with an `OVERLAPPED`
  /// offset of `-1`.
  func append(_ span: RawSpan) throws(Win32.Error) {
    try Win32Simulation.append(_descriptor, span)
  }
}

extension Win32.FileHandle {
  /// Returns the current position of the file pointer.
  ///
  /// The corresponding C function is `SetFilePointerEx` with zero offset
  /// from `FILE_CURRENT`.
  func currentOffset() throws(Win32.Error) -> Int64 {
    try Win32Simulation.currentOffset(_descriptor)
  }

  /// Moves the file pointer to an absolute position.
  ///
  /// The corresponding C function is `SetFilePointerEx`.
  func seek(to offset: Int64) throws(Win32.Error) {
    guard offset >= 0 else { throw .negativeSeek }
    _ = try Win32Simulation.seek(_descriptor, offset: offset, from: .start)
  }

  /// Moves the file pointer and returns its new absolute position.
  ///
  /// - Warning: This function is not valid on a nonseeking device such as a
  ///   pipe or console. The call may succeed anyway, returning a position
  ///   that no transfer ever advances.
  ///
  /// The corresponding C function is `SetFilePointerEx`.
  @discardableResult
  func seek(
    offset: Int64,
    from origin: Win32.SeekOrigin
  ) throws(Win32.Error) -> Int64 {
    try Win32Simulation.seek(_descriptor, offset: offset, from: origin)
  }

  /// Flushes this handle's buffered data to the device, and tells the device
  /// to commit its own volatile cache.
  ///
  /// - Important: On a pipe, this blocks until the reader has read everything
  ///   written so far.
  ///
  /// The corresponding C function is `FlushFileBuffers`.
  func flush() throws(Win32.Error) {
    try Win32Simulation.flush(_descriptor)
  }

  /// The size of the file, in bytes.
  ///
  /// The corresponding C function is `GetFileSizeEx`.
  func size() throws(Win32.Error) -> Int64 {
    try Win32Simulation.size(_descriptor)
  }

  /// Truncates or extends the file to `newSize`, leaving the file pointer
  /// where it is.
  ///
  /// The corresponding C function is `SetFileInformationByHandle` with
  /// `FileEndOfFileInfo`.
  func resize(to newSize: Int64) throws(Win32.Error) {
    try Win32Simulation.resize(_descriptor, to: newSize)
  }

  /// Sets the end of the file to the current file pointer.
  ///
  /// The corresponding C function is `SetEndOfFile`.
  func resizeToCurrentOffset() throws(Win32.Error) {
    try Win32Simulation.resize(_descriptor, to: currentOffset())
  }
}

// MARK: - Byte-range locking (SYS-0014)

extension Win32.FileHandle {
  /// Locks a byte range of the file, runs `body`, and unlocks the range.
  ///
  /// Blocks while any handle holds a conflicting lock on an overlapping
  /// range. `byteRange` defaults to `0...`, the whole file. The range is
  /// unlocked when `body` returns or throws.
  ///
  /// - Important: Windows byte-range locks are mandatory, not advisory.
  ///
  /// The corresponding C functions are `LockFileEx` and `UnlockFileEx`.
  @available(*, noasync)
  func withLock<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws(Win32.Error) -> R
  ) throws(Win32.Error) -> R {
    let range = try Win32Simulation.lockRange(byteRange)
    let result = try Win32Simulation.withLock(
      _descriptor, range: range, mode: mode, wait: true, body)
    // With `wait`, the simulation returns a result or traps.
    return try result!.get()
  }

  @available(*, noasync)
  @_disfavoredOverload
  func withLock<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws -> R
  ) throws -> R {
    let range = try Win32Simulation.lockRange(byteRange)
    let result = try Win32Simulation.withLock(
      _descriptor, range: range, mode: mode, wait: true, body)
    return try result!.get()
  }

  /// Locks a byte range of the file if it's available, runs `body`, and
  /// unlocks the range.
  ///
  /// - Returns: The value `body` returned, or `nil` if a conflicting lock
  ///   holds an overlapping range.
  ///
  /// The corresponding C functions are `LockFileEx` with
  /// `LOCKFILE_FAIL_IMMEDIATELY`, and `UnlockFileEx`.
  func withLockIfAvailable<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws(Win32.Error) -> R
  ) throws(Win32.Error) -> R? {
    let range = try Win32Simulation.lockRange(byteRange)
    guard let result = try Win32Simulation.withLock(
      _descriptor, range: range, mode: mode, wait: false, body)
    else { return nil }
    return try result.get()
  }

  @_disfavoredOverload
  func withLockIfAvailable<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws -> R
  ) throws -> R? {
    let range = try Win32Simulation.lockRange(byteRange)
    guard let result = try Win32Simulation.withLock(
      _descriptor, range: range, mode: mode, wait: false, body)
    else { return nil }
    return try result.get()
  }
}

// MARK: - Volume information (SYS-0015) and final path (SYS-0016)

extension Win32.FileHandle {
  /// Returns information about the volume this file resides on.
  ///
  /// The corresponding C function is `GetVolumeInformationByHandleW`.
  func volumeInformation() throws(Win32.Error) -> Win32.VolumeInformation {
    try Win32Simulation.volumeInformation(_descriptor)
  }

  /// Returns the fully resolved path of the file this handle refers to.
  ///
  /// The corresponding C function is `GetFinalPathNameByHandleW`.
  func finalPath(
    volumeName: Win32.VolumeNameFormat = .dos,
    normalized: Bool = true
  ) throws(Win32.Error) -> FilePath {
    try Win32Simulation.finalPath(_descriptor)
  }
}

extension Win32.DirectoryHandle {
  func volumeInformation() throws(Win32.Error) -> Win32.VolumeInformation {
    try Win32Simulation.volumeInformation(_descriptor)
  }

  func finalPath(
    volumeName: Win32.VolumeNameFormat = .dos,
    normalized: Bool = true
  ) throws(Win32.Error) -> FilePath {
    try Win32Simulation.finalPath(_descriptor)
  }
}

#endif // SIMULATE_PLATFORMS
