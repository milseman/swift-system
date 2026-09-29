/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's I/O policies: how a process's or a thread's disk I/O is
// throttled, and how the file system treats its accesses.

#if SYSTEM_PACKAGE_DARWIN

/// A namespace for Darwin's I/O policies,
/// each a value for a process, a thread, or the process's
/// background state.
///
///     let throttled = try IOPolicy.value(of: .disk, for: .thread)
///
/// Each kind of policy has values of its own, which `<sys/resource.h>`
/// names, such as `IOPOL_THROTTLE` for ``Kind/disk``
/// and `IOPOL_ATIME_UPDATES_OFF` for ``Kind/accessTimeUpdates``.
///
/// The corresponding C functions are `getiopolicy_np` and `setiopolicy_np`.
///
/// - Note: Only available on Darwin.
@available(System 199, *)
public enum IOPolicy {}

@available(System 199, *)
extension IOPolicy {
  /// A kind of I/O policy.
  ///
  /// A kind that isn't named here, such as one from a private header,
  /// can be made from its raw value.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Kind: RawRepresentable, Hashable, Sendable {
    /// The raw C policy type.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed policy kind from a raw C policy type.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// How much the system throttles disk I/O.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_DISK`.
    @_alwaysEmitIntoClient
    public static var disk: Self { Self(rawValue: _IOPOL_TYPE_DISK) }

    /// Whether reading a file updates its access time.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_ATIME_UPDATES`.
    @_alwaysEmitIntoClient
    public static var accessTimeUpdates: Self { Self(rawValue: _IOPOL_TYPE_VFS_ATIME_UPDATES) }

    /// Whether accessing a dataless file materializes its contents.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES`.
    @_alwaysEmitIntoClient
    public static var materializeDatalessFiles: Self {
      Self(rawValue: _IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES)
    }

    /// Whether `statfs` reports the data volume for the root.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_STATFS_NO_DATA_VOLUME`.
    @_alwaysEmitIntoClient
    public static var statFSNoDataVolume: Self { Self(rawValue: _IOPOL_TYPE_VFS_STATFS_NO_DATA_VOLUME) }

    /// Whether looking up a path triggers the automounter.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_TRIGGER_RESOLVE`.
    @_alwaysEmitIntoClient
    public static var triggerResolve: Self { Self(rawValue: _IOPOL_TYPE_VFS_TRIGGER_RESOLVE) }

    /// Whether I/O ignores data protection.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_IGNORE_CONTENT_PROTECTION`.
    @_alwaysEmitIntoClient
    public static var ignoreContentProtection: Self {
      Self(rawValue: _IOPOL_TYPE_VFS_IGNORE_CONTENT_PROTECTION)
    }

    /// Whether I/O ignores file permissions, for a process entitled to.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_IGNORE_PERMISSIONS`.
    @_alwaysEmitIntoClient
    public static var ignorePermissions: Self { Self(rawValue: _IOPOL_TYPE_VFS_IGNORE_PERMISSIONS) }

    /// Whether writing a file skips updating its modification time.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_SKIP_MTIME_UPDATE`.
    @_alwaysEmitIntoClient
    public static var skipModificationTimeUpdates: Self { Self(rawValue: _IOPOL_TYPE_VFS_SKIP_MTIME_UPDATE) }

    /// Whether writes are allowed when the volume is low on space.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_ALLOW_LOW_SPACE_WRITES`.
    @_alwaysEmitIntoClient
    public static var allowLowSpaceWrites: Self { Self(rawValue: _IOPOL_TYPE_VFS_ALLOW_LOW_SPACE_WRITES) }

    /// Whether a file opened for events only can be read or written.
    ///
    /// The corresponding C constant is `IOPOL_TYPE_VFS_DISALLOW_RW_FOR_O_EVTONLY`.
    @_alwaysEmitIntoClient
    public static var disallowReadWriteForEventsOnly: Self {
      Self(rawValue: _IOPOL_TYPE_VFS_DISALLOW_RW_FOR_O_EVTONLY)
    }
  }

  /// Whose I/O policy.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Scope: RawRepresentable, Hashable, Sendable {
    /// The raw C scope.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed scope from a raw C scope.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The calling process.
    ///
    /// The corresponding C constant is `IOPOL_SCOPE_PROCESS`.
    @_alwaysEmitIntoClient
    public static var process: Self { Self(rawValue: _IOPOL_SCOPE_PROCESS) }

    /// The calling thread.
    ///
    /// The corresponding C constant is `IOPOL_SCOPE_THREAD`.
    @_alwaysEmitIntoClient
    public static var thread: Self { Self(rawValue: _IOPOL_SCOPE_THREAD) }

    /// The calling process when it runs in the background.
    ///
    /// The corresponding C constant is `IOPOL_SCOPE_DARWIN_BG`.
    @_alwaysEmitIntoClient
    public static var darwinBackground: Self { Self(rawValue: _IOPOL_SCOPE_DARWIN_BG) }
  }

  /// Returns the value of an I/O policy.
  ///
  /// - Parameters:
  ///   - kind: The policy.
  ///   - scope: Whose policy.
  /// - Returns: The policy's value, one of its kind's constants.
  ///
  /// The corresponding C function is `getiopolicy_np`.
  @_alwaysEmitIntoClient
  public static func value(of kind: Kind, for scope: Scope) throws(Errno) -> CInt {
    try _value(of: kind, for: scope).get()
  }

  @usableFromInline
  internal static func _value(of kind: Kind, for scope: Scope) -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: false) { system_getiopolicy_np(kind.rawValue, scope.rawValue) }
  }

  /// Sets the value of an I/O policy.
  ///
  /// - Parameters:
  ///   - value: The policy's new value, one of its kind's constants.
  ///   - kind: The policy.
  ///   - scope: Whose policy.
  ///
  /// The corresponding C function is `setiopolicy_np`.
  @_alwaysEmitIntoClient
  public static func setValue(_ value: CInt, of kind: Kind, for scope: Scope) throws(Errno) {
    try _setValue(value, of: kind, for: scope).get()
  }

  @usableFromInline
  internal static func _setValue(_ value: CInt, of kind: Kind, for scope: Scope) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_setiopolicy_np(kind.rawValue, scope.rawValue, value)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
