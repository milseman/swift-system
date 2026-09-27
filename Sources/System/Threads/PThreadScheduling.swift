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
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Scheduling policies

@available(System 199, *)
extension PThread {
  /// A policy for scheduling threads.
  @frozen
  public struct SchedulingPolicy: RawRepresentable, Hashable, Sendable {
    /// The raw C scheduling policy.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed scheduling policy from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The default time-sharing policy.
    ///
    /// The corresponding C constant is `SCHED_OTHER`.
    @_alwaysEmitIntoClient
    public static var other: Self { Self(rawValue: _SCHED_OTHER) }

    /// A real-time policy that runs each thread
    /// until it blocks or yields.
    ///
    /// The corresponding C constant is `SCHED_FIFO`.
    @_alwaysEmitIntoClient
    public static var fifo: Self { Self(rawValue: _SCHED_FIFO) }

    /// A real-time policy that runs each thread for a time slice
    /// before the next thread at the same priority.
    ///
    /// The corresponding C constant is `SCHED_RR`.
    @_alwaysEmitIntoClient
    public static var roundRobin: Self { Self(rawValue: _SCHED_RR) }
  }

  /// A scheduling policy, together with a thread's priority under it.
  ///
  /// The corresponding C types are the policy's `int`
  /// and `struct sched_param`.
  @frozen
  public struct Scheduling: Hashable, Sendable {
    /// The scheduling policy.
    public var policy: SchedulingPolicy

    /// The thread's priority, within the policy's
    /// ``SchedulingPolicy/priorityRange()``.
    ///
    /// The corresponding C field is `sched_param.sched_priority`.
    public var priority: CInt

    /// Creates a scheduling policy and priority.
    @_alwaysEmitIntoClient
    public init(policy: SchedulingPolicy, priority: CInt) {
      self.policy = policy
      self.priority = priority
    }
  }
}

@available(System 199, *)
extension PThread.SchedulingPolicy {
  /// The priorities that threads can have under this policy.
  ///
  /// On Darwin, every policy has the same range, 15...47 on macOS 26,
  /// and a policy that doesn't exist doesn't throw.
  ///
  /// The corresponding C functions are `sched_get_priority_min`
  /// and `sched_get_priority_max`.
  @_alwaysEmitIntoClient
  public func priorityRange() throws(Errno) -> ClosedRange<CInt> {
    try _priorityRange().get()
  }

  @usableFromInline
  internal func _priorityRange() -> Result<ClosedRange<CInt>, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_sched_get_priority_min(rawValue)
    }.flatMap { minimum in
      valueOrErrno(retryOnInterrupt: false) {
        system_sched_get_priority_max(rawValue)
      }.map { maximum in minimum...maximum }
    }
  }
}

@available(System 199, *)
extension PThread.ID {
  /// The thread's scheduling policy and priority.
  ///
  /// The corresponding C function is `pthread_getschedparam`.
  @_alwaysEmitIntoClient
  public func scheduling() throws(Errno) -> PThread.Scheduling {
    try _scheduling().get()
  }

  @usableFromInline
  internal func _scheduling() -> Result<PThread.Scheduling, Errno> {
    var policy: CInt = 0
    var parameters = sched_param()
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_getschedparam(rawValue, &policy, &parameters)
    }.map {
      PThread.Scheduling(
        policy: PThread.SchedulingPolicy(rawValue: policy),
        priority: parameters.sched_priority)
    }
  }

  /// Sets the thread's scheduling policy and priority.
  ///
  /// A real-time policy can require privileges that the process lacks,
  /// in which case this method throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `pthread_setschedparam`.
  @_alwaysEmitIntoClient
  public func setScheduling(_ scheduling: PThread.Scheduling) throws(Errno) {
    try _setScheduling(scheduling).get()
  }

  @usableFromInline
  internal func _setScheduling(_ scheduling: PThread.Scheduling) -> Result<(), Errno> {
    var parameters = sched_param()
    parameters.sched_priority = scheduling.priority
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_setschedparam(rawValue, scheduling.policy.rawValue, &parameters)
    }
  }
}

// MARK: - Quality of service

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension PThread {
  /// A quality-of-service class,
  /// which tells the system how important a thread's work is.
  ///
  /// The corresponding C type is `qos_class_t`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct QoSClass: RawRepresentable, Hashable, Sendable {
    /// The raw C quality-of-service class.
    @_alwaysEmitIntoClient
    public var rawValue: qos_class_t

    /// Creates a strongly-typed quality-of-service class from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: qos_class_t) { self.rawValue = rawValue }

    /// Work that the user is interacting with,
    /// such as handling events or drawing.
    ///
    /// The corresponding C constant is `QOS_CLASS_USER_INTERACTIVE`.
    @_alwaysEmitIntoClient
    public static var userInteractive: Self { Self(rawValue: _QOS_CLASS_USER_INTERACTIVE) }

    /// Work that the user started and is waiting for.
    ///
    /// The corresponding C constant is `QOS_CLASS_USER_INITIATED`.
    @_alwaysEmitIntoClient
    public static var userInitiated: Self { Self(rawValue: _QOS_CLASS_USER_INITIATED) }

    /// Work without a more specific class.
    ///
    /// The corresponding C constant is `QOS_CLASS_DEFAULT`.
    @_alwaysEmitIntoClient
    public static var `default`: Self { Self(rawValue: _QOS_CLASS_DEFAULT) }

    /// Work that the user doesn't wait for, such as downloading,
    /// that may report its progress.
    ///
    /// The corresponding C constant is `QOS_CLASS_UTILITY`.
    @_alwaysEmitIntoClient
    public static var utility: Self { Self(rawValue: _QOS_CLASS_UTILITY) }

    /// Work that the user isn't aware of, such as indexing or backups.
    ///
    /// The corresponding C constant is `QOS_CLASS_BACKGROUND`.
    @_alwaysEmitIntoClient
    public static var background: Self { Self(rawValue: _QOS_CLASS_BACKGROUND) }

    /// The absence of a quality-of-service class.
    ///
    /// The corresponding C constant is `QOS_CLASS_UNSPECIFIED`.
    @_alwaysEmitIntoClient
    public static var unspecified: Self { Self(rawValue: _QOS_CLASS_UNSPECIFIED) }

    /// The quality-of-service class of the calling thread.
    ///
    /// The corresponding C function is `qos_class_self`.
    @_alwaysEmitIntoClient
    public static var current: Self { Self(rawValue: _current()) }

    @usableFromInline
    internal static func _current() -> qos_class_t {
      system_qos_class_self()
    }

    /// The quality-of-service class that the process's main thread
    /// started with.
    ///
    /// This class suits threads that do work on the main thread's behalf.
    ///
    /// The corresponding C function is `qos_class_main`.
    @_alwaysEmitIntoClient
    public static var main: Self { Self(rawValue: _main()) }

    @usableFromInline
    internal static func _main() -> qos_class_t {
      system_qos_class_main()
    }
  }

  /// Sets the quality-of-service class of the calling thread.
  ///
  /// - Parameters:
  ///   - qosClass: The class for the calling thread.
  ///   - relativePriority: The thread's priority relative to others
  ///     in the class, from 0, the default,
  ///     down to `QOS_MIN_RELATIVE_PRIORITY`.
  ///
  /// A thread whose scheduling policy was set explicitly
  /// has opted out of quality-of-service classes,
  /// and this method throws ``Errno/notPermitted`` for it.
  ///
  /// The corresponding C function is `pthread_set_qos_class_self_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func setCurrentQoSClass(
    _ qosClass: QoSClass, relativePriority: CInt = 0
  ) throws(Errno) {
    try _setCurrentQoSClass(qosClass, relativePriority: relativePriority).get()
  }

  @usableFromInline
  internal static func _setCurrentQoSClass(
    _ qosClass: QoSClass, relativePriority: CInt
  ) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_set_qos_class_self_np(qosClass.rawValue, relativePriority)
    }
  }
}

@available(System 199, *)
extension PThread.ID {
  /// The thread's quality-of-service class
  /// and its priority relative to others in the class.
  ///
  /// The corresponding C function is `pthread_get_qos_class_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func qosClass() throws(Errno) -> (qosClass: PThread.QoSClass, relativePriority: CInt) {
    try _qosClass().get()
  }

  @usableFromInline
  internal func _qosClass() -> Result<(qosClass: PThread.QoSClass, relativePriority: CInt), Errno> {
    var qosClass = _QOS_CLASS_UNSPECIFIED
    var relativePriority: CInt = 0
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_get_qos_class_np(rawValue, &qosClass, &relativePriority)
    }.map { (PThread.QoSClass(rawValue: qosClass), relativePriority) }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#endif // !os(Windows) && !os(WASI)
