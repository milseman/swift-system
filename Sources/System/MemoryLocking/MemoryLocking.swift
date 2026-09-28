/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Any memory

@available(System 199, *)
extension Memory {
  /// Locks the pages that hold a buffer in physical memory,
  /// so that the system doesn't page them out.
  ///
  /// - Parameter buffer: The memory to lock.
  ///   The system locks every page the buffer touches.
  ///
  /// Locking a page brings it into memory if it isn't there,
  /// so locking a large region takes time and memory at once.
  /// A page stays locked until ``unlockPages(_:)`` unlocks it,
  /// or it's unmapped, or the process ends;
  /// locks don't nest, so one unlock undoes any number of locks.
  /// A child process doesn't inherit the locks.
  ///
  /// This method throws ``Errno/noMemory`` for memory that isn't mapped,
  /// or when the process would lock more than its
  /// `RLIMIT_MEMLOCK` resource limit allows,
  /// and ``Errno/resourceTemporarilyUnavailable`` when the system can't
  /// lock that much memory now.
  ///
  /// The corresponding C function is `mlock`.
  @_alwaysEmitIntoClient
  public static func lockPages(_ buffer: UnsafeRawBufferPointer) throws(Errno) {
    try _lockPages(buffer.baseAddress, buffer.count).get()
  }

  @usableFromInline
  internal static func _lockPages(_ start: UnsafeRawPointer?, _ count: Int) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_mlock(start, count) }
  }

  /// Unlocks the pages that hold a buffer,
  /// so that the system can page them out again.
  ///
  /// - Parameter buffer: The memory to unlock.
  ///   The system unlocks every page the buffer touches.
  ///
  /// Unlocking a page that isn't locked does nothing.
  /// The pages stay in memory until the system needs them.
  ///
  /// The corresponding C function is `munlock`.
  @_alwaysEmitIntoClient
  public static func unlockPages(_ buffer: UnsafeRawBufferPointer) throws(Errno) {
    try _unlockPages(buffer.baseAddress, buffer.count).get()
  }

  @usableFromInline
  internal static func _unlockPages(_ start: UnsafeRawPointer?, _ count: Int) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_munlock(start, count) }
  }
}

// MARK: - All of a process's memory

#if !SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension Memory {
  /// Which of the process's pages ``lockAllPages(_:)`` locks.
  ///
  /// - Note: Not available on Darwin, whose `mlockall` always fails.
  @frozen
  public struct PageLockOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed options value from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The pages that are mapped now.
    ///
    /// The corresponding C constant is `MCL_CURRENT`.
    @_alwaysEmitIntoClient
    public static var current: PageLockOptions { PageLockOptions(rawValue: _MCL_CURRENT) }

    /// The pages that are mapped from now on,
    /// such as by the heap and stacks growing.
    ///
    /// A mapping that would exceed the process's `RLIMIT_MEMLOCK`
    /// resource limit then fails.
    ///
    /// The corresponding C constant is `MCL_FUTURE`.
    @_alwaysEmitIntoClient
    public static var future: PageLockOptions { PageLockOptions(rawValue: _MCL_FUTURE) }

    #if os(Linux) || os(Android)
    /// Locks each page as it's first touched,
    /// rather than bringing every page into memory at once.
    ///
    /// Combine it with ``current``, ``future``, or both.
    ///
    /// The corresponding C constant is `MCL_ONFAULT`.
    ///
    /// - Note: Only available on Linux and Android, from Linux 4.4.
    @_alwaysEmitIntoClient
    public static var onFault: PageLockOptions { PageLockOptions(rawValue: _MCL_ONFAULT) }
    #endif
  }

  /// Locks all of the process's pages in physical memory:
  /// those mapped now, those mapped later, or both.
  ///
  /// - Parameter options: Which pages to lock.
  ///
  /// See ``lockPages(_:)``.
  /// A process usually needs privileges, or a high enough
  /// `RLIMIT_MEMLOCK` resource limit, to lock all its pages;
  /// without them, this method throws ``Errno/noMemory`` or
  /// ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `mlockall`.
  ///
  /// - Note: Not available on Darwin, whose `mlockall` always fails
  ///   with ``Errno/noFunction``.
  @_alwaysEmitIntoClient
  public static func lockAllPages(_ options: PageLockOptions) throws(Errno) {
    try _lockAllPages(options).get()
  }

  @usableFromInline
  internal static func _lockAllPages(_ options: PageLockOptions) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_mlockall(options.rawValue) }
  }

  /// Unlocks all of the process's pages,
  /// and stops locking the pages it maps later.
  ///
  /// The corresponding C function is `munlockall`.
  ///
  /// - Note: Not available on Darwin, whose `munlockall` always fails
  ///   with ``Errno/noFunction``.
  @_alwaysEmitIntoClient
  public static func unlockAllPages() throws(Errno) {
    try _unlockAllPages().get()
  }

  @usableFromInline
  internal static func _unlockAllPages() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_munlockall() }
  }
}
#endif // !SYSTEM_PACKAGE_DARWIN

// MARK: - A mapping's memory

@available(System 199, *)
extension MemoryMapping {
  /// Locks the mapping's pages in physical memory,
  /// so that the system doesn't page them out.
  ///
  /// - Parameters:
  ///   - range: The bytes to lock, as offsets into the mapping;
  ///     the system locks every page they touch.
  ///     The default is the whole mapping.
  ///
  /// Unmapping the mapping unlocks its pages.
  /// See ``Memory/lockPages(_:)``.
  ///
  /// The corresponding C function is `mlock`.
  @_alwaysEmitIntoClient
  public func lockPages(range: Range<Int>? = nil) throws(Errno) {
    try _lockPages(range: range).get()
  }

  @usableFromInline
  internal func _lockPages(range: Range<Int>?) -> Result<(), Errno> {
    let (start, length) = _region(range)
    return Memory._lockPages(start, length)
  }

  /// Unlocks the mapping's pages,
  /// so that the system can page them out again.
  ///
  /// - Parameters:
  ///   - range: The bytes to unlock, as offsets into the mapping;
  ///     the system unlocks every page they touch.
  ///     The default is the whole mapping.
  ///
  /// The corresponding C function is `munlock`.
  @_alwaysEmitIntoClient
  public func unlockPages(range: Range<Int>? = nil) throws(Errno) {
    try _unlockPages(range: range).get()
  }

  @usableFromInline
  internal func _unlockPages(range: Range<Int>?) -> Result<(), Errno> {
    let (start, length) = _region(range)
    return Memory._unlockPages(start, length)
  }
}

#endif // !os(Windows) && !os(WASI)
