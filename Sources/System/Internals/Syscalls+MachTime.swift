/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The Mach time calls: mach_absolute_time, mach_approximate_time,
// mach_continuous_time, mach_continuous_approximate_time, and
// mach_timebase_info. None can fail or set errno, so they have no mock
// hooks, as getpid has none.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// mach_absolute_time
internal func system_mach_absolute_time() -> UInt64 {
  mach_absolute_time()
}

// mach_approximate_time
internal func system_mach_approximate_time() -> UInt64 {
  mach_approximate_time()
}

// mach_continuous_time
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_mach_continuous_time() -> UInt64 {
  mach_continuous_time()
}

// mach_continuous_approximate_time
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_mach_continuous_approximate_time() -> UInt64 {
  mach_continuous_approximate_time()
}

// mach_timebase_info, which returns KERN_SUCCESS.
internal func system_mach_timebase_info(
  _ info: UnsafeMutablePointer<mach_timebase_info_data_t>
) -> kern_return_t {
  mach_timebase_info(info)
}

#endif // SYSTEM_PACKAGE_DARWIN
