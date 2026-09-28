/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Named shared memory and semaphores: shm_open, shm_unlink, sem_open,
// sem_close, sem_unlink, sem_wait, sem_trywait, and sem_post. shm_open is
// variadic, so it comes from CSystem; the Swift overlays declare sem_open.
//
// In a mock test, a semaphore that sem_open "opened" is a placeholder
// address, so every call that takes one is mocked too, and none touches it.

#if !os(Windows) && !os(WASI) && !os(Android)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

// shm_open
internal func system_shm_open(
  _ name: UnsafePointer<CChar>, _ oflag: CInt, _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name, oflag, mode) }
#endif
  return csystem_shm_open(name, oflag, UInt32(mode))
}

// shm_unlink
internal func system_shm_unlink(_ name: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name) }
#endif
  return shm_unlink(name)
}

#if ENABLE_MOCKING
// What a mocked sem_open returns: an address no semaphore is at.
internal var _mockSemaphore: UnsafeMutablePointer<sem_t> {
  UnsafeMutablePointer<sem_t>(bitPattern: 0x5E70)!
}
#endif

// sem_open, returning nil rather than SEM_FAILED
internal func system_sem_open(
  _ name: UnsafePointer<CChar>, _ oflag: CInt, _ mode: CInterop.Mode, _ value: CUnsignedInt
) -> UnsafeMutablePointer<sem_t>? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name, oflag, mode, value) == -1 ? nil : _mockSemaphore }
#endif
  guard let semaphore = sem_open(name, oflag, mode, value), semaphore != SEM_FAILED else {
    return nil
  }
  return semaphore
}

// sem_close
internal func system_sem_close(_ semaphore: UnsafeMutablePointer<sem_t>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: semaphore)) }
#endif
  return sem_close(semaphore)
}

// sem_unlink
internal func system_sem_unlink(_ name: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name) }
#endif
  return sem_unlink(name)
}

// sem_wait
internal func system_sem_wait(_ semaphore: UnsafeMutablePointer<sem_t>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: semaphore)) }
#endif
  return sem_wait(semaphore)
}

// sem_trywait
internal func system_sem_trywait(_ semaphore: UnsafeMutablePointer<sem_t>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: semaphore)) }
#endif
  return sem_trywait(semaphore)
}

// sem_post
internal func system_sem_post(_ semaphore: UnsafeMutablePointer<sem_t>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(bitPattern: semaphore)) }
#endif
  return sem_post(semaphore)
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
