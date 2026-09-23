/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// Must import here to use the C flock type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// The C `flock` type, which describes an advisory lock
  /// on a range of a file's bytes.
  public typealias FileLock = flock
}

@available(System 199, *)
extension FileDescriptor {
  /// A description of an advisory lock on a range of a file's bytes.
  ///
  /// Most code places and removes locks with
  /// ``FileDescriptor/lock(_:byteRange:retryOnInterrupt:)``
  /// and ``FileDescriptor/unlock(byteRange:retryOnInterrupt:)``,
  /// which describe the lock for you.
  /// Use this type with the `fcntl` lock commands directly,
  /// such as to ask which lock would block one you'd like to place.
  ///
  /// The corresponding C type is `struct flock`.
  @frozen
  public struct FileLock: RawRepresentable, Sendable {
    /// The raw C lock description.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.FileLock

    /// Creates a strongly-typed lock description from a raw C lock description.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.FileLock) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.FileLock {
  /// Creates a description of a lock on a range of a file's bytes.
  ///
  /// - Parameters:
  ///   - kind: The kind of lock.
  ///   - start: The offset of the first byte in the range,
  ///     relative to `origin`.
  ///     The default is `0`.
  ///   - length: The number of bytes in the range,
  ///     or `0` for a range that extends to the end of the file,
  ///     however large the file grows.
  ///     The default is `0`.
  ///   - origin: The position that `start` is relative to.
  ///     The default is ``FileDescriptor/SeekOrigin/start``,
  ///     the beginning of the file.
  ///
  /// The description's ``processID`` is zero,
  /// as the open file description lock commands require.
  @_alwaysEmitIntoClient
  public init(
    kind: Kind,
    start: Int64 = 0,
    length: Int64 = 0,
    origin: FileDescriptor.SeekOrigin = .start
  ) {
    self.init(rawValue: CInterop.FileLock())
    self.kind = kind
    self.start = start
    self.length = length
    self.origin = origin
  }

  /// The kind of lock.
  ///
  /// The corresponding C field is `l_type`.
  @_alwaysEmitIntoClient
  public var kind: Kind {
    get { Kind(rawValue: rawValue.l_type) }
    set { rawValue.l_type = newValue.rawValue }
  }

  /// The position that ``start`` is relative to.
  ///
  /// The corresponding C field is `l_whence`.
  @_alwaysEmitIntoClient
  public var origin: FileDescriptor.SeekOrigin {
    get { FileDescriptor.SeekOrigin(rawValue: CInt(rawValue.l_whence)) }
    set { rawValue.l_whence = .init(truncatingIfNeeded: newValue.rawValue) }
  }

  /// The offset of the first byte in the range, relative to ``origin``.
  ///
  /// The corresponding C field is `l_start`.
  @_alwaysEmitIntoClient
  public var start: Int64 {
    get { Int64(rawValue.l_start) }
    set { rawValue.l_start = .init(newValue) }
  }

  /// The number of bytes in the range.
  ///
  /// A length of `0` means that the range extends to the end of the file,
  /// however large the file grows.
  ///
  /// The corresponding C field is `l_len`.
  @_alwaysEmitIntoClient
  public var length: Int64 {
    get { Int64(rawValue.l_len) }
    set { rawValue.l_len = .init(newValue) }
  }

  /// The process that holds a lock that a query found.
  ///
  /// A query for the lock that blocks another
  /// reports `-1` if an open file description lock
  /// or a whole-file lock blocks it,
  /// since those locks belong to an open file rather than to a process.
  /// When describing a lock to place, leave this zero.
  ///
  /// The corresponding C field is `l_pid`.
  @_alwaysEmitIntoClient
  public var processID: ProcessID {
    get { ProcessID(rawValue: rawValue.l_pid) }
    set { rawValue.l_pid = newValue.rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.FileLock {
  /// The kind of an advisory lock: a read lock, a write lock, or no lock.
  @frozen
  public struct Kind: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C lock type.
    @_alwaysEmitIntoClient
    public var rawValue: CShort

    /// Creates a strongly-typed lock kind from a raw C lock type.
    @_alwaysEmitIntoClient
    public init(rawValue: CShort) { self.rawValue = rawValue }

    /// A read lock, also known as a shared lock.
    ///
    /// Any number of open files can hold read locks
    /// on the same bytes at once,
    /// but none of them can while another holds a write lock there.
    /// Placing a read lock requires a file descriptor open for reading.
    ///
    /// The corresponding C constant is `F_RDLCK`.
    @_alwaysEmitIntoClient
    public static var read: Kind { Kind(rawValue: _F_RDLCK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "read")
    public static var F_RDLCK: Kind { read }

    /// A write lock, also known as an exclusive lock.
    ///
    /// While an open file holds a write lock on some bytes,
    /// no other open file can hold any lock on them.
    /// Placing a write lock requires a file descriptor open for writing.
    ///
    /// The corresponding C constant is `F_WRLCK`.
    @_alwaysEmitIntoClient
    public static var write: Kind { Kind(rawValue: _F_WRLCK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "write")
    public static var F_WRLCK: Kind { write }

    /// No lock.
    ///
    /// Placing a lock of this kind removes any lock on the range.
    /// A query that finds no lock in the way of the one described
    /// reports this kind.
    ///
    /// The corresponding C constant is `F_UNLCK`.
    @_alwaysEmitIntoClient
    public static var none: Kind { Kind(rawValue: _F_UNLCK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "none")
    public static var F_UNLCK: Kind { none }

    /// A shared lock, which is another name for ``read``.
    @_alwaysEmitIntoClient
    public static var shared: Kind { .read }

    /// An exclusive lock, which is another name for ``write``.
    @_alwaysEmitIntoClient
    public static var exclusive: Kind { .write }

    /// No lock, which is another name for ``none``.
    @_alwaysEmitIntoClient
    public static var unlock: Kind { .none }
  }
}

@available(System 199, *)
extension FileDescriptor.FileLock.Kind
  : CustomStringConvertible, CustomDebugStringConvertible
{
  /// A textual representation of the lock kind.
  @inline(never)
  public var description: String {
    switch self {
    case .read: return "read"
    case .write: return "write"
    case .none: return "none"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the lock kind, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - Open file description locks

// FreeBSD and OpenBSD have no open file description locks.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
@available(System 199, *)
extension FileDescriptor {
  /// Places an advisory lock on a range of the open file
  /// that this file descriptor refers to, if no other lock is in the way.
  ///
  /// - Parameters:
  ///   - kind: The kind of lock to place.
  ///     Passing ``FileLock/Kind/none`` removes the lock from the range
  ///     instead, like ``unlock(byteRange:retryOnInterrupt:)``.
  ///   - byteRange: The offsets of the bytes to lock.
  ///     A range without an upper bound, such as `100...`,
  ///     extends to the end of the file, however large the file grows.
  ///     An empty range locks nothing.
  ///     Omit this parameter to lock the whole file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if the lock was placed,
  ///   or `false` if another open file holds a lock that's in the way.
  ///
  /// This method doesn't wait for a lock that's in the way to be removed.
  /// To wait, call ``lock(_:byteRange:wait:retryOnInterrupt:)``.
  ///
  /// These are open file description locks.
  /// A lock belongs to the open file, rather than to this file descriptor
  /// or to the process, so descriptors duplicated from this one share it,
  /// and two opens of the same file exclude each other
  /// even within one process.
  /// The lock is released by ``unlock(byteRange:retryOnInterrupt:)``,
  /// or when the last descriptor for the open file is closed.
  /// Placing a lock on bytes that this open file has already locked
  /// replaces the lock on those bytes with the requested kind.
  ///
  /// Locks are advisory: they only exclude others that also lock the file.
  /// A read lock requires this file descriptor to be open for reading,
  /// and a write lock requires it to be open for writing;
  /// otherwise, this method throws ``Errno/badFileDescriptor``.
  ///
  /// These locks aren't the whole-file locks that
  /// ``lockWholeFile(shared:nonBlocking:retryOnInterrupt:)`` places.
  /// On Darwin the two kinds of lock conflict with each other;
  /// on Linux they're independent.
  ///
  /// The corresponding C function is `fcntl`, with the `F_OFD_SETLK` command.
  @_alwaysEmitIntoClient
  public func lock(
    _ kind: FileLock.Kind,
    byteRange: (some RangeExpression<Int64>)? = Range?.none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    guard let bounds = FileDescriptor._lockBounds(byteRange) else { return true }
    return try _lock(
      kind, start: bounds.start, length: bounds.length, command: _F_OFD_SETLK,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Places an advisory lock on a range of the open file
  /// that this file descriptor refers to,
  /// optionally waiting for other locks to get out of the way.
  ///
  /// - Parameters:
  ///   - kind: The kind of lock to place.
  ///     Passing ``FileLock/Kind/none`` removes the lock from the range
  ///     instead, like ``unlock(byteRange:retryOnInterrupt:)``.
  ///   - byteRange: The offsets of the bytes to lock.
  ///     A range without an upper bound, such as `100...`,
  ///     extends to the end of the file, however large the file grows.
  ///     An empty range locks nothing.
  ///     Omit this parameter to lock the whole file.
  ///   - wait: Whether to wait until no other open file holds a lock
  ///     that's in the way, rather than returning `false`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: `true` if the lock was placed,
  ///   or `false` if `wait` is `false`
  ///   and another open file holds a lock that's in the way.
  ///   When `wait` is `true`, the result is always `true`.
  ///
  /// The system doesn't detect deadlocks between open file description locks,
  /// so waiting for a lock that the same thread keeps from being released
  /// through another open file waits forever.
  ///
  /// For more about these locks,
  /// see ``lock(_:byteRange:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_OFD_SETLKW` command,
  /// or `F_OFD_SETLK` if `wait` is `false`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func lock(
    _ kind: FileLock.Kind,
    byteRange: (some RangeExpression<Int64>)? = Range?.none,
    wait: Bool,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    guard let bounds = FileDescriptor._lockBounds(byteRange) else { return true }
    return try _lock(
      kind, start: bounds.start, length: bounds.length,
      command: wait ? _F_OFD_SETLKW : _F_OFD_SETLK,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Removes the advisory lock from a range of the open file
  /// that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - byteRange: The offsets of the bytes to unlock.
  ///     A range without an upper bound, such as `100...`,
  ///     extends to the end of the file.
  ///     An empty range unlocks nothing.
  ///     Omit this parameter to unlock the whole file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Unlocking part of a locked range leaves the rest locked.
  /// Unlocking bytes that aren't locked isn't an error.
  ///
  /// For more about these locks,
  /// see ``lock(_:byteRange:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_OFD_SETLK` command
  /// and the `F_UNLCK` lock type.
  @_alwaysEmitIntoClient
  public func unlock(
    byteRange: (some RangeExpression<Int64>)? = Range?.none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    guard let bounds = FileDescriptor._lockBounds(byteRange) else { return }
    try _unlock(
      start: bounds.start, length: bounds.length, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  // Returns false if another lock is in the way.
  @usableFromInline
  internal func _lock(
    _ kind: FileLock.Kind,
    start: Int64,
    length: Int64,
    command: CInt,
    retryOnInterrupt: Bool
  ) -> Result<Bool, Errno> {
    var lock = FileLock(kind: kind, start: start, length: length)
    let result = nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      withUnsafeMutablePointer(to: &lock.rawValue) {
        system_fcntl(self.rawValue, command, $0)
      }
    }
    switch result {
    case .success:
      return .success(true)
    // Linux and Darwin report EAGAIN for a lock in the way, not EACCES.
    case .failure(.resourceTemporarilyUnavailable):
      return .success(false)
    case .failure(let error):
      return .failure(error)
    }
  }

  @usableFromInline
  internal func _unlock(
    start: Int64,
    length: Int64,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    var lock = FileLock(kind: .none, start: start, length: length)
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      withUnsafeMutablePointer(to: &lock.rawValue) {
        system_fcntl(self.rawValue, _F_OFD_SETLK, $0)
      }
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#if SYSTEM_PACKAGE_DARWIN
// Duration needs a newer OS than System 199 means in the default build,
// so this extension carries both.
extension FileDescriptor {
  /// Places an advisory lock on a range of the open file
  /// that this file descriptor refers to,
  /// waiting up to a time limit for other locks to get out of the way.
  ///
  /// - Parameters:
  ///   - kind: The kind of lock to place.
  ///     Passing ``FileLock/Kind/none`` removes the lock from the range
  ///     instead, like ``unlock(byteRange:retryOnInterrupt:)``.
  ///   - byteRange: The offsets of the bytes to lock.
  ///     A range without an upper bound, such as `100...`,
  ///     extends to the end of the file, however large the file grows.
  ///     An empty range locks nothing.
  ///     Omit this parameter to lock the whole file.
  ///   - timeout: The longest time to wait.
  ///     A timeout of zero or less doesn't wait.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///     A retried wait starts its timeout over.
  /// - Returns: `true` if the lock was placed,
  ///   or `false` if another open file still held a lock that's in the way
  ///   when the timeout ran out.
  ///
  /// For more about these locks,
  /// see ``lock(_:byteRange:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `fcntl`,
  /// with the `F_OFD_SETLKWTIMEOUT` command.
  /// - Note: Only available on Darwin.
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @_alwaysEmitIntoClient
  public func lock(
    _ kind: FileLock.Kind,
    byteRange: (some RangeExpression<Int64>)? = Range?.none,
    timeout: Duration,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    guard let bounds = FileDescriptor._lockBounds(byteRange) else { return true }
    // The kernel waits forever for a zero timeout, so don't pass one.
    guard timeout > .zero else {
      return try _lock(
        kind, start: bounds.start, length: bounds.length, command: _F_OFD_SETLK,
        retryOnInterrupt: retryOnInterrupt
      ).get()
    }
    let (seconds, attoseconds) = timeout.components
    return try _lock(
      kind, start: bounds.start, length: bounds.length,
      timeoutSeconds: Int(seconds),
      // Round a timeout under a nanosecond up, rather than down to zero.
      timeoutNanoseconds: max(Int(attoseconds / 1_000_000_000), seconds == 0 ? 1 : 0),
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  // Returns false if another lock is still in the way when the timeout runs out.
  @available(System 199, *)
  @usableFromInline
  internal func _lock(
    _ kind: FileLock.Kind,
    start: Int64,
    length: Int64,
    timeoutSeconds: Int,
    timeoutNanoseconds: Int,
    retryOnInterrupt: Bool
  ) -> Result<Bool, Errno> {
    var lock = flocktimeout(
      fl: FileLock(kind: kind, start: start, length: length).rawValue,
      timeout: timespec(tv_sec: timeoutSeconds, tv_nsec: timeoutNanoseconds))
    let result = nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      withUnsafeMutablePointer(to: &lock) {
        system_fcntl(self.rawValue, _F_OFD_SETLKWTIMEOUT, $0)
      }
    }
    switch result {
    case .success:
      return .success(true)
    case .failure(.timedOut), .failure(.resourceTemporarilyUnavailable):
      return .success(false)
    case .failure(let error):
      return .failure(error)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
@available(System 199, *)
extension FileDescriptor {
  // Maps a byte range to the start and length of a `struct flock`,
  // or to `nil` if the range is empty. A missing range, or a range without
  // an upper bound, has a length of 0, which means "to the end of the file".
  @_alwaysEmitIntoClient
  internal static func _lockBounds(
    _ byteRange: (some RangeExpression<Int64>)?
  ) -> (start: Int64, length: Int64)? {
    guard let byteRange else { return (start: 0, length: 0) }
    let range = byteRange.relative(to: Int64.min..<Int64.max)
    let start = range.lowerBound == .min ? 0 : range.lowerBound
    if range.upperBound == .max { return (start: start, length: 0) }
    guard start < range.upperBound else { return nil }
    return (start: start, length: range.upperBound - start)
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#endif // !os(Windows) && !os(WASI)
