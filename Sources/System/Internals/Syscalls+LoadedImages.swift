/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The dynamic loader's count of loaded images: _dyld_image_count.

#if SYSTEM_PACKAGE_DARWIN
import MachO.dyld

// _dyld_image_count can't fail, so it has no mock hook.
internal func system__dyld_image_count() -> UInt32 {
  _dyld_image_count()
}

#endif // SYSTEM_PACKAGE_DARWIN
