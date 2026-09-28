/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Removing a file hierarchy with Darwin's removefile, which walks a
// directory depth first and removes everything in it, and then it.
//
// removefile removes a directory only when asked to recurse: without
// REMOVEFILE_RECURSIVE it leaves any directory in place, even an empty one,
// and reports success. So these methods always recurse, and are named for
// it; remove(), unlink() and removeDirectory() remove one entry.

#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin

// MARK: - Options

@available(System 199, *)
extension FilePath {
  /// Options for removing a file hierarchy.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct RemoveOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates a strongly-typed options value from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Removes everything in the directory, but not the directory itself.
    ///
    /// A path that isn't a directory is removed regardless.
    ///
    /// The corresponding C constant is `REMOVEFILE_KEEP_PARENT`.
    @_alwaysEmitIntoClient
    public static var keepDirectory: RemoveOptions {
      RemoveOptions(rawValue: _REMOVEFILE_KEEP_PARENT)
    }

    /// Removes what's in directories on other volumes, too.
    ///
    /// By default, the removal doesn't descend into a directory
    /// whose device differs from the path's,
    /// such as a volume mounted inside the hierarchy,
    /// and so fails to remove the directory that holds it.
    ///
    /// The corresponding C constant is `REMOVEFILE_CROSS_MOUNT`.
    @_alwaysEmitIntoClient
    public static var crossMountPoints: RemoveOptions {
      RemoveOptions(rawValue: _REMOVEFILE_CROSS_MOUNT)
    }

    /// Removes files whose paths in the hierarchy
    /// are longer than ``SystemConfig/maxPathBytes``.
    ///
    /// To reach them, the removal changes the process's working directory
    /// for its duration, which every thread shares:
    /// another thread's relative paths resolve from wherever it is.
    /// The path passed in, and each of its components,
    /// still has to be within the limits.
    ///
    /// The corresponding C constant is `REMOVEFILE_ALLOW_LONG_PATHS`.
    @_alwaysEmitIntoClient
    public static var allowLongPaths: RemoveOptions {
      RemoveOptions(rawValue: _REMOVEFILE_ALLOW_LONG_PATHS)
    }
  }
}

@available(System 199, *)
extension FilePath.RemoveOptions: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the options.
  @inline(never)
  public var description: String {
    let descriptions: [(Element, StaticString)] = [
      (.keepDirectory, ".keepDirectory"),
      (.crossMountPoints, ".crossMountPoints"),
      (.allowLongPaths, ".allowLongPaths"),
    ]
    return _buildDescription(descriptions)
  }

  /// A textual representation of the options, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - Removing a hierarchy

@available(System 199, *)
extension FilePath {
  /// Removes the file or directory at this path,
  /// and if it's a directory, everything in it.
  ///
  /// - Parameters:
  ///   - options: How to remove the hierarchy.
  ///
  /// The removal goes depth first,
  /// removing each directory after what's in it.
  /// It removes a symbolic link, not what the link points to,
  /// wherever the link is in the hierarchy.
  /// If it can't remove something, it stops and throws the error,
  /// leaving in place what it hasn't removed yet;
  /// ``removeRecursively(options:progress:)`` can go on past errors instead.
  ///
  /// This method doesn't retry if it's interrupted;
  /// it throws ``Errno/interrupted``,
  /// and calling it again removes what's left.
  ///
  /// The corresponding C function is `removefile`,
  /// with `REMOVEFILE_RECURSIVE`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func removeRecursively(options: RemoveOptions = []) throws(Errno) {
    try withPlatformString {
      FilePath._removeRecursively($0, options: options, progress: nil)
    }.get()
  }

  /// Removes the file or directory at the given path,
  /// and if it's a directory, everything in it.
  ///
  /// - Parameters:
  ///   - path: The file or directory to remove.
  ///   - options: How to remove the hierarchy.
  ///
  /// See ``removeRecursively(options:)``.
  ///
  /// The corresponding C function is `removefile`,
  /// with `REMOVEFILE_RECURSIVE`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    options: RemoveOptions = []
  ) throws(Errno) {
    try _removeRecursively(path, options: options, progress: nil).get()
  }

  /// Removes the file or directory at this path,
  /// and if it's a directory, everything in it,
  /// reporting the removal's progress.
  ///
  /// - Parameters:
  ///   - options: How to remove the hierarchy.
  ///   - progress: A closure that the removal calls before and after
  ///     it removes each file, and when it fails to,
  ///     and that returns what to do next.
  ///
  /// The removal reports each file at the stage ``RemoveProgress/Stage/start``,
  /// before removing it,
  /// and at ``RemoveProgress/Stage/finish`` after,
  /// in the order it removes them: depth first,
  /// with each directory's start before what's in it
  /// and its finish after.
  /// It reports a failure at ``RemoveProgress/Stage/error``.
  ///
  /// Returning ``RemoveProgress/Action/skip`` at the start of a file
  /// leaves it in place,
  /// and then the directory that holds it can't be removed,
  /// which the removal reports as an error.
  /// Returning ``RemoveProgress/Action/proceed`` for an error
  /// ignores it: the removal goes on, and doesn't throw it.
  /// Returning ``RemoveProgress/Action/stop`` stops the removal,
  /// which then throws the error it stopped at,
  /// or ``Errno/canceled`` if it stopped at another stage.
  ///
  /// The corresponding C function is `removefile`,
  /// with `REMOVEFILE_RECURSIVE`
  /// and the confirm, status, and error callbacks.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func removeRecursively(
    options: RemoveOptions = [],
    progress: (RemoveProgress) -> RemoveProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      withPlatformString {
        FilePath._removeRecursively($0, options: options, progress: progress)
      }
    }.get()
  }

  /// Removes the file or directory at the given path,
  /// and if it's a directory, everything in it,
  /// reporting the removal's progress.
  ///
  /// - Parameters:
  ///   - path: The file or directory to remove.
  ///   - options: How to remove the hierarchy.
  ///   - progress: A closure that the removal calls before and after
  ///     it removes each file, and when it fails to,
  ///     and that returns what to do next.
  ///
  /// See ``removeRecursively(options:progress:)``.
  ///
  /// The corresponding C function is `removefile`,
  /// with `REMOVEFILE_RECURSIVE`
  /// and the confirm, status, and error callbacks.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    options: RemoveOptions = [],
    progress: (RemoveProgress) -> RemoveProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      _removeRecursively(path, options: options, progress: progress)
    }.get()
  }

  @usableFromInline
  internal static func _removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    options: RemoveOptions,
    progress: _RemoveProgressHandler?
  ) -> Result<Void, Errno> {
    _withRemoveState(progress: progress) { state in
      system_removefile(path, state, options.rawValue | _REMOVEFILE_RECURSIVE)
    }
  }
}

// MARK: - Relative to a directory

@available(System 199, *)
extension FilePath {
  /// Removes the file or directory at this path, resolved against a
  /// directory, and if it's a directory, everything in it.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - options: How to remove the hierarchy.
  ///
  /// An absolute path ignores `fd`.
  /// See ``removeRecursively(options:)``.
  ///
  /// The corresponding C function is `removefileat`,
  /// with `REMOVEFILE_RECURSIVE`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func removeRecursively(
    relativeTo fd: FileDescriptor,
    options: RemoveOptions = []
  ) throws(Errno) {
    try withPlatformString {
      FilePath._removeRecursively($0, relativeTo: fd, options: options, progress: nil)
    }.get()
  }

  /// Removes the file or directory at the given path, resolved against a
  /// directory, and if it's a directory, everything in it.
  ///
  /// - Parameters:
  ///   - path: The file or directory to remove.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - options: How to remove the hierarchy.
  ///
  /// An absolute path ignores `fd`.
  /// See ``removeRecursively(options:)``.
  ///
  /// The corresponding C function is `removefileat`,
  /// with `REMOVEFILE_RECURSIVE`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    relativeTo fd: FileDescriptor,
    options: RemoveOptions = []
  ) throws(Errno) {
    try _removeRecursively(path, relativeTo: fd, options: options, progress: nil).get()
  }

  /// Removes the file or directory at this path, resolved against a
  /// directory, and if it's a directory, everything in it,
  /// reporting the removal's progress.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - options: How to remove the hierarchy.
  ///   - progress: A closure that the removal calls before and after
  ///     it removes each file, and when it fails to,
  ///     and that returns what to do next.
  ///
  /// An absolute path ignores `fd`.
  /// See ``removeRecursively(options:progress:)``.
  ///
  /// The corresponding C function is `removefileat`,
  /// with `REMOVEFILE_RECURSIVE`
  /// and the confirm, status, and error callbacks.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func removeRecursively(
    relativeTo fd: FileDescriptor,
    options: RemoveOptions = [],
    progress: (RemoveProgress) -> RemoveProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      withPlatformString {
        FilePath._removeRecursively($0, relativeTo: fd, options: options, progress: progress)
      }
    }.get()
  }

  /// Removes the file or directory at the given path, resolved against a
  /// directory, and if it's a directory, everything in it,
  /// reporting the removal's progress.
  ///
  /// - Parameters:
  ///   - path: The file or directory to remove.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - options: How to remove the hierarchy.
  ///   - progress: A closure that the removal calls before and after
  ///     it removes each file, and when it fails to,
  ///     and that returns what to do next.
  ///
  /// An absolute path ignores `fd`.
  /// See ``removeRecursively(options:progress:)``.
  ///
  /// The corresponding C function is `removefileat`,
  /// with `REMOVEFILE_RECURSIVE`
  /// and the confirm, status, and error callbacks.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    relativeTo fd: FileDescriptor,
    options: RemoveOptions = [],
    progress: (RemoveProgress) -> RemoveProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      _removeRecursively(path, relativeTo: fd, options: options, progress: progress)
    }.get()
  }

  @usableFromInline
  internal static func _removeRecursively(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    relativeTo fd: FileDescriptor,
    options: RemoveOptions,
    progress: _RemoveProgressHandler?
  ) -> Result<Void, Errno> {
    _withRemoveState(progress: progress) { state in
      system_removefileat(fd.rawValue, path, state, options.rawValue | _REMOVEFILE_RECURSIVE)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
