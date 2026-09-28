/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned buffer of the C allocator's memory, whose deinit frees
// it. Not API; see Prototype/Memory/README.md.

import SystemPackage

@available(System 199, *)
extension Memory {
  /// A buffer of elements in memory from the C allocator,
  /// which this buffer owns and frees.
  ///
  ///     var buffer = try Memory.Buffer<UInt8>(capacity: 4096)
  ///     try buffer.withUnusedByteCapacity { try fd.read(into: &$0) }
  ///     process(buffer.bytes)
  ///
  /// A buffer holds its initialized elements, `count` of them,
  /// at the start of its `capacity`.
  /// C's allocator doesn't initialize memory, so the rest is uninitialized
  /// until you append to it, and its spans cover only the elements.
  ///
  /// Growing the buffer can move it, through `realloc`,
  /// so its spans and pointers last only until you next mutate it,
  /// which Swift enforces for the spans.
  ///
  /// Elements are `BitwiseCopyable`, since `realloc` moves them
  /// by copying their bytes, and freeing them needs no deinitialization.
  @frozen
  public struct Buffer<Element: BitwiseCopyable>: ~Copyable {
    @usableFromInline
    internal var _start: UnsafeMutablePointer<Element>

    @usableFromInline
    internal var _count: Int

    @usableFromInline
    internal var _capacity: Int

    @usableFromInline
    internal var _allocator: Memory._Allocator

    /// Takes ownership of `capacity` elements' worth of memory from
    /// the C allocator, whose first `count` elements are initialized.
    ///
    /// The buffer frees the memory at the end of its lifetime,
    /// so nothing else may free it.
    @_alwaysEmitIntoClient
    public init(
      unsafeTaking start: UnsafeMutablePointer<Element>, count: Int, capacity: Int
    ) {
      precondition(0 <= count && count <= capacity, "count isn't within capacity")
      self.init(
        _start: start, count: count, capacity: capacity,
        allocator: Memory._Allocator(alignment: MemoryLayout<Element>.alignment))
    }

    @usableFromInline
    internal init(
      _start start: UnsafeMutablePointer<Element>, count: Int, capacity: Int,
      allocator: Memory._Allocator
    ) {
      self._start = start
      self._count = count
      self._capacity = capacity
      self._allocator = allocator
    }

    deinit {
      _deinitPolicy(_start, allocator: _allocator)
      _allocator.free(_start)
    }
  }
}

// MARK: - Creating

@available(System 199, *)
extension Memory.Buffer {
  /// Allocates an empty buffer with room for some elements.
  ///
  /// - Parameter capacity: The number of elements to make room for,
  ///   which can't be negative.
  ///
  /// The corresponding C function is `malloc`.
  @_alwaysEmitIntoClient
  public init(capacity: Int) throws(Errno) {
    try self.init(capacity: capacity, allocator: Memory._Allocator(alignment: MemoryLayout<Element>.alignment))
  }

  /// Allocates an empty buffer with room for some elements,
  /// at an address that's a multiple of an alignment.
  ///
  /// - Parameters:
  ///   - capacity: The number of elements to make room for.
  ///   - alignment: The alignment, in bytes, which must be a power of two.
  ///
  /// The buffer keeps its alignment as it grows, which `realloc` doesn't,
  /// by allocating anew and copying.
  ///
  /// The corresponding C function is `posix_memalign`.
  @_alwaysEmitIntoClient
  public init(capacity: Int, alignment: Int) throws(Errno) {
    // Checked here, since a small alignment uses malloc's own.
    guard alignment > 0 && alignment.nonzeroBitCount == 1 else { throw .invalidArgument }
    try self.init(
      capacity: capacity,
      allocator: Memory._Allocator(alignment: Swift.max(alignment, MemoryLayout<Element>.alignment)))
  }

  /// Allocates a buffer of `count` copies of a value.
  ///
  /// - Parameters:
  ///   - value: The value to repeat.
  ///   - count: The number of copies, which can't be negative.
  ///
  /// When the value's bytes are all zero, such as `0`, `nil`,
  /// or a C structure's `init()`, this allocates zeroed memory,
  /// which can cost nothing for memory fresh from the system.
  ///
  /// The corresponding C function is `calloc`, or `malloc`
  /// when the value isn't zeros.
  @_alwaysEmitIntoClient
  public init(repeating value: Element, count: Int) throws(Errno) {
    try self.init(
      _repeating: value, count: count,
      allocator: Memory._Allocator(alignment: MemoryLayout<Element>.alignment))
  }

  #if canImport(Darwin)
  /// Allocates an empty buffer in a zone, with room for some elements.
  ///
  /// - Parameters:
  ///   - capacity: The number of elements to make room for.
  ///   - zone: The zone to allocate in, which must outlive the buffer.
  ///
  /// The buffer grows in the zone, and frees its memory to it.
  /// Nothing stops the zone from being destroyed first;
  /// ``Memory/OwnedZone`` and ``Memory/ZoneBuffer`` do.
  ///
  /// The corresponding C function is `malloc_zone_malloc`.
  @_alwaysEmitIntoClient
  public init(capacity: Int, in zone: Memory.Zone) throws(Errno) {
    try self.init(
      capacity: capacity,
      allocator: Memory._Allocator(zone: zone, alignment: MemoryLayout<Element>.alignment))
  }

  /// Allocates a buffer of `count` copies of a value in a zone.
  ///
  /// The corresponding C function is `malloc_zone_calloc`, or
  /// `malloc_zone_malloc` when the value isn't zeros.
  @_alwaysEmitIntoClient
  public init(repeating value: Element, count: Int, in zone: Memory.Zone) throws(Errno) {
    try self.init(
      _repeating: value, count: count,
      allocator: Memory._Allocator(zone: zone, alignment: MemoryLayout<Element>.alignment))
  }
  #endif

  @usableFromInline
  internal init(capacity: Int, allocator: Memory._Allocator) throws(Errno) {
    let start = try allocator.allocate(byteCount: try Self._byteCount(capacity))
    self.init(
      _start: start.bindMemory(to: Element.self, capacity: capacity),
      count: 0, capacity: capacity, allocator: allocator)
  }

  @usableFromInline
  internal init(_repeating value: Element, count: Int, allocator: Memory._Allocator) throws(Errno) {
    precondition(count >= 0, "count can't be negative")
    let zero = withUnsafeBytes(of: value) { $0.allSatisfy { $0 == 0 } }
    let raw: UnsafeMutableRawPointer
    if zero {
      // The same bytes as `value` repeated, padding included.
      raw = try allocator.allocateZeroed(count: count, stride: MemoryLayout<Element>.stride)
    } else {
      raw = try allocator.allocate(byteCount: try Self._byteCount(count))
    }
    let start = raw.bindMemory(to: Element.self, capacity: count)
    if !zero { start.initialize(repeating: value, count: count) }
    self.init(_start: start, count: count, capacity: count, allocator: allocator)
  }

  /// The bytes for `count` elements. A total too large to represent is
  /// noMemory, as it is for calloc.
  @usableFromInline
  internal static func _byteCount(_ count: Int) throws(Errno) -> Int {
    precondition(count >= 0, "capacity can't be negative")
    let (bytes, overflow) = count.multipliedReportingOverflow(by: MemoryLayout<Element>.stride)
    guard !overflow else { throw .noMemory }
    return bytes
  }
}

// MARK: - Elements

@available(System 199, *)
extension Memory.Buffer {
  /// The number of initialized elements.
  @_alwaysEmitIntoClient
  public var count: Int { _count }

  /// The number of elements the buffer has room for without growing.
  @_alwaysEmitIntoClient
  public var capacity: Int { _capacity }

  /// Whether the buffer has no elements.
  @_alwaysEmitIntoClient
  public var isEmpty: Bool { _count == 0 }

  /// Appends an element, growing the buffer if it's full.
  ///
  /// The corresponding C function is `realloc`, when the buffer grows.
  @_alwaysEmitIntoClient
  public mutating func append(_ element: Element) throws(Errno) {
    if _count == _capacity { try _grow(toAtLeast: _count + 1) }
    (_start + _count).initialize(to: element)
    _count += 1
  }

  /// Removes the elements, keeping the capacity.
  @_alwaysEmitIntoClient
  public mutating func removeAll() {
    // BitwiseCopyable elements need no deinitialization.
    _count = 0
  }

  /// Removes the last `k` elements.
  @_alwaysEmitIntoClient
  public mutating func removeLast(_ k: Int = 1) {
    precondition(0 <= k && k <= _count, "can't remove more elements than the buffer has")
    _count -= k
  }

  /// Makes room for at least `minimumCapacity` elements.
  ///
  /// The buffer can move, and gets at least the room asked for:
  /// on Darwin, as much as the block the allocator gives it holds.
  ///
  /// The corresponding C function is `realloc`, or `posix_memalign`
  /// for an aligned buffer.
  @_alwaysEmitIntoClient
  public mutating func reserveCapacity(_ minimumCapacity: Int) throws(Errno) {
    if minimumCapacity > _capacity { try _resize(toCapacity: minimumCapacity) }
  }

  /// Shrinks the buffer's memory to its elements, or to one element's
  /// worth when it's empty.
  ///
  /// The corresponding C function is `realloc`.
  @_alwaysEmitIntoClient
  public mutating func shrinkToFit() throws(Errno) {
    if _capacity > Swift.max(_count, 1) { try _resize(toCapacity: Swift.max(_count, 1)) }
  }

  /// Grows geometrically, so that appending is amortized constant time.
  @usableFromInline
  internal mutating func _grow(toAtLeast minimumCapacity: Int) throws(Errno) {
    let doubled = _capacity < Int.max / 2 ? 2 * _capacity : Int.max
    try _resize(toCapacity: Swift.max(minimumCapacity, doubled, 16 / Swift.max(1, MemoryLayout<Element>.stride)))
  }

  @usableFromInline
  internal mutating func _resize(toCapacity newCapacity: Int) throws(Errno) {
    let requested = try Self._byteCount(newCapacity)
    let byteCount = _allocator.goodSize(for: requested)
    let start = try _allocator.reallocate(
      UnsafeMutableRawPointer(_start), byteCount: byteCount,
      preserving: _count * MemoryLayout<Element>.stride)
    _capacity = byteCount / MemoryLayout<Element>.stride
    _start = start.bindMemory(to: Element.self, capacity: _capacity)
    _count = Swift.min(_count, _capacity)
  }
}

// MARK: - Spans

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Memory.Buffer {
  /// The buffer's elements, to read.
  @_alwaysEmitIntoClient
  public var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get {
      let span = Span(_unsafeStart: _start, count: _count)
      return _overrideLifetime(span, borrowing: self)
    }
  }

  /// The buffer's elements, to read and write.
  @_alwaysEmitIntoClient
  public var mutableSpan: MutableSpan<Element> {
    @_lifetime(&self)
    mutating get {
      let span = MutableSpan(_unsafeStart: _start, count: _count)
      return _overrideLifetime(span, mutating: &self)
    }
  }

  /// The bytes of the buffer's elements, to read.
  @_alwaysEmitIntoClient
  public var bytes: RawSpan {
    @_lifetime(borrow self)
    borrowing get {
      let span = RawSpan(_unsafeStart: _start, byteCount: _count * MemoryLayout<Element>.stride)
      return _overrideLifetime(span, borrowing: self)
    }
  }

  /// Initializes elements in the buffer's unused capacity,
  /// and appends them.
  ///
  /// - Parameter body: A closure that appends to an output span over
  ///   the unused capacity. The elements it initializes are the buffer's
  ///   when it returns or throws.
  ///
  /// Call ``reserveCapacity(_:)`` first to make room.
  @_alwaysEmitIntoClient
  public mutating func withUnusedCapacity<E: Error, R: ~Copyable>(
    _ body: (inout OutputSpan<Element>) throws(E) -> R
  ) throws(E) -> R {
    let unused = UnsafeMutableBufferPointer(start: _start + _count, count: _capacity - _count)
    var output = OutputSpan(buffer: unused, initializedCount: 0)
    // Not a defer: finalizing consumes the span, which a defer can't.
    do {
      let result = try body(&output)
      _count += output.finalize(for: unused)
      return result
    } catch {
      _count += output.finalize(for: unused)
      throw error
    }
  }
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Memory.Buffer where Element == UInt8 {
  /// The buffer's bytes, to read and write.
  @_alwaysEmitIntoClient
  public var mutableBytes: MutableRawSpan {
    @_lifetime(&self)
    mutating get {
      let span = MutableRawSpan(_unsafeStart: _start, byteCount: _count)
      return _overrideLifetime(span, mutating: &self)
    }
  }

  /// Initializes bytes in the buffer's unused capacity, and appends them,
  /// as a read into an `OutputRawSpan` does.
  ///
  ///     try buffer.reserveCapacity(buffer.count + 4096)
  ///     let read = try buffer.withUnusedByteCapacity { try fd.read(into: &$0) }
  ///
  /// - Parameter body: A closure that appends to an output span over
  ///   the unused capacity.
  @_alwaysEmitIntoClient
  public mutating func withUnusedByteCapacity<E: Error, R: ~Copyable>(
    _ body: (inout OutputRawSpan) throws(E) -> R
  ) throws(E) -> R {
    let unused = UnsafeMutableRawBufferPointer(start: _start + _count, count: _capacity - _count)
    var output = OutputRawSpan(buffer: unused, initializedCount: 0)
    do {
      let result = try body(&output)
      _count += output.finalize(for: unused)
      return result
    } catch {
      _count += output.finalize(for: unused)
      throw error
    }
  }
}

// MARK: - C interop

@available(System 199, *)
extension Memory.Buffer {
  /// Calls a closure with a pointer to the buffer's elements,
  /// for calls that `Memory.Buffer` doesn't provide.
  ///
  /// The pointer is valid only for the closure's duration.
  @_alwaysEmitIntoClient
  public func withUnsafeBufferPointer<E: Error, R: ~Copyable>(
    _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
  ) throws(E) -> R {
    try body(UnsafeBufferPointer(start: _start, count: _count))
  }

  /// Calls a closure with a pointer to the buffer's elements,
  /// to change them.
  ///
  /// The pointer is valid only for the closure's duration.
  @_alwaysEmitIntoClient
  public mutating func withUnsafeMutableBufferPointer<E: Error, R: ~Copyable>(
    _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
  ) throws(E) -> R {
    try body(UnsafeMutableBufferPointer(start: _start, count: _count))
  }

  /// Transfers ownership of the memory to the caller, without freeing it.
  ///
  /// After this method returns, the caller is responsible for freeing
  /// the memory with C's `free`, or `Memory.free(_:)`,
  /// or for a zone's buffer, the zone's `free(_:)`.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> (start: UnsafeMutablePointer<Element>, count: Int, capacity: Int) {
    let result = (_start, _count, _capacity)
    discard self
    return result
  }

  /// Frees the memory now, rather than at the end of the buffer's lifetime.
  ///
  /// Ending the lifetime frees it just the same:
  /// this is for code that says so, as the must-free policy requires.
  @_alwaysEmitIntoClient
  public consuming func free() {
    let (start, allocator) = (_start, _allocator)
    discard self
    allocator.free(start)
  }
}

// A buffer owns its memory alone, so it can move to another thread, as
// MemoryMapping can.
@available(System 199, *)
extension Memory.Buffer: @unchecked Sendable where Element: Sendable {}
