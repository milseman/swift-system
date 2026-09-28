/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library calls that System wraps provisionally (see
// Sources/System/Provisional): C standard I/O.
//
// In a mock test, a stream that fopen or fdopen "opened" is a placeholder
// address, so every call that takes a stream is mocked too, and none of
// them touches it.

#if !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if ENABLE_MOCKING
// What a mocked fopen or fdopen returns: an address no stream is at.
internal var _mockStream: UnsafeMutablePointer<FILE> {
  UnsafeMutablePointer<FILE>(bitPattern: 0x5710)!
}

private func _mockStreamResult(_ result: CInt) -> UnsafeMutablePointer<FILE>? {
  result == -1 ? nil : _mockStream
}
#endif

// MARK: - stdio

// fopen
internal func system_fopen(
  _ path: UnsafePointer<CChar>, _ mode: UnsafePointer<CChar>
) -> UnsafeMutablePointer<FILE>? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockStreamResult(_mock(path: path, String(cString: mode))) }
#endif
  return fopen(path, mode)
}

// fdopen
internal func system_fdopen(
  _ fd: CInt, _ mode: UnsafePointer<CChar>
) -> UnsafeMutablePointer<FILE>? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockStreamResult(_mock(fd, String(cString: mode))) }
#endif
  return fdopen(fd, mode)
}

// fclose
internal func system_fclose(_ stream: UnsafeMutablePointer<FILE>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream)) }
#endif
  return fclose(stream)
}

// fflush
internal func system_fflush(_ stream: UnsafeMutablePointer<FILE>?) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(stream.map { Int(bitPattern: $0) } ?? 0) }
#endif
  return fflush(stream)
}

// fwrite: the count of bytes written, which is short only after an error.
internal func system_fwrite(
  _ bytes: UnsafeRawPointer?, _ count: Int, _ stream: UnsafeMutablePointer<FILE>
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(Int(bitPattern: stream), count) == -1 ? 0 : count }
#endif
  return fwrite(bytes, 1, count, stream)
}

// fread: the count of bytes read, which is short at the end or after an error.
internal func system_fread(
  _ bytes: UnsafeMutableRawPointer?, _ count: Int, _ stream: UnsafeMutablePointer<FILE>
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(Int(bitPattern: stream), count) == -1 ? 0 : count }
#endif
  return fread(bytes, 1, count, stream)
}

// fileno
internal func system_fileno(_ stream: UnsafeMutablePointer<FILE>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream)) }
#endif
  return fileno(stream)
}

// setvbuf
internal func system_setvbuf(
  _ stream: UnsafeMutablePointer<FILE>,
  _ buffer: UnsafeMutablePointer<CChar>?,
  _ mode: CInt,
  _ size: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(Int(bitPattern: stream), buffer.map { Int(bitPattern: $0) } ?? 0, mode, size)
  }
#endif
  return setvbuf(stream, buffer, mode, size)
}

// The calls that can't fail have no mock hooks, since a mock test's stream
// is a placeholder that they'd touch; those tests don't call them.

// ferror
internal func system_ferror(_ stream: UnsafeMutablePointer<FILE>) -> CInt {
  ferror(stream)
}

// feof
internal func system_feof(_ stream: UnsafeMutablePointer<FILE>) -> CInt {
  feof(stream)
}

// clearerr
internal func system_clearerr(_ stream: UnsafeMutablePointer<FILE>) {
  clearerr(stream)
}

#if !os(WASI)
// flockfile
internal func system_flockfile(_ stream: UnsafeMutablePointer<FILE>) {
  flockfile(stream)
}

// funlockfile
internal func system_funlockfile(_ stream: UnsafeMutablePointer<FILE>) {
  funlockfile(stream)
}

// ftrylockfile
internal func system_ftrylockfile(_ stream: UnsafeMutablePointer<FILE>) -> CInt {
  ftrylockfile(stream)
}
#endif // !os(WASI)

#endif // !os(Windows)
