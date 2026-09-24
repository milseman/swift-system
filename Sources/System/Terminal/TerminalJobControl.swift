/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

// MARK: - Job Control

@available(System 199, *)
extension TerminalDescriptor {
  /// Returns the terminal's foreground process group.
  ///
  /// - Returns: The ID of the process group whose processes
  ///   can read from the terminal,
  ///   and that receive the signals the terminal generates,
  ///   such as `SIGINT`.
  ///   If the terminal has no foreground process group,
  ///   the result doesn't match any existing process group.
  ///
  /// The terminal must be the calling process's controlling terminal;
  /// otherwise, this method throws
  /// ``Errno/inappropriateIOCTLForDevice``.
  ///
  /// The corresponding C function is `tcgetpgrp`.
  @_alwaysEmitIntoClient
  public func foregroundProcessGroup() throws(Errno) -> ProcessID {
    try _foregroundProcessGroup().get()
  }

  @usableFromInline
  internal func _foregroundProcessGroup() -> Result<ProcessID, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_tcgetpgrp(rawValue)
    }.map(ProcessID.init(rawValue:))
  }

  /// Makes a process group the terminal's foreground process group.
  ///
  /// - Parameters:
  ///   - group: The process group to bring to the foreground,
  ///     which must be in the calling process's session.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// A shell calls this method to give the terminal to a job,
  /// and again to take it back.
  /// The terminal must be the calling process's controlling terminal;
  /// otherwise, this method throws
  /// ``Errno/inappropriateIOCTLForDevice``.
  ///
  /// When a process in a background process group calls this method,
  /// the system sends `SIGTTOU` to that process group,
  /// which stops it by default,
  /// unless the calling thread blocks or ignores the signal.
  ///
  /// The corresponding C function is `tcsetpgrp`.
  @_alwaysEmitIntoClient
  public func setForegroundProcessGroup(
    _ group: ProcessID,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setForegroundProcessGroup(group, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setForegroundProcessGroup(
    _ group: ProcessID,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_tcsetpgrp(rawValue, group.rawValue)
    }
  }

  /// Returns the session that the terminal belongs to.
  ///
  /// - Returns: The ID of the session,
  ///   which is the process ID of the session's leader.
  ///
  /// The terminal must be the calling process's controlling terminal;
  /// otherwise, this method throws
  /// ``Errno/inappropriateIOCTLForDevice``.
  ///
  /// The corresponding C function is `tcgetsid`.
  @_alwaysEmitIntoClient
  public func sessionID() throws(Errno) -> ProcessID {
    try _sessionID().get()
  }

  @usableFromInline
  internal func _sessionID() -> Result<ProcessID, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_tcgetsid(rawValue)
    }.map(ProcessID.init(rawValue:))
  }
}

#endif // !os(Windows) && !os(WASI)
