/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Making a path's directories: mkpath_np and mkpathat_np. (confstr's
// wrapper is in Syscalls.swift.)

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// mkpath_np, which returns an error number rather than setting errno.
internal func system_mkpath_np(
  _ path: UnsafePointer<CInterop.PlatformChar>, _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(path: path, mode) }
#endif
  return mkpath_np(path, mode)
}

// mkpathat_np, which returns an error number rather than setting errno.
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_mkpathat_np(
  _ fd: CInt, _ path: UnsafePointer<CInterop.PlatformChar>, _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(fd, String(_errorCorrectingPlatformString: path), mode)
  }
#endif
  return mkpathat_np(fd, path, mode)
}

#endif // SYSTEM_PACKAGE_DARWIN
