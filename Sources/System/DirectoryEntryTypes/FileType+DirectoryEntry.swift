/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension FileType {
  /// Creates a file type from a directory entry's type,
  /// the `d_type` that `readdir` reports,
  /// or returns `nil` if the type is unknown.
  ///
  ///     while let entry = readdir(directory) {
  ///       let type = FileType(directoryEntryType: entry.pointee.d_type)
  ///     }
  ///
  /// A file system that can't report an entry's type
  /// without reading its inode reports `DT_UNKNOWN`, for which this
  /// initializer returns `nil`; the file's ``Stat`` has its type.
  ///
  /// ``DirectoryStream`` and ``DirectoryWalk`` read `d_type` themselves;
  /// this is for code that reads directory entries some other way.
  ///
  /// The corresponding C field is `d_type`.
  /// The corresponding C constants are `DT_REG`, `DT_DIR`, `DT_LNK`,
  /// `DT_FIFO`, `DT_SOCK`, `DT_CHR`, `DT_BLK`, and on Darwin and FreeBSD
  /// `DT_WHT`; and `DT_UNKNOWN`, for which it returns `nil`.
  public init?(directoryEntryType: UInt8) {
    self.init(_directoryEntryType: directoryEntryType)
  }

  /// The directory entry type for this file type, as `d_type` holds it,
  /// or `DT_UNKNOWN` for a file type that has none.
  ///
  /// The corresponding C macro is `IFTODT`.
  public var directoryEntryType: UInt8 {
    let type: CInt
    switch self {
    case .regular: type = _DT_REG
    case .directory: type = _DT_DIR
    case .symbolicLink: type = _DT_LNK
    case .fifo: type = _DT_FIFO
    case .socket: type = _DT_SOCK
    case .characterSpecial: type = _DT_CHR
    case .blockSpecial: type = _DT_BLK
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    case .whiteout: type = _DT_WHT
    #endif
    default: type = _DT_UNKNOWN
    }
    return UInt8(type)
  }
}

#endif // !os(Windows) && !os(WASI)
