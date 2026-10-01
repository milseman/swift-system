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

@Suite("Process credentials")
private struct ProcessCredentialsTests {
  /// The test runner isn't set-user-ID.
  @available(System 199, *)
  @Test func theTestsArentSetUserID() {
    #expect(!ProcessID.isSetUserOrGroupID)
    #if SYSTEM_PACKAGE_DARWIN
    #expect(issetugid() == 0)
    #endif
    #expect(ProcessEnvironment.secureValue(of: "PATH") == ProcessEnvironment.value(of: "PATH"))
    #expect(ProcessEnvironment.secureValue(of: "SYSTEM_TESTS_NOT_SET_ANYWHERE") == nil)
  }

  @available(System 199, *)
  @Test func aUsersGroups() throws {
    let me = try #require(try UserEntry(userID: .effective))
    let groups = try GroupID.supplementary(forUser: me.name, including: me.groupID)
    #expect(groups.first == me.groupID)
    #expect(Set(groups).count == groups.count, "no duplicates: \(groups)")

    // The same list as the C library's.
    var buffer = [CInterop.GroupID](repeating: 0, count: 1024)
    var count = CInt(buffer.count)
    #if SYSTEM_PACKAGE_DARWIN
    let result = buffer.withUnsafeMutableBufferPointer {
      $0.withMemoryRebound(to: CInt.self) {
        getgrouplist(me.name, CInt(bitPattern: me.groupID.rawValue), $0.baseAddress!, &count)
      }
    }
    #else
    let result = getgrouplist(me.name, me.groupID.rawValue, &buffer, &count)
    #endif
    #expect(result != -1)
    #expect(groups.map(\.rawValue) == Array(buffer[..<Int(count)]))

    // Another group to include comes first, and adds one. Darwin's list
    // keeps the user's primary group; glibc's has it only if the group
    // database lists the user in it, as it doesn't list root in group 0.
    let unusual = GroupID(rawValue: 4242)
    let more = try GroupID.supplementary(forUser: me.name, including: unusual)
    #expect(more.first == unusual)
    #if SYSTEM_PACKAGE_DARWIN
    #expect(Set(more) == Set(groups).union([unusual]))
    #else
    #expect(Set(more).union([me.groupID]) == Set(groups).union([unusual]))
    #endif
  }

  @available(System 199, *)
  @Test func rootsGroups() throws {
    let root = try #require(try UserEntry(userID: UserID(rawValue: 0)))
    let groups = try GroupID.supplementary(forUser: root.name, including: root.groupID)
    #expect(groups.first == root.groupID)
    #expect(groups.contains(GroupID(rawValue: 0)))
  }

  /// Darwin also lists (gid_t)-1 for a user it doesn't know.
  @available(System 199, *)
  @Test func anUnknownUsersGroups() throws {
    let group = GroupID(rawValue: 4242)
    let groups = try GroupID.supplementary(forUser: "system-tests-no-such-user", including: group)
    #expect(groups == [group])
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// A thread acts as its process unless it has its own credentials, which
  /// only a privileged process can give it.
  @available(System 199, *)
  @Test func aThreadActsAsItsProcess() throws {
    #expect(try PThread.credentials() == nil)
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
