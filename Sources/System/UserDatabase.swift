//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows) && !os(WASI)

// Must import here to read the C passwd and group members.
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

// MARK: - UserEntry

/// An entry in the user database, which describes a user account.
///
/// Look up an entry by user ID or by name:
///
///     if let user = try UserEntry(userID: .effective) {
///       print(user.name, user.homeDirectory)
///     }
///
/// An entry holds copies of the values the system returned,
/// so it doesn't change if the database does.
///
/// The corresponding C type is `struct passwd`.
/// - Note: Only available on Unix-like platforms other than WASI.
@frozen
@available(System 199, *)
public struct UserEntry: Sendable, Hashable {
  /// The user's login name.
  ///
  /// The corresponding C property is `pw_name`.
  public var name: String

  /// The user's ID.
  ///
  /// The corresponding C property is `pw_uid`.
  public var userID: UserID

  /// The ID of the user's primary group.
  ///
  /// The corresponding C property is `pw_gid`.
  public var groupID: GroupID

  #if !os(Android) || _pointerBitWidth(_64)
  /// The user's real name,
  /// which some systems follow with other information, separated by commas.
  ///
  /// The corresponding C property is `pw_gecos`.
  /// - Note: Not available on 32-bit Android.
  public var realName: String
  #endif

  /// The user's home directory.
  ///
  /// The corresponding C property is `pw_dir`.
  public var homeDirectory: FilePath

  /// The user's login shell.
  ///
  /// The corresponding C property is `pw_shell`.
  public var shell: FilePath
}

@available(System 199, *)
extension UserEntry {
  /// Looks up the user database entry for a user ID.
  ///
  /// - Parameters:
  ///   - userID: The user ID to look up.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This initializer returns `nil` if the database has no entry
  /// for `userID`, and throws if the lookup itself fails.
  ///
  /// The corresponding C function is `getpwuid_r`.
  @_alwaysEmitIntoClient
  public init?(userID: UserID, retryOnInterrupt: Bool = true) throws(Errno) {
    guard let entry = try UserEntry._lookUp(
      userID: userID, retryOnInterrupt: retryOnInterrupt
    ).get() else {
      return nil
    }
    self = entry
  }

  /// Looks up the user database entry for a login name.
  ///
  /// - Parameters:
  ///   - name: The login name to look up.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This initializer returns `nil` if the database has no entry
  /// for `name`, and throws if the lookup itself fails.
  ///
  /// The corresponding C function is `getpwnam_r`.
  @_alwaysEmitIntoClient
  public init?(name: String, retryOnInterrupt: Bool = true) throws(Errno) {
    guard let entry = try UserEntry._lookUp(
      name: name, retryOnInterrupt: retryOnInterrupt
    ).get() else {
      return nil
    }
    self = entry
  }

  @usableFromInline
  internal static func _lookUp(
    userID: UserID, retryOnInterrupt: Bool
  ) -> Result<UserEntry?, Errno> {
    _lookUpEntry(retryOnInterrupt: retryOnInterrupt, UserEntry.init(_:)) {
      system_getpwuid_r(userID.rawValue, $0, $1, $2, $3)
    }
  }

  @usableFromInline
  internal static func _lookUp(
    name: String, retryOnInterrupt: Bool
  ) -> Result<UserEntry?, Errno> {
    name.withCString { name in
      _lookUpEntry(retryOnInterrupt: retryOnInterrupt, UserEntry.init(_:)) {
        system_getpwnam_r(name, $0, $1, $2, $3)
      }
    }
  }

  // Copies the values out of a C entry, whose strings point into
  // the buffer passed to the lookup function.
  internal init(_ entry: passwd) {
    #if !os(Android) || _pointerBitWidth(_64)
    self.init(
      name: _string(entry.pw_name),
      userID: UserID(rawValue: entry.pw_uid),
      groupID: GroupID(rawValue: entry.pw_gid),
      realName: _string(entry.pw_gecos),
      homeDirectory: _path(entry.pw_dir),
      shell: _path(entry.pw_shell))
    #else
    self.init(
      name: _string(entry.pw_name),
      userID: UserID(rawValue: entry.pw_uid),
      groupID: GroupID(rawValue: entry.pw_gid),
      homeDirectory: _path(entry.pw_dir),
      shell: _path(entry.pw_shell))
    #endif
  }
}

// MARK: - GroupEntry

/// An entry in the group database, which describes a group of users.
///
/// Look up an entry by group ID or by name:
///
///     if let group = try GroupEntry(groupID: .effective) {
///       print(group.name, group.members)
///     }
///
/// An entry holds copies of the values the system returned,
/// so it doesn't change if the database does.
///
/// The corresponding C type is `struct group`.
/// - Note: Only available on Unix-like platforms other than WASI.
@frozen
@available(System 199, *)
public struct GroupEntry: Sendable, Hashable {
  /// The group's name.
  ///
  /// The corresponding C property is `gr_name`.
  public var name: String

  /// The group's ID.
  ///
  /// The corresponding C property is `gr_gid`.
  public var groupID: GroupID

  /// The login names of the group's members.
  ///
  /// Users whose primary group is this group,
  /// given by ``UserEntry/groupID``,
  /// aren't necessarily listed.
  ///
  /// The corresponding C property is `gr_mem`.
  public var members: [String]
}

@available(System 199, *)
extension GroupEntry {
  /// Looks up the group database entry for a group ID.
  ///
  /// - Parameters:
  ///   - groupID: The group ID to look up.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This initializer returns `nil` if the database has no entry
  /// for `groupID`, and throws if the lookup itself fails.
  ///
  /// The corresponding C function is `getgrgid_r`.
  @_alwaysEmitIntoClient
  public init?(groupID: GroupID, retryOnInterrupt: Bool = true) throws(Errno) {
    guard let entry = try GroupEntry._lookUp(
      groupID: groupID, retryOnInterrupt: retryOnInterrupt
    ).get() else {
      return nil
    }
    self = entry
  }

  /// Looks up the group database entry for a group name.
  ///
  /// - Parameters:
  ///   - name: The group name to look up.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This initializer returns `nil` if the database has no entry
  /// for `name`, and throws if the lookup itself fails.
  ///
  /// The corresponding C function is `getgrnam_r`.
  @_alwaysEmitIntoClient
  public init?(name: String, retryOnInterrupt: Bool = true) throws(Errno) {
    guard let entry = try GroupEntry._lookUp(
      name: name, retryOnInterrupt: retryOnInterrupt
    ).get() else {
      return nil
    }
    self = entry
  }

  @usableFromInline
  internal static func _lookUp(
    groupID: GroupID, retryOnInterrupt: Bool
  ) -> Result<GroupEntry?, Errno> {
    _lookUpEntry(retryOnInterrupt: retryOnInterrupt, GroupEntry.init(_:)) {
      system_getgrgid_r(groupID.rawValue, $0, $1, $2, $3)
    }
  }

  @usableFromInline
  internal static func _lookUp(
    name: String, retryOnInterrupt: Bool
  ) -> Result<GroupEntry?, Errno> {
    name.withCString { name in
      _lookUpEntry(retryOnInterrupt: retryOnInterrupt, GroupEntry.init(_:)) {
        system_getgrnam_r(name, $0, $1, $2, $3)
      }
    }
  }

  // Copies the values out of a C entry, whose strings point into
  // the buffer passed to the lookup function.
  internal init(_ entry: group) {
    var members: [String] = []
    if var member = entry.gr_mem {
      while let name = member.pointee {
        members.append(_string(name))
        member += 1
      }
    }
    self.init(
      name: _string(entry.gr_name),
      groupID: GroupID(rawValue: entry.gr_gid),
      members: members)
  }
}

// MARK: - Lookup

/// The buffer capacity for the first attempt to look up an entry.
internal var _initialEntryBufferCapacity: Int { 1024 }

/// The largest buffer to try before giving up with `ERANGE`.
internal var _maximumEntryBufferCapacity: Int { 1 << 20 }

// Looks up a user or group database entry with a `get*_r` function,
// doubling the size of the buffer it fills while it reports ERANGE.
@available(System 199, *)
internal func _lookUpEntry<CEntry, Entry>(
  retryOnInterrupt: Bool,
  _ makeEntry: (CEntry) -> Entry,
  _ lookUp: (
    UnsafeMutablePointer<CEntry>, UnsafeMutablePointer<CChar>, Int,
    UnsafeMutablePointer<UnsafeMutablePointer<CEntry>?>
  ) -> CInt
) -> Result<Entry?, Errno> {
  var capacity = _initialEntryBufferCapacity
  while true {
    let result = withUnsafeTemporaryAllocation(of: CEntry.self, capacity: 1) { entry in
      withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity) { buffer in
        var found: UnsafeMutablePointer<CEntry>? = nil
        return nothingOrReturnedErrno(retryOnInterrupt: retryOnInterrupt) {
          lookUp(entry.baseAddress!, buffer.baseAddress!, buffer.count, &found)
        }.map {
          // Copy the entry out while the buffer it points into is alive.
          found.map { makeEntry($0.pointee) }
        }
      }
    }
    guard case .failure(.outOfRange) = result,
          capacity < _maximumEntryBufferCapacity
    else {
      return result
    }
    capacity *= 2
  }
}

private func _string(_ cString: UnsafeMutablePointer<CChar>?) -> String {
  cString.map { String(_errorCorrectingPlatformString: $0) } ?? ""
}

private func _path(_ cString: UnsafeMutablePointer<CChar>?) -> FilePath {
  cString.map { FilePath(platformString: $0) } ?? FilePath()
}

#endif // !os(Windows) && !os(WASI)
