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

// Win32.TokenHandle, the calling thread's user names, and group membership.
// The tests run as whichever user runs them, with or without elevation, so
// they compare System's answers with raw Win32 calls and the environment.
@available(System 199, *)
final class Win32AccessTokenTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let rights: [(Win32.TokenAccess, DWORD)] = [
      (.assignPrimary, DWORD(WinSDK.TOKEN_ASSIGN_PRIMARY)),
      (.duplicate, DWORD(WinSDK.TOKEN_DUPLICATE)),
      (.impersonate, DWORD(WinSDK.TOKEN_IMPERSONATE)),
      (.query, DWORD(WinSDK.TOKEN_QUERY)),
      (.querySource, DWORD(WinSDK.TOKEN_QUERY_SOURCE)),
      (.adjustPrivileges, DWORD(WinSDK.TOKEN_ADJUST_PRIVILEGES)),
      (.adjustGroups, DWORD(WinSDK.TOKEN_ADJUST_GROUPS)),
      (.adjustDefault, DWORD(WinSDK.TOKEN_ADJUST_DEFAULT)),
      (.adjustSessionID, DWORD(WinSDK.TOKEN_ADJUST_SESSIONID)),
      (.delete, DWORD(WinSDK.DELETE)),
      (.readControl, DWORD(WinSDK.READ_CONTROL)),
      (.writeDAC, DWORD(WinSDK.WRITE_DAC)),
      (.writeOwner, DWORD(WinSDK.WRITE_OWNER)),
      // TOKEN_READ and TOKEN_ALL_ACCESS, spelled from their parts, as
      // winnt.h defines them.
      (.read, DWORD(WinSDK.READ_CONTROL) | DWORD(WinSDK.TOKEN_QUERY)),
      (.all, DWORD(WinSDK.STANDARD_RIGHTS_REQUIRED) | 0x1FF),
      (.maximumAllowed, DWORD(WinSDK.MAXIMUM_ALLOWED)),
    ]
    for (right, value) in rights {
      XCTAssertEqual(right.rawValue, value, "\(right)")
    }
    let formats: [(Win32.UserNameFormat, CInt)] = [
      (.fullyQualifiedDistinguishedName, CInt(NameFullyQualifiedDN.rawValue)),
      (.samCompatible, CInt(NameSamCompatible.rawValue)),
      (.display, CInt(NameDisplay.rawValue)),
      (.uniqueID, CInt(NameUniqueId.rawValue)),
      (.canonical, CInt(NameCanonical.rawValue)),
      (.userPrincipal, CInt(NameUserPrincipal.rawValue)),
      (.canonicalEx, CInt(NameCanonicalEx.rawValue)),
      (.servicePrincipal, CInt(NameServicePrincipal.rawValue)),
      (.dnsDomain, CInt(NameDnsDomain.rawValue)),
      (.givenName, CInt(NameGivenName.rawValue)),
      (.surname, CInt(NameSurname.rawValue)),
    ]
    for (format, value) in formats {
      XCTAssertEqual(format.rawValue, value, "\(format)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_UNLEN, Int(WinSDK.UNLEN))
  }

  func testTheProcessToken() throws {
    let token = try Win32.TokenHandle.open(process: .current, access: .query)
    let user = try token.user()
    XCTAssertEqual(user, rawProcessUser())
    let elevated = try token.isElevated()
    XCTAssertEqual(elevated, rawProcessIsElevated())
    try token.close()
  }

  func testTheTokenNeedsTheRight() throws {
    let token = try Win32.TokenHandle.open(process: .current, access: .readControl)
    XCTAssertThrowsWin32Error(.accessDenied) { try token.user() }
    XCTAssertThrowsWin32Error(.accessDenied) { try token.isElevated() }
  }

  func testTheProfileDirectory() throws {
    let token = try Win32.TokenHandle.open(process: .current, access: .query)
    let profile = try token.profileDirectory()
    XCTAssertTrue(win32RawExists(profile), "\(profile)")
    if let variable = win32RawEnvironmentValue("USERPROFILE") {
      XCTAssertEqual(profile.description.lowercased(), variable.lowercased())
    }
  }

  func testUserNames() throws {
    let name = try Win32.userName()
    XCTAssertFalse(name.isEmpty)
    if let variable = win32RawEnvironmentValue("USERNAME") {
      XCTAssertEqual(name.lowercased(), variable.lowercased())
    }
    // Every account has the SAM-compatible form, its account's
    // description.
    let token = try Win32.TokenHandle.open(process: .current, access: .query)
    let account = try Win32.Account(try token.user())
    let samCompatible = try Win32.userName(format: .samCompatible)
    XCTAssertEqual(samCompatible.lowercased(), account?.description.lowercased())
    // An account outside a domain has no display name.
    do {
      let display = try Win32.userName(format: .display)
      XCTAssertFalse(display.isEmpty)
    } catch {
      // The do block's one call throws Win32.Error.
      XCTAssertTrue(error == .noneMapped || error == .noSuchDomain, error.debugDescription)
    }
  }

  func testMembership() throws {
    let everyone = try Win32.SecurityIdentifier(.everyone)
    let inEveryone = try Win32.callingThreadIsMember(of: everyone)
    XCTAssertTrue(inEveryone)
    let anonymous = try Win32.SecurityIdentifier(.anonymous)
    let inAnonymous = try Win32.callingThreadIsMember(of: anonymous)
    XCTAssertFalse(inAnonymous)
    // A user's own identifier is enabled in its token.
    let user = try XCTUnwrap(rawProcessUser())
    let isUser = try Win32.callingThreadIsMember(of: user)
    XCTAssertTrue(isUser)
    // An administrator's administrative group is enabled only when the
    // token is elevated.
    let administrators = try Win32.SecurityIdentifier(.builtinAdministrators)
    let inAdministrators = try Win32.callingThreadIsMember(of: administrators)
    if inAdministrators {
      XCTAssertEqual(rawProcessIsElevated(), true)
    }
  }
}

/// The calling process's user, read with raw Win32 calls.
@available(System 199, *)
private func rawProcessUser() -> Win32.SecurityIdentifier? {
  var token: HANDLE? = nil
  guard OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &token), let token else {
    return nil
  }
  defer { CloseHandle(token) }
  var buffer = [UInt64](repeating: 0, count: 32)
  return buffer.withUnsafeMutableBytes { buffer -> Win32.SecurityIdentifier? in
    var size: DWORD = 0
    guard GetTokenInformation(token, TokenUser, buffer.baseAddress, DWORD(buffer.count), &size)
    else { return nil }
    let user = buffer.baseAddress!.load(as: TOKEN_USER.self)
    return Win32.SecurityIdentifier(unsafeCopying: user.User.Sid)
  }
}

/// Whether the calling process's token is elevated, read with raw Win32
/// calls.
@available(System 199, *)
private func rawProcessIsElevated() -> Bool? {
  var token: HANDLE? = nil
  guard OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &token), let token else {
    return nil
  }
  defer { CloseHandle(token) }
  var elevation = TOKEN_ELEVATION()
  var size: DWORD = 0
  guard GetTokenInformation(
    token, TokenElevation, &elevation, DWORD(MemoryLayout<TOKEN_ELEVATION>.size), &size)
  else { return nil }
  return elevation.TokenIsElevated != 0
}

#endif // os(Windows)
