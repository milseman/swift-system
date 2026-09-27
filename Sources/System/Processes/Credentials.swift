/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

// Setting the calling process's user and group IDs. They go next to the
// getters in FileSystem/Identifiers.swift: UserID.real and .effective, and
// GroupID.real, .effective, and supplementary().

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension UserID {
  /// Sets the calling process's user IDs.
  ///
  /// - Parameter id: The user ID to set.
  ///
  /// With appropriate privileges, this sets the real and effective user IDs,
  /// and the saved set-user-ID, so a process that drops root this way
  /// can't get it back.
  /// Without them, `id` must be the real user ID or the saved set-user-ID,
  /// and only the effective user ID changes;
  /// otherwise, this method throws ``Errno/notPermitted``.
  ///
  /// A process that changes its group IDs as well changes them first,
  /// since giving up root takes away the privilege to change them.
  ///
  /// The corresponding C function is `setuid`.
  @_alwaysEmitIntoClient
  public static func set(_ id: UserID) throws(Errno) {
    try _set(id).get()
  }

  @usableFromInline
  internal static func _set(_ id: UserID) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_setuid(id.rawValue) }
  }

  /// Sets the calling process's effective user ID.
  ///
  /// - Parameter id: The effective user ID to set.
  ///   Without appropriate privileges,
  ///   it must be the real user ID or the saved set-user-ID.
  ///
  /// A set-user-ID program uses this method to switch
  /// between its real and its saved user ID.
  ///
  /// The corresponding C function is `seteuid`.
  @_alwaysEmitIntoClient
  public static func setEffective(_ id: UserID) throws(Errno) {
    try _setEffective(id).get()
  }

  @usableFromInline
  internal static func _setEffective(_ id: UserID) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_seteuid(id.rawValue) }
  }

  /// Sets the calling process's real and effective user IDs.
  ///
  /// - Parameters:
  ///   - real: The real user ID to set, or `nil` to leave it unchanged.
  ///   - effective: The effective user ID to set,
  ///     or `nil` to leave it unchanged.
  ///
  /// The corresponding C function is `setreuid`.
  @_alwaysEmitIntoClient
  public static func set(real: UserID?, effective: UserID?) throws(Errno) {
    try _set(real: real, effective: effective).get()
  }

  @usableFromInline
  internal static func _set(real: UserID?, effective: UserID?) -> Result<(), Errno> {
    // (uid_t)-1 leaves an ID unchanged.
    nothingOrErrno(retryOnInterrupt: false) {
      system_setreuid(real?.rawValue ?? .max, effective?.rawValue ?? .max)
    }
  }
}

@available(System 199, *)
extension GroupID {
  /// Sets the calling process's group IDs.
  ///
  /// - Parameter id: The group ID to set.
  ///
  /// With appropriate privileges, this sets the real and effective group IDs,
  /// and the saved set-group-ID.
  /// Without them, `id` must be the real group ID or the saved set-group-ID,
  /// and only the effective group ID changes;
  /// otherwise, this method throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `setgid`.
  @_alwaysEmitIntoClient
  public static func set(_ id: GroupID) throws(Errno) {
    try _set(id).get()
  }

  @usableFromInline
  internal static func _set(_ id: GroupID) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_setgid(id.rawValue) }
  }

  /// Sets the calling process's effective group ID.
  ///
  /// - Parameter id: The effective group ID to set.
  ///   Without appropriate privileges,
  ///   it must be the real group ID or the saved set-group-ID.
  ///
  /// The corresponding C function is `setegid`.
  @_alwaysEmitIntoClient
  public static func setEffective(_ id: GroupID) throws(Errno) {
    try _setEffective(id).get()
  }

  @usableFromInline
  internal static func _setEffective(_ id: GroupID) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_setegid(id.rawValue) }
  }

  /// Sets the calling process's real and effective group IDs.
  ///
  /// - Parameters:
  ///   - real: The real group ID to set, or `nil` to leave it unchanged.
  ///   - effective: The effective group ID to set,
  ///     or `nil` to leave it unchanged.
  ///
  /// The corresponding C function is `setregid`.
  @_alwaysEmitIntoClient
  public static func set(real: GroupID?, effective: GroupID?) throws(Errno) {
    try _set(real: real, effective: effective).get()
  }

  @usableFromInline
  internal static func _set(real: GroupID?, effective: GroupID?) -> Result<(), Errno> {
    // (gid_t)-1 leaves an ID unchanged.
    nothingOrErrno(retryOnInterrupt: false) {
      system_setregid(real?.rawValue ?? .max, effective?.rawValue ?? .max)
    }
  }

  /// Sets the calling process's supplementary group IDs.
  ///
  /// - Parameter groups: The supplementary groups to set.
  ///
  /// Setting them takes appropriate privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// More groups than the system allows,
  /// `SystemConfig.Name.maxSupplementaryGroups`,
  /// throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `setgroups`.
  @_alwaysEmitIntoClient
  public static func setSupplementary(_ groups: [GroupID]) throws(Errno) {
    try _setSupplementary(groups).get()
  }

  @usableFromInline
  internal static func _setSupplementary(_ groups: [GroupID]) -> Result<(), Errno> {
    groups.withUnsafeBufferPointer { groups in
      groups.withMemoryRebound(to: CInterop.GroupID.self) { groups in
        nothingOrErrno(retryOnInterrupt: false) {
          system_setgroups(groups.count, groups.baseAddress)
        }
      }
    }
  }

  /// Sets the calling process's supplementary group IDs
  /// to a user's groups, from the group database, and one more.
  ///
  /// - Parameters:
  ///   - user: The name of the user whose groups to set.
  ///   - group: A group to include as well,
  ///     typically the user's primary group.
  ///
  /// A login program calls this method
  /// before it sets the process's group and user IDs.
  /// Setting the groups takes appropriate privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `initgroups`.
  @_alwaysEmitIntoClient
  public static func setSupplementary(
    forUser user: String, including group: GroupID
  ) throws(Errno) {
    try _setSupplementary(forUser: user, including: group).get()
  }

  @usableFromInline
  internal static func _setSupplementary(
    forUser user: String, including group: GroupID
  ) -> Result<(), Errno> {
    user.withCString { user in
      nothingOrErrno(retryOnInterrupt: false) {
        system_initgroups(user, group.rawValue)
      }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
