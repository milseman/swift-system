/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Win32.SecurityIdentifier and Win32.Account. The names of the built-in and
// well-known accounts are localized, so the tests compare identifiers, not
// names, except for the current user's.
@available(System 199, *)
final class Win32SecurityIdentifierTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let wellKnown: [(Win32.SecurityIdentifier.WellKnown, CInt)] = [
      (.null, CInt(WinNullSid.rawValue)),
      (.everyone, CInt(WinWorldSid.rawValue)),
      (.local, CInt(WinLocalSid.rawValue)),
      (.creatorOwner, CInt(WinCreatorOwnerSid.rawValue)),
      (.creatorGroup, CInt(WinCreatorGroupSid.rawValue)),
      (.network, CInt(WinNetworkSid.rawValue)),
      (.batch, CInt(WinBatchSid.rawValue)),
      (.interactive, CInt(WinInteractiveSid.rawValue)),
      (.service, CInt(WinServiceSid.rawValue)),
      (.anonymous, CInt(WinAnonymousSid.rawValue)),
      (.authenticatedUsers, CInt(WinAuthenticatedUserSid.rawValue)),
      (.localSystem, CInt(WinLocalSystemSid.rawValue)),
      (.localService, CInt(WinLocalServiceSid.rawValue)),
      (.networkService, CInt(WinNetworkServiceSid.rawValue)),
      (.builtinAdministrators, CInt(WinBuiltinAdministratorsSid.rawValue)),
      (.builtinUsers, CInt(WinBuiltinUsersSid.rawValue)),
      (.builtinGuests, CInt(WinBuiltinGuestsSid.rawValue)),
      (.accountAdministrator, CInt(WinAccountAdministratorSid.rawValue)),
    ]
    for (identifier, value) in wellKnown {
      XCTAssertEqual(identifier.rawValue, value, "\(identifier)")
    }
    let kinds: [(Win32.Account.Kind, CInt)] = [
      (.user, CInt(SidTypeUser.rawValue)),
      (.group, CInt(SidTypeGroup.rawValue)),
      (.domain, CInt(SidTypeDomain.rawValue)),
      (.alias, CInt(SidTypeAlias.rawValue)),
      (.wellKnownGroup, CInt(SidTypeWellKnownGroup.rawValue)),
      (.deletedAccount, CInt(SidTypeDeletedAccount.rawValue)),
      (.invalid, CInt(SidTypeInvalid.rawValue)),
      (.unknown, CInt(SidTypeUnknown.rawValue)),
      (.computer, CInt(SidTypeComputer.rawValue)),
      (.label, CInt(SidTypeLabel.rawValue)),
      (.logonSession, CInt(SidTypeLogonSession.rawValue)),
    ]
    for (kind, value) in kinds {
      XCTAssertEqual(kind.rawValue, value, "\(kind)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(CInt(_SID_REVISION), CInt(WinSDK.SID_REVISION))
    XCTAssertEqual(_SID_MAX_SUB_AUTHORITIES, Int(WinSDK.SID_MAX_SUB_AUTHORITIES))
  }

  func testParts() {
    let administrators = Win32.SecurityIdentifier(authority: 5, subauthorities: [32, 544])
    XCTAssertEqual(administrators.authority, 5)
    XCTAssertEqual(administrators.subauthorities, [32, 544])
    XCTAssertEqual(administrators.description, "S-1-5-32-544")
    // The C form: revision 1, two subauthorities, the authority big-endian,
    // and the subauthorities little-endian.
    let bytes = administrators.withUnsafeBytes { Array($0) }
    XCTAssertEqual(bytes, [1, 2, 0, 0, 0, 0, 0, 5, 0x20, 0, 0, 0, 0x20, 0x02, 0, 0])
    let none = Win32.SecurityIdentifier(authority: 0, subauthorities: [])
    XCTAssertEqual(none.description, "S-1-0")
    XCTAssertEqual(none.subauthorities, [])
    let most = Win32.SecurityIdentifier(
      authority: 0xFFFF_FFFF_FFFF, subauthorities: Array(repeating: .max, count: 15))
    XCTAssertEqual(most.authority, 0xFFFF_FFFF_FFFF)
    XCTAssertEqual(most.subauthorities.count, 15)
  }

  func testStringFormsMatchConvertSidToStringSidW() throws {
    let identifiers = [
      Win32.SecurityIdentifier(authority: 5, subauthorities: [32, 544]),
      Win32.SecurityIdentifier(authority: 0, subauthorities: []),
      Win32.SecurityIdentifier(authority: 0xFFFF_FFFF, subauthorities: [.max, 0]),
      // Authorities past 32 bits, which the string form gives in hexadecimal.
      Win32.SecurityIdentifier(authority: 0x1_0000_0000, subauthorities: [1]),
      Win32.SecurityIdentifier(authority: 0x1234_5678_9ABC, subauthorities: [7]),
      Win32.SecurityIdentifier(
        authority: 5, subauthorities: (1...15).map { UInt32($0) * 1_000_003 }),
    ]
    for identifier in identifiers {
      let expected = rawStringForm(identifier)
      XCTAssertEqual(identifier.description, expected)
      // And it parses back.
      let parsed = try Win32.SecurityIdentifier(identifier.description)
      XCTAssertEqual(parsed, identifier, identifier.description)
    }
  }

  func testParsing() throws {
    let administrators = Win32.SecurityIdentifier(authority: 5, subauthorities: [32, 544])
    let parsed = try Win32.SecurityIdentifier("S-1-5-32-544")
    XCTAssertEqual(parsed, administrators)
    XCTAssertEqual(parsed.hashValue, administrators.hashValue)
    // The SDDL abbreviations of well-known identifiers.
    let abbreviated = try Win32.SecurityIdentifier("BA")
    XCTAssertEqual(abbreviated, administrators)
    let system = try Win32.SecurityIdentifier("SY")
    XCTAssertEqual(system.description, "S-1-5-18")

    for string in ["", "S-1-", "S-2-5-32", "X", "S-1-5-32-544\u{0}"] {
      XCTAssertThrowsWin32Error(.invalidSecurityIdentifier, string) {
        try Win32.SecurityIdentifier(string)
      }
    }
  }

  func testWellKnown() throws {
    let expected: [(Win32.SecurityIdentifier.WellKnown, String)] = [
      (.null, "S-1-0-0"),
      (.everyone, "S-1-1-0"),
      (.local, "S-1-2-0"),
      (.creatorOwner, "S-1-3-0"),
      (.creatorGroup, "S-1-3-1"),
      (.network, "S-1-5-2"),
      (.batch, "S-1-5-3"),
      (.interactive, "S-1-5-4"),
      (.service, "S-1-5-6"),
      (.anonymous, "S-1-5-7"),
      (.authenticatedUsers, "S-1-5-11"),
      (.localSystem, "S-1-5-18"),
      (.localService, "S-1-5-19"),
      (.networkService, "S-1-5-20"),
      (.builtinAdministrators, "S-1-5-32-544"),
      (.builtinUsers, "S-1-5-32-545"),
      (.builtinGuests, "S-1-5-32-546"),
    ]
    for (wellKnown, string) in expected {
      let identifier = try Win32.SecurityIdentifier(wellKnown)
      XCTAssertEqual(identifier.description, string)
    }
  }

  func testWellKnownRelativeToADomain() throws {
    // A domain-relative identifier needs a domain.
    XCTAssertThrowsError(try Win32.SecurityIdentifier(.accountAdministrator))
    // The current user's domain, if it's an account domain's: S-1-5-21-…
    // and the user's own number.
    let user = try currentUser()
    guard user.authority == 5, user.subauthorities.first == 21 else {
      throw XCTSkip("the current user, \(user), isn't in an account domain")
    }
    let domain = Win32.SecurityIdentifier(
      authority: 5, subauthorities: Array(user.subauthorities.dropLast()))
    let administrator = try Win32.SecurityIdentifier(.accountAdministrator, domain: domain)
    XCTAssertEqual(administrator.subauthorities, domain.subauthorities + [500])
  }

  func testAccounts() throws {
    let system = try Win32.SecurityIdentifier(.localSystem)
    let systemAccount = try Win32.Account(system)
    XCTAssertEqual(systemAccount?.securityIdentifier, system)
    XCTAssertEqual(systemAccount?.kind, .wellKnownGroup)

    let administrators = try Win32.SecurityIdentifier(.builtinAdministrators)
    guard let account = try Win32.Account(administrators) else {
      XCTFail("no account for \(administrators)")
      return
    }
    XCTAssertEqual(account.kind, .alias)
    XCTAssertFalse(account.name.isEmpty)
    XCTAssertFalse(account.domain.isEmpty)
    XCTAssertEqual(account.description, account.domain + "\\" + account.name)
    // Its names look up its identifier, with the domain and without.
    let qualified = try Win32.SecurityIdentifier(accountName: account.description)
    XCTAssertEqual(qualified, administrators)
    let unqualified = try Win32.SecurityIdentifier(accountName: account.name)
    XCTAssertEqual(unqualified, administrators)

    // Everyone's account has no domain.
    let everyone = try Win32.Account(try Win32.SecurityIdentifier(.everyone))
    XCTAssertEqual(everyone?.domain, "")
    XCTAssertEqual(everyone?.kind, .wellKnownGroup)
  }

  func testTheCurrentUsersAccount() throws {
    let user = try currentUser()
    guard let account = try Win32.Account(user) else {
      XCTFail("no account for \(user)")
      return
    }
    XCTAssertEqual(account.kind, .user)
    let name = try Win32.userName()
    XCTAssertEqual(account.name.lowercased(), name.lowercased())
    let found = try Win32.SecurityIdentifier(accountName: account.description)
    XCTAssertEqual(found, user)
  }

  func testUnknownAccounts() throws {
    let name = "no-such-account-\(UInt32.random(in: 0 ... .max))"
    let missing = try Win32.SecurityIdentifier(accountName: name)
    XCTAssertNil(missing)
    // A null character can't be in a name, which mustn't end the C string
    // early at an account's name.
    let truncated = try Win32.SecurityIdentifier(accountName: "Administrators\u{0}x")
    XCTAssertNil(truncated)
    // A domain Windows doesn't know.
    let unknown = Win32.SecurityIdentifier(
      authority: 5, subauthorities: [21, 1, 2, 3, 0x7FFF_FFFF])
    let account = try Win32.Account(unknown)
    XCTAssertNil(account)
  }

  func testCopying() throws {
    let administrators = Win32.SecurityIdentifier(authority: 5, subauthorities: [32, 544])
    let copied = rawParsed("S-1-5-32-544") { sid in
      Win32.SecurityIdentifier(unsafeCopying: sid)
    }
    XCTAssertEqual(copied, administrators)
    let none = Win32.SecurityIdentifier(unsafeCopying: nil)
    XCTAssertNil(none)
    // A revision other than 1 isn't an identifier.
    var bytes: [UInt8] = [2, 0, 0, 0, 0, 0, 0, 5]
    let wrong = bytes.withUnsafeMutableBytes { buffer in
      Win32.SecurityIdentifier(unsafeCopying: buffer.baseAddress)
    }
    XCTAssertNil(wrong)
  }
}

/// The calling process's user, from its token.
@available(System 199, *)
private func currentUser() throws -> Win32.SecurityIdentifier {
  let token = try Win32.TokenHandle.open(process: .current, access: .query)
  return try token.user()
}

/// The string form `ConvertSidToStringSidW` gives an identifier.
@available(System 199, *)
private func rawStringForm(_ identifier: Win32.SecurityIdentifier) -> String? {
  identifier.withUnsafeBytes { bytes -> String? in
    var string: LPWSTR? = nil
    guard ConvertSidToStringSidW(UnsafeMutableRawPointer(mutating: bytes.baseAddress!), &string),
      let string
    else { return nil }
    defer { LocalFree(string) }
    return String(decodingCString: string, as: UTF16.self)
  }
}

/// Calls `body` with the identifier that `ConvertStringSidToSidW` makes of
/// `string`.
@available(System 199, *)
private func rawParsed<R>(_ string: String, _ body: (PSID) -> R?) -> R? {
  string.withCString(encodedAs: UTF16.self) { string -> R? in
    var sid: PSID? = nil
    guard ConvertStringSidToSidW(string, &sid), let sid else { return nil }
    defer { LocalFree(sid) }
    return body(sid)
  }
}

#endif // os(Windows)
