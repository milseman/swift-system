/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The ioctl that returns a VM socket's local context ID.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
import SystemPackage

internal func system_ioctl(
  _ fd: CInt, _ request: UInt, _ value: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, request) }
#endif
  return ioctl(fd, request, value)
}

// IOCTL_VM_SOCKETS_GET_LOCAL_CID, _IOR('s', 209, uint32_t), a macro that
// Swift can't import: IOC_OUT, the argument's size, the group, the number.
internal var _IOCTL_VM_SOCKETS_GET_LOCAL_CID: UInt {
  0x4000_0000 | UInt(MemoryLayout<UInt32>.size) << 16 | UInt(UInt8(ascii: "s")) << 8 | 209
}
#endif
