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

@Suite("Vectored I/O")
private struct VectoredIOTests {
  @available(System 199, *)
  @Test func gatherIntoAPipeAndScatterOut() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let parts: [[UInt8]] = [Array("head".utf8), [], Array("-body-".utf8), Array("tail".utf8)]
    let written = try withVectors(over: parts) { vectors in
      try pipe.writeEnd.write(vectors: vectors)
    }
    #expect(written == 14)

    // Read back into buffers whose sizes don't match the parts.
    var first = [UInt8](repeating: 0, count: 5)
    var second = [UInt8](repeating: 0, count: 20)
    let read = try first.withUnsafeMutableBytes { first in
      try second.withUnsafeMutableBytes { second in
        let vectors = [_ioVector(UnsafeRawBufferPointer(first)),
                       _ioVector(UnsafeRawBufferPointer(second))]
        return try vectors.withUnsafeBufferPointer { try pipe.readEnd.read(intoVectors: $0) }
      }
    }
    #expect(read == 14)
    #expect(first == Array("head-".utf8))
    #expect(Array(second.prefix(9)) == Array("body-tail".utf8))
    #expect(second.dropFirst(9).allSatisfy { $0 == 0 })
  }

  @available(System 199, *)
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  @Test func positionalVectorsLeaveTheOffsetAlone() throws {
    try withTemporaryFilePath(basename: "positionalVectors") { directory in
      let fd = try FileDescriptor.open(
        directory.appending("file"), .readWrite, options: [.create, .truncate],
        permissions: .ownerReadWrite)
      defer { try? fd.close() }

      let written = try withVectors(over: [Array("abc".utf8), Array("defg".utf8)]) {
        try fd.write(toAbsoluteOffset: 10, vectors: $0)
      }
      #expect(written == 7)
      #expect(try fd.seek(offset: 0, from: .current) == 0)

      var buffer = [UInt8](repeating: 0, count: 5)
      let read = try buffer.withUnsafeMutableBytes { buffer in
        try [_ioVector(UnsafeRawBufferPointer(buffer))].withUnsafeBufferPointer {
          try fd.read(fromAbsoluteOffset: 12, intoVectors: $0)
        }
      }
      #expect(read == 5)
      #expect(buffer == Array("cdefg".utf8))
      #expect(try fd.seek(offset: 0, from: .current) == 0)
      #expect(try fd.stat().size == 17)
    }
  }

  @available(System 199, *)
  @Test func emptyAndTooManyVectors() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    #expect(try pipe.writeEnd.write(vectors: UnsafeBufferPointer(start: nil, count: 0)) == 0)

    // The system rejects more vectors than its limit, all at once.
    let limit = try SystemConfig.value(.maxIOVectors) ?? 1024
    let byte: [UInt8] = [0]
    try byte.withUnsafeBytes { byte in
      let vectors = [CInterop.IOVec](repeating: _ioVector(byte), count: limit + 1)
      #expect(throws: Errno.invalidArgument) {
        try vectors.withUnsafeBufferPointer { try pipe.writeEnd.write(vectors: $0) }
      }
    }
  }

  @available(System 199, *)
  @Test func badDescriptor() {
    let bad = FileDescriptor(rawValue: -1)
    #expect(throws: Errno.badFileDescriptor) {
      try withVectors(over: [[1]]) { try bad.write(vectors: $0) }
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func spans() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let header = ContiguousArray<UInt8>([0, 5])
    let payload = ContiguousArray("hello".utf8)
    let trailer = ContiguousArray("\n".utf8)
    #expect(try pipe.writeEnd.write(RawSpan(_elements: header.span), RawSpan(_elements: payload.span)) == 7)
    #expect(try pipe.writeEnd.writeAll(
      RawSpan(_elements: header.span), RawSpan(_elements: payload.span),
      RawSpan(_elements: trailer.span)) == 8)
    #expect(try pipe.writeEnd.write(
      RawSpan(_elements: trailer.span), RawSpan(_elements: trailer.span),
      RawSpan(_elements: trailer.span)) == 3)

    // Scatter the first record into a header and a payload.
    var readHeader = ContiguousArray<UInt8>(repeating: 0, count: 2)
    var readPayload = ContiguousArray<UInt8>(repeating: 0, count: 5)
    do {
      var headerSpan = readHeader.mutableSpan, payloadSpan = readPayload.mutableSpan
      var headerBytes = headerSpan.mutableBytes, payloadBytes = payloadSpan.mutableBytes
      #expect(try pipe.readEnd.read(into: &headerBytes, &payloadBytes) == 7)
    }
    #expect(Array(readHeader) == [0, 5])
    #expect(Array(readPayload) == Array("hello".utf8))

    // And the rest into three buffers, the last one only partly.
    var one = ContiguousArray<UInt8>(repeating: 0, count: 2)
    var two = ContiguousArray<UInt8>(repeating: 0, count: 6)
    var three = ContiguousArray<UInt8>(repeating: 0, count: 10)
    do {
      var oneSpan = one.mutableSpan, twoSpan = two.mutableSpan, threeSpan = three.mutableSpan
      var oneBytes = oneSpan.mutableBytes, twoBytes = twoSpan.mutableBytes
      var threeBytes = threeSpan.mutableBytes
      #expect(try pipe.readEnd.read(into: &oneBytes, &twoBytes, &threeBytes) == 11)
    }
    #expect(Array(one) == [0, 5])
    #expect(Array(two) == Array("hello\n".utf8))
    #expect(Array(three.prefix(3)) == Array("\n\n\n".utf8))
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func positionalSpans() throws {
    try withTemporaryFilePath(basename: "positionalSpans") { directory in
      let fd = try FileDescriptor.open(
        directory.appending("file"), .readWrite, options: [.create, .truncate],
        permissions: .ownerReadWrite)
      defer { try? fd.close() }
      let ab = ContiguousArray("ab".utf8), cd = ContiguousArray("cd".utf8)
      let ef = ContiguousArray("ef".utf8)
      #expect(try fd.write(
        toAbsoluteOffset: 4, RawSpan(_elements: ab.span), RawSpan(_elements: cd.span)) == 4)
      #expect(try fd.write(
        toAbsoluteOffset: 0, RawSpan(_elements: ef.span), RawSpan(_elements: ef.span),
        RawSpan(_elements: ef.span)) == 6)
      #expect(try fd.writeAll(
        toAbsoluteOffset: 8, RawSpan(_elements: cd.span), RawSpan(_elements: ab.span)) == 4)
      #expect(try fd.writeAll(
        toAbsoluteOffset: 12, RawSpan(_elements: ab.span), RawSpan(_elements: cd.span),
        RawSpan(_elements: ef.span)) == 6)
      #expect(try fd.seek(offset: 0, from: .current) == 0)

      var x = ContiguousArray<UInt8>(repeating: 0, count: 3)
      var y = ContiguousArray<UInt8>(repeating: 0, count: 3)
      var z = ContiguousArray<UInt8>(repeating: 0, count: 20)
      do {
        var xs = x.mutableSpan, ys = y.mutableSpan
        var xb = xs.mutableBytes, yb = ys.mutableBytes
        #expect(try fd.read(fromAbsoluteOffset: 2, into: &xb, &yb) == 6)
      }
      #expect(String(decoding: x, as: UTF8.self) == "efe")
      #expect(String(decoding: y, as: UTF8.self) == "fcd")
      do {
        var xs = x.mutableSpan, ys = y.mutableSpan, zs = z.mutableSpan
        var xb = xs.mutableBytes, yb = ys.mutableBytes, zb = zs.mutableBytes
        #expect(try fd.read(fromAbsoluteOffset: 0, into: &xb, &yb, &zb) == 18)
      }
      #expect(String(decoding: Array(x) + Array(y) + Array(z.prefix(12)), as: UTF8.self) == "efefefcdcdababcdef")
      #expect(try fd.seek(offset: 0, from: .current) == 0)
    }
  }
}

/// Calls `body` with vectors over `parts`.
@available(System 199, *)
private func withVectors<R>(
  over parts: [[UInt8]],
  _ body: (UnsafeBufferPointer<CInterop.IOVec>) throws -> R
) throws -> R {
  func recurse(_ index: Int, _ vectors: [CInterop.IOVec]) throws -> R {
    guard index < parts.count else {
      return try vectors.withUnsafeBufferPointer(body)
    }
    return try parts[index].withUnsafeBytes {
      try recurse(index + 1, vectors + [_ioVector($0)])
    }
  }
  return try recurse(0, [])
}

#endif // !os(Windows) && !os(WASI)
