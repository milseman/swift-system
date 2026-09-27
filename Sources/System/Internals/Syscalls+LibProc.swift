/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The libproc calls beyond proc_pid_rusage and proc_pidinfo, whose
// wrappers are in Syscalls.swift: proc_pidpath, proc_name, and
// proc_listpids. Each returns a length, or 0 with errno set for an error.

// libproc is only in the macOS SDK.
#if os(macOS)
import Darwin

// proc_pidpath
internal func system_proc_pidpath(
  _ pid: pid_t, _ buffer: UnsafeMutableRawPointer, _ size: UInt32
) -> CInt {
#if ENABLE_MOCKING
  // Reports success the way the call does, with a length.
  if mockingEnabled { return _mock(pid, size) == 0 ? 1 : 0 }
#endif
  return proc_pidpath(pid, buffer, size)
}

// proc_name
internal func system_proc_name(
  _ pid: pid_t, _ buffer: UnsafeMutableRawPointer, _ size: UInt32
) -> CInt {
#if ENABLE_MOCKING
  // Reports success the way the call does, with a length.
  if mockingEnabled { return _mock(pid, size) == 0 ? 1 : 0 }
#endif
  return proc_name(pid, buffer, size)
}

// proc_listpids, which returns the number of bytes it fills. It returns 0
// both for an error and for no processes, so the caller clears errno first.
internal func system_proc_listpids(
  _ type: UInt32, _ typeinfo: UInt32,
  _ buffer: UnsafeMutableRawPointer?, _ size: CInt
) -> CInt {
#if ENABLE_MOCKING
  // Fills nothing, and sets errno if an error is forced.
  if mockingEnabled {
    _ = _mock(type, typeinfo, size)
    return 0
  }
#endif
  return proc_listpids(type, typeinfo, buffer, size)
}

#endif // os(macOS)
