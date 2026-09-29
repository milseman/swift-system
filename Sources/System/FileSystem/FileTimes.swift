//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows)

// Must import here to use the C timespec type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

// The times are `timespec` values since the Epoch, the same type as
// `Stat.st_atim` and `Stat.st_mtim`. A `nil` time is left unchanged
// (`UTIME_OMIT`), and the `setTimesToNow` methods use the current time
// (`UTIME_NOW`).

// MARK: - futimens

@available(System 199, *)
extension FileDescriptor {
  /// Sets the access and modification times of the file referenced by this
  /// file descriptor.
  ///
  /// - Parameters:
  ///   - access: The new access time, as a time since the Epoch,
  ///     or `nil` to leave the access time unchanged.
  ///   - modification: The new modification time, as a time since the Epoch,
  ///     or `nil` to leave the modification time unchanged.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The times are the same `timespec` values
  /// as ``Stat/st_atim`` and ``Stat/st_mtim``.
  /// To set either time to the current time,
  /// call ``setTimesToNow(access:modification:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `futimens`,
  /// with `UTIME_OMIT` for a `nil` time.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimes(
    access: timespec?,
    modification: timespec?,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      _fileTime(access), _fileTime(modification), retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Sets the access and modification times of the file referenced by this
  /// file descriptor to the current time.
  ///
  /// - Parameters:
  ///   - access: Whether to set the access time.
  ///     The default is `true`.
  ///   - modification: Whether to set the modification time.
  ///     The default is `true`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A time that isn't set is left unchanged.
  ///
  /// The corresponding C function is `futimens`, with `UTIME_NOW`.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimesToNow(
    access: Bool = true,
    modification: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      _fileTime(now: access), _fileTime(now: modification),
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @usableFromInline
  internal func _setTimes(
    _ access: timespec,
    _ modification: timespec,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    _withFileTimes(access, modification) { times in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_futimens(self.rawValue, times)
      }
    }
  }
}

// MARK: - utimensat

@available(System 199, *)
extension FilePath {
  /// Sets the access and modification times of the file at this path.
  ///
  /// - Parameters:
  ///   - access: The new access time, as a time since the Epoch,
  ///     or `nil` to leave the access time unchanged.
  ///   - modification: The new modification time, as a time since the Epoch,
  ///     or `nil` to leave the modification time unchanged.
  ///   - followTargetSymlink: Whether to set the times
  ///     of a symbolic link's target, if this path names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to set the times of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The times are the same `timespec` values
  /// as ``Stat/st_atim`` and ``Stat/st_mtim``.
  /// To set either time to the current time, call
  /// ``setTimesToNow(access:modification:followTargetSymlink:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `utimensat`,
  /// with `UTIME_OMIT` for a `nil` time.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimes(
    access: timespec?,
    modification: timespec?,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setTimes(
        $0, relativeTo: _AT_FDCWD, _fileTime(access), _fileTime(modification),
        flags: followTargetSymlink ? 0 : _AT_SYMLINK_NOFOLLOW,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Sets the access and modification times of the file at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - access: The new access time, as a time since the Epoch,
  ///     or `nil` to leave the access time unchanged.
  ///   - modification: The new modification time, as a time since the Epoch,
  ///     or `nil` to leave the modification time unchanged.
  ///   - followTargetSymlink: Whether to set the times
  ///     of a symbolic link's target, if `path` names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to set the times of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `utimensat`,
  /// with `UTIME_OMIT` for a `nil` time.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public static func setTimes(
    _ path: UnsafePointer<CChar>,
    access: timespec?,
    modification: timespec?,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      path, relativeTo: _AT_FDCWD, _fileTime(access), _fileTime(modification),
      flags: followTargetSymlink ? 0 : _AT_SYMLINK_NOFOLLOW,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Sets the access and modification times of the file at this path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - access: The new access time, as a time since the Epoch,
  ///     or `nil` to leave the access time unchanged.
  ///   - modification: The new modification time, as a time since the Epoch,
  ///     or `nil` to leave the modification time unchanged.
  ///   - flags: Options that control how the path is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to set the times of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `utimensat`,
  /// with `UTIME_OMIT` for a `nil` time.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimes(
    relativeTo fd: FileDescriptor,
    access: timespec?,
    modification: timespec?,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setTimes(
        $0, relativeTo: fd.rawValue, _fileTime(access), _fileTime(modification),
        flags: flags.rawValue, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Sets the access and modification times of the file at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - access: The new access time, as a time since the Epoch,
  ///     or `nil` to leave the access time unchanged.
  ///   - modification: The new modification time, as a time since the Epoch,
  ///     or `nil` to leave the modification time unchanged.
  ///   - flags: Options that control how `path` is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to set the times of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `utimensat`,
  /// with `UTIME_OMIT` for a `nil` time.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public static func setTimes(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    access: timespec?,
    modification: timespec?,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      path, relativeTo: fd.rawValue, _fileTime(access), _fileTime(modification),
      flags: flags.rawValue, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Sets the access and modification times of the file at this path
  /// to the current time.
  ///
  /// - Parameters:
  ///   - access: Whether to set the access time.
  ///     The default is `true`.
  ///   - modification: Whether to set the modification time.
  ///     The default is `true`.
  ///   - followTargetSymlink: Whether to set the times
  ///     of a symbolic link's target, if this path names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to set the times of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A time that isn't set is left unchanged.
  ///
  /// The corresponding C function is `utimensat`, with `UTIME_NOW`.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimesToNow(
    access: Bool = true,
    modification: Bool = true,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setTimes(
        $0, relativeTo: _AT_FDCWD, _fileTime(now: access), _fileTime(now: modification),
        flags: followTargetSymlink ? 0 : _AT_SYMLINK_NOFOLLOW,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Sets the access and modification times of the file at the given path
  /// to the current time.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - access: Whether to set the access time.
  ///     The default is `true`.
  ///   - modification: Whether to set the modification time.
  ///     The default is `true`.
  ///   - followTargetSymlink: Whether to set the times
  ///     of a symbolic link's target, if `path` names a symbolic link.
  ///     The default is `true`.
  ///     Pass `false` to set the times of the link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A time that isn't set is left unchanged.
  ///
  /// The corresponding C function is `utimensat`, with `UTIME_NOW`.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public static func setTimesToNow(
    _ path: UnsafePointer<CChar>,
    access: Bool = true,
    modification: Bool = true,
    followTargetSymlink: Bool = true,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      path, relativeTo: _AT_FDCWD, _fileTime(now: access), _fileTime(now: modification),
      flags: followTargetSymlink ? 0 : _AT_SYMLINK_NOFOLLOW,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Sets the access and modification times of the file at this path
  /// to the current time,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - access: Whether to set the access time.
  ///     The default is `true`.
  ///   - modification: Whether to set the modification time.
  ///     The default is `true`.
  ///   - flags: Options that control how the path is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to set the times of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A time that isn't set is left unchanged.
  ///
  /// If this path is absolute (starts with a forward slash), then `fd` is ignored.
  /// If this path is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `utimensat`, with `UTIME_NOW`.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public func setTimesToNow(
    relativeTo fd: FileDescriptor,
    access: Bool = true,
    modification: Bool = true,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try withPlatformString {
      FilePath._setTimes(
        $0, relativeTo: fd.rawValue, _fileTime(now: access), _fileTime(now: modification),
        flags: flags.rawValue, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Sets the access and modification times of the file at the given path
  /// to the current time,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - access: Whether to set the access time.
  ///     The default is `true`.
  ///   - modification: Whether to set the modification time.
  ///     The default is `true`.
  ///   - flags: Options that control how `path` is resolved.
  ///     Pass ``ResolutionFlags/symlinkNoFollow``
  ///     to set the times of a symbolic link itself.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A time that isn't set is left unchanged.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `utimensat`, with `UTIME_NOW`.
  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @_alwaysEmitIntoClient
  public static func setTimesToNow(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    access: Bool = true,
    modification: Bool = true,
    flags: FilePath.ResolutionFlags = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setTimes(
      path, relativeTo: fd.rawValue, _fileTime(now: access), _fileTime(now: modification),
      flags: flags.rawValue, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
  @usableFromInline
  internal static func _setTimes(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: CInt,
    _ access: timespec,
    _ modification: timespec,
    flags: CInt,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    _withFileTimes(access, modification) { times in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_utimensat(fd, path, times, flags)
      }
    }
  }
}

// MARK: - Helpers

// A time for futimens or utimensat: the given time, or UTIME_OMIT for nil.
@_alwaysEmitIntoClient
internal func _fileTime(_ time: timespec?) -> timespec {
  time ?? timespec(tv_sec: 0, tv_nsec: numericCast(_UTIME_OMIT))
}

// A time for futimens or utimensat: UTIME_NOW, or UTIME_OMIT for false.
@_alwaysEmitIntoClient
internal func _fileTime(now: Bool) -> timespec {
  timespec(tv_sec: 0, tv_nsec: numericCast(now ? _UTIME_NOW : _UTIME_OMIT))
}

// Calls `body` with the two-element array that futimens and utimensat take.
internal func _withFileTimes<R>(
  _ access: timespec,
  _ modification: timespec,
  _ body: (UnsafePointer<timespec>) -> R
) -> R {
  var times = (access, modification)
  return withUnsafePointer(to: &times) {
    $0.withMemoryRebound(to: timespec.self, capacity: 2, body)
  }
}

#endif // !os(Windows)
