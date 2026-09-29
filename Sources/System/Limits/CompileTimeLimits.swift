/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// The limits the C library's headers define, for sizing a buffer before
// there's a file to ask. A file system can have lower limits of its own,
// which SystemConfig's value(_:for:) methods return for a path or a
// descriptor: `SystemConfig.value(.maxFileNameBytes, for: directory)`
// is that directory's, `SystemConfig.maxFileNameBytes` the headers'.

@available(System 199, *)
extension SystemConfig {
  /// The maximum number of bytes in a file name,
  /// not counting the null terminator, as the C library's headers define it.
  ///
  /// A file system can allow fewer:
  /// the `value(_:for:)` methods with ``PathName/maxFileNameBytes``
  /// return a directory's own limit.
  ///
  /// The corresponding C constant is `NAME_MAX`.
  @_alwaysEmitIntoClient
  public static var maxFileNameBytes: Int { Int(_NAME_MAX) }

  /// The maximum number of bytes in a path that a call accepts,
  /// counting the null terminator, as the C library's headers define it.
  ///
  /// It's the size of a buffer that holds any path a call returns,
  /// such as `realpath`'s.
  /// A longer path fails with ``Errno/fileNameTooLong``.
  ///
  /// The corresponding C constant is `PATH_MAX`.
  @_alwaysEmitIntoClient
  public static var maxPathBytes: Int { Int(_PATH_MAX) }

  /// The number of bytes of arguments and environment
  /// that POSIX guarantees a new program can receive:
  /// the least that the system's own limit,
  /// ``Name/maxArgumentBytes``, can be.
  ///
  /// It's 4096.
  ///
  /// The corresponding C constant is `_POSIX_ARG_MAX`.
  @_alwaysEmitIntoClient
  public static var guaranteedArgumentBytes: Int { Int(__POSIX_ARG_MAX) }

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
  /// The maximum number of buffers that one vectored read or write takes,
  /// as the C library's headers define it.
  ///
  /// More buffers throw ``Errno/invalidArgument``.
  /// ``Name/maxIOVectors`` is the system's own limit, at run time.
  ///
  /// The corresponding C constant is `IOV_MAX`, or on Linux `UIO_MAXIOV`.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
  @_alwaysEmitIntoClient
  public static var maxIOVectors: Int { Int(_IOV_MAX) }
  #endif

  #if SYSTEM_PACKAGE_DARWIN
  /// The maximum number of bytes in an extended attribute's name,
  /// not counting the null terminator.
  ///
  /// A longer name throws ``Errno/fileNameTooLong``.
  ///
  /// The corresponding C constant is `XATTR_MAXNAMELEN`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var maxExtendedAttributeNameBytes: Int { Int(_XATTR_MAXNAMELEN) }

  /// The maximum number of symbolic links that resolving one path follows.
  ///
  /// Every link counts, in any component of the path.
  /// Resolving a path that needs more
  /// fails with ``Errno/tooManySymbolicLinkLevels``.
  ///
  /// The corresponding C constant is `MAXSYMLINKS`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var maxSymbolicLinks: Int { Int(_MAXSYMLINKS) }
  #endif
}

#endif // !os(Windows) && !os(WASI)
