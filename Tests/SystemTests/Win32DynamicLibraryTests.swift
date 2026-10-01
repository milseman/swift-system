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

// DynamicLibrary on Windows. kernel32.dll is loaded in every process, so
// its exports are always there to look up.
@available(System 199, *)
final class Win32DynamicLibraryTests: XCTestCase {
  private typealias GetCurrentProcessIdFunction = @convention(c) () -> DWORD

  func testConstantsMatchTheSDK() {
    let options: [(DynamicLibrary.LoadOptions, DWORD)] = [
      (.alteredSearchPath, DWORD(WinSDK.LOAD_WITH_ALTERED_SEARCH_PATH)),
      (.searchLibraryDirectory, DWORD(WinSDK.LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR)),
      (.searchApplicationDirectory, DWORD(WinSDK.LOAD_LIBRARY_SEARCH_APPLICATION_DIR)),
      (.searchUserDirectories, DWORD(WinSDK.LOAD_LIBRARY_SEARCH_USER_DIRS)),
      (.searchSystemDirectory, DWORD(WinSDK.LOAD_LIBRARY_SEARCH_SYSTEM32)),
      (.searchDefaultDirectories, DWORD(WinSDK.LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)),
    ]
    for (option, value) in options {
      XCTAssertEqual(option.rawValue, value, "\(option)")
    }
  }

  func testLoadingAndLookingUp() throws {
    let library = try DynamicLibrary("kernel32.dll")
    let address = try XCTUnwrap(library.address(of: "GetCurrentProcessId"))
    let function = unsafeBitCast(address, to: GetCurrentProcessIdFunction.self)
    XCTAssertEqual(function(), GetCurrentProcessId())
    XCTAssertNil(library.address(of: "SystemTestsNoSuchFunction"))
    // The C-string overload of the lookup.
    let viaCString = "GetCurrentProcessId".withCString { library.address(of: $0) }
    XCTAssertEqual(viaCString, address)
    try library.close()
  }

  func testLoadOptionsAndTheCStringOverload() throws {
    // Neither String.withCString nor Array.withUnsafeBufferPointer can
    // return a noncopyable value, so the C string is allocated here.
    let units = Array("kernel32".utf16) + [0]
    let name = UnsafeMutablePointer<WCHAR>.allocate(capacity: units.count)
    name.initialize(from: units, count: units.count)
    defer { name.deallocate() }
    let library = try DynamicLibrary(name, options: .searchSystemDirectory)
    // A loaded library's handle is the module's, whichever reference holds it.
    let loaded = "kernel32.dll".withCString(encodedAs: UTF16.self) { GetModuleHandleW($0) }
    XCTAssertEqual(library.handle, loaded)
    XCTAssertNotNil(library.address(of: "GetCurrentProcessId"))
    try library.close()
  }

  func testMissingLibraries() {
    XCTAssertThrowsWin32Error(.moduleNotFound) {
      try DynamicLibrary("system-tests-no-such-library.dll")
    }
    XCTAssertThrowsWin32Error(.moduleNotFound) {
      try DynamicLibrary(alreadyLoaded: "system-tests-not-loaded.dll")
    }
  }

  func testAlreadyLoaded() throws {
    let ntdll = try DynamicLibrary(alreadyLoaded: "ntdll.dll")
    XCTAssertNotNil(ntdll.address(of: "NtQueryInformationFile"))
    try ntdll.close()
  }

  func testMainProgram() throws {
    let program = try DynamicLibrary.mainProgram()
    XCTAssertEqual(program.handle, GetModuleHandleW(nil))
    try program.close()
  }

  func testTakingAndRelinquishing() throws {
    let raw = try XCTUnwrap("kernel32.dll".withCString(encodedAs: UTF16.self) { LoadLibraryW($0) })
    let library = DynamicLibrary(taking: raw)
    let handle = library.relinquish()
    XCTAssertEqual(handle, raw)
    // Still a reference of the caller's to free.
    XCTAssertTrue(FreeLibrary(handle))
  }
}

#endif // os(Windows)
