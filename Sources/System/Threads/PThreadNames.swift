/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Thread names. Darwin can name only the calling thread; Linux, Android,
// FreeBSD, and OpenBSD can name any thread in the process. So every platform
// has `PThread.setCurrentName(_:)`, and only those that can name another
// thread have `PThread.ID.setName(_:)`. Neither truncates a name that's too
// long, except on OpenBSD: the limit is 63 bytes on Darwin and 15 on Linux,
// and the error differs, while OpenBSD keeps the first 23 bytes and reports
// nothing. OpenBSD spells the functions pthread_set_name_np and
// pthread_get_name_np, as FreeBSD also does beside the other spellings.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)

@available(System 199, *)
extension PThread.ID {
  /// The name of the thread.
  ///
  /// A thread that hasn't been named has an empty name on Darwin
  /// and OpenBSD.
  /// On Linux, it has the name of the thread that created it,
  /// which for the main thread is the name of the program.
  ///
  /// The corresponding C function is `pthread_getname_np`,
  /// or `pthread_get_name_np` on OpenBSD.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public func name() throws(Errno) -> String {
    try _name().get()
  }

  @usableFromInline
  internal func _name() -> Result<String, Errno> {
    // Names are at most 64 bytes, including the terminating NUL, on Darwin,
    // 16 on Linux, 20 on FreeBSD, and 24 on OpenBSD.
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: 64) { buffer in
      buffer.initialize(repeating: 0)
      if let error = _pthreadError(
        system_pthread_getname_np(rawValue, buffer.baseAddress!, buffer.count)
      ) {
        return .failure(error)
      }
      buffer[buffer.count - 1] = 0
      return .success(String(cString: buffer.baseAddress!))
    }
  }
}

#if os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension PThread.ID {
  /// Sets the name of the thread.
  ///
  /// - Parameter name: The new name. On Linux and Android,
  ///   the name can be at most 15 bytes of UTF-8;
  ///   a longer name throws ``Errno/outOfRange``.
  ///   OpenBSD keeps the first 23 bytes of a longer name.
  ///
  /// The name can't contain a NUL character;
  /// such a name throws ``Errno/invalidArgument``.
  ///
  /// To name the calling thread on every platform,
  /// call ``PThread/setCurrentName(_:)``.
  ///
  /// The corresponding C function is `pthread_setname_np`,
  /// or `pthread_set_name_np` on OpenBSD.
  /// - Note: Only available on Linux, Android, FreeBSD, and OpenBSD.
  ///   Darwin can name only the calling thread.
  @_alwaysEmitIntoClient
  public func setName(_ name: String) throws(Errno) {
    try _setName(name).get()
  }

  @usableFromInline
  internal func _setName(_ name: String) -> Result<(), Errno> {
    guard !name.utf8.contains(0) else { return .failure(.invalidArgument) }
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      name.withCString { system_pthread_setname_np(rawValue, $0) }
    }
  }
}
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)

@available(System 199, *)
extension PThread {
  /// Sets the name of the calling thread.
  ///
  /// - Parameter name: The new name.
  ///   On Darwin, the name can be at most 63 bytes of UTF-8;
  ///   a longer name throws ``Errno/fileNameTooLong``.
  ///   On Linux and Android, the name can be at most 15 bytes;
  ///   a longer name throws ``Errno/outOfRange``.
  ///   OpenBSD keeps the first 23 bytes of a longer name.
  ///
  /// The name can't contain a NUL character;
  /// such a name throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `pthread_setname_np`,
  /// or `pthread_set_name_np` on OpenBSD.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "A task can move between threads")
  public static func setCurrentName(_ name: String) throws(Errno) {
    try _setCurrentName(name).get()
  }

  @usableFromInline
  internal static func _setCurrentName(_ name: String) -> Result<(), Errno> {
    guard !name.utf8.contains(0) else { return .failure(.invalidArgument) }
    #if SYSTEM_PACKAGE_DARWIN
    // Darwin's pthread_setname_np returns -1 and sets errno.
    return nothingOrErrno(retryOnInterrupt: false) {
      name.withCString { system_pthread_setname_np($0) }
    }
    #else
    return ID.current._setName(name)
    #endif
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
