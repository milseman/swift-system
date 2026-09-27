/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

// Process groups and sessions. A process group's ID, like a session's, is
// the process ID of the process that leads it, so both are ProcessIDs, as
// in TerminalDescriptor.foregroundProcessGroup() and sessionID().

@available(System 199, *)
extension ProcessID {
  /// The process group of the calling process.
  ///
  /// The corresponding C function is `getpgrp`.
  @_alwaysEmitIntoClient
  public static var currentProcessGroup: ProcessID {
    ProcessID(rawValue: _getpgrp())
  }

  @usableFromInline
  internal static func _getpgrp() -> CInterop.ProcessID {
    system_getpgrp()
  }

  /// Returns the process group of the process.
  ///
  /// - Returns: The ID of the process group,
  ///   which is the process ID of the process that leads it.
  ///
  /// Some platforms throw ``Errno/notPermitted``
  /// for a process in another session.
  ///
  /// The corresponding C function is `getpgid`.
  @_alwaysEmitIntoClient
  public func processGroup() throws(Errno) -> ProcessID {
    try _processGroup().get()
  }

  @usableFromInline
  internal func _processGroup() -> Result<ProcessID, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_getpgid(rawValue)
    }.map(ProcessID.init(rawValue:))
  }

  /// Moves the process into a process group.
  ///
  /// - Parameter group: The process group to join,
  ///   which must be in the process's session.
  ///   Passing the process's own ID makes it the leader of a new group
  ///   with that ID.
  ///
  /// The process must be the calling process
  /// or one of its children that hasn't yet called an `exec` function;
  /// otherwise, this method throws ``Errno/noSuchProcess``
  /// or ``Errno/permissionDenied``.
  /// A shell moves each job's processes into a group of their own,
  /// from both the parent and the child, since either can run first;
  /// to put a child that `spawn` starts in a new group, use
  /// ``SpawnAttributes/processGroup`` instead.
  ///
  /// The corresponding C function is `setpgid`.
  @_alwaysEmitIntoClient
  public func setProcessGroup(_ group: ProcessID) throws(Errno) {
    try _setProcessGroup(group).get()
  }

  @usableFromInline
  internal func _setProcessGroup(_ group: ProcessID) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_setpgid(rawValue, group.rawValue)
    }
  }

  /// Returns the session of the process.
  ///
  /// - Returns: The ID of the session,
  ///   which is the process ID of the process that leads it.
  ///
  /// Some platforms throw ``Errno/notPermitted``
  /// for a process in another session.
  ///
  /// The corresponding C function is `getsid`.
  @_alwaysEmitIntoClient
  public func sessionID() throws(Errno) -> ProcessID {
    try _sessionID().get()
  }

  @usableFromInline
  internal func _sessionID() -> Result<ProcessID, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_getsid(rawValue)
    }.map(ProcessID.init(rawValue:))
  }

  /// Makes the calling process the leader of a new session
  /// and of a new process group in it.
  ///
  /// - Returns: The ID of the new session,
  ///   which is the calling process's ID.
  ///
  /// The new session has no controlling terminal.
  /// A process that already leads a process group can't start a session,
  /// and this method throws ``Errno/notPermitted`` for it;
  /// a daemon starts a session from a child, which never leads a group.
  /// To start a child in a new session, use
  /// ``SpawnAttributes/Flags/createSession`` instead.
  ///
  /// The corresponding C function is `setsid`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func createSession() throws(Errno) -> ProcessID {
    try _createSession().get()
  }

  @usableFromInline
  internal static func _createSession() -> Result<ProcessID, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_setsid()
    }.map(ProcessID.init(rawValue:))
  }
}

#endif // !os(Windows) && !os(WASI)
