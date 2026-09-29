/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

#if os(Linux) || os(Android)
import CSystem
#endif

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

/// Opens a pseudoterminal, and calls `body` with its two ends.
///
/// - Parameters:
///   - body: A closure that takes the controller and the terminal.
///     What the controller writes is input to the terminal,
///     and what the terminal writes can be read from the controller.
///     Both close when `body` returns.
///
/// Neither end becomes the process's controlling terminal,
/// so the terminal's signal characters don't signal any process.
///
/// A new pseudoterminal is in canonical mode with echo,
/// so it echoes the input that the controller writes back to the controller.
/// On Darwin, until the controller reads that output,
/// draining the terminal, or setting its attributes `.afterDrain`
/// or `.afterFlush`, blocks, and closing the terminal waits for a while.
internal func withPseudoterminal<Result>(
  _ body: (_ controller: FileDescriptor, _ terminal: FileDescriptor) throws -> Result
) throws -> Result {
  let controller = FileDescriptor(rawValue: openController(O_RDWR | O_NOCTTY))
  guard controller.rawValue != -1 else { throw Errno(rawValue: errno) }
  defer { try? controller.close() }

  guard grantAccess(controller) == 0, unlock(controller) == 0 else {
    throw Errno(rawValue: errno)
  }
  let terminal = try FileDescriptor.open(
    terminalPath(controller), .readWrite,
    options: FileDescriptor.OpenOptions(rawValue: O_NOCTTY))
  defer { try? terminal.close() }
  return try body(controller, terminal)
}

// glibc declares posix_openpt and its companions only with _XOPEN_SOURCE or
// _GNU_SOURCE, which Swift's Glibc module doesn't define, so CSystem wraps
// them on Linux.

private func openController(_ flags: CInt) -> CInt {
  #if os(Linux) || os(Android)
  csystem_posix_openpt(flags)
  #else
  posix_openpt(flags)
  #endif
}

private func grantAccess(_ controller: FileDescriptor) -> CInt {
  #if os(Linux) || os(Android)
  csystem_grantpt(controller.rawValue)
  #else
  grantpt(controller.rawValue)
  #endif
}

private func unlock(_ controller: FileDescriptor) -> CInt {
  #if os(Linux) || os(Android)
  csystem_unlockpt(controller.rawValue)
  #else
  unlockpt(controller.rawValue)
  #endif
}

/// Returns the path of the terminal that `controller` controls.
private func terminalPath(_ controller: FileDescriptor) throws(Errno) -> String {
  // ptsname returns a buffer that every call shares, which tests running in
  // parallel could race on, so use ptsname_r where the platform has it.
  #if os(Linux) || os(Android)
  return try pathFromBuffer { csystem_ptsname_r(controller.rawValue, $0, $1) }
  #else
  #if SYSTEM_PACKAGE_DARWIN
  if #available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *) {
    return try pathFromBuffer { ptsname_r(controller.rawValue, $0, $1) }
  }
  #endif
  guard let path = ptsname(controller.rawValue) else { throw Errno(rawValue: errno) }
  return String(cString: path)
  #endif
}

/// Calls `ptsnameR` with a buffer and its size,
/// and returns the path it writes there.
private func pathFromBuffer(
  _ ptsnameR: (UnsafeMutablePointer<CChar>, Int) -> CInt
) throws(Errno) -> String {
  var buffer = [CChar](repeating: 0, count: 128)
  let status = buffer.withUnsafeMutableBufferPointer { ptsnameR($0.baseAddress!, $0.count) }
  // Darwin's ptsname_r returns -1 and sets errno;
  // the Linux C libraries return the error number.
  guard status == 0 else { throw Errno(rawValue: status == -1 ? errno : status) }
  return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
}

/// Reads from `fd` until it has read `count` bytes,
/// or until `timeout` milliseconds pass without any arriving.
///
/// A pseudoterminal passes data between its ends asynchronously on some
/// platforms, so a test waits for the data it expects rather than
/// reading only what has already arrived. The timeout only guards against
/// a hang.
internal func readBytes(
  from fd: FileDescriptor, count: Int, timeout: CInt = CInt(hangGuardSeconds * 1_000)
) throws -> [UInt8] {
  var bytes: [UInt8] = []
  while bytes.count < count {
    var request = pollfd(fd: fd.rawValue, events: CShort(POLLIN), revents: 0)
    let ready = poll(&request, 1, timeout)
    guard ready != -1 else {
      if errno == EINTR { continue }
      throw Errno(rawValue: errno)
    }
    guard ready > 0 else { break }
    var chunk = [UInt8](repeating: 0, count: count - bytes.count)
    let length = try chunk.withUnsafeMutableBytes { try fd.read(into: $0) }
    guard length > 0 else { break }
    bytes += chunk.prefix(length)
  }
  return bytes
}

/// Waits up to `timeout` milliseconds for `fd` to have data to read.
internal func isReadable(_ fd: FileDescriptor, timeout: CInt) throws(Errno) -> Bool {
  var request = pollfd(fd: fd.rawValue, events: CShort(POLLIN), revents: 0)
  while true {
    let ready = poll(&request, 1, timeout)
    if ready != -1 { return ready > 0 }
    guard errno == EINTR else { throw Errno(rawValue: errno) }
  }
}

#endif // !os(Windows) && !os(WASI)
