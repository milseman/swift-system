/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The dynamic loader's loaded images: their count and their headers
// (_dyld_image_count, _dyld_get_image_header), and where a loaded image's
// section is mapped (getsectiondata, from <mach-o/getsect.h>).

#if SYSTEM_PACKAGE_DARWIN
import MachO.dyld
import MachO.getsect

// None of these can fail but by returning nothing, so they have no mock
// hooks.
internal func system__dyld_image_count() -> UInt32 {
  _dyld_image_count()
}

// A null header for an index that no image has.
internal func system__dyld_get_image_header(_ index: UInt32) -> UnsafePointer<mach_header>? {
  _dyld_get_image_header(index)
}

// getsect.h declares the header as the process's own kind: mach_header_64
// where pointers are 64 bits, and mach_header where they're 32 (arm64_32).
// Null if the image has no such section.
internal func system_getsectiondata(
  _ header: UnsafeRawPointer, _ segment: UnsafePointer<CChar>, _ section: UnsafePointer<CChar>,
  _ size: UnsafeMutablePointer<UInt>
) -> UnsafeMutablePointer<UInt8>? {
#if _pointerBitWidth(_64)
  getsectiondata(header.assumingMemoryBound(to: mach_header_64.self), segment, section, size)
#else
  getsectiondata(header.assumingMemoryBound(to: mach_header.self), segment, section, size)
#endif
}

#endif // SYSTEM_PACKAGE_DARWIN
