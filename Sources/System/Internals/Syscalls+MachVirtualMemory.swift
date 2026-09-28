/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Mach virtual memory: vm_allocate, vm_deallocate and vm_copy, in the
// calling task. They return a kern_return_t rather than setting errno; the
// mock hooks return the forced error number as one.

#if SYSTEM_PACKAGE_DARWIN

import Darwin.Mach

internal func system_vm_allocate(
  _ address: UnsafeMutablePointer<vm_address_t>, _ size: vm_size_t, _ flags: CInt
) -> kern_return_t {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(size, flags)
    // A made-up page boundary, which a test mustn't touch.
    if result == 0 && size > 0 { address.pointee = 0x10_0000 }
    return result
  }
#endif
  return vm_allocate(mach_task_self_, address, size, flags)
}

internal func system_vm_deallocate(
  _ address: vm_address_t, _ size: vm_size_t
) -> kern_return_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(address, size) }
#endif
  return vm_deallocate(mach_task_self_, address, size)
}

internal func system_vm_copy(
  _ source: vm_address_t, _ size: vm_size_t, _ destination: vm_address_t
) -> kern_return_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(source, size, destination) }
#endif
  return vm_copy(mach_task_self_, source, size, destination)
}

#endif // SYSTEM_PACKAGE_DARWIN
