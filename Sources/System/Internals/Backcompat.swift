/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

extension String {
  internal init(
    _unsafeUninitializedCapacity capacity: Int,
    initializingUTF8With body: (UnsafeMutableBufferPointer<UInt8>) throws -> Int
  ) rethrows {
    if #available(macOS 11, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      self = try String(
        unsafeUninitializedCapacity: capacity,
        initializingUTF8With: body)
      return
    }

    let start = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    defer { start.deallocate() }
    let count = try body(UnsafeMutableBufferPointer(start: start, count: capacity))
    self = String(
      decoding: UnsafeBufferPointer(start: start, count: count),
      as: UTF8.self)
  }
}
