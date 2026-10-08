/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Access rights

@available(System 199, *)
extension Win32 {
  /// The access rights to request for a handle to an access token.
  ///
  /// Each operation on ``Win32/TokenHandle`` says which rights it needs.
  ///
  /// The corresponding C type is `ACCESS_MASK`, as `OpenProcessToken`'s
  /// `DesiredAccess`.
  @frozen
  public struct TokenAccess: OptionSet, Sendable, Hashable, Codable {
    /// The raw C access mask.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed access mask from a raw C access mask.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The right to make the token a new process's primary token.
    ///
    /// The corresponding C constant is `TOKEN_ASSIGN_PRIMARY`.
    @_alwaysEmitIntoClient
    public static var assignPrimary: TokenAccess { TokenAccess(rawValue: 0x0001) }

    /// The right to duplicate the token.
    ///
    /// The corresponding C constant is `TOKEN_DUPLICATE`.
    @_alwaysEmitIntoClient
    public static var duplicate: TokenAccess { TokenAccess(rawValue: 0x0002) }

    /// The right to impersonate the token's user.
    ///
    /// The corresponding C constant is `TOKEN_IMPERSONATE`.
    @_alwaysEmitIntoClient
    public static var impersonate: TokenAccess { TokenAccess(rawValue: 0x0004) }

    /// The right to read what the token holds: its user, its groups, and
    /// the rest.
    ///
    /// The corresponding C constant is `TOKEN_QUERY`.
    @_alwaysEmitIntoClient
    public static var query: TokenAccess { TokenAccess(rawValue: 0x0008) }

    /// The right to read the token's source.
    ///
    /// The corresponding C constant is `TOKEN_QUERY_SOURCE`.
    @_alwaysEmitIntoClient
    public static var querySource: TokenAccess { TokenAccess(rawValue: 0x0010) }

    /// The right to enable and disable the token's privileges.
    ///
    /// The corresponding C constant is `TOKEN_ADJUST_PRIVILEGES`.
    @_alwaysEmitIntoClient
    public static var adjustPrivileges: TokenAccess { TokenAccess(rawValue: 0x0020) }

    /// The right to enable and disable the token's groups.
    ///
    /// The corresponding C constant is `TOKEN_ADJUST_GROUPS`.
    @_alwaysEmitIntoClient
    public static var adjustGroups: TokenAccess { TokenAccess(rawValue: 0x0040) }

    /// The right to change the token's default owner, primary group, and
    /// access control list, which the objects it creates get.
    ///
    /// The corresponding C constant is `TOKEN_ADJUST_DEFAULT`.
    @_alwaysEmitIntoClient
    public static var adjustDefault: TokenAccess { TokenAccess(rawValue: 0x0080) }

    /// The right to change the token's session.
    ///
    /// The corresponding C constant is `TOKEN_ADJUST_SESSIONID`.
    @_alwaysEmitIntoClient
    public static var adjustSessionID: TokenAccess { TokenAccess(rawValue: 0x0100) }

    /// The right to delete the token object.
    ///
    /// The corresponding C constant is `DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: TokenAccess { TokenAccess(rawValue: 0x0001_0000) }

    /// The right to read the token's security descriptor, not including
    /// its system access control list.
    ///
    /// The corresponding C constant is `READ_CONTROL`.
    @_alwaysEmitIntoClient
    public static var readControl: TokenAccess { TokenAccess(rawValue: 0x0002_0000) }

    /// The right to change the token's discretionary access control list.
    ///
    /// The corresponding C constant is `WRITE_DAC`.
    @_alwaysEmitIntoClient
    public static var writeDAC: TokenAccess { TokenAccess(rawValue: 0x0004_0000) }

    /// The right to change the token's owner.
    ///
    /// The corresponding C constant is `WRITE_OWNER`.
    @_alwaysEmitIntoClient
    public static var writeOwner: TokenAccess { TokenAccess(rawValue: 0x0008_0000) }

    /// The rights to read the token: ``query`` and ``readControl``.
    ///
    /// The corresponding C constant is `TOKEN_READ`.
    @_alwaysEmitIntoClient
    public static var read: TokenAccess { TokenAccess(rawValue: 0x0002_0008) }

    /// Every right a token handle can have.
    ///
    /// The corresponding C constant is `TOKEN_ALL_ACCESS`.
    @_alwaysEmitIntoClient
    public static var all: TokenAccess { TokenAccess(rawValue: 0x000F_01FF) }

    /// Every right the access check finds the caller entitled to.
    ///
    /// This doesn't name a right, and never appears in a mask the system
    /// reports.
    ///
    /// The corresponding C constant is `MAXIMUM_ALLOWED`.
    @_alwaysEmitIntoClient
    public static var maximumAllowed: TokenAccess { TokenAccess(rawValue: 0x0200_0000) }
  }
}

// MARK: - The handle

@available(System 199, *)
extension Win32 {
  /// An open access token: the security context of a process or a thread.
  ///
  /// A token holds the user it acts for, the user's groups and
  /// privileges, and the rest of what Windows checks a process's access
  /// with; every process has one, its primary token, and a thread that
  /// impersonates another user has one of its own. A token is Windows'
  /// counterpart of POSIX's user and group IDs.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope
  /// and discards the error.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct TokenHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw token handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL`.
    ///
    /// - Warning: This initializer doesn't check that `raw` is a handle to
    ///   an access token. Don't pass a pseudo handle, such as the one
    ///   `GetCurrentProcessToken` returns, which isn't to be closed.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw else { return nil }
      self._handle = raw
    }

    /// The raw C handle. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawHandle: HANDLE { _handle }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> HANDLE {
      let handle = _handle
      discard self
      return handle
    }

    /// Closes this handle.
    ///
    /// The handle is closed whether this method returns or throws.
    ///
    /// The corresponding C function is `CloseHandle`.
    @_alwaysEmitIntoClient
    public consuming func close() throws(Win32.Error) {
      let handle = _handle
      discard self
      try Win32._closeHandle(handle).get()
    }

    deinit {
      _ = system_CloseHandle(_handle)
    }
  }
}

// MARK: - Opening

@available(System 199, *)
extension Win32.TokenHandle {
  /// Opens a process's primary token.
  ///
  /// - Parameters:
  ///   - process: The process, whose handle needs
  ///     ``Win32/ProcessAccess/queryLimitedInformation``. For the calling
  ///     process, pass ``Win32/ProcessHandle/current``.
  ///   - access: The access rights to request. An open that requests a
  ///     right the token's security descriptor withholds fails with
  ///     ``Win32/Error/accessDenied``.
  ///
  /// The corresponding C function is `OpenProcessToken`.
  @_alwaysEmitIntoClient
  public static func open(
    process: borrowing Win32.ProcessHandle,
    access: Win32.TokenAccess
  ) throws(Win32.Error) -> Win32.TokenHandle {
    Win32.TokenHandle(
      _owning: try Win32.TokenHandle._open(process._handle, access: access.rawValue).get())
  }
}

// MARK: - Operations

@available(System 199, *)
extension Win32.TokenHandle {
  /// The user the token acts for.
  ///
  /// Needs ``Win32/TokenAccess/query``.
  ///
  /// The corresponding C function is `GetTokenInformation`, with
  /// `TokenUser`.
  @_alwaysEmitIntoClient
  public func user() throws(Win32.Error) -> Win32.SecurityIdentifier {
    Win32.SecurityIdentifier(_bytes: try Win32.TokenHandle._user(_handle).get())
  }

  /// Whether the token is elevated: whether it has the administrative
  /// rights that User Account Control keeps from an administrator until
  /// they're asked for, as "Run as administrator" asks.
  ///
  /// An administrator's token that isn't elevated holds the administrative
  /// groups only to deny access. The local system account's token is
  /// elevated.
  ///
  /// Needs ``Win32/TokenAccess/query``.
  ///
  /// The corresponding C function is `GetTokenInformation`, with
  /// `TokenElevation` and a `TOKEN_ELEVATION`.
  @_alwaysEmitIntoClient
  public func isElevated() throws(Win32.Error) -> Bool {
    try Win32.TokenHandle._isElevated(_handle).get()
  }

  /// The user's profile directory: their home directory, such as
  /// `C:\Users\name`.
  ///
  /// Needs ``Win32/TokenAccess/query``.
  ///
  /// The `USERPROFILE` environment variable normally names the same
  /// directory, but a process can change its environment, and the
  /// variable names the calling process's user, not the token's.
  ///
  /// The corresponding C function is `GetUserProfileDirectoryW`.
  @_alwaysEmitIntoClient
  public func profileDirectory() throws(Win32.Error) -> FilePath {
    try Win32.TokenHandle._profileDirectory(_handle).get()
  }
}

// MARK: - The calling thread's user

@available(System 199, *)
extension Win32 {
  /// The name of the user the calling thread acts for, without its
  /// domain.
  ///
  /// That's the user of the thread's token, if it's impersonating one, and
  /// otherwise its process's.
  ///
  /// The corresponding C function is `GetUserNameW`, with a buffer of
  /// `UNLEN` + 1 characters, which grows if the name needs more.
  @_alwaysEmitIntoClient
  public static func userName() throws(Win32.Error) -> String {
    try _userName().get()
  }

  /// A form of a user's name, for ``userName(format:)``.
  ///
  /// The corresponding C type is `EXTENDED_NAME_FORMAT`.
  @frozen
  public struct UserNameFormat: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed format from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The distinguished name of the user's directory object, such as
    /// `CN=Jeff Smith,OU=Users,DC=Engineering,DC=Example,DC=Com`.
    ///
    /// The corresponding C constant is `NameFullyQualifiedDN`.
    @_alwaysEmitIntoClient
    public static var fullyQualifiedDistinguishedName: UserNameFormat {
      UserNameFormat(rawValue: 1)
    }

    /// The name after its domain and a backslash, `DOMAIN\name`, the form
    /// that every account has.
    ///
    /// The corresponding C constant is `NameSamCompatible`.
    @_alwaysEmitIntoClient
    public static var samCompatible: UserNameFormat { UserNameFormat(rawValue: 2) }

    /// The user's display name, such as `Jeff Smith`.
    ///
    /// The corresponding C constant is `NameDisplay`.
    @_alwaysEmitIntoClient
    public static var display: UserNameFormat { UserNameFormat(rawValue: 3) }

    /// The GUID of the user's directory object, in braces.
    ///
    /// The corresponding C constant is `NameUniqueId`.
    @_alwaysEmitIntoClient
    public static var uniqueID: UserNameFormat { UserNameFormat(rawValue: 6) }

    /// The user's canonical name, such as
    /// `engineering.example.com/software/someone`.
    ///
    /// The corresponding C constant is `NameCanonical`.
    @_alwaysEmitIntoClient
    public static var canonical: UserNameFormat { UserNameFormat(rawValue: 7) }

    /// The user principal name, such as `someone@example.com`.
    ///
    /// The corresponding C constant is `NameUserPrincipal`.
    @_alwaysEmitIntoClient
    public static var userPrincipal: UserNameFormat { UserNameFormat(rawValue: 8) }

    /// The canonical name, with a line feed before its last component.
    ///
    /// The corresponding C constant is `NameCanonicalEx`.
    @_alwaysEmitIntoClient
    public static var canonicalEx: UserNameFormat { UserNameFormat(rawValue: 9) }

    /// The service principal name, such as `www/www.example.com@example.com`.
    ///
    /// The corresponding C constant is `NameServicePrincipal`.
    @_alwaysEmitIntoClient
    public static var servicePrincipal: UserNameFormat { UserNameFormat(rawValue: 10) }

    /// The DNS domain's name, after a backslash, as in
    /// `engineering.example.com\name`.
    ///
    /// The corresponding C constant is `NameDnsDomain`.
    @_alwaysEmitIntoClient
    public static var dnsDomain: UserNameFormat { UserNameFormat(rawValue: 12) }

    /// The user's first name.
    ///
    /// The corresponding C constant is `NameGivenName`.
    @_alwaysEmitIntoClient
    public static var givenName: UserNameFormat { UserNameFormat(rawValue: 13) }

    /// The user's last name.
    ///
    /// The corresponding C constant is `NameSurname`.
    @_alwaysEmitIntoClient
    public static var surname: UserNameFormat { UserNameFormat(rawValue: 14) }
  }

  /// A form of the name of the user the calling thread acts for.
  ///
  /// - Parameter format: Which form. Only an account of a domain has the
  ///   others; a local account, outside a domain, has only
  ///   ``UserNameFormat/samCompatible``.
  ///
  /// Throws ``Win32/Error/noneMapped`` if the user has no name in
  /// `format`, and ``Win32/Error/noSuchDomain`` if the domain's controller
  /// can't be reached to look the name up.
  ///
  /// The corresponding C function is `GetUserNameExW`.
  @_alwaysEmitIntoClient
  public static func userName(format: Win32.UserNameFormat) throws(Win32.Error) -> String {
    try _userName(format: format.rawValue).get()
  }

  /// Whether a group is enabled in the calling thread's security context:
  /// in its token, if it's impersonating a user, and otherwise in its
  /// process's.
  ///
  /// - Parameter group: The group's security identifier, such as
  ///   ``Win32/SecurityIdentifier/WellKnown/builtinAdministrators``'s.
  ///
  /// A group that a token holds only to deny access, such as an
  /// administrator's administrative groups in a token that isn't
  /// elevated, isn't enabled.
  ///
  /// The corresponding C function is `CheckTokenMembership`, with a `NULL`
  /// token.
  @_alwaysEmitIntoClient
  public static func callingThreadIsMember(
    of group: Win32.SecurityIdentifier
  ) throws(Win32.Error) -> Bool {
    try _callingThreadIsMember(of: group).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32.TokenHandle {
  @usableFromInline
  internal static func _open(_ process: HANDLE, access: DWORD) -> Result<HANDLE, Win32.Error> {
    var token: HANDLE? = nil
    guard system_OpenProcessToken(process, access, &token), let token else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(token)
  }

  @usableFromInline
  internal static func _user(_ handle: HANDLE) -> Result<[UInt8], Win32.Error> {
    // A TOKEN_USER, followed by the identifier it points to: 16 bytes and
    // at most 68.
    var capacity = 128
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        byteCount: capacity, alignment: MemoryLayout<TOKEN_USER>.alignment
      ) { buffer -> _Win32SizedResult<[UInt8]> in
        var size = DWORD(buffer.count)
        guard system_GetTokenInformation(
          handle, TokenUser, buffer.baseAddress, DWORD(buffer.count), &size
        ) else {
          let error = GetLastError()
          if error == Win32.Error.insufficientBuffer.rawValue {
            return .retry(capacity: max(Int(size), buffer.count + 1))
          }
          return .failure(Win32.Error(error))
        }
        let user = buffer.baseAddress!.load(as: TOKEN_USER.self)
        guard let sid = user.User.Sid, let bytes = Win32.SecurityIdentifier._copy(sid) else {
          return .failure(.invalidSecurityIdentifier)
        }
        return .success(bytes)
      }
      switch outcome {
      case .success(let bytes): return .success(bytes)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }

  @usableFromInline
  internal static func _isElevated(_ handle: HANDLE) -> Result<Bool, Win32.Error> {
    var elevation = TOKEN_ELEVATION()
    var size = DWORD(0)
    guard system_GetTokenInformation(
      handle, TokenElevation, &elevation, DWORD(MemoryLayout<TOKEN_ELEVATION>.size), &size
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(elevation.TokenIsElevated != 0)
  }

  @usableFromInline
  internal static func _profileDirectory(_ handle: HANDLE) -> Result<FilePath, Win32.Error> {
    var capacity = _win32MaxPath
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<FilePath> in
        // In, the buffer's size; out, when it's too small, the size it
        // needs, with the terminator. The path ends at its terminator.
        var size = DWORD(buffer.count)
        guard system_GetUserProfileDirectoryW(handle, buffer.baseAddress, &size) else {
          let error = GetLastError()
          if error == Win32.Error.insufficientBuffer.rawValue {
            return .retry(capacity: max(Int(size), buffer.count + 1))
          }
          return .failure(Win32.Error(error))
        }
        return .success(FilePath(platformString: buffer.baseAddress!))
      }
      switch outcome {
      case .success(let path): return .success(path)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _userName() -> Result<String, Win32.Error> {
    var capacity = _UNLEN + 1
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<String> in
        // In, the buffer's size; out, the name's, or the size the buffer
        // needs, with the terminator either way.
        var size = DWORD(buffer.count)
        guard system_GetUserNameW(buffer.baseAddress, &size) else {
          let error = GetLastError()
          if error == Win32.Error.insufficientBuffer.rawValue {
            return .retry(capacity: max(Int(size), buffer.count + 1))
          }
          return .failure(Win32.Error(error))
        }
        return .success(String(decodingCString: buffer.baseAddress!, as: UTF16.self))
      }
      switch outcome {
      case .success(let name): return .success(name)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }

  @usableFromInline
  internal static func _userName(format: CInt) -> Result<String, Win32.Error> {
    var capacity = 64
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<String> in
        // In, the buffer's size; out, the name's, without the terminator,
        // or the size the buffer needs, with it.
        var size = ULONG(buffer.count)
        guard system_GetUserNameExW(format, buffer.baseAddress, &size) else {
          let error = GetLastError()
          if error == Win32.Error.moreData.rawValue {
            return .retry(capacity: max(Int(size), buffer.count + 1))
          }
          return .failure(Win32.Error(error))
        }
        return .success(String(
          decoding: UnsafeBufferPointer(start: buffer.baseAddress, count: Int(size)),
          as: UTF16.self))
      }
      switch outcome {
      case .success(let name): return .success(name)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }

  @usableFromInline
  internal static func _callingThreadIsMember(
    of group: Win32.SecurityIdentifier
  ) -> Result<Bool, Win32.Error> {
    var isMember: WindowsBool = false
    let error: DWORD? = group._withSID { sid in
      system_CheckTokenMembership(nil, sid, &isMember) ? nil : GetLastError()
    }
    if let error { return .failure(Win32.Error(error)) }
    return .success(isMember.boolValue)
  }
}

#endif // os(Windows)
