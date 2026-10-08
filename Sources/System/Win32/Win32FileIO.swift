/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Every transfer, seek, and resize here shares the handle's one file
// pointer, which belongs to the file object: a duplicate, an inherited copy,
// and a handle lent through FileDescriptor.withWin32HandleIfAvailable all
// move it. Windows serializes I/O on a synchronous handle.
//
// A transfer at a non-nil offset passes it in an OVERLAPPED. On a
// synchronous handle, that reads or writes at the offset *and* moves the
// file pointer, unlike POSIX `pread` and `pwrite`. Negative offsets are
// rejected before the call, since -1 and -2 are OVERLAPPED sentinels, for
// appending and for the current file pointer.

// MARK: - Reading

@available(System 199, *)
extension Win32.FileHandle {
  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`.
  ///
  /// Calls `ReadFile` once. A short read ends the call, which can be useful
  /// when reading from a pipe or console. To read until `span` is full or the
  /// file ends, use `readFully(fromAbsoluteOffset:into:)`.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if
  /// - `offset` is negative, or
  /// - `span` is larger than the `DWORD.max` bytes `ReadFile` can express.
  ///
  /// A read never throws ``Win32/Error/endOfFile``, ``Win32/Error/brokenPipe``,
  /// or ``Win32/Error/pipeNotConnected``: it returns zero at the end of a file
  /// and when a pipe's writer closes. On a message-mode pipe, a message longer
  /// than `span` fills it, and the rest arrives on the next read. A console
  /// read that Ctrl+C interrupts throws ``Win32/Error/operationAborted``.
  ///
  /// - Important: Reading from a non-`nil` `offset` also updates the file
  ///   pointer, unlike POSIX `pread`.
  ///
  /// - Returns: The number of bytes read, which may be fewer than
  ///   `span.byteCount`. Zero indicates end of file or an empty `span`.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED` offset
  /// when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout MutableRawSpan
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    return try span.withUnsafeMutableBytes { buffer in
      Win32._readFile(handle, into: buffer, at: offset)
    }.get()
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`.
  ///
  /// See ``read(fromAbsoluteOffset:into:)-(_,MutableRawSpan)``.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED` offset
  /// when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout MutableSpan<UInt8>
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    return try span.withUnsafeMutableBytes { buffer in
      Win32._readFile(handle, into: buffer, at: offset)
    }.get()
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, into `span`'s free capacity.
  ///
  /// Otherwise like ``read(fromAbsoluteOffset:into:)-(_,MutableRawSpan)``.
  ///
  /// - Returns: The number of bytes read. `span.byteCount` also grows by
  ///   this amount. Zero indicates end of file, or no free capacity.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED` offset
  /// when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func read(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    return try span.withUnsafeMutableBytes { buffer, initializedCount in
      let result = Win32._readFile(
        handle, into: UnsafeMutableRawBufferPointer(rebasing: buffer[initializedCount...]),
        at: offset)
      if case .success(let count) = result { initializedCount += count }
      return result
    }.get()
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, into `span`'s free capacity.
  ///
  /// See ``read(fromAbsoluteOffset:into:)-(_,OutputRawSpan)``.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED` offset
  /// when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func read(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputSpan<UInt8>
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    return try span.withUnsafeMutableBufferPointer { buffer, initializedCount in
      let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
      let result = Win32._readFile(
        handle, into: UnsafeMutableRawBufferPointer(free), at: offset)
      if case .success(let count) = result { initializedCount += count }
      return result
    }.get()
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, until `span` is full or the file ends.
  ///
  /// Unlike ``read(fromAbsoluteOffset:into:)-(_,MutableRawSpan)``, a short
  /// read only ends the transfer for a disk file, where it means the file
  /// ended, and a span larger than `DWORD.max` bytes is split across calls
  /// to `ReadFile` rather than rejected. The split falls at a multiple of
  /// 64 KiB, so a handle opened with ``Win32/FileFlags/noBuffering`` can read
  /// a sector-aligned span.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `offset` is negative.
  ///
  /// - Important: On a pipe or console, this blocks until the span fills, so
  ///   an over-sized span will hang for as long as the writer stays open.
  ///   Size the span to a length given by the transfer protocol, or use
  ///   ``read(fromAbsoluteOffset:into:)-(_,MutableRawSpan)`` to only read
  ///   bytes that are currently available. A message-mode pipe's message
  ///   boundaries aren't preserved.
  ///
  /// - Returns: The number of bytes read. A number less than `span.byteCount`
  ///   signifies the end of the file. If a `ReadFile` fails, the bytes already
  ///   read stay initialized in `span`.
  ///
  /// The corresponding C function is `ReadFile`, called in a loop.
  @_alwaysEmitIntoClient
  public func readFully(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout MutableRawSpan
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    var bytesRead = 0
    try span.withUnsafeMutableBytes { buffer in
      Win32._readFileFully(handle, into: buffer, at: offset, bytesRead: &bytesRead)
    }.get()
    return bytesRead
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, until `span` is full or the file ends.
  ///
  /// See ``readFully(fromAbsoluteOffset:into:)-(_,MutableRawSpan)``.
  ///
  /// The corresponding C function is `ReadFile`, called in a loop.
  @_alwaysEmitIntoClient
  public func readFully(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout MutableSpan<UInt8>
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    var bytesRead = 0
    try span.withUnsafeMutableBytes { buffer in
      Win32._readFileFully(handle, into: buffer, at: offset, bytesRead: &bytesRead)
    }.get()
    return bytesRead
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, until `span` has no free capacity or the file ends.
  ///
  /// Otherwise like ``readFully(fromAbsoluteOffset:into:)-(_,MutableRawSpan)``.
  ///
  /// - Returns: The number of bytes read. `span.byteCount` also grows by
  ///   this amount, and still counts the bytes read if a later `ReadFile`
  ///   throws.
  ///
  /// The corresponding C function is `ReadFile`, called in a loop.
  @_alwaysEmitIntoClient
  @discardableResult
  public func readFully(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    var bytesRead = 0
    try span.withUnsafeMutableBytes { buffer, initializedCount in
      let result = Win32._readFileFully(
        handle, into: UnsafeMutableRawBufferPointer(rebasing: buffer[initializedCount...]),
        at: offset, bytesRead: &bytesRead)
      initializedCount += bytesRead
      return result
    }.get()
    return bytesRead
  }

  /// Reads bytes starting at `offset`, or the current file pointer when
  /// `offset` is `nil`, until `span` has no free capacity or the file ends.
  ///
  /// See ``readFully(fromAbsoluteOffset:into:)-(_,OutputRawSpan)``.
  ///
  /// The corresponding C function is `ReadFile`, called in a loop.
  @_alwaysEmitIntoClient
  @discardableResult
  public func readFully(
    fromAbsoluteOffset offset: Int64? = nil,
    into span: inout OutputSpan<UInt8>
  ) throws(Win32.Error) -> Int {
    let handle = _handle
    var bytesRead = 0
    try span.withUnsafeMutableBufferPointer { buffer, initializedCount in
      let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
      let result = Win32._readFileFully(
        handle, into: UnsafeMutableRawBufferPointer(free), at: offset,
        bytesRead: &bytesRead)
      initializedCount += bytesRead
      return result
    }.get()
    return bytesRead
  }
}

// MARK: - Writing

@available(System 199, *)
extension Win32.FileHandle {
  /// Writes the contents of `span` to the specified `offset`, or the current
  /// file pointer when `offset` is `nil`.
  ///
  /// This loops until the span is exhausted by splitting a span larger than
  /// `DWORD.max` bytes across multiple `WriteFile` calls. The split falls at
  /// a multiple of 64 KiB, so a handle opened with
  /// ``Win32/FileFlags/noBuffering`` can write a sector-aligned span.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `offset` is
  /// negative. To write at the end of the file, use ``append(_:)``.
  ///
  /// - Important: Writing to a non-`nil` `offset` also updates the file
  ///   pointer, unlike POSIX `pwrite`.
  ///
  /// - Important: On a blocking pipe, this waits until the reader has taken
  ///   the whole span, so an over-sized span will hang until a reader fully
  ///   drains it.
  ///
  /// - Note: A `WriteFile` that succeeds without writing anything ends the
  ///   loop with a synthesized ``Win32/Error/incompleteTransfer`` instead of
  ///   retrying forever. A legacy `PIPE_NOWAIT` pipe reports a span that
  ///   doesn't fit this way. Such a write is all-or-nothing, so only retry a
  ///   `span` that will fit in the pipe's buffer.
  ///
  /// The corresponding C function is `WriteFile`, called in a loop, with an
  /// `OVERLAPPED` offset when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  public func write(
    _ span: RawSpan,
    toAbsoluteOffset offset: Int64? = nil
  ) throws(Win32.Error) {
    let handle = _handle
    var bytesWritten = 0
    try span.withUnsafeBytes { buffer in
      Win32._writeFile(handle, buffer, at: offset, bytesWritten: &bytesWritten)
    }.get()
  }

  /// Writes `span` like ``write(_:toAbsoluteOffset:)``, but advances the start
  /// of `span` to exclude the bytes that were written.
  ///
  /// If this throws, `span` holds the bytes that weren't written. On success,
  /// `span` is empty.
  ///
  /// The corresponding C function is `WriteFile`, called in a loop, with an
  /// `OVERLAPPED` offset when `offset` is non-`nil`.
  @_alwaysEmitIntoClient
  public func write(
    draining span: inout RawSpan,
    toAbsoluteOffset offset: Int64? = nil
  ) throws(Win32.Error) {
    let handle = _handle
    var bytesWritten = 0
    let result = span.withUnsafeBytes { buffer in
      Win32._writeFile(handle, buffer, at: offset, bytesWritten: &bytesWritten)
    }
    span = span.extracting(droppingFirst: bytesWritten)
    try result.get()
  }

  /// Writes the contents of `span` to the end of the file.
  ///
  /// Calls `WriteFile` once, transferring the whole span or throwing. The file
  /// pointer is updated to the new end of file.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `span` is larger
  /// than `DWORD.max` bytes. A single `WriteFile` can't express this size, and
  /// looping would risk another writer appending between the chunks.
  ///
  /// - Note: Because the append is all-or-nothing, a `WriteFile` that succeeds
  ///   without taking the whole span throws ``Win32/Error/incompleteTransfer``.
  ///   A legacy `PIPE_NOWAIT` pipe reports a span that doesn't fit this way;
  ///   see ``write(_:toAbsoluteOffset:)``.
  ///
  /// The corresponding C function is `WriteFile` with an `OVERLAPPED` offset of `-1`.
  @_alwaysEmitIntoClient
  public func append(_ span: RawSpan) throws(Win32.Error) {
    let handle = _handle
    var bytesWritten = 0
    try span.withUnsafeBytes { buffer in
      Win32._appendFile(handle, buffer, bytesWritten: &bytesWritten)
    }.get()
  }

  /// Appends `span` like ``append(_:)``, but advances the start of `span` to
  /// exclude the bytes that were written.
  ///
  /// If this throws, `span` holds the bytes that weren't written. On success,
  /// `span` is empty.
  ///
  /// The corresponding C function is `WriteFile` with an `OVERLAPPED` offset of `-1`.
  @_alwaysEmitIntoClient
  public func append(draining span: inout RawSpan) throws(Win32.Error) {
    let handle = _handle
    var bytesWritten = 0
    let result = span.withUnsafeBytes { buffer in
      Win32._appendFile(handle, buffer, bytesWritten: &bytesWritten)
    }
    span = span.extracting(droppingFirst: bytesWritten)
    try result.get()
  }
}

// MARK: - Seeking

@available(System 199, *)
extension Win32 {
  /// The reference point that a seek offset is measured from.
  @frozen
  public struct SeekOrigin: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C move method.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed seek origin from a raw C move method.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The start of the file.
    ///
    /// The corresponding C constant is `FILE_BEGIN`.
    @_alwaysEmitIntoClient
    public static var start: SeekOrigin { SeekOrigin(rawValue: 0) }

    /// The current file pointer.
    ///
    /// The corresponding C constant is `FILE_CURRENT`.
    @_alwaysEmitIntoClient
    public static var current: SeekOrigin { SeekOrigin(rawValue: 1) }

    /// The end of the file.
    ///
    /// The corresponding C constant is `FILE_END`.
    @_alwaysEmitIntoClient
    public static var end: SeekOrigin { SeekOrigin(rawValue: 2) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Returns the current position of the file pointer.
  ///
  /// - Warning: This function is not valid on a nonseeking device such as a
  ///   pipe or console. The call may succeed anyway, reporting a position
  ///   that no transfer ever advances, so file pointer arithmetic is invalid.
  ///
  /// The corresponding C function is `SetFilePointerEx` with zero offset
  /// from `FILE_CURRENT`.
  @_alwaysEmitIntoClient
  public func currentOffset() throws(Win32.Error) -> Int64 {
    try Win32._setFilePointer(_handle, 0, Win32.SeekOrigin.current.rawValue).get()
  }

  /// Moves the file pointer to an absolute position.
  ///
  /// A negative `offset` throws ``Win32/Error/negativeSeek``, the error
  /// `SetFilePointerEx` sets when a displacement lands before the start
  /// of the file.
  ///
  /// - Warning: This function is not valid on a nonseeking device such as a
  ///   pipe or console. The call may succeed anyway, moving a position that
  ///   no transfer uses.
  ///
  /// The corresponding C function is `SetFilePointerEx`.
  @_alwaysEmitIntoClient
  public func seek(to offset: Int64) throws(Win32.Error) {
    guard offset >= 0 else { throw .negativeSeek }
    _ = try Win32._setFilePointer(_handle, offset, Win32.SeekOrigin.start.rawValue).get()
  }

  /// Moves the file pointer and returns its new absolute position.
  ///
  /// `offset` is a displacement from `origin`, so it may be negative. For
  /// instance, `-1` from ``Win32/SeekOrigin/end`` addresses the last byte.
  /// A displacement that would land before the start of the file throws
  /// ``Win32/Error/negativeSeek``.
  ///
  /// - Warning: This function is not valid on a nonseeking device such as a
  ///   pipe or console. The call may succeed anyway, returning a position
  ///   that no transfer ever advances, so file pointer arithmetic is invalid.
  ///
  /// The corresponding C function is `SetFilePointerEx`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func seek(
    offset: Int64,
    from origin: Win32.SeekOrigin
  ) throws(Win32.Error) -> Int64 {
    try Win32._setFilePointer(_handle, offset, origin.rawValue).get()
  }
}

// MARK: - Flushing and resizing

@available(System 199, *)
extension Win32.FileHandle {
  /// Flushes this handle's buffered data to the device.
  ///
  /// Call this after writes that must survive power loss, such as a commit
  /// record. Most writes don't require flushing; readers already see the data
  /// without it, and each call costs a round trip to the device.
  ///
  /// This function provides a durability barrier similar to POSIX `fsync`. It
  /// writes this file's data out of the system cache and tells the device to
  /// commit its own volatile cache. For many writes that must each be durable,
  /// Windows recommends opening with ``Win32/FileFlags/writeThrough`` and
  /// ``Win32/FileFlags/noBuffering`` instead, which also asks the device to
  /// write through its cache.
  ///
  /// Requires ``Win32/AccessMask/writeData`` or
  /// ``Win32/AccessMask/appendData``.
  ///
  /// - Important: On a pipe, this blocks until the reader has read everything
  ///   written so far.
  ///
  /// The corresponding C function is `FlushFileBuffers`.
  @_alwaysEmitIntoClient
  public func flush() throws(Win32.Error) {
    try Win32._flushFileBuffers(_handle).get()
  }

  /// The size of the file, in bytes.
  ///
  /// - Warning: This function is not valid on a nonseeking device such as a
  ///   pipe or console. On a pipe, the call may succeed anyway and return an
  ///   unspecified value. To ask how many bytes a pipe has available to read,
  ///   use `PeekNamedPipe`.
  ///
  /// The corresponding C function is `GetFileSizeEx`, with a
  /// `LARGE_INTEGER`.
  @_alwaysEmitIntoClient
  public func size() throws(Win32.Error) -> Int64 {
    try Win32._fileSize(_handle).get()
  }

  /// Sets the end of the file to the current file pointer, truncating or
  /// extending it.
  ///
  /// Throws ``Win32/Error/userMappedFile`` when truncating a file that has a
  /// mapped view.
  ///
  /// The corresponding C function is `SetEndOfFile`.
  @_alwaysEmitIntoClient
  public func resizeToCurrentOffset() throws(Win32.Error) {
    try Win32._setEndOfFile(_handle).get()
  }

  /// Truncates or extends the file to `newSize`, leaving the file pointer
  /// where it is.
  ///
  /// Extending the file makes the new region read as zeros. A size past the
  /// volume's free space fails with ``Win32/Error/diskFull``. No failure
  /// leaves the file partly resized.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `newSize` is negative, or
  /// larger than the file system can represent, and
  /// ``Win32/Error/userMappedFile`` when truncating a file that has a mapped
  /// view.
  ///
  /// Unlike `FileDescriptor.resize(to:)` on Windows, which seeks, resizes,
  /// and restores the file pointer, this resizes in one call.
  ///
  /// The corresponding C function is `SetFileInformationByHandle` with
  /// `FileEndOfFileInfo` and a `FILE_END_OF_FILE_INFO`.
  @_alwaysEmitIntoClient
  public func resize(to newSize: Int64) throws(Win32.Error) {
    guard newSize >= 0 else { throw .invalidParameter }
    try Win32._setEndOfFileInformation(_handle, newSize).get()
  }
}

// MARK: - Implementation

@available(System 199, *)
extension Win32 {
  /// The most a transfer loop passes to one `ReadFile` or `WriteFile`: the
  /// largest multiple of 64 KiB that a `DWORD` holds, so that a split keeps
  /// the offsets and buffer addresses of a non-buffered handle
  /// sector-aligned.
  internal static var _transferChunkLimit: Int { 0xFFFF_0000 }

  internal static func _overlapped(offset: Int64) -> OVERLAPPED {
    var overlapped = OVERLAPPED()
    overlapped.Offset = DWORD(truncatingIfNeeded: offset)
    overlapped.OffsetHigh = DWORD(truncatingIfNeeded: offset >> 32)
    return overlapped
  }

  /// Whether a transfer of `count` bytes at `offset` is expressible: `nil`
  /// or a nonnegative offset whose end doesn't overflow.
  internal static func _isValidTransfer(at offset: Int64?, count: Int) -> Bool {
    guard let offset else { return true }
    return offset >= 0 && offset <= Int64.max - Int64(count)
  }

  /// One `ReadFile`, absorbing the codes that mean the end of the data.
  internal static func _readOnce(
    _ handle: HANDLE,
    _ address: UnsafeMutableRawPointer?,
    _ count: DWORD,
    at offset: Int64?
  ) -> Result<Int, Win32.Error> {
    var bytesRead: DWORD = 0
    // A successful console read that Ctrl+C interrupted leaves
    // ERROR_OPERATION_ABORTED, so no stale code may be left in place.
    SetLastError(Win32.Error.success.rawValue)
    let succeeded: Bool
    if let offset {
      var overlapped = _overlapped(offset: offset)
      succeeded = system_ReadFile(handle, address, count, &bytesRead, &overlapped)
    } else {
      succeeded = system_ReadFile(handle, address, count, &bytesRead, nil)
    }
    let error = Win32.Error(GetLastError())
    guard succeeded else {
      // A read at a specific offset past the end fails with
      // ERROR_HANDLE_EOF, where a file-pointer read returns zero bytes.
      // A pipe whose writer closed or whose server disconnected reports
      // ERROR_BROKEN_PIPE or ERROR_PIPE_NOT_CONNECTED, and the C runtime's
      // `_read` returns zero for the former. Compared with ==: until Errno's
      // `~=` is disfavored too, an implicit-member pattern for a name both
      // types have, such as `.brokenPipe`, would match Errno's code.
      if error == Win32.Error.endOfFile || error == Win32.Error.brokenPipe
        || error == Win32.Error.pipeNotConnected
      {
        return .success(0)
      }
      // A message longer than the read: its prefix is in the buffer, and
      // the rest follows on the next read.
      if error == Win32.Error.moreData { return .success(Int(bytesRead)) }
      return .failure(error)
    }
    if bytesRead == 0 && error == Win32.Error.operationAborted {
      return .failure(error)
    }
    return .success(Int(bytesRead))
  }

  @usableFromInline
  internal static func _readFile(
    _ handle: HANDLE,
    into buffer: UnsafeMutableRawBufferPointer,
    at offset: Int64?
  ) -> Result<Int, Win32.Error> {
    guard _isValidTransfer(at: offset, count: buffer.count),
      buffer.count <= Int(DWORD.max)
    else {
      return .failure(.invalidParameter)
    }
    return _readOnce(handle, buffer.baseAddress, DWORD(buffer.count), at: offset)
  }

  @usableFromInline
  internal static func _readFileFully(
    _ handle: HANDLE,
    into buffer: UnsafeMutableRawBufferPointer,
    at offset: Int64?,
    bytesRead: inout Int
  ) -> Result<Void, Win32.Error> {
    guard _isValidTransfer(at: offset, count: buffer.count) else {
      return .failure(.invalidParameter)
    }
    var isDisk: Bool? = nil
    // An empty span still issues its ReadFile.
    repeat {
      let chunk = min(buffer.count - bytesRead, _transferChunkLimit)
      let result = _readOnce(
        handle, buffer.baseAddress.map { $0 + bytesRead }, DWORD(chunk),
        at: offset.map { $0 + Int64(bytesRead) })
      switch result {
      case .failure(let error):
        return .failure(error)
      case .success(let count):
        bytesRead += count
        // Zero bytes: the end of the file, or a pipe whose writer closed.
        if count == 0 { return .success(()) }
        // A short read ends the transfer only on a disk file, where it means
        // the file ended. With FILE_FLAG_NO_BUFFERING, the next read would
        // start at an unaligned offset anyway.
        if count < chunk {
          if isDisk == nil {
            isDisk = system_GetFileType(handle) == _FILE_TYPE_DISK
          }
          if isDisk == true { return .success(()) }
        }
      }
    } while bytesRead < buffer.count
    return .success(())
  }

  internal static func _writeOnce(
    _ handle: HANDLE,
    _ address: UnsafeRawPointer?,
    _ count: DWORD,
    at offset: Int64?
  ) -> Result<Int, Win32.Error> {
    var bytesWritten: DWORD = 0
    let succeeded: Bool
    if let offset {
      var overlapped = _overlapped(offset: offset)
      succeeded = system_WriteFile(handle, address, count, &bytesWritten, &overlapped)
    } else {
      succeeded = system_WriteFile(handle, address, count, &bytesWritten, nil)
    }
    guard succeeded else { return .failure(Win32.Error(GetLastError())) }
    return .success(Int(bytesWritten))
  }

  @usableFromInline
  internal static func _writeFile(
    _ handle: HANDLE,
    _ buffer: UnsafeRawBufferPointer,
    at offset: Int64?,
    bytesWritten: inout Int
  ) -> Result<Void, Win32.Error> {
    guard _isValidTransfer(at: offset, count: buffer.count) else {
      return .failure(.invalidParameter)
    }
    // An empty span still issues its WriteFile: on a message-mode pipe, a
    // zero-length write sends a zero-length message.
    repeat {
      let chunk = min(buffer.count - bytesWritten, _transferChunkLimit)
      let result = _writeOnce(
        handle, buffer.baseAddress.map { $0 + bytesWritten }, DWORD(chunk),
        at: offset.map { $0 + Int64(bytesWritten) })
      switch result {
      case .failure(let error):
        return .failure(error)
      case .success(let count):
        bytesWritten += count
        // Retrying a write that took nothing could loop forever.
        if count == 0 && chunk > 0 { return .failure(.incompleteTransfer) }
      }
    } while bytesWritten < buffer.count
    return .success(())
  }

  @usableFromInline
  internal static func _appendFile(
    _ handle: HANDLE,
    _ buffer: UnsafeRawBufferPointer,
    bytesWritten: inout Int
  ) -> Result<Void, Win32.Error> {
    // One WriteFile, so that no other writer's append lands between chunks.
    guard buffer.count <= Int(DWORD.max) else { return .failure(.invalidParameter) }
    // Offset and OffsetHigh of 0xFFFFFFFF write at the end of the file.
    switch _writeOnce(handle, buffer.baseAddress, DWORD(buffer.count), at: -1) {
    case .failure(let error):
      return .failure(error)
    case .success(let count):
      bytesWritten = count
      guard count == buffer.count else { return .failure(.incompleteTransfer) }
      return .success(())
    }
  }

  @usableFromInline
  internal static func _setFilePointer(
    _ handle: HANDLE, _ distance: Int64, _ moveMethod: DWORD
  ) -> Result<Int64, Win32.Error> {
    var newPosition = LARGE_INTEGER()
    guard system_SetFilePointerEx(
      handle, LARGE_INTEGER(QuadPart: distance), &newPosition, moveMethod
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(newPosition.QuadPart)
  }

  @usableFromInline
  internal static func _flushFileBuffers(_ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_FlushFileBuffers(handle) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _fileSize(_ handle: HANDLE) -> Result<Int64, Win32.Error> {
    var size = LARGE_INTEGER()
    guard system_GetFileSizeEx(handle, &size) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(size.QuadPart)
  }

  @usableFromInline
  internal static func _setEndOfFile(_ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_SetEndOfFile(handle) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _setEndOfFileInformation(
    _ handle: HANDLE, _ newSize: Int64
  ) -> Result<Void, Win32.Error> {
    var information = FILE_END_OF_FILE_INFO(EndOfFile: LARGE_INTEGER(QuadPart: newSize))
    guard system_SetFileInformationByHandle(
      handle, FileEndOfFileInfo, &information,
      DWORD(MemoryLayout<FILE_END_OF_FILE_INFO>.size)
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
