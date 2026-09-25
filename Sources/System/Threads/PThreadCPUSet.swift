/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// CPU affinity: which processors a thread may run on. Linux and Android
// have it; Darwin has no equivalent (its affinity tags group threads, rather
// than naming processors). Android has no pthread affinity functions, so
// the calling thread's affinity uses sched_setaffinity, which both have, and
// only Linux has `PThread.ID.affinity()`.

#if os(Linux) || os(Android)

@available(System 199, *)
extension PThread {
  /// A set of processors, identified by number from zero.
  ///
  ///     try PThread.setCurrentAffinity([0, 1])
  ///
  /// The corresponding C type is `cpu_set_t`.
  /// - Note: Only available on Linux and Android.
  @frozen
  public struct CPUSet: Hashable, Sendable {
    // The bits of a cpu_set_t: bit `n % UInt.bitWidth` of word
    // `n / UInt.bitWidth` is processor `n`, as the CPU_SET macro sets it.
    @usableFromInline
    internal var _words: [UInt]

    /// The number of processors that a set can hold.
    ///
    /// Processor numbers in a set must be less than this value.
    ///
    /// The corresponding C constant is `CPU_SETSIZE`.
    @_alwaysEmitIntoClient
    public static var capacity: Int {
      #if os(Android) && (arch(arm) || arch(i386))
      return 32
      #else
      return 1024
      #endif
    }

    /// Creates an empty set.
    ///
    /// The corresponding C macro is `CPU_ZERO`.
    @_alwaysEmitIntoClient
    public init() {
      _words = Array(repeating: 0, count: CPUSet.capacity / UInt.bitWidth)
    }

    /// Creates a set of the given processors.
    ///
    /// Each processor number must be at least zero
    /// and less than ``capacity``.
    @_alwaysEmitIntoClient
    public init(_ processors: some Sequence<Int>) {
      self.init()
      for processor in processors {
        insert(processor)
      }
    }

    /// Whether the set contains a processor.
    ///
    /// The corresponding C macro is `CPU_ISSET`.
    @_alwaysEmitIntoClient
    public func contains(_ processor: Int) -> Bool {
      guard processor >= 0 && processor < CPUSet.capacity else { return false }
      return _words[processor / UInt.bitWidth] & (1 << (processor % UInt.bitWidth)) != 0
    }

    /// Adds a processor to the set.
    ///
    /// The processor number must be at least zero
    /// and less than ``capacity``.
    ///
    /// The corresponding C macro is `CPU_SET`.
    @_alwaysEmitIntoClient
    public mutating func insert(_ processor: Int) {
      precondition(
        processor >= 0 && processor < CPUSet.capacity,
        "Processor number out of range")
      _words[processor / UInt.bitWidth] |= 1 << (processor % UInt.bitWidth)
    }

    /// Removes a processor from the set.
    ///
    /// The corresponding C macro is `CPU_CLR`.
    @_alwaysEmitIntoClient
    public mutating func remove(_ processor: Int) {
      guard processor >= 0 && processor < CPUSet.capacity else { return }
      _words[processor / UInt.bitWidth] &= ~(1 << (processor % UInt.bitWidth))
    }

    /// The number of processors in the set.
    ///
    /// The corresponding C macro is `CPU_COUNT`.
    @_alwaysEmitIntoClient
    public var count: Int {
      _words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    /// Whether the set is empty.
    @_alwaysEmitIntoClient
    public var isEmpty: Bool { _words.allSatisfy { $0 == 0 } }
  }
}

@available(System 199, *)
extension PThread.CPUSet: Sequence {
  /// An iterator over the processor numbers in a set, in increasing order.
  @frozen
  public struct Iterator: IteratorProtocol {
    @usableFromInline
    internal let _set: PThread.CPUSet

    @usableFromInline
    internal var _next: Int

    @_alwaysEmitIntoClient
    internal init(_ set: PThread.CPUSet) {
      _set = set
      _next = 0
    }

    @_alwaysEmitIntoClient
    public mutating func next() -> Int? {
      while _next < PThread.CPUSet.capacity {
        defer { _next += 1 }
        if _set.contains(_next) { return _next }
      }
      return nil
    }
  }

  @_alwaysEmitIntoClient
  public func makeIterator() -> Iterator { Iterator(self) }
}

@available(System 199, *)
extension PThread.CPUSet: ExpressibleByArrayLiteral {
  @_alwaysEmitIntoClient
  public init(arrayLiteral processors: Int...) {
    self.init(processors)
  }
}

@available(System 199, *)
extension PThread {
  /// The processors that the calling thread may run on.
  ///
  /// The corresponding C function is `sched_getaffinity`,
  /// for the calling thread.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static func currentAffinity() throws(Errno) -> CPUSet {
    try _currentAffinity().get()
  }

  @usableFromInline
  internal static func _currentAffinity() -> Result<CPUSet, Errno> {
    var set = CPUSet()
    return set._words.withUnsafeMutableBytes { mask in
      nothingOrErrno(retryOnInterrupt: false) {
        system_sched_getaffinity(0, mask.count, mask.baseAddress!)
      }
    }.map { set }
  }

  /// Restricts the calling thread to run on the given processors.
  ///
  /// - Parameter processors: The processors the thread may run on.
  ///   The set can't be empty, and must include a processor
  ///   that the thread's cgroup allows;
  ///   otherwise, this method throws ``Errno/invalidArgument``.
  ///
  /// Threads that the calling thread creates afterward
  /// inherit its affinity.
  ///
  /// The corresponding C function is `sched_setaffinity`,
  /// for the calling thread.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static func setCurrentAffinity(_ processors: CPUSet) throws(Errno) {
    try _setCurrentAffinity(processors).get()
  }

  @usableFromInline
  internal static func _setCurrentAffinity(_ processors: CPUSet) -> Result<(), Errno> {
    processors._words.withUnsafeBytes { mask in
      nothingOrErrno(retryOnInterrupt: false) {
        system_sched_setaffinity(0, mask.count, mask.baseAddress!)
      }
    }
  }
}

#if os(Linux)
@available(System 199, *)
extension PThread.ID {
  /// The processors that the thread may run on.
  ///
  /// The corresponding C function is `pthread_getaffinity_np`.
  /// - Note: Only available on Linux.
  @_alwaysEmitIntoClient
  public func affinity() throws(Errno) -> PThread.CPUSet {
    try _affinity().get()
  }

  @usableFromInline
  internal func _affinity() -> Result<PThread.CPUSet, Errno> {
    var set = PThread.CPUSet()
    return set._words.withUnsafeMutableBytes { mask in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_getaffinity_np(rawValue, mask.count, mask.baseAddress!)
      }
    }.map { set }
  }

  /// Restricts the thread to run on the given processors.
  ///
  /// - Parameter processors: The processors the thread may run on.
  ///
  /// The corresponding C function is `pthread_setaffinity_np`.
  /// - Note: Only available on Linux.
  @_alwaysEmitIntoClient
  public func setAffinity(_ processors: PThread.CPUSet) throws(Errno) {
    try _setAffinity(processors).get()
  }

  @usableFromInline
  internal func _setAffinity(_ processors: PThread.CPUSet) -> Result<(), Errno> {
    processors._words.withUnsafeBytes { mask in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_setaffinity_np(rawValue, mask.count, mask.baseAddress!)
      }
    }
  }
}
#endif // os(Linux)

#endif // os(Linux) || os(Android)
