/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// Whether a byte-range lock admits other holders.
  @frozen
  public enum LockMode: Sendable, Hashable, Codable {
    /// A shared, or read, lock.
    ///
    /// Other handles may take a shared lock on an overlapping range, and any
    /// process may read it.
    ///
    /// - Important: A shared lock denies write access to the range for every
    ///   process, including the one that took it. Writing through this handle
    ///   inside a shared ``Win32/FileHandle/withLock(byteRange:mode:_:)``
    ///   fails with ``Win32/Error/lockViolation``.
    ///
    /// The corresponding C value is a `dwFlags` without
    /// `LOCKFILE_EXCLUSIVE_LOCK`.
    case shared

    /// An exclusive, or write, lock.
    ///
    /// No other handle may lock an overlapping range, and reads and writes
    /// from other unrelated handles are denied. The locking handle and its
    /// duplicates in the same process may read and write freely, but a child
    /// process that inherits the handle may not.
    ///
    /// The corresponding C constant is `LOCKFILE_EXCLUSIVE_LOCK`.
    case exclusive
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Locks a byte range of the file, runs `body`, and unlocks the range.
  ///
  /// Acquires a lock for this handle. This call blocks while any handle holds
  /// a conflicting lock on an overlapping range, including the handle itself.
  /// Nesting this function with a conflicting lock will deadlock. See
  /// ``withLockIfAvailable(byteRange:mode:_:)``
  /// to fail instead of waiting.
  ///
  /// `byteRange` defaults to `0...`, which locks the whole file, including
  /// bytes appended while the lock is held. An empty range locks nothing and
  /// never calls `LockFileEx`, so `body` runs immediately. A negative bound
  /// throws ``Win32/Error/invalidParameter``. Byte `Int64.max` is not
  /// addressable, so a range closed at `Int64.max` ends one byte earlier.
  ///
  /// The range is unlocked when `body` returns or throws. If `body` succeeds
  /// but the unlock fails, the unlock error is thrown, discarding the result.
  /// If both fail, `body`'s error wins.
  ///
  /// Locking requires ``Win32/AccessMask/readData`` or
  /// ``Win32/AccessMask/writeData``, and fails with
  /// ``Win32/Error/invalidFunction`` on a pipe or a console.
  ///
  /// - Important: Windows byte-range locks are mandatory, not advisory.
  ///   Unlike POSIX `flock`, the system rejects conflicting reads and writes
  ///   by other processes whether or not they take locks themselves. Locks
  ///   aren't enforced on memory-mapped views.
  ///
  /// - Important: `UnlockFileEx` must name exactly the range that was
  ///   locked, and Windows locks don't split or coalesce, unlike POSIX
  ///   `fcntl` locks. This function unlocks the range it locked.
  ///
  /// The corresponding C functions are `LockFileEx` and `UnlockFileEx`.
  @_alwaysEmitIntoClient
  @available(*, noasync)
  public func withLock<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws(Win32.Error) -> R
  ) throws(Win32.Error) -> R {
    let handle = _handle
    let range = try Win32._lockRange(byteRange).get()
    guard !range.isEmpty else { return try body() }
    _ = try Win32._lockFile(
      handle, range, exclusive: mode == .exclusive, failImmediately: false
    ).get()
    let result = try Win32._unlockingIfThrows(handle, range, body)
    try Win32._unlockFile(handle, range).get()
    return result
  }

  /// Locks a byte range of the file, runs `body`, and unlocks the range.
  ///
  /// This overload is for a `body` that throws errors other than
  /// ``Win32/Error``. Otherwise, it behaves like the overload whose `body`
  /// throws `Win32.Error`, which Swift prefers where both apply.
  ///
  /// The corresponding C functions are `LockFileEx` and `UnlockFileEx`.
  @_alwaysEmitIntoClient
  @available(*, noasync)
  @_disfavoredOverload
  public func withLock<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws -> R
  ) throws -> R {
    let handle = _handle
    let range = try Win32._lockRange(byteRange).get()
    guard !range.isEmpty else { return try body() }
    _ = try Win32._lockFile(
      handle, range, exclusive: mode == .exclusive, failImmediately: false
    ).get()
    let result = try Win32._unlockingIfThrows(handle, range, body)
    try Win32._unlockFile(handle, range).get()
    return result
  }

  /// Locks a byte range of the file if it's available, runs `body`, and
  /// unlocks the range.
  ///
  /// Unlike ``withLock(byteRange:mode:_:)``,
  /// this never waits for another lock, so `async` code can call it. It
  /// returns `nil` only when a conflicting lock holds an overlapping range.
  ///
  /// - Returns: The value `body` returned, or `nil` if a conflicting lock
  ///   holds an overlapping range.
  ///
  /// The corresponding C functions are `LockFileEx` with
  /// `LOCKFILE_FAIL_IMMEDIATELY`, and `UnlockFileEx`.
  @_alwaysEmitIntoClient
  public func withLockIfAvailable<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws(Win32.Error) -> R
  ) throws(Win32.Error) -> R? {
    let handle = _handle
    let range = try Win32._lockRange(byteRange).get()
    guard !range.isEmpty else { return try body() }
    guard try Win32._lockFile(
      handle, range, exclusive: mode == .exclusive, failImmediately: true
    ).get() else {
      return nil
    }
    let result = try Win32._unlockingIfThrows(handle, range, body)
    try Win32._unlockFile(handle, range).get()
    return result
  }

  /// Locks a byte range of the file if it's available, runs `body`, and
  /// unlocks the range.
  ///
  /// This overload is for a `body` that throws errors other than
  /// ``Win32/Error``. Otherwise, it behaves like the overload whose `body`
  /// throws `Win32.Error`, which Swift prefers where both apply.
  ///
  /// The corresponding C functions are `LockFileEx` with
  /// `LOCKFILE_FAIL_IMMEDIATELY`, and `UnlockFileEx`.
  @_alwaysEmitIntoClient
  @_disfavoredOverload
  public func withLockIfAvailable<R: ~Copyable>(
    byteRange: some RangeExpression<Int64> = Int64.zero...,
    mode: Win32.LockMode = .exclusive,
    _ body: () throws -> R
  ) throws -> R? {
    let handle = _handle
    let range = try Win32._lockRange(byteRange).get()
    guard !range.isEmpty else { return try body() }
    guard try Win32._lockFile(
      handle, range, exclusive: mode == .exclusive, failImmediately: true
    ).get() else {
      return nil
    }
    let result = try Win32._unlockingIfThrows(handle, range, body)
    try Win32._unlockFile(handle, range).get()
    return result
  }
}

@available(System 199, *)
extension Win32 {
  /// The offsets a byte range can address, for resolving a range expression
  /// with `relative(to:)`.
  ///
  /// `index(after:)` saturates, so a range closed at `Int64.max` resolves to
  /// one that ends there rather than trapping on `Int64.max + 1`.
  internal struct _ByteOffsets: Collection {
    internal var startIndex: Int64 { 0 }
    internal var endIndex: Int64 { .max }
    internal func index(after i: Int64) -> Int64 { i == .max ? .max : i + 1 }
    internal subscript(position: Int64) -> Int64 { position }
  }

  /// Resolves `byteRange` to the range of bytes to lock.
  @usableFromInline
  internal static func _lockRange(
    _ byteRange: some RangeExpression<Int64>
  ) -> Result<Range<Int64>, Win32.Error> {
    // `relative(to:)` traps, rather than returning a range to reject, for
    // these two with a negative upper bound.
    if let range = byteRange as? PartialRangeUpTo<Int64>, range.upperBound < 0 {
      return .failure(.invalidParameter)
    }
    if let range = byteRange as? PartialRangeThrough<Int64>, range.upperBound < 0 {
      return .failure(.invalidParameter)
    }
    let range = byteRange.relative(to: _ByteOffsets())
    guard range.lowerBound >= 0 else { return .failure(.invalidParameter) }
    return .success(range)
  }

  internal static func _overlapped(for range: Range<Int64>) -> OVERLAPPED {
    _overlapped(offset: range.lowerBound)
  }

  /// Locks `range`, returning `false` if `failImmediately` and a conflicting
  /// lock holds an overlapping range.
  @usableFromInline
  internal static func _lockFile(
    _ handle: HANDLE, _ range: Range<Int64>, exclusive: Bool, failImmediately: Bool
  ) -> Result<Bool, Win32.Error> {
    var flags: DWORD = 0
    if exclusive { flags |= _LOCKFILE_EXCLUSIVE_LOCK }
    if failImmediately { flags |= _LOCKFILE_FAIL_IMMEDIATELY }
    // A range ends at or below Int64.max, so ERROR_INVALID_LOCK_RANGE is
    // unreachable.
    let length = UInt64(range.upperBound - range.lowerBound)
    var overlapped = _overlapped(for: range)
    guard system_LockFileEx(
      handle, flags, 0, DWORD(truncatingIfNeeded: length),
      DWORD(truncatingIfNeeded: length >> 32), &overlapped
    ) else {
      let error = Win32.Error(GetLastError())
      if failImmediately && error == Win32.Error.lockViolation { return .success(false) }
      return .failure(error)
    }
    return .success(true)
  }

  @usableFromInline
  internal static func _unlockFile(
    _ handle: HANDLE, _ range: Range<Int64>
  ) -> Result<Void, Win32.Error> {
    let length = UInt64(range.upperBound - range.lowerBound)
    var overlapped = _overlapped(for: range)
    guard system_UnlockFileEx(
      handle, 0, DWORD(truncatingIfNeeded: length),
      DWORD(truncatingIfNeeded: length >> 32), &overlapped
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  /// Runs `body`, unlocking `range` if it throws. `body`'s error wins over
  /// the unlock's.
  @_alwaysEmitIntoClient
  internal static func _unlockingIfThrows<R: ~Copyable, E: Swift.Error>(
    _ handle: HANDLE, _ range: Range<Int64>, _ body: () throws(E) -> R
  ) throws(E) -> R {
    do throws(E) {
      return try body()
    } catch {
      _ = _unlockFile(handle, range)
      throw error
    }
  }
}

#endif // os(Windows)
