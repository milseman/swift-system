/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Security identifiers

@available(System 199, *)
extension Win32 {
  /// A security identifier: the value that names a user, a group, a
  /// computer, or another security principal to Windows.
  ///
  /// An identifier is an identifier authority and up to 15 subauthorities,
  /// written as `S-1-` and those numbers: the Administrators group's,
  /// `S-1-5-32-544`, is authority 5 with subauthorities 32 and 544.
  ///
  /// This type holds an identifier's C form, its bytes, so a copy is a value
  /// that compares and hashes by them, as `EqualSid` compares identifiers.
  /// ``withUnsafeBytes(_:)`` lends them to a Windows function that takes a
  /// `PSID`.
  ///
  /// The corresponding C type is `SID`.
  @frozen
  public struct SecurityIdentifier: Hashable, Sendable {
    // The SID's bytes: its revision, 1; its count of subauthorities; its
    // authority, 6 bytes, big-endian; and its subauthorities, 4 bytes each,
    // little-endian.
    @usableFromInline
    internal var _bytes: [UInt8]

    @_alwaysEmitIntoClient
    internal init(_bytes bytes: [UInt8]) {
      self._bytes = bytes
    }
  }
}

@available(System 199, *)
extension Win32.SecurityIdentifier {
  /// Creates a security identifier from its authority and subauthorities.
  ///
  /// - Parameters:
  ///   - authority: The identifier authority, which is 48 bits. Windows
  ///     issues its own identifiers under authority 5,
  ///     `SECURITY_NT_AUTHORITY`.
  ///   - subauthorities: The subauthorities, at most 15.
  ///
  /// - Precondition: `authority` fits in 48 bits, and there are at most 15
  ///   subauthorities.
  ///
  /// This is the identifier that C builds with `InitializeSid` and
  /// `GetSidSubAuthority`, or allocates with `AllocateAndInitializeSid`.
  @_alwaysEmitIntoClient
  public init(authority: UInt64, subauthorities: [UInt32]) {
    self.init(
      _bytes: Win32.SecurityIdentifier._bytes(authority: authority, subauthorities: subauthorities))
  }

  /// The identifier authority.
  @_alwaysEmitIntoClient
  public var authority: UInt64 { _authority }

  /// The subauthorities, which follow the authority.
  @_alwaysEmitIntoClient
  public var subauthorities: [UInt32] { _subauthorities }

  /// Parses a security identifier's string form, such as `S-1-5-32-544`,
  /// or the abbreviation that the Security Descriptor Definition Language
  /// gives a well-known identifier, such as `BA` for the Administrators
  /// group.
  ///
  /// Throws ``Win32/Error/invalidSecurityIdentifier`` for a string that's
  /// neither, or that holds a null character.
  ///
  /// The corresponding C function is `ConvertStringSidToSidW`.
  @_alwaysEmitIntoClient
  public init(_ string: String) throws(Win32.Error) {
    self.init(_bytes: try Win32.SecurityIdentifier._parse(string).get())
  }

  /// Creates a security identifier that Windows defines.
  ///
  /// - Parameters:
  ///   - wellKnown: Which identifier.
  ///   - domain: The domain's identifier, for an identifier that's relative
  ///     to a domain, such as its administrator account's. Pass `nil`, the
  ///     default, for the others, which are the same on every computer; a
  ///     domain's identifier is ignored for them.
  ///
  /// Throws if `wellKnown` needs a domain and `domain` is `nil`.
  ///
  /// The corresponding C function is `CreateWellKnownSid`.
  @_alwaysEmitIntoClient
  public init(
    _ wellKnown: Win32.SecurityIdentifier.WellKnown,
    domain: Win32.SecurityIdentifier? = nil
  ) throws(Win32.Error) {
    self.init(
      _bytes: try Win32.SecurityIdentifier._wellKnown(wellKnown.rawValue, domain: domain).get())
  }

  /// Looks up the security identifier of the account with a name.
  ///
  /// - Parameter accountName: The account's name, alone, such as
  ///   `Administrators`, or with its domain, as `DOMAIN\name`, or as a user
  ///   principal name, `name@domain`. A name alone is looked up first among
  ///   the well-known identifiers, then the computer's built-in and local
  ///   accounts, then its domain, and then the domains its domain trusts.
  ///
  /// This initializer returns `nil` if no account has the name, and throws
  /// if the lookup itself fails. Names are compared without regard to case.
  ///
  /// The corresponding C function is `LookupAccountNameW`.
  @_alwaysEmitIntoClient
  public init?(accountName: String) throws(Win32.Error) {
    guard let bytes = try Win32.SecurityIdentifier._lookUp(accountName: accountName).get() else {
      return nil
    }
    self.init(_bytes: bytes)
  }

  /// Copies a security identifier from its C form.
  ///
  /// Returns `nil` if `sid` is `NULL`, or isn't an identifier of revision
  /// 1 with at most 15 subauthorities.
  ///
  /// - Warning: `sid` must point to as many bytes as its count of
  ///   subauthorities says: 8, and 4 for each.
  @_alwaysEmitIntoClient
  @unsafe
  public init?(unsafeCopying sid: PSID?) {
    guard let sid, let bytes = Win32.SecurityIdentifier._copy(sid) else { return nil }
    self.init(_bytes: bytes)
  }

  /// Calls a closure with the identifier's C form.
  ///
  /// - Parameter body: A closure that takes the identifier's bytes, which
  ///   are valid only until it returns. A Windows function that reads a
  ///   `PSID` takes the buffer's base address, which is never `nil`.
  /// - Returns: What `body` returns.
  @_alwaysEmitIntoClient
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try _bytes.withUnsafeBytes(body)
  }
}

@available(System 199, *)
extension Win32.SecurityIdentifier: CustomStringConvertible, CustomDebugStringConvertible {
  /// The identifier's string form, such as `S-1-5-32-544`, as
  /// `ConvertSidToStringSidW` writes it: an authority that doesn't fit in
  /// 32 bits is written as 12 hexadecimal digits after `0x`.
  @inline(never)
  public var description: String {
    let authority = _authority
    var result = "S-\(_bytes[0])-"
    if authority >> 32 == 0 {
      result += String(authority)
    } else {
      let digits = String(authority, radix: 16)
      result += "0x" + String(repeating: "0", count: 12 - digits.count) + digits
    }
    for subauthority in _subauthorities {
      result += "-\(subauthority)"
    }
    return result
  }

  /// The identifier's string form, as ``description`` gives it.
  public var debugDescription: String { description }
}

// MARK: - Well-known identifiers

@available(System 199, *)
extension Win32.SecurityIdentifier {
  /// A security identifier that Windows defines, for
  /// ``init(_:domain:)``.
  ///
  /// Each one's doc gives its account's English name and its string form.
  ///
  /// The corresponding C type is `WELL_KNOWN_SID_TYPE`.
  @frozen
  public struct WellKnown: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed identifier from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// No security principal, `NULL SID`: `S-1-0-0`.
    ///
    /// The corresponding C constant is `WinNullSid`.
    @_alwaysEmitIntoClient
    public static var null: WellKnown { WellKnown(rawValue: 0) }

    /// Every user, `Everyone`: `S-1-1-0`.
    ///
    /// The corresponding C constant is `WinWorldSid`.
    @_alwaysEmitIntoClient
    public static var everyone: WellKnown { WellKnown(rawValue: 1) }

    /// The users who log on at the computer's console, `LOCAL`: `S-1-2-0`.
    ///
    /// The corresponding C constant is `WinLocalSid`.
    @_alwaysEmitIntoClient
    public static var local: WellKnown { WellKnown(rawValue: 2) }

    /// A placeholder for the creator of an object, `CREATOR OWNER`, in an
    /// inheritable access control entry: `S-1-3-0`.
    ///
    /// The corresponding C constant is `WinCreatorOwnerSid`.
    @_alwaysEmitIntoClient
    public static var creatorOwner: WellKnown { WellKnown(rawValue: 3) }

    /// A placeholder for the primary group of an object's creator,
    /// `CREATOR GROUP`, in an inheritable access control entry: `S-1-3-1`.
    ///
    /// The corresponding C constant is `WinCreatorGroupSid`.
    @_alwaysEmitIntoClient
    public static var creatorGroup: WellKnown { WellKnown(rawValue: 4) }

    /// The users who log on across a network, `NETWORK`: `S-1-5-2`.
    ///
    /// The corresponding C constant is `WinNetworkSid`.
    @_alwaysEmitIntoClient
    public static var network: WellKnown { WellKnown(rawValue: 9) }

    /// The users who log on as a batch job, `BATCH`: `S-1-5-3`.
    ///
    /// The corresponding C constant is `WinBatchSid`.
    @_alwaysEmitIntoClient
    public static var batch: WellKnown { WellKnown(rawValue: 10) }

    /// The users who log on interactively, `INTERACTIVE`: `S-1-5-4`.
    ///
    /// The corresponding C constant is `WinInteractiveSid`.
    @_alwaysEmitIntoClient
    public static var interactive: WellKnown { WellKnown(rawValue: 11) }

    /// The accounts that log on as a service, `SERVICE`: `S-1-5-6`.
    ///
    /// The corresponding C constant is `WinServiceSid`.
    @_alwaysEmitIntoClient
    public static var service: WellKnown { WellKnown(rawValue: 12) }

    /// A user who logs on without credentials, `ANONYMOUS LOGON`: `S-1-5-7`.
    ///
    /// The corresponding C constant is `WinAnonymousSid`.
    @_alwaysEmitIntoClient
    public static var anonymous: WellKnown { WellKnown(rawValue: 13) }

    /// The users who log on with credentials, `Authenticated Users`:
    /// `S-1-5-11`.
    ///
    /// The corresponding C constant is `WinAuthenticatedUserSid`.
    @_alwaysEmitIntoClient
    public static var authenticatedUsers: WellKnown { WellKnown(rawValue: 17) }

    /// The operating system's own account, `SYSTEM`: `S-1-5-18`.
    ///
    /// The corresponding C constant is `WinLocalSystemSid`.
    @_alwaysEmitIntoClient
    public static var localSystem: WellKnown { WellKnown(rawValue: 22) }

    /// The account that services with few rights run as,
    /// `LOCAL SERVICE`: `S-1-5-19`.
    ///
    /// The corresponding C constant is `WinLocalServiceSid`.
    @_alwaysEmitIntoClient
    public static var localService: WellKnown { WellKnown(rawValue: 23) }

    /// The account that services with few rights run as, which presents
    /// the computer's credentials to the network, `NETWORK SERVICE`:
    /// `S-1-5-20`.
    ///
    /// The corresponding C constant is `WinNetworkServiceSid`.
    @_alwaysEmitIntoClient
    public static var networkService: WellKnown { WellKnown(rawValue: 24) }

    /// The computer's administrators, `BUILTIN\Administrators`:
    /// `S-1-5-32-544`.
    ///
    /// The corresponding C constant is `WinBuiltinAdministratorsSid`.
    @_alwaysEmitIntoClient
    public static var builtinAdministrators: WellKnown { WellKnown(rawValue: 26) }

    /// The computer's users, `BUILTIN\Users`: `S-1-5-32-545`.
    ///
    /// The corresponding C constant is `WinBuiltinUsersSid`.
    @_alwaysEmitIntoClient
    public static var builtinUsers: WellKnown { WellKnown(rawValue: 27) }

    /// The computer's guests, `BUILTIN\Guests`: `S-1-5-32-546`.
    ///
    /// The corresponding C constant is `WinBuiltinGuestsSid`.
    @_alwaysEmitIntoClient
    public static var builtinGuests: WellKnown { WellKnown(rawValue: 28) }

    /// A domain's administrator account, `Administrator`, relative to the
    /// domain: the domain's identifier, then 500.
    ///
    /// The corresponding C constant is `WinAccountAdministratorSid`.
    @_alwaysEmitIntoClient
    public static var accountAdministrator: WellKnown { WellKnown(rawValue: 38) }
  }
}

// MARK: - Accounts

@available(System 199, *)
extension Win32 {
  /// An account: a security identifier, and the names Windows knows it by.
  ///
  /// The names of the built-in and well-known accounts are in the language
  /// Windows was installed in, so look these up by identifier, not name.
  ///
  /// The corresponding C function is `LookupAccountSidW`, which reports
  /// an account's names.
  public struct Account: Hashable, Sendable {
    /// The account's security identifier.
    public var securityIdentifier: Win32.SecurityIdentifier

    /// The account's name, without its domain, such as `Administrators`.
    public var name: String

    /// The domain the account belongs to: the computer's name for one of
    /// its own accounts, `BUILTIN` for one of its built-in groups, or
    /// `NT AUTHORITY` for an account of the operating system's, for
    /// example. Some well-known accounts, such as `Everyone`, have none.
    public var domain: String

    /// What the account names.
    public var kind: Win32.Account.Kind

    internal init(
      _securityIdentifier securityIdentifier: Win32.SecurityIdentifier,
      name: String,
      domain: String,
      kind: Win32.Account.Kind
    ) {
      self.securityIdentifier = securityIdentifier
      self.name = name
      self.domain = domain
      self.kind = kind
    }
  }
}

@available(System 199, *)
extension Win32.Account {
  /// What an account names.
  ///
  /// The corresponding C type is `SID_NAME_USE`.
  @frozen
  public struct Kind: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed kind from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// A user.
    ///
    /// The corresponding C constant is `SidTypeUser`.
    @_alwaysEmitIntoClient
    public static var user: Kind { Kind(rawValue: 1) }

    /// A group, of a domain.
    ///
    /// The corresponding C constant is `SidTypeGroup`.
    @_alwaysEmitIntoClient
    public static var group: Kind { Kind(rawValue: 2) }

    /// A domain.
    ///
    /// The corresponding C constant is `SidTypeDomain`.
    @_alwaysEmitIntoClient
    public static var domain: Kind { Kind(rawValue: 3) }

    /// An alias: a group of the computer's, such as one of its built-in
    /// groups.
    ///
    /// The corresponding C constant is `SidTypeAlias`.
    @_alwaysEmitIntoClient
    public static var alias: Kind { Kind(rawValue: 4) }

    /// A well-known group, such as `Everyone`.
    ///
    /// The corresponding C constant is `SidTypeWellKnownGroup`.
    @_alwaysEmitIntoClient
    public static var wellKnownGroup: Kind { Kind(rawValue: 5) }

    /// An account that was deleted.
    ///
    /// The corresponding C constant is `SidTypeDeletedAccount`.
    @_alwaysEmitIntoClient
    public static var deletedAccount: Kind { Kind(rawValue: 6) }

    /// An account that isn't valid.
    ///
    /// The corresponding C constant is `SidTypeInvalid`.
    @_alwaysEmitIntoClient
    public static var invalid: Kind { Kind(rawValue: 7) }

    /// An account of an unknown kind.
    ///
    /// The corresponding C constant is `SidTypeUnknown`.
    @_alwaysEmitIntoClient
    public static var unknown: Kind { Kind(rawValue: 8) }

    /// A computer.
    ///
    /// The corresponding C constant is `SidTypeComputer`.
    @_alwaysEmitIntoClient
    public static var computer: Kind { Kind(rawValue: 9) }

    /// A mandatory integrity label, such as `Medium Mandatory Level`.
    ///
    /// The corresponding C constant is `SidTypeLabel`.
    @_alwaysEmitIntoClient
    public static var label: Kind { Kind(rawValue: 10) }

    /// A logon session.
    ///
    /// The corresponding C constant is `SidTypeLogonSession`.
    @_alwaysEmitIntoClient
    public static var logonSession: Kind { Kind(rawValue: 11) }
  }

  /// Looks up the account a security identifier names.
  ///
  /// This initializer returns `nil` if Windows knows no account with the
  /// identifier, such as one from a domain it can't reach or doesn't
  /// trust, and throws if the lookup itself fails. An identifier of a
  /// domain's can take a request to the domain's controller.
  ///
  /// The corresponding C function is `LookupAccountSidW`.
  @_alwaysEmitIntoClient
  public init?(_ securityIdentifier: Win32.SecurityIdentifier) throws(Win32.Error) {
    guard let account = try Win32.Account._lookUp(securityIdentifier).get() else {
      return nil
    }
    self = account
  }
}

@available(System 199, *)
extension Win32.Account: CustomStringConvertible, CustomDebugStringConvertible {
  /// The account's name, after its domain and a backslash if it has one,
  /// as in `BUILTIN\Administrators`: the name's form that Windows calls
  /// SAM-compatible.
  @inline(never)
  public var description: String {
    domain.isEmpty ? name : domain + "\\" + name
  }

  /// The account's name, as ``description`` gives it.
  public var debugDescription: String { description }
}

// MARK: - Internals

@available(System 199, *)
extension Win32.SecurityIdentifier {
  @usableFromInline
  internal static func _bytes(authority: UInt64, subauthorities: [UInt32]) -> [UInt8] {
    precondition(authority >> 48 == 0, "A security identifier's authority is 48 bits")
    precondition(
      subauthorities.count <= _SID_MAX_SUB_AUTHORITIES,
      "A security identifier has at most 15 subauthorities")
    var bytes: [UInt8] = [_SID_REVISION, UInt8(subauthorities.count)]
    bytes.reserveCapacity(8 + 4 * subauthorities.count)
    for shift in stride(from: 40, through: 0, by: -8) {
      bytes.append(UInt8(truncatingIfNeeded: authority >> UInt64(shift)))
    }
    for subauthority in subauthorities {
      for shift in stride(from: 0, through: 24, by: 8) {
        bytes.append(UInt8(truncatingIfNeeded: subauthority >> UInt32(shift)))
      }
    }
    return bytes
  }

  @usableFromInline
  internal var _authority: UInt64 {
    _bytes[2..<8].reduce(0) { $0 << 8 | UInt64($1) }
  }

  @usableFromInline
  internal var _subauthorities: [UInt32] {
    (0..<Int(_bytes[1])).map { index in
      let start = 8 + 4 * index
      return _bytes[start..<(start + 4)].reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }
  }

  /// The bytes of the identifier at `sid`, if it has revision 1 and at most
  /// 15 subauthorities.
  @usableFromInline
  internal static func _copy(_ sid: UnsafeRawPointer) -> [UInt8]? {
    let revision = sid.load(as: UInt8.self)
    let count = Int(sid.load(fromByteOffset: 1, as: UInt8.self))
    guard revision == _SID_REVISION, count <= _SID_MAX_SUB_AUTHORITIES else { return nil }
    return Array(UnsafeRawBufferPointer(start: sid, count: 8 + 4 * count))
  }

  /// Calls `body` with a `PSID` for the identifier, which Windows reads and
  /// doesn't write.
  internal func _withSID<R>(_ body: (PSID) -> R) -> R {
    _bytes.withUnsafeBytes { body(UnsafeMutableRawPointer(mutating: $0.baseAddress!)) }
  }

  @usableFromInline
  internal static func _parse(_ string: String) -> Result<[UInt8], Win32.Error> {
    // A null character would end the C string early, maybe at a valid
    // identifier.
    guard !string.utf16.contains(0) else { return .failure(.invalidSecurityIdentifier) }
    return string.withCString(encodedAs: UTF16.self) { string in
      var sid: PSID? = nil
      guard system_ConvertStringSidToSidW(string, &sid), let sid else {
        return .failure(Win32.Error(GetLastError()))
      }
      defer { _ = system_LocalFree(sid) }
      guard let bytes = _copy(sid) else { return .failure(.invalidSecurityIdentifier) }
      return .success(bytes)
    }
  }

  @usableFromInline
  internal static func _wellKnown(
    _ type: CInt, domain: Win32.SecurityIdentifier?
  ) -> Result<[UInt8], Win32.Error> {
    var bytes = [UInt8](repeating: 0, count: _SECURITY_MAX_SID_SIZE)
    // In, the buffer's size; out, the identifier's.
    var size = DWORD(bytes.count)
    let error: DWORD? = bytes.withUnsafeMutableBytes { sid in
      func create(_ domain: PSID?) -> DWORD? {
        system_CreateWellKnownSid(type, domain, sid.baseAddress, &size) ? nil : GetLastError()
      }
      guard let domain else { return create(nil) }
      return domain._withSID(create)
    }
    if let error { return .failure(Win32.Error(error)) }
    bytes.removeSubrange(Int(size)...)
    return .success(bytes)
  }

  @usableFromInline
  internal static func _lookUp(accountName name: String) -> Result<[UInt8]?, Win32.Error> {
    // No account's name holds a null character, which would end the C
    // string early, maybe at another account's name.
    guard !name.utf16.contains(0) else { return .success(nil) }
    return name.withCString(encodedAs: UTF16.self) { name in
      var sid = [UInt8](repeating: 0, count: _SECURITY_MAX_SID_SIZE)
      var capacity = 64
      while true {
        // The domain's name, which this discards, needs a buffer too.
        let outcome = sid.withUnsafeMutableBytes { sid in
          withUnsafeTemporaryAllocation(
            of: WCHAR.self, capacity: capacity
          ) { domain -> _Win32SizedResult<Void> in
            var sidSize = DWORD(sid.count)
            var domainSize = DWORD(domain.count)
            var use = SidTypeUnknown
            guard system_LookupAccountNameW(
              name, sid.baseAddress, &sidSize, domain.baseAddress, &domainSize, &use
            ) else {
              let error = GetLastError()
              if error == Win32.Error.insufficientBuffer.rawValue {
                return .retry(capacity: max(Int(domainSize), domain.count + 1))
              }
              return .failure(Win32.Error(error))
            }
            return .success(())
          }
        }
        switch outcome {
        case .success:
          guard let bytes = sid.withUnsafeBytes({ _copy($0.baseAddress!) }) else {
            return .failure(.invalidSecurityIdentifier)
          }
          return .success(bytes)
        case .failure(let error):
          return error == .noneMapped ? .success(nil) : .failure(error)
        case .retry(let needed):
          capacity = needed
        }
      }
    }
  }
}

@available(System 199, *)
extension Win32.Account {
  @usableFromInline
  internal static func _lookUp(
    _ securityIdentifier: Win32.SecurityIdentifier
  ) -> Result<Win32.Account?, Win32.Error> {
    enum Outcome {
      case success(Win32.Account)
      case failure(Win32.Error)
      case retry(nameCapacity: Int, domainCapacity: Int)
    }
    var nameCapacity = 64
    var domainCapacity = 64
    while true {
      let outcome = securityIdentifier._withSID { sid in
        withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: nameCapacity) { name in
          withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: domainCapacity) { domain in
            // In, each buffer's size; out, when one is too small, the size
            // it needs, with its terminator.
            var nameSize = DWORD(name.count)
            var domainSize = DWORD(domain.count)
            var use = SidTypeUnknown
            guard system_LookupAccountSidW(
              sid, name.baseAddress, &nameSize, domain.baseAddress, &domainSize, &use
            ) else {
              let error = GetLastError()
              if error == Win32.Error.insufficientBuffer.rawValue {
                return Outcome.retry(
                  nameCapacity: max(Int(nameSize), name.count),
                  domainCapacity: max(Int(domainSize), domain.count))
              }
              return Outcome.failure(Win32.Error(error))
            }
            return Outcome.success(Win32.Account(
              _securityIdentifier: securityIdentifier,
              name: String(decodingCString: name.baseAddress!, as: UTF16.self),
              domain: String(decodingCString: domain.baseAddress!, as: UTF16.self),
              kind: Win32.Account.Kind(rawValue: use.rawValue)))
          }
        }
      }
      switch outcome {
      case .success(let account):
        return .success(account)
      case .failure(let error):
        return error == .noneMapped ? .success(nil) : .failure(error)
      case .retry(let name, let domain):
        // A size that didn't grow would retry forever.
        guard name > nameCapacity || domain > domainCapacity else {
          return .failure(.insufficientBuffer)
        }
        nameCapacity = name
        domainCapacity = domain
      }
    }
  }
}

#endif // os(Windows)
