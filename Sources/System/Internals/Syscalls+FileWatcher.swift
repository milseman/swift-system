/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// inotify, for FileWatcher.swift. A watch's path is recorded by value.

#if os(Linux) || os(Android)

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

internal func system_inotify_init1(_ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(flags) }
#endif
  return inotify_init1(flags)
}

internal func system_inotify_add_watch(
  _ fd: CInt, _ path: UnsafePointer<CChar>, _ mask: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), mask)
  }
#endif
  return inotify_add_watch(fd, path, mask)
}

internal func system_inotify_rm_watch(_ fd: CInt, _ watch: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, watch) }
#endif
  return inotify_rm_watch(fd, watch)
}

#endif // os(Linux) || os(Android)
