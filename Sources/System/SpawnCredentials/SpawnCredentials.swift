/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Spawning a child with other credentials, as Subprocess's userID, groupID
// and supplementaryGroups options do. posix_spawn can't change a child's
// user or groups, so System forks first, in C, where the child calls only
// async-signal-safe functions: it sets its groups and user, clears
// close-on-exec on the descriptors that the file actions use, and runs the
// program with posix_spawn and POSIX_SPAWN_SETEXEC, which applies the file
// actions and attributes to the child itself. A failure comes back to the
// parent through a close-on-exec pipe.
//
// Only on Darwin, the one platform with POSIX_SPAWN_SETEXEC; elsewhere the
// child would have to apply the file actions and attributes itself.

#if SYSTEM_PACKAGE_DARWIN

import Darwin

/// The credentials for a child to run with:
/// the user and groups it runs as.
///
/// Each property that's `nil` leaves the child
/// with the calling process's credential.
/// Changing to another user or group usually takes root privileges.
///
/// - Note: Only available on Darwin.
@frozen
@available(System 199, *)
public struct SpawnCredentials: Hashable, Sendable {
  /// The user for the child to run as,
  /// or `nil` for the calling process's user.
  ///
  /// The corresponding C function is `setuid`.
  public var user: UserID?

  /// The group for the child to run as,
  /// or `nil` for the calling process's group.
  ///
  /// The corresponding C function is `setgid`.
  public var group: GroupID?

  /// The child's supplementary groups, which can be empty,
  /// or `nil` for the calling process's.
  ///
  /// The corresponding C function is `setgroups`.
  public var supplementaryGroups: [GroupID]?

  /// Creates a set of credentials.
  ///
  /// - Parameters:
  ///   - user: The user for the child to run as,
  ///     or `nil` for the calling process's user.
  ///     The default is `nil`.
  ///   - group: The group for the child to run as,
  ///     or `nil` for the calling process's group.
  ///     The default is `nil`.
  ///   - supplementaryGroups: The child's supplementary groups,
  ///     or `nil` for the calling process's.
  ///     The default is `nil`.
  @_alwaysEmitIntoClient
  public init(user: UserID? = nil, group: GroupID? = nil, supplementaryGroups: [GroupID]? = nil) {
    self.user = user
    self.group = group
    self.supplementaryGroups = supplementaryGroups
  }
}

@available(System 199, *)
extension ProcessID {
  /// Starts a child process running a program, with other credentials.
  ///
  /// - Parameters:
  ///   - path: The program to run.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - fileActions: Actions to take on the child's descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the child.
  ///   - credentials: The user and groups for the child to run as.
  /// - Returns: The child's process ID.
  ///
  /// `posix_spawn` can't change a child's user or groups,
  /// so this method forks first.
  /// The child sets its supplementary groups, then its group,
  /// then its user, since once it isn't root it can't change the others;
  /// then it runs the program with `posix_spawn`
  /// and the `POSIX_SPAWN_SETEXEC` flag,
  /// which applies `fileActions` and `attributes` to the child itself,
  /// as ``spawn(_:arguments:environment:fileActions:attributes:)-(FilePath,_,_,_,_)``
  /// applies them to a new child.
  /// If a step fails, this method throws its error,
  /// such as ``Errno/notPermitted`` for credentials
  /// that the calling process can't give,
  /// and no child is left to reap.
  ///
  /// Between the fork and the program, the child runs only C code
  /// that's safe after a fork, and none of the calling process's
  /// signal handlers.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes(),
    credentials: SpawnCredentials
  ) throws(Errno) -> ProcessID {
    try path.withPlatformString { path in
      ProcessID._spawn(
        path, searchingPath: false, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes, credentials: credentials)
    }.get()
  }

  /// Starts a child process running a program,
  /// searching for it in the directories that `PATH` names,
  /// with other credentials.
  ///
  /// See ``spawn(_:arguments:environment:fileActions:attributes:credentials:)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawnp`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func spawn(
    searchingPathFor file: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes(),
    credentials: SpawnCredentials
  ) throws(Errno) -> ProcessID {
    try file.withPlatformString { file in
      ProcessID._spawn(
        file, searchingPath: true, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes, credentials: credentials)
    }.get()
  }

  /// Starts a child process running a program,
  /// with C file actions and attributes, and other credentials.
  ///
  /// - Parameters:
  ///   - path: The program to run.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - cFileActions: The C file actions, such as
  ///     ``SpawnFileAction/withCFileActions(_:_:)`` passes its closure,
  ///     or `nil` for none.
  ///   - cAttributes: The C attributes, such as
  ///     ``SpawnAttributes/withCAttributes(_:)`` passes its closure,
  ///     or `nil` for the defaults.
  ///   - credentials: The user and groups for the child to run as.
  ///   - fileActionDescriptors: The descriptors that the file actions use,
  ///     such as the ones they duplicate or close.
  /// - Returns: The child's process ID.
  ///
  /// With `POSIX_SPAWN_SETEXEC`, Darwin closes the descriptors
  /// that have close-on-exec set before it applies the file actions,
  /// which then fail with ``Errno/badFileDescriptor``,
  /// so the child clears close-on-exec on `fileActionDescriptors` first;
  /// it can't read them from the C file actions.
  /// The flag is set on the child's copy of the attributes,
  /// so `cAttributes` keeps its flags.
  /// See ``spawn(_:arguments:environment:fileActions:attributes:credentials:)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?,
    credentials: SpawnCredentials,
    fileActionDescriptors: [FileDescriptor]
  ) throws(Errno) -> ProcessID {
    try path.withPlatformString { path in
      ProcessID._spawn(
        path, searchingPath: false, arguments: arguments, environment: environment,
        cFileActions: cFileActions, cAttributes: cAttributes, credentials: credentials,
        fileActionDescriptors: fileActionDescriptors)
    }.get()
  }

  /// Starts a child process running a program,
  /// searching for it in the directories that `PATH` names,
  /// with C file actions and attributes, and other credentials.
  ///
  /// See ``spawn(_:arguments:environment:cFileActions:cAttributes:credentials:fileActionDescriptors:)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawnp`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func spawn(
    searchingPathFor file: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?,
    credentials: SpawnCredentials,
    fileActionDescriptors: [FileDescriptor]
  ) throws(Errno) -> ProcessID {
    try file.withPlatformString { file in
      ProcessID._spawn(
        file, searchingPath: true, arguments: arguments, environment: environment,
        cFileActions: cFileActions, cAttributes: cAttributes, credentials: credentials,
        fileActionDescriptors: fileActionDescriptors)
    }.get()
  }

  @usableFromInline
  internal static func _spawn(
    _ path: UnsafePointer<CChar>,
    searchingPath: Bool,
    arguments: [String],
    environment: [String]?,
    fileActions: [SpawnFileAction],
    attributes: SpawnAttributes,
    credentials: SpawnCredentials
  ) -> Result<ProcessID, Errno> {
    SpawnFileAction._withUnsafeFileActions(fileActions) { cFileActions in
      attributes._withUnsafeAttributes(extraFlags: 0) { cAttributes in
        _spawn(
          path, searchingPath: searchingPath, arguments: arguments, environment: environment,
          cFileActions: cFileActions, cAttributes: cAttributes, credentials: credentials,
          fileActionDescriptors: fileActions.flatMap(\._usedDescriptors))
      }
    }
  }

  @usableFromInline
  internal static func _spawn(
    _ path: UnsafePointer<CChar>,
    searchingPath: Bool,
    arguments: [String],
    environment: [String]?,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?,
    credentials: SpawnCredentials,
    fileActionDescriptors: [FileDescriptor]
  ) -> Result<ProcessID, Errno> {
    // The shim sets POSIX_SPAWN_SETEXEC on the child's copy of the
    // attributes, so it needs attributes even when the caller has none.
    func withAttributes(_ body: (UnsafePointer<CInterop.SpawnAttributes>) -> CInt) -> CInt {
      if let cAttributes { return body(cAttributes) }
      var storage = _spawnAttributesZero
      let initialized = system_posix_spawnattr_init(&storage)
      guard initialized == 0 else { return initialized }
      defer { _ = system_posix_spawnattr_destroy(&storage) }
      return body(&storage)
    }
    return arguments._withCStringArray { arguments in
      let arguments = _mutableCStrings(arguments)
      func spawn(_ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>) -> Result<ProcessID, Errno> {
        var pid: pid_t = 0
        return nothingOrReturnedErrno(retryOnInterrupt: false) {
          withAttributes { attributes in
            system_spawn_with_credentials(
              &pid, path, searchingPath: searchingPath, cFileActions, attributes,
              arguments, environment,
              user: credentials.user?.rawValue, group: credentials.group?.rawValue,
              groups: credentials.supplementaryGroups?.map(\.rawValue),
              descriptors: fileActionDescriptors.map(\.rawValue))
          }
        }.map { ProcessID(rawValue: pid) }
      }
      guard let environment else { return _withCallingEnvironment(spawn) }
      return environment._withCStringArray { spawn(_mutableCStrings($0)) }
    }
  }
}

@available(System 199, *)
extension SpawnFileAction {
  // The descriptors that the action uses, which must be open when it's
  // applied.
  internal var _usedDescriptors: [FileDescriptor] {
    switch _kind {
    case .duplicate(let descriptor, _), .close(let descriptor),
         .setWorkingDirectoryDescriptor(let descriptor), .inherit(let descriptor):
      return [descriptor]
    case .open, .setWorkingDirectory, .closeAll:
      return []
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
