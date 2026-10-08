/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: C standard I/O streams, on Windows. Provisional+Stdio.swift
// declares them for the other platforms; this is the same API over the
// Universal C Runtime, which names most of the calls as POSIX does. What
// differs is noted in each doc comment: the UCRT opens streams in text mode
// unless the mode says "b", its _IOLBF is full buffering, it has no
// ftrylockfile, its seeks don't reject a pipe or a console, which System
// checks for, and it reports an argument it rejects to the invalid
// parameter handler, whose default ends the process, so every call here
// runs with one that returns, and the call fails with EINVAL instead.

#if os(Windows)

import ucrt

@available(System 199, *)
extension CInterop {
  /// The state of a C standard I/O stream.
  ///
  /// The corresponding C type is `FILE`.
  ///
  /// - Note: Provisional: C standard I/O may move to the Swift standard library.
  public typealias File = ucrt.FILE
}

/// A C standard I/O stream: a buffered stream of bytes over a file descriptor.
///
/// A stream holds what's written to it in a buffer,
/// and writes the buffer to its file descriptor
/// when it fills, or when it's flushed or closed;
/// it reads ahead into the same buffer.
/// Swift's `print` writes to the standard output's stream,
/// so what a program writes to ``standardOutput`` interleaves with it.
///
/// A stream is a handle, as ``FileDescriptor`` is:
/// copying one doesn't copy the stream,
/// and ``close()`` closes it for every copy.
/// The C runtime locks a stream for each call,
/// so threads can share one;
/// ``withLock(_:)`` keeps a series of calls together.
///
/// A stream reports the errors of the calls it makes with `errno`,
/// so its methods throw ``Errno``.
/// On Windows, the C runtime reports an argument it rejects,
/// such as an invalid mode or a closed file descriptor,
/// to its invalid parameter handler, which ends the process by default;
/// this type's calls run with a handler that returns,
/// so they throw ``Errno/invalidArgument`` or ``Errno/badFileDescriptor``
/// instead.
///
/// - Note: Provisional: C standard I/O may move to the Swift standard library.
@frozen
@available(System 199, *)
public struct FileStream: RawRepresentable, Hashable, @unchecked Sendable {
  /// The C stream.
  @_alwaysEmitIntoClient
  public var rawValue: UnsafeMutablePointer<CInterop.File>

  /// Creates a stream from a C stream.
  @_alwaysEmitIntoClient
  public init(rawValue: UnsafeMutablePointer<CInterop.File>) { self.rawValue = rawValue }
}

// MARK: - The standard streams

@available(System 199, *)
extension FileStream {
  /// The standard input stream, which reads file descriptor 0.
  ///
  /// The corresponding C variable is `stdin`, which the C runtime spells
  /// `__acrt_iob_func(0)`.
  @_alwaysEmitIntoClient
  public static var standardInput: FileStream { FileStream(rawValue: _standardStream(0)) }

  /// The standard output stream, which writes file descriptor 1,
  /// and which Swift's `print` writes to.
  ///
  /// It's unbuffered when it's a console, and fully buffered otherwise.
  ///
  /// The corresponding C variable is `stdout`, which the C runtime spells
  /// `__acrt_iob_func(1)`.
  @_alwaysEmitIntoClient
  public static var standardOutput: FileStream { FileStream(rawValue: _standardStream(1)) }

  /// The standard error stream, which writes file descriptor 2,
  /// unbuffered.
  ///
  /// The corresponding C variable is `stderr`, which the C runtime spells
  /// `__acrt_iob_func(2)`.
  @_alwaysEmitIntoClient
  public static var standardError: FileStream { FileStream(rawValue: _standardStream(2)) }

  @usableFromInline
  internal static func _standardStream(_ index: UInt32) -> UnsafeMutablePointer<CInterop.File> {
    system___acrt_iob_func(index)
  }
}

// MARK: - Opening and closing

@available(System 199, *)
extension FileStream {
  /// Opens a stream on the file at a path.
  ///
  /// - Parameters:
  ///   - path: The file to open.
  ///   - mode: How to open it, as C spells it:
  ///     `"r"` to read; `"w"` to write, creating the file or truncating it;
  ///     `"a"` to append, creating the file;
  ///     and `"r+"`, `"w+"`, or `"a+"` to read and write.
  ///     A mode can add `"x"` after `"w"`, to fail if the file exists.
  ///     On Windows, a stream translates newlines to `\r\n` and back
  ///     unless its mode adds `"b"`, for binary, and its descriptor is
  ///     inherited by the processes the C runtime creates unless the mode
  ///     adds `"N"`, the C runtime's counterpart of POSIX's `"e"`.
  ///
  /// An invalid mode throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `_wfopen`.
  @_alwaysEmitIntoClient
  public static func open(_ path: FilePath, mode: String) throws(Errno) -> FileStream {
    try path.withPlatformString { FileStream._open($0, mode: mode) }.get()
  }

  /// Opens a stream on the file at a path.
  ///
  /// - Parameters:
  ///   - path: The file to open.
  ///   - mode: How to open it, as C spells it. See ``open(_:mode:)-(FilePath,_)``.
  ///
  /// The corresponding C function is `_wfopen`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CInterop.PlatformChar>, mode: String
  ) throws(Errno) -> FileStream {
    try _open(path, mode: mode).get()
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CInterop.PlatformChar>, mode: String
  ) -> Result<FileStream, Errno> {
    mode.withCString(encodedAs: UTF16.self) { mode in
      guard let stream = system__wfopen(path, mode) else { return .failure(.current) }
      return .success(FileStream(rawValue: stream))
    }
  }

  /// Opens a stream on a file descriptor.
  ///
  /// - Parameters:
  ///   - fd: The file descriptor the stream reads and writes.
  ///     The stream takes it over: closing the stream closes it.
  ///   - mode: How the stream uses it, as C spells it,
  ///     which the descriptor's access mode must allow.
  ///     See ``open(_:mode:)-(FilePath,_)``;
  ///     `"w"` doesn't truncate the file.
  ///
  /// The corresponding C function is `_fdopen`.
  @_alwaysEmitIntoClient
  public static func open(_ fd: FileDescriptor, mode: String) throws(Errno) -> FileStream {
    try _open(fd, mode: mode).get()
  }

  @usableFromInline
  internal static func _open(_ fd: FileDescriptor, mode: String) -> Result<FileStream, Errno> {
    mode.withCString { mode in
      guard let stream = system__fdopen(fd.rawValue, mode) else { return .failure(.current) }
      return .success(FileStream(rawValue: stream))
    }
  }

  /// Flushes the stream and closes it, and its file descriptor.
  ///
  /// The stream can't be used afterward, even if this method throws.
  ///
  /// The corresponding C function is `fclose`.
  @_alwaysEmitIntoClient
  public func close() throws(Errno) {
    try _close().get()
  }

  @usableFromInline
  internal func _close() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_fclose(rawValue) }
  }

  /// Returns the file descriptor that the stream reads and writes.
  ///
  /// The descriptor stays the stream's:
  /// closing it, or reading or writing it directly,
  /// leaves the stream's buffer out of step with the file.
  /// A standard stream of a process without a console has none,
  /// and throws ``Errno/badFileDescriptor``.
  ///
  /// The corresponding C function is `_fileno`.
  @_alwaysEmitIntoClient
  public func fileDescriptor() throws(Errno) -> FileDescriptor {
    try _fileDescriptor().get()
  }

  @usableFromInline
  internal func _fileDescriptor() -> Result<FileDescriptor, Errno> {
    // -2 is the C runtime's descriptor for a standard stream with no
    // handle behind it.
    let fd = system__fileno(rawValue)
    guard fd >= 0 else { return .failure(fd == -2 ? .badFileDescriptor : .current) }
    return .success(FileDescriptor(rawValue: fd))
  }
}

// MARK: - Reading and writing

@available(System 199, *)
extension FileStream {
  /// Writes bytes to the stream.
  ///
  /// - Parameter bytes: The bytes to write.
  ///
  /// The stream holds the bytes in its buffer until it writes the buffer
  /// to its file descriptor, as its ``Buffering`` says,
  /// or ``flush()`` writes it.
  /// If writing fails, this method throws the error,
  /// and some of the bytes may have been written;
  /// the stream's ``hasError`` is then `true`.
  ///
  /// The corresponding C function is `fwrite`.
  @_alwaysEmitIntoClient
  public func write(_ bytes: UnsafeRawBufferPointer) throws(Errno) {
    try _write(bytes.baseAddress, bytes.count).get()
  }

  /// Writes a string's UTF-8 bytes to the stream.
  ///
  /// See ``write(_:)-(UnsafeRawBufferPointer)``.
  ///
  /// The corresponding C function is `fwrite`.
  @_alwaysEmitIntoClient
  public func write(_ string: String) throws(Errno) {
    var string = string
    try string.withUTF8 { _write($0.baseAddress, $0.count) }.get()
  }

  @usableFromInline
  internal func _write(_ start: UnsafeRawPointer?, _ count: Int) -> Result<(), Errno> {
    guard count > 0 else { return .success(()) }
    return system_fwrite(start, count, rawValue) == count ? .success(()) : .failure(.current)
  }

  /// Writes a C string's bytes to the stream, up to its null byte.
  ///
  /// - Parameter string: A null-terminated C string,
  ///   such as a message from C code.
  ///
  /// See ``write(_:)-(UnsafeRawBufferPointer)``.
  ///
  /// The corresponding C function is `fputs`.
  @_alwaysEmitIntoClient
  public func write(cString string: UnsafePointer<CChar>) throws(Errno) {
    try _write(cString: string).get()
  }

  @usableFromInline
  internal func _write(cString string: UnsafePointer<CChar>) -> Result<(), Errno> {
    system_fputs(string, rawValue) == _EOF ? .failure(.current) : .success(())
  }

  /// Writes one byte to the stream.
  ///
  /// - Parameter byte: The byte to write.
  ///
  /// See ``write(_:)-(UnsafeRawBufferPointer)``.
  ///
  /// The corresponding C function is `fputc`.
  @_alwaysEmitIntoClient
  public func write(byte: UInt8) throws(Errno) {
    try _write(byte: byte).get()
  }

  @usableFromInline
  internal func _write(byte: UInt8) -> Result<(), Errno> {
    system_fputc(CInt(byte), rawValue) == _EOF ? .failure(.current) : .success(())
  }

  /// Reads bytes from the stream into a buffer.
  ///
  /// - Parameter buffer: Where to put the bytes.
  /// - Returns: The number of bytes read,
  ///   which is fewer than the buffer holds only at the end of the file,
  ///   where ``isAtEnd`` becomes `true`.
  ///
  /// The stream fills the buffer from what it has read ahead,
  /// and reads its file descriptor for the rest,
  /// waiting until it has enough or the file ends.
  ///
  /// The corresponding C function is `fread`.
  @_alwaysEmitIntoClient
  public func read(into buffer: UnsafeMutableRawBufferPointer) throws(Errno) -> Int {
    try _read(buffer.baseAddress, buffer.count).get()
  }

  @usableFromInline
  internal func _read(_ start: UnsafeMutableRawPointer?, _ count: Int) -> Result<Int, Errno> {
    guard count > 0 else { return .success(0) }
    let read = system_fread(start, count, rawValue)
    if read < count && system_ferror(rawValue) != 0 { return .failure(.current) }
    return .success(read)
  }

  /// Reads a line from the stream:
  /// its bytes up to and including the next newline,
  /// or to the end of the file.
  ///
  /// - Parameter strippingNewline: Whether to leave out the line's
  ///   newline, and a carriage return before it. The default is `true`.
  /// - Returns: The line, decoded as UTF-8, or `nil` at the end of the file,
  ///   where ``isAtEnd`` becomes `true`.
  ///
  /// This method reads any stream as the standard library's
  /// `readLine(strippingNewline:)` reads the standard input,
  /// replacing bytes that aren't valid UTF-8 with U+FFFD.
  /// The stream reads its file descriptor as it needs to,
  /// waiting until it has a whole line or the file ends.
  /// If reading fails, this method throws the error,
  /// and the stream's ``hasError`` is then `true`.
  ///
  /// The C runtime has no `getline`, so this method reads the line a byte at
  /// a time, with the stream locked.
  ///
  /// The corresponding C function is `fgetc`.
  @_alwaysEmitIntoClient
  public func readLine(strippingNewline: Bool = true) throws(Errno) -> String? {
    try _readLine(strippingNewline: strippingNewline).get()
  }

  @usableFromInline
  internal func _readLine(strippingNewline: Bool) -> Result<String?, Errno> {
    var bytes: [UInt8] = []
    system__lock_file(rawValue)
    defer { system__unlock_file(rawValue) }
    while true {
      let byte = system_fgetc(rawValue)
      guard byte != _EOF else {
        if system_ferror(rawValue) != 0 { return .failure(.current) }
        if bytes.isEmpty { return .success(nil) }
        break
      }
      bytes.append(UInt8(truncatingIfNeeded: byte))
      if byte == CInt(UInt8(ascii: "\n")) { break }
    }
    var line = bytes[...]
    if strippingNewline, line.last == UInt8(ascii: "\n") {
      line = line.dropLast()
      if line.last == UInt8(ascii: "\r") { line = line.dropLast() }
    }
    return .success(String(decoding: line, as: UTF8.self))
  }

  /// Writes what the stream holds in its buffer to its file descriptor.
  ///
  /// The corresponding C function is `fflush`.
  @_alwaysEmitIntoClient
  public func flush() throws(Errno) {
    try FileStream._flush(rawValue).get()
  }

  /// Writes what every open output stream holds in its buffer
  /// to its file descriptor.
  ///
  /// The corresponding C function is `fflush`, with a null stream.
  @_alwaysEmitIntoClient
  public static func flushAll() throws(Errno) {
    try _flush(nil).get()
  }

  @usableFromInline
  internal static func _flush(_ stream: UnsafeMutablePointer<CInterop.File>?) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_fflush(stream) }
  }

  /// Whether a read or write on the stream has failed,
  /// until ``clearError()``.
  ///
  /// The corresponding C function is `ferror`.
  @_alwaysEmitIntoClient
  public var hasError: Bool { _hasError }

  @usableFromInline
  internal var _hasError: Bool { system_ferror(rawValue) != 0 }

  /// Whether a read reached the end of the file,
  /// until ``clearError()``.
  ///
  /// The corresponding C function is `feof`.
  @_alwaysEmitIntoClient
  public var isAtEnd: Bool { _isAtEnd }

  @usableFromInline
  internal var _isAtEnd: Bool { system_feof(rawValue) != 0 }

  /// Clears the stream's error and end-of-file indicators,
  /// ``hasError`` and ``isAtEnd``.
  ///
  /// The corresponding C function is `clearerr`.
  @_alwaysEmitIntoClient
  public func clearError() {
    _clearError()
  }

  @usableFromInline
  internal func _clearError() {
    system_clearerr(rawValue)
  }
}

// MARK: - Positioning

@available(System 199, *)
extension FileStream {
  /// Moves the stream's position, where its next read or write starts.
  ///
  /// - Parameters:
  ///   - offset: The new position, in bytes from `origin`.
  ///   - origin: Where `offset` counts from:
  ///     ``FileDescriptor/SeekOrigin/start``,
  ///     ``FileDescriptor/SeekOrigin/current``,
  ///     or ``FileDescriptor/SeekOrigin/end``.
  ///
  /// The stream first writes what it holds in its buffer,
  /// and drops what it read ahead;
  /// moving clears ``isAtEnd``.
  /// A stream over a pipe, a socket, or a character device,
  /// such as a console or `NUL`, can't move,
  /// and throws ``Errno/illegalSeek``.
  /// The C runtime doesn't check, and its result for one is undefined,
  /// so this method checks the type of the stream's file first.
  ///
  /// In a stream that translates newlines,
  /// positions count the file's bytes, so `\r\n` counts as two.
  ///
  /// The corresponding C function is `_fseeki64`, or `fseek`, whose offset
  /// is a 32-bit `long` on Windows.
  @_alwaysEmitIntoClient
  public func seek(offset: Int64, from origin: FileDescriptor.SeekOrigin) throws(Errno) {
    try _seek(offset: offset, from: origin).get()
  }

  @usableFromInline
  internal func _seek(offset: Int64, from origin: FileDescriptor.SeekOrigin) -> Result<(), Errno> {
    if _hasNoPosition() { return .failure(.illegalSeek) }
    return nothingOrErrno(retryOnInterrupt: false) {
      system__fseeki64(rawValue, offset, origin.rawValue)
    }
  }

  /// Returns the stream's position, where its next read or write starts,
  /// in bytes from the start of the file.
  ///
  /// The position counts what the stream holds in its buffer:
  /// it's after what was written to the stream and not yet flushed,
  /// and before what the stream read ahead,
  /// wherever its file descriptor's offset is.
  /// A stream over a pipe, a socket, or a character device,
  /// such as a console or `NUL`, has no position,
  /// and throws ``Errno/illegalSeek``.
  ///
  /// In a stream that translates newlines,
  /// positions count the file's bytes, so `\r\n` counts as two.
  ///
  /// The corresponding C function is `_ftelli64`.
  @_alwaysEmitIntoClient
  public func offset() throws(Errno) -> Int64 {
    try _offset().get()
  }

  @usableFromInline
  internal func _offset() -> Result<Int64, Errno> {
    if _hasNoPosition() { return .failure(.illegalSeek) }
    return valueOrErrno(retryOnInterrupt: false) { system__ftelli64(rawValue) }
  }

  /// Whether the stream's file is one with no position. A stream with no
  /// file descriptor, or a descriptor with no handle, is left to the C
  /// runtime's call, which reports it.
  internal func _hasNoPosition() -> Bool {
    let fd = system__fileno(rawValue)
    return fd >= 0 && FileDescriptor(rawValue: fd)._hasNoPosition()
  }
}

// MARK: - Buffering

@available(System 199, *)
extension FileStream {
  /// How a stream buffers what's written to it.
  ///
  /// - Note: Provisional: C standard I/O may move to the Swift standard library.
  @frozen
  public struct Buffering: RawRepresentable, Hashable, Sendable {
    /// The raw C mode.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed mode from a raw C mode.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Writes the buffer when it's full.
    ///
    /// The corresponding C constant is `_IOFBF`.
    @_alwaysEmitIntoClient
    public static var full: Buffering { Buffering(rawValue: 0x0000) }

    /// Writes the buffer at each newline, and when it's full.
    ///
    /// On Windows, the C runtime buffers a line-buffered stream fully.
    ///
    /// The corresponding C constant is `_IOLBF`.
    @_alwaysEmitIntoClient
    public static var line: Buffering { Buffering(rawValue: 0x0040) }

    /// Writes each call's bytes at once.
    ///
    /// The corresponding C constant is `_IONBF`.
    @_alwaysEmitIntoClient
    public static var unbuffered: Buffering { Buffering(rawValue: 0x0004) }
  }

  /// Sets how the stream buffers, and the memory it buffers in.
  ///
  /// - Parameters:
  ///   - buffering: How to buffer.
  ///   - buffer: Memory for the stream to buffer in,
  ///     which must stay valid until the stream is closed,
  ///     or `nil` for memory the stream allocates.
  ///     The default is `nil`.
  ///
  /// Call this method before reading or writing the stream.
  /// The C runtime takes a buffer of 2 bytes or more, and throws
  /// ``Errno/invalidArgument`` for a smaller one, or a mode other than
  /// the three; for `nil`, it allocates 4 KiB.
  ///
  /// The corresponding C function is `setvbuf`.
  @_alwaysEmitIntoClient
  public func setBuffering(
    _ buffering: Buffering, buffer: UnsafeMutableRawBufferPointer? = nil
  ) throws(Errno) {
    try _setBuffering(buffering, buffer).get()
  }

  @usableFromInline
  internal func _setBuffering(
    _ buffering: Buffering, _ buffer: UnsafeMutableRawBufferPointer?
  ) -> Result<(), Errno> {
    // The C runtime's checks, made first, since it reports a failed one to
    // the invalid parameter handler. It allocates a buffer of the size it's
    // given when it's given none, where POSIX's picks one for a size of 0.
    let size = buffer?.count ?? 4096
    guard buffering == .full || buffering == .line || buffering == .unbuffered,
      buffering == .unbuffered || (2...Int(CInt.max)).contains(size)
    else {
      return .failure(.invalidArgument)
    }
    Errno.current = Errno(rawValue: 0)
    let start = buffer?.baseAddress?.assumingMemoryBound(to: CChar.self)
    guard system_setvbuf(rawValue, start, buffering.rawValue, size) == 0 else {
      return .failure(Errno.current.rawValue == 0 ? .invalidArgument : .current)
    }
    return .success(())
  }
}

@available(System 199, *)
extension FileStream.Buffering: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the buffering.
  @inline(never)
  public var description: String {
    switch self {
    case .full: return "full"
    case .line: return "line"
    case .unbuffered: return "unbuffered"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the buffering, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - Locking

@available(System 199, *)
extension FileStream {
  /// Locks the stream,
  /// waiting until no other thread has it locked.
  ///
  /// The C runtime locks the stream for each call,
  /// and the lock is recursive,
  /// so a thread that locks the stream
  /// can go on calling methods on it,
  /// and other threads' calls wait until it unlocks the stream
  /// as many times as it locked it.
  ///
  /// Windows' C runtime has no `ftrylockfile`, so there's no `tryLock()`.
  ///
  /// The corresponding C function is `_lock_file`.
  @_alwaysEmitIntoClient
  public func lock() {
    _lock()
  }

  @usableFromInline
  internal func _lock() {
    system__lock_file(rawValue)
  }

  /// Unlocks the stream, which the calling thread locked.
  ///
  /// The corresponding C function is `_unlock_file`.
  @_alwaysEmitIntoClient
  public func unlock() {
    _unlock()
  }

  @usableFromInline
  internal func _unlock() {
    system__unlock_file(rawValue)
  }

  /// Calls a closure with the stream locked,
  /// so that other threads' calls on it
  /// don't come between the closure's.
  ///
  /// - Parameter body: The closure to call.
  /// - Returns: What `body` returns.
  ///
  /// The corresponding C functions are `_lock_file` and `_unlock_file`.
  @_alwaysEmitIntoClient
  public func withLock<R>(_ body: () throws -> R) rethrows -> R {
    _lock()
    defer { _unlock() }
    return try body()
  }
}

#endif // os(Windows)
