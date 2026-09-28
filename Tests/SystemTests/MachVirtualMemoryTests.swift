/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import Darwin

@Suite("Mach virtual memory")
private struct MachVirtualMemoryTests {
  typealias VM = Mach.VirtualMemory

  var pageSize: Int { Int(getpagesize()) }

  @available(System 199, *)
  @Test func allocatingZeroedPages() throws {
    let region = try VM.allocate(byteCount: 100)
    #expect(region.count == 100)
    let start = try #require(region.baseAddress)
    #expect(Int(bitPattern: start) % pageSize == 0)
    // The whole page is allocated and zero, past the count asked for.
    let page = UnsafeMutableRawBufferPointer(start: start, count: pageSize)
    #expect(page.allSatisfy { $0 == 0 })
    page.storeBytes(of: 0xFF, toByteOffset: pageSize - 1, as: UInt8.self)
    try VM.deallocate(region)
    // Deallocating again skips the pages, which aren't allocated.
    try VM.deallocate(region)
  }

  @available(System 199, *)
  @Test func allocatingNothing() throws {
    let region = try VM.allocate(byteCount: 0)
    #expect(region.count == 0)
    #expect(region.baseAddress == nil)
    try VM.deallocate(region)
  }

  @available(System 199, *)
  @Test func allocatingTooMuch() {
    #expect(throws: Mach.KernelError.noSpace) {
      try VM.allocate(byteCount: 1 << 62)
    }
  }

  @available(System 199, *)
  @Test func copying() throws {
    let source = try VM.allocate(byteCount: 3 * pageSize)
    defer { try? VM.deallocate(source) }
    let destination = try VM.allocate(byteCount: 3 * pageSize)
    defer { try? VM.deallocate(destination) }
    for i in source.indices { source[i] = UInt8(truncatingIfNeeded: i &* 7) }

    // Whole pages.
    try VM.copy(from: UnsafeRawBufferPointer(source), to: destination.baseAddress!)
    #expect(destination.elementsEqual(source))

    // Anywhere, and exactly the bytes asked for.
    destination.initializeMemory(as: UInt8.self, repeating: 0)
    try VM.copy(
      from: UnsafeRawBufferPointer(rebasing: source[1..<101]),
      to: destination.baseAddress! + 3)
    #expect(destination[2] == 0 && destination[103] == 0)
    #expect(destination[3..<103].elementsEqual(source[1..<101]))
  }

  /// Overlapping regions copy as memmove copies them.
  @available(System 199, *)
  @Test func copyingOverlappingRegions() throws {
    let region = try VM.allocate(byteCount: 4 * pageSize)
    defer { try? VM.deallocate(region) }
    func fill() {
      for i in region.indices { region[i] = UInt8(i / pageSize + 1) }
    }
    func pages() -> [UInt8] { stride(from: 0, to: region.count, by: pageSize).map { region[$0] } }

    fill()
    try VM.copy(
      from: UnsafeRawBufferPointer(rebasing: region[0..<2 * pageSize]),
      to: region.baseAddress! + pageSize)
    #expect(pages() == [1, 1, 2, 4])

    fill()
    try VM.copy(
      from: UnsafeRawBufferPointer(rebasing: region[pageSize..<3 * pageSize]),
      to: region.baseAddress!)
    #expect(pages() == [2, 3, 3, 4])
  }

  @available(System 199, *)
  @Test func copyingToOrFromUnallocatedMemory() throws {
    let region = try VM.allocate(byteCount: 2 * pageSize)
    defer { try? VM.deallocate(region) }
    let first = UnsafeRawBufferPointer(rebasing: region[..<pageSize])

    // Deallocating part of a page deallocates all of it.
    try VM.deallocate(UnsafeMutableRawBufferPointer(rebasing: region[1..<11]))
    #expect(throws: Mach.KernelError.invalidAddress) {
      try VM.copy(from: first, to: region.baseAddress! + pageSize)
    }
    #expect(throws: Mach.KernelError.invalidAddress) {
      try VM.copy(
        from: UnsafeRawBufferPointer(rebasing: region[pageSize...]),
        to: region.baseAddress!)
    }

    // A read-only destination is an invalid address too.
    let second = region.baseAddress! + pageSize
    #expect(mprotect(second, pageSize, PROT_READ) == 0)
    let other = try VM.allocate(byteCount: pageSize)
    defer { try? VM.deallocate(other) }
    #expect(throws: Mach.KernelError.invalidAddress) {
      try VM.copy(from: UnsafeRawBufferPointer(other), to: second)
    }
  }

  @available(System 199, *)
  @Test func kernelErrors() {
    let errors: [(Mach.KernelError, kern_return_t)] = [
      (.invalidAddress, KERN_INVALID_ADDRESS), (.protectionFailure, KERN_PROTECTION_FAILURE),
      (.noSpace, KERN_NO_SPACE), (.invalidArgument, KERN_INVALID_ARGUMENT),
      (.failure, KERN_FAILURE), (.resourceShortage, KERN_RESOURCE_SHORTAGE),
      (.notReceiver, KERN_NOT_RECEIVER), (.noAccess, KERN_NO_ACCESS),
      (.memoryFailure, KERN_MEMORY_FAILURE), (.memoryError, KERN_MEMORY_ERROR),
      (.aborted, KERN_ABORTED), (.invalidName, KERN_INVALID_NAME),
      (.invalidTask, KERN_INVALID_TASK), (.invalidRight, KERN_INVALID_RIGHT),
      (.invalidValue, KERN_INVALID_VALUE), (.invalidCapability, KERN_INVALID_CAPABILITY),
      (.notSupported, KERN_NOT_SUPPORTED), (.operationTimedOut, KERN_OPERATION_TIMED_OUT),
      (.denied, KERN_DENIED), (.notFound, KERN_NOT_FOUND),
    ]
    for (error, code) in errors {
      #expect(error.rawValue == code)
      #expect(error.description == String(cString: mach_error_string(code)))
    }
    #expect(Mach.KernelError.noSpace.description == "(os/kern) no space available")
    #expect(Mach.KernelError(rawValue: 99).description == "unknown error code")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
