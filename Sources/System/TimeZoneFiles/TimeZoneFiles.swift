/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Where the system keeps its time zone files: <tzfile.h>'s TZDIR and
// TZDEFAULT. The Darwin module doesn't declare them, so they come from
// CSystem's Darwin header. On Linux, glibc keeps <tzfile.h> to itself and
// Musl has none, so they come from shims.c: the system's <tzfile.h>, where
// there is one, or the conventional paths, which both C libraries read.
// Bionic has no public <tzfile.h>, and its tzcode's private one has the
// conventional paths, which it doesn't read: its time zones are in one file
// (tzdata), and the device's is a system property. So on Android these are
// those paths, which code that reads them on Linux finds missing there.
// FreeBSD and OpenBSD don't install a <tzfile.h> either, and their tzcode
// reads the conventional paths, so these are those there too.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
import CSystem

@available(System 199, *)
extension FilePath {
  /// The directory of the system's time zone files,
  /// one for each time zone, named for it, such as `America/Denver`.
  ///
  /// On Linux it's `/usr/share/zoneinfo`,
  /// unless the system has a `<tzfile.h>` that says otherwise,
  /// and the directory can be missing,
  /// as in a container without time zone data.
  /// On Android it's `/usr/share/zoneinfo`, which Android doesn't have:
  /// its C library keeps the time zones in one file, `tzdata`.
  /// On FreeBSD and OpenBSD it's `/usr/share/zoneinfo`.
  ///
  /// The corresponding C constant is `TZDIR`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD and OpenBSD.
  @_alwaysEmitIntoClient
  public static var timeZoneDirectory: FilePath { FilePath(_TZDIR) }

  /// The file of the system's time zone,
  /// a symbolic link to its file in a time zone directory.
  ///
  /// The link's target need not start with ``timeZoneDirectory``,
  /// but the directory it's in is named `zoneinfo`,
  /// so the target's path after `zoneinfo/` is the time zone's name.
  /// On Linux the file can instead be a copy of the zone's file,
  /// or missing, which means UTC.
  /// On Android it's `/etc/localtime`, which is always missing:
  /// the system's time zone is the `persist.sys.timezone` property,
  /// which the C library reads unless `TZ` names another.
  /// On FreeBSD and OpenBSD it's `/etc/localtime`.
  ///
  /// The corresponding C constant is `TZDEFAULT`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD and OpenBSD.
  @_alwaysEmitIntoClient
  public static var defaultTimeZoneFile: FilePath { FilePath(_TZDEFAULT) }
}

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _TZDIR: String { TZDIR }

@_alwaysEmitIntoClient
internal var _TZDEFAULT: String { TZDEFAULT }
#elseif os(Android) || os(FreeBSD) || os(OpenBSD)
// The values in tzcode's <tzfile.h>, which Bionic and OpenBSD keep private
// (OpenBSD's lib/libc/time/tzfile.h), and which FreeBSD's tzcode reads.
@_alwaysEmitIntoClient
internal var _TZDIR: String { "/usr/share/zoneinfo" }

@_alwaysEmitIntoClient
internal var _TZDEFAULT: String { "/etc/localtime" }
#else
@_alwaysEmitIntoClient
internal var _TZDIR: String { String(cString: _system_get_TZDIR()) }

@_alwaysEmitIntoClient
internal var _TZDEFAULT: String { String(cString: _system_get_TZDEFAULT()) }
#endif

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
