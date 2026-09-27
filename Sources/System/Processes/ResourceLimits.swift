/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

import CSystem
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

/// A limit on a resource that a process can use,
/// such as its number of open files.
///
/// Each limit has two values:
/// the system enforces the soft limit,
/// and the hard limit is the ceiling for the soft limit.
/// A process can lower either,
/// and raise its soft limit up to its hard limit;
/// raising a hard limit takes privilege.
/// A child inherits its parent's limits.
///
/// A server that needs many descriptors
/// raises its soft limit to its hard limit:
///
///     var limit = try ResourceLimit.current(for: .openFiles)
///     limit.soft = limit.hard
///     try ResourceLimit.setCurrent(limit, for: .openFiles)
///
/// The corresponding C type is `struct rlimit`.
@frozen
@available(System 199, *)
public struct ResourceLimit: Hashable, Sendable {
  /// The limit that the system enforces.
  ///
  /// The corresponding C field is `rlim_cur`.
  public var soft: Value

  /// The ceiling for the soft limit.
  ///
  /// The corresponding C field is `rlim_max`.
  public var hard: Value

  /// Creates a limit.
  @_alwaysEmitIntoClient
  public init(soft: Value, hard: Value) {
    self.soft = soft
    self.hard = hard
  }
}

@available(System 199, *)
extension ResourceLimit: RawRepresentable {
  /// Creates a strongly-typed limit from a raw C `struct rlimit`.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.ResourceLimit) {
    self.init(soft: Value(rawValue: rawValue.rlim_cur), hard: Value(rawValue: rawValue.rlim_max))
  }

  /// The raw C `struct rlimit`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.ResourceLimit {
    CInterop.ResourceLimit(rlim_cur: soft.rawValue, rlim_max: hard.rawValue)
  }
}

@available(System 199, *)
extension ResourceLimit {
  /// The value of a resource limit: an amount, or no limit.
  ///
  /// The unit depends on the resource:
  /// bytes for sizes, seconds for processor time, and a count for the rest.
  @frozen
  public struct Value:
    RawRepresentable, Hashable, Comparable, Sendable, ExpressibleByIntegerLiteral
  {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.ResourceLimitValue

    /// Creates a strongly-typed value from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.ResourceLimitValue) { self.rawValue = rawValue }

    /// Creates a value from an integer literal.
    @_alwaysEmitIntoClient
    public init(integerLiteral value: CInterop.ResourceLimitValue) { self.rawValue = value }

    /// No limit.
    ///
    /// It's the largest value, so it compares greater than every amount.
    ///
    /// The corresponding C constant is `RLIM_INFINITY`.
    @_alwaysEmitIntoClient
    public static var unlimited: Value { Value(rawValue: _RLIM_INFINITY) }

    @_alwaysEmitIntoClient
    public static func < (lhs: Value, rhs: Value) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  /// A resource that the system limits.
  ///
  /// The corresponding C type is `int`, as the `RLIMIT_` constants.
  @frozen
  public struct Resource: RawRepresentable, Hashable, Sendable {
    /// The raw C resource.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed resource from a raw C resource.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The processor time the process can use, in seconds.
    ///
    /// At the soft limit, the system sends ``Signal/cpuTimeLimitExceeded``.
    ///
    /// The corresponding C constant is `RLIMIT_CPU`.
    @_alwaysEmitIntoClient
    public static var cpuTime: Resource { Resource(rawValue: _RLIMIT_CPU) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "cpuTime")
    public static var RLIMIT_CPU: Resource { cpuTime }

    /// The largest file the process can create or grow, in bytes.
    ///
    /// Growing a file beyond it sends ``Signal/fileSizeLimitExceeded``.
    ///
    /// The corresponding C constant is `RLIMIT_FSIZE`.
    @_alwaysEmitIntoClient
    public static var fileSize: Resource { Resource(rawValue: _RLIMIT_FSIZE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "fileSize")
    public static var RLIMIT_FSIZE: Resource { fileSize }

    /// The size of the process's data segment, in bytes.
    ///
    /// The corresponding C constant is `RLIMIT_DATA`.
    @_alwaysEmitIntoClient
    public static var dataSize: Resource { Resource(rawValue: _RLIMIT_DATA) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "dataSize")
    public static var RLIMIT_DATA: Resource { dataSize }

    /// The size of the main thread's stack, in bytes.
    ///
    /// The corresponding C constant is `RLIMIT_STACK`.
    @_alwaysEmitIntoClient
    public static var stackSize: Resource { Resource(rawValue: _RLIMIT_STACK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "stackSize")
    public static var RLIMIT_STACK: Resource { stackSize }

    /// The largest core file the system writes for the process, in bytes.
    ///
    /// Zero, often the default, means that it writes none.
    ///
    /// The corresponding C constant is `RLIMIT_CORE`.
    @_alwaysEmitIntoClient
    public static var coreFileSize: Resource { Resource(rawValue: _RLIMIT_CORE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "coreFileSize")
    public static var RLIMIT_CORE: Resource { coreFileSize }

    /// The process's resident set size, in bytes,
    /// which some platforms don't enforce.
    ///
    /// The corresponding C constant is `RLIMIT_RSS`.
    @_alwaysEmitIntoClient
    public static var residentSetSize: Resource { Resource(rawValue: _RLIMIT_RSS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "residentSetSize")
    public static var RLIMIT_RSS: Resource { residentSetSize }

    /// The number of processes that the process's real user can have.
    ///
    /// The corresponding C constant is `RLIMIT_NPROC`.
    @_alwaysEmitIntoClient
    public static var processes: Resource { Resource(rawValue: _RLIMIT_NPROC) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "processes")
    public static var RLIMIT_NPROC: Resource { processes }

    /// One more than the highest file descriptor the process can open.
    ///
    /// Older releases of macOS reject a soft limit above `OPEN_MAX` (10240),
    /// including ``Value/unlimited``, with ``Errno/invalidArgument``;
    /// macOS 26 accepts any soft limit up to the hard limit.
    ///
    /// The corresponding C constant is `RLIMIT_NOFILE`.
    @_alwaysEmitIntoClient
    public static var openFiles: Resource { Resource(rawValue: _RLIMIT_NOFILE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "openFiles")
    public static var RLIMIT_NOFILE: Resource { openFiles }

    /// The memory the process can lock into RAM, in bytes.
    ///
    /// The corresponding C constant is `RLIMIT_MEMLOCK`.
    @_alwaysEmitIntoClient
    public static var lockedMemory: Resource { Resource(rawValue: _RLIMIT_MEMLOCK) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "lockedMemory")
    public static var RLIMIT_MEMLOCK: Resource { lockedMemory }

    /// The size of the process's virtual address space, in bytes.
    ///
    /// The corresponding C constant is `RLIMIT_AS`.
    @_alwaysEmitIntoClient
    public static var addressSpace: Resource { Resource(rawValue: _RLIMIT_AS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "addressSpace")
    public static var RLIMIT_AS: Resource { addressSpace }

    #if os(Linux) || os(Android)
    /// The number of file locks the process can hold.
    ///
    /// The corresponding C constant is `RLIMIT_LOCKS`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var fileLocks: Resource { Resource(rawValue: _RLIMIT_LOCKS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "fileLocks")
    public static var RLIMIT_LOCKS: Resource { fileLocks }

    /// The number of signals that the process's real user
    /// can have pending.
    ///
    /// The corresponding C constant is `RLIMIT_SIGPENDING`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var pendingSignals: Resource { Resource(rawValue: _RLIMIT_SIGPENDING) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "pendingSignals")
    public static var RLIMIT_SIGPENDING: Resource { pendingSignals }

    /// The bytes that the process's real user
    /// can allocate for POSIX message queues.
    ///
    /// The corresponding C constant is `RLIMIT_MSGQUEUE`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var messageQueueBytes: Resource { Resource(rawValue: _RLIMIT_MSGQUEUE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "messageQueueBytes")
    public static var RLIMIT_MSGQUEUE: Resource { messageQueueBytes }

    /// The ceiling for the process's nice value, as 20 minus the value.
    ///
    /// The corresponding C constant is `RLIMIT_NICE`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var niceCeiling: Resource { Resource(rawValue: _RLIMIT_NICE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "niceCeiling")
    public static var RLIMIT_NICE: Resource { niceCeiling }

    /// The ceiling for the process's real-time priority.
    ///
    /// The corresponding C constant is `RLIMIT_RTPRIO`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var realTimePriority: Resource { Resource(rawValue: _RLIMIT_RTPRIO) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "realTimePriority")
    public static var RLIMIT_RTPRIO: Resource { realTimePriority }

    /// The processor time, in microseconds, that a process
    /// with a real-time policy can use without blocking.
    ///
    /// The corresponding C constant is `RLIMIT_RTTIME`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var realTimeCPUTime: Resource { Resource(rawValue: _RLIMIT_RTTIME) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "realTimeCPUTime")
    public static var RLIMIT_RTTIME: Resource { realTimeCPUTime }
    #endif

    #if os(FreeBSD)
    /// The bytes that the process's real user's sockets
    /// can use for buffers.
    ///
    /// The corresponding C constant is `RLIMIT_SBSIZE`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var socketBufferSize: Resource { Resource(rawValue: _RLIMIT_SBSIZE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "socketBufferSize")
    public static var RLIMIT_SBSIZE: Resource { socketBufferSize }

    /// The number of pseudoterminals that the process's real user can have.
    ///
    /// The corresponding C constant is `RLIMIT_NPTS`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var pseudoterminals: Resource { Resource(rawValue: _RLIMIT_NPTS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "pseudoterminals")
    public static var RLIMIT_NPTS: Resource { pseudoterminals }

    /// The swap space that the process's real user can reserve, in bytes.
    ///
    /// The corresponding C constant is `RLIMIT_SWAP`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var swapSize: Resource { Resource(rawValue: _RLIMIT_SWAP) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "swapSize")
    public static var RLIMIT_SWAP: Resource { swapSize }

    /// The number of kqueues that the process's real user can have.
    ///
    /// The corresponding C constant is `RLIMIT_KQUEUES`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var kernelQueues: Resource { Resource(rawValue: _RLIMIT_KQUEUES) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "kernelQueues")
    public static var RLIMIT_KQUEUES: Resource { kernelQueues }
    #endif
  }
}

@available(System 199, *)
extension ResourceLimit {
  /// Returns the calling process's limit on a resource.
  ///
  /// The corresponding C function is `getrlimit`.
  @_alwaysEmitIntoClient
  public static func current(for resource: Resource) throws(Errno) -> ResourceLimit {
    try _current(for: resource).get()
  }

  @usableFromInline
  internal static func _current(for resource: Resource) -> Result<ResourceLimit, Errno> {
    var limit = CInterop.ResourceLimit()
    return nothingOrErrno(retryOnInterrupt: false) {
      system_getrlimit(resource.rawValue, &limit)
    }.map { ResourceLimit(rawValue: limit) }
  }

  /// Sets the calling process's limit on a resource.
  ///
  /// - Parameters:
  ///   - limit: The new soft and hard limits.
  ///   - resource: The resource to limit.
  ///
  /// A soft limit above the hard limit throws ``Errno/invalidArgument``,
  /// and raising the hard limit without privilege
  /// throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `setrlimit`.
  @_alwaysEmitIntoClient
  public static func setCurrent(_ limit: ResourceLimit, for resource: Resource) throws(Errno) {
    try _setCurrent(limit, for: resource).get()
  }

  @usableFromInline
  internal static func _setCurrent(
    _ limit: ResourceLimit, for resource: Resource
  ) -> Result<(), Errno> {
    withUnsafePointer(to: limit.rawValue) { limit in
      nothingOrErrno(retryOnInterrupt: false) {
        system_setrlimit(resource.rawValue, limit)
      }
    }
  }
}

@available(System 199, *)
extension ResourceLimit: CustomStringConvertible {
  /// A description of the limit, such as `soft 256, hard unlimited`.
  public var description: String { "soft \(soft), hard \(hard)" }
}

@available(System 199, *)
extension ResourceLimit.Value: CustomStringConvertible {
  /// The value's amount, or `unlimited`.
  public var description: String {
    self == .unlimited ? "unlimited" : "\(rawValue)"
  }
}

#endif // !os(Windows) && !os(WASI)
