/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Where the system keeps its time zone files: <tzfile.h>'s TZDIR and
// TZDEFAULT. The Darwin module doesn't declare them, so they come from
// CSystem's Darwin header.

#if SYSTEM_PACKAGE_DARWIN
import CSystem

@available(System 199, *)
extension FilePath {
  /// The directory of the system's time zone files,
  /// one for each time zone, named for it, such as `America/Denver`.
  ///
  /// The corresponding C constant is `TZDIR`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var timeZoneDirectory: FilePath { FilePath(_TZDIR) }

  /// The file of the system's time zone,
  /// a symbolic link to its file in a time zone directory.
  ///
  /// The link's target need not start with ``timeZoneDirectory``,
  /// but the directory it's in is named `zoneinfo`,
  /// so the target's path after `zoneinfo/` is the time zone's name.
  ///
  /// The corresponding C constant is `TZDEFAULT`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var defaultTimeZoneFile: FilePath { FilePath(_TZDEFAULT) }
}

@_alwaysEmitIntoClient
internal var _TZDIR: String { TZDIR }

@_alwaysEmitIntoClient
internal var _TZDEFAULT: String { TZDEFAULT }

#endif // SYSTEM_PACKAGE_DARWIN
