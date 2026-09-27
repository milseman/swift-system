/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The names of common kernel state variables, each typed by its value.
// Each name's type is the size that the kernel reports for it.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: - Hardware

@available(System 199, *)
extension SystemControl.Name where Value == Int32 {
  /// The number of processors.
  ///
  /// The system deprecates this variable in favor of
  /// ``logicalProcessorCount``, ``maxLogicalProcessorCount``,
  /// ``physicalProcessorCount``, and ``maxPhysicalProcessorCount``.
  ///
  /// The corresponding variable is `hw.ncpu`.
  @_alwaysEmitIntoClient
  public static var processorCount: Self { Self("hw.ncpu") }

  /// The number of processors that are available now.
  ///
  /// The corresponding variable is `hw.activecpu`.
  @_alwaysEmitIntoClient
  public static var activeProcessorCount: Self { Self("hw.activecpu") }

  /// The number of logical processors available
  /// in the current power management mode.
  ///
  /// The corresponding variable is `hw.logicalcpu`.
  @_alwaysEmitIntoClient
  public static var logicalProcessorCount: Self { Self("hw.logicalcpu") }

  /// The most logical processors that could be available since boot.
  ///
  /// The corresponding variable is `hw.logicalcpu_max`.
  @_alwaysEmitIntoClient
  public static var maxLogicalProcessorCount: Self { Self("hw.logicalcpu_max") }

  /// The number of physical processors available
  /// in the current power management mode.
  ///
  /// The corresponding variable is `hw.physicalcpu`.
  @_alwaysEmitIntoClient
  public static var physicalProcessorCount: Self { Self("hw.physicalcpu") }

  /// The most physical processors that could be available since boot.
  ///
  /// The corresponding variable is `hw.physicalcpu_max`.
  @_alwaysEmitIntoClient
  public static var maxPhysicalProcessorCount: Self { Self("hw.physicalcpu_max") }

  /// The number of processor packages.
  ///
  /// The corresponding variable is `hw.packages`.
  @_alwaysEmitIntoClient
  public static var processorPackageCount: Self { Self("hw.packages") }

  /// The byte order: 1234 for little-endian, or 4321 for big-endian.
  ///
  /// The corresponding variable is `hw.byteorder`.
  @_alwaysEmitIntoClient
  public static var byteOrder: Self { Self("hw.byteorder") }

  /// The processor type, a Mach-O `cpu_type_t`, such as `CPU_TYPE_ARM64`.
  ///
  /// The corresponding variable is `hw.cputype`.
  @_alwaysEmitIntoClient
  public static var cpuType: Self { Self("hw.cputype") }

  /// The processor subtype, a Mach-O `cpu_subtype_t`.
  ///
  /// The corresponding variable is `hw.cpusubtype`.
  @_alwaysEmitIntoClient
  public static var cpuSubtype: Self { Self("hw.cpusubtype") }

  /// Whether the processor can run 64-bit code: 1 if so, and 0 if not.
  ///
  /// The corresponding variable is `hw.cpu64bit_capable`.
  @_alwaysEmitIntoClient
  public static var is64BitCapable: Self { Self("hw.cpu64bit_capable") }

  /// Whether the process runs translated by Rosetta:
  /// 1 if so, and 0 if not.
  ///
  /// A system that can't translate, such as one on an Intel processor,
  /// has no such variable,
  /// and reading it throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding variable is `sysctl.proc_translated`.
  @_alwaysEmitIntoClient
  public static var isTranslated: Self { Self("sysctl.proc_translated") }
}

@available(System 199, *)
extension SystemControl.Name where Value == UInt32 {
  /// The processor family, such as `CPUFAMILY_ARM_FIRESTORM_ICESTORM`.
  ///
  /// The corresponding variable is `hw.cpufamily`.
  @_alwaysEmitIntoClient
  public static var cpuFamily: Self { Self("hw.cpufamily") }
}

@available(System 199, *)
extension SystemControl.Name where Value == UInt64 {
  /// The number of bytes of physical memory.
  ///
  /// The corresponding variable is `hw.memsize`.
  @_alwaysEmitIntoClient
  public static var memorySize: Self { Self("hw.memsize") }
}

@available(System 199, *)
extension SystemControl.Name where Value == Int64 {
  /// The number of bytes in a page of virtual memory.
  ///
  /// The corresponding variable is `hw.pagesize`.
  @_alwaysEmitIntoClient
  public static var pageSize: Self { Self("hw.pagesize") }

  /// The number of bytes in a cache line.
  ///
  /// The corresponding variable is `hw.cachelinesize`.
  @_alwaysEmitIntoClient
  public static var cacheLineSize: Self { Self("hw.cachelinesize") }

  /// The number of bytes in each processor's level 1 data cache.
  ///
  /// The corresponding variable is `hw.l1dcachesize`.
  @_alwaysEmitIntoClient
  public static var level1DataCacheSize: Self { Self("hw.l1dcachesize") }

  /// The number of bytes in each processor's level 1 instruction cache.
  ///
  /// The corresponding variable is `hw.l1icachesize`.
  @_alwaysEmitIntoClient
  public static var level1InstructionCacheSize: Self { Self("hw.l1icachesize") }

  /// The number of bytes in the level 2 cache.
  ///
  /// The corresponding variable is `hw.l2cachesize`.
  @_alwaysEmitIntoClient
  public static var level2CacheSize: Self { Self("hw.l2cachesize") }

  /// The frequency of the timebase that Mach absolute time counts,
  /// in hertz.
  ///
  /// The corresponding variable is `hw.tbfrequency`.
  @_alwaysEmitIntoClient
  public static var timebaseFrequency: Self { Self("hw.tbfrequency") }
}

@available(System 199, *)
extension SystemControl.Name where Value == String {
  /// The machine's architecture, such as `arm64` or `x86_64`.
  ///
  /// The corresponding variable is `hw.machine`.
  @_alwaysEmitIntoClient
  public static var machine: Self { Self("hw.machine") }

  /// The machine's model identifier, such as `MacBookPro18,2`.
  ///
  /// The corresponding variable is `hw.model`.
  @_alwaysEmitIntoClient
  public static var model: Self { Self("hw.model") }

  /// The processor's name, such as `Apple M1 Max`.
  ///
  /// The corresponding variable is `machdep.cpu.brand_string`.
  @_alwaysEmitIntoClient
  public static var cpuBrand: Self { Self("machdep.cpu.brand_string") }
}

// MARK: - Kernel

@available(System 199, *)
extension SystemControl.Name where Value == String {
  /// The operating system's type, `Darwin`.
  ///
  /// The corresponding variable is `kern.ostype`.
  @_alwaysEmitIntoClient
  public static var osType: Self { Self("kern.ostype") }

  /// The kernel's release, such as `25.3.0`.
  ///
  /// The corresponding variable is `kern.osrelease`.
  @_alwaysEmitIntoClient
  public static var osRelease: Self { Self("kern.osrelease") }

  /// The operating system's build, such as `25D125`.
  ///
  /// The corresponding variable is `kern.osversion`.
  @_alwaysEmitIntoClient
  public static var osVersion: Self { Self("kern.osversion") }

  /// The operating system's product version, such as `26.3`.
  ///
  /// The corresponding variable is `kern.osproductversion`.
  @_alwaysEmitIntoClient
  public static var osProductVersion: Self { Self("kern.osproductversion") }

  /// The kernel's full version string.
  ///
  /// The corresponding variable is `kern.version`.
  @_alwaysEmitIntoClient
  public static var kernelVersion: Self { Self("kern.version") }

  /// The kernel's UUID.
  ///
  /// The corresponding variable is `kern.uuid`.
  @_alwaysEmitIntoClient
  public static var kernelUUID: Self { Self("kern.uuid") }

  /// A UUID that identifies the current boot of the system.
  ///
  /// The corresponding variable is `kern.bootsessionuuid`.
  @_alwaysEmitIntoClient
  public static var bootSessionUUID: Self { Self("kern.bootsessionuuid") }

  /// The machine's host name, which a privileged process can change.
  ///
  /// The corresponding variable is `kern.hostname`.
  @_alwaysEmitIntoClient
  public static var hostName: Self { Self("kern.hostname") }
}

@available(System 199, *)
extension SystemControl.Name where Value == Int32 {
  /// The kernel's revision number.
  ///
  /// The corresponding variable is `kern.osrevision`.
  @_alwaysEmitIntoClient
  public static var osRevision: Self { Self("kern.osrevision") }

  /// The most files that the system can have open at once.
  ///
  /// The corresponding variable is `kern.maxfiles`.
  @_alwaysEmitIntoClient
  public static var maxFiles: Self { Self("kern.maxfiles") }

  /// The most files that a process can have open at once,
  /// unless its effective user is the superuser.
  ///
  /// The corresponding variable is `kern.maxfilesperproc`.
  @_alwaysEmitIntoClient
  public static var maxFilesPerProcess: Self { Self("kern.maxfilesperproc") }

  /// The most processes that the system can run at once.
  ///
  /// The corresponding variable is `kern.maxproc`.
  @_alwaysEmitIntoClient
  public static var maxProcesses: Self { Self("kern.maxproc") }

  /// The most processes that a user other than the superuser
  /// can run at once.
  ///
  /// The corresponding variable is `kern.maxprocperuid`.
  @_alwaysEmitIntoClient
  public static var maxProcessesPerUser: Self { Self("kern.maxprocperuid") }

  /// The most bytes of arguments and environment
  /// that a new process image can receive, as through `execve`.
  ///
  /// The corresponding variable is `kern.argmax`.
  @_alwaysEmitIntoClient
  public static var maxArgumentBytes: Self { Self("kern.argmax") }

  /// The most supplementary groups that a process can have.
  ///
  /// The corresponding variable is `kern.ngroups`.
  @_alwaysEmitIntoClient
  public static var maxSupplementaryGroups: Self { Self("kern.ngroups") }

  /// The version of POSIX.1 that the system attempts to comply with.
  ///
  /// The corresponding variable is `kern.posix1version`.
  @_alwaysEmitIntoClient
  public static var posixVersion: Self { Self("kern.posix1version") }

  /// The system's security level,
  /// which a privileged process can raise but not lower.
  ///
  /// The corresponding variable is `kern.securelevel`.
  @_alwaysEmitIntoClient
  public static var securityLevel: Self { Self("kern.securelevel") }
}

@available(System 199, *)
extension SystemControl.Name where Value == timeval {
  /// The time that the system booted.
  ///
  /// The corresponding variable is `kern.boottime`.
  @_alwaysEmitIntoClient
  public static var bootTime: Self { Self("kern.boottime") }

  /// The time that the system last went to sleep.
  ///
  /// The corresponding variable is `kern.sleeptime`.
  @_alwaysEmitIntoClient
  public static var sleepTime: Self { Self("kern.sleeptime") }

  /// The time that the system last woke from sleep.
  ///
  /// The corresponding variable is `kern.waketime`.
  @_alwaysEmitIntoClient
  public static var wakeTime: Self { Self("kern.waketime") }
}

@available(System 199, *)
extension SystemControl.Name where Value == clockinfo {
  /// The rates of the system's clocks.
  ///
  /// The corresponding variable is `kern.clockrate`.
  @_alwaysEmitIntoClient
  public static var clockRate: Self { Self("kern.clockrate") }
}

// MARK: - Virtual memory

@available(System 199, *)
extension SystemControl.Name where Value == loadavg {
  /// The system's load averages over the last 1, 5, and 15 minutes,
  /// in fixed point with the scale in the structure's `fscale`.
  ///
  /// The corresponding variable is `vm.loadavg`.
  @_alwaysEmitIntoClient
  public static var loadAverage: Self { Self("vm.loadavg") }
}

@available(System 199, *)
extension SystemControl.Name where Value == xsw_usage {
  /// The system's use of swap space.
  ///
  /// The corresponding variable is `vm.swapusage`.
  @_alwaysEmitIntoClient
  public static var swapUsage: Self { Self("vm.swapusage") }
}

// MARK: - Processes

@available(System 199, *)
extension SystemControl.Name where Value == kinfo_proc {
  /// The kernel's information about a process,
  /// such as its IDs, credentials, and status.
  ///
  /// If there's no such process, reading the variable throws
  /// ``Errno/invalidArgument``.
  ///
  /// The corresponding variable is `kern.proc.pid`,
  /// with the process ID as the identifier's last component.
  @_alwaysEmitIntoClient
  public static func process(_ id: ProcessID) -> Self {
    Self(identifier: [_CTL_KERN, _KERN_PROC, _KERN_PROC_PID, id.rawValue])
  }
}

@available(System 199, *)
extension SystemControl.Name where Value == [kinfo_proc] {
  /// The kernel's information about every process.
  ///
  /// The corresponding variable is `kern.proc.all`.
  @_alwaysEmitIntoClient
  public static var allProcesses: Self {
    Self(identifier: [_CTL_KERN, _KERN_PROC, _KERN_PROC_ALL])
  }

  /// The kernel's information about the processes in a process group.
  ///
  /// The corresponding variable is `kern.proc.pgrp`,
  /// with the group's ID as the identifier's last component.
  @_alwaysEmitIntoClient
  public static func processes(inGroup group: ProcessID) -> Self {
    Self(identifier: [_CTL_KERN, _KERN_PROC, _KERN_PROC_PGRP, group.rawValue])
  }

  /// The kernel's information about the processes
  /// whose effective user is a given user.
  ///
  /// The corresponding variable is `kern.proc.uid`,
  /// with the user's ID as the identifier's last component.
  @_alwaysEmitIntoClient
  public static func processes(ofUser user: UserID) -> Self {
    Self(identifier: [_CTL_KERN, _KERN_PROC, _KERN_PROC_UID, CInt(bitPattern: user.rawValue)])
  }

  /// The kernel's information about the processes
  /// whose real user is a given user.
  ///
  /// The corresponding variable is `kern.proc.ruid`,
  /// with the user's ID as the identifier's last component.
  @_alwaysEmitIntoClient
  public static func processes(ofRealUser user: UserID) -> Self {
    Self(identifier: [_CTL_KERN, _KERN_PROC, _KERN_PROC_RUID, CInt(bitPattern: user.rawValue)])
  }
}

@available(System 199, *)
extension SystemControl.Name where Value == [UInt8] {
  /// A process's arguments and environment, as the process began.
  ///
  /// The value begins with the argument count, a C `int`,
  /// followed by the path the process was executed with,
  /// and then its arguments and its environment,
  /// each a null-terminated string, with padding between them.
  /// Reading another user's process requires privileges.
  ///
  /// The corresponding variable is `kern.procargs2`,
  /// with the process ID as the identifier's last component.
  @_alwaysEmitIntoClient
  public static func processArguments(_ id: ProcessID) -> Self {
    Self(identifier: [_CTL_KERN, _KERN_PROCARGS2, id.rawValue])
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
