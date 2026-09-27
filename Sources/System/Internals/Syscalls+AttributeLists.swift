/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The attribute list calls: getattrlist, fgetattrlist, getattrlistat, and
// getattrlistbulk.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

#if ENABLE_MOCKING
// Records the list's five groups, rather than its address.
private func _groups(_ list: UnsafePointer<attrlist>) -> [UInt32] {
  let list = list.pointee
  return [list.commonattr, list.volattr, list.dirattr, list.fileattr, list.forkattr]
}
#endif

// getattrlist
internal func system_getattrlist(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ list: UnsafeMutablePointer<attrlist>,
  _ buffer: UnsafeMutableRawPointer?,
  _ size: Int,
  _ options: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, _groups(list), size, options) }
#endif
  return getattrlist(path, list, buffer, size, options)
}

// fgetattrlist
internal func system_fgetattrlist(
  _ fd: CInt,
  _ list: UnsafeMutablePointer<attrlist>,
  _ buffer: UnsafeMutableRawPointer?,
  _ size: Int,
  _ options: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, _groups(list), size, options) }
#endif
  return fgetattrlist(fd, list, buffer, size, options)
}

// getattrlistat
internal func system_getattrlistat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ list: UnsafeMutablePointer<attrlist>,
  _ buffer: UnsafeMutableRawPointer?,
  _ size: Int,
  _ options: UInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), _groups(list), size, options)
  }
#endif
  return getattrlistat(fd, path, list, buffer, size, options)
}

// getattrlistbulk, which returns the number of entries it reads.
internal func system_getattrlistbulk(
  _ fd: CInt,
  _ list: UnsafeMutablePointer<attrlist>,
  _ buffer: UnsafeMutableRawPointer?,
  _ size: Int,
  _ options: UInt64
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, _groups(list), size, options) }
#endif
  return getattrlistbulk(fd, list, buffer, size, options)
}

#endif // SYSTEM_PACKAGE_DARWIN
