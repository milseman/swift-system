/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// libproc is only in the macOS SDK.
#if os(macOS)

// Must import here to use the C types in @_alwaysEmitIntoClient APIs.
import Darwin

@available(System 199, *)
extension CInterop {
  /// The C `proc_taskinfo` type,
  /// which describes a process's Mach task.
  public typealias ProcTaskInfo = proc_taskinfo
}

// The times use Duration, which needs a newer OS than System 199 means in
// the default build, so these declarations carry both.

@available(System 199, *)
@available(macOS 13.0, *)
extension ProcessID {
  /// Information about a process's Mach task,
  /// such as its memory, processor time, and threads.
  ///
  /// To get the information for a process,
  /// call ``ProcessID/taskInfo()``.
  ///
  /// The system reports processor times in Mach absolute time units,
  /// which aren't nanoseconds on every Mac.
  /// This type's properties convert them to `Duration` values.
  ///
  /// The corresponding C type is `struct proc_taskinfo`.
  /// - Note: Only available on macOS.
  @frozen
  public struct TaskInfo: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public let rawValue: CInterop.ProcTaskInfo

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.ProcTaskInfo) { self.rawValue = rawValue }
  }

  /// Returns information about the process's Mach task.
  ///
  /// Getting the information for a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidinfo`,
  /// with the `PROC_PIDTASKINFO` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func taskInfo() throws(Errno) -> TaskInfo {
    try _taskInfo().get()
  }

  @usableFromInline
  internal func _taskInfo() -> Result<TaskInfo, Errno> {
    var info = CInterop.ProcTaskInfo()
    let size = CInt(MemoryLayout<CInterop.ProcTaskInfo>.size)
    // proc_pidinfo returns the number of bytes it fills, or 0 on failure.
    let filled = withUnsafeMutableBytes(of: &info) { buffer in
      system_proc_pidinfo(rawValue, _PROC_PIDTASKINFO, 0, buffer.baseAddress!, size)
    }
    if filled == 0 { return .failure(.current) }
    // A partial structure isn't the information, and shouldn't happen.
    guard filled == size else { return .failure(.ioError) }
    return .success(TaskInfo(rawValue: info))
  }
}

@available(System 199, *)
@available(macOS 13.0, *)
extension ProcessID.TaskInfo {
  /// The size of the process's virtual address space, in bytes.
  ///
  /// The corresponding C field is `pti_virtual_size`.
  @_alwaysEmitIntoClient
  public var virtualSize: UInt64 { rawValue.pti_virtual_size }

  /// The number of bytes of the process's memory
  /// that are resident in physical memory.
  ///
  /// The corresponding C field is `pti_resident_size`.
  @_alwaysEmitIntoClient
  public var residentSize: UInt64 { rawValue.pti_resident_size }

  /// The processor time that the process's threads have spent in user mode,
  /// including threads that have exited.
  ///
  /// The corresponding C field is `pti_total_user`.
  @_alwaysEmitIntoClient
  public var totalUserTime: Duration {
    _duration(machAbsoluteTime: rawValue.pti_total_user)
  }

  /// The processor time that the kernel has spent on the process's behalf,
  /// including for threads that have exited.
  ///
  /// The corresponding C field is `pti_total_system`.
  @_alwaysEmitIntoClient
  public var totalSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.pti_total_system)
  }

  /// The processor time that the process's existing threads
  /// have spent in user mode.
  ///
  /// The corresponding C field is `pti_threads_user`.
  @_alwaysEmitIntoClient
  public var existingThreadsUserTime: Duration {
    _duration(machAbsoluteTime: rawValue.pti_threads_user)
  }

  /// The processor time that the kernel has spent
  /// on behalf of the process's existing threads.
  ///
  /// The corresponding C field is `pti_threads_system`.
  @_alwaysEmitIntoClient
  public var existingThreadsSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.pti_threads_system)
  }

  /// The default scheduling policy for the process's new threads,
  /// such as `POLICY_TIMESHARE`.
  ///
  /// The corresponding C field is `pti_policy`.
  @_alwaysEmitIntoClient
  public var policy: Int { Int(rawValue.pti_policy) }

  /// The number of page faults that the process has had.
  ///
  /// The corresponding C field is `pti_faults`.
  @_alwaysEmitIntoClient
  public var faults: Int { Int(rawValue.pti_faults) }

  /// The number of the process's page faults that read a page from storage.
  ///
  /// The corresponding C field is `pti_pageins`.
  @_alwaysEmitIntoClient
  public var pageIns: Int { Int(rawValue.pti_pageins) }

  /// The number of copy-on-write faults that the process has had.
  ///
  /// The corresponding C field is `pti_cow_faults`.
  @_alwaysEmitIntoClient
  public var copyOnWriteFaults: Int { Int(rawValue.pti_cow_faults) }

  /// The number of Mach messages that the process has sent.
  ///
  /// The corresponding C field is `pti_messages_sent`.
  @_alwaysEmitIntoClient
  public var messagesSent: Int { Int(rawValue.pti_messages_sent) }

  /// The number of Mach messages that the process has received.
  ///
  /// The corresponding C field is `pti_messages_received`.
  @_alwaysEmitIntoClient
  public var messagesReceived: Int { Int(rawValue.pti_messages_received) }

  /// The number of Mach traps that the process has made.
  ///
  /// The corresponding C field is `pti_syscalls_mach`.
  @_alwaysEmitIntoClient
  public var machSystemCalls: Int { Int(rawValue.pti_syscalls_mach) }

  /// The number of BSD system calls that the process has made.
  ///
  /// The corresponding C field is `pti_syscalls_unix`.
  @_alwaysEmitIntoClient
  public var unixSystemCalls: Int { Int(rawValue.pti_syscalls_unix) }

  /// The number of context switches that the process has had.
  ///
  /// The corresponding C field is `pti_csw`.
  @_alwaysEmitIntoClient
  public var contextSwitches: Int { Int(rawValue.pti_csw) }

  /// The number of threads in the process.
  ///
  /// The corresponding C field is `pti_threadnum`.
  @_alwaysEmitIntoClient
  public var threadCount: Int { Int(rawValue.pti_threadnum) }

  /// The number of the process's threads that are running.
  ///
  /// The corresponding C field is `pti_numrunning`.
  @_alwaysEmitIntoClient
  public var runningThreadCount: Int { Int(rawValue.pti_numrunning) }

  /// The process's scheduling priority.
  ///
  /// The corresponding C field is `pti_priority`.
  @_alwaysEmitIntoClient
  public var priority: Int { Int(rawValue.pti_priority) }
}

#endif // os(macOS)
