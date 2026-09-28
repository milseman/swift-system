/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's typed allocation: type descriptors and the allocations that
// take one.

#if SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
final class TypedAllocationTest: XCTestCase {
  typealias TypeDescriptor = Memory.TypeDescriptor

  /// The C union's identifier, after `body` sets its fields.
  private func cIdentifier(_ body: (inout malloc_type_descriptor_v0_t) -> Void) -> UInt64 {
    var descriptor = malloc_type_descriptor_v0_t()
    body(&descriptor)
    return descriptor.type_id
  }

  func testDescriptorsAreTheCUnions() {
    let layouts: [(TypeDescriptor.Layout, UInt64)] = [
      (.containsDataPointer, cIdentifier { $0.summary.layout_semantics.contains_data_pointer = true }),
      (.containsStructPointer, cIdentifier { $0.summary.layout_semantics.contains_struct_pointer = true }),
      (.containsImmutablePointer, cIdentifier { $0.summary.layout_semantics.contains_immutable_pointer = true }),
      (.containsAnonymousPointer, cIdentifier { $0.summary.layout_semantics.contains_anonymous_pointer = true }),
      (.isReferenceCounted, cIdentifier { $0.summary.layout_semantics.is_reference_counted = true }),
      (.containsGenericData, cIdentifier { $0.summary.layout_semantics.contains_generic_data = true }),
    ]
    for (layout, expected) in layouts {
      XCTAssertEqual(TypeDescriptor(layout: layout).rawValue, expected)
      XCTAssertEqual(TypeDescriptor(rawValue: expected).layout, layout)
    }

    let kinds: [(TypeDescriptor.Kind, malloc_type_kind_v0_t)] = [
      (.other, MALLOC_TYPE_KIND_V0_OTHER), (.objectiveC, MALLOC_TYPE_KIND_V0_OBJC),
      (.swift, MALLOC_TYPE_KIND_V0_SWIFT), (.cPlusPlus, MALLOC_TYPE_KIND_V0_CXX),
    ]
    for (kind, cKind) in kinds {
      let expected = cIdentifier { $0.summary.type_kind = cKind }
      XCTAssertEqual(TypeDescriptor(layout: [], kind: kind).rawValue, expected)
      XCTAssertEqual(TypeDescriptor(rawValue: expected).kind, kind)
    }

    let flags: [(TypeDescriptor.CallSiteFlags, malloc_type_callsite_flags_v0_t)] = [
      (.fixedSize, MALLOC_TYPE_CALLSITE_FLAGS_V0_FIXED_SIZE), (.array, MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY),
    ]
    for (flag, cFlag) in flags {
      let expected = cIdentifier { $0.summary.callsite_flags = cFlag }
      XCTAssertEqual(TypeDescriptor(layout: [], callSiteFlags: flag).rawValue, expected)
      XCTAssertEqual(TypeDescriptor(rawValue: expected).callSiteFlags, flag)
    }

    let hashed = cIdentifier { $0.hash = 0xDEAD_BEEF }
    XCTAssertEqual(TypeDescriptor(layout: [], typeHash: 0xDEAD_BEEF).rawValue, hashed)
    XCTAssertEqual(TypeDescriptor(rawValue: hashed).typeHash, 0xDEAD_BEEF)
    XCTAssertEqual(TypeDescriptor(rawValue: hashed).version, 0)
    XCTAssertEqual(TypeDescriptor(layout: []).rawValue, 0)
  }

  func testEachPropertyKeepsTheOthers() {
    var descriptor = TypeDescriptor(
      layout: [.containsDataPointer, .isReferenceCounted], kind: .swift,
      callSiteFlags: .array, typeHash: 0x1234_5678)
    let expected = cIdentifier {
      $0.summary.layout_semantics.contains_data_pointer = true
      $0.summary.layout_semantics.is_reference_counted = true
      $0.summary.type_kind = MALLOC_TYPE_KIND_V0_SWIFT
      $0.summary.callsite_flags = MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY
      $0.hash = 0x1234_5678
    }
    XCTAssertEqual(descriptor.rawValue, expected)

    descriptor.layout = .containsGenericData
    XCTAssertEqual(descriptor.layout, .containsGenericData)
    XCTAssertEqual(descriptor.kind, .swift)
    XCTAssertEqual(descriptor.callSiteFlags, .array)
    XCTAssertEqual(descriptor.typeHash, 0x1234_5678)

    descriptor.kind = .cPlusPlus
    descriptor.callSiteFlags = [.fixedSize, .array]
    descriptor.typeHash = 1
    XCTAssertEqual(descriptor.layout, .containsGenericData)
    XCTAssertEqual(descriptor.kind, .cPlusPlus)
    XCTAssertEqual(descriptor.callSiteFlags, [.fixedSize, .array])
    XCTAssertEqual(descriptor.typeHash, 1)
    XCTAssertEqual(descriptor.version, 0)

    // A version the properties don't know is kept, as are reserved bits.
    let versioned = cIdentifier { $0.summary.version = 1 }
    var other = TypeDescriptor(rawValue: versioned | 1 << 63)
    XCTAssertEqual(other.version, 1)
    other.kind = .objectiveC
    XCTAssertEqual(other.version, 1)
    XCTAssertEqual(other.rawValue >> 63, 1)
  }

  func testAllocations() throws {
    let data = TypeDescriptor(layout: .containsGenericData)
    let pageSize = Int(getpagesize())

    let block = try Memory.allocate(byteCount: 64, type: data)
    block.initializeMemory(as: UInt8.self, repeating: 7, count: 64)
    let grown = try Memory.reallocate(block, byteCount: 4096, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: grown, count: 64).filter { $0 != 7 }.count, 0)
    Memory.free(grown)

    let zeroed = try Memory.allocateZeroed(byteCount: 100, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: zeroed, count: 100).filter { $0 != 0 }.count, 0)
    Memory.free(zeroed)
    let elements = try Memory.allocateZeroed(count: 10, stride: 8, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: elements, count: 80).filter { $0 != 0 }.count, 0)
    Memory.free(elements)
    XCTAssertThrowsError(try Memory.allocateZeroed(count: .max, stride: 16, type: data)) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }

    let aligned = try Memory.allocate(byteCount: 10, alignment: 256, type: data)
    XCTAssertEqual(Int(bitPattern: aligned) % 256, 0)
    Memory.free(aligned)
    XCTAssertThrowsError(try Memory.allocate(byteCount: 10, alignment: 24, type: data)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }

    let page = try Memory.allocatePageAligned(byteCount: 10, type: data)
    XCTAssertEqual(Int(bitPattern: page) % pageSize, 0)
    Memory.free(page)

    // A block that holds pointers, as the Swift runtime would describe it.
    let pointers = TypeDescriptor(
      layout: [.containsStructPointer, .isReferenceCounted], kind: .swift, typeHash: 42)
    let object = try Memory.allocate(byteCount: MemoryLayout<UnsafeRawPointer>.size * 4, type: pointers)
    XCTAssertGreaterThanOrEqual(Memory.usableSize(of: object), MemoryLayout<UnsafeRawPointer>.size * 4)
    Memory.free(object)
  }

  func testZoneAllocations() throws {
    let zone = try Memory.Zone.create(name: "typed")
    defer { zone.destroy() }
    let data = TypeDescriptor(layout: .containsGenericData)
    let pageSize = Int(getpagesize())

    let block = try zone.allocate(byteCount: 32, type: data)
    XCTAssertEqual(Memory.Zone(containing: block), zone)
    block.initializeMemory(as: UInt8.self, repeating: 9, count: 32)
    let grown = try zone.reallocate(block, byteCount: 1024, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: grown, count: 32).filter { $0 != 9 }.count, 0)
    XCTAssertEqual(Memory.Zone(containing: grown), zone)

    let zeroed = try zone.allocateZeroed(byteCount: 48, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: zeroed, count: 48).filter { $0 != 0 }.count, 0)
    let elements = try zone.allocateZeroed(count: 6, stride: 8, type: data)
    XCTAssertEqual(UnsafeRawBufferPointer(start: elements, count: 48).filter { $0 != 0 }.count, 0)

    let aligned = try zone.allocate(byteCount: 10, alignment: 128, type: data)
    XCTAssertEqual(Int(bitPattern: aligned) % 128, 0)
    XCTAssertThrowsError(try zone.allocate(byteCount: 10, alignment: 3, type: data)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
    let page = try zone.allocatePageAligned(byteCount: 10, type: data)
    XCTAssertEqual(Int(bitPattern: page) % pageSize, 0)

    // Memory.free finds a typed block's zone, as it does any block's.
    for pointer in [grown, zeroed, elements, aligned, page] {
      XCTAssertEqual(Memory.Zone(containing: pointer), zone)
      Memory.free(pointer)
    }
  }

  #if ENABLE_MOCKING
  // The calls record their pointers as optionals, which AnyHashable doesn't
  // equate with the pointers themselves.
  private func optional(_ pointer: UnsafeMutableRawPointer?) -> AnyHashable { pointer }

  private func entries(_ mocking: MockingDriver) -> [(String, [AnyHashable])] {
    var result: [(String, [AnyHashable])] = []
    while let entry = mocking.trace.dequeue() { result.append((entry.name, entry.arguments)) }
    return result
  }

  func testRequests() throws {
    let pointerSize = MemoryLayout<UnsafeRawPointer>.size
    let type = TypeDescriptor(layout: .containsGenericData)
    let id = type.rawValue
    try MockingDriver.withMockingEnabled { mocking in
      Memory.free(try Memory.allocate(byteCount: 0, type: type))
      Memory.free(try Memory.allocateZeroed(byteCount: 10, type: type))
      Memory.free(try Memory.allocateZeroed(count: 0, stride: 8, type: type))
      Memory.free(try Memory.allocate(byteCount: 10, alignment: 2, type: type))
      Memory.free(try Memory.allocatePageAligned(byteCount: 0, type: type))
      let block = try Memory.reallocate(nil, byteCount: 5, type: type)
      Memory.free(try Memory.reallocate(block, byteCount: 0, type: type))

      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), [
        "malloc_type_malloc", "malloc_type_calloc", "malloc_type_calloc",
        "malloc_type_posix_memalign", "malloc_type_valloc",
        "malloc_type_realloc", "malloc_type_realloc",
      ])
      // Zero is one byte, and a small alignment a pointer's.
      XCTAssertEqual(calls.map(\.1), [
        [1, id], [1, 10, id], [1, 1, id], [pointerSize, 10, id], [1, id],
        [optional(nil), 5, id], [optional(block), 1, id],
      ] as [[AnyHashable]])

      XCTAssertThrowsError(try Memory.allocate(byteCount: 16, alignment: 12, type: type)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testFailures() throws {
    let type = TypeDescriptor(layout: .containsGenericData)
    try MockingDriver.withMockingEnabled { mocking in
      // A failed allocation is noMemory, whatever errno says.
      mocking.forceErrno = .counted(errno: EIO, count: 1)
      XCTAssertThrowsError(try Memory.allocate(byteCount: 8, type: type)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try Memory.allocateZeroed(byteCount: 8, type: type)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      // posix_memalign returns its error, which is thrown.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertThrowsError(try Memory.allocate(byteCount: 8, alignment: 64, type: type)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      // A failed reallocation leaves the block as it was.
      let block = try Memory.allocate(byteCount: 8, type: type)
      block.storeBytes(of: 7, as: Int.self)
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try Memory.reallocate(block, byteCount: 64, type: type)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      XCTAssertEqual(block.load(as: Int.self), 7)
      Memory.free(block)
      XCTAssertEqual(entries(mocking).map(\.0), [
        "malloc_type_malloc", "malloc_type_calloc", "malloc_type_posix_memalign",
        "malloc_type_malloc", "malloc_type_realloc",
      ])
    }
  }

  func testZoneRequests() throws {
    let pointerSize = MemoryLayout<UnsafeRawPointer>.size
    let type = TypeDescriptor(layout: .containsGenericData)
    let id = type.rawValue
    let zone = try Memory.Zone.create(name: "mocked")
    defer { zone.destroy() }
    let raw = AnyHashable(zone.rawValue)
    try MockingDriver.withMockingEnabled { mocking in
      let block = try zone.allocate(byteCount: 0, type: type)
      let zeroed = try zone.allocateZeroed(byteCount: 8, type: type)
      let elements = try zone.allocateZeroed(count: 2, stride: 0, type: type)
      let aligned = try zone.allocate(byteCount: 8, alignment: 4, type: type)
      let page = try zone.allocatePageAligned(byteCount: 8, type: type)
      let moved = try zone.reallocate(block, byteCount: 16, type: type)
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try zone.allocate(byteCount: 8, type: type)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), [
        "malloc_type_zone_malloc", "malloc_type_zone_calloc", "malloc_type_zone_calloc",
        "malloc_type_zone_memalign", "malloc_type_zone_valloc", "malloc_type_zone_realloc",
        "malloc_type_zone_malloc",
      ])
      XCTAssertEqual(calls.map(\.1), [
        [raw, 1, id], [raw, 1, 8, id], [raw, 1, 1, id], [raw, pointerSize, 8, id],
        [raw, 8, id], [raw, optional(block), 16, id], [raw, 8, id],
      ] as [[AnyHashable]])
      for pointer in [moved, zeroed, elements, aligned, page] { Memory.free(pointer) }
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)
