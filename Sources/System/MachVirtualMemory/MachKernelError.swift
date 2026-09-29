/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

// Must import here to use kern_return_t's constants in
// @_alwaysEmitIntoClient API.
import Darwin.Mach

@available(System 199, *)
extension Mach {
  /// An error that a Mach kernel call returns.
  ///
  /// Mach calls return a code, which is `KERN_SUCCESS` when they succeed,
  /// rather than setting `errno`, and their codes aren't errno's.
  /// System's Mach methods throw an error for any code but success;
  /// the corresponding C constants are `KERN_SUCCESS`
  /// and `ERR_SUCCESS`, its spelling as a Mach error.
  ///
  ///     do {
  ///       let region = try Mach.VirtualMemory.allocate(byteCount: 1 << 40)
  ///       // ...
  ///     } catch .noSpace {
  ///       print("There's no room in the address space")
  ///     }
  ///
  /// The corresponding C type is `kern_return_t`.
  @frozen
  public struct KernelError: Error, RawRepresentable, Hashable, Sendable {
    /// The raw C code.
    @_alwaysEmitIntoClient
    public var rawValue: kern_return_t

    /// Creates a strongly-typed error from a raw C code.
    @_alwaysEmitIntoClient
    public init(rawValue: kern_return_t) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Mach.KernelError: CustomStringConvertible {
  /// A description of the error, such as
  /// `"(os/kern) no space available"`.
  ///
  /// The corresponding C function is `mach_error_string`.
  public var description: String {
    String(cString: mach_error_string(rawValue))
  }
}

@available(System 199, *)
extension Mach.KernelError {
  /// The address isn't in the task's address space, or its memory doesn't allow the access.
  ///
  /// The corresponding C constant is `KERN_INVALID_ADDRESS`.
  @_alwaysEmitIntoClient
  public static var invalidAddress: Self { Self(rawValue: _KERN_INVALID_ADDRESS) }

  /// The memory's protection doesn't allow the access.
  ///
  /// The corresponding C constant is `KERN_PROTECTION_FAILURE`.
  @_alwaysEmitIntoClient
  public static var protectionFailure: Self { Self(rawValue: _KERN_PROTECTION_FAILURE) }

  /// The address space has no room for the region.
  ///
  /// The corresponding C constant is `KERN_NO_SPACE`.
  @_alwaysEmitIntoClient
  public static var noSpace: Self { Self(rawValue: _KERN_NO_SPACE) }

  /// An argument isn't valid.
  ///
  /// The corresponding C constant is `KERN_INVALID_ARGUMENT`.
  @_alwaysEmitIntoClient
  public static var invalidArgument: Self { Self(rawValue: _KERN_INVALID_ARGUMENT) }

  /// The call failed, for a reason it doesn't say.
  ///
  /// The corresponding C constant is `KERN_FAILURE`.
  @_alwaysEmitIntoClient
  public static var failure: Self { Self(rawValue: _KERN_FAILURE) }

  /// The kernel ran out of a resource, such as memory.
  ///
  /// The corresponding C constant is `KERN_RESOURCE_SHORTAGE`.
  @_alwaysEmitIntoClient
  public static var resourceShortage: Self { Self(rawValue: _KERN_RESOURCE_SHORTAGE) }

  /// The task doesn't hold the receive right.
  ///
  /// The corresponding C constant is `KERN_NOT_RECEIVER`.
  @_alwaysEmitIntoClient
  public static var notReceiver: Self { Self(rawValue: _KERN_NOT_RECEIVER) }

  /// The caller doesn't have access.
  ///
  /// The corresponding C constant is `KERN_NO_ACCESS`.
  @_alwaysEmitIntoClient
  public static var noAccess: Self { Self(rawValue: _KERN_NO_ACCESS) }

  /// The memory can't be accessed, because its backing store failed.
  ///
  /// The corresponding C constant is `KERN_MEMORY_FAILURE`.
  @_alwaysEmitIntoClient
  public static var memoryFailure: Self { Self(rawValue: _KERN_MEMORY_FAILURE) }

  /// The memory's manager couldn't return its data.
  ///
  /// The corresponding C constant is `KERN_MEMORY_ERROR`.
  @_alwaysEmitIntoClient
  public static var memoryError: Self { Self(rawValue: _KERN_MEMORY_ERROR) }

  /// The operation was aborted.
  ///
  /// The corresponding C constant is `KERN_ABORTED`.
  @_alwaysEmitIntoClient
  public static var aborted: Self { Self(rawValue: _KERN_ABORTED) }

  /// The port name doesn't name a right.
  ///
  /// The corresponding C constant is `KERN_INVALID_NAME`.
  @_alwaysEmitIntoClient
  public static var invalidName: Self { Self(rawValue: _KERN_INVALID_NAME) }

  /// The task isn't valid.
  ///
  /// The corresponding C constant is `KERN_INVALID_TASK`.
  @_alwaysEmitIntoClient
  public static var invalidTask: Self { Self(rawValue: _KERN_INVALID_TASK) }

  /// The right isn't valid for the operation.
  ///
  /// The corresponding C constant is `KERN_INVALID_RIGHT`.
  @_alwaysEmitIntoClient
  public static var invalidRight: Self { Self(rawValue: _KERN_INVALID_RIGHT) }

  /// A value isn't valid.
  ///
  /// The corresponding C constant is `KERN_INVALID_VALUE`.
  @_alwaysEmitIntoClient
  public static var invalidValue: Self { Self(rawValue: _KERN_INVALID_VALUE) }

  /// The port isn't the right kind for the operation.
  ///
  /// The corresponding C constant is `KERN_INVALID_CAPABILITY`.
  @_alwaysEmitIntoClient
  public static var invalidCapability: Self { Self(rawValue: _KERN_INVALID_CAPABILITY) }

  /// The operation isn't supported.
  ///
  /// The corresponding C constant is `KERN_NOT_SUPPORTED`.
  @_alwaysEmitIntoClient
  public static var notSupported: Self { Self(rawValue: _KERN_NOT_SUPPORTED) }

  /// The operation timed out.
  ///
  /// The corresponding C constant is `KERN_OPERATION_TIMED_OUT`.
  @_alwaysEmitIntoClient
  public static var operationTimedOut: Self { Self(rawValue: _KERN_OPERATION_TIMED_OUT) }

  /// The operation was denied, by policy.
  ///
  /// The corresponding C constant is `KERN_DENIED`.
  @_alwaysEmitIntoClient
  public static var denied: Self { Self(rawValue: _KERN_DENIED) }

  /// What the operation looked for wasn't found.
  ///
  /// The corresponding C constant is `KERN_NOT_FOUND`.
  @_alwaysEmitIntoClient
  public static var notFound: Self { Self(rawValue: _KERN_NOT_FOUND) }
}

@available(System 199, *)
extension Mach.KernelError {
  // Success for KERN_SUCCESS, and the error for any other code.
  @usableFromInline
  internal static func _check(_ result: kern_return_t) -> Result<(), Mach.KernelError> {
    result == _KERN_SUCCESS ? .success(()) : .failure(Mach.KernelError(rawValue: result))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
