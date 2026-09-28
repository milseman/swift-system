/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned memory mapping, on the pattern of OwnedFD, whose
// deinit drops errors from unmapping. See Prototype/PosixMore.

#if !os(Windows) && !os(WASI)

/// A region of the process's memory that the system maps to part of a file,
/// or to memory of its own, which this value owns.
///
/// Map a file to read it without copying it into a buffer:
///
///     let size = Int(try fd.stat().size)
///     let mapping = try MemoryMapping(file: fd, byteCount: size)
///     let bytes = mapping.bytes
///
/// A mapping unmaps its memory at the end of its lifetime,
/// ignoring any error, or when you call ``unmap()``, which reports one.
/// Its address never moves, so its spans are valid for its lifetime.
///
/// Mapped memory has hazards that no type can remove:
/// - Another process can change a file's shared mapping at any time,
///   including while you read a span of it.
/// - Reading or writing a page past the end of the file,
///   such as after another process truncates it, raises `SIGBUS`,
///   which ends the process.
/// - Writing to memory whose protection doesn't allow it,
///   through ``mutableBytes`` or otherwise, crashes the process:
///   nothing checks the protection first.
///
/// The corresponding C function is `mmap`.
@frozen
@available(System 199, *)
public struct MemoryMapping: ~Copyable, @unchecked Sendable {
  @usableFromInline
  internal let _start: UnsafeMutableRawPointer

  @usableFromInline
  internal let _byteCount: Int

  /// Takes ownership of a region that `mmap` mapped.
  ///
  /// The region is unmapped at the end of the mapping's lifetime,
  /// so nothing else may unmap it.
  /// Unmapping memory that `mmap` didn't map, or that something else
  /// still uses, is undefined behavior.
  @_alwaysEmitIntoClient
  public init(unsafeTaking start: UnsafeMutableRawPointer, byteCount: Int) {
    self._start = start
    self._byteCount = byteCount
  }

  deinit {
    // deinit can't throw, so an error from unmapping is dropped here,
    // as OwnedFD's deinit drops one from closing.
    _ = system_munmap(_start, _byteCount)
  }
}

// MARK: - Options

@available(System 199, *)
extension MemoryMapping {
  /// What a mapping's memory allows: reading, writing, executing,
  /// or none of them.
  @frozen
  public struct Protection: OptionSet, Hashable, Sendable {
    /// The raw C protection.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed protection from a raw C protection.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The memory can be read.
    ///
    /// The corresponding C constant is `PROT_READ`.
    @_alwaysEmitIntoClient
    public static var read: Protection { Protection(rawValue: _PROT_READ) }

    /// The memory can be written.
    ///
    /// The corresponding C constant is `PROT_WRITE`.
    @_alwaysEmitIntoClient
    public static var write: Protection { Protection(rawValue: _PROT_WRITE) }

    /// The memory can be executed.
    ///
    /// The corresponding C constant is `PROT_EXEC`.
    @_alwaysEmitIntoClient
    public static var execute: Protection { Protection(rawValue: _PROT_EXEC) }
  }

  /// Options for a mapping.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Writes through the mapping change the file,
    /// and other processes that map the file share them.
    ///
    /// Exactly one of `shared` and ``private`` is required.
    ///
    /// The corresponding C constant is `MAP_SHARED`.
    @_alwaysEmitIntoClient
    public static var shared: Options { Options(rawValue: _MAP_SHARED) }

    /// Writes through the mapping stay in this process's copy of the pages,
    /// and don't change the file.
    ///
    /// Exactly one of ``shared`` and `private` is required.
    ///
    /// The corresponding C constant is `MAP_PRIVATE`.
    @_alwaysEmitIntoClient
    public static var `private`: Options { Options(rawValue: _MAP_PRIVATE) }

    #if os(Linux) || os(Android)
    /// Doesn't reserve swap space for the mapping,
    /// so that writing to it can fail when memory runs short.
    ///
    /// The corresponding C constant is `MAP_NORESERVE`.
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var noReserve: Options { Options(rawValue: _MAP_NORESERVE) }

    /// Reads the mapping's pages in as it's made,
    /// rather than as they're first used.
    ///
    /// The corresponding C constant is `MAP_POPULATE`.
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var populate: Options { Options(rawValue: _MAP_POPULATE) }
    #endif
  }

  /// How you'll use a mapping's memory, which lets the system
  /// read ahead, or free pages, accordingly.
  @frozen
  public struct Advice: RawRepresentable, Hashable, Sendable {
    /// The raw C advice.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed advice from a raw C advice.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// No particular use, which is the default.
    ///
    /// The corresponding C constant is `MADV_NORMAL`.
    @_alwaysEmitIntoClient
    public static var normal: Advice { Advice(rawValue: _MADV_NORMAL) }

    /// Use in no particular order, so reading ahead would be wasted.
    ///
    /// The corresponding C constant is `MADV_RANDOM`.
    @_alwaysEmitIntoClient
    public static var random: Advice { Advice(rawValue: _MADV_RANDOM) }

    /// Use from start to end, so the system can read ahead,
    /// and free pages after they're used.
    ///
    /// The corresponding C constant is `MADV_SEQUENTIAL`.
    @_alwaysEmitIntoClient
    public static var sequential: Advice { Advice(rawValue: _MADV_SEQUENTIAL) }

    /// Use soon, so the system can start reading the pages in.
    ///
    /// The corresponding C constant is `MADV_WILLNEED`.
    @_alwaysEmitIntoClient
    public static var willNeed: Advice { Advice(rawValue: _MADV_WILLNEED) }

    /// No use soon.
    ///
    /// What the system does differs by platform:
    /// Linux discards the pages of a private mapping at once,
    /// so that reading them again reads the file, or zeros,
    /// and Darwin and the BSDs treat this as a hint that
    /// keeps the pages' contents.
    ///
    /// The corresponding C constant is `MADV_DONTNEED`.
    @_alwaysEmitIntoClient
    public static var doNotNeed: Advice { Advice(rawValue: _MADV_DONTNEED) }

    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
    /// The pages' contents aren't needed, so the system can free the pages
    /// when it wants memory, and gives zeros for any it freed.
    ///
    /// The corresponding C constant is `MADV_FREE`.
    /// - Note: Not available on OpenBSD.
    @_alwaysEmitIntoClient
    public static var free: Advice { Advice(rawValue: _MADV_FREE) }
    #endif
  }
}

// MARK: - Mapping

@available(System 199, *)
extension MemoryMapping {
  /// Maps memory that no file backs, which starts out filled with zeros.
  ///
  /// - Parameters:
  ///   - byteCount: The size of the mapping, which the system rounds up
  ///     to a whole number of pages. It can't be zero.
  ///   - protection: What the memory allows. The default is `[.read, .write]`.
  ///   - options: Options for the mapping. The default is `.private`;
  ///     with `.shared`, child processes created with `fork` share it.
  ///
  /// The corresponding C function is `mmap`, with `MAP_ANON`.
  @_alwaysEmitIntoClient
  public init(
    byteCount: Int,
    protection: Protection = [.read, .write],
    options: Options = .private
  ) throws(Errno) {
    let start = try MemoryMapping._map(
      byteCount: byteCount, protection: protection,
      flags: options.rawValue | _MAP_ANON, fd: -1, offset: 0
    ).get()
    self.init(unsafeTaking: start, byteCount: byteCount)
  }

  /// Maps part of a file.
  ///
  /// - Parameters:
  ///   - fd: A descriptor open on the file, with access that allows
  ///     `protection`, such as ``FileDescriptor/AccessMode/readWrite``
  ///     for a shared mapping that can be written.
  ///     The mapping doesn't need the descriptor to stay open.
  ///   - offset: Where in the file the mapping starts,
  ///     which must be a multiple of the page size. The default is zero.
  ///   - byteCount: The size of the mapping. It can't be zero,
  ///     and it can be larger than the file,
  ///     though using a page wholly past the file's end raises `SIGBUS`.
  ///   - protection: What the memory allows. The default is `.read`.
  ///   - options: Options for the mapping. The default is `.shared`.
  ///
  /// The corresponding C function is `mmap`.
  @_alwaysEmitIntoClient
  public init(
    file fd: FileDescriptor,
    offset: Int64 = 0,
    byteCount: Int,
    protection: Protection = .read,
    options: Options = .shared
  ) throws(Errno) {
    let start = try MemoryMapping._map(
      byteCount: byteCount, protection: protection,
      flags: options.rawValue, fd: fd.rawValue, offset: offset
    ).get()
    self.init(unsafeTaking: start, byteCount: byteCount)
  }

  @usableFromInline
  internal static func _map(
    byteCount: Int, protection: Protection, flags: CInt, fd: CInt, offset: Int64
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    // A zero length is EINVAL on every platform, but checking first keeps
    // a mocked call from succeeding with it.
    guard byteCount > 0 else { return .failure(.invalidArgument) }
    guard let start = system_mmap(byteCount, protection.rawValue, flags, fd, _COffT(offset)) else {
      return .failure(.current)
    }
    return .success(start)
  }

  /// The size of the mapping, in bytes.
  @_alwaysEmitIntoClient
  public var byteCount: Int { _byteCount }

  /// The mapping's memory, for calls that `MemoryMapping` doesn't provide.
  ///
  /// The buffer is valid only while this mapping is alive:
  /// don't unmap it, and don't keep it.
  /// To take ownership of it, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var unsafeBuffer: UnsafeMutableRawBufferPointer {
    UnsafeMutableRawBufferPointer(start: _start, count: _byteCount)
  }

  /// Unmaps the memory.
  ///
  /// The memory isn't unmapped again, whether this method returns or throws.
  ///
  /// The corresponding C function is `munmap`.
  @_alwaysEmitIntoClient
  public consuming func unmap() throws(Errno) {
    let (start, byteCount) = (_start, _byteCount)
    discard self
    try MemoryMapping._unmap(start, byteCount).get()
  }

  @usableFromInline
  internal static func _unmap(_ start: UnsafeMutableRawPointer, _ byteCount: Int) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_munmap(start, byteCount) }
  }

  /// Transfers ownership of the memory to the caller, without unmapping it.
  ///
  /// After this method returns, the caller is responsible for unmapping
  /// the memory with `munmap`.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> UnsafeMutableRawBufferPointer {
    let buffer = unsafeBuffer
    discard self
    return buffer
  }
}

// MARK: - Spans

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension MemoryMapping {
  /// The mapping's memory, to read.
  ///
  /// The mapping must allow reading.
  @_alwaysEmitIntoClient
  public var bytes: RawSpan {
    @_lifetime(borrow self)
    borrowing get {
      let span = RawSpan(_unsafeStart: _start, byteCount: _byteCount)
      return _overrideLifetime(span, borrowing: self)
    }
  }

  /// The mapping's memory, to read and write.
  ///
  /// The mapping must allow reading and writing: writing to memory that
  /// doesn't allow it crashes the process.
  @_alwaysEmitIntoClient
  public var mutableBytes: MutableRawSpan {
    @_lifetime(&self)
    mutating get {
      let span = MutableRawSpan(_unsafeStart: _start, byteCount: _byteCount)
      return _overrideLifetime(span, mutating: &self)
    }
  }
}

// MARK: - Operations

@available(System 199, *)
extension MemoryMapping {
  /// Changes what the mapping's memory allows.
  ///
  /// - Parameters:
  ///   - protection: What the memory should allow.
  ///   - range: The bytes to change, as offsets into the mapping,
  ///     starting at a multiple of the page size;
  ///     the system rounds the end up to a page.
  ///     The default is the whole mapping.
  ///
  /// A mapping of a file can't allow more than the file's descriptor did:
  /// making a shared mapping of a file opened read-only writable
  /// throws ``Errno/permissionDenied``.
  ///
  /// The corresponding C function is `mprotect`.
  @_alwaysEmitIntoClient
  public func setProtection(_ protection: Protection, range: Range<Int>? = nil) throws(Errno) {
    try _setProtection(protection, range: range).get()
  }

  @usableFromInline
  internal func _setProtection(_ protection: Protection, range: Range<Int>?) -> Result<(), Errno> {
    let (start, length) = _region(range)
    return nothingOrErrno(retryOnInterrupt: false) {
      system_mprotect(start, length, protection.rawValue)
    }
  }

  /// Writes the changes to a shared mapping of a file to the file.
  ///
  /// - Parameters:
  ///   - asynchronously: Whether to start writing and return,
  ///     rather than wait until the writes finish.
  ///     The default is `false`.
  ///   - invalidatingCaches: Whether to discard other mappings'
  ///     cached copies of the pages, so that they read what's in the file.
  ///     The default is `false`.
  ///   - range: The bytes to write, as offsets into the mapping,
  ///     starting at a multiple of the page size.
  ///     The default is the whole mapping.
  ///
  /// Like `write`, this hands the data to the file system,
  /// which can still keep it in a cache:
  /// to make it durable, call
  /// ``FileDescriptor/synchronize(retryOnInterrupt:)`` afterward.
  ///
  /// The corresponding C function is `msync`.
  @_alwaysEmitIntoClient
  public func synchronize(
    asynchronously: Bool = false,
    invalidatingCaches: Bool = false,
    range: Range<Int>? = nil
  ) throws(Errno) {
    try _synchronize(
      asynchronously: asynchronously, invalidatingCaches: invalidatingCaches, range: range
    ).get()
  }

  @usableFromInline
  internal func _synchronize(
    asynchronously: Bool, invalidatingCaches: Bool, range: Range<Int>?
  ) -> Result<(), Errno> {
    let (start, length) = _region(range)
    var flags = asynchronously ? _MS_ASYNC : _MS_SYNC
    if invalidatingCaches { flags |= _MS_INVALIDATE }
    return nothingOrErrno(retryOnInterrupt: false) {
      system_msync(start, length, flags)
    }
  }

  /// Tells the system how you'll use the mapping's memory.
  ///
  /// - Parameters:
  ///   - advice: How you'll use the memory.
  ///   - range: The bytes the advice is for, as offsets into the mapping,
  ///     starting at a multiple of the page size,
  ///     which Linux requires and Darwin rounds down to.
  ///     The default is the whole mapping.
  ///
  /// The corresponding C function is `madvise`.
  @_alwaysEmitIntoClient
  public func advise(_ advice: Advice, range: Range<Int>? = nil) throws(Errno) {
    try _advise(advice, range: range).get()
  }

  @usableFromInline
  internal func _advise(_ advice: Advice, range: Range<Int>?) -> Result<(), Errno> {
    let (start, length) = _region(range)
    return nothingOrErrno(retryOnInterrupt: false) {
      system_madvise(start, length, advice.rawValue)
    }
  }

  #if !os(OpenBSD)
  /// Returns whether each of the mapping's pages is in memory.
  ///
  /// - Returns: An element for each page, `true` if it's in memory,
  ///   which reading it wouldn't need to wait for.
  ///
  /// The answer can be out of date by the time this method returns.
  ///
  /// The corresponding C function is `mincore`.
  /// - Note: Not available on OpenBSD.
  @_alwaysEmitIntoClient
  public func residentPages() throws(Errno) -> [Bool] {
    try _residentPages().get()
  }

  @usableFromInline
  internal func _residentPages() -> Result<[Bool], Errno> {
    let pageSize: Int
    switch SystemConfig._value(.pageSize) {
    case .success(let size?): pageSize = size
    case .success(nil): return .failure(.invalidArgument)
    case .failure(let error): return .failure(error)
    }
    let pages = (_byteCount + pageSize - 1) / pageSize
    var vector = [UInt8](repeating: 0, count: pages)
    let result = vector.withUnsafeMutableBytes { vector in
      nothingOrErrno(retryOnInterrupt: false) {
        system_mincore(_start, _byteCount, vector.baseAddress!)
      }
    }
    // The low bit says whether the page is in memory; Darwin uses
    // the others for more.
    return result.map { vector.map { $0 & 1 != 0 } }
  }
  #endif

  /// The start and length of `range` of the mapping, which must be inside it.
  @usableFromInline
  internal func _region(_ range: Range<Int>?) -> (UnsafeMutableRawPointer, Int) {
    guard let range else { return (_start, _byteCount) }
    precondition(
      range.lowerBound >= 0 && range.upperBound <= _byteCount,
      "range isn't inside the mapping")
    return (_start + range.lowerBound, range.count)
  }
}

#endif // !os(Windows) && !os(WASI)
