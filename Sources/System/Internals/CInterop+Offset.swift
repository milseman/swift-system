/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// C's file offset type, for code whose own API names it, such as a
// signature shared with Dispatch's DispatchIO. System's own API takes Int64
// offsets.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif os(Windows)
import ucrt
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// A file offset or size, as C's calls take it.
  ///
  /// Its width is the platform's:
  /// it's `Int64` on Darwin and WASI, `Int` on Linux and Android,
  /// and `Int32` on Windows.
  /// System's own API takes `Int64` offsets;
  /// this is the C type, for code whose API names it.
  ///
  /// The corresponding C type is `off_t`.
  public typealias Offset = off_t
}
