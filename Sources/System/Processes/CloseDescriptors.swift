/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

// Closing, or marking close-on-exec, every descriptor in a range: what a
// process does before it runs another program, so that the program inherits
// only the descriptors it should. Linux and FreeBSD have close_range, and
// OpenBSD has closefrom. Darwin has neither, and macOS lists a process's
// descriptors instead, which glibc's closefrom also falls back to. For
// spawning, POSIX_SPAWN_CLOEXEC_DEFAULT on Darwin, and closeAll(from:) as a
// file action on Linux, do the same in the child without these.
#if os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(macOS)

import CSystem
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
extension FileDescriptor {
  /// Closes every open file descriptor in a range.
  ///
  /// - Parameters:
  ///   - first: The lowest descriptor to close.
  ///   - last: The highest descriptor to close,
  ///     or `nil` for every descriptor from `first` up.
  ///
  /// This method closes descriptors that anything in the process opened,
  /// including other threads and libraries,
  /// and owners such as ``OwnedFD`` that close their descriptors later
  /// would then close numbers that can name other files.
  /// Use it in a process that owns every descriptor in the range,
  /// such as one that's about to run another program.
  ///
  /// On macOS, this method lists the process's descriptors and closes each,
  /// so a descriptor that another thread opens meanwhile can stay open.
  /// On Linux before 5.9, it throws ``Errno/noFunction``.
  ///
  /// The corresponding C function is `close_range`
  /// on Linux, Android, and FreeBSD, and `closefrom` on OpenBSD.
  ///
  /// - Note: Only available on Linux, Android, FreeBSD, OpenBSD, and macOS.
  @_alwaysEmitIntoClient
  public static func closeAll(
    from first: FileDescriptor, through last: FileDescriptor? = nil
  ) throws(Errno) {
    try _closeRange(first, last, markingCloseOnExec: false).get()
  }

  #if !os(OpenBSD)
  /// Sets close-on-exec on every open file descriptor in a range,
  /// so that a program the process runs doesn't inherit them.
  ///
  /// - Parameters:
  ///   - first: The lowest descriptor to change.
  ///   - last: The highest descriptor to change,
  ///     or `nil` for every descriptor from `first` up.
  ///
  /// Unlike closing them, marking descriptors leaves them working
  /// for the rest of the process,
  /// which is how a process that runs another program keeps an exec
  /// that fails from breaking descriptors it still uses.
  ///
  /// On macOS, this method lists the process's descriptors and changes each,
  /// so a descriptor that another thread opens meanwhile can be missed.
  /// On Linux before 5.11, it throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `close_range`,
  /// with `CLOSE_RANGE_CLOEXEC`, on Linux, Android, and FreeBSD.
  ///
  /// - Note: Only available on Linux, Android, FreeBSD, and macOS.
  @_alwaysEmitIntoClient
  public static func setCloseOnExecForAll(
    from first: FileDescriptor, through last: FileDescriptor? = nil
  ) throws(Errno) {
    try _closeRange(first, last, markingCloseOnExec: true).get()
  }
  #endif

  @usableFromInline
  internal static func _closeRange(
    _ first: FileDescriptor, _ last: FileDescriptor?, markingCloseOnExec: Bool
  ) -> Result<(), Errno> {
    guard first.rawValue >= 0, (last?.rawValue ?? .max) >= first.rawValue else {
      return .failure(.invalidArgument)
    }
    #if os(Linux) || os(Android) || os(FreeBSD)
    let flags = markingCloseOnExec ? _CLOSE_RANGE_CLOEXEC : 0
    return nothingOrErrno(retryOnInterrupt: false) {
      system_close_range(
        CUnsignedInt(first.rawValue), CUnsignedInt(last?.rawValue ?? .max), flags)
    }
    #elseif os(OpenBSD)
    guard let last else {
      return nothingOrErrno(retryOnInterrupt: false) { system_closefrom(first.rawValue) }
    }
    // OpenBSD has no close_range, so close a bounded range one at a time.
    for fd in first.rawValue...last.rawValue {
      _ = system_close(fd)
    }
    return .success(())
    #else
    return _openDescriptors().flatMap { descriptors in
      for fd in descriptors where fd >= first.rawValue && fd <= (last?.rawValue ?? .max) {
        let descriptor = FileDescriptor(rawValue: fd)
        if markingCloseOnExec {
          // A descriptor that another thread closed meanwhile is fine.
          if case .failure(let error) = descriptor._descriptorFlags().flatMap({
            descriptor._setDescriptorFlags($0.union(.closeOnExec))
          }), error != .badFileDescriptor {
            return .failure(error)
          }
        } else {
          _ = system_close(fd)
        }
      }
      return .success(())
    }
    #endif
  }

  #if os(macOS)
  // The calling process's open descriptors, from libproc.
  internal static func _openDescriptors() -> Result<[CInt], Errno> {
    // A process rarely has more descriptors open than its soft limit; if
    // the list fills the buffer, try again with a larger one.
    var capacity = max(Int(getdtablesize()), 64)
    for _ in 0..<8 {
      var entries = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
      let size = CInt(clamping: capacity * MemoryLayout<proc_fdinfo>.stride)
      let filled = entries.withUnsafeMutableBytes {
        system_proc_pidinfo(getpid(), _PROC_PIDLISTFDS, 0, $0.baseAddress!, size)
      }
      guard filled > 0 else { return .failure(Errno.current) }
      let count = Int(filled) / MemoryLayout<proc_fdinfo>.stride
      if count < capacity {
        return .success(entries.prefix(count).map(\.proc_fd))
      }
      capacity *= 2
    }
    return .failure(.noMemory)
  }
  #endif
}

#endif // os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(macOS)
