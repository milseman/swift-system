/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// posix_spawn's C attributes and file actions, for code that needs them
// raw: to hand them to a client that changes them, as Subprocess's
// preSpawnProcessConfigurator does, or to pass them to a spawn of its own,
// such as one that forks first to change credentials. SpawnAttributes and
// SpawnFileAction build them, SpawnAttributes.Flags reads and sets their
// flags, and ProcessID.spawn(_:arguments:environment:cFileActions:
// cAttributes:) spawns with them.

#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// A spawn's C attributes: what `posix_spawn` takes a pointer to,
  /// which on Darwin and the BSDs is itself a pointer to the attributes,
  /// `nil` until `posix_spawnattr_init` sets it.
  ///
  /// The corresponding C type is `posix_spawnattr_t`.
  public typealias SpawnAttributes = posix_spawnattr_t?

  /// A spawn's C file actions: what `posix_spawn` takes a pointer to,
  /// which on Darwin and the BSDs is itself a pointer to the actions,
  /// `nil` until `posix_spawn_file_actions_init` sets it.
  ///
  /// The corresponding C type is `posix_spawn_file_actions_t`.
  public typealias SpawnFileActions = posix_spawn_file_actions_t?
  #else
  /// A spawn's C attributes: what `posix_spawn` takes a pointer to.
  ///
  /// The corresponding C type is `posix_spawnattr_t`.
  public typealias SpawnAttributes = posix_spawnattr_t

  /// A spawn's C file actions: what `posix_spawn` takes a pointer to.
  ///
  /// The corresponding C type is `posix_spawn_file_actions_t`.
  public typealias SpawnFileActions = posix_spawn_file_actions_t
  #endif
}

// MARK: - Building them

@available(System 199, *)
extension SpawnAttributes {
  /// Calls a closure with C attributes that have these attributes' settings.
  ///
  /// - Parameter body: A closure that gets the C attributes,
  ///   which it can change with the C library's `posix_spawnattr_*` calls
  ///   and pass to a spawn, but mustn't destroy or keep.
  /// - Returns: What `body` returns.
  ///
  /// The attributes are initialized before `body` runs
  /// and destroyed after it returns.
  /// This method throws the error of a setting that the system rejects,
  /// before calling `body`, or what `body` throws.
  ///
  /// The corresponding C functions are `posix_spawnattr_init`,
  /// `posix_spawnattr_setflags` and the other setters,
  /// and `posix_spawnattr_destroy`.
  @_alwaysEmitIntoClient
  public func withCAttributes<R>(
    _ body: (inout CInterop.SpawnAttributes) throws -> R
  ) throws -> R {
    var bodyError: (any Error)? = nil
    var result: R? = nil
    try _withUnsafeAttributes(extraFlags: 0) { attributes -> Result<(), Errno> in
      do { result = try body(&attributes.pointee) } catch { bodyError = error }
      return .success(())
    }.get()
    if let bodyError { throw bodyError }
    return result!
  }
}

@available(System 199, *)
extension SpawnFileAction {
  /// Calls a closure with C file actions that take these actions, in order.
  ///
  /// - Parameters:
  ///   - actions: The actions.
  ///   - body: A closure that gets the C file actions,
  ///     which it can add to with the C library's
  ///     `posix_spawn_file_actions_*` calls and pass to a spawn,
  ///     but mustn't destroy or keep.
  /// - Returns: What `body` returns.
  ///
  /// The file actions are initialized before `body` runs
  /// and destroyed after it returns.
  /// This method throws the error of an action that the system rejects,
  /// before calling `body`, or what `body` throws.
  ///
  /// The corresponding C functions are `posix_spawn_file_actions_init`,
  /// `posix_spawn_file_actions_addopen` and the other actions,
  /// and `posix_spawn_file_actions_destroy`.
  @_alwaysEmitIntoClient
  public static func withCFileActions<R>(
    _ actions: [SpawnFileAction],
    _ body: (inout CInterop.SpawnFileActions) throws -> R
  ) throws -> R {
    var bodyError: (any Error)? = nil
    var result: R? = nil
    try _withUnsafeFileActions(actions) { fileActions -> Result<(), Errno> in
      do { result = try body(&fileActions.pointee) } catch { bodyError = error }
      return .success(())
    }.get()
    if let bodyError { throw bodyError }
    return result!
  }
}

// MARK: - Their flags

@available(System 199, *)
extension SpawnAttributes.Flags {
  /// Reads the flags of C attributes.
  ///
  /// - Parameter cAttributes: The C attributes, such as
  ///   ``SpawnAttributes/withCAttributes(_:)`` passes its closure.
  ///
  /// The flags include the ones that ``SpawnAttributes``'s other properties
  /// set, such as `POSIX_SPAWN_SETPGROUP` for a
  /// ``SpawnAttributes/processGroup``, which this type keeps but doesn't name.
  ///
  /// The corresponding C function is `posix_spawnattr_getflags`.
  @_alwaysEmitIntoClient
  public init(of cAttributes: UnsafePointer<CInterop.SpawnAttributes>) throws(Errno) {
    self = try Self._flags(of: cAttributes).get()
  }

  @usableFromInline
  internal static func _flags(
    of cAttributes: UnsafePointer<CInterop.SpawnAttributes>
  ) -> Result<Self, Errno> {
    var flags: CShort = 0
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_posix_spawnattr_getflags(cAttributes, &flags)
    }.map { Self(rawValue: flags) }
  }

  /// Replaces the flags of C attributes with these flags.
  ///
  /// - Parameter cAttributes: The C attributes, such as
  ///   ``SpawnAttributes/withCAttributes(_:)`` passes its closure.
  ///
  /// To add a flag, read the flags first:
  ///
  ///     var flags = try SpawnAttributes.Flags(of: &attributes)
  ///     flags.insert(.createSession)
  ///     try flags.store(in: &attributes)
  ///
  /// The corresponding C function is `posix_spawnattr_setflags`.
  @_alwaysEmitIntoClient
  public func store(in cAttributes: UnsafeMutablePointer<CInterop.SpawnAttributes>) throws(Errno) {
    try _store(in: cAttributes).get()
  }

  @usableFromInline
  internal func _store(
    in cAttributes: UnsafeMutablePointer<CInterop.SpawnAttributes>
  ) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_posix_spawnattr_setflags(cAttributes, rawValue)
    }
  }
}

// MARK: - Spawning with them

@available(System 199, *)
extension ProcessID {
  /// Starts a child process running a program,
  /// with C file actions and attributes.
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
  /// - Returns: The child's process ID.
  ///
  /// See ``spawn(_:arguments:environment:fileActions:attributes:)-(FilePath,_,_,_,_)``,
  /// which builds the C values from System's types.
  ///
  /// The corresponding C function is `posix_spawn`.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?
  ) throws(Errno) -> ProcessID {
    try path.withPlatformString { path in
      ProcessID._spawn(
        path, searchingPath: false, arguments: arguments, environment: environment,
        cFileActions: cFileActions, cAttributes: cAttributes)
    }.get()
  }

  /// Starts a child process running a program,
  /// searching for it in the directories that `PATH` names,
  /// with C file actions and attributes.
  ///
  /// See ``spawn(_:arguments:environment:cFileActions:cAttributes:)``
  /// and ``spawn(searchingPathFor:arguments:environment:fileActions:attributes:)``.
  ///
  /// The corresponding C function is `posix_spawnp`.
  @_alwaysEmitIntoClient
  public static func spawn(
    searchingPathFor file: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?
  ) throws(Errno) -> ProcessID {
    try file.withPlatformString { file in
      ProcessID._spawn(
        file, searchingPath: true, arguments: arguments, environment: environment,
        cFileActions: cFileActions, cAttributes: cAttributes)
    }.get()
  }

  @usableFromInline
  internal static func _spawn(
    _ path: UnsafePointer<CChar>,
    searchingPath: Bool,
    arguments: [String],
    environment: [String]?,
    cFileActions: UnsafePointer<CInterop.SpawnFileActions>?,
    cAttributes: UnsafePointer<CInterop.SpawnAttributes>?
  ) -> Result<ProcessID, Errno> {
    arguments._withCStringArray { arguments in
      let arguments = _mutableCStrings(arguments)
      func spawn(_ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>) -> Result<ProcessID, Errno> {
        var pid: pid_t = 0
        return nothingOrReturnedErrno(retryOnInterrupt: false) {
          if searchingPath {
            return system_posix_spawnp(&pid, path, cFileActions, cAttributes, arguments, environment)
          }
          return system_posix_spawn(&pid, path, cFileActions, cAttributes, arguments, environment)
        }.map { ProcessID(rawValue: pid) }
      }
      guard let environment else { return _withCallingEnvironment(spawn) }
      return environment._withCStringArray { spawn(_mutableCStrings($0)) }
    }
  }
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
