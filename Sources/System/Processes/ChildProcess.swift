/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// A child process that the caller owns, and must reap.
///
/// A child that ends stays a zombie, keeping its process ID,
/// until its parent reaps it by waiting for it.
/// `ChildProcess` can't be copied, and reaps its child exactly once:
/// either ``wait()`` reaps it, or ``tryWait()`` does,
/// or destroying the owner does.
/// Until then, the child's ID can't name another process,
/// so ``sendSignal(_:)`` can't signal the wrong one.
///
///     let child = try ChildProcess.spawn("/bin/sleep", arguments: ["sleep", "10"])
///     try child.sendSignal(.terminate)
///     print(try child.wait())    // ended by SIGTERM
///
/// That guarantee holds only while nothing else reaps the child:
/// a wait for any child, such as ``ProcessID/waitForAnyChild(retryOnInterrupt:)``,
/// or setting ``Signal/childStatusChange``'s action to ``Signal/Action/ignore``,
/// reaps it behind the owner's back.
///
/// Destroying a `ChildProcess` whose child hasn't been reaped
/// ends the child with ``Signal/kill``, if it's still running,
/// and reaps it:
/// a child started in a scope doesn't outlive the scope,
/// even when an error ends the scope early.
/// Whether destruction should instead wait for the child,
/// leave it running, or trap is an open question,
/// the same one as `PThread`'s and `OwnedFD`'s;
/// see Prototype/Processes.
/// To leave a child running, take its ID with ``relinquish()``,
/// and reap it later.
@frozen
@available(System 199, *)
public struct ChildProcess: ~Copyable, Sendable {
  @usableFromInline
  internal let _id: ProcessID

  // How the child ended, once tryWait() has reaped it.
  @usableFromInline
  internal var _status: ExitStatus?

  /// Takes ownership of a child process.
  ///
  /// The process must be an unreaped child of the calling process,
  /// and nothing else may reap it.
  @_alwaysEmitIntoClient
  public init(taking id: ProcessID) {
    self._id = id
    self._status = nil
  }

  deinit {
    if _status == nil { ChildProcess._destroy(_id) }
  }
}

@available(System 199, *)
extension ChildProcess {
  /// The child's process ID.
  ///
  /// The ID names the child until it's reaped;
  /// after that, the system can give it to another process.
  @_alwaysEmitIntoClient
  public var id: ProcessID { _id }

  /// Waits for the child to end, and reaps it.
  ///
  /// - Returns: How the child ended.
  ///
  /// If ``tryWait()`` already reaped the child,
  /// this method returns how it ended.
  /// It retries the wait when a signal interrupts it;
  /// to wait interruptibly, call ``ProcessID/wait(retryOnInterrupt:)``
  /// on ``id``, which leaves the owner in place.
  /// It throws ``Errno/noChildProcess``
  /// if something else already reaped the child.
  ///
  /// The corresponding C function is `waitpid`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread; wait for the process's exit event instead, then call tryWait()")
  public consuming func wait() throws(Errno) -> ExitStatus {
    let id = _id
    let status = _status
    discard self
    if let status { return status }
    return try id._wait(retryOnInterrupt: true).get()
  }

  /// Reaps the child if it has ended, without waiting.
  ///
  /// - Returns: How the child ended, or `nil` if it's still running.
  ///
  /// Once this method reaps the child, the owner remembers how it ended:
  /// later calls return the same status,
  /// ``sendSignal(_:)`` throws ``Errno/noSuchProcess``,
  /// and destroying the owner does nothing.
  /// An event loop calls this method
  /// after a kqueue or a process descriptor reports that the child exited.
  ///
  /// The corresponding C function is `waitpid`, with `WNOHANG`.
  @_alwaysEmitIntoClient
  public mutating func tryWait() throws(Errno) -> ExitStatus? {
    if let _status { return _status }
    _status = try _id._tryWait().get()
    return _status
  }

  /// Sends a signal to the child.
  ///
  /// - Parameter signal: The signal to send,
  ///   or `nil` to send none, which checks that the child exists.
  ///
  /// Until the child is reaped, its ID can't name another process,
  /// even after the child ends:
  /// the signal reaches the child, or does nothing.
  /// Once ``tryWait()`` has reaped the child,
  /// this method throws ``Errno/noSuchProcess`` without sending anything.
  ///
  /// The corresponding C function is `kill`.
  @_alwaysEmitIntoClient
  public func sendSignal(_ signal: Signal?) throws(Errno) {
    guard _status == nil else { throw .noSuchProcess }
    try _id._sendSignal(signal).get()
  }

  /// Transfers the responsibility for reaping the child to the caller,
  /// without waiting for it or signaling it.
  ///
  /// - Returns: The child's process ID.
  ///
  /// After this method returns, the caller must reap the child,
  /// with ``ProcessID/wait(retryOnInterrupt:)`` or ``ProcessID/tryWait()``,
  /// or it stays a zombie after it ends.
  /// If ``tryWait()`` already reaped the child,
  /// the ID no longer names it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> ProcessID {
    let id = _id
    discard self
    return id
  }
}

@available(System 199, *)
extension ChildProcess {
  // Called by the deinit for a child that hasn't been reaped. The deinit
  // can't throw, so errors are dropped. This is the default policy, not a
  // decision; see Prototype/Processes.
  internal static func _destroy(_ id: ProcessID) {
    guard id.rawValue > 0 else { return }
    // Check, without reaping, that the child is still an unreaped child of
    // this process. If something else reaped it, its ID may name another
    // process now, which mustn't be signaled.
    let peek = ProcessID._waitID(
      _P_PID, id_t(truncatingIfNeeded: id.rawValue),
      options: [.exited, .noHang, .keepWaitable], retryOnInterrupt: true)
    guard case .success(let exited) = peek else { return }
    if exited == nil {
      _ = id._sendSignal(.kill)
    }
    _ = id._wait(retryOnInterrupt: true)
  }
}

#if !os(watchOS) && !os(tvOS) && !os(Android)
@available(System 199, *)
extension ChildProcess {
  /// Starts a child process running a program,
  /// and takes ownership of it.
  ///
  /// See ``ProcessID/spawn(_:arguments:environment:fileActions:attributes:)``.
  ///
  /// The corresponding C function is `posix_spawn`.
  @_alwaysEmitIntoClient
  public static func spawn(
    _ path: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes()
  ) throws(Errno) -> ChildProcess {
    ChildProcess(taking: try ProcessID.spawn(
      path, arguments: arguments, environment: environment,
      fileActions: fileActions, attributes: attributes))
  }

  /// Starts a child process running a program,
  /// searching for it in the directories that `PATH` names,
  /// and takes ownership of it.
  ///
  /// See ``ProcessID/spawn(searchingPathFor:arguments:environment:fileActions:attributes:)``.
  ///
  /// The corresponding C function is `posix_spawnp`.
  @_alwaysEmitIntoClient
  public static func spawn(
    searchingPathFor file: FilePath,
    arguments: [String],
    environment: [String]? = nil,
    fileActions: [SpawnFileAction] = [],
    attributes: SpawnAttributes = SpawnAttributes()
  ) throws(Errno) -> ChildProcess {
    ChildProcess(taking: try ProcessID.spawn(
      searchingPathFor: file, arguments: arguments, environment: environment,
      fileActions: fileActions, attributes: attributes))
  }
}
#endif // !os(watchOS) && !os(tvOS) && !os(Android)

#endif // !os(Windows) && !os(WASI)
