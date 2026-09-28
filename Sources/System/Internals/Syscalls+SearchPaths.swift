/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's standard directories: sysdir_start_search_path_enumeration and
// sysdir_get_next_search_path_enumeration. Neither reports an error; the
// mock hooks record the arguments, and end the enumeration.

#if SYSTEM_PACKAGE_DARWIN

import Darwin
import Darwin.sysdir

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_sysdir_start_search_path_enumeration(
  _ directory: CUnsignedInt, _ domains: CUnsignedInt
) -> CUnsignedInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    _ = _mock(directory, domains)
    return 0
  }
#endif
  return sysdir_start_search_path_enumeration(
    sysdir_search_path_directory_t(directory),
    sysdir_search_path_domain_mask_t(rawValue: domains))
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_sysdir_get_next_search_path_enumeration(
  _ state: CUnsignedInt, _ path: UnsafeMutablePointer<CChar>
) -> CUnsignedInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    _ = _mock(state)
    return 0
  }
#endif
  return sysdir_get_next_search_path_enumeration(state, path)
}

#endif // SYSTEM_PACKAGE_DARWIN
