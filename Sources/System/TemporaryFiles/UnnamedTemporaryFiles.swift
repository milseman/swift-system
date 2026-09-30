/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unnamed temporary files, on Linux: open's O_TMPFILE, which creates a
// regular file that no path names, and the *at functions' AT_EMPTY_PATH,
// with which linkat can give it a name. glibc and Musl declare both only
// with _GNU_SOURCE, so their values come from shims.c.

#if os(Linux) || os(Android)
import CSystem
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
extension FileDescriptor.OpenOptions {
  /// Creates an unnamed regular file in the directory at the path:
  /// a file that no path names,
  /// which is removed when its last descriptor closes.
  ///
  /// Open the directory for writing,
  /// with ``FileDescriptor/AccessMode/writeOnly``
  /// or ``FileDescriptor/AccessMode/readWrite``,
  /// and pass the new file's permissions, as for ``create``.
  /// To name the file later, link it into a directory with
  /// ``FilePath/makeHardLink(relativeTo:to:relativeTo:flags:retryOnInterrupt:)``,
  /// passing its descriptor as the existing path's directory,
  /// an empty existing path,
  /// and ``FilePath/ResolutionFlags/emptyPath``.
  /// With ``exclusiveCreate`` too, the file can't be linked.
  ///
  /// A file system that doesn't support unnamed files
  /// throws ``Errno/notSupported``.
  ///
  /// The option includes ``directory``.
  ///
  /// The corresponding C constant is `O_TMPFILE`.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var temporaryFile: Self { Self(rawValue: _O_TMPFILE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "temporaryFile")
  public static var O_TMPFILE: Self { temporaryFile }
}

@available(System 199, *)
extension FilePath.ResolutionFlags {
  /// If the path is empty, operate on the file
  /// that the directory argument's descriptor refers to,
  /// which needn't be a directory.
  ///
  /// With it, `linkat` names the file that a descriptor refers to,
  /// such as an unnamed ``FileDescriptor/OpenOptions/temporaryFile``.
  /// Linking this way can need the `CAP_DAC_READ_SEARCH` capability:
  /// without it, the call can throw ``Errno/noSuchFileOrDirectory``,
  /// and linking the descriptor's path under `/proc/self/fd`
  /// with ``symlinkFollow`` works instead.
  ///
  /// The corresponding C constant is `AT_EMPTY_PATH`.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var emptyPath: Self { Self(rawValue: _AT_EMPTY_PATH) }
}

@_alwaysEmitIntoClient
internal var _O_TMPFILE: CInt { _system_get_O_TMPFILE() }

@_alwaysEmitIntoClient
internal var _AT_EMPTY_PATH: CInt { _system_get_AT_EMPTY_PATH() }

#endif // os(Linux) || os(Android)
