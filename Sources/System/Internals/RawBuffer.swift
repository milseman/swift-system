/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A copy-on-write fixed-size buffer of raw memory.
internal struct _RawBuffer {
  internal var _storage: Storage
}

extension _RawBuffer {
  internal init(
    unsafeUninitializedMinimumCapacity minimumCapacity: Int,
    initializingWith body: (UnsafeMutableRawBufferPointer) throws -> Int
  ) rethrows {
    _storage = Storage.create(minimumCapacity: minimumCapacity)
    try _storage.withUnsafeMutablePointers { count, bytes in
      let buffer = UnsafeMutableRawBufferPointer(start: bytes, count: count.pointee)
      let c = try body(buffer)
      precondition(c >= 0 && c <= count.pointee)
      count.pointee = c
    }
  }

  internal var capacity: Int {
    _storage.header // Note: not capacity!
  }

  internal mutating func ensureUnique() {
    let unique = isKnownUniquelyReferenced(&_storage)
    if !unique {
      _storage = _storage.copy(capacity: capacity)
    }
  }

  internal func _grow(desired: Int) -> Int {
    let next = Int(1.75 * Double(self.capacity))
    return Swift.max(next, desired)
  }

  internal mutating func ensureUnique(capacity: Int) {
    let unique = isKnownUniquelyReferenced(&_storage)
    if !unique || self.capacity > capacity {
      _storage = _storage.copy(capacity: _grow(desired: capacity))
    }
  }

  internal func withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try _storage.withUnsafeMutablePointers { count, bytes in
      let buffer = UnsafeRawBufferPointer(start: bytes, count: count.pointee)
      return try body(buffer)
    }
  }

  internal mutating func withUnsafeMutableBytes<R>(
    _ body: (UnsafeMutableRawBufferPointer) throws -> R
  ) rethrows -> R {
    ensureUnique()
    return try _storage.withUnsafeMutablePointers { count, bytes in
      let buffer = UnsafeMutableRawBufferPointer(start: bytes, count: count.pointee)
      return try body(buffer)
    }
  }
}

extension _RawBuffer {
  internal class Storage: ManagedBuffer<Int, UInt8> {
    internal static func create(minimumCapacity: Int) -> Storage {
      Storage.create(
        minimumCapacity: minimumCapacity,
        makingHeaderWith: { $0.capacity }
      ) as! Storage
    }

    internal func copy(capacity: Int) -> Storage {
      let copy = Storage.create(minimumCapacity: capacity)
      copy.withUnsafeMutablePointers { dstlen, dst in
        self.withUnsafeMutablePointers { srclen, src in
          assert(srclen.pointee == dstlen.pointee)
          UnsafeMutableRawPointer(dst)
            .copyMemory(
              from: src,
              byteCount: Swift.min(srclen.pointee, dstlen.pointee))
        }
      }
      return copy
    }
  }
}
