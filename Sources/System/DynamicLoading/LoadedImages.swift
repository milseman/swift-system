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

  /// Returns the Mach-O header of an image the dynamic loader has loaded,
  /// by its index among the loaded images.
  ///
  /// - Parameter index: The image's index, from 0 up to
  ///   ``loadedImageCount``. The program is the first, image 0.
  /// - Returns: The image's header, where the loader mapped it,
  ///   or `nil` if no image has the index.
  ///
  /// A loaded image's header is the start of the image in memory,
  /// followed by its load commands, in the host's byte order.
  /// Its type is C's: a 64-bit image, as every image is
  /// where pointers are 64 bits, has a ``CInterop/MachHeader64``,
  /// whose fields begin with these,
  /// and its load commands start after that structure's size.
  /// Pass the header to ``sectionData(segment:section:inImageAt:)``
  /// to find one of the image's sections.
  ///
  /// Images load and unload as other threads run,
  /// so by the time an index is used it can be another image's, or none;
  /// and an image's header stays mapped only while the image is loaded.
  /// To find the image that holds an address,
  /// ``symbolInfo(containing:)`` is safe from any thread.
  ///
  /// The corresponding C function is `_dyld_get_image_header`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func loadedImageHeader(at index: Int) -> UnsafePointer<CInterop.MachHeader>? {
    _loadedImageHeader(at: index)
  }

  @usableFromInline
  internal static func _loadedImageHeader(at index: Int) -> UnsafePointer<CInterop.MachHeader>? {
    guard let index = UInt32(exactly: index) else { return nil }
    return system__dyld_get_image_header(index)
  }

  /// Returns the bytes of a section of a loaded image,
  /// where the dynamic loader mapped them.
  ///
  ///     guard let section = DynamicLibrary.sectionData(
  ///       segment: "__TEXT", section: "__swift5_proto", inImageAt: #dsohandle)
  ///     else { return }
  ///
  /// - Parameters:
  ///   - segment: The segment's name, such as `__TEXT`.
  ///   - section: The section's name, such as `__swift5_proto`.
  ///   - header: The address of the image's Mach-O header:
  ///     what ``loadedImageHeader(at:)`` returns, `#dsohandle` for the image
  ///     that calls this, or a ``SymbolInfo``'s `libraryAddress`.
  ///     It must be a loaded image's,
  ///     whose segments are mapped where its load commands say,
  ///     of the process's own kind: 64-bit where pointers are 64 bits.
  /// - Returns: The section's bytes,
  ///   or `nil` if the image has no such section.
  ///   They stay mapped while the image is loaded.
  ///
  /// The corresponding C function is `getsectiondata`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func sectionData(
    segment: String, section: String, inImageAt header: UnsafeRawPointer
  ) -> UnsafeRawBufferPointer? {
    _sectionData(segment: segment, section: section, inImageAt: header)
  }

  @usableFromInline
  internal static func _sectionData(
    segment: String, section: String, inImageAt header: UnsafeRawPointer
  ) -> UnsafeRawBufferPointer? {
    var size: UInt = 0
    let start = segment.withCString { segment in
      section.withCString { section in system_getsectiondata(header, segment, section, &size) }
    }
    guard let start else { return nil }
    return UnsafeRawBufferPointer(start: start, count: Int(size))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
