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

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
#if canImport(Android)
import Android
#endif

final class UserDatabaseTest: XCTestCase {
  #if ENABLE_MOCKING
  @available(System 199, *)
  func testSyscalls() {
    let capacity = _initialEntryBufferCapacity
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(
        name: "getpwuid_r", .interruptable, 501, Wildcard(), Wildcard(), capacity, Wildcard()
      ) { retryOnInterrupt in
        _ = try UserEntry(userID: UserID(501), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "getpwnam_r", .interruptable, "a user", Wildcard(), Wildcard(), capacity,
        Wildcard()
      ) { retryOnInterrupt in
        _ = try UserEntry(name: "a user", retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "getgrgid_r", .interruptable, 20, Wildcard(), Wildcard(), capacity, Wildcard()
      ) { retryOnInterrupt in
        _ = try GroupEntry(groupID: GroupID(20), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "getgrnam_r", .interruptable, "a group", Wildcard(), Wildcard(), capacity,
        Wildcard()
      ) { retryOnInterrupt in
        _ = try GroupEntry(name: "a group", retryOnInterrupt: retryOnInterrupt)
      },
    ]

    for test in syscallTestCases { test.runAllTests() }
  }

  @available(System 199, *)
  func testSupplementaryGroupsSyscall() throws {
    let getgroups = MockTestCase(
      name: "getgroups", .noInterrupt, GroupID._initialSupplementaryCapacity, Wildcard()
    ) { _ in
      _ = try GroupID.supplementary()
    }
    getgroups.runAllTests()

    // EINVAL means the buffer was too small, so it retries with a larger one.
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertEqual(try GroupID.supplementary(), [])
      let capacity = GroupID._initialSupplementaryCapacity
      XCTAssertEqual(mocking.trace.dequeue()?.arguments[0], AnyHashable(capacity))
      XCTAssertEqual(mocking.trace.dequeue()?.arguments[0], AnyHashable(capacity * 4))
      XCTAssertNil(mocking.trace.dequeue())
    }
  }

  @available(System 199, *)
  func testBufferGrowth() throws {
    // ERANGE means the buffer was too small, so the lookup retries with
    // a larger one until it reaches the maximum.
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: ERANGE, count: 2)
      XCTAssertNil(try UserEntry(userID: UserID(501)))
      for capacity in [1024, 2048, 4096] {
        XCTAssertEqual(mocking.trace.dequeue()?.arguments[3], AnyHashable(capacity))
      }
      XCTAssertNil(mocking.trace.dequeue())

      mocking.forceErrno = .always(errno: ERANGE)
      XCTAssertThrowsError(try GroupEntry(groupID: GroupID(20))) {
        XCTAssertEqual($0 as? Errno, .outOfRange)
      }
      var last: AnyHashable? = nil
      while let entry = mocking.trace.dequeue() { last = entry.arguments[3] }
      XCTAssertEqual(last, AnyHashable(_maximumEntryBufferCapacity))
    }
  }
  #endif // ENABLE_MOCKING

  @available(System 199, *)
  func testUserEntry() throws {
    // Compare with the non-reentrant call. The effective user and user ID 0
    // needn't have entries, as in a container run with an arbitrary user ID,
    // so neither does UserEntry then.
    for userID in [UserID.effective, UserID(0)] {
      let entry = try UserEntry(userID: userID)
      guard let c = getpwuid(userID.rawValue)?.pointee else {
        XCTAssertNil(entry, "\(userID)")
        continue
      }
      let found = try XCTUnwrap(entry, "\(userID)")
      XCTAssertEqual(found.userID, userID)
      XCTAssertFalse(found.name.isEmpty)
      XCTAssertEqual(try UserEntry(name: found.name), found)

      // Bionic marks the strings nullable.
      XCTAssertEqual(found.name, c.pw_name.map { String(cString: $0) })
      XCTAssertEqual(found.groupID.rawValue, c.pw_gid)
      XCTAssertEqual(found.homeDirectory, c.pw_dir.map { FilePath(platformString: $0) })
      XCTAssertEqual(found.shell, c.pw_shell.map { FilePath(platformString: $0) })
      // A null real name is empty. 32-bit Bionic's header defines pw_gecos
      // as pw_passwd.
      #if os(Android) && _pointerBitWidth(_32)
      let realName = c.pw_passwd
      #else
      let realName = c.pw_gecos
      #endif
      XCTAssertEqual(found.realName, realName.map { String(cString: $0) } ?? "")
    }

    XCTAssertNil(try UserEntry(name: "no such user \(Int.random(in: 0..<1_000_000))"))
  }

  @available(System 199, *)
  func testGroupEntry() throws {
    // Compare with the non-reentrant call. As for users, the effective group
    // and group ID 0 needn't have entries.
    for groupID in [GroupID.effective, GroupID(0)] {
      let entry = try GroupEntry(groupID: groupID)
      guard let c = getgrgid(groupID.rawValue)?.pointee else {
        XCTAssertNil(entry, "\(groupID)")
        continue
      }
      let found = try XCTUnwrap(entry, "\(groupID)")
      XCTAssertEqual(found.groupID, groupID)
      XCTAssertFalse(found.name.isEmpty)
      XCTAssertEqual(try GroupEntry(name: found.name), found)

      // Bionic marks the strings nullable.
      XCTAssertEqual(found.name, c.gr_name.map { String(cString: $0) })
      var members: [String] = []
      if var member = c.gr_mem {
        while let name = member.pointee {
          members.append(String(cString: name))
          member += 1
        }
      }
      XCTAssertEqual(found.members, members)
    }

    XCTAssertNil(try GroupEntry(name: "no such group \(Int.random(in: 0..<1_000_000))"))
  }
}

#endif // !os(Windows) && !os(WASI)
