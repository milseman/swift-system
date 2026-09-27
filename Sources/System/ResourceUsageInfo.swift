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
  /// The C `rusage_info_v6` type,
  /// which describes a process's use of resources.
  public typealias RUsageInfo = rusage_info_v6
}

// The times use Duration, which needs a newer OS than System 199 means in
// the default build, so these declarations carry both.

@available(System 199, *)
@available(macOS 13.0, *)
extension ProcessID {
  /// Information about a process's use of resources,
  /// such as processor time and memory.
  ///
  /// To get the information for a process,
  /// call ``ProcessID/resourceUsageInfo()``.
  ///
  /// The system reports processor times in Mach absolute time units,
  /// which aren't nanoseconds on every Mac.
  /// This type's properties convert them to `Duration` values.
  ///
  /// The corresponding C type is `struct rusage_info_v6`.
  /// - Note: Only available on macOS.
  @frozen
  public struct ResourceUsageInfo: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public let rawValue: CInterop.RUsageInfo

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.RUsageInfo) { self.rawValue = rawValue }
  }

  /// Returns information about the process's use of resources.
  ///
  /// Getting the information for a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pid_rusage`,
  /// with the `RUSAGE_INFO_V6` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func resourceUsageInfo() throws(Errno) -> ResourceUsageInfo {
    try _resourceUsageInfo().get()
  }

  @usableFromInline
  internal func _resourceUsageInfo() -> Result<ResourceUsageInfo, Errno> {
    var info = CInterop.RUsageInfo()
    return withUnsafeMutableBytes(of: &info) { buffer in
      nothingOrErrno(retryOnInterrupt: false) {
        system_proc_pid_rusage(rawValue, _RUSAGE_INFO_V6, buffer.baseAddress!)
      }
    }.map { ResourceUsageInfo(rawValue: info) }
  }
}

@available(System 199, *)
@available(macOS 13.0, *)
extension ProcessID.ResourceUsageInfo {
  /// The UUID of the process's main executable.
  ///
  /// The corresponding C field is `ri_uuid`.
  @_alwaysEmitIntoClient
  public var executableUUID: uuid_t { rawValue.ri_uuid }

  /// The processor time that the process has spent in user mode.
  ///
  /// The corresponding C field is `ri_user_time`.
  @_alwaysEmitIntoClient
  public var userTime: Duration { _duration(machAbsoluteTime: rawValue.ri_user_time) }

  /// The processor time that the kernel has spent on the process's behalf.
  ///
  /// The corresponding C field is `ri_system_time`.
  @_alwaysEmitIntoClient
  public var systemTime: Duration { _duration(machAbsoluteTime: rawValue.ri_system_time) }

  /// The number of times that the process woke
  /// an idle processor package.
  ///
  /// The corresponding C field is `ri_pkg_idle_wkups`.
  @_alwaysEmitIntoClient
  public var packageIdleWakeups: UInt64 { rawValue.ri_pkg_idle_wkups }

  /// The number of times that the process woke an idle processor.
  ///
  /// The corresponding C field is `ri_interrupt_wkups`.
  @_alwaysEmitIntoClient
  public var interruptWakeups: UInt64 { rawValue.ri_interrupt_wkups }

  /// The number of pages that the system has read into memory
  /// for the process.
  ///
  /// The corresponding C field is `ri_pageins`.
  @_alwaysEmitIntoClient
  public var pageIns: UInt64 { rawValue.ri_pageins }

  /// The number of bytes of the process's memory that are wired,
  /// which the system can't page out.
  ///
  /// The corresponding C field is `ri_wired_size`.
  @_alwaysEmitIntoClient
  public var wiredSize: UInt64 { rawValue.ri_wired_size }

  /// The number of bytes of the process's memory
  /// that are resident in physical memory.
  ///
  /// The corresponding C field is `ri_resident_size`.
  @_alwaysEmitIntoClient
  public var residentSize: UInt64 { rawValue.ri_resident_size }

  /// The process's physical footprint:
  /// the number of bytes of memory that the system attributes to it,
  /// which the system compares with the process's memory limit.
  ///
  /// The corresponding C field is `ri_phys_footprint`.
  @_alwaysEmitIntoClient
  public var physicalFootprint: UInt64 { rawValue.ri_phys_footprint }

  /// The time that the process started,
  /// in the units that `mach_absolute_time` returns.
  ///
  /// The corresponding C field is `ri_proc_start_abstime`.
  @_alwaysEmitIntoClient
  public var startAbsoluteTime: UInt64 { rawValue.ri_proc_start_abstime }

  /// The time that the process exited,
  /// in the units that `mach_absolute_time` returns,
  /// or `0` if it hasn't.
  ///
  /// The corresponding C field is `ri_proc_exit_abstime`.
  @_alwaysEmitIntoClient
  public var exitAbsoluteTime: UInt64 { rawValue.ri_proc_exit_abstime }

  /// The processor time that the process's children have spent
  /// in user mode, counting children that have exited
  /// and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_user_time`.
  @_alwaysEmitIntoClient
  public var childUserTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_child_user_time)
  }

  /// The processor time that the kernel has spent
  /// on behalf of the process's children, counting children that have exited
  /// and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_system_time`.
  @_alwaysEmitIntoClient
  public var childSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_child_system_time)
  }

  /// The number of times that the process's children
  /// woke an idle processor package,
  /// counting children that have exited and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_pkg_idle_wkups`.
  @_alwaysEmitIntoClient
  public var childPackageIdleWakeups: UInt64 { rawValue.ri_child_pkg_idle_wkups }

  /// The number of times that the process's children
  /// woke an idle processor,
  /// counting children that have exited and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_interrupt_wkups`.
  @_alwaysEmitIntoClient
  public var childInterruptWakeups: UInt64 { rawValue.ri_child_interrupt_wkups }

  /// The number of pages that the system has read into memory
  /// for the process's children,
  /// counting children that have exited and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_pageins`.
  @_alwaysEmitIntoClient
  public var childPageIns: UInt64 { rawValue.ri_child_pageins }

  /// The total time from start to exit of the process's children,
  /// counting children that have exited and that the process has waited for.
  ///
  /// The corresponding C field is `ri_child_elapsed_abstime`.
  @_alwaysEmitIntoClient
  public var childElapsedTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_child_elapsed_abstime)
  }

  /// The number of bytes that the process has read from storage devices.
  ///
  /// The corresponding C field is `ri_diskio_bytesread`.
  @_alwaysEmitIntoClient
  public var diskBytesRead: UInt64 { rawValue.ri_diskio_bytesread }

  /// The number of bytes that the process has written to storage devices.
  ///
  /// The corresponding C field is `ri_diskio_byteswritten`.
  @_alwaysEmitIntoClient
  public var diskBytesWritten: UInt64 { rawValue.ri_diskio_byteswritten }

  /// The processor time that the process has spent
  /// at the default quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_default`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSDefault: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_default)
  }

  /// The processor time that the process has spent
  /// at the maintenance quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_maintenance`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSMaintenance: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_maintenance)
  }

  /// The processor time that the process has spent
  /// at the background quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_background`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSBackground: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_background)
  }

  /// The processor time that the process has spent
  /// at the utility quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_utility`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSUtility: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_utility)
  }

  /// The processor time that the process has spent
  /// without a quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_legacy`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSLegacy: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_legacy)
  }

  /// The processor time that the process has spent
  /// at the user-initiated quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_user_initiated`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSUserInitiated: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_user_initiated)
  }

  /// The processor time that the process has spent
  /// at the user-interactive quality of service.
  ///
  /// The corresponding C field is `ri_cpu_time_qos_user_interactive`.
  @_alwaysEmitIntoClient
  public var cpuTimeQoSUserInteractive: Duration {
    _duration(machAbsoluteTime: rawValue.ri_cpu_time_qos_user_interactive)
  }

  /// The processor time that other processes have spent
  /// doing work on this process's behalf.
  ///
  /// The corresponding C field is `ri_billed_system_time`.
  @_alwaysEmitIntoClient
  public var billedSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_billed_system_time)
  }

  /// The processor time that this process has spent
  /// doing work on other processes' behalf.
  ///
  /// The corresponding C field is `ri_serviced_system_time`.
  @_alwaysEmitIntoClient
  public var servicedSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_serviced_system_time)
  }

  /// The number of bytes that the process has written to files,
  /// whether or not they've reached storage.
  ///
  /// The corresponding C field is `ri_logical_writes`.
  @_alwaysEmitIntoClient
  public var logicalWrites: UInt64 { rawValue.ri_logical_writes }

  /// The largest physical footprint that the process has had.
  ///
  /// The corresponding C field is `ri_lifetime_max_phys_footprint`.
  @_alwaysEmitIntoClient
  public var lifetimeMaxPhysicalFootprint: UInt64 {
    rawValue.ri_lifetime_max_phys_footprint
  }

  /// The number of instructions that the process has retired.
  ///
  /// The corresponding C field is `ri_instructions`.
  @_alwaysEmitIntoClient
  public var instructions: UInt64 { rawValue.ri_instructions }

  /// The number of processor cycles that the process has used.
  ///
  /// The corresponding C field is `ri_cycles`.
  @_alwaysEmitIntoClient
  public var cycles: UInt64 { rawValue.ri_cycles }

  /// The energy that other processes have used
  /// doing work on this process's behalf, in nanojoules.
  ///
  /// The corresponding C field is `ri_billed_energy`.
  @_alwaysEmitIntoClient
  public var billedEnergy: UInt64 { rawValue.ri_billed_energy }

  /// The energy that this process has used
  /// doing work on other processes' behalf, in nanojoules.
  ///
  /// The corresponding C field is `ri_serviced_energy`.
  @_alwaysEmitIntoClient
  public var servicedEnergy: UInt64 { rawValue.ri_serviced_energy }

  /// The largest physical footprint that the process has had
  /// since the interval was last reset.
  ///
  /// The corresponding C field is `ri_interval_max_phys_footprint`.
  @_alwaysEmitIntoClient
  public var intervalMaxPhysicalFootprint: UInt64 {
    rawValue.ri_interval_max_phys_footprint
  }

  /// The time that the process's threads have been runnable,
  /// whether running or waiting for a processor.
  ///
  /// The corresponding C field is `ri_runnable_time`.
  @_alwaysEmitIntoClient
  public var runnableTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_runnable_time)
  }

  /// The part of ``userTime`` that the process has spent
  /// on performance cores.
  ///
  /// The corresponding C field is `ri_user_ptime`.
  @_alwaysEmitIntoClient
  public var performanceCoreUserTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_user_ptime)
  }

  /// The part of ``systemTime`` that the kernel has spent
  /// on performance cores.
  ///
  /// The corresponding C field is `ri_system_ptime`.
  @_alwaysEmitIntoClient
  public var performanceCoreSystemTime: Duration {
    _duration(machAbsoluteTime: rawValue.ri_system_ptime)
  }

  /// The part of ``instructions`` that the process has retired
  /// on performance cores.
  ///
  /// The corresponding C field is `ri_pinstructions`.
  @_alwaysEmitIntoClient
  public var performanceCoreInstructions: UInt64 { rawValue.ri_pinstructions }

  /// The part of ``cycles`` that the process has used
  /// on performance cores.
  ///
  /// The corresponding C field is `ri_pcycles`.
  @_alwaysEmitIntoClient
  public var performanceCoreCycles: UInt64 { rawValue.ri_pcycles }

  /// The energy that the process has used, in nanojoules.
  ///
  /// The corresponding C field is `ri_energy_nj`.
  @_alwaysEmitIntoClient
  public var energy: UInt64 { rawValue.ri_energy_nj }

  /// The part of ``energy`` that the process has used
  /// on performance cores, in nanojoules.
  ///
  /// The corresponding C field is `ri_penergy_nj`.
  @_alwaysEmitIntoClient
  public var performanceCoreEnergy: UInt64 { rawValue.ri_penergy_nj }
}

// Converts Mach absolute time units, which are nanoseconds on Intel
// processors but not on Apple silicon, saturating rather than overflowing.
@available(System 199, *)
@available(macOS 13.0, *)
@usableFromInline
internal func _duration(machAbsoluteTime ticks: UInt64) -> Duration {
  Mach.Timebase.current.duration(ofTicks: ticks)
}

#endif // os(macOS)
