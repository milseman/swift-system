/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension PThread {
  /// The identifier of a thread.
  ///
  /// An identifier names a thread without owning it:
  /// it can be copied, compared, and used as a dictionary key,
  /// but not joined or detached.
  /// To own a thread, use ``PThread``.
  ///
  /// An identifier is valid while its thread is running,
  /// and after that until the thread is joined.
  /// The system can reuse the identifier of a thread
  /// that was joined, or that finished detached,
  /// so an old identifier can compare equal to a new thread's.
  /// Using an invalid identifier is undefined behavior on some platforms,
  /// such as Linux; Darwin reports ``Errno/noSuchProcess``.
  ///
  /// The corresponding C type is `pthread_t`.
  @frozen
  public struct ID: RawRepresentable, Hashable, @unchecked Sendable {
    /// The raw C thread identifier.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.PThread

    /// Creates a strongly-typed thread identifier from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.PThread) { self.rawValue = rawValue }

    /// Creates a strongly-typed thread identifier from a raw C value.
    @_alwaysEmitIntoClient
    public init(_ rawValue: CInterop.PThread) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension PThread.ID {
  /// The identifier of the calling thread.
  ///
  /// The corresponding C function is `pthread_self`.
  @_alwaysEmitIntoClient
  public static var current: PThread.ID { PThread.ID(rawValue: _current()) }

  @usableFromInline
  internal static func _current() -> CInterop.PThread {
    system_pthread_self()
  }

  /// Whether two identifiers refer to the same thread.
  ///
  /// The corresponding C function is `pthread_equal`.
  @_alwaysEmitIntoClient
  public static func == (lhs: PThread.ID, rhs: PThread.ID) -> Bool {
    _equal(lhs.rawValue, rhs.rawValue)
  }

  @usableFromInline
  internal static func _equal(_ lhs: CInterop.PThread, _ rhs: CInterop.PThread) -> Bool {
    system_pthread_equal(lhs, rhs)
  }

  // pthread_equal compares the bits of a pthread_t on every platform System
  // supports, so hashing them agrees with ==.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }
}

#endif // !os(Windows) && !os(WASI)
