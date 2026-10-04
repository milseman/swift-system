/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Synchronized I/O on Darwin, Linux, Android, FreeBSD and OpenBSD: O_SYNC
// and O_DSYNC, which open() takes and F_GETFL reports, and on Darwin F_SETFL
// changes. (FreeBSD's OpenOptions has .sync already, in FileDescriptor.swift.)
// FreeBSD has O_DSYNC from 13.0; OpenBSD's O_DSYNC is O_SYNC.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
extension FileDescriptor.OpenOptions {
  #if !os(FreeBSD)
  /// Makes each write wait until the data and all of the file's metadata
  /// are written to the storage device.
  ///
  /// ``dataSync`` waits for less, and ``FileDescriptor/synchronize(retryOnInterrupt:)``
  /// syncs once, when you choose.
  ///
  /// On Linux it includes ``dataSync``.
  ///
  /// The corresponding C constant is `O_SYNC`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, and OpenBSD here;
  ///   FreeBSD has its own.
  @_alwaysEmitIntoClient
  public static var sync: Self { Self(rawValue: _O_SYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "sync")
  public static var O_SYNC: Self { sync }
  #endif

  /// Makes each write wait until the data, and the metadata needed to read
  /// it back, such as the file's size, are written to the storage device,
  /// but not metadata such as its modification time.
  ///
  /// On OpenBSD it's the same flag as ``sync``.
  ///
  /// The corresponding C constant is `O_DSYNC`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var dataSync: Self { Self(rawValue: _O_DSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "dataSync")
  public static var O_DSYNC: Self { dataSync }
}

@available(System 199, *)
extension FileDescriptor.StatusFlags {
  /// Each write waits until the data and all of the file's metadata
  /// are written to the storage device.
  ///
  /// On Linux, ``FileDescriptor/setStatusFlags(_:)`` can't change it:
  /// only opening the file can set it.
  ///
  /// The corresponding C constant is `O_SYNC`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var sync: Self { Self(rawValue: _O_SYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "sync")
  public static var O_SYNC: Self { sync }

  /// Each write waits until the data, and the metadata needed to read it
  /// back, are written to the storage device.
  ///
  /// On Linux, ``FileDescriptor/setStatusFlags(_:)`` can't change it.
  /// On OpenBSD it's the same flag as ``sync``.
  ///
  /// The corresponding C constant is `O_DSYNC`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var dataSync: Self { Self(rawValue: _O_DSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "dataSync")
  public static var O_DSYNC: Self { dataSync }
}

// Constants.swift has O_SYNC only for FreeBSD.
#if !os(FreeBSD)
@_alwaysEmitIntoClient
internal var _O_SYNC: CInt { O_SYNC }
#endif

@_alwaysEmitIntoClient
internal var _O_DSYNC: CInt { O_DSYNC }

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
