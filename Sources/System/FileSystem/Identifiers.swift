//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows)
/// A Swift wrapper of the C `uid_t` type.
@frozen
@available(System 1.7.0, *)
public struct UserID: RawRepresentable, Sendable, Hashable, Codable {

  /// The raw C `uid_t`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.UserID

  /// Creates a strongly-typed `UserID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.UserID) { self.rawValue = rawValue }

  /// Creates a strongly-typed `UserID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.UserID) { self.rawValue = rawValue }
}

/// A Swift wrapper of the C `gid_t` type.
@frozen
@available(System 1.7.0, *)
public struct GroupID: RawRepresentable, Sendable, Hashable, Codable {

  /// The raw C `gid_t`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.GroupID

  /// Creates a strongly-typed `GroupID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.GroupID) { self.rawValue = rawValue }

  /// Creates a strongly-typed `GroupID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.GroupID) { self.rawValue = rawValue }
}

/// A Swift wrapper of the C `dev_t` type.
@frozen
@available(System 1.7.0, *)
public struct DeviceID: RawRepresentable, Sendable, Hashable, Codable {

  /// The raw C `dev_t`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.DeviceID

  /// Creates a strongly-typed `DeviceID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.DeviceID) { self.rawValue = rawValue }

  /// Creates a strongly-typed `DeviceID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.DeviceID) { self.rawValue = rawValue }
}

/// A Swift wrapper of the C `ino_t` type.
@frozen
@available(System 1.7.0, *)
public struct Inode: RawRepresentable, Sendable, Hashable, Codable {

  /// The raw C `ino_t`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.Inode

  /// Creates a strongly-typed `Inode` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.Inode) { self.rawValue = rawValue }

  /// Creates a strongly-typed `Inode` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.Inode) { self.rawValue = rawValue }
}

#if !os(WASI)
@available(System 199, *)
extension UserID {
  /// The real user ID of the calling process.
  ///
  /// The real user ID identifies the user who started the process.
  /// Permission checks use the effective user ID, ``effective``, instead;
  /// the two differ in a set-user-ID program.
  ///
  /// The corresponding C function is `getuid`.
  @_alwaysEmitIntoClient
  public static var real: UserID { UserID(rawValue: _getuid()) }

  /// The effective user ID of the calling process.
  ///
  /// The effective user ID determines the process's permissions.
  /// It differs from the real user ID, ``real``, in a set-user-ID program.
  ///
  /// The corresponding C function is `geteuid`.
  @_alwaysEmitIntoClient
  public static var effective: UserID { UserID(rawValue: _geteuid()) }

  @usableFromInline
  internal static func _getuid() -> CInterop.UserID {
    system_getuid()
  }

  @usableFromInline
  internal static func _geteuid() -> CInterop.UserID {
    system_geteuid()
  }
}

@available(System 199, *)
extension GroupID {
  /// The real group ID of the calling process.
  ///
  /// The real group ID identifies the group of the user who started the process.
  /// Permission checks use the effective group ID, ``effective``, instead;
  /// the two differ in a set-group-ID program.
  ///
  /// The corresponding C function is `getgid`.
  @_alwaysEmitIntoClient
  public static var real: GroupID { GroupID(rawValue: _getgid()) }

  /// The effective group ID of the calling process.
  ///
  /// The effective group ID determines the process's permissions,
  /// along with its supplementary groups.
  /// It differs from the real group ID, ``real``, in a set-group-ID program.
  ///
  /// The corresponding C function is `getegid`.
  @_alwaysEmitIntoClient
  public static var effective: GroupID { GroupID(rawValue: _getegid()) }

  @usableFromInline
  internal static func _getgid() -> CInterop.GroupID {
    system_getgid()
  }

  @usableFromInline
  internal static func _getegid() -> CInterop.GroupID {
    system_getegid()
  }

  /// Returns the supplementary group IDs of the calling process.
  ///
  /// - Returns: The process's supplementary group IDs, in no particular order.
  ///
  /// Along with ``effective``, the supplementary groups determine
  /// the process's group permissions.
  /// Whether the list includes the effective group ID varies by platform.
  ///
  /// The corresponding C function is `getgroups`.
  @_alwaysEmitIntoClient
  public static func supplementary() throws(Errno) -> [GroupID] {
    try _supplementary().get()
  }

  /// The group capacity for the first attempt to get the supplementary groups.
  internal static var _initialSupplementaryCapacity: Int { 64 }

  @usableFromInline
  internal static func _supplementary() -> Result<[GroupID], Errno> {
    // getgroups fails with EINVAL if the buffer is too small, which it can
    // be even after asking for the count, since the list can grow.
    var capacity = _initialSupplementaryCapacity
    while true {
      var result: Result<CInt, Errno> = .success(0)
      let groups = [GroupID](unsafeUninitializedCapacity: capacity) { buffer, count in
        result = buffer.withMemoryRebound(to: CInterop.GroupID.self) { buffer in
          valueOrErrno(retryOnInterrupt: false) {
            system_getgroups(CInt(buffer.count), buffer.baseAddress!)
          }
        }
        // getgroups initialized as many IDs as it returned.
        count = (try? result.get()).map(Int.init) ?? 0
      }
      switch result {
      case .success:
        return .success(groups)
      case .failure(.invalidArgument) where capacity < 1 << 17:
        capacity *= 4
      case .failure(let error):
        return .failure(error)
      }
    }
  }
}
#endif // !os(WASI)
#endif // !os(Windows)
