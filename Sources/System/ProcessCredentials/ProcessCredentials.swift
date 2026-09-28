/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Credential queries beside the processes lane's setters
// (Processes/Credentials.swift) and the getters in
// FileSystem/Identifiers.swift.

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

// MARK: - Set-user-ID processes

@available(System 199, *)
extension ProcessID {
  /// Whether the calling process runs with privileges
  /// that the user who started it doesn't have,
  /// as a set-user-ID or set-group-ID program does.
  ///
  /// Such a process shouldn't trust its environment,
  /// which the less privileged user chose:
  /// ``ProcessEnvironment/secureValue(of:)`` reads a variable only if this
  /// is `false`.
  ///
  /// When this becomes `true` differs by platform.
  /// On Darwin and the BSDs, it's `true` for a program that ran set-user-ID
  /// or set-group-ID, and for one that has since changed
  /// any of its user or group IDs.
  /// On Linux and Android, it's the kernel's secure-execution mode,
  /// decided when the program started: `true` when its effective IDs
  /// differed from its real ones, or it gained capabilities,
  /// and unchanged by later changes of ID.
  ///
  /// The corresponding C function is `issetugid`.
  /// On Linux and Android, it's `getauxval(AT_SECURE)`.
  @_alwaysEmitIntoClient
  public static var isSetUserOrGroupID: Bool { _isSetUserOrGroupID }

  @usableFromInline
  internal static var _isSetUserOrGroupID: Bool {
    system_isSecureExecution()
  }
}

@available(System 199, *)
extension ProcessEnvironment {
  /// Returns the value of an environment variable,
  /// or `nil` if it isn't set, or the process is set-user-ID.
  ///
  /// - Parameter name: The variable's name.
  ///
  /// A set-user-ID or set-group-ID program,
  /// ``ProcessID/isSetUserOrGroupID``,
  /// gets `nil` for every variable,
  /// since the user who started it chose them.
  /// Use this method for variables that name files to trust,
  /// such as `TMPDIR` or `HOME`.
  ///
  /// The corresponding C function is glibc's `secure_getenv`,
  /// and elsewhere `getenv` after `issetugid`.
  @_alwaysEmitIntoClient
  public static func secureValue(of name: String) -> String? {
    _secureValue(of: name)
  }

  @usableFromInline
  internal static func _secureValue(of name: String) -> String? {
    ProcessID._isSetUserOrGroupID ? nil : value(of: name)
  }
}

// MARK: - A user's groups

@available(System 199, *)
extension GroupID {
  /// Returns the groups that the group database lists a user in,
  /// and one more.
  ///
  /// - Parameters:
  ///   - user: The name of the user whose groups to find.
  ///   - group: A group to include as well,
  ///     typically the user's primary group, ``UserEntry/groupID``.
  /// - Returns: `group`, first, and the groups the user is a member of.
  ///
  /// These are the groups that
  /// ``UserID/setSupplementary(forUser:including:)`` sets.
  /// A user that the group database doesn't know
  /// is in no groups but `group`.
  /// Darwin also lists `(gid_t)-1` for such a user,
  /// which isn't a group, and which this method leaves out.
  ///
  /// The corresponding C function is `getgrouplist`.
  @_alwaysEmitIntoClient
  public static func supplementary(
    forUser user: String, including group: GroupID
  ) throws(Errno) -> [GroupID] {
    try _supplementary(forUser: user, including: group).get()
  }

  @usableFromInline
  internal static func _supplementary(
    forUser user: String, including group: GroupID
  ) -> Result<[GroupID], Errno> {
    user.withCString { user in
      // getgrouplist returns -1 when the groups don't fit. glibc then says
      // how many there are, and Darwin doesn't.
      var capacity = _initialSupplementaryCapacity
      while capacity <= 1 << 17 {
        var count = CInt(capacity)
        var fits = false
        let groups = [GroupID](unsafeUninitializedCapacity: capacity) { buffer, initialized in
          buffer.withMemoryRebound(to: CInterop.GroupID.self) { buffer in
            fits = system_getgrouplist(
              user, group.rawValue, buffer.baseAddress!, &count) != -1
          }
          initialized = fits ? min(Int(count), capacity) : 0
        }
        if fits {
          return .success(groups.filter { $0.rawValue != CInterop.GroupID.max })
        }
        capacity = max(capacity * 4, Int(count))
      }
      return .failure(.outOfRange)
    }
  }
}

// MARK: - A thread's own credentials

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension PThread {
  /// Returns the user and group IDs that the calling thread acts as,
  /// if it has its own, rather than its process's.
  ///
  /// - Returns: The thread's user and group IDs,
  ///   or `nil` if it acts as its process,
  ///   whose IDs are ``UserID/effective`` and ``GroupID/effective``.
  ///
  /// A privileged server's thread can act as a client this way,
  /// with credentials of its own that apply only to that thread.
  /// Setting them, with `pthread_setugid_np`, is deprecated,
  /// and isn't wrapped.
  ///
  /// The corresponding C function is `pthread_getugid_np`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func credentials() throws(Errno) -> (user: UserID, group: GroupID)? {
    try _credentials().get()
  }

  @usableFromInline
  internal static func _credentials() -> Result<(user: UserID, group: GroupID)?, Errno> {
    var user = CInterop.UserID()
    var group = CInterop.GroupID()
    switch nothingOrErrno(retryOnInterrupt: false, {
      system_pthread_getugid_np(&user, &group)
    }) {
    case .success:
      return .success((UserID(rawValue: user), GroupID(rawValue: group)))
    case .failure(.noSuchProcess):
      // The thread has no credentials of its own.
      return .success(nil)
    case .failure(let error):
      return .failure(error)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#endif // !os(Windows) && !os(WASI)
