/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// mach-o/utils.h's architecture names, which libdyld implements, from
// macOS 13, iOS 16, tvOS 16 and watchOS 8: the name for a processor type
// and subtype, or for a Mach-O header's, and the type and subtype for a
// name. They fail only by returning nothing, not with errno, so they have
// no mock hooks.

#if SYSTEM_PACKAGE_DARWIN
import MachO.dyld.utils

@available(macOS 13.0, iOS 16.0, watchOS 8.0, tvOS 16.0, *)
internal func system_macho_arch_name_for_cpu_type(
  _ type: cpu_type_t, _ subtype: cpu_subtype_t
) -> UnsafePointer<CChar>? {
  macho_arch_name_for_cpu_type(type, subtype)
}

// A null header is the main executable's.
@available(macOS 13.0, iOS 16.0, watchOS 8.0, tvOS 16.0, *)
internal func system_macho_arch_name_for_mach_header(
  _ header: UnsafePointer<mach_header>?
) -> UnsafePointer<CChar>? {
  macho_arch_name_for_mach_header(header)
}

@available(macOS 13.0, iOS 16.0, watchOS 8.0, tvOS 16.0, *)
internal func system_macho_cpu_type_for_arch_name(
  _ name: UnsafePointer<CChar>, _ type: UnsafeMutablePointer<cpu_type_t>,
  _ subtype: UnsafeMutablePointer<cpu_subtype_t>
) -> Bool {
  macho_cpu_type_for_arch_name(name, type, subtype)
}

#endif // SYSTEM_PACKAGE_DARWIN
