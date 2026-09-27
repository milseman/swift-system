/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@Suite("System identity")
private struct SystemIdentityTests {
  @available(System 199, *)
  @Test func currentIsUname() throws {
    let system = try SystemIdentity.current()
    var names = utsname()
    #expect(uname(&names) == 0)
    #expect(system.systemName == _fixedString(names.sysname))
    #expect(system.nodeName == _fixedString(names.nodename))
    #expect(system.release == _fixedString(names.release))
    #expect(system.version == _fixedString(names.version))
    #expect(system.machine == _fixedString(names.machine))
    #if SYSTEM_PACKAGE_DARWIN
    #expect(system.systemName == "Darwin")
    #elseif os(Linux) || os(Android)
    #expect(system.systemName == "Linux")
    #endif
    #expect(!system.release.isEmpty && !system.machine.isEmpty)
  }

  @available(System 199, *)
  @Test func hostNameIsTheNodeName() throws {
    let hostName = try SystemIdentity.hostName()
    #expect(!hostName.isEmpty)
    #expect(hostName == (try SystemIdentity.current().nodeName))
  }

  @available(System 199, *)
  @Test func loginNameMatchesGetlogin() throws {
    let expected = getlogin().map { String(cString: $0) }
    let result = Result { () throws(Errno) in try SystemIdentity.loginName() }
    if let expected {
      #expect(try result.get() == expected)
    } else {
      // A process with no login name, such as one a daemon started.
      #expect(throws: Errno.self) { try result.get() }
    }
  }

  @Test func fixedStrings() {
    #expect(_fixedString((CChar(0x61), CChar(0x62), CChar(0), CChar(0x63))) == "ab")
    // A full array without a terminator ends at its end.
    #expect(_fixedString((CChar(0x61), CChar(0x62))) == "ab")
    #expect(_fixedString((CChar(0), CChar(0x62))) == "")
  }
}

#endif // !os(Windows) && !os(WASI)
