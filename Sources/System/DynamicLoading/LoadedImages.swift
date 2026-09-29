/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

@available(System 199, *)
extension DynamicLibrary {
  /// The number of images the dynamic loader has loaded:
  /// the program, and every library and bundle it has loaded,
  /// whether the program asked for it or another image depends on it.
  ///
  /// The count grows as images load, and falls as bundles unload.
  /// A count that differs from an earlier one means that images
  /// have loaded or unloaded since,
  /// such as one that a search of the loaded images may now find.
  /// The same count doesn't mean that none did:
  /// one could have loaded and another unloaded.
  /// Another thread can load or unload an image at any time,
  /// so the count can change as soon as it's read.
  ///
  /// The corresponding C function is `_dyld_image_count`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var loadedImageCount: Int { _loadedImageCount }

  @usableFromInline
  internal static var _loadedImageCount: Int { Int(system__dyld_image_count()) }
}

#endif // SYSTEM_PACKAGE_DARWIN
