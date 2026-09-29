/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// One-package gaps (REPORT.md section 36): fstatat's Darwin-only flags,
// dladdr, the call stack, and I/O policies.

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SmallDarwinGapsTest: XCTestCase {
  /// AT_FDONLY gets the descriptor's status and ignores the path;
  /// AT_REALDEV reports the same device on an ordinary volume.
  func testStatFlags() throws {
    try withTemporaryFilePath(basename: "testStatFlags") { dir in
      let file = try FileDescriptor.open(
        dir.appending("file"), .writeOnly, options: .create, permissions: .ownerReadWrite)
      defer { try? file.close() }
      let own = try Stat(file)
      let viaDescriptor = try Stat("no-such-file", relativeTo: file, flags: .descriptorOnly)
      XCTAssertEqual(viaDescriptor.inode, own.inode)
      let real = try Stat("file", relativeTo: try FileDescriptor.open(dir, .readOnly), flags: .realDevice)
      XCTAssertEqual(real.inode, own.inode)
      XCTAssertEqual(real.deviceID, own.deviceID)
    }
  }

  /// dladdr finds the library that contains a function, and its symbol.
  func testSymbolInfo() throws {
    let program = try DynamicLibrary.mainProgram()
    let found = program.address(of: "getpid")
    let getpidAddress = try XCTUnwrap(found)
    try program.close()
    let info = try XCTUnwrap(DynamicLibrary.symbolInfo(containing: getpidAddress))
    // The nearest symbol can be an alias, such as __getpid.
    XCTAssertTrue(info.symbolName?.hasSuffix("getpid") == true, "\(String(describing: info.symbolName))")
    XCTAssertEqual(info.symbolAddress, UnsafeRawPointer(getpidAddress))
    XCTAssertTrue(info.libraryPath.string.contains("libsystem"), "\(info.libraryPath)")
    XCTAssertNotNil(info.libraryAddress)
    // An address that no library contains.
    XCTAssertNil(DynamicLibrary.symbolInfo(containing: UnsafeRawPointer(bitPattern: 0x10)!))
  }

  /// The call stack has this test's frames, and a symbol for each.
  func testCallStack() throws {
    let addresses = CallStack.returnAddresses()
    XCTAssertGreaterThan(addresses.count, 2)
    XCTAssertEqual(CallStack.returnAddresses(maxCount: 2).count, 2)
    XCTAssertEqual(CallStack.returnAddresses(maxCount: 0).count, 0)
    let symbols = try CallStack.symbols(for: addresses)
    XCTAssertEqual(symbols.count, addresses.count)
    XCTAssertTrue(symbols.contains { $0.contains("testCallStack") }, "\(symbols)")
    XCTAssertEqual(try CallStack.symbols(for: []), [])
  }

  /// A thread's I/O policy can be read and set, on a thread of its own.
  func testIOPolicy() throws {
    XCTAssertGreaterThanOrEqual(try IOPolicy.value(of: .disk, for: .process), 0)
    let seen = Locked<[CInt]>([])
    let thread = try PThread {
      let before = try! IOPolicy.value(of: .disk, for: .thread)
      try! IOPolicy.setValue(CInt(IOPOL_THROTTLE), of: .disk, for: .thread)
      let after = try! IOPolicy.value(of: .disk, for: .thread)
      seen.withValue { $0 = [before, after] }
    }
    try thread.join()
    XCTAssertEqual(seen.value.last, CInt(IOPOL_THROTTLE))
    XCTAssertThrowsError(try IOPolicy.value(of: IOPolicy.Kind(rawValue: 9999), for: .process)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }

  #if ENABLE_MOCKING
  func testIOPolicyCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "getiopolicy_np", .noInterrupt, IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD) { _ in
        _ = try IOPolicy.value(of: .disk, for: .thread)
      },
      MockTestCase(name: "setiopolicy_np", .noInterrupt, IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, 1) {
        _ in try IOPolicy.setValue(1, of: .accessTimeUpdates, for: .process)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN
