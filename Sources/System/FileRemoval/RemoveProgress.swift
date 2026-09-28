/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A removal's progress: what removefile reports to its confirm, status and
// error callbacks, and what the progress handler returns to it.
//
// As with a copy's state (FileCopyState.swift), the C state lives only for
// the duration of one removal, and the handler is a non-escaping closure,
// so nothing can use a C state after it's freed.

#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin

@available(System 199, *)
extension FilePath {
  /// A report of a removal's progress, which a removal's progress handler gets.
  ///
  /// See ``FilePath/removeRecursively(options:progress:)``.
  ///
  /// The corresponding C type is `removefile_callback_t`,
  /// which gets the path as an argument.
  /// - Note: Only available on Darwin.
  @frozen
  public struct RemoveProgress: Hashable, Sendable {
    /// How far the removal has gotten with the file.
    public var stage: Stage

    /// The file's path: the path the removal was given, or a path in it,
    /// as an absolute path with the links in its directories resolved.
    ///
    /// A relative path is reported from the root,
    /// and a file in `/var` in `/private/var`.
    public var path: FilePath

    /// The error the removal encountered, at the stage ``Stage/error``.
    ///
    /// The corresponding C constant is `REMOVEFILE_STATE_ERRNO`.
    public var error: Errno?

    /// Creates a report of a removal's progress.
    @_alwaysEmitIntoClient
    public init(stage: Stage, path: FilePath, error: Errno? = nil) {
      self.stage = stage
      self.path = path
      self.error = error
    }
  }
}

@available(System 199, *)
extension FilePath.RemoveProgress {
  /// How far a removal has gotten with a file:
  /// the callback that the C library reports it to.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Stage: RawRepresentable, Hashable, Sendable {
    /// The raw C value: the state key of the stage's callback.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed stage from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The removal is about to remove the file,
    /// or, for a directory, what's in it and then it.
    ///
    /// Returning ``Action/skip`` leaves the file in place.
    ///
    /// The corresponding C constant is `REMOVEFILE_STATE_CONFIRM_CALLBACK`.
    @_alwaysEmitIntoClient
    public static var start: Stage { Stage(rawValue: _REMOVEFILE_STATE_CONFIRM_CALLBACK) }

    /// The removal has removed the file.
    ///
    /// A directory that ``FilePath/RemoveOptions/keepDirectory`` keeps
    /// is reported too, once what's in it is gone.
    ///
    /// The corresponding C constant is `REMOVEFILE_STATE_STATUS_CALLBACK`.
    @_alwaysEmitIntoClient
    public static var finish: Stage { Stage(rawValue: _REMOVEFILE_STATE_STATUS_CALLBACK) }

    /// The removal failed to remove the file,
    /// with ``FilePath/RemoveProgress/error``.
    ///
    /// Returning ``Action/proceed`` or ``Action/skip`` ignores the error.
    ///
    /// The corresponding C constant is `REMOVEFILE_STATE_ERROR_CALLBACK`.
    @_alwaysEmitIntoClient
    public static var error: Stage { Stage(rawValue: _REMOVEFILE_STATE_ERROR_CALLBACK) }
  }

  /// What a removal should do next, which its progress handler returns.
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

    /// Go on: remove the file, or for an error, ignore it.
    ///
    /// The corresponding C constant is `REMOVEFILE_PROCEED`.
    @_alwaysEmitIntoClient
    public static var proceed: Action { Action(rawValue: _REMOVEFILE_PROCEED) }

    /// Leave the file in place, and go on with the rest.
    ///
    /// The corresponding C constant is `REMOVEFILE_SKIP`.
    @_alwaysEmitIntoClient
    public static var skip: Action { Action(rawValue: _REMOVEFILE_SKIP) }

    /// Stop the whole removal, which then throws the error it stopped at,
    /// or ``Errno/canceled``.
    ///
    /// What the removal has removed stays removed.
    ///
    /// The corresponding C constant is `REMOVEFILE_STOP`.
    @_alwaysEmitIntoClient
    public static var stop: Action { Action(rawValue: _REMOVEFILE_STOP) }
  }
}

@available(System 199, *)
extension FilePath.RemoveProgress.Stage: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the stage.
  @inline(never)
  public var description: String {
    switch self {
    case .start: return "start"
    case .finish: return "finish"
    case .error: return "error"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the stage, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension FilePath.RemoveProgress.Action: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the action.
  @inline(never)
  public var description: String {
    switch self {
    case .proceed: return "proceed"
    case .skip: return "skip"
    case .stop: return "stop"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the action, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - Running a removal with a state

@available(System 199, *)
@usableFromInline
internal typealias _RemoveProgressHandler =
  (FilePath.RemoveProgress) -> FilePath.RemoveProgress.Action

// Calls `remove` with a C state whose callbacks call `progress`, or with
// none if there's no handler. removefile returns a negative value for an
// error, but succeeds when a callback stops it at any stage but an error's,
// so a stop is recorded and thrown as ECANCELED.
@available(System 199, *)
@usableFromInline
internal func _withRemoveState(
  progress: _RemoveProgressHandler?,
  _ remove: (removefile_state_t?) -> CInt
) -> Result<Void, Errno> {
  guard let progress else {
    return remove(nil) < 0 ? .failure(.current) : .success(())
  }
  guard let state = system_removefile_state_alloc() else {
    return .failure(.current)
  }
  defer { _ = system_removefile_state_free(state) }
  var context = _RemoveProgressContext(handler: progress)
  return withUnsafeMutablePointer(to: &context) { context in
    let confirm: removefile_callback_t = _removeConfirmCallback
    let status: removefile_callback_t = _removeStatusCallback
    let error: removefile_callback_t = _removeErrorCallback
    for (key, value) in [
      (_REMOVEFILE_STATE_CONFIRM_CALLBACK, unsafeBitCast(confirm, to: UnsafeRawPointer.self)),
      (_REMOVEFILE_STATE_CONFIRM_CONTEXT, UnsafeRawPointer(context)),
      (_REMOVEFILE_STATE_STATUS_CALLBACK, unsafeBitCast(status, to: UnsafeRawPointer.self)),
      (_REMOVEFILE_STATE_STATUS_CONTEXT, UnsafeRawPointer(context)),
      (_REMOVEFILE_STATE_ERROR_CALLBACK, unsafeBitCast(error, to: UnsafeRawPointer.self)),
      (_REMOVEFILE_STATE_ERROR_CONTEXT, UnsafeRawPointer(context)),
    ] {
      guard system_removefile_state_set(state, key, value) == 0 else {
        return .failure(.current)
      }
    }
    let result = remove(state)
    if let stopped = context.pointee.stopped {
      return .failure(stopped)
    }
    return result < 0 ? .failure(.current) : .success(())
  }
}

// The context of a removal's callbacks.
@available(System 199, *)
internal struct _RemoveProgressContext {
  internal var handler: _RemoveProgressHandler

  // The error to throw, once the handler has returned `stop`.
  internal var stopped: Errno? = nil
}

// Calls the handler for one of removefile's callbacks, whose context is a
// `_RemoveProgressContext`. It restores errno before returning, since
// removefile can go on to use it.
@available(System 199, *)
private func _reportRemoveProgress(
  _ stage: FilePath.RemoveProgress.Stage,
  _ state: removefile_state_t?,
  _ path: UnsafePointer<CChar>?,
  _ context: UnsafeMutableRawPointer?
) -> CInt {
  let saved = system_errno
  defer { system_errno = saved }
  guard let context = context?.assumingMemoryBound(to: _RemoveProgressContext.self) else {
    return _REMOVEFILE_PROCEED
  }
  var error: Errno? = nil
  if stage == .error, let state {
    var number: CInt = 0
    if system_removefile_state_get(state, _REMOVEFILE_STATE_ERRNO, &number) == 0, number != 0 {
      error = Errno(rawValue: number)
    }
  }
  let progress = FilePath.RemoveProgress(
    stage: stage,
    path: path.map { FilePath(platformString: $0) } ?? FilePath(),
    error: error)
  let action = context.pointee.handler(progress)
  if action == .stop {
    context.pointee.stopped = error ?? .canceled
    return _REMOVEFILE_STOP
  }
  // A value other than these three would leave the file in place, as a
  // skip does; keep to them.
  return action == .skip ? _REMOVEFILE_SKIP : _REMOVEFILE_PROCEED
}

@available(System 199, *)
private func _removeConfirmCallback(
  _ state: removefile_state_t?, _ path: UnsafePointer<CChar>?, _ context: UnsafeMutableRawPointer?
) -> CInt {
  _reportRemoveProgress(.start, state, path, context)
}

@available(System 199, *)
private func _removeStatusCallback(
  _ state: removefile_state_t?, _ path: UnsafePointer<CChar>?, _ context: UnsafeMutableRawPointer?
) -> CInt {
  _reportRemoveProgress(.finish, state, path, context)
}

@available(System 199, *)
private func _removeErrorCallback(
  _ state: removefile_state_t?, _ path: UnsafePointer<CChar>?, _ context: UnsafeMutableRawPointer?
) -> CInt {
  _reportRemoveProgress(.error, state, path, context)
}

#endif // SYSTEM_PACKAGE_DARWIN
