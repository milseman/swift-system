/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Extended attributes: getxattr, setxattr, removexattr and listxattr, and
// their descriptor forms. Darwin's take a position, which is for resource
// forks only, and options, which include XATTR_NOFOLLOW; Linux has an l
// form of each path call instead. FreeBSD's are its extattr calls, in the
// user namespace: a _link form of each path call, no options, a set that
// returns the bytes it wrote, and a list of length-prefixed names. These
// wrappers take the same arguments on each, and each has one mock name
// whichever form it calls.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)

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
#elseif os(FreeBSD)
  return noFollow
    ? extattr_get_link(path, EXTATTR_NAMESPACE_USER, name, value, size)
    : extattr_get_file(path, EXTATTR_NAMESPACE_USER, name, value, size)
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
#elseif os(FreeBSD)
  return extattr_get_fd(fd, EXTATTR_NAMESPACE_USER, name, value, size)
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
#elseif os(FreeBSD)
  // FreeBSD's calls take no options.
  guard flags == 0 else {
    system_errno = EINVAL
    return -1
  }
  let written = noFollow
    ? extattr_set_link(path, EXTATTR_NAMESPACE_USER, name, value, size)
    : extattr_set_file(path, EXTATTR_NAMESPACE_USER, name, value, size)
  return written < 0 ? -1 : 0
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
#elseif os(FreeBSD)
  guard flags == 0 else {
    system_errno = EINVAL
    return -1
  }
  return extattr_set_fd(fd, EXTATTR_NAMESPACE_USER, name, value, size) < 0 ? -1 : 0
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
#elseif os(FreeBSD)
  return noFollow
    ? extattr_delete_link(path, EXTATTR_NAMESPACE_USER, name)
    : extattr_delete_file(path, EXTATTR_NAMESPACE_USER, name)
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
#elseif os(FreeBSD)
  return extattr_delete_fd(fd, EXTATTR_NAMESPACE_USER, name)
#else
  return fremovexattr(fd, name)
#endif
}

// The names are null-terminated, one after another; on FreeBSD, each is
// a length byte and the name, without a terminator.
internal func system_listxattr(
  _ path: UnsafePointer<CChar>, _ names: UnsafeMutablePointer<CChar>?, _ size: Int,
  noFollow: Bool
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(path: path, size, noFollow) }
#endif
#if SYSTEM_PACKAGE_DARWIN
  return listxattr(path, names, size, noFollow ? XATTR_NOFOLLOW : 0)
#elseif os(FreeBSD)
  return noFollow
    ? extattr_list_link(path, EXTATTR_NAMESPACE_USER, names, size)
    : extattr_list_file(path, EXTATTR_NAMESPACE_USER, names, size)
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
#elseif os(FreeBSD)
  return extattr_list_fd(fd, EXTATTR_NAMESPACE_USER, names, size)
#else
  return flistxattr(fd, names, size)
#endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
