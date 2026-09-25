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

@available(System 199, *)
extension PThread {
  /// Options for creating a thread.
  ///
  /// Each option is `nil` by default, which leaves the system's default
  /// in place.
  /// A thread that ``PThread`` creates is always joinable;
  /// to let it finish on its own, call ``PThread/detach()``.
  ///
  ///     var attributes = PThread.Attributes()
  ///     attributes.stackSize = 1 << 20
  ///     let worker = try PThread(attributes: attributes) { work() }
  ///
  /// The corresponding C type is `pthread_attr_t`.
  @frozen
  public struct Attributes: Hashable, Sendable {
    /// The size of the new thread's stack, in bytes,
    /// or `nil` for the system's default.
    ///
    /// The size must be at least `PTHREAD_STACK_MIN`,
    /// and on Darwin a multiple of the page size;
    /// otherwise, creating the thread throws ``Errno/invalidArgument``.
    ///
    /// The corresponding C function is `pthread_attr_setstacksize`.
    public var stackSize: Int?

    /// The size of the guard area past the end of the new thread's stack,
    /// in bytes, or `nil` for the system's default.
    ///
    /// The corresponding C function is `pthread_attr_setguardsize`.
    public var guardSize: Int?

    /// The new thread's scheduling policy and priority,
    /// or `nil` to inherit them from the creating thread.
    ///
    /// Creating a thread with a real-time policy
    /// can require privileges that the process lacks,
    /// in which case it throws ``Errno/notPermitted``.
    ///
    /// The corresponding C functions are `pthread_attr_setinheritsched`,
    /// with `PTHREAD_EXPLICIT_SCHED`, `pthread_attr_setschedpolicy`,
    /// and `pthread_attr_setschedparam`.
    public var scheduling: Scheduling?

    #if SYSTEM_PACKAGE_DARWIN
    /// The new thread's quality-of-service class,
    /// or `nil` for the system's default.
    ///
    /// On Darwin, a thread's quality-of-service class
    /// and an explicit ``scheduling`` policy are exclusive.
    /// Setting both applies the quality-of-service class.
    ///
    /// The corresponding C function is `pthread_attr_set_qos_class_np`.
    /// - Note: Only available on Darwin.
    public var qosClass: QoSClass?

    /// The new thread's priority relative to others
    /// in its quality-of-service class,
    /// from 0, the default, down to `QOS_MIN_RELATIVE_PRIORITY`.
    ///
    /// This option applies only if ``qosClass`` isn't `nil`.
    ///
    /// The corresponding C function is `pthread_attr_set_qos_class_np`.
    /// - Note: Only available on Darwin.
    public var qosRelativePriority: CInt = 0
    #endif

    /// Creates options that use the system's defaults.
    @_alwaysEmitIntoClient
    public init() {}
  }
}

@available(System 199, *)
extension PThread.Attributes {
  // Calls `body` with the C attributes, or with nil if every option is the
  // default, so that pthread_create applies its own defaults.
  internal func _withUnsafeAttributes<R>(
    _ body: (UnsafePointer<_PThreadAttrStorage>?) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    guard self != PThread.Attributes() else { return body(nil) }
    var attributes = _pthreadAttrZero
    return withUnsafeMutablePointer(to: &attributes) { attributes in
      if let error = _pthreadError(system_pthread_attr_init(attributes)) {
        return .failure(error)
      }
      defer { _ = system_pthread_attr_destroy(attributes) }
      if let error = _apply(to: attributes) {
        return .failure(error)
      }
      return body(attributes)
    }
  }

  private func _apply(to attributes: UnsafeMutablePointer<_PThreadAttrStorage>) -> Errno? {
    if let stackSize {
      if let error = _pthreadError(system_pthread_attr_setstacksize(attributes, stackSize)) {
        return error
      }
    }
    if let guardSize {
      if let error = _pthreadError(system_pthread_attr_setguardsize(attributes, guardSize)) {
        return error
      }
    }
    if let scheduling {
      if let error = _pthreadError(
        system_pthread_attr_setinheritsched(attributes, _PTHREAD_EXPLICIT_SCHED)
      ) {
        return error
      }
      if let error = _pthreadError(
        system_pthread_attr_setschedpolicy(attributes, scheduling.policy.rawValue)
      ) {
        return error
      }
      var parameters = sched_param()
      parameters.sched_priority = scheduling.priority
      if let error = _pthreadError(system_pthread_attr_setschedparam(attributes, &parameters)) {
        return error
      }
    }
    #if SYSTEM_PACKAGE_DARWIN
    if let qosClass {
      if let error = _pthreadError(
        system_pthread_attr_set_qos_class_np(
          attributes, qosClass.rawValue, qosRelativePriority)
      ) {
        return error
      }
    }
    #endif
    return nil
  }
}

// The error number that a pthread function returned, or nil for success.
internal func _pthreadError(_ result: CInt) -> Errno? {
  result == 0 ? nil : Errno(rawValue: result)
}

#endif // !os(Windows) && !os(WASI)
