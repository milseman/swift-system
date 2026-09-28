/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Removing a file hierarchy: removefile and removefileat, with their state.
// <removefile.h> isn't in the Darwin module, so these come from CSystem.

#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin

// removefile
internal func system_removefile(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ state: removefile_state_t?,
  _ flags: removefile_flags_t
) -> CInt {
#if ENABLE_MOCKING
  // Records whether there's a state, rather than its address.
  if mockingEnabled { return _mock(path: path, state != nil, flags) }
#endif
  return removefile(path, state, flags)
}

// removefileat
internal func system_removefileat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ state: removefile_state_t?,
  _ flags: removefile_flags_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), state != nil, flags)
  }
#endif
  return removefileat(fd, path, state, flags)
}

// The state calls only allocate, free, and access memory, so they have no
// mock hooks: a mock test's removal uses a real state.

// removefile_state_alloc
internal func system_removefile_state_alloc() -> removefile_state_t? {
  removefile_state_alloc()
}

// removefile_state_free
internal func system_removefile_state_free(_ state: removefile_state_t) -> CInt {
  removefile_state_free(state)
}

// removefile_state_get
internal func system_removefile_state_get(
  _ state: removefile_state_t, _ key: UInt32, _ value: UnsafeMutableRawPointer
) -> CInt {
  removefile_state_get(state, key, value)
}

// removefile_state_set
internal func system_removefile_state_set(
  _ state: removefile_state_t, _ key: UInt32, _ value: UnsafeRawPointer?
) -> CInt {
  removefile_state_set(state, key, value)
}

#endif // SYSTEM_PACKAGE_DARWIN
