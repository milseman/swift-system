/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned Darwin zone, and buffers in it that can't outlive it.
// Not API; see Prototype/Memory/README.md.

#if canImport(Darwin)

import SystemPackage

@available(System 199, *)
extension Memory {
  /// A malloc zone that this value owns, and destroys at the end of its
  /// lifetime, with every block still in it.
  ///
  ///     let arena = try Memory.OwnedZone(name: "request")
  ///     var nodes = try Memory.ZoneBuffer<Node>(capacity: 64, in: arena)
  ///     // ...
  ///     // Destroying the zone frees `nodes`, which can't outlive it.
  ///
  /// Destroying a zone can't fail, so this owner has no error to drop.
  @frozen
  public struct OwnedZone: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _zone: Memory.Zone

    /// Creates a zone.
    ///
    /// The corresponding C function is `malloc_create_zone`.
    @_alwaysEmitIntoClient
    public init(name: String? = nil) throws(Errno) {
      self._zone = try Memory.Zone.create(name: name)
    }

    deinit {
      _zone.destroy()
    }

    /// The zone, for `Memory.Zone`'s calls, such as its statistics.
    ///
    /// The handle is valid only while this owner is alive;
    /// don't destroy it, or keep it.
    @_alwaysEmitIntoClient
    public var zone: Memory.Zone { _zone }

    /// Destroys the zone now, with every block still in it.
    ///
    /// The corresponding C function is `malloc_destroy_zone`.
    @_alwaysEmitIntoClient
    public consuming func destroy() {
      let zone = _zone
      discard self
      zone.destroy()
    }
  }

  /// A buffer in memory from an owned zone, which can't outlive the zone.
  ///
  /// It's a ``Memory/Buffer`` whose lifetime depends on its zone's, so
  /// that the compiler rejects code that destroys the zone, or lets the
  /// zone's lifetime end, while the buffer is alive.
  @frozen
  public struct ZoneBuffer<Element: BitwiseCopyable>: ~Copyable, ~Escapable {
    @usableFromInline
    internal var _buffer: Memory.Buffer<Element>

    /// Allocates an empty buffer in a zone, with room for some elements.
    ///
    /// The corresponding C function is `malloc_zone_malloc`.
    @_alwaysEmitIntoClient
    @_lifetime(borrow zone)
    public init(capacity: Int, in zone: borrowing OwnedZone) throws(Errno) {
      self._buffer = try Memory.Buffer(capacity: capacity, in: zone._zone)
    }

    /// Allocates a buffer of `count` copies of a value in a zone.
    ///
    /// The corresponding C function is `malloc_zone_calloc` when the
    /// value's bytes are zeros, and otherwise `malloc_zone_malloc`.
    @_alwaysEmitIntoClient
    @_lifetime(borrow zone)
    public init(repeating value: Element, count: Int, in zone: borrowing OwnedZone) throws(Errno) {
      self._buffer = try Memory.Buffer(repeating: value, count: count, in: zone._zone)
    }

    // A deinit, though it does nothing itself (the buffer's frees the
    // memory to the zone), so that the buffer can't be moved out of this
    // value and so escape the zone's lifetime.
    deinit {}
  }
}

@available(System 199, *)
extension Memory.ZoneBuffer {
  /// The number of initialized elements.
  @_alwaysEmitIntoClient
  public var count: Int { _buffer.count }

  /// The number of elements the buffer has room for without growing.
  @_alwaysEmitIntoClient
  public var capacity: Int { _buffer.capacity }

  /// Appends an element, growing the buffer in its zone if it's full.
  @_alwaysEmitIntoClient
  @_lifetime(self: copy self)
  public mutating func append(_ element: Element) throws(Errno) {
    try _buffer.append(element)
  }

  /// Makes room for at least `minimumCapacity` elements.
  @_alwaysEmitIntoClient
  @_lifetime(self: copy self)
  public mutating func reserveCapacity(_ minimumCapacity: Int) throws(Errno) {
    try _buffer.reserveCapacity(minimumCapacity)
  }

  /// Removes the elements, keeping the capacity.
  @_alwaysEmitIntoClient
  @_lifetime(self: copy self)
  public mutating func removeAll() {
    _buffer.removeAll()
  }
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Memory.ZoneBuffer {
  /// The buffer's elements, to read.
  @_alwaysEmitIntoClient
  public var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get { _buffer.span }
  }

  /// The buffer's elements, to read and write.
  @_alwaysEmitIntoClient
  public var mutableSpan: MutableSpan<Element> {
    @_lifetime(&self)
    mutating get { _buffer.mutableSpan }
  }
}

#endif // canImport(Darwin)
