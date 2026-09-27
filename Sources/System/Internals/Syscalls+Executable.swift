/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The dynamic loader's path of the main executable: _NSGetExecutablePath.

#if SYSTEM_PACKAGE_DARWIN
import MachO.dyld

// _NSGetExecutablePath, which returns -1 for a buffer too small, with the
// size it needs in `size`, and doesn't otherwise fail, so it has no mock
// hook.
internal func system__NSGetExecutablePath(
  _ buffer: UnsafeMutablePointer<CChar>?, _ size: UnsafeMutablePointer<UInt32>
) -> CInt {
  _NSGetExecutablePath(buffer, size)
}

#endif // SYSTEM_PACKAGE_DARWIN
