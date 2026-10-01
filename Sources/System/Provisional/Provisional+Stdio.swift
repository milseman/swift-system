/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: C standard I/O streams.
//
// System wraps C's stdio provisionally. Buffered FILE streams are the C
// library's layer above the file descriptors that System wraps, not an
// operating-system interface, and Swift's `print` shares the standard
// output's buffer with them, so their lasting home may be the standard
// library, next to `print`. Until then, a package that writes through a
// stream's buffer, such as a logger that interleaves with `print`, can do
// it without importing the C library.

#if !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// wasi-libc's FILE is an incomplete type, which Swift doesn't import, so
// WASI has no CInterop.File, and a stream's rawValue is an OpaquePointer.
#if !os(WASI)
@available(System 199, *)
extension CInterop {
  /// The state of a C standard I/O stream.
  ///
  /// The corresponding C type is `FILE`.
  ///
  /// - Note: Provisional: C standard I/O may move to the Swift standard library.
  public typealias File = FILE
}
#endif

/// A C standard I/O stream: a buffered stream of bytes over a file descriptor.
///
/// A stream holds what's written to it in a buffer,
/// and writes the buffer to its file descriptor
/// when it fills, at a newline for a line-buffered stream,
/// or when it's flushed or closed;
/// it reads ahead into the same buffer.
/// Swift's `print` writes to the standard output's stream,
/// so what a program writes to ``standardOutput`` interleaves with it.
///
/// A stream is a handle, as ``FileDescriptor`` is:
/// copying one doesn't copy the stream,
/// and ``close()`` closes it for every copy.
/// The C library locks a stream for each call,
/// so threads can share one;
/// ``withLock(_:)`` keeps a series of calls together.
///
/// A stream reports the errors of the calls it makes with `errno`,
/// so its methods throw ``Errno``.
/// None of them retries an interrupted call:
/// a stream can have written some of a buffer before the interruption.
///
/// - Note: Provisional: C standard I/O may move to the Swift standard library.
@frozen
@available(System 199, *)
public struct FileStream: RawRepresentable, Hashable, @unchecked Sendable {
  #if os(WASI)
  /// The C stream.
  ///
  /// WASI's `FILE` is an incomplete type,
  /// so Swift imports a pointer to one as `OpaquePointer`.
  @_alwaysEmitIntoClient
  public var rawValue: OpaquePointer

  /// Creates a stream from a C stream.
  @_alwaysEmitIntoClient
  public init(rawValue: OpaquePointer) { self.rawValue = rawValue }
  #else
  /// The C stream.
  @_alwaysEmitIntoClient
  public var rawValue: UnsafeMutablePointer<CInterop.File>

  /// Creates a stream from a C stream.
  @_alwaysEmitIntoClient
  public init(rawValue: UnsafeMutablePointer<CInterop.File>) { self.rawValue = rawValue }
  #endif
}

// MARK: - The standard streams

@available(System 199, *)
extension FileStream {
  /// The standard input stream, which reads file descriptor 0.
  ///
  /// The corresponding C variable is `stdin`.
  @_alwaysEmitIntoClient
  public static var standardInput: FileStream { FileStream(rawValue: _stdin) }

  /// The standard output stream, which writes file descriptor 1,
  /// and which Swift's `print` writes to.
  ///
  /// It's line-buffered when it's a terminal, and fully buffered otherwise.
  ///
  /// The corresponding C variable is `stdout`.
  @_alwaysEmitIntoClient
  public static var standardOutput: FileStream { FileStream(rawValue: _stdout) }

  /// The standard error stream, which writes file descriptor 2,
  /// unbuffered.
  ///
  /// The corresponding C variable is `stderr`.
  @_alwaysEmitIntoClient
  public static var standardError: FileStream { FileStream(rawValue: _stderr) }
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
  ///     A mode can add `"x"` after `"w"`, to fail if the file exists,
  ///     and `"e"`, to set ``FileDescriptor/OpenOptions/closeOnExec``.
  ///     C accepts `"b"`, and ignores it.
  ///
  /// An invalid mode throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `fopen`.
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
  /// The corresponding C function is `fopen`.
  @_alwaysEmitIntoClient
  public static func open(_ path: UnsafePointer<CChar>, mode: String) throws(Errno) -> FileStream {
    try _open(path, mode: mode).get()
  }

  @usableFromInline
  internal static func _open(_ path: UnsafePointer<CChar>, mode: String) -> Result<FileStream, Errno> {
    mode.withCString { mode in
      guard let stream = system_fopen(path, mode) else { return .failure(.current) }
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
  /// The corresponding C function is `fdopen`.
  @_alwaysEmitIntoClient
  public static func open(_ fd: FileDescriptor, mode: String) throws(Errno) -> FileStream {
    try _open(fd, mode: mode).get()
  }

  @usableFromInline
  internal static func _open(_ fd: FileDescriptor, mode: String) -> Result<FileStream, Errno> {
    mode.withCString { mode in
      guard let stream = system_fdopen(fd.rawValue, mode) else { return .failure(.current) }
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
  ///
  /// The corresponding C function is `fileno`.
  @_alwaysEmitIntoClient
  public func fileDescriptor() throws(Errno) -> FileDescriptor {
    try _fileDescriptor().get()
  }

  @usableFromInline
  internal func _fileDescriptor() -> Result<FileDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: false) { system_fileno(rawValue) }.map(FileDescriptor.init(rawValue:))
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
    system_fputs(string, rawValue) == EOF ? .failure(.current) : .success(())
  }

  /// Writes one byte to the stream.
  ///
  /// - Parameter byte: The byte to write.
  ///
  /// See ``write(_:)-(UnsafeRawBufferPointer)``.
  ///
  /// The corresponding C functions are `fputc` and `putc`.
  @_alwaysEmitIntoClient
  public func write(byte: UInt8) throws(Errno) {
    try _write(byte: byte).get()
  }

  @usableFromInline
  internal func _write(byte: UInt8) -> Result<(), Errno> {
    system_fputc(CInt(byte), rawValue) == EOF ? .failure(.current) : .success(())
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
  /// The corresponding C function is `getline`.
  @_alwaysEmitIntoClient
  public func readLine(strippingNewline: Bool = true) throws(Errno) -> String? {
    try _readLine(strippingNewline: strippingNewline).get()
  }

  @usableFromInline
  internal func _readLine(strippingNewline: Bool) -> Result<String?, Errno> {
    var line: UnsafeMutablePointer<CChar>? = nil
    var capacity = 0
    // getline allocates the line's buffer, whether or not it reads.
    defer { system_free(line) }
    let count = system_getline(&line, &capacity, rawValue)
    guard count >= 0 else {
      return system_ferror(rawValue) != 0 ? .failure(.current) : .success(nil)
    }
    var bytes = UnsafeRawBufferPointer(start: line, count: count)
    if strippingNewline, bytes.last == UInt8(ascii: "\n") {
      bytes = UnsafeRawBufferPointer(rebasing: bytes.dropLast())
      if bytes.last == UInt8(ascii: "\r") {
        bytes = UnsafeRawBufferPointer(rebasing: bytes.dropLast())
      }
    }
    return .success(String(decoding: bytes, as: UTF8.self))
  }

  /// Writes what the stream holds in its buffer to its file descriptor.
  ///
  /// The corresponding C function is `fflush`.
  @_alwaysEmitIntoClient
  public func flush() throws(Errno) {
    try _flush(rawValue).get()
  }

  /// Writes what every open output stream holds in its buffer
  /// to its file descriptor.
  ///
  /// The corresponding C function is `fflush`, with a null stream.
  @_alwaysEmitIntoClient
  public static func flushAll() throws(Errno) {
    try _flush(nil).get()
  }

  #if os(WASI)
  @usableFromInline
  internal static func _flush(_ stream: OpaquePointer?) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_fflush(stream) }
  }

  @usableFromInline
  internal func _flush(_ stream: OpaquePointer) -> Result<(), Errno> {
    FileStream._flush(stream)
  }
  #else
  @usableFromInline
  internal static func _flush(_ stream: UnsafeMutablePointer<CInterop.File>?) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_fflush(stream) }
  }

  @usableFromInline
  internal func _flush(_ stream: UnsafeMutablePointer<CInterop.File>) -> Result<(), Errno> {
    FileStream._flush(stream)
  }
  #endif

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
  /// A stream over a pipe, a socket or a terminal can't move,
  /// and throws ``Errno/illegalSeek``.
  ///
  /// The corresponding C function is `fseeko`.
  @_alwaysEmitIntoClient
  public func seek(offset: Int64, from origin: FileDescriptor.SeekOrigin) throws(Errno) {
    try _seek(offset: offset, from: origin).get()
  }

  @usableFromInline
  internal func _seek(offset: Int64, from origin: FileDescriptor.SeekOrigin) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_fseeko(rawValue, _COffT(offset), origin.rawValue)
    }
  }

  /// Returns the stream's position, where its next read or write starts,
  /// in bytes from the start of the file.
  ///
  /// The position counts what the stream holds in its buffer:
  /// it's after what was written to the stream and not yet flushed,
  /// and before what the stream read ahead,
  /// wherever its file descriptor's offset is.
  /// A stream over a pipe, a socket or a terminal has no position,
  /// and throws ``Errno/illegalSeek``.
  ///
  /// The corresponding C function is `ftello`.
  @_alwaysEmitIntoClient
  public func offset() throws(Errno) -> Int64 {
    try _offset().get()
  }

  @usableFromInline
  internal func _offset() -> Result<Int64, Errno> {
    valueOrErrno(retryOnInterrupt: false) { Int64(system_ftello(rawValue)) }
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
    public static var full: Buffering { Buffering(rawValue: __IOFBF) }

    /// Writes the buffer at each newline, and when it's full.
    ///
    /// The corresponding C constant is `_IOLBF`.
    @_alwaysEmitIntoClient
    public static var line: Buffering { Buffering(rawValue: __IOLBF) }

    /// Writes each call's bytes at once.
    ///
    /// The corresponding C constant is `_IONBF`.
    @_alwaysEmitIntoClient
    public static var unbuffered: Buffering { Buffering(rawValue: __IONBF) }
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
  /// With a buffer smaller than 128 bytes, glibc sends some writes,
  /// the stream's first among them, straight to the file descriptor.
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
    system_errno = 0
    let start = buffer?.baseAddress?.assumingMemoryBound(to: CChar.self)
    guard system_setvbuf(rawValue, start, buffering.rawValue, buffer?.count ?? 0) == 0 else {
      // C doesn't promise to set errno for an invalid mode or size.
      return .failure(system_errno == 0 ? .invalidArgument : .current)
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

#if !os(WASI)
@available(System 199, *)
extension FileStream {
  /// Locks the stream,
  /// waiting until no other thread has it locked.
  ///
  /// The C library locks the stream for each call,
  /// and the lock is recursive,
  /// so a thread that locks the stream
  /// can go on calling methods on it,
  /// and other threads' calls wait until it unlocks the stream
  /// as many times as it locked it.
  ///
  /// The corresponding C function is `flockfile`.
  ///
  /// - Note: Not available on WASI.
  @_alwaysEmitIntoClient
  public func lock() {
    _lock()
  }

  @usableFromInline
  internal func _lock() {
    system_flockfile(rawValue)
  }

  /// Unlocks the stream, which the calling thread locked.
  ///
  /// The corresponding C function is `funlockfile`.
  ///
  /// - Note: Not available on WASI.
  @_alwaysEmitIntoClient
  public func unlock() {
    _unlock()
  }

  @usableFromInline
  internal func _unlock() {
    system_funlockfile(rawValue)
  }

  /// Locks the stream if no other thread has it locked.
  ///
  /// - Returns: `true` if this call locked the stream.
  ///
  /// The corresponding C function is `ftrylockfile`.
  ///
  /// - Note: Not available on WASI.
  @_alwaysEmitIntoClient
  public func tryLock() -> Bool {
    _tryLock()
  }

  @usableFromInline
  internal func _tryLock() -> Bool {
    system_ftrylockfile(rawValue) == 0
  }

  /// Calls a closure with the stream locked,
  /// so that other threads' calls on it
  /// don't come between the closure's.
  ///
  /// - Parameter body: The closure to call.
  /// - Returns: What `body` returns.
  ///
  /// The corresponding C functions are `flockfile` and `funlockfile`.
  ///
  /// - Note: Not available on WASI.
  @_alwaysEmitIntoClient
  public func withLock<R>(_ body: () throws -> R) rethrows -> R {
    _lock()
    defer { _unlock() }
    return try body()
  }
}
#endif // !os(WASI)

#endif // !os(Windows)
