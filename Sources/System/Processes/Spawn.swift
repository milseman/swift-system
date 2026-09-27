/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

// posix_spawn is unavailable on watchOS and tvOS, and this package doesn't
// wrap it on Android; see Internals/Syscalls+Processes.swift.
#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

// MARK: - Attributes

/// Options for a process that `spawn` starts:
/// its process group, its signals, and on some platforms,
/// its session and the descriptors that it inherits.
///
/// A child inherits its parent's signal mask,
/// and every signal that its parent ignores.
/// To start it with no signals blocked and every signal's default action,
/// as a shell does:
///
///     var attributes = SpawnAttributes()
///     attributes.signalMask = []
///     attributes.defaultSignals = .all
///
/// Each property that's `nil` leaves the child as `posix_spawn` would.
///
/// The corresponding C type is `posix_spawnattr_t`.
@frozen
@available(System 199, *)
public struct SpawnAttributes: Hashable, Sendable {
  /// Options that have no value of their own.
  public var flags: Flags

  /// The process group to put the child in,
  /// or `nil` for the parent's group.
  ///
  /// The corresponding C function is `posix_spawnattr_setpgroup`,
  /// with the `POSIX_SPAWN_SETPGROUP` flag.
  public var processGroup: ProcessGroup?

  /// The signals for the child to block,
  /// or `nil` for the parent's signal mask.
  ///
  /// The corresponding C function is `posix_spawnattr_setsigmask`,
  /// with the `POSIX_SPAWN_SETSIGMASK` flag.
  public var signalMask: SignalSet?

  /// The signals for the child to take the default action for,
  /// even if the parent ignores them,
  /// or `nil` to reset none.
  ///
  /// Signals that the parent catches with a handler
  /// always have their default action in the child.
  /// The system skips the signals that no process can change,
  /// so ``SignalSet/all`` resets every signal that it can.
  ///
  /// The corresponding C function is `posix_spawnattr_setsigdefault`,
  /// with the `POSIX_SPAWN_SETSIGDEF` flag.
  public var defaultSignals: SignalSet?

  #if SYSTEM_PACKAGE_DARWIN
  /// The quality-of-service class for the child,
  /// or `nil` for the default.
  ///
  /// Darwin accepts only ``PThread/QoSClass/utility``
  /// and ``PThread/QoSClass/background``,
  /// and `spawn` throws ``Errno/invalidArgument`` for any other class.
  ///
  /// The corresponding C function is `posix_spawnattr_set_qos_class_np`.
  ///
  /// - Note: Only available on Darwin.
  public var qualityOfService: PThread.QoSClass?
  #endif

  /// Creates a set of attributes.
  ///
  /// - Parameters:
  ///   - flags: Options that have no value of their own.
  ///   - processGroup: The process group to put the child in,
  ///     or `nil` for the parent's group.
  ///   - signalMask: The signals for the child to block,
  ///     or `nil` for the parent's signal mask.
  ///   - defaultSignals: The signals for the child to take
  ///     the default action for, or `nil` to reset none.
  @_alwaysEmitIntoClient
  public init(
    flags: Flags = [],
    processGroup: ProcessGroup? = nil,
    signalMask: SignalSet? = nil,
    defaultSignals: SignalSet? = nil
  ) {
    self.flags = flags
    self.processGroup = processGroup
    self.signalMask = signalMask
    self.defaultSignals = defaultSignals
    #if SYSTEM_PACKAGE_DARWIN
    self.qualityOfService = nil
    #endif
  }
}

@available(System 199, *)
extension SpawnAttributes {
  /// The process group for a child to join.
  @frozen
  public enum ProcessGroup: Hashable, Sendable {
    /// A new process group, which the child leads,
    /// with the child's process ID as its ID.
    ///
    /// Signals that a terminal sends to its foreground group,
    /// such as ``Signal/interrupt`` for Control-C,
    /// don't reach a child in a group of its own
    /// unless the child's group is the foreground group.
    case new

    /// An existing process group, in the parent's session.
    case existing(ProcessID)
  }

  /// Options for a child that have no value of their own.
  ///
  /// The flags that go with a value,
  /// such as `POSIX_SPAWN_SETPGROUP` with a process group,
  /// are set by the value's property
  /// in ``SpawnAttributes``.
  @frozen
  public struct Flags: OptionSet, Sendable, Hashable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CShort

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CShort) { self.rawValue = rawValue }

    /// Sets the child's effective user and group IDs
    /// to the parent's real IDs.
    ///
    /// A set-user-ID or set-group-ID program's effective IDs
    /// still change when the child runs it.
    ///
    /// The corresponding C constant is `POSIX_SPAWN_RESETIDS`.
    @_alwaysEmitIntoClient
    public static var resetIDs: Flags { Flags(rawValue: _POSIX_SPAWN_RESETIDS) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "resetIDs")
    public static var POSIX_SPAWN_RESETIDS: Flags { resetIDs }

    #if SYSTEM_PACKAGE_DARWIN || os(Linux)
    /// Makes the child the leader of a new session,
    /// and of a new process group in it,
    /// with no controlling terminal.
    ///
    /// Don't combine this flag with ``SpawnAttributes/processGroup``:
    /// a session leader can't join a process group.
    ///
    /// The corresponding C constant is `POSIX_SPAWN_SETSID`.
    ///
    /// - Note: Only available on Darwin, from macOS 10.15,
    ///   and on Linux, from glibc 2.26.
    @_alwaysEmitIntoClient
    public static var createSession: Flags { Flags(rawValue: _POSIX_SPAWN_SETSID) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "createSession")
    public static var POSIX_SPAWN_SETSID: Flags { createSession }
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    /// Closes every descriptor in the child,
    /// except for those that its file actions name,
    /// as if each had close-on-exec set.
    ///
    /// With this flag, a child inherits only the descriptors
    /// that a ``SpawnFileAction`` opens, duplicates, or inherits,
    /// even when another thread opens a descriptor
    /// without ``FileDescriptor/OpenOptions/closeOnExec`` at the same time.
    ///
    /// The corresponding C constant is `POSIX_SPAWN_CLOEXEC_DEFAULT`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var closeOnExecByDefault: Flags { Flags(rawValue: _POSIX_SPAWN_CLOEXEC_DEFAULT) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "closeOnExecByDefault")
    public static var POSIX_SPAWN_CLOEXEC_DEFAULT: Flags { closeOnExecByDefault }

    /// Starts the child suspended,
    /// until it receives ``Signal/continue``.
    ///
    /// The corresponding C constant is `POSIX_SPAWN_START_SUSPENDED`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var startSuspended: Flags { Flags(rawValue: _POSIX_SPAWN_START_SUSPENDED) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "startSuspended")
    public static var POSIX_SPAWN_START_SUSPENDED: Flags { startSuspended }
    #endif
  }
}

// MARK: - File actions

/// An action on descriptors that `spawn` takes in the child,
/// in order, before it runs the program.
///
/// A child inherits every descriptor that its parent has open
/// without close-on-exec.
/// File actions arrange the ones it needs,
/// such as a pipe's end as its standard output:
///
///     let child = try ChildProcess.spawn(
///       "/bin/ls", arguments: ["ls"],
///       fileActions: [
///         .duplicate(pipe.writeEnd, as: .standardOutput),
///         .close(pipe.readEnd),
///       ])
///
/// The corresponding C type is `posix_spawn_file_actions_t`.
@frozen
@available(System 199, *)
public struct SpawnFileAction: Hashable, Sendable {
  @usableFromInline
  internal enum _Kind: Hashable, Sendable {
    case open(FilePath, CInt, CInterop.Mode, FileDescriptor)
    case duplicate(FileDescriptor, FileDescriptor)
    case close(FileDescriptor)
    case setWorkingDirectory(FilePath)
    case setWorkingDirectoryDescriptor(FileDescriptor)
    case inherit(FileDescriptor)
    case closeAll(FileDescriptor)
  }

  @usableFromInline
  internal var _kind: _Kind

  @_alwaysEmitIntoClient
  internal init(_ kind: _Kind) { self._kind = kind }
}

@available(System 199, *)
extension SpawnFileAction {
  /// Opens a file in the child as a descriptor.
  ///
  /// - Parameters:
  ///   - path: The file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for a created file.
  ///   - descriptor: The descriptor for the child to open the file as,
  ///     closing it first if it's open.
  ///
  /// See ``FileDescriptor/open(_:_:options:permissions:retryOnInterrupt:)-2266j``.
  /// If `options` includes ``FileDescriptor/OpenOptions/create``,
  /// `permissions` must not be `nil`.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_addopen`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    as descriptor: FileDescriptor
  ) -> SpawnFileAction {
    precondition(
      permissions != nil || !options.contains(.create),
      "SpawnFileAction.open: 'permissions' must not be nil when 'options' contains '.create'")
    return SpawnFileAction(
      .open(path, mode.rawValue | options.rawValue, permissions?.rawValue ?? 0, descriptor))
  }

  /// Duplicates a descriptor in the child as another descriptor.
  ///
  /// - Parameters:
  ///   - descriptor: The descriptor to duplicate.
  ///   - target: The descriptor for the child to have,
  ///     closing it first if it's open.
  ///
  /// The duplicate doesn't have close-on-exec set,
  /// so the child's program inherits it,
  /// even if `descriptor` has it set.
  /// When the two are the same descriptor, POSIX.1-2024
  /// says that this action clears close-on-exec,
  /// but not every platform does; on Darwin, use ``inherit(_:)``.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_adddup2`.
  @_alwaysEmitIntoClient
  public static func duplicate(
    _ descriptor: FileDescriptor, as target: FileDescriptor
  ) -> SpawnFileAction {
    SpawnFileAction(.duplicate(descriptor, target))
  }

  /// Closes a descriptor in the child.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_addclose`.
  @_alwaysEmitIntoClient
  public static func close(_ descriptor: FileDescriptor) -> SpawnFileAction {
    SpawnFileAction(.close(descriptor))
  }

  /// Changes the child's working directory.
  ///
  /// A relative path in a later action, or in the program's path,
  /// is relative to the new working directory.
  /// Not every platform has this action:
  /// `spawn` throws ``Errno/noFunction`` where it's missing,
  /// which includes Darwin's platforms other than macOS,
  /// glibc before 2.29, Android before API level 34, and OpenBSD.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_addchdir`,
  /// or `posix_spawn_file_actions_addchdir_np` where the C library
  /// doesn't have it yet.
  @_alwaysEmitIntoClient
  public static func setWorkingDirectory(_ path: FilePath) -> SpawnFileAction {
    SpawnFileAction(.setWorkingDirectory(path))
  }

  /// Changes the child's working directory to an open directory.
  ///
  /// See ``setWorkingDirectory(_:)-(FilePath)``, which is missing
  /// from the same platforms.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_addfchdir`,
  /// or `posix_spawn_file_actions_addfchdir_np` where the C library
  /// doesn't have it yet.
  @_alwaysEmitIntoClient
  public static func setWorkingDirectory(_ directory: FileDescriptor) -> SpawnFileAction {
    SpawnFileAction(.setWorkingDirectoryDescriptor(directory))
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Lets the child inherit a descriptor,
  /// even with ``SpawnAttributes/Flags/closeOnExecByDefault``,
  /// and even if it has close-on-exec set.
  ///
  /// The corresponding C function is `posix_spawn_file_actions_addinherit_np`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func inherit(_ descriptor: FileDescriptor) -> SpawnFileAction {
    SpawnFileAction(.inherit(descriptor))
  }
  #endif

  #if os(Linux) || os(FreeBSD)
  /// Closes every descriptor in the child
  /// that's numbered `descriptor` or higher.
  ///
  /// Put this action after the ones that arrange the child's descriptors,
  /// to keep the child from inheriting any others,
  /// even one that another thread opens at the same time
  /// without close-on-exec.
  /// `spawn` throws ``Errno/noFunction`` where the C library lacks it.
  ///
  /// The corresponding C function is
  /// `posix_spawn_file_actions_addclosefrom_np`.
  ///
  /// - Note: Only available on Linux, from glibc 2.34,
  ///   and on FreeBSD, from 13.1.
  @_alwaysEmitIntoClient
  public static func closeAll(from descriptor: FileDescriptor) -> SpawnFileAction {
    SpawnFileAction(.closeAll(descriptor))
  }
  #endif
}

// MARK: - Spawning

@available(System 199, *)
extension ProcessID {
  /// Starts a child process running a program.
  ///
  /// - Parameters:
  ///   - path: The program to run.
  ///     A relative path is relative to the working directory
  ///     that the file actions leave the child with.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - fileActions: Actions for the child to take on its descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the child.
  /// - Returns: The child's process ID.
  ///
  /// The caller is responsible for reaping the child,
  /// with ``wait(retryOnInterrupt:)`` or ``tryWait()``,
  /// so that it doesn't stay a zombie after it ends.
  /// ``ChildProcess/spawn(_:arguments:environment:fileActions:attributes:)``
  /// returns an owner that does that.
  ///
  /// If the program can't run, because it doesn't exist or isn't executable,
  /// this method throws the error that the child's `exec` failed with,
  /// such as ``Errno/noSuchFileOrDirectory``,
  /// and no child is left to reap.
  ///
  /// The corresponding C function is `posix_spawn`.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes()
  ) throws(Errno) -> ProcessID {
    try path.withPlatformString { path in
      ProcessID._spawn(
        path, searchingPath: false, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes)
    }.get()
  }

  /// Starts a child process running a program,
  /// searching for it in the directories that `PATH` names.
  ///
  /// - Parameters:
  ///   - file: The program to run.
  ///     A name that contains a slash is a path, used as is;
  ///     otherwise, this method searches for it.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - fileActions: Actions for the child to take on its descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the child.
  /// - Returns: The child's process ID.
  ///
  /// The search uses the calling process's `PATH`,
  /// not the one in `environment`,
  /// and the calling process's working directory,
  /// not the one that the file actions set.
  /// See ``spawn(_:arguments:environment:fileActions:attributes:)``.
  ///
  /// The corresponding C function is `posix_spawnp`.
  @_alwaysEmitIntoClient
  public static func spawn(
    searchingPathFor file: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes()
  ) throws(Errno) -> ProcessID {
    try file.withPlatformString { file in
      ProcessID._spawn(
        file, searchingPath: true, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes)
    }.get()
  }

  /// Starts a child process running a program,
  /// with arguments and an environment as C arrays.
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
  ///   - fileActions: Actions for the child to take on its descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the child.
  /// - Returns: The child's process ID.
  ///
  /// Use this method for arguments that aren't valid UTF-8.
  /// See ``spawn(_:arguments:environment:fileActions:attributes:)``.
  ///
  /// The corresponding C function is `posix_spawn`.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: UnsafePointer<CChar>,
    arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    environment: UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes()
  ) throws(Errno) -> ProcessID {
    try ProcessID._spawn(
      path, searchingPath: false, arguments: arguments, environment: environment,
      fileActions: fileActions, attributes: attributes
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
    extraFlags: CShort = 0
  ) -> Result<ProcessID, Errno> {
    arguments._withCStringArray { arguments in
      let arguments = _mutableCStrings(arguments)
      guard let environment else {
        return _spawn(
          path, searchingPath: searchingPath, arguments: arguments, environment: nil,
          fileActions: fileActions, attributes: attributes, extraFlags: extraFlags)
      }
      return environment._withCStringArray { environment in
        _spawn(
          path, searchingPath: searchingPath, arguments: arguments,
          environment: _mutableCStrings(environment),
          fileActions: fileActions, attributes: attributes, extraFlags: extraFlags)
      }
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
    extraFlags: CShort = 0
  ) -> Result<ProcessID, Errno> {
    SpawnFileAction._withUnsafeFileActions(fileActions) { actions in
      attributes._withUnsafeAttributes(extraFlags: extraFlags) { attributes in
        var pid: pid_t = 0
        let environment = environment ?? UnsafePointer(system_environ())
        return nothingOrReturnedErrno(retryOnInterrupt: false) {
          if searchingPath {
            return system_posix_spawnp(&pid, path, actions, attributes, arguments, environment)
          }
          return system_posix_spawn(&pid, path, actions, attributes, arguments, environment)
        }.map { ProcessID(rawValue: pid) }
      }
    }
  }
}

// The C functions take `char *const []`, and don't change the strings.
internal func _mutableCStrings(
  _ strings: UnsafeBufferPointer<UnsafePointer<CChar>?>
) -> UnsafePointer<UnsafeMutablePointer<CChar>?> {
  UnsafeRawPointer(strings.baseAddress!).assumingMemoryBound(
    to: UnsafeMutablePointer<CChar>?.self)
}

@available(System 199, *)
extension SpawnFileAction {
  // Calls `body` with the C file actions, or reports the first action that
  // fails to add.
  @usableFromInline
  internal static func _withUnsafeFileActions<R>(
    _ actions: [SpawnFileAction],
    _ body: (UnsafePointer<_SpawnFileActionsStorage>) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    var storage = _spawnFileActionsZero
    let initialized = system_posix_spawn_file_actions_init(&storage)
    guard initialized == 0 else { return .failure(Errno(rawValue: initialized)) }
    defer { _ = system_posix_spawn_file_actions_destroy(&storage) }
    for action in actions {
      let added = action._add(to: &storage)
      guard added == 0 else { return .failure(Errno(rawValue: added)) }
    }
    return body(&storage)
  }

  // Returns the error number that adding the action returns.
  internal func _add(to storage: inout _SpawnFileActionsStorage) -> CInt {
    switch _kind {
    case .open(let path, let flags, let mode, let descriptor):
      return path.withPlatformString {
        system_posix_spawn_file_actions_addopen(
          &storage, descriptor.rawValue, $0, flags, mode)
      }
    case .duplicate(let descriptor, let target):
      return system_posix_spawn_file_actions_adddup2(
        &storage, descriptor.rawValue, target.rawValue)
    case .close(let descriptor):
      return system_posix_spawn_file_actions_addclose(&storage, descriptor.rawValue)
    case .setWorkingDirectory(let path):
      return path.withPlatformString {
        system_posix_spawn_file_actions_addchdir(&storage, $0)
      }
    case .setWorkingDirectoryDescriptor(let directory):
      return system_posix_spawn_file_actions_addfchdir(&storage, directory.rawValue)
    case .inherit(let descriptor):
      #if SYSTEM_PACKAGE_DARWIN
      return system_posix_spawn_file_actions_addinherit_np(&storage, descriptor.rawValue)
      #else
      _ = descriptor
      return ENOSYS
      #endif
    case .closeAll(let descriptor):
      return system_posix_spawn_file_actions_addclosefrom(&storage, descriptor.rawValue)
    }
  }
}

@available(System 199, *)
extension SpawnAttributes {
  // Calls `body` with the C attributes, or reports the first attribute that
  // fails to set.
  @usableFromInline
  internal func _withUnsafeAttributes<R>(
    extraFlags: CShort,
    _ body: (UnsafePointer<_SpawnAttributesStorage>) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    var storage = _spawnAttributesZero
    let initialized = system_posix_spawnattr_init(&storage)
    guard initialized == 0 else { return .failure(Errno(rawValue: initialized)) }
    defer { _ = system_posix_spawnattr_destroy(&storage) }
    var flags = self.flags.rawValue | extraFlags
    var result: CInt = 0
    if let processGroup {
      flags |= _POSIX_SPAWN_SETPGROUP
      switch processGroup {
      case .new: result = system_posix_spawnattr_setpgroup(&storage, 0)
      case .existing(let group): result = system_posix_spawnattr_setpgroup(&storage, group.rawValue)
      }
      guard result == 0 else { return .failure(Errno(rawValue: result)) }
    }
    if let signalMask {
      flags |= _POSIX_SPAWN_SETSIGMASK
      result = withUnsafePointer(to: signalMask.rawValue) {
        system_posix_spawnattr_setsigmask(&storage, $0)
      }
      guard result == 0 else { return .failure(Errno(rawValue: result)) }
    }
    if let defaultSignals {
      flags |= _POSIX_SPAWN_SETSIGDEF
      result = withUnsafePointer(to: defaultSignals.rawValue) {
        system_posix_spawnattr_setsigdefault(&storage, $0)
      }
      guard result == 0 else { return .failure(Errno(rawValue: result)) }
    }
    #if SYSTEM_PACKAGE_DARWIN
    if let qualityOfService {
      result = system_posix_spawnattr_set_qos_class_np(&storage, qualityOfService.rawValue)
      guard result == 0 else { return .failure(Errno(rawValue: result)) }
    }
    #endif
    result = system_posix_spawnattr_setflags(&storage, flags)
    guard result == 0 else { return .failure(Errno(rawValue: result)) }
    return body(&storage)
  }
}

// MARK: - Executing

@available(System 199, *)
extension ProcessID {
  /// Replaces the calling process's program with another.
  ///
  /// - Parameters:
  ///   - path: The program to run.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///
  /// This method returns only by throwing the error
  /// that kept the program from running.
  /// When it succeeds, the process keeps its ID, its descriptors
  /// that don't have close-on-exec set, its signal mask,
  /// and the signals that it ignores;
  /// every other thread ends, and no Swift code runs again,
  /// including deinitializers and `defer` blocks.
  ///
  /// The corresponding C function is `execve`.
  @_alwaysEmitIntoClient
  public static func execute(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil
  ) throws(Errno) -> Never {
    let error = path.withPlatformString { path in
      ProcessID._execute(path, arguments: arguments, environment: environment)
    }
    throw error
  }

  /// Replaces the calling process's program with another,
  /// searching for it in the directories that `PATH` names.
  ///
  /// - Parameters:
  ///   - file: The program to run.
  ///     A name that contains a slash is a path, used as is;
  ///     otherwise, this method searches for it.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///
  /// The program gets the calling process's environment.
  /// See ``execute(_:arguments:environment:)``.
  ///
  /// The corresponding C function is `execvp`.
  @_alwaysEmitIntoClient
  public static func execute(
    searchingPathFor file: FilePath,
    arguments: [String]
  ) throws(Errno) -> Never {
    let error = file.withPlatformString { file in
      ProcessID._execute(searchingPathFor: file, arguments: arguments)
    }
    throw error
  }

  @usableFromInline
  internal static func _execute(
    _ path: UnsafePointer<CChar>, arguments: [String], environment: [String]?
  ) -> Errno {
    arguments._withCStringArray { arguments in
      let arguments = _mutableCStrings(arguments)
      guard let environment else {
        _ = system_execve(path, arguments, system_environ())
        return Errno.current
      }
      return environment._withCStringArray { environment in
        _ = system_execve(path, arguments, _mutableCStrings(environment))
        return Errno.current
      }
    }
  }

  @usableFromInline
  internal static func _execute(
    searchingPathFor file: UnsafePointer<CChar>, arguments: [String]
  ) -> Errno {
    arguments._withCStringArray { arguments in
      _ = system_execvp(file, _mutableCStrings(arguments))
      return Errno.current
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Replaces the calling process's program with another,
  /// applying file actions and attributes as `spawn` does.
  ///
  /// - Parameters:
  ///   - path: The program to run.
  ///   - arguments: The program's arguments, including the first,
  ///     which by convention is the program's name, such as `ls`.
  ///   - environment: The program's environment,
  ///     as strings of the form `NAME=value`,
  ///     or `nil` for the calling process's environment.
  ///   - fileActions: Actions to take on the process's descriptors,
  ///     in order, before it runs the program.
  ///   - attributes: Options for the process.
  ///
  /// With ``SpawnAttributes/Flags/closeOnExecByDefault``,
  /// the new program inherits only the descriptors
  /// that the file actions name.
  /// See ``execute(_:arguments:environment:)``.
  ///
  /// The corresponding C function is `posix_spawn`,
  /// with the `POSIX_SPAWN_SETEXEC` flag.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func execute(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes
  ) throws(Errno) -> Never {
    let result = path.withPlatformString { path in
      ProcessID._spawn(
        path, searchingPath: false, arguments: arguments, environment: environment,
        fileActions: fileActions, attributes: attributes,
        extraFlags: _POSIX_SPAWN_SETEXEC)
    }
    switch result {
    case .failure(let error): throw error
    case .success:
      // With POSIX_SPAWN_SETEXEC, posix_spawn returns only when it fails.
      throw Errno.execFormatError
    }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
