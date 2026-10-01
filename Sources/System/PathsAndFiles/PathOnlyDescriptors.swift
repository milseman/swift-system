/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Descriptors that refer to a file's location without opening the file:
// open's O_PATH, on Linux, Android and FreeBSD (14 and later). glibc declares
// it only with _GNU_SOURCE, so on Linux and Android its value comes from
// shims.c, as O_TMPFILE's does; FreeBSD's <fcntl.h> declares it. Darwin has
// no O_PATH; for a directory, its nearest is AccessMode.search (O_SEARCH).

#if os(Linux) || os(Android) || os(FreeBSD)
#if os(Linux) || os(Android)
import CSystem
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
extension FileDescriptor.OpenOptions {
  /// Opens a descriptor that refers to the file's location
  /// without opening the file itself.
  ///
  /// The descriptor can be the directory that calls with a `relativeTo`
  /// parameter resolve relative paths against,
  /// and ``FileDescriptor/stat(retryOnInterrupt:)``,
  /// ``FileDescriptor/close()`` and ``FileDescriptor/duplicate(as:retryOnInterrupt:)``
  /// take it, but reading or writing through it,
  /// and most other calls on it, throw ``Errno/badFileDescriptor``.
  /// Opening it needs search permission on the directories in the path,
  /// but no permission on the file.
  ///
  /// The access mode doesn't matter, and nor do the other options
  /// but ``directory``, ``noFollow`` and ``closeOnExec``.
  /// With ``noFollow``, the descriptor of a symbolic link refers to the link.
  ///
  /// The corresponding C constant is `O_PATH`.
  ///
  /// - Note: Only available on Linux, Android and FreeBSD.
  @_alwaysEmitIntoClient
  public static var pathOnly: Self { Self(rawValue: _O_PATH) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "pathOnly")
  public static var O_PATH: Self { pathOnly }
}

#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _O_PATH: CInt { _system_get_O_PATH() }
#else
@_alwaysEmitIntoClient
internal var _O_PATH: CInt { O_PATH }
#endif

#endif // os(Linux) || os(Android) || os(FreeBSD)
