/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's unfair lock (os_unfair_lock_*) and the C library's random
// number generator (arc4random, arc4random_uniform, arc4random_buf).
// None of them can fail, so none has a mock hook.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// os_unfair_lock_lock
internal func system_os_unfair_lock_lock(_ lock: UnsafeMutablePointer<os_unfair_lock>) {
  os_unfair_lock_lock(lock)
}

// os_unfair_lock_trylock
internal func system_os_unfair_lock_trylock(_ lock: UnsafeMutablePointer<os_unfair_lock>) -> Bool {
  os_unfair_lock_trylock(lock)
}

// os_unfair_lock_unlock
internal func system_os_unfair_lock_unlock(_ lock: UnsafeMutablePointer<os_unfair_lock>) {
  os_unfair_lock_unlock(lock)
}

// os_unfair_lock_assert_owner
internal func system_os_unfair_lock_assert_owner(_ lock: UnsafeMutablePointer<os_unfair_lock>) {
  os_unfair_lock_assert_owner(lock)
}

// os_unfair_lock_assert_not_owner
internal func system_os_unfair_lock_assert_not_owner(_ lock: UnsafeMutablePointer<os_unfair_lock>) {
  os_unfair_lock_assert_not_owner(lock)
}

// os_unfair_lock_lock_with_flags
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
internal func system_os_unfair_lock_lock_with_flags(
  _ lock: UnsafeMutablePointer<os_unfair_lock>, _ flags: UInt32
) {
  os_unfair_lock_lock_with_flags(lock, __os_unfair_lock_flags_t(rawValue: flags))
}
#endif // SYSTEM_PACKAGE_DARWIN

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

// arc4random
internal func system_arc4random() -> UInt32 {
  arc4random()
}

// arc4random_uniform
internal func system_arc4random_uniform(_ upperBound: UInt32) -> UInt32 {
  arc4random_uniform(upperBound)
}

// arc4random_buf
internal func system_arc4random_buf(_ buffer: UnsafeMutableRawPointer?, _ count: Int) {
  arc4random_buf(buffer, count)
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)
