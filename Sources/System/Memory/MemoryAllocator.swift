/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

#if os(Linux) && canImport(Glibc)
import CSystem
import Glibc
#endif

// MARK: - Block sizes

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
@available(System 199, *)
extension Memory {
  /// Returns the number of bytes in a block,
  /// which can be more than were asked for.
  ///
  /// - Parameter pointer: The start of a block that the C allocator allocated.
  /// - Returns: The block's size, in bytes.
  ///
  /// On Darwin, memory that no zone allocated has a size of zero;
  /// elsewhere, asking about it is undefined behavior.
  ///
  /// The block's bytes past the size you asked for are there to use,
  /// but tools that check memory use, such as the Address Sanitizer,
  /// may report it; to use them, reallocate to the size this returns.
  ///
  /// The corresponding C function is `malloc_size` on Darwin,
  /// and `malloc_usable_size` elsewhere.
  /// - Note: Not available on OpenBSD.
  @_alwaysEmitIntoClient
  public static func usableSize(of pointer: UnsafeRawPointer) -> Int {
    _usableSize(of: pointer)
  }

  @usableFromInline
  internal static func _usableSize(of pointer: UnsafeRawPointer) -> Int {
    #if SYSTEM_PACKAGE_DARWIN
    system_malloc_size(pointer)
    #else
    system_malloc_usable_size(pointer)
    #endif
  }
}
#endif

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension Memory {
  /// Returns the size of the block that the allocator would allocate
  /// for a request, which uses the whole block.
  ///
  /// - Parameter byteCount: The number of bytes to ask for,
  ///   which can't be negative.
  /// - Returns: The request, rounded up to the size of a block.
  ///
  /// Asking for this size, rather than `byteCount`, wastes nothing,
  /// as when choosing how much a buffer should grow by.
  ///
  /// The corresponding C function is `malloc_good_size`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func goodSize(for byteCount: Int) -> Int {
    _goodSize(for: byteCount)
  }

  @usableFromInline
  internal static func _goodSize(for byteCount: Int) -> Int {
    precondition(byteCount >= 0, "byteCount can't be negative")
    return system_malloc_good_size(byteCount)
  }
}
#endif

// MARK: - glibc's allocator

#if os(Linux) && canImport(Glibc)
@available(System 199, *)
extension Memory {
  /// Returns free memory at the top of the heap,
  /// and in free pages elsewhere, to the system.
  ///
  /// - Parameter padding: The number of free bytes to keep
  ///   at the top of the heap, which can't be negative.
  ///   The default is zero.
  /// - Returns: Whether any memory was returned.
  ///
  /// The corresponding C function is `malloc_trim`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func trim(padding: Int = 0) -> Bool {
    _trim(padding: padding)
  }

  @usableFromInline
  internal static func _trim(padding: Int) -> Bool {
    precondition(padding >= 0, "padding can't be negative")
    return system_malloc_trim(padding) != 0
  }

  /// A setting of glibc's allocator.
  ///
  /// - Note: Only available on Linux with glibc.
  @frozen
  public struct AllocatorOption: RawRepresentable, Hashable, Sendable {
    /// The raw C parameter.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed option from a raw C parameter.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The largest request, in bytes, that the allocator serves
    /// from its fast bins.
    ///
    /// The corresponding C constant is `M_MXFAST`.
    @_alwaysEmitIntoClient
    public static var maxFastSize: Self { Self(rawValue: _M_MXFAST) }

    /// How many free bytes at the top of the heap
    /// make the allocator return them to the system.
    ///
    /// The corresponding C constant is `M_TRIM_THRESHOLD`.
    @_alwaysEmitIntoClient
    public static var trimThreshold: Self { Self(rawValue: _M_TRIM_THRESHOLD) }

    /// How many bytes more than it needs the allocator asks
    /// the system for as the heap grows.
    ///
    /// The corresponding C constant is `M_TOP_PAD`.
    @_alwaysEmitIntoClient
    public static var topPadding: Self { Self(rawValue: _M_TOP_PAD) }

    /// The smallest request, in bytes, that the allocator serves
    /// with a memory mapping of its own.
    ///
    /// The corresponding C constant is `M_MMAP_THRESHOLD`.
    @_alwaysEmitIntoClient
    public static var mappingThreshold: Self { Self(rawValue: _M_MMAP_THRESHOLD) }

    /// The most requests that the allocator serves with memory mappings
    /// of their own at once.
    ///
    /// The corresponding C constant is `M_MMAP_MAX`.
    @_alwaysEmitIntoClient
    public static var maxMappings: Self { Self(rawValue: _M_MMAP_MAX) }

    /// What the allocator does when it finds a heap inconsistency.
    ///
    /// The corresponding C constant is `M_CHECK_ACTION`.
    @_alwaysEmitIntoClient
    public static var checkAction: Self { Self(rawValue: _M_CHECK_ACTION) }

    /// A byte, other than zero, that the allocator fills
    /// new and freed blocks with, to expose their misuse.
    ///
    /// The corresponding C constant is `M_PERTURB`.
    @_alwaysEmitIntoClient
    public static var perturbByte: Self { Self(rawValue: _M_PERTURB) }

    /// How many arenas the allocator creates
    /// before it checks ``maxArenas``.
    ///
    /// The corresponding C constant is `M_ARENA_TEST`.
    @_alwaysEmitIntoClient
    public static var arenaTest: Self { Self(rawValue: _M_ARENA_TEST) }

    /// The most arenas the allocator creates for threads.
    ///
    /// The corresponding C constant is `M_ARENA_MAX`.
    @_alwaysEmitIntoClient
    public static var maxArenas: Self { Self(rawValue: _M_ARENA_MAX) }
  }

  /// Sets a setting of glibc's allocator.
  ///
  /// - Parameters:
  ///   - option: The setting.
  ///   - value: Its new value.
  ///
  /// A setting or value that glibc rejects throws
  /// ``Errno/invalidArgument``; `mallopt` reports no error of its own.
  ///
  /// The corresponding C function is `mallopt`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static func setAllocatorOption(_ option: AllocatorOption, to value: Int) throws(Errno) {
    try _setAllocatorOption(option, to: value).get()
  }

  @usableFromInline
  internal static func _setAllocatorOption(_ option: AllocatorOption, to value: Int) -> Result<(), Errno> {
    guard let value = CInt(exactly: value), system_mallopt(option.rawValue, value) != 0 else {
      return .failure(.invalidArgument)
    }
    return .success(())
  }

  /// glibc's allocator's use of memory, in all its arenas.
  ///
  /// The corresponding C type is `struct mallinfo2`.
  /// - Note: Only available on Linux with glibc.
  @frozen
  public struct AllocatorStatistics: Hashable, Sendable {
    /// The bytes the allocator has from the system, other than in
    /// memory mappings of its own.
    public var arenaBytes: Int

    /// The number of free chunks.
    public var freeChunks: Int

    /// The number of free chunks in fast bins.
    public var freeFastBinChunks: Int

    /// The number of memory mappings of their own that blocks use.
    public var mappings: Int

    /// The bytes in memory mappings of their own that blocks use.
    public var mappedBytes: Int

    /// The bytes in free chunks in fast bins.
    public var freeFastBinBytes: Int

    /// The bytes in blocks in use.
    public var bytesInUse: Int

    /// The bytes in free chunks.
    public var freeBytes: Int

    /// The free bytes at the top of the heap that trimming could release.
    public var releasableBytes: Int

    /// Creates statistics with the given values.
    @_alwaysEmitIntoClient
    public init(
      arenaBytes: Int, freeChunks: Int, freeFastBinChunks: Int, mappings: Int,
      mappedBytes: Int, freeFastBinBytes: Int, bytesInUse: Int, freeBytes: Int,
      releasableBytes: Int
    ) {
      self.arenaBytes = arenaBytes
      self.freeChunks = freeChunks
      self.freeFastBinChunks = freeFastBinChunks
      self.mappings = mappings
      self.mappedBytes = mappedBytes
      self.freeFastBinBytes = freeFastBinBytes
      self.bytesInUse = bytesInUse
      self.freeBytes = freeBytes
      self.releasableBytes = releasableBytes
    }
  }

  /// Returns glibc's allocator's use of memory.
  ///
  /// Before glibc 2.33, which added `mallinfo2`, this reads `mallinfo`,
  /// whose counts wrap around at 4 GB.
  ///
  /// The corresponding C function is `mallinfo2`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static func allocatorStatistics() -> AllocatorStatistics {
    _allocatorStatistics()
  }

  @usableFromInline
  internal static func _allocatorStatistics() -> AllocatorStatistics {
    let info = system_mallinfo2()
    // usmblks, which glibc no longer sets, isn't here.
    return AllocatorStatistics(
      arenaBytes: Int(info.arena), freeChunks: Int(info.ordblks),
      freeFastBinChunks: Int(info.smblks), mappings: Int(info.hblks),
      mappedBytes: Int(info.hblkhd), freeFastBinBytes: Int(info.fsmblks),
      bytesInUse: Int(info.uordblks), freeBytes: Int(info.fordblks),
      releasableBytes: Int(info.keepcost))
  }

  /// Returns an XML description of glibc's allocator's state,
  /// arena by arena.
  ///
  /// The corresponding C function is `malloc_info`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static func allocatorReport() throws(Errno) -> String {
    try _allocatorReport().get()
  }

  @usableFromInline
  internal static func _allocatorReport() -> Result<String, Errno> {
    var text: UnsafeMutablePointer<CChar>? = nil
    var length = 0
    guard let stream = system_open_memstream(&text, &length) else { return .failure(.current) }
    let failure = system_malloc_info(0, UnsafeMutableRawPointer(stream)) == 0 ? nil : Errno.current
    // Closing the stream writes the text out, and its terminating NUL.
    let closeFailure = system_fclose(stream) == 0 ? nil : Errno.current
    defer { system_free(text) }
    if let error = failure ?? closeFailure { return .failure(error) }
    return .success(text.map { String(cString: $0) } ?? "")
  }

  /// Prints glibc's allocator's use of memory, arena by arena,
  /// to the standard error.
  ///
  /// The corresponding C function is `malloc_stats`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static func printAllocatorStatistics() {
    _printAllocatorStatistics()
  }

  @usableFromInline
  internal static func _printAllocatorStatistics() {
    system_malloc_stats()
  }
}
#endif // os(Linux) && canImport(Glibc)

#endif // !os(Windows) && !os(WASI)
