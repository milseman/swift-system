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
//
// O_RSYNC is here where the headers declare it, and all of them make it
// O_SYNC: glibc, Musl and Bionic, since Linux doesn't synchronize reads
// apart from writes, and OpenBSD, whose synchronized I/O is all or
// nothing. Darwin's headers don't declare it, nor FreeBSD's ("XXX missing
// O_RSYNC"). WASI's fdflags have O_DSYNC, O_RSYNC and O_SYNC, each its own
// flag, but System has none of them on WASI.

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

  #if os(Linux) || os(Android) || os(OpenBSD)
  /// Makes each read wait, with ``sync`` or ``dataSync``,
  /// until writes still pending for the data it reads
  /// are written to the storage device, as that flag makes writes wait.
  ///
  /// On Linux, Android and OpenBSD it's the same flag as ``sync``,
  /// so it makes each write wait as ``sync`` does,
  /// and does nothing more for reads.
  ///
  /// The corresponding C constant is `O_RSYNC`.
  ///
  /// - Note: Only available on Linux, Android, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var readSync: Self { Self(rawValue: _O_RSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "readSync")
  public static var O_RSYNC: Self { readSync }
  #endif
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

  #if os(Linux) || os(Android) || os(OpenBSD)
  /// Each read waits, with ``sync`` or ``dataSync``,
  /// until writes still pending for the data it reads
  /// are written to the storage device.
  ///
  /// On Linux, Android and OpenBSD it's the same flag as ``sync``;
  /// on Linux, ``FileDescriptor/setStatusFlags(_:)`` can't change it.
  ///
  /// The corresponding C constant is `O_RSYNC`.
  ///
  /// - Note: Only available on Linux, Android, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var readSync: Self { Self(rawValue: _O_RSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "readSync")
  public static var O_RSYNC: Self { readSync }
  #endif
}

// Constants.swift has O_SYNC only for FreeBSD.
#if !os(FreeBSD)
@_alwaysEmitIntoClient
internal var _O_SYNC: CInt { O_SYNC }
#endif

@_alwaysEmitIntoClient
internal var _O_DSYNC: CInt { O_DSYNC }

#if os(Linux) || os(Android) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _O_RSYNC: CInt { O_RSYNC }
#endif

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
