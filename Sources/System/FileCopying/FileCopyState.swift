/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A copy's state: the settings and results that copyfile and fcopyfile
// keep in a copyfile_state_t, and the progress they report to its callback.
//
// The C state is an allocation that outlives the call. Here it lives only
// for the duration of one copy: `CopyState` is a value that the copy
// applies to a fresh C state and updates from it afterward, and the progress
// handler is a non-escaping closure. So nothing can use a C state after
// it's freed, and a handler can't be left installed.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: - Copy state

@available(System 199, *)
extension FilePath {
  /// The settings and results of a copy.
  ///
  /// Set a copy's settings in a state,
  /// pass the state to a copy method such as
  /// ``FilePath/copy(to:options:state:)``,
  /// and read the copy's results from it afterward:
  ///
  ///     var state = FilePath.CopyState()
  ///     try source.copy(to: destination, options: [.all, .clone], state: &state)
  ///     print(state.wasCloned ? "cloned" : "copied \(state.copiedByteCount) bytes")
  ///
  /// A setting that's `nil` or `false` leaves the system's default in place.
  /// The results describe a copy of one file.
  /// A recursive copy doesn't set them;
  /// its progress handler gets each file's results instead.
  ///
  /// The corresponding C type is `copyfile_state_t`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct CopyState: Hashable, Sendable {
    /// The number of bytes to read from the source at a time,
    /// or `nil` for the system's choice.
    ///
    /// The copy allocates a buffer of this size.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_SRC_BSIZE`.
    public var sourceBlockSize: UInt32?

    /// The number of bytes to write to the destination at a time,
    /// or `nil` for the system's choice.
    ///
    /// The copy ignores a destination block size
    /// larger than the source block size.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_DST_BSIZE`.
    public var destinationBlockSize: UInt32?

    /// Whether a recursive copy skips directories on other volumes
    /// than the source's.
    ///
    /// The default is `false`, which copies them.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_FORBID_CROSS_MOUNT`.
    public var forbidsCrossingMountPoints: Bool = false

    /// Whether copying POSIX information copies the set-user-ID and
    /// set-group-ID bits, even from or to a volume mounted with `MNT_NOSUID`.
    ///
    /// The default is `false`.
    /// A clone never copies the bits.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_PRESERVE_SUID`.
    public var preservesSetIDBits: Bool = false

    /// Whether the copy leaves the source's data protection class
    /// off the destination.
    ///
    /// The default is `false`, which copies it.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_NOCPROTECT`.
    public var skipsProtectionClass: Bool = false

    /// Whether the copy throws an error rather than replace
    /// a symbolic link at the destination.
    ///
    /// The default is `false`,
    /// which lets a copy replace whatever is at the destination.
    ///
    /// The corresponding C constant is
    /// `COPYFILE_STATE_FORBID_DST_EXISTING_SYMLINKS`.
    public var forbidsReplacingSymbolicLinks: Bool = false

    /// Whether the last copy with this state cloned the file,
    /// rather than copying its data.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_WAS_CLONED`.
    public internal(set) var wasCloned: Bool = false

    /// The number of bytes of data that the last copy with this state
    /// copied, which is `0` if it cloned the file.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_COPIED`.
    public internal(set) var copiedByteCount: Int64 = 0

    /// Creates a state with the system's default settings.
    @_alwaysEmitIntoClient
    public init() {}
  }
}

@available(System 199, *)
extension FilePath.CopyState {
  // Applies the settings that aren't the defaults, so that a system that
  // lacks one only fails a copy that uses it.
  internal func _apply(to state: copyfile_state_t) -> Errno? {
    func set<T>(_ flag: UInt32, _ value: T) -> Errno? {
      withUnsafeBytes(of: value) { value in
        system_copyfile_state_set(state, flag, value.baseAddress!) < 0 ? .current : nil
      }
    }
    if let sourceBlockSize,
      let error = set(_COPYFILE_STATE_SRC_BSIZE, sourceBlockSize) {
      return error
    }
    if let destinationBlockSize,
      let error = set(_COPYFILE_STATE_DST_BSIZE, destinationBlockSize) {
      return error
    }
    // This field is a bool, and the rest are uint32_t.
    if forbidsCrossingMountPoints,
      let error = set(_COPYFILE_STATE_FORBID_CROSS_MOUNT, true) {
      return error
    }
    if preservesSetIDBits,
      let error = set(_COPYFILE_STATE_PRESERVE_SUID, UInt32(1)) {
      return error
    }
    if skipsProtectionClass,
      let error = set(_COPYFILE_STATE_NOCPROTECT, UInt32(1)) {
      return error
    }
    if forbidsReplacingSymbolicLinks,
      let error = set(_COPYFILE_STATE_FORBID_DST_EXISTING_SYMLINKS, UInt32(1)) {
      return error
    }
    return nil
  }

  internal mutating func _record(from state: copyfile_state_t) {
    wasCloned = _copyStateWasCloned(state)
    copiedByteCount = _copyStateCopiedByteCount(state)
  }
}

private func _copyStateWasCloned(_ state: copyfile_state_t) -> Bool {
  var cloned = false
  _ = system_copyfile_state_get(state, _COPYFILE_STATE_WAS_CLONED, &cloned)
  return cloned
}

private func _copyStateCopiedByteCount(_ state: copyfile_state_t) -> Int64 {
  var copied: off_t = 0
  _ = system_copyfile_state_get(state, _COPYFILE_STATE_COPIED, &copied)
  return Int64(copied)
}

// MARK: - Copy progress

@available(System 199, *)
extension FilePath {
  /// A report of a copy's progress, which a copy's progress handler gets.
  ///
  /// A copy reports progress for two kinds of work.
  /// A recursive copy reports the ``Stage/start`` of each file,
  /// and then its ``Stage/finish`` or an ``Stage/error``.
  /// It reports a directory twice,
  /// as ``Kind/directory`` before copying what's in it
  /// and as ``Kind/directoryCleanup`` after.
  /// Any copy that writes data or extended attributes
  /// reports ``Stage/progress`` as it goes,
  /// unless it clones the file.
  ///
  /// The corresponding C type is `copyfile_callback_t`,
  /// which gets the report as its arguments.
  /// - Note: Only available on Darwin.
  @frozen
  public struct CopyProgress: Hashable, Sendable {
    /// What the copy is working on.
    public var kind: Kind

    /// How far the copy has gotten with it.
    public var stage: Stage

    /// The file being copied, or `nil` for a copy between file descriptors.
    public var source: FilePath?

    /// Where the file is being copied to,
    /// or `nil` for a copy between file descriptors.
    public var destination: FilePath?

    /// The number of bytes of the file's data copied so far.
    ///
    /// When a recursive copy finishes a file,
    /// this is the number of bytes it copied,
    /// which is `0` if it cloned the file.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_COPIED`.
    public var copiedByteCount: Int64

    /// Whether the copy cloned the file,
    /// which a recursive copy reports as it finishes each file.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_WAS_CLONED`.
    public var wasCloned: Bool

    /// The name of the extended attribute being copied,
    /// for progress of the kind ``Kind/extendedAttribute``.
    ///
    /// The corresponding C constant is `COPYFILE_STATE_XATTRNAME`.
    public var extendedAttributeName: String?

    /// The error that the copy encountered, at the stage ``Stage/error``.
    public var error: Errno?

    /// Creates a report of a copy's progress.
    @_alwaysEmitIntoClient
    public init(
      kind: Kind,
      stage: Stage,
      source: FilePath? = nil,
      destination: FilePath? = nil,
      copiedByteCount: Int64 = 0,
      wasCloned: Bool = false,
      extendedAttributeName: String? = nil,
      error: Errno? = nil
    ) {
      self.kind = kind
      self.stage = stage
      self.source = source
      self.destination = destination
      self.copiedByteCount = copiedByteCount
      self.wasCloned = wasCloned
      self.extendedAttributeName = extendedAttributeName
      self.error = error
    }
  }
}

@available(System 199, *)
extension FilePath.CopyProgress {
  /// What a copy is working on.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Kind: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed kind from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// A recursive copy failed to read the source hierarchy,
    /// or found a file of an unknown type in it.
    ///
    /// The stage is always ``Stage/error``.
    ///
    /// The corresponding C constant is `COPYFILE_RECURSE_ERROR`.
    @_alwaysEmitIntoClient
    public static var traversalError: Kind { Kind(rawValue: _COPYFILE_RECURSE_ERROR) }

    /// A recursive copy is copying something other than a directory.
    ///
    /// The corresponding C constant is `COPYFILE_RECURSE_FILE`.
    @_alwaysEmitIntoClient
    public static var file: Kind { Kind(rawValue: _COPYFILE_RECURSE_FILE) }

    /// A recursive copy is entering a directory,
    /// before copying what's in it.
    ///
    /// Returning ``Action/skip`` at the start
    /// skips everything in the directory.
    ///
    /// The corresponding C constant is `COPYFILE_RECURSE_DIR`.
    @_alwaysEmitIntoClient
    public static var directory: Kind { Kind(rawValue: _COPYFILE_RECURSE_DIR) }

    /// A recursive copy has copied what's in a directory,
    /// and is setting the destination directory's final permissions.
    ///
    /// The corresponding C constant is `COPYFILE_RECURSE_DIR_CLEANUP`.
    @_alwaysEmitIntoClient
    public static var directoryCleanup: Kind {
      Kind(rawValue: _COPYFILE_RECURSE_DIR_CLEANUP)
    }

    /// The copy is writing a file's data.
    ///
    /// The corresponding C constant is `COPYFILE_COPY_DATA`.
    @_alwaysEmitIntoClient
    public static var data: Kind { Kind(rawValue: _COPYFILE_COPY_DATA) }

    /// The copy is writing one of a file's extended attributes,
    /// which ``FilePath/CopyProgress/extendedAttributeName`` names.
    ///
    /// The corresponding C constant is `COPYFILE_COPY_XATTR`.
    @_alwaysEmitIntoClient
    public static var extendedAttribute: Kind { Kind(rawValue: _COPYFILE_COPY_XATTR) }
  }

  /// How far a copy has gotten with what it's working on.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Stage: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed stage from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The copy is about to begin.
    ///
    /// The corresponding C constant is `COPYFILE_START`.
    @_alwaysEmitIntoClient
    public static var start: Stage { Stage(rawValue: _COPYFILE_START) }

    /// The copy has finished.
    ///
    /// The corresponding C constant is `COPYFILE_FINISH`.
    @_alwaysEmitIntoClient
    public static var finish: Stage { Stage(rawValue: _COPYFILE_FINISH) }

    /// The copy has failed, with ``FilePath/CopyProgress/error``.
    ///
    /// For progress of the kind ``Kind/data``,
    /// returning ``Action/continue`` tries the write again.
    ///
    /// The corresponding C constant is `COPYFILE_ERR`.
    @_alwaysEmitIntoClient
    public static var error: Stage { Stage(rawValue: _COPYFILE_ERR) }

    /// The copy has written some of the data or extended attribute.
    ///
    /// The corresponding C constant is `COPYFILE_PROGRESS`.
    @_alwaysEmitIntoClient
    public static var progress: Stage { Stage(rawValue: _COPYFILE_PROGRESS) }
  }

  /// What a copy should do next, which its progress handler returns.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Action: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed action from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Continue the copy.
    ///
    /// The corresponding C constant is `COPYFILE_CONTINUE`.
    @_alwaysEmitIntoClient
    public static var `continue`: Action { Action(rawValue: _COPYFILE_CONTINUE) }

    /// Skip the file, and go on to the next one;
    /// for data, stop copying it, without an error.
    ///
    /// The corresponding C constant is `COPYFILE_SKIP`.
    @_alwaysEmitIntoClient
    public static var skip: Action { Action(rawValue: _COPYFILE_SKIP) }

    /// Stop the whole copy,
    /// which then throws ``Errno/canceled``.
    ///
    /// What the copy has created stays in place.
    ///
    /// The corresponding C constant is `COPYFILE_QUIT`.
    @_alwaysEmitIntoClient
    public static var quit: Action { Action(rawValue: _COPYFILE_QUIT) }
  }
}

@available(System 199, *)
extension FilePath.CopyProgress.Kind: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the kind.
  @inline(never)
  public var description: String {
    switch self {
    case .traversalError: return "traversalError"
    case .file: return "file"
    case .directory: return "directory"
    case .directoryCleanup: return "directoryCleanup"
    case .data: return "data"
    case .extendedAttribute: return "extendedAttribute"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the kind, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension FilePath.CopyProgress.Stage: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the stage.
  @inline(never)
  public var description: String {
    switch self {
    case .start: return "start"
    case .finish: return "finish"
    case .error: return "error"
    case .progress: return "progress"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the stage, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension FilePath.CopyProgress.Action: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the action.
  @inline(never)
  public var description: String {
    switch self {
    case .continue: return "continue"
    case .skip: return "skip"
    case .quit: return "quit"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the action, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - Running a copy with a state

@available(System 199, *)
internal typealias _CopyProgressHandler =
  (FilePath.CopyProgress) -> FilePath.CopyProgress.Action

// Calls `copy` with a C state that applies `state`'s settings and calls
// `progress`, or with none if there's neither, and records the results in
// `state`. copyfile and fcopyfile return a negative value for an error.
@available(System 199, *)
internal func _withCopyState(
  _ state: UnsafeMutablePointer<FilePath.CopyState>?,
  progress: _CopyProgressHandler?,
  _ copy: (copyfile_state_t?) -> CInt
) -> Result<CInt, Errno> {
  guard state != nil || progress != nil else {
    let result = copy(nil)
    return result < 0 ? .failure(.current) : .success(result)
  }
  guard let cState = system_copyfile_state_alloc() else {
    return .failure(.current)
  }
  defer { _ = system_copyfile_state_free(cState) }
  if let error = state?.pointee._apply(to: cState) {
    return .failure(error)
  }
  var context = _CopyProgressContext(handler: progress)
  return withUnsafeMutablePointer(to: &context) { context in
    if progress != nil {
      let callback: copyfile_callback_t = _copyProgressCallback
      guard
        system_copyfile_state_set(
          cState, _COPYFILE_STATE_STATUS_CB, unsafeBitCast(callback, to: UnsafeRawPointer.self)
        ) == 0,
        system_copyfile_state_set(cState, _COPYFILE_STATE_STATUS_CTX, context) == 0
      else {
        return .failure(.current)
      }
    }
    let result = copy(cState)
    // A recursive copy that quits restores errno to what it was.
    let error = context.pointee.quit ? Errno.canceled : Errno.current
    state?.pointee._record(from: cState)
    return result < 0 ? .failure(error) : .success(result)
  }
}

// The context of a copy's progress callback.
@available(System 199, *)
internal struct _CopyProgressContext {
  internal var handler: _CopyProgressHandler?

  // Whether the handler returned `quit`.
  internal var quit = false
}

// The C callback for a copy's progress handler, whose context is a
// `_CopyProgressContext`. It restores errno before returning, since
// copyfile can go on to use it, except that quitting sets ECANCELED.
@available(System 199, *)
private func _copyProgressCallback(
  _ what: CInt,
  _ stage: CInt,
  _ state: copyfile_state_t?,
  _ source: UnsafePointer<CChar>?,
  _ destination: UnsafePointer<CChar>?,
  _ context: UnsafeMutableRawPointer?
) -> CInt {
  let error = system_errno
  guard
    let context = context?.assumingMemoryBound(to: _CopyProgressContext.self),
    let handler = context.pointee.handler
  else {
    return _COPYFILE_CONTINUE
  }
  let stage = FilePath.CopyProgress.Stage(rawValue: stage)
  var progress = FilePath.CopyProgress(
    kind: FilePath.CopyProgress.Kind(rawValue: what),
    stage: stage,
    source: source.map { FilePath(platformString: $0) },
    destination: destination.map { FilePath(platformString: $0) },
    error: stage == .error ? Errno(rawValue: error) : nil)
  if let state {
    progress.copiedByteCount = _copyStateCopiedByteCount(state)
    progress.wasCloned = _copyStateWasCloned(state)
    var name: UnsafePointer<CChar>? = nil
    if progress.kind == .extendedAttribute,
      system_copyfile_state_get(state, _COPYFILE_STATE_XATTRNAME, &name) == 0,
      let name {
      progress.extendedAttributeName = String(platformString: name)
    }
  }
  let action = handler(progress)
  if action == .quit { context.pointee.quit = true }
  system_errno = action == .quit ? _ECANCELED : error
  return action.rawValue
}

#endif // SYSTEM_PACKAGE_DARWIN
