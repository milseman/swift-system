/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

// The low-level interface to fcntl: a `control` method for each kind of
// argument that commands take. The common commands also have methods of
// their own, such as `descriptorFlags()`, in FileOperations.swift and
// FileLock.swift.

@available(System 199, *)
extension FileDescriptor {
  /// Performs a command that takes no argument on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// This method is the low-level interface to `fcntl`.
  /// Prefer a method that performs the command directly, if there is one,
  /// such as ``descriptorFlags()`` for
  /// ``Command/getDescriptorFlags``.
  ///
  /// The corresponding C function is `fcntl`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a command that takes an integer argument on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform.
  ///   - value: The command's argument.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// This method is the low-level interface to `fcntl`.
  /// Prefer a method that performs the command directly, if there is one,
  /// such as ``setDescriptorFlags(_:)`` for
  /// ``Command/setDescriptorFlags``.
  ///
  /// The corresponding C function is `fcntl`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ value: CInt,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, value, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a command that takes a pointer argument on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform.
  ///   - pointer: The command's argument,
  ///     which must point to memory of the size and layout the command expects.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// This method is the low-level interface to `fcntl`.
  /// Prefer a method that performs the command directly, if there is one,
  /// or one of the `control` methods
  /// that takes a typed argument, such as a ``FileLock``.
  ///
  /// The corresponding C function is `fcntl`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ pointer: UnsafeMutableRawPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, pointer, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a record lock command on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform, such as
  ///     ``Command/getLock`` or ``Command/setLock``.
  ///   - lock: The lock that the command places, removes, or looks up.
  ///     Commands that look up a lock replace this value.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// To place and remove open file description locks,
  /// prefer ``lock(_:byteRange:retryOnInterrupt:)``
  /// and ``unlock(byteRange:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `fcntl`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ lock: inout FileLock,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, &lock, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _control(
    _ command: Command,
    retryOnInterrupt: Bool
  ) -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fcntl(self.rawValue, command.rawValue)
    }
  }

  @usableFromInline
  internal func _control(
    _ command: Command,
    _ value: CInt,
    retryOnInterrupt: Bool
  ) -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fcntl(self.rawValue, command.rawValue, value)
    }
  }

  @usableFromInline
  internal func _control(
    _ command: Command,
    _ pointer: UnsafeMutableRawPointer,
    retryOnInterrupt: Bool
  ) -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fcntl(self.rawValue, command.rawValue, pointer)
    }
  }

  @usableFromInline
  internal func _control(
    _ command: Command,
    _ lock: inout FileLock,
    retryOnInterrupt: Bool
  ) -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      withUnsafeMutablePointer(to: &lock.rawValue) {
        system_fcntl(self.rawValue, command.rawValue, $0)
      }
    }
  }
}

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension FileDescriptor {
  /// Performs a command that preallocates storage on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform, ``Command/preallocate``.
  ///   - store: The request.
  ///     The command sets its ``ControlTypes/Store/bytesAllocated``.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// The corresponding C function is `fcntl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ store: inout ControlTypes.Store,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, &store.rawValue, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a command that deallocates a range of the file
  /// on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform, ``Command/punchHole``.
  ///   - punchHole: The range to deallocate.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// The corresponding C function is `fcntl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ punchHole: inout ControlTypes.PunchHole,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, &punchHole.rawValue, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a command that reads a range of the file ahead of time
  /// on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform, ``Command/readAdvise``.
  ///   - readAdvisory: The range to read.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// The corresponding C function is `fcntl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ readAdvisory: inout ControlTypes.ReadAdvisory,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(command, &readAdvisory.rawValue, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Performs a command that looks up where file data is on its device
  /// on this file descriptor.
  ///
  /// - Parameters:
  ///   - command: The command to perform, ``Command/logicalToPhysical``
  ///     or ``Command/logicalToPhysicalExtended``.
  ///   - logicalToPhysical: The location to look up,
  ///     which the command replaces with the location it finds.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The command's result, whose meaning depends on the command.
  ///
  /// The corresponding C function is `fcntl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  @discardableResult
  public func control(
    _ command: Command,
    _ logicalToPhysical: inout ControlTypes.LogicalToPhysical,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> CInt {
    try _control(
      command, &logicalToPhysical.rawValue, retryOnInterrupt: retryOnInterrupt
    ).get()
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#endif // !os(Windows) && !os(WASI)
