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
    // The node name changes when the host name does, which the system can do
    // at any moment, as when the network changes; the other names don't.
    var before = utsname()
    #expect(uname(&before) == 0)
    let system = try SystemIdentity.current()
    var names = utsname()
    #expect(uname(&names) == 0)
    #expect(system.systemName == _fixedString(names.sysname))
    #expect([_fixedString(before.nodename), _fixedString(names.nodename)].contains(system.nodeName))
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
    // The host name can change at any moment, as when the network changes,
    // so it's compared with the node names read before and after it.
    let before = try SystemIdentity.current().nodeName
    let hostName = try SystemIdentity.hostName()
    let after = try SystemIdentity.current().nodeName
    #expect(!hostName.isEmpty)
    #expect([before, after].contains(hostName))
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
