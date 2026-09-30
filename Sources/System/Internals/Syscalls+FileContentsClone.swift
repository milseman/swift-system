/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Linux's FICLONE ioctl (FileContentsClone.swift), through a CSystem shim:
// the request is _IOW(0x94, 9, int), a macro Swift can't import, whose
// encoding differs by architecture.

#if os(Linux) || os(Android)
import CSystem

internal func system_ficlone(_ fd: CInt, _ source: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, source) }
#endif
  return _system_ioctl_FICLONE(fd, source)
}

#endif // os(Linux) || os(Android)
