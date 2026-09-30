/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The Linux side of SmallGapsTest and SmallDarwinGapsTest: unique files with
// a suffix (mkostemps), dladdr, and glibc's RTLD_DEEPBIND.

#if os(Linux) || os(Android)

import XCTest

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SmallLinuxGapsTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mkostemps", .interruptable, "aXXXXXX.txt", CInt(4), O_CLOEXEC) { retryOnInterrupt in
        _ = try FilePath("aXXXXXX.txt").makeUniqueFile(
          suffixLength: 4, options: .closeOnExec, retryOnInterrupt: retryOnInterrupt)
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testUniqueFileWithASuffix() throws {
    try withTemporaryFilePath(basename: "testUniqueFileWithASuffix") { dir in
      let (path, fd) = try dir.appending("report-XXXXXX.txt").makeUniqueFile(
        suffixLength: 4, options: .closeOnExec)
      defer { try? fd.close() }
      let name = try XCTUnwrap(path.lastComponent?.string)
      XCTAssertTrue(name.hasPrefix("report-") && name.hasSuffix(".txt"))
      XCTAssertEqual(name.count, "report-XXXXXX.txt".count)
      XCTAssertFalse(name.contains("XXXXXX"))
      XCTAssertEqual(try path.stat().type, .regular)
      XCTAssertEqual(try fd.stat().mode.permissions, .ownerReadWrite)
      XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))
      // Six X's must come before the suffix.
      XCTAssertThrowsError(try dir.appending("report-XXXXX.txt").makeUniqueFile(suffixLength: 4)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try dir.appending("XXXXXX").makeUniqueFile(suffixLength: 1)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  /// dladdr finds the library that contains a function, and its symbol.
  func testSymbolInfo() throws {
    let program = try DynamicLibrary.mainProgram()
    let found = program.address(of: "getpid")
    try program.close()
    guard let getpidAddress = found else {
      // A statically linked program, as Musl's are, has no symbols to find.
      throw XCTSkip("the program has no dynamic symbols")
    }
    let info = try XCTUnwrap(DynamicLibrary.symbolInfo(containing: getpidAddress))
    // The nearest symbol can be an alias, such as glibc's __getpid.
    XCTAssertTrue(info.symbolName?.hasSuffix("getpid") == true, "\(String(describing: info.symbolName))")
    XCTAssertEqual(info.symbolAddress, UnsafeRawPointer(getpidAddress))
    #if canImport(Glibc)
    XCTAssertTrue(info.libraryPath.string.contains("libc.so"), "\(info.libraryPath)")
    #endif
    XCTAssertNotNil(info.libraryAddress)
    // An address that no library contains.
    XCTAssertNil(DynamicLibrary.symbolInfo(containing: UnsafeRawPointer(bitPattern: 0x10)!))
  }

  #if canImport(Glibc)
  /// A library loaded with deep binding still has its own symbols.
  func testDeepBinding() throws {
    XCTAssertEqual(DynamicLibrary.OpenOptions.deepBind.rawValue, 0x8)
    let library = try DynamicLibrary("libm.so.6", options: [.now, .local, .deepBind])
    let cosine = library.address(of: "cos")
    XCTAssertNotNil(cosine)
    try library.close()
  }
  #endif
}

#endif // os(Linux) || os(Android)
