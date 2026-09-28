/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Darwin

@available(System 199, *)
extension Memory {
  /// A malloc zone: a heap of its own, whose blocks you can free one at
  /// a time, or all at once by destroying the zone.
  ///
  ///     let zone = try Memory.Zone.create(name: "parser")
  ///     let node = try zone.allocate(byteCount: 64)
  ///     // ...
  ///     zone.destroy()  // Frees `node`, and every other block in the zone.
  ///
  /// A zone is a handle, as a file descriptor is:
  /// its copies refer to the same zone, and nothing destroys it for you.
  /// ``Memory/free(_:)`` and ``Memory/reallocate(_:byteCount:)``
  /// find the zone of any block, and so work on a zone's blocks too.
  ///
  /// The corresponding C type is `malloc_zone_t *`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Zone: RawRepresentable, Hashable, @unchecked Sendable {
    /// The raw C zone.
    @_alwaysEmitIntoClient
    public var rawValue: UnsafeMutablePointer<malloc_zone_t>

    /// Creates a strongly-typed zone from a raw C zone.
    @_alwaysEmitIntoClient
    public init(rawValue: UnsafeMutablePointer<malloc_zone_t>) { self.rawValue = rawValue }
  }
}

// MARK: - Zones

@available(System 199, *)
extension Memory.Zone {
  /// The zone that `malloc`, and ``Memory/allocate(byteCount:)``
  /// and the rest of ``Memory``'s allocation, allocate in.
  ///
  /// The default zone can't be destroyed.
  ///
  /// The corresponding C function is `malloc_default_zone`.
  @_alwaysEmitIntoClient
  public static var `default`: Memory.Zone { _default }

  @usableFromInline
  internal static var _default: Memory.Zone {
    Memory.Zone(rawValue: system_malloc_default_zone())
  }

  /// Creates a zone.
  ///
  /// - Parameter name: A name for the zone, which tools such as
  ///   `heap` and Instruments show, or `nil` for none.
  ///   The default is `nil`.
  ///
  /// The zone lasts until you call ``destroy()``.
  ///
  /// The corresponding C function is `malloc_create_zone`.
  @_alwaysEmitIntoClient
  public static func create(name: String? = nil) throws(Errno) -> Memory.Zone {
    try _create(name: name).get()
  }

  @usableFromInline
  internal static func _create(name: String?) -> Result<Memory.Zone, Errno> {
    // malloc_create_zone doesn't document errno.
    guard let zone = system_malloc_create_zone() else { return .failure(.noMemory) }
    let result = Memory.Zone(rawValue: zone)
    if let name { result._setName(name) }
    return .success(result)
  }

  /// The zone that allocated a block.
  ///
  /// - Parameter pointer: The start of a block.
  ///
  /// This is `nil` for memory that no zone allocated,
  /// such as the stack, or memory that the system maps.
  ///
  /// The corresponding C function is `malloc_zone_from_ptr`.
  @_alwaysEmitIntoClient
  public init?(containing pointer: UnsafeRawPointer) {
    guard let zone = Memory.Zone._containing(pointer) else { return nil }
    self = zone
  }

  @usableFromInline
  internal static func _containing(_ pointer: UnsafeRawPointer) -> Memory.Zone? {
    system_malloc_zone_from_ptr(pointer).map { Memory.Zone(rawValue: $0) }
  }

  /// Destroys the zone, and frees every block in it.
  ///
  /// After this returns, the zone and every pointer into it are invalid.
  /// Destroy only a zone you created: destroying the default zone
  /// is a precondition failure, and destroying another library's zone
  /// frees memory it still uses.
  ///
  /// The corresponding C function is `malloc_destroy_zone`.
  @_alwaysEmitIntoClient
  public func destroy() {
    _destroy()
  }

  @usableFromInline
  internal func _destroy() {
    precondition(self != Memory.Zone._default, "the default zone can't be destroyed")
    system_malloc_destroy_zone(rawValue)
  }

  /// The zone's name, or `nil` if it has none.
  ///
  /// The default zone is named `DefaultMallocZone`.
  ///
  /// The corresponding C function is `malloc_get_zone_name`.
  @_alwaysEmitIntoClient
  public var name: String? { _name }

  @usableFromInline
  internal var _name: String? {
    system_malloc_get_zone_name(rawValue).map { String(cString: $0) }
  }

  /// Names the zone, as tools such as `heap` and Instruments show it.
  ///
  /// - Parameter name: The new name, which the zone copies,
  ///   or `nil` to remove the name.
  ///   A name ends at its first NUL character.
  ///
  /// The corresponding C function is `malloc_set_zone_name`.
  @_alwaysEmitIntoClient
  public func setName(_ name: String?) {
    _setName(name)
  }

  @usableFromInline
  internal func _setName(_ name: String?) {
    guard let name else { return system_malloc_set_zone_name(rawValue, nil) }
    name.withCString { system_malloc_set_zone_name(rawValue, $0) }
  }
}

// MARK: - Allocation

@available(System 199, *)
extension Memory.Zone {
  /// Allocates memory in the zone, whose contents are uninitialized.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// The corresponding C function is `malloc_zone_malloc`.
  @_alwaysEmitIntoClient
  public func allocate(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount).get()
  }

  @usableFromInline
  internal func _allocate(byteCount: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(system_malloc_zone_malloc(rawValue, Memory._requestSize(byteCount)))
  }

  /// Allocates memory in the zone, filled with zeros.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// The corresponding C function is `malloc_zone_calloc`.
  @_alwaysEmitIntoClient
  public func allocateZeroed(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: 1, stride: byteCount).get()
  }

  /// Allocates memory in the zone, filled with zeros,
  /// for a number of elements.
  ///
  /// - Parameters:
  ///   - count: The number of elements, which can't be negative.
  ///   - stride: The number of bytes from one element to the next,
  ///     which can't be negative, such as `MemoryLayout<T>.stride`.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// A total size too large to represent throws ``Errno/noMemory``.
  ///
  /// The corresponding C function is `malloc_zone_calloc`.
  @_alwaysEmitIntoClient
  public func allocateZeroed(count: Int, stride: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: count, stride: stride).get()
  }

  @usableFromInline
  internal func _allocateZeroed(count: Int, stride: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    let (count, stride) = Memory._requestSizes(count, stride)
    return Memory._allocated(system_malloc_zone_calloc(rawValue, count, stride))
  }

  /// Allocates memory in the zone at an address that's a multiple of
  /// an alignment, whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - alignment: The alignment, in bytes, which must be a power of two.
  ///     An alignment smaller than a pointer's size is raised to it.
  /// - Returns: The start of the new block.
  ///
  /// An alignment that isn't a power of two
  /// throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `malloc_zone_memalign`.
  @_alwaysEmitIntoClient
  public func allocate(byteCount: Int, alignment: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, alignment: alignment).get()
  }

  @usableFromInline
  internal func _allocate(byteCount: Int, alignment: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    let size = Memory._requestSize(byteCount)
    guard let alignment = Memory._requestAlignment(alignment) else {
      return .failure(.invalidArgument)
    }
    return Memory._allocated(system_malloc_zone_memalign(rawValue, alignment, size))
  }

  /// Allocates memory in the zone that starts at a page boundary,
  /// filled with zeros.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block.
  ///
  /// Unlike ``Memory/allocatePageAligned(byteCount:)``,
  /// a zone clears the block.
  ///
  /// The corresponding C function is `malloc_zone_valloc`.
  @_alwaysEmitIntoClient
  public func allocatePageAligned(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocatePageAligned(byteCount: byteCount).get()
  }

  @usableFromInline
  internal func _allocatePageAligned(byteCount: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(system_malloc_zone_valloc(rawValue, Memory._requestSize(byteCount)))
  }

  /// Resizes a block of the zone, moving it if it can't grow in place.
  ///
  /// - Parameters:
  ///   - pointer: The start of a block of this zone,
  ///     or `nil` to allocate a new one.
  ///   - byteCount: The block's new size, which can't be negative.
  ///     Zero resizes the block to one byte.
  /// - Returns: The start of the resized block, which can differ from `pointer`:
  ///   when this method returns, use only the returned pointer.
  ///
  /// If this method throws, the original block is unchanged,
  /// and still yours to free.
  ///
  /// The corresponding C function is `malloc_zone_realloc`.
  @_alwaysEmitIntoClient
  public func reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _reallocate(pointer, byteCount: byteCount).get()
  }

  @usableFromInline
  internal func _reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(system_malloc_zone_realloc(rawValue, pointer, Memory._requestSize(byteCount)))
  }

  /// Frees a block of the zone.
  ///
  /// - Parameter pointer: The start of a block of this zone,
  ///   or `nil`, which does nothing.
  ///
  /// Freeing a block of another zone, or one that's been freed,
  /// is undefined behavior. ``Memory/free(_:)`` frees a block
  /// of any zone.
  ///
  /// The corresponding C function is `malloc_zone_free`.
  @_alwaysEmitIntoClient
  public func free(_ pointer: UnsafeMutableRawPointer?) {
    _free(pointer)
  }

  @usableFromInline
  internal func _free(_ pointer: UnsafeMutableRawPointer?) {
    system_malloc_zone_free(rawValue, pointer)
  }
}

// MARK: - Pressure and statistics

@available(System 199, *)
extension Memory.Zone {
  /// Returns memory that the zone isn't using to the system.
  ///
  /// - Parameter goal: The number of bytes to try to return,
  ///   or `nil` to return as many as the zone can.
  ///   The default is `nil`.
  /// - Returns: The number of bytes returned.
  ///
  /// The corresponding C function is `malloc_zone_pressure_relief`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func relievePressure(goal: Int? = nil) -> Int {
    Memory.Zone._relievePressure(rawValue, goal: goal)
  }

  /// Returns memory that no zone is using to the system.
  ///
  /// - Parameter goal: The number of bytes to try to return,
  ///   or `nil` to return as many as the zones can.
  ///   The default is `nil`.
  /// - Returns: The number of bytes returned.
  ///
  /// The corresponding C function is `malloc_zone_pressure_relief`,
  /// with a null zone.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func relievePressureInAllZones(goal: Int? = nil) -> Int {
    _relievePressure(nil, goal: goal)
  }

  @usableFromInline
  internal static func _relievePressure(
    _ zone: UnsafeMutablePointer<malloc_zone_t>?, goal: Int?
  ) -> Int {
    // A goal of zero is as much as possible.
    precondition((goal ?? 0) >= 0, "goal can't be negative")
    return system_malloc_zone_pressure_relief(zone, goal ?? 0)
  }

  /// A zone's use of memory.
  ///
  /// The corresponding C type is `malloc_statistics_t`.
  @frozen
  public struct Statistics: Hashable, Sendable {
    /// The number of blocks in use.
    public var blocksInUse: Int

    /// The number of bytes in the blocks in use.
    public var bytesInUse: Int

    /// The most bytes that have been in use at once,
    /// or zero if the zone doesn't track it, as Darwin's zones don't.
    public var maximumBytesInUse: Int

    /// The number of bytes the zone has reserved from the system,
    /// including those it isn't using.
    public var bytesReserved: Int

    /// Creates statistics with the given values.
    @_alwaysEmitIntoClient
    public init(blocksInUse: Int, bytesInUse: Int, maximumBytesInUse: Int, bytesReserved: Int) {
      self.blocksInUse = blocksInUse
      self.bytesInUse = bytesInUse
      self.maximumBytesInUse = maximumBytesInUse
      self.bytesReserved = bytesReserved
    }
  }

  /// Returns the zone's use of memory.
  ///
  /// The corresponding C function is `malloc_zone_statistics`.
  @_alwaysEmitIntoClient
  public func statistics() -> Statistics {
    Memory.Zone._statistics(rawValue)
  }

  /// Returns the sum of every zone's use of memory.
  ///
  /// This covers C's `mstats`, which reads the same sums.
  ///
  /// The corresponding C function is `malloc_zone_statistics`,
  /// with a null zone.
  @_alwaysEmitIntoClient
  public static func statisticsForAllZones() -> Statistics {
    _statistics(nil)
  }

  @usableFromInline
  internal static func _statistics(_ zone: UnsafeMutablePointer<malloc_zone_t>?) -> Statistics {
    var statistics = malloc_statistics_t()
    system_malloc_zone_statistics(zone, &statistics)
    return Statistics(
      blocksInUse: Int(statistics.blocks_in_use),
      bytesInUse: statistics.size_in_use,
      maximumBytesInUse: statistics.max_size_in_use,
      bytesReserved: statistics.size_allocated)
  }
}

// MARK: - C spellings

@available(System 199, *)
extension Memory {
  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "Zone.statisticsForAllZones()")
  public static func mstats() -> Zone.Statistics {
    fatalError("Not implemented")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
