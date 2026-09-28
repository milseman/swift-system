/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: a reusable pool of I/O vectors, on Memory.Buffer, for writing
// many buffers with one writev, as NIO's PendingWritesManager does. Not
// API; see Prototype/Memory/README.md.

import SystemPackage

// The vectors' fields are C's iov_base and iov_len, which a client reaches
// only by importing the C library (MemberImportVisibility). The syscalls-4
// lane's CInterop.IOVec(base:length:), .base and .length (its 338401f,
// not yet in system-next) would replace them, and this import.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

/// A reusable array of I/O vectors, for writing many buffers with one call.
///
///     var pool = try IOVectorPool()
///     let written = try pool.writeAll([header, body], to: socket)
///
/// The pool allocates its vectors once, so that a write allocates nothing:
/// NIO keeps such a pool per event loop. Each write points the vectors at
/// the caller's buffers only for the call's duration.
@available(System 199, *)
public struct IOVectorPool: ~Copyable {
  @usableFromInline
  internal var _vectors: Memory.Buffer<CInterop.IOVec>

  /// The most vectors that one write takes.
  public let limit: Int

  /// The most bytes that one write takes: Darwin's writev rejects a total
  /// that doesn't fit in 32 bits, as NIO's pool also caps it.
  public let byteLimit: Int

  /// Allocates a pool of vectors.
  ///
  /// - Parameters:
  ///   - limit: The most vectors that one write takes,
  ///     or `nil` for the system's limit, `IOV_MAX`.
  ///   - byteLimit: The most bytes that one write takes.
  ///     The default is `Int32.max`, which is Darwin's limit.
  public init(limit: Int? = nil, byteLimit: Int = Int(Int32.max)) throws(Errno) {
    // Not `limit ?? (try ...)`, whose autoclosure throws `any Error`.
    var vectors = limit ?? 0
    if limit == nil { vectors = try SystemConfig.value(.maxIOVectors) ?? 16 }
    precondition(vectors > 0 && byteLimit > 0, "a pool needs room for a vector and a byte")
    self._vectors = try Memory.Buffer(capacity: vectors)
    self.limit = vectors
    self.byteLimit = byteLimit
  }

  /// Points the vectors at as many of the buffers, from a position,
  /// as one write takes.
  ///
  /// - Returns: The number of bytes the vectors cover.
  @usableFromInline
  internal mutating func _gather<Buffers: Collection<UnsafeRawBufferPointer>>(
    _ buffers: Buffers, from position: (index: Buffers.Index, offset: Int)
  ) -> Int {
    _vectors.removeAll()
    var total = 0
    var (index, offset) = position
    while index != buffers.endIndex && _vectors.count < limit && total < byteLimit {
      let buffer = buffers[index]
      let length = Swift.min(buffer.count - offset, byteLimit - total)
      if length > 0 {
        // writev doesn't write through the vectors.
        let base = UnsafeMutableRawPointer(mutating: buffer.baseAddress! + offset)
        // Within capacity, so appending can't fail.
        try! _vectors.append(CInterop.IOVec(iov_base: base, iov_len: length))
        total += length
      }
      guard offset + length == buffer.count else { break }
      (index, offset) = (buffers.index(after: index), 0)
    }
    return total
  }

  /// Writes as many of the buffers as one call takes.
  ///
  /// - Returns: The number of bytes written, which can be fewer than
  ///   the buffers hold.
  ///
  /// The corresponding C function is `writev`.
  public mutating func write(
    _ buffers: some Collection<UnsafeRawBufferPointer>, to fd: FileDescriptor
  ) throws(Errno) -> Int {
    _ = _gather(buffers, from: (buffers.startIndex, 0))
    return try _vectors.withUnsafeBufferPointer { vectors throws(Errno) in
      try fd.write(vectors: vectors)
    }
  }

  /// Writes all of the buffers, in as many calls as it takes,
  /// resuming inside whichever buffer a partial write stopped in.
  ///
  /// - Returns: The number of bytes written, which is all of them.
  ///
  /// The corresponding C function is `writev`.
  public mutating func writeAll<Buffers: Collection<UnsafeRawBufferPointer>>(
    _ buffers: Buffers, to fd: FileDescriptor
  ) throws(Errno) -> Int {
    var position = (index: buffers.startIndex, offset: 0)
    var written = 0
    while _gather(buffers, from: position) > 0 {
      var n = try _vectors.withUnsafeBufferPointer { vectors throws(Errno) in
        try fd.write(vectors: vectors)
      }
      written += n
      // Advance past what was written, into the buffer it stopped in.
      while n > 0 {
        let rest = buffers[position.index].count - position.offset
        if n < rest {
          position.offset += n
          n = 0
        } else {
          n -= rest
          position = (buffers.index(after: position.index), 0)
        }
      }
    }
    return written
  }

  /// The vectors of the last write, for tests and tools.
  public var lastVectors: [CInterop.IOVec] {
    _vectors.withUnsafeBufferPointer { Array($0) }
  }

  /// The pool's capacity, which writes never grow.
  public var capacity: Int { _vectors.capacity }
}
