/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library calls that System wraps provisionally (see
// Sources/System/Provisional): C strings, character classes, and C
// standard I/O.
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

// A pointer to a C stream. wasi-libc's FILE is an incomplete type, which
// Swift imports only as a pointer, OpaquePointer.
#if os(WASI)
@usableFromInline internal typealias _CFilePointer = OpaquePointer
#else
@usableFromInline internal typealias _CFilePointer = UnsafeMutablePointer<FILE>
#endif

#if ENABLE_MOCKING
// What a mocked fopen or fdopen returns: an address no stream is at.
internal var _mockStream: _CFilePointer {
  _CFilePointer(bitPattern: 0x5710)!
}

private func _mockStreamResult(_ result: CInt) -> _CFilePointer? {
  result == -1 ? nil : _mockStream
}
#endif

// MARK: - string.h

// strlen is system_strlen, in Exports.swift. A mocked strdup or strndup
// records its arguments and fails if an error is forced; otherwise it
// copies for real, so that the caller can use and free the copy, as a
// mocked allocation does (Syscalls+Memory.swift). The others can't fail.

internal func system_strnlen(_ string: UnsafePointer<CChar>, _ maxLength: Int) -> Int {
  strnlen(string, maxLength)
}

internal func system_strdup(_ string: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(path: string) != 0 { return nil }
#endif
  return strdup(string)
}

internal func system_strndup(
  _ string: UnsafePointer<CChar>, _ maxLength: Int
) -> UnsafeMutablePointer<CChar>? {
#if ENABLE_MOCKING
  // Record the bytes strndup reads, which needn't end with a null byte.
  if mockingEnabled {
    let bytes = UnsafeRawBufferPointer(start: string, count: strnlen(string, maxLength))
    if _mock(String(decoding: bytes, as: UTF8.self), maxLength) != 0 { return nil }
  }
#endif
  return strndup(string, maxLength)
}

internal func system_strcmp(_ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>) -> CInt {
  strcmp(string, other)
}

internal func system_strncmp(
  _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>, _ maxLength: Int
) -> CInt {
  strncmp(string, other, maxLength)
}

// glibc has strlcpy only from 2.38, and WASI's libc may not declare it, so
// there it's strlen and a copy.
internal func system_strlcpy(
  _ destination: UnsafeMutablePointer<CChar>, _ source: UnsafePointer<CChar>, _ size: Int
) -> Int {
#if canImport(Glibc) || os(WASI)
  let length = strlen(source)
  if size > 0 {
    let count = min(length, size - 1)
    UnsafeMutableRawPointer(destination).copyMemory(from: source, byteCount: count)
    destination[count] = 0
  }
  return length
#else
  return strlcpy(destination, source, size)
#endif
}

// MARK: - ctype.h

// None of them can fail.

internal func system_isspace(_ c: CInt) -> CInt { isspace(c) }
internal func system_isblank(_ c: CInt) -> CInt { isblank(c) }
internal func system_isdigit(_ c: CInt) -> CInt { isdigit(c) }
internal func system_isxdigit(_ c: CInt) -> CInt { isxdigit(c) }
internal func system_isalpha(_ c: CInt) -> CInt { isalpha(c) }
internal func system_isalnum(_ c: CInt) -> CInt { isalnum(c) }
internal func system_isupper(_ c: CInt) -> CInt { isupper(c) }
internal func system_islower(_ c: CInt) -> CInt { islower(c) }
internal func system_ispunct(_ c: CInt) -> CInt { ispunct(c) }
internal func system_isprint(_ c: CInt) -> CInt { isprint(c) }
internal func system_isgraph(_ c: CInt) -> CInt { isgraph(c) }
internal func system_iscntrl(_ c: CInt) -> CInt { iscntrl(c) }
internal func system_tolower(_ c: CInt) -> CInt { tolower(c) }
internal func system_toupper(_ c: CInt) -> CInt { toupper(c) }

// MARK: - execinfo.h

#if SYSTEM_PACKAGE_DARWIN
// Neither sets errno; backtrace_symbols returns NULL when it can't allocate.
internal func system_backtrace(
  _ buffer: UnsafeMutablePointer<UnsafeMutableRawPointer?>, _ count: CInt
) -> CInt {
  backtrace(buffer, count)
}

internal func system_backtrace_symbols(
  _ addresses: UnsafePointer<UnsafeMutableRawPointer?>, _ count: CInt
) -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? {
  backtrace_symbols(addresses, count)
}
#endif

// MARK: - stdio

// fopen
internal func system_fopen(
  _ path: UnsafePointer<CChar>, _ mode: UnsafePointer<CChar>
) -> _CFilePointer? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockStreamResult(_mock(path: path, String(cString: mode))) }
#endif
  return fopen(path, mode)
}

// fdopen
internal func system_fdopen(
  _ fd: CInt, _ mode: UnsafePointer<CChar>
) -> _CFilePointer? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockStreamResult(_mock(fd, String(cString: mode))) }
#endif
  return fdopen(fd, mode)
}

// fclose
internal func system_fclose(_ stream: _CFilePointer) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream)) }
#endif
  return fclose(stream)
}

// fflush
internal func system_fflush(_ stream: _CFilePointer?) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(stream.map { Int(bitPattern: $0) } ?? 0) }
#endif
  return fflush(stream)
}

// fwrite: the count of bytes written, which is short only after an error.
internal func system_fwrite(
  _ bytes: UnsafeRawPointer?, _ count: Int, _ stream: _CFilePointer
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(Int(bitPattern: stream), count) == -1 ? 0 : count }
#endif
  return fwrite(bytes, 1, count, stream)
}

// fputs
internal func system_fputs(
  _ string: UnsafePointer<CChar>, _ stream: _CFilePointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream), String(cString: string)) == -1 ? EOF : 0 }
#endif
  return fputs(string, stream)
}

// fputc
internal func system_fputc(_ byte: CInt, _ stream: _CFilePointer) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream), byte) == -1 ? EOF : byte }
#endif
  return fputc(byte, stream)
}

// fread: the count of bytes read, which is short at the end or after an error.
internal func system_fread(
  _ bytes: UnsafeMutableRawPointer?, _ count: Int, _ stream: _CFilePointer
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(Int(bitPattern: stream), count) == -1 ? 0 : count }
#endif
  return fread(bytes, 1, count, stream)
}

// getline: the count of bytes read, or -1 at the end or after an error. A
// mocked getline reads nothing, so it returns 0 and leaves the line alone.
internal func system_getline(
  _ line: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
  _ capacity: UnsafeMutablePointer<Int>,
  _ stream: _CFilePointer
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(Int(bitPattern: stream)) }
#endif
  return getline(line, capacity, stream)
}

// fileno
internal func system_fileno(_ stream: _CFilePointer) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: stream)) }
#endif
  return fileno(stream)
}

// setvbuf
internal func system_setvbuf(
  _ stream: _CFilePointer,
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
internal func system_ferror(_ stream: _CFilePointer) -> CInt {
  ferror(stream)
}

// feof
internal func system_feof(_ stream: _CFilePointer) -> CInt {
  feof(stream)
}

// clearerr
internal func system_clearerr(_ stream: _CFilePointer) {
  clearerr(stream)
}

// wasi-libc defines the stream locks only with threads.
#if !os(WASI) || _runtime(_multithreaded)
// flockfile
internal func system_flockfile(_ stream: _CFilePointer) {
  flockfile(stream)
}

// funlockfile
internal func system_funlockfile(_ stream: _CFilePointer) {
  funlockfile(stream)
}

// ftrylockfile
internal func system_ftrylockfile(_ stream: _CFilePointer) -> CInt {
  ftrylockfile(stream)
}
#endif // !os(WASI) || _runtime(_multithreaded)

#endif // !os(Windows)
