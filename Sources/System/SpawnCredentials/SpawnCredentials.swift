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
// actions and attributes to the child itself. For System's file actions,
// actions added at the end close the ones among those descriptors that a
// spawn's exec would close. A failure comes back to the parent through a
// close-on-exec pipe.
//
// On Linux, which has no POSIX_SPAWN_SETEXEC, a thread's credentials are
// its own, and a child gets those of the thread that spawns it: so the shim
// sets the credentials of a thread of its own, with the raw system calls,
// which change only that thread's, and spawns the program from it with
// posix_spawn. Elsewhere, the child would have to apply the file actions
// and attributes itself. Not on Android, whose posix_spawn is from API
// level 28.

#if SYSTEM_PACKAGE_DARWIN || os(Linux)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// The credentials for a child to run with:
/// the user and groups it runs as.
///
/// Each property that's `nil` leaves the child
/// with the calling process's credential.
/// Changing to another user or group usually takes root privileges.
///
/// - Note: Only available on Darwin and Linux.
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
  /// With `POSIX_SPAWN_SETEXEC`, Darwin closes the descriptors
  /// that have close-on-exec set before it applies the file actions,
  /// rather than when the program starts,
  /// so the child clears close-on-exec on the descriptors
  /// that `fileActions` use.
  /// So that the program gets the descriptors
  /// that a spawn without credentials would give it,
  /// this method adds an action at the end that closes each of them
  /// that has close-on-exec set,
  /// unless an action closes it, replaces it, or lets the child inherit it.
  ///
  /// On Linux, which has no `POSIX_SPAWN_SETEXEC`, this method doesn't fork:
  /// Linux keeps credentials per thread, and a child gets the credentials
  /// of the thread that spawns it,
  /// so it sets the credentials of a thread of its own,
  /// with the system calls that change only that thread's,
  /// and spawns the program from it with `posix_spawn`,
  /// which applies `fileActions` and `attributes` as it always does;
  /// the process's other threads keep their credentials.
  /// The close-on-exec descriptors need nothing there,
  /// and the rest of this paragraph and the next are about Darwin.
  ///
  /// Between the fork and the program, the child runs only C code
  /// that's safe after a fork, and none of the calling process's
  /// signal handlers.
  /// It reports a failure through a pipe whose ends are close-on-exec,
  /// and this method waits for the program to start,
  /// which closes the child's end.
  /// Where `pipe2` is missing (before macOS 27,
  /// or in a build of System with an older SDK),
  /// the pipe gets close-on-exec in a second step;
  /// a program that another thread starts between the two inherits the pipe,
  /// and then this method doesn't return until that program, too,
  /// exits or closes it.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`;
  /// on Linux, the `setgroups`, `setresgid` and `setresuid` system calls,
  /// on a thread of the method's own, and `posix_spawn`.
  /// - Note: Only available on Darwin and Linux.
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
  /// See ``spawn(_:arguments:environment:fileActions:attributes:credentials:)-(FilePath,_,_,_,_,_)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawnp`.
  /// - Note: Only available on Darwin and Linux.
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
  /// with arguments and an environment as C arrays, and other credentials.
  ///
  /// - Parameters:
  ///   - path: The program to run, as a C string.
  ///   - arguments: The program's arguments, as a null-terminated array
  ///     of C strings, including the first,
  ///     which by convention is the program's name.
  ///   - environment: The program's environment,
  ///     as a null-terminated array of C strings
  ///     of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - fileActions: Actions to take on the child's descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the child.
  ///   - credentials: The user and groups for the child to run as.
  /// - Returns: The child's process ID.
  ///
  /// Use this method for arguments that aren't valid UTF-8.
  /// See ``spawn(_:arguments:environment:fileActions:attributes:credentials:)-(FilePath,_,_,_,_,_)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`;
  /// on Linux, the `setgroups`, `setresgid` and `setresuid` system calls,
  /// on a thread of the method's own, and `posix_spawn`.
  /// - Note: Only available on Darwin and Linux.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: UnsafePointer<CChar>,
    arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    environment: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes(),
    credentials: SpawnCredentials
  ) throws(Errno) -> ProcessID {
    try ProcessID._spawn(
      path, searchingPath: false, arguments: arguments, environment: environment,
      fileActions: fileActions, attributes: attributes, credentials: credentials
    ).get()
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
  ///
  /// Unlike the form that takes ``SpawnFileAction`` values,
  /// this method can't add actions:
  /// each of `fileActionDescriptors` that had close-on-exec set
  /// stays open in the program,
  /// where a spawn without credentials would close it,
  /// unless the actions close it, replace it, or let the child inherit it.
  /// To close them, add a close action for each after its last use,
  /// or set ``SpawnAttributes/Flags/closeOnExecByDefault``
  /// (`POSIX_SPAWN_CLOEXEC_DEFAULT`) in `cAttributes`,
  /// which closes every descriptor that the actions don't install,
  /// even with `POSIX_SPAWN_SETEXEC`.
  /// See ``spawn(_:arguments:environment:fileActions:attributes:credentials:)-(FilePath,_,_,_,_,_)``.
  ///
  /// On Linux, `fileActionDescriptors` is unused: `posix_spawn` applies
  /// the actions before the program starts and closes the close-on-exec
  /// descriptors, so the program gets the ones a spawn without credentials
  /// would.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`;
  /// on Linux, the `setgroups`, `setresgid` and `setresuid` system calls,
  /// on a thread of the method's own, and `posix_spawn`.
  /// - Note: Only available on Darwin and Linux.
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
  /// See ``spawn(_:arguments:environment:cFileActions:cAttributes:credentials:fileActionDescriptors:)-(FilePath,_,_,_,_,_,_)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawnp`.
  /// - Note: Only available on Darwin and Linux.
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

  // Calls `body` with the arguments and the environment as the
  // null-terminated C arrays that posix_spawn takes.
  internal static func _withCStringArrays<R>(
    _ arguments: [String], _ environment: [String]?,
    _ body: (
      UnsafePointer<UnsafeMutablePointer<CChar>?>, UnsafePointer<UnsafeMutablePointer<CChar>?>?
    ) -> R
  ) -> R {
    arguments._withCStringArray { arguments in
      let arguments = _mutableCStrings(arguments)
      guard let environment else { return body(arguments, nil) }
      return environment._withCStringArray { body(arguments, _mutableCStrings($0)) }
    }
  }

  /// Starts a child process running a program,
  /// with arguments and an environment as C arrays,
  /// C file actions and attributes, and other credentials.
  ///
  /// - Parameters:
  ///   - path: The program to run, as a C string.
  ///   - arguments: The program's arguments, as a null-terminated array
  ///     of C strings, including the first,
  ///     which by convention is the program's name.
  ///   - environment: The program's environment,
  ///     as a null-terminated array of C strings
  ///     of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - cFileActions: The C file actions, or `nil` for none.
  ///   - cAttributes: The C attributes, or `nil` for the defaults.
  ///   - credentials: The user and groups for the child to run as.
  ///   - fileActionDescriptors: The descriptors that the file actions use,
  ///     such as the ones they duplicate or close.
  /// - Returns: The child's process ID.
  ///
  /// Use this method for arguments that aren't valid UTF-8.
  /// See ``spawn(_:arguments:environment:cFileActions:cAttributes:credentials:fileActionDescriptors:)-(FilePath,_,_,_,_,_,_)``.
  ///
  /// The corresponding C functions are `fork`, `setgroups`, `setgid`,
  /// `setuid`, and `posix_spawn`;
  /// on Linux, the `setgroups`, `setresgid` and `setresuid` system calls,
  /// on a thread of the method's own, and `posix_spawn`.
  /// - Note: Only available on Darwin and Linux.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: UnsafePointer<CChar>,
    arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    environment: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?,
    credentials: SpawnCredentials,
    fileActionDescriptors: [FileDescriptor]
  ) throws(Errno) -> ProcessID {
    try ProcessID._spawn(
      path, searchingPath: false, arguments: arguments, environment: environment,
      cFileActions: cFileActions, cAttributes: cAttributes, credentials: credentials,
      fileActionDescriptors: fileActionDescriptors
    ).get()
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
    _withCStringArrays(arguments, environment) { arguments, environment in
      _spawn(
        path, searchingPath: searchingPath, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes, credentials: credentials)
    }
  }

  @usableFromInline
  internal static func _spawn(
    _ path: UnsafePointer<CChar>,
    searchingPath: Bool,
    arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    environment: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    fileActions: [SpawnFileAction],
    attributes: SpawnAttributes,
    credentials: SpawnCredentials
  ) -> Result<ProcessID, Errno> {
    #if SYSTEM_PACKAGE_DARWIN
    let closes = SpawnFileAction._closesOfCloseOnExecSources(fileActions)
    #else
    // posix_spawn applies the actions before exec closes the close-on-exec
    // descriptors, which already gives the program what a spawn without
    // credentials would.
    let closes: [SpawnFileAction] = []
    #endif
    return SpawnFileAction._withUnsafeFileActions(fileActions + closes) { cFileActions in
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
    _withCStringArrays(arguments, environment) { arguments, environment in
      _spawn(
        path, searchingPath: searchingPath, arguments: arguments, environment: environment,
        cFileActions: cFileActions, cAttributes: cAttributes, credentials: credentials,
        fileActionDescriptors: fileActionDescriptors)
    }
  }

  @usableFromInline
  internal static func _spawn(
    _ path: UnsafePointer<CChar>,
    searchingPath: Bool,
    arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    environment: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
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
    return spawn(environment)
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

  // Actions that close the descriptors that `actions` use as a source (a
  // duplicate's, or a working directory) and leave with close-on-exec set,
  // which a spawn's exec closes when the program starts. The child clears
  // close-on-exec on them so that the actions can use them, since with
  // POSIX_SPAWN_SETEXEC Darwin closes close-on-exec descriptors before it
  // applies the actions, so they'd stay open in the program. An action that
  // closes a descriptor, replaces it (opening or duplicating another
  // descriptor as it) or lets the child inherit it settles its state; a
  // duplicate onto itself doesn't, since on Darwin it keeps its flag. A
  // descriptor that isn't open is left for the child to report.
  internal static func _closesOfCloseOnExecSources(
    _ actions: [SpawnFileAction]
  ) -> [SpawnFileAction] {
    var sources: [FileDescriptor] = []
    var settled: Set<FileDescriptor> = []
    for action in actions {
      switch action._kind {
      case .open(_, _, _, let descriptor), .close(let descriptor), .inherit(let descriptor):
        settled.insert(descriptor)
      case .duplicate(let source, let target):
        if source != target { settled.insert(target) }
        if !sources.contains(source) { sources.append(source) }
      case .setWorkingDirectoryDescriptor(let directory):
        if !sources.contains(directory) { sources.append(directory) }
      case .setWorkingDirectory, .closeAll:
        break
      }
    }
    return sources.filter { source in
      guard !settled.contains(source), let flags = try? source.descriptorFlags() else {
        return false
      }
      return flags.contains(.closeOnExec)
    }.map { .close($0) }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux)
