/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A process's BSD information: proc_pidinfo's PROC_PIDTBSDINFO.

// libproc is only in the macOS SDK.
#if os(macOS)

// Must import here to use the C types in @_alwaysEmitIntoClient APIs.
import Darwin

@available(System 199, *)
extension CInterop {
  /// The C `proc_bsdinfo` type,
  /// which describes a process's IDs, credentials, and state.
  public typealias ProcBSDInfo = proc_bsdinfo
}

@available(System 199, *)
extension ProcessID {
  /// The kernel's information about a process:
  /// its IDs, credentials, state, and terminal.
  ///
  /// To get the information for a process,
  /// call ``ProcessID/bsdInfo()``.
  ///
  /// The process's start time is in the raw information's
  /// `pbi_start_tvsec` and `pbi_start_tvusec` fields,
  /// seconds and microseconds since the Epoch.
  ///
  /// The corresponding C type is `struct proc_bsdinfo`.
  /// - Note: Only available on macOS.
  @frozen
  public struct BSDInfo: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public let rawValue: CInterop.ProcBSDInfo

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.ProcBSDInfo) { self.rawValue = rawValue }
  }

  /// Returns the kernel's information about the process.
  ///
  /// Getting the information for a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidinfo`,
  /// with the `PROC_PIDTBSDINFO` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func bsdInfo() throws(Errno) -> BSDInfo {
    try _bsdInfo().get()
  }

  @usableFromInline
  internal func _bsdInfo() -> Result<BSDInfo, Errno> {
    var info = CInterop.ProcBSDInfo()
    let size = CInt(MemoryLayout<CInterop.ProcBSDInfo>.size)
    // proc_pidinfo returns the number of bytes it fills, or 0 on failure.
    let filled = withUnsafeMutableBytes(of: &info) { buffer in
      system_proc_pidinfo(rawValue, _PROC_PIDTBSDINFO, 0, buffer.baseAddress!, size)
    }
    if filled == 0 { return .failure(.current) }
    // A partial structure isn't the information, and shouldn't happen.
    guard filled == size else { return .failure(.ioError) }
    return .success(BSDInfo(rawValue: info))
  }
}

@available(System 199, *)
extension ProcessID.BSDInfo {
  /// The process's ID.
  ///
  /// The corresponding C field is `pbi_pid`.
  @_alwaysEmitIntoClient
  public var id: ProcessID { ProcessID(rawValue: CInterop.ProcessID(bitPattern: rawValue.pbi_pid)) }

  /// The ID of the process's parent.
  ///
  /// The corresponding C field is `pbi_ppid`.
  @_alwaysEmitIntoClient
  public var parent: ProcessID {
    ProcessID(rawValue: CInterop.ProcessID(bitPattern: rawValue.pbi_ppid))
  }

  /// The ID of the process's process group.
  ///
  /// The corresponding C field is `pbi_pgid`.
  @_alwaysEmitIntoClient
  public var processGroup: ProcessID {
    ProcessID(rawValue: CInterop.ProcessID(bitPattern: rawValue.pbi_pgid))
  }

  /// The process's effective user.
  ///
  /// The corresponding C field is `pbi_uid`.
  @_alwaysEmitIntoClient
  public var effectiveUser: UserID { UserID(rawValue: rawValue.pbi_uid) }

  /// The process's effective group.
  ///
  /// The corresponding C field is `pbi_gid`.
  @_alwaysEmitIntoClient
  public var effectiveGroup: GroupID { GroupID(rawValue: rawValue.pbi_gid) }

  /// The process's real user.
  ///
  /// The corresponding C field is `pbi_ruid`.
  @_alwaysEmitIntoClient
  public var realUser: UserID { UserID(rawValue: rawValue.pbi_ruid) }

  /// The process's real group.
  ///
  /// The corresponding C field is `pbi_rgid`.
  @_alwaysEmitIntoClient
  public var realGroup: GroupID { GroupID(rawValue: rawValue.pbi_rgid) }

  /// The process's saved set-user-ID,
  /// the effective user that it can switch back to.
  ///
  /// The corresponding C field is `pbi_svuid`.
  @_alwaysEmitIntoClient
  public var savedUser: UserID { UserID(rawValue: rawValue.pbi_svuid) }

  /// The process's saved set-group-ID,
  /// the effective group that it can switch back to.
  ///
  /// The corresponding C field is `pbi_svgid`.
  @_alwaysEmitIntoClient
  public var savedGroup: GroupID { GroupID(rawValue: rawValue.pbi_svgid) }

  /// The first 16 bytes of the name of the process's executable.
  ///
  /// The corresponding C field is `pbi_comm`.
  @_alwaysEmitIntoClient
  public var command: String { _string(rawValue.pbi_comm) }

  /// The name that the process registered,
  /// or an empty string if it hasn't registered one.
  ///
  /// The corresponding C field is `pbi_name`.
  @_alwaysEmitIntoClient
  public var name: String { _string(rawValue.pbi_name) }

  /// The process's state, such as running or stopped.
  ///
  /// The corresponding C field is `pbi_status`.
  @_alwaysEmitIntoClient
  public var status: Status { Status(rawValue: rawValue.pbi_status) }

  /// Details of the process's state, such as whether it's being traced.
  ///
  /// The corresponding C field is `pbi_flags`.
  @_alwaysEmitIntoClient
  public var flags: Flags { Flags(rawValue: rawValue.pbi_flags) }

  /// The process's exit status, if it has exited
  /// and its parent hasn't waited for it.
  ///
  /// The corresponding C field is `pbi_xstatus`.
  @_alwaysEmitIntoClient
  public var exitStatus: CInt { CInt(bitPattern: rawValue.pbi_xstatus) }

  /// The number of entries in the process's file descriptor table,
  /// which exceeds the process's highest open file descriptor.
  ///
  /// The table grows as the process opens files,
  /// so this is more than the number the process has open;
  /// to list those, call ``ProcessID/openFileDescriptors()``.
  ///
  /// The corresponding C field is `pbi_nfiles`.
  @_alwaysEmitIntoClient
  public var descriptorTableSize: Int { Int(rawValue.pbi_nfiles) }

  /// The process's nice value, its scheduling priority adjustment.
  ///
  /// The corresponding C field is `pbi_nice`.
  @_alwaysEmitIntoClient
  public var nice: Int { Int(rawValue.pbi_nice) }

  /// The process's controlling terminal,
  /// or `nil` if it has none.
  ///
  /// The corresponding C field is `e_tdev`.
  @_alwaysEmitIntoClient
  public var controllingTerminal: DeviceID? {
    // NODEV, which is -1.
    let device = CInterop.DeviceID(bitPattern: rawValue.e_tdev)
    return device == -1 ? nil : DeviceID(rawValue: device)
  }

  /// The foreground process group of the process's controlling terminal,
  /// or `nil` if it has none.
  ///
  /// The corresponding C field is `e_tpgid`.
  @_alwaysEmitIntoClient
  public var terminalProcessGroup: ProcessID? {
    rawValue.e_tpgid == 0
      ? nil : ProcessID(rawValue: CInterop.ProcessID(bitPattern: rawValue.e_tpgid))
  }

  @usableFromInline
  internal func _string<T>(_ field: T) -> String {
    withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
  }
}

@available(System 199, *)
extension ProcessID.BSDInfo {
  /// A process's state.
  ///
  /// The corresponding C type is the `p_stat` values, such as `SRUN`.
  /// - Note: Only available on macOS.
  @frozen
  public struct Status: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed status from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The process is being created by `fork`.
    ///
    /// The corresponding C constant is `SIDL`.
    @_alwaysEmitIntoClient
    public static var creating: Status { Status(rawValue: _SIDL) }

    /// The process can run.
    ///
    /// The corresponding C constant is `SRUN`.
    @_alwaysEmitIntoClient
    public static var running: Status { Status(rawValue: _SRUN) }

    /// The process is waiting for an event.
    ///
    /// The corresponding C constant is `SSLEEP`.
    @_alwaysEmitIntoClient
    public static var sleeping: Status { Status(rawValue: _SSLEEP) }

    /// The process is stopped, as by a signal or a debugger.
    ///
    /// The corresponding C constant is `SSTOP`.
    @_alwaysEmitIntoClient
    public static var stopped: Status { Status(rawValue: _SSTOP) }

    /// The process has exited, and its parent hasn't waited for it.
    ///
    /// The corresponding C constant is `SZOMB`.
    @_alwaysEmitIntoClient
    public static var zombie: Status { Status(rawValue: _SZOMB) }
  }

  /// Details of a process's state.
  ///
  /// - Note: Only available on macOS.
  @frozen
  public struct Flags: OptionSet, Sendable, Hashable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The process is a system process.
    ///
    /// The corresponding C constant is `PROC_FLAG_SYSTEM`.
    @_alwaysEmitIntoClient
    public static var system: Flags { Flags(rawValue: _PROC_FLAG_SYSTEM) }

    /// The process is being traced, as by a debugger.
    ///
    /// The corresponding C constant is `PROC_FLAG_TRACED`.
    @_alwaysEmitIntoClient
    public static var traced: Flags { Flags(rawValue: _PROC_FLAG_TRACED) }

    /// The process is exiting.
    ///
    /// The corresponding C constant is `PROC_FLAG_INEXIT`.
    @_alwaysEmitIntoClient
    public static var exiting: Flags { Flags(rawValue: _PROC_FLAG_INEXIT) }

    /// The process's parent is waiting for it to exec or exit,
    /// as after `vfork`.
    ///
    /// The corresponding C constant is `PROC_FLAG_PPWAIT`.
    @_alwaysEmitIntoClient
    public static var parentWaiting: Flags { Flags(rawValue: _PROC_FLAG_PPWAIT) }

    /// The process runs 64-bit code.
    ///
    /// The corresponding C constant is `PROC_FLAG_LP64`.
    @_alwaysEmitIntoClient
    public static var is64Bit: Flags { Flags(rawValue: _PROC_FLAG_LP64) }

    /// The process leads its session.
    ///
    /// The corresponding C constant is `PROC_FLAG_SLEADER`.
    @_alwaysEmitIntoClient
    public static var sessionLeader: Flags { Flags(rawValue: _PROC_FLAG_SLEADER) }

    /// The process's session has a controlling terminal.
    ///
    /// The corresponding C constant is `PROC_FLAG_CTTY`.
    @_alwaysEmitIntoClient
    public static var sessionHasTerminal: Flags { Flags(rawValue: _PROC_FLAG_CTTY) }

    /// The process has a controlling terminal.
    ///
    /// The corresponding C constant is `PROC_FLAG_CONTROLT`.
    @_alwaysEmitIntoClient
    public static var hasControllingTerminal: Flags { Flags(rawValue: _PROC_FLAG_CONTROLT) }

    /// A thread of the process has a working directory of its own.
    ///
    /// The corresponding C constant is `PROC_FLAG_THCWD`.
    @_alwaysEmitIntoClient
    public static var threadWorkingDirectory: Flags { Flags(rawValue: _PROC_FLAG_THCWD) }

    /// The process has changed its privileges since its last exec.
    ///
    /// The corresponding C constant is `PROC_FLAG_PSUGID`.
    @_alwaysEmitIntoClient
    public static var changedPrivileges: Flags { Flags(rawValue: _PROC_FLAG_PSUGID) }

    /// The process has called exec.
    ///
    /// The corresponding C constant is `PROC_FLAG_EXEC`.
    @_alwaysEmitIntoClient
    public static var execed: Flags { Flags(rawValue: _PROC_FLAG_EXEC) }
  }
}

@available(System 199, *)
extension ProcessID.BSDInfo.Status: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the status.
  @inline(never)
  public var description: String {
    switch self {
    case .creating: return "creating"
    case .running: return "running"
    case .sleeping: return "sleeping"
    case .stopped: return "stopped"
    case .zombie: return "zombie"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the status, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension ProcessID.BSDInfo.Flags: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the flags.
  @inline(never)
  public var description: String {
    let descriptions: [(Element, StaticString)] = [
      (.system, ".system"),
      (.traced, ".traced"),
      (.exiting, ".exiting"),
      (.parentWaiting, ".parentWaiting"),
      (.is64Bit, ".is64Bit"),
      (.sessionLeader, ".sessionLeader"),
      (.sessionHasTerminal, ".sessionHasTerminal"),
      (.hasControllingTerminal, ".hasControllingTerminal"),
      (.threadWorkingDirectory, ".threadWorkingDirectory"),
      (.changedPrivileges, ".changedPrivileges"),
      (.execed, ".execed"),
    ]
    return _buildDescription(descriptions)
  }

  /// A textual representation of the flags, suitable for debugging.
  public var debugDescription: String { self.description }
}

#endif // os(macOS)
