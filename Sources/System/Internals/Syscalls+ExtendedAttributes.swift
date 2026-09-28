/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Extended attributes: getxattr, setxattr, removexattr and listxattr, and
// their descriptor forms. Darwin's take a position, which is for resource
// forks only, and options, which include XATTR_NOFOLLOW; Linux has an l
// form of each path call instead. These wrappers take the same arguments
// on both, and each has one mock name whichever form it calls.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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

internal func system_getxattr(
  _ path: UnsafePointer<CChar>, _ name: UnsafePointer<CChar>,
  _ value: UnsafeMutableRawPointer?, _ size: Int, noFollow: Bool
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockInt(path: path, String(_errorCorrectingPlatformString: name), size, noFollow)
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return getxattr(path, name, value, size, 0, noFollow ? XATTR_NOFOLLOW : 0)
#else
  return noFollow ? lgetxattr(path, name, value, size) : getxattr(path, name, value, size)
#endif
}

internal func system_fgetxattr(
  _ fd: CInt, _ name: UnsafePointer<CChar>, _ value: UnsafeMutableRawPointer?, _ size: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, String(_errorCorrectingPlatformString: name), size) }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return fgetxattr(fd, name, value, size, 0, 0)
#else
  return fgetxattr(fd, name, value, size)
#endif
}

internal func system_setxattr(
  _ path: UnsafePointer<CChar>, _ name: UnsafePointer<CChar>,
  _ value: UnsafeRawPointer?, _ size: Int, _ flags: CInt, noFollow: Bool
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: path, String(_errorCorrectingPlatformString: name), size, flags, noFollow)
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return setxattr(path, name, value, size, 0, flags | (noFollow ? XATTR_NOFOLLOW : 0))
#else
  return noFollow
    ? lsetxattr(path, name, value, size, flags) : setxattr(path, name, value, size, flags)
#endif
}

internal func system_fsetxattr(
  _ fd: CInt, _ name: UnsafePointer<CChar>,
  _ value: UnsafeRawPointer?, _ size: Int, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: name), size, flags)
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return fsetxattr(fd, name, value, size, 0, flags)
#else
  return fsetxattr(fd, name, value, size, flags)
#endif
}

internal func system_removexattr(
  _ path: UnsafePointer<CChar>, _ name: UnsafePointer<CChar>, noFollow: Bool
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: path, String(_errorCorrectingPlatformString: name), noFollow)
  }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return removexattr(path, name, noFollow ? XATTR_NOFOLLOW : 0)
#else
  return noFollow ? lremovexattr(path, name) : removexattr(path, name)
#endif
}

internal func system_fremovexattr(_ fd: CInt, _ name: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, String(_errorCorrectingPlatformString: name)) }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return fremovexattr(fd, name, 0)
#else
  return fremovexattr(fd, name)
#endif
}

// The names are null-terminated, one after another.
internal func system_listxattr(
  _ path: UnsafePointer<CChar>, _ names: UnsafeMutablePointer<CChar>?, _ size: Int,
  noFollow: Bool
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(path: path, size, noFollow) }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return listxattr(path, names, size, noFollow ? XATTR_NOFOLLOW : 0)
#else
  return noFollow ? llistxattr(path, names, size) : listxattr(path, names, size)
#endif
}

internal func system_flistxattr(
  _ fd: CInt, _ names: UnsafeMutablePointer<CChar>?, _ size: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, size) }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return flistxattr(fd, names, size, 0)
#else
  return flistxattr(fd, names, size)
#endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
