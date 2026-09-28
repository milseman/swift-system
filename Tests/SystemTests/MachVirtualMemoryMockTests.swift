/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN && ENABLE_MOCKING

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import Darwin

@available(System 199, *)
final class MachVirtualMemoryMockTests: XCTestCase {
  typealias VM = Mach.VirtualMemory

  func testCalls() {
    let source = UnsafeRawBufferPointer(start: UnsafeRawPointer(bitPattern: 0x4000), count: 64)
    let destination = UnsafeMutableRawPointer(bitPattern: 0x8000)!
    let cases: [MockTestCase] = [
      MockTestCase(name: "vm_allocate", .noError, vm_size_t(100), CInt(VM_FLAGS_ANYWHERE)) { _ in
        let region = try VM.allocate(byteCount: 100)
        XCTAssertEqual(region.count, 100)
      },
      MockTestCase(name: "vm_deallocate", .noError, vm_address_t(0x4000), vm_size_t(64)) { _ in
        try VM.deallocate(UnsafeMutableRawBufferPointer(mutating: source))
      },
      MockTestCase(
        name: "vm_copy", .noError, vm_address_t(0x4000), vm_size_t(64), vm_address_t(0x8000)
      ) { _ in
        try VM.copy(from: source, to: destination)
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// The kernel's return code is the error, whatever it is.
  func testErrors() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: KERN_NO_SPACE)
      XCTAssertThrowsError(try VM.allocate(byteCount: 1 << 20)) {
        XCTAssertEqual($0 as? Mach.KernelError, .noSpace)
      }
      mocking.forceErrno = .always(errno: KERN_INVALID_ADDRESS)
      let region = UnsafeMutableRawBufferPointer(
        start: UnsafeMutableRawPointer(bitPattern: 0x4000), count: 1)
      XCTAssertThrowsError(try VM.deallocate(region)) {
        XCTAssertEqual($0 as? Mach.KernelError, .invalidAddress)
      }
      mocking.forceErrno = .always(errno: 1234)
      XCTAssertThrowsError(try VM.copy(from: UnsafeRawBufferPointer(region), to: region.baseAddress!)) {
        XCTAssertEqual($0 as? Mach.KernelError, Mach.KernelError(rawValue: 1234))
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN && ENABLE_MOCKING
