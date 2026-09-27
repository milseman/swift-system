/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The file copying and cloning calls: copyfile and fcopyfile with their
// state, and clonefile, clonefileat, and fclonefileat.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// copyfile
internal func system_copyfile(
  _ from: UnsafePointer<CInterop.PlatformChar>,
  _ to: UnsafePointer<CInterop.PlatformChar>?,
  _ state: copyfile_state_t?,
  _ flags: copyfile_flags_t
) -> CInt {
#if ENABLE_MOCKING
  // Records whether there's a state, rather than its address.
  if mockingEnabled {
    return _mock(
      path: from, to.map { String(_errorCorrectingPlatformString: $0) },
      state != nil, flags)
  }
#endif
  return copyfile(from, to, state, flags)
}

// fcopyfile
internal func system_fcopyfile(
  _ from: CInt, _ to: CInt, _ state: copyfile_state_t?, _ flags: copyfile_flags_t
) -> CInt {
#if ENABLE_MOCKING
  // Records whether there's a state, rather than its address.
  if mockingEnabled { return _mock(from, to, state != nil, flags) }
#endif
  return fcopyfile(from, to, state, flags)
}

// The state calls only allocate, free, and access memory, so they have no
// mock hooks: a mock test's copy uses a real state.

// copyfile_state_alloc
internal func system_copyfile_state_alloc() -> copyfile_state_t? {
  copyfile_state_alloc()
}

// copyfile_state_free
internal func system_copyfile_state_free(_ state: copyfile_state_t) -> CInt {
  copyfile_state_free(state)
}

// copyfile_state_get
internal func system_copyfile_state_get(
  _ state: copyfile_state_t, _ flag: UInt32, _ value: UnsafeMutableRawPointer
) -> CInt {
  copyfile_state_get(state, flag, value)
}

// copyfile_state_set
internal func system_copyfile_state_set(
  _ state: copyfile_state_t, _ flag: UInt32, _ value: UnsafeRawPointer
) -> CInt {
  copyfile_state_set(state, flag, value)
}

// clonefile
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_clonefile(
  _ from: UnsafePointer<CInterop.PlatformChar>,
  _ to: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: from, String(_errorCorrectingPlatformString: to), flags)
  }
#endif
  return clonefile(from, to, flags)
}

// clonefileat
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_clonefileat(
  _ fromFD: CInt,
  _ from: UnsafePointer<CInterop.PlatformChar>,
  _ toFD: CInt,
  _ to: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      fromFD, String(_errorCorrectingPlatformString: from),
      toFD, String(_errorCorrectingPlatformString: to), flags)
  }
#endif
  return clonefileat(fromFD, from, toFD, to, flags)
}

// fclonefileat
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_fclonefileat(
  _ fd: CInt,
  _ toFD: CInt,
  _ to: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, toFD, String(_errorCorrectingPlatformString: to), flags)
  }
#endif
  return fclonefileat(fd, toFD, to, flags)
}

#endif // SYSTEM_PACKAGE_DARWIN
