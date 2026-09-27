/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Vectored I/O: reading into, and writing from, several buffers with one call.

#if !os(Windows) && !os(WASI)

// Must import here to use the C iovec type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// The C `iovec` type, which describes one buffer of a vectored read or write:
  /// its start, `iov_base`, and its length in bytes, `iov_len`.
  public typealias IOVec = iovec
}

// MARK: - Vectors

@available(System 199, *)
extension FileDescriptor {
  /// Reads bytes at the current file offset into several buffers, in order.
  ///
  /// - Parameters:
  ///   - vectors: The buffers to read into, each described by
  ///     its start and its length in bytes.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// This method fills each buffer before it moves on to the next one,
  /// so if it reads fewer bytes than the buffers can hold,
  /// the bytes are in the first buffers, and the last ones are untouched.
  /// A return value of zero means end of file,
  /// unless the buffers have no room.
  /// For an empty array of vectors, this method returns zero without reading:
  /// POSIX requires `readv` to reject one, as Darwin does, but Linux doesn't.
  ///
  /// Each vector must describe memory that's valid and writable
  /// until this method returns; `vectors` itself can be reused afterward.
  /// The system limits the number of vectors in one call to
  /// ``SystemConfig/Name/maxIOVectors``, and throws ``Errno/invalidArgument``
  /// for more.
  ///
  /// After reading,
  /// this method increments the file's offset by the number of bytes read.
  ///
  /// The corresponding C function is `readv`.
  @_alwaysEmitIntoClient
  public func read(
    intoVectors vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _read(intoVectors: vectors, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _read(
    intoVectors vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    _withVectorPointer(vectors) { base, count in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_readv(self.rawValue, base, count)
      }
    }
  }

  /// Writes the contents of several buffers at the current file offset,
  /// in order.
  ///
  /// - Parameters:
  ///   - vectors: The buffers to write, each described by
  ///     its start and its length in bytes.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// This is a *gathering* write:
  /// the file receives the buffers' bytes as if they were one buffer.
  /// Like ``write(_:retryOnInterrupt:)-(UnsafeRawBufferPointer,_)``,
  /// it can write fewer bytes than the buffers hold,
  /// such as to a socket or a pipe that's nearly full;
  /// the bytes it wrote are always a prefix of the whole.
  /// To resume, advance the vectors past that prefix and call it again.
  /// For an empty array of vectors, this method returns zero without writing:
  /// POSIX requires `writev` to reject one, as Darwin does, but Linux doesn't.
  ///
  /// Each vector must describe memory that's valid
  /// until this method returns; `vectors` itself can be reused afterward.
  /// The system limits the number of vectors in one call to
  /// ``SystemConfig/Name/maxIOVectors``, and throws ``Errno/invalidArgument``
  /// for more.
  ///
  /// After writing,
  /// this method increments the file's offset by the number of bytes written.
  ///
  /// The corresponding C function is `writev`.
  @_alwaysEmitIntoClient
  public func write(
    vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _write(vectors: vectors, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _write(
    vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    _withVectorPointer(vectors) { base, count in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_writev(self.rawValue, base, count)
      }
    }
  }
}

@available(System 199, *)
@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
extension FileDescriptor {
  /// Reads bytes at the specified offset into several buffers, in order.
  ///
  /// - Parameters:
  ///   - offset: The file offset where reading begins.
  ///   - vectors: The buffers to read into, each described by
  ///     its start and its length in bytes.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// Unlike ``read(intoVectors:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `preadv`.
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64,
    intoVectors vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _read(
      fromAbsoluteOffset: offset, intoVectors: vectors,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _read(
    fromAbsoluteOffset offset: Int64,
    intoVectors vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    _withVectorPointer(vectors) { base, count in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_preadv(self.rawValue, base, count, _COffT(offset))
      }
    }
  }

  /// Writes the contents of several buffers at the specified offset,
  /// in order.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - vectors: The buffers to write, each described by
  ///     its start and its length in bytes.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// Unlike ``write(vectors:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwritev`.
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _write(
      toAbsoluteOffset: offset, vectors: vectors,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _write(
    toAbsoluteOffset offset: Int64,
    vectors: UnsafeBufferPointer<CInterop.IOVec>,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    _withVectorPointer(vectors) { base, count in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_pwritev(self.rawValue, base, count, _COffT(offset))
      }
    }
  }

  /// Writes every byte that `vectors` describes, calling `writev`,
  /// or `pwritev` at `offset`, until the whole of it is written,
  /// and advancing `vectors` in place past each partial write.
  @usableFromInline
  internal func _writeAllVectors(
    vectors: UnsafeMutableBufferPointer<CInterop.IOVec>,
    toAbsoluteOffset offset: Int64?,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    var remaining = _advanceVectors(vectors, by: 0)
    var total = 0
    while !remaining.isEmpty {
      let result: Result<Int, Errno>
      if let offset {
        result = _write(
          toAbsoluteOffset: offset + Int64(total),
          vectors: UnsafeBufferPointer(remaining),
          retryOnInterrupt: retryOnInterrupt)
      } else {
        result = _write(
          vectors: UnsafeBufferPointer(remaining),
          retryOnInterrupt: retryOnInterrupt)
      }
      switch result {
      case .success(let count):
        total += count
        remaining = _advanceVectors(remaining, by: count)
      case .failure(let error):
        return .failure(error)
      }
    }
    return .success(total)
  }
}

// MARK: - Spans

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension FileDescriptor {
  /// Writes the contents of two buffers at the current file offset,
  /// in order, with one call.
  ///
  /// - Parameters:
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// This is a *gathering* write, such as of a header and a payload:
  /// the file receives the bytes as if they were one buffer,
  /// without copying them into one.
  /// It can write fewer bytes than `first` and `second` hold,
  /// such as to a socket or a pipe that's nearly full;
  /// the bytes it wrote are always a prefix of the whole.
  /// To write all of them, call ``writeAll(_:_:retryOnInterrupt:)``.
  ///
  /// After writing,
  /// this method increments the file's offset by the number of bytes written.
  ///
  /// The corresponding C function is `writev`.
  @_alwaysEmitIntoClient
  public func write(
    _ first: RawSpan,
    _ second: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        _withVectors(first, second) { vectors in
          _write(vectors: UnsafeBufferPointer(vectors), retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Writes the contents of three buffers at the current file offset,
  /// in order, with one call.
  ///
  /// - Parameters:
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - third: The bytes to write after `second`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// Like ``write(_:_:retryOnInterrupt:)``,
  /// this method can write only a prefix of the bytes.
  /// To write all of them, call ``writeAll(_:_:_:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `writev`.
  @_alwaysEmitIntoClient
  public func write(
    _ first: RawSpan,
    _ second: RawSpan,
    _ third: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        third.withUnsafeBytes { third in
          _withVectors(first, second, third) { vectors in
            _write(vectors: UnsafeBufferPointer(vectors), retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }

  /// Writes the contents of two buffers at the specified offset,
  /// in order, with one call.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// Unlike ``write(_:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwritev`.
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ first: RawSpan,
    _ second: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        _withVectors(first, second) { vectors in
          _write(
            toAbsoluteOffset: offset, vectors: UnsafeBufferPointer(vectors),
            retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Writes the contents of three buffers at the specified offset,
  /// in order, with one call.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - third: The bytes to write after `second`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written, in total.
  ///
  /// Unlike ``write(_:_:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwritev`.
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ first: RawSpan,
    _ second: RawSpan,
    _ third: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        third.withUnsafeBytes { third in
          _withVectors(first, second, third) { vectors in
            _write(
              toAbsoluteOffset: offset, vectors: UnsafeBufferPointer(vectors),
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }

  /// Writes the entire contents of two buffers at the current file offset,
  /// in order, retrying on partial writes.
  ///
  /// - Parameters:
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written:
  ///   the number in `first` and `second` together.
  ///
  /// After a partial write, this method writes the rest,
  /// resuming inside whichever buffer the last write stopped in.
  /// It either writes every byte, or throws an error;
  /// after an error, the file can have received a prefix of the bytes.
  ///
  /// The corresponding C function is `writev`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll(
    _ first: RawSpan,
    _ second: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        _withVectors(first, second) { vectors in
          _writeAllVectors(
            vectors: vectors, toAbsoluteOffset: nil,
            retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Writes the entire contents of three buffers at the current file offset,
  /// in order, retrying on partial writes.
  ///
  /// - Parameters:
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - third: The bytes to write after `second`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written:
  ///   the number in all three buffers together.
  ///
  /// After a partial write, this method writes the rest,
  /// resuming inside whichever buffer the last write stopped in.
  /// It either writes every byte, or throws an error;
  /// after an error, the file can have received a prefix of the bytes.
  ///
  /// The corresponding C function is `writev`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll(
    _ first: RawSpan,
    _ second: RawSpan,
    _ third: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        third.withUnsafeBytes { third in
          _withVectors(first, second, third) { vectors in
            _writeAllVectors(
              vectors: vectors, toAbsoluteOffset: nil,
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }

  /// Writes the entire contents of two buffers at the specified offset,
  /// in order, retrying on partial writes.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written:
  ///   the number in `first` and `second` together.
  ///
  /// Unlike ``writeAll(_:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwritev`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll(
    toAbsoluteOffset offset: Int64,
    _ first: RawSpan,
    _ second: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        _withVectors(first, second) { vectors in
          _writeAllVectors(
            vectors: vectors, toAbsoluteOffset: offset,
            retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Writes the entire contents of three buffers at the specified offset,
  /// in order, retrying on partial writes.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - first: The bytes to write first.
  ///   - second: The bytes to write after `first`.
  ///   - third: The bytes to write after `second`.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written:
  ///   the number in all three buffers together.
  ///
  /// Unlike ``writeAll(_:_:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwritev`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll(
    toAbsoluteOffset offset: Int64,
    _ first: RawSpan,
    _ second: RawSpan,
    _ third: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeBytes { first in
      second.withUnsafeBytes { second in
        third.withUnsafeBytes { third in
          _withVectors(first, second, third) { vectors in
            _writeAllVectors(
              vectors: vectors, toAbsoluteOffset: offset,
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }

  /// Reads bytes at the current file offset into two buffers, in order,
  /// with one call.
  ///
  /// - Parameters:
  ///   - first: The buffer to fill first.
  ///   - second: The buffer to fill after `first`.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// This is a *scattering* read, such as of a fixed-size header
  /// and the payload that follows it.
  /// It overwrites a prefix of the two buffers, as C does:
  /// if it returns `n`, the first `min(n, first.byteCount)` bytes
  /// are in `first`, and the rest are at the start of `second`.
  /// A return value of zero means end of file,
  /// unless both buffers are empty.
  ///
  /// After reading,
  /// this method increments the file's offset by the number of bytes read.
  ///
  /// The corresponding C function is `readv`.
  @_alwaysEmitIntoClient
  @_lifetime(first: copy first)
  @_lifetime(second: copy second)
  public func read(
    into first: inout MutableRawSpan,
    _ second: inout MutableRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeMutableBytes { first in
      second.withUnsafeMutableBytes { second in
        _withVectors(.init(first), .init(second)) { vectors in
          _read(intoVectors: UnsafeBufferPointer(vectors), retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Reads bytes at the current file offset into three buffers, in order,
  /// with one call.
  ///
  /// - Parameters:
  ///   - first: The buffer to fill first.
  ///   - second: The buffer to fill after `first`.
  ///   - third: The buffer to fill after `second`.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// Like ``read(into:_:retryOnInterrupt:)``,
  /// this method fills each buffer before it moves on to the next one.
  ///
  /// The corresponding C function is `readv`.
  @_alwaysEmitIntoClient
  @_lifetime(first: copy first)
  @_lifetime(second: copy second)
  @_lifetime(third: copy third)
  public func read(
    into first: inout MutableRawSpan,
    _ second: inout MutableRawSpan,
    _ third: inout MutableRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeMutableBytes { first in
      second.withUnsafeMutableBytes { second in
        third.withUnsafeMutableBytes { third in
          _withVectors(.init(first), .init(second), .init(third)) { vectors in
            _read(intoVectors: UnsafeBufferPointer(vectors), retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }

  /// Reads bytes at the specified offset into two buffers, in order,
  /// with one call.
  ///
  /// - Parameters:
  ///   - offset: The file offset where reading begins.
  ///   - first: The buffer to fill first.
  ///   - second: The buffer to fill after `first`.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// Unlike ``read(into:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `preadv`.
  @_alwaysEmitIntoClient
  @_lifetime(first: copy first)
  @_lifetime(second: copy second)
  public func read(
    fromAbsoluteOffset offset: Int64,
    into first: inout MutableRawSpan,
    _ second: inout MutableRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeMutableBytes { first in
      second.withUnsafeMutableBytes { second in
        _withVectors(.init(first), .init(second)) { vectors in
          _read(
            fromAbsoluteOffset: offset, intoVectors: UnsafeBufferPointer(vectors),
            retryOnInterrupt: retryOnInterrupt)
        }
      }
    }.get()
  }

  /// Reads bytes at the specified offset into three buffers, in order,
  /// with one call.
  ///
  /// - Parameters:
  ///   - offset: The file offset where reading begins.
  ///   - first: The buffer to fill first.
  ///   - second: The buffer to fill after `first`.
  ///   - third: The buffer to fill after `second`.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read, in total.
  ///
  /// Unlike ``read(into:_:_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `preadv`.
  @_alwaysEmitIntoClient
  @_lifetime(first: copy first)
  @_lifetime(second: copy second)
  @_lifetime(third: copy third)
  public func read(
    fromAbsoluteOffset offset: Int64,
    into first: inout MutableRawSpan,
    _ second: inout MutableRawSpan,
    _ third: inout MutableRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try first.withUnsafeMutableBytes { first in
      second.withUnsafeMutableBytes { second in
        third.withUnsafeMutableBytes { third in
          _withVectors(.init(first), .init(second), .init(third)) { vectors in
            _read(
              fromAbsoluteOffset: offset, intoVectors: UnsafeBufferPointer(vectors),
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      }
    }.get()
  }
}

// MARK: - Internals

// These spell the C type: most have no availability of their own.

/// Calls `body` with the start of `vectors` and their count,
/// or returns zero for no vectors.
///
/// POSIX requires readv and writev to reject an empty array, as Darwin does,
/// but Linux accepts one; either way, no vectors means no bytes.
/// A count too large for a `CInt` becomes `CInt.max`,
/// which the system rejects with `EINVAL`, as it does any count
/// over its limit.
internal func _withVectorPointer(
  _ vectors: UnsafeBufferPointer<iovec>,
  _ body: (UnsafePointer<iovec>, CInt) -> Result<Int, Errno>
) -> Result<Int, Errno> {
  guard let base = vectors.baseAddress, !vectors.isEmpty else { return .success(0) }
  return body(base, CInt(clamping: vectors.count))
}

/// Calls `body` with vectors for two or three buffers,
/// in temporary storage.
@available(System 199, *)
@usableFromInline
internal func _withVectors<R>(
  _ first: UnsafeRawBufferPointer,
  _ second: UnsafeRawBufferPointer,
  _ third: UnsafeRawBufferPointer? = nil,
  _ body: (UnsafeMutableBufferPointer<iovec>) -> R
) -> R {
  let count = third == nil ? 2 : 3
  return withUnsafeTemporaryAllocation(
    of: iovec.self, capacity: count
  ) { vectors in
    let base = vectors.baseAddress!
    base.initialize(to: _ioVector(first))
    (base + 1).initialize(to: _ioVector(second))
    if let third { (base + 2).initialize(to: _ioVector(third)) }
    return body(vectors)
  }
}

/// A vector that describes a buffer.
internal func _ioVector(_ buffer: UnsafeRawBufferPointer) -> iovec {
  iovec(
    iov_base: UnsafeMutableRawPointer(mutating: buffer.baseAddress),
    iov_len: buffer.count)
}

/// Advances `vectors` past their first `count` bytes,
/// shortening the vector that those bytes end in, in place,
/// and returns the vectors that remain, without any empty ones at the start.
internal func _advanceVectors(
  _ vectors: UnsafeMutableBufferPointer<iovec>, by count: Int
) -> UnsafeMutableBufferPointer<iovec> {
  var rest = count
  var index = vectors.startIndex
  while index < vectors.endIndex, rest >= vectors[index].iov_len {
    rest -= vectors[index].iov_len
    index += 1
  }
  if rest > 0 {
    precondition(index < vectors.endIndex, "wrote more bytes than the vectors hold")
    vectors[index].iov_base = vectors[index].iov_base.map { $0 + rest }
    vectors[index].iov_len -= rest
  }
  return UnsafeMutableBufferPointer(rebasing: vectors[index...])
}

#endif // !os(Windows) && !os(WASI)
