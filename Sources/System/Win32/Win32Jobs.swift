/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - The handle

@available(System 199, *)
extension Win32 {
  /// An open job object: a group of processes that Windows manages as one.
  ///
  /// A process stays in the job it's assigned to, and the processes it
  /// creates join the job too, unless the job lets them break away. That
  /// makes a job Windows' counterpart of a POSIX process group, and more:
  /// ``terminate(exitCode:)`` ends every process in it, however they were
  /// started, and ``Win32/JobOptions/killOnClose`` ends them all when the
  /// job's last handle closes, even if the process that held it crashed.
  /// A process can be in more than one job, which then nest.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope
  /// and discards the error.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct JobHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw job handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL`, which `CreateJobObjectW` returns when
    /// it fails.
    ///
    /// - Warning: This initializer doesn't check that `raw` is a handle to a
    ///   job.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw else { return nil }
      self._handle = raw
    }

    /// The raw C handle. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawHandle: HANDLE { _handle }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> HANDLE {
      let handle = _handle
      discard self
      return handle
    }

    /// Closes this handle.
    ///
    /// The handle is closed whether this method returns or throws. The
    /// job's processes keep running, unless the job has
    /// ``Win32/JobOptions/killOnClose`` and this was its last handle.
    ///
    /// The corresponding C function is `CloseHandle`.
    @_alwaysEmitIntoClient
    public consuming func close() throws(Win32.Error) {
      let handle = _handle
      discard self
      try Win32._closeHandle(handle).get()
    }

    deinit {
      _ = system_CloseHandle(_handle)
    }
  }

  /// How a job treats its processes: the limits that take no value.
  ///
  /// The corresponding C type is the `JOB_OBJECT_LIMIT_*` flags of
  /// `JOBOBJECT_BASIC_LIMIT_INFORMATION`'s `LimitFlags`.
  @frozen
  public struct JobOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed set of options from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// A process in the job that has an unhandled exception ends at once,
    /// without Windows Error Reporting's dialog or report.
    ///
    /// The corresponding C constant is
    /// `JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION`.
    @_alwaysEmitIntoClient
    public static var dieOnUnhandledException: JobOptions { JobOptions(rawValue: 0x0400) }

    /// A process in the job can create a process outside it, with
    /// ``Win32/ProcessCreationFlags/breakawayFromJob``.
    ///
    /// The corresponding C constant is `JOB_OBJECT_LIMIT_BREAKAWAY_OK`.
    @_alwaysEmitIntoClient
    public static var breakawayAllowed: JobOptions { JobOptions(rawValue: 0x0800) }

    /// The processes that the job's processes create are outside it,
    /// without asking.
    ///
    /// The corresponding C constant is `JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK`.
    @_alwaysEmitIntoClient
    public static var silentBreakaway: JobOptions { JobOptions(rawValue: 0x1000) }

    /// Closing the job's last handle ends every process in it.
    ///
    /// The corresponding C constant is `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`.
    @_alwaysEmitIntoClient
    public static var killOnClose: JobOptions { JobOptions(rawValue: 0x2000) }
  }
}

// MARK: - Creating and assigning

@available(System 199, *)
extension Win32.JobHandle {
  /// Creates a job, with no processes in it.
  ///
  /// - Parameter inheritable: Whether child processes created with handle
  ///   inheritance enabled receive a copy of this handle. Leave it `false`
  ///   unless a child must manage the job: a process with a handle keeps
  ///   the job open, and can end it.
  ///
  /// The corresponding C function is `CreateJobObjectW`.
  @_alwaysEmitIntoClient
  public static func create(inheritable: Bool = false) throws(Win32.Error) -> Win32.JobHandle {
    Win32.JobHandle(_owning: try Win32._createJob(inheritable: inheritable).get())
  }

  /// Puts a process in the job.
  ///
  /// - Parameter process: The process, whose handle needs
  ///   ``Win32/ProcessAccess/setQuota`` and
  ///   ``Win32/ProcessAccess/terminate``.
  ///
  /// The process stays in the job until it exits, and the processes it
  /// creates from now on join it. To keep a new process from running
  /// before it's in the job, create it
  /// ``Win32/ProcessCreationFlags/suspended``, assign it, and then resume
  /// its thread.
  ///
  /// Throws if the process is in a job that this one can't nest in, such as
  /// one that limits its processes' use of the user interface.
  ///
  /// The corresponding C function is `AssignProcessToJobObject`.
  @_alwaysEmitIntoClient
  public func assign(_ process: borrowing Win32.ProcessHandle) throws(Win32.Error) {
    try Win32._assign(process._handle, to: _handle).get()
  }

  /// Whether a process is in the job.
  ///
  /// - Parameter process: The process, whose handle needs
  ///   ``Win32/ProcessAccess/queryLimitedInformation``.
  ///
  /// The corresponding C function is `IsProcessInJob`.
  @_alwaysEmitIntoClient
  public func contains(_ process: borrowing Win32.ProcessHandle) throws(Win32.Error) -> Bool {
    try Win32._isInJob(process._handle, _handle).get()
  }

  /// Ends every process in the job, as ``Win32/ProcessHandle/terminate(exitCode:)``
  /// ends one.
  ///
  /// - Parameter exitCode: The exit code each process gets.
  ///
  /// The job stays, empty, for processes assigned to it later.
  ///
  /// The corresponding C function is `TerminateJobObject`.
  @_alwaysEmitIntoClient
  public func terminate(exitCode: DWORD) throws(Win32.Error) {
    try Win32._terminateJob(_handle, exitCode: exitCode).get()
  }
}

// MARK: - Options

@available(System 199, *)
extension Win32.JobHandle {
  /// The job's options.
  ///
  /// The corresponding C function is `QueryInformationJobObject`, with
  /// `JobObjectExtendedLimitInformation`.
  @_alwaysEmitIntoClient
  public func options() throws(Win32.Error) -> Win32.JobOptions {
    Win32.JobOptions(
      rawValue: try Win32._limits(_handle).get().BasicLimitInformation.LimitFlags
        & _JOB_OBJECT_OPTION_FLAGS)
  }

  /// Sets the job's options, replacing the ones it had, and keeping its
  /// other limits.
  ///
  /// The corresponding C functions are `QueryInformationJobObject` and
  /// `SetInformationJobObject`, with `JobObjectExtendedLimitInformation`.
  @_alwaysEmitIntoClient
  public func setOptions(_ options: Win32.JobOptions) throws(Win32.Error) {
    try Win32._setOptions(_handle, options.rawValue).get()
  }
}

// MARK: - Notifications

@available(System 199, *)
extension Win32.JobHandle {
  /// Has the job post a packet to a completion port for each event in its
  /// processes' lives: one joining, one exiting, the last one exiting.
  ///
  /// - Parameters:
  ///   - port: The completion port, which keeps receiving the job's packets
  ///     while it's open.
  ///   - key: The packets' key, which tells them from the port's other
  ///     packets.
  ///
  /// ``Win32/JobNotification/init(_:)`` reads a packet the port dequeues.
  /// The processes in the job when it's associated are reported as
  /// joining it. Windows doesn't promise to deliver every packet: a missing
  /// one doesn't mean its event didn't happen.
  ///
  /// The corresponding C function is `SetInformationJobObject`, with
  /// `JobObjectAssociateCompletionPortInformation`.
  @_alwaysEmitIntoClient
  public func associate(with port: borrowing Win32.CompletionPort, key: UInt) throws(Win32.Error) {
    try Win32._associateJob(_handle, with: port._handle, key: key).get()
  }
}

@available(System 199, *)
extension Win32 {
  /// A packet that a job posted to its completion port.
  ///
  /// The corresponding C type is the `JOB_OBJECT_MSG_*` message of a
  /// packet from a port that a `JOBOBJECT_ASSOCIATE_COMPLETION_PORT`
  /// associates with a job.
  @frozen
  public struct JobNotification: Sendable, Hashable {
    /// What happened.
    public var kind: Win32.JobNotification.Kind

    /// The process it happened to, or `nil` for an event of the whole job,
    /// such as ``Kind/noActiveProcesses``.
    public var processID: ProcessID?

    /// The key that ``Win32/JobHandle/associate(with:key:)`` gave the
    /// job's packets.
    public var key: UInt

    /// Reads a packet that a job posted to its completion port.
    ///
    /// - Parameter completion: The packet, which
    ///   ``Win32/CompletionPort/dequeue(timeout:)`` returned with the key the
    ///   job was associated with. Any other packet reads as a meaningless
    ///   notification.
    ///
    /// The packet's byte count is the message, and its `OVERLAPPED` pointer
    /// the process's ID.
    @_alwaysEmitIntoClient
    public init(_ completion: Win32.Completion) {
      self.kind = Kind(rawValue: DWORD(truncatingIfNeeded: completion.bytesTransferred))
      let id = UInt(bitPattern: completion.overlapped)
      self.processID = id == 0 ? nil : ProcessID(rawValue: DWORD(truncatingIfNeeded: id))
      self.key = completion.key
    }
  }
}

@available(System 199, *)
extension Win32.JobNotification {
  /// What a job's packet reports.
  ///
  /// Its values are the `JOB_OBJECT_MSG_*` constants.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct Kind: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed kind from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The job's time limit passed.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_END_OF_JOB_TIME`.
    @_alwaysEmitIntoClient
    public static var endOfJobTime: Kind { Kind(rawValue: 1) }

    /// A process's time limit passed.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_END_OF_PROCESS_TIME`.
    @_alwaysEmitIntoClient
    public static var endOfProcessTime: Kind { Kind(rawValue: 2) }

    /// A process joining the job passed its limit of active processes.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT`.
    @_alwaysEmitIntoClient
    public static var activeProcessLimit: Kind { Kind(rawValue: 3) }

    /// The job's last process exited.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO`.
    @_alwaysEmitIntoClient
    public static var noActiveProcesses: Kind { Kind(rawValue: 4) }

    /// A process joined the job.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_NEW_PROCESS`.
    @_alwaysEmitIntoClient
    public static var newProcess: Kind { Kind(rawValue: 6) }

    /// A process exited.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_EXIT_PROCESS`.
    @_alwaysEmitIntoClient
    public static var processExited: Kind { Kind(rawValue: 7) }

    /// A process exited with an exit code that's an exception's, such as
    /// an access violation's.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS`.
    @_alwaysEmitIntoClient
    public static var processExitedAbnormally: Kind { Kind(rawValue: 8) }

    /// A process passed its memory limit.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT`.
    @_alwaysEmitIntoClient
    public static var processMemoryLimit: Kind { Kind(rawValue: 9) }

    /// A process passed the job's memory limit.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_JOB_MEMORY_LIMIT`.
    @_alwaysEmitIntoClient
    public static var jobMemoryLimit: Kind { Kind(rawValue: 10) }

    /// The job passed one of its notification limits.
    ///
    /// The corresponding C constant is `JOB_OBJECT_MSG_NOTIFICATION_LIMIT`.
    @_alwaysEmitIntoClient
    public static var notificationLimit: Kind { Kind(rawValue: 11) }
  }
}

// MARK: - The process's side

@available(System 199, *)
extension Win32.ProcessHandle {
  /// Whether the process is in a job.
  ///
  /// Needs ``Win32/ProcessAccess/queryLimitedInformation``. A process is
  /// often in a job already, one that the program that started it made.
  ///
  /// The corresponding C function is `IsProcessInJob`, with a `NULL` job.
  @_alwaysEmitIntoClient
  public func isInJob() throws(Win32.Error) -> Bool {
    try Win32._isInJob(_handle, nil).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createJob(inheritable: Bool) -> Result<HANDLE, Win32.Error> {
    var securityAttributes = SECURITY_ATTRIBUTES(
      nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
      lpSecurityDescriptor: nil,
      bInheritHandle: WindowsBool(inheritable))
    guard let job = system_CreateJobObjectW(&securityAttributes) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(job)
  }

  @usableFromInline
  internal static func _assign(_ process: HANDLE, to job: HANDLE) -> Result<Void, Win32.Error> {
    guard system_AssignProcessToJobObject(job, process) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _isInJob(_ process: HANDLE, _ job: HANDLE?) -> Result<Bool, Win32.Error> {
    var result: WindowsBool = false
    guard system_IsProcessInJob(process, job, &result) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(result.boolValue)
  }

  @usableFromInline
  internal static func _terminateJob(_ job: HANDLE, exitCode: DWORD) -> Result<Void, Win32.Error> {
    guard system_TerminateJobObject(job, exitCode) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _limits(
    _ job: HANDLE
  ) -> Result<JOBOBJECT_EXTENDED_LIMIT_INFORMATION, Win32.Error> {
    var information = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
    guard system_QueryInformationJobObject(
      job, JobObjectExtendedLimitInformation, &information,
      DWORD(MemoryLayout<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>.size)
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(information)
  }

  @usableFromInline
  internal static func _setOptions(_ job: HANDLE, _ options: DWORD) -> Result<Void, Win32.Error> {
    // The limits are set together, so the others are read first, and kept.
    var information: JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    switch _limits(job) {
    case .success(let limits): information = limits
    case .failure(let error): return .failure(error)
    }
    let flags = information.BasicLimitInformation.LimitFlags
    information.BasicLimitInformation.LimitFlags =
      (flags & ~_JOB_OBJECT_OPTION_FLAGS) | (options & _JOB_OBJECT_OPTION_FLAGS)
    guard system_SetInformationJobObject(
      job, JobObjectExtendedLimitInformation, &information,
      DWORD(MemoryLayout<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>.size)
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _associateJob(
    _ job: HANDLE, with port: HANDLE, key: UInt
  ) -> Result<Void, Win32.Error> {
    var association = JOBOBJECT_ASSOCIATE_COMPLETION_PORT(
      CompletionKey: UnsafeMutableRawPointer(bitPattern: key), CompletionPort: port)
    guard system_SetInformationJobObject(
      job, JobObjectAssociateCompletionPortInformation, &association,
      DWORD(MemoryLayout<JOBOBJECT_ASSOCIATE_COMPLETION_PORT>.size)
    ) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
