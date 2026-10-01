/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Processors and memory pages

@available(System 199, *)
extension Win32 {
  /// A processor architecture.
  ///
  /// The corresponding C type is the `WORD` of `SYSTEM_INFO`'s
  /// `wProcessorArchitecture`.
  @frozen
  public struct ProcessorArchitecture: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: WORD

    /// Creates a strongly-typed architecture from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: WORD) { self.rawValue = rawValue }

    /// 32-bit x86.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_INTEL`.
    @_alwaysEmitIntoClient
    public static var x86: ProcessorArchitecture { ProcessorArchitecture(rawValue: 0) }

    /// 32-bit ARM.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_ARM`.
    @_alwaysEmitIntoClient
    public static var arm: ProcessorArchitecture { ProcessorArchitecture(rawValue: 5) }

    /// Intel Itanium.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_IA64`.
    @_alwaysEmitIntoClient
    public static var ia64: ProcessorArchitecture { ProcessorArchitecture(rawValue: 6) }

    /// x64, which AMD and Intel processors implement.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_AMD64`.
    @_alwaysEmitIntoClient
    public static var x64: ProcessorArchitecture { ProcessorArchitecture(rawValue: 9) }

    /// 64-bit ARM.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_ARM64`.
    @_alwaysEmitIntoClient
    public static var arm64: ProcessorArchitecture { ProcessorArchitecture(rawValue: 12) }

    /// An architecture Windows doesn't name.
    ///
    /// The corresponding C constant is `PROCESSOR_ARCHITECTURE_UNKNOWN`.
    @_alwaysEmitIntoClient
    public static var unknown: ProcessorArchitecture { ProcessorArchitecture(rawValue: 0xFFFF) }
  }

  /// The system's processor architecture, page size, and processors.
  ///
  /// The processor count and mask cover the calling thread's processor
  /// group, which holds at most 64 processors; ``activeProcessorCount()``
  /// counts every group's.
  ///
  /// The corresponding C type is `SYSTEM_INFO`.
  @frozen
  public struct SystemInformation: RawRepresentable, @unchecked Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: SYSTEM_INFO

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: SYSTEM_INFO) { self.rawValue = rawValue }

    /// The processor architecture.
    ///
    /// The corresponding C field is `wProcessorArchitecture`.
    @_alwaysEmitIntoClient
    public var processorArchitecture: Win32.ProcessorArchitecture {
      Win32.ProcessorArchitecture(rawValue: rawValue.wProcessorArchitecture)
    }

    /// The size of a page of virtual memory, in bytes.
    ///
    /// The corresponding C field is `dwPageSize`.
    @_alwaysEmitIntoClient
    public var pageSize: Int { Int(rawValue.dwPageSize) }

    /// The granularity of the addresses at which virtual memory can be
    /// allocated, in bytes, such as 64 KiB.
    ///
    /// The corresponding C field is `dwAllocationGranularity`.
    @_alwaysEmitIntoClient
    public var allocationGranularity: Int { Int(rawValue.dwAllocationGranularity) }

    /// The lowest address that applications and libraries can use.
    ///
    /// The corresponding C field is `lpMinimumApplicationAddress`.
    @_alwaysEmitIntoClient
    public var minimumApplicationAddress: UInt {
      UInt(bitPattern: rawValue.lpMinimumApplicationAddress)
    }

    /// The highest address that applications and libraries can use.
    ///
    /// The corresponding C field is `lpMaximumApplicationAddress`.
    @_alwaysEmitIntoClient
    public var maximumApplicationAddress: UInt {
      UInt(bitPattern: rawValue.lpMaximumApplicationAddress)
    }

    /// The processors of the calling thread's group that the system has
    /// configured, a bit for each.
    ///
    /// The corresponding C field is `dwActiveProcessorMask`.
    @_alwaysEmitIntoClient
    public var activeProcessorMask: UInt { UInt(rawValue.dwActiveProcessorMask) }

    /// The number of logical processors in the calling thread's group.
    ///
    /// The corresponding C field is `dwNumberOfProcessors`.
    @_alwaysEmitIntoClient
    public var processorCount: Int { Int(rawValue.dwNumberOfProcessors) }

    /// The processor's level, which depends on its architecture: for x86
    /// and x64, its family.
    ///
    /// The corresponding C field is `wProcessorLevel`.
    @_alwaysEmitIntoClient
    public var processorLevel: Int { Int(rawValue.wProcessorLevel) }

    /// The processor's revision, which depends on its architecture: for
    /// x86 and x64, its model and stepping.
    ///
    /// The corresponding C field is `wProcessorRevision`.
    @_alwaysEmitIntoClient
    public var processorRevision: Int { Int(rawValue.wProcessorRevision) }
  }

  /// The system's processors and memory pages, as the calling process sees
  /// them.
  ///
  /// A process that Windows runs under emulation, such as an x86 process on
  /// an x64 or ARM64 system, sees the emulated architecture; see
  /// ``nativeSystemInformation()``.
  ///
  /// The corresponding C function is `GetSystemInfo`.
  @_alwaysEmitIntoClient
  public static func systemInformation() -> SystemInformation {
    SystemInformation(rawValue: _systemInformation(native: false))
  }

  /// The system's processors and memory pages, as a process of its native
  /// architecture sees them.
  ///
  /// The corresponding C function is `GetNativeSystemInfo`.
  @_alwaysEmitIntoClient
  public static func nativeSystemInformation() -> SystemInformation {
    SystemInformation(rawValue: _systemInformation(native: true))
  }

  /// The number of active logical processors, in every processor group.
  ///
  /// The corresponding C function is `GetActiveProcessorCount`, with
  /// `ALL_PROCESSOR_GROUPS`.
  @_alwaysEmitIntoClient
  public static func activeProcessorCount() -> Int {
    _activeProcessorCount()
  }
}

// MARK: - Logical processors

@available(System 199, *)
extension Win32 {
  /// How a set of logical processors is related.
  ///
  /// The corresponding C type is `LOGICAL_PROCESSOR_RELATIONSHIP`.
  @frozen
  public struct ProcessorRelationship: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed relationship from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The processors share a core: they're its hardware threads.
    ///
    /// The corresponding C constant is `RelationProcessorCore`.
    @_alwaysEmitIntoClient
    public static var processorCore: ProcessorRelationship { ProcessorRelationship(rawValue: 0) }

    /// The processors are a NUMA node.
    ///
    /// The corresponding C constant is `RelationNumaNode`.
    @_alwaysEmitIntoClient
    public static var numaNode: ProcessorRelationship { ProcessorRelationship(rawValue: 1) }

    /// The processors share a cache, which the information's
    /// `rawValue.Cache` describes.
    ///
    /// The corresponding C constant is `RelationCache`.
    @_alwaysEmitIntoClient
    public static var cache: ProcessorRelationship { ProcessorRelationship(rawValue: 2) }

    /// The processors share a package: a physical processor.
    ///
    /// The corresponding C constant is `RelationProcessorPackage`.
    @_alwaysEmitIntoClient
    public static var processorPackage: ProcessorRelationship {
      ProcessorRelationship(rawValue: 3)
    }
  }

  /// A set of logical processors and how they're related, such as the
  /// hardware threads of one core.
  ///
  /// The corresponding C type is `SYSTEM_LOGICAL_PROCESSOR_INFORMATION`.
  @frozen
  public struct LogicalProcessorInformation: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: SYSTEM_LOGICAL_PROCESSOR_INFORMATION

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: SYSTEM_LOGICAL_PROCESSOR_INFORMATION) { self.rawValue = rawValue }

    /// The processors, a bit for each.
    ///
    /// The corresponding C field is `ProcessorMask`.
    @_alwaysEmitIntoClient
    public var processorMask: UInt { UInt(rawValue.ProcessorMask) }

    /// How the processors are related.
    ///
    /// The corresponding C field is `Relationship`.
    @_alwaysEmitIntoClient
    public var relationship: Win32.ProcessorRelationship {
      Win32.ProcessorRelationship(rawValue: CInt(rawValue.Relationship.rawValue))
    }
  }

  /// How the logical processors of the calling thread's processor group
  /// are related: one entry for each core, NUMA node, cache, and package.
  ///
  /// The corresponding C function is `GetLogicalProcessorInformation`.
  @_alwaysEmitIntoClient
  public static func logicalProcessorInformation() throws(Win32.Error) -> [LogicalProcessorInformation] {
    try _logicalProcessorInformation().get().map(LogicalProcessorInformation.init(rawValue:))
  }
}

// MARK: - Memory

@available(System 199, *)
extension Win32 {
  /// The size of the physical memory installed, in bytes, as the
  /// firmware's SMBIOS tables report it.
  ///
  /// This can be more than the memory Windows can use, which excludes what
  /// the firmware and devices reserve.
  ///
  /// The corresponding C function is `GetPhysicallyInstalledSystemMemory`,
  /// which reports kilobytes.
  @_alwaysEmitIntoClient
  public static func installedMemory() throws(Win32.Error) -> UInt64 {
    try _installedMemory().get()
  }
}

// MARK: - The computer's name

@available(System 199, *)
extension Win32 {
  /// Which of a computer's names to get.
  ///
  /// The corresponding C type is `COMPUTER_NAME_FORMAT`.
  @frozen
  public struct ComputerNameFormat: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed format from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The NetBIOS name, of up to 15 characters.
    ///
    /// The corresponding C constant is `ComputerNameNetBIOS`.
    @_alwaysEmitIntoClient
    public static var netBIOS: ComputerNameFormat { ComputerNameFormat(rawValue: 0) }

    /// The DNS host name, without a domain.
    ///
    /// The corresponding C constant is `ComputerNameDnsHostname`.
    @_alwaysEmitIntoClient
    public static var dnsHostName: ComputerNameFormat { ComputerNameFormat(rawValue: 1) }

    /// The DNS domain the computer belongs to.
    ///
    /// The corresponding C constant is `ComputerNameDnsDomain`.
    @_alwaysEmitIntoClient
    public static var dnsDomain: ComputerNameFormat { ComputerNameFormat(rawValue: 2) }

    /// The fully qualified DNS name: the host name and the domain.
    ///
    /// The corresponding C constant is `ComputerNameDnsFullyQualified`.
    @_alwaysEmitIntoClient
    public static var dnsFullyQualified: ComputerNameFormat { ComputerNameFormat(rawValue: 3) }

    /// The NetBIOS name of the physical computer, which differs from
    /// ``netBIOS`` only for a cluster's virtual server.
    ///
    /// The corresponding C constant is `ComputerNamePhysicalNetBIOS`.
    @_alwaysEmitIntoClient
    public static var physicalNetBIOS: ComputerNameFormat { ComputerNameFormat(rawValue: 4) }

    /// The DNS host name of the physical computer.
    ///
    /// The corresponding C constant is `ComputerNamePhysicalDnsHostname`.
    @_alwaysEmitIntoClient
    public static var physicalDnsHostName: ComputerNameFormat { ComputerNameFormat(rawValue: 5) }

    /// The DNS domain of the physical computer.
    ///
    /// The corresponding C constant is `ComputerNamePhysicalDnsDomain`.
    @_alwaysEmitIntoClient
    public static var physicalDnsDomain: ComputerNameFormat { ComputerNameFormat(rawValue: 6) }

    /// The fully qualified DNS name of the physical computer.
    ///
    /// The corresponding C constant is `ComputerNamePhysicalDnsFullyQualified`.
    @_alwaysEmitIntoClient
    public static var physicalDnsFullyQualified: ComputerNameFormat {
      ComputerNameFormat(rawValue: 7)
    }
  }

  /// One of the computer's names.
  ///
  /// - Parameter format: Which name. The default, the DNS host name, is
  ///   POSIX's `gethostname` name.
  ///
  /// A cluster's virtual server reports its own names; the `physical`
  /// formats report the node's.
  ///
  /// The corresponding C function is `GetComputerNameExW`.
  @_alwaysEmitIntoClient
  public static func computerName(
    _ format: Win32.ComputerNameFormat = .dnsHostName
  ) throws(Win32.Error) -> String {
    try _computerName(format.rawValue).get()
  }
}

// MARK: - The Windows version

@available(System 199, *)
extension Win32 {
  /// Whether Windows is a workstation, a server, or a domain controller.
  ///
  /// The corresponding C type is the `BYTE` of `OSVERSIONINFOEXW`'s
  /// `wProductType`.
  @frozen
  public struct ProductType: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: BYTE

    /// Creates a strongly-typed product type from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: BYTE) { self.rawValue = rawValue }

    /// A workstation: a desktop release, such as Windows 11.
    ///
    /// The corresponding C constant is `VER_NT_WORKSTATION`.
    @_alwaysEmitIntoClient
    public static var workstation: ProductType { ProductType(rawValue: 1) }

    /// A server that's a domain controller.
    ///
    /// The corresponding C constant is `VER_NT_DOMAIN_CONTROLLER`.
    @_alwaysEmitIntoClient
    public static var domainController: ProductType { ProductType(rawValue: 2) }

    /// A server that isn't a domain controller.
    ///
    /// The corresponding C constant is `VER_NT_SERVER`.
    @_alwaysEmitIntoClient
    public static var server: ProductType { ProductType(rawValue: 3) }
  }

  /// The running Windows release's version.
  ///
  /// The corresponding C type is `RTL_OSVERSIONINFOEXW`.
  @frozen
  public struct OSVersion: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: RTL_OSVERSIONINFOEXW

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: RTL_OSVERSIONINFOEXW) { self.rawValue = rawValue }

    /// The major version: 10 for Windows 10 and 11, and their servers.
    ///
    /// The corresponding C field is `dwMajorVersion`.
    @_alwaysEmitIntoClient
    public var majorVersion: Int { Int(rawValue.dwMajorVersion) }

    /// The minor version.
    ///
    /// The corresponding C field is `dwMinorVersion`.
    @_alwaysEmitIntoClient
    public var minorVersion: Int { Int(rawValue.dwMinorVersion) }

    /// The build number, which tells releases of one version apart:
    /// Windows 11's begin at 22000.
    ///
    /// The corresponding C field is `dwBuildNumber`.
    @_alwaysEmitIntoClient
    public var buildNumber: Int { Int(rawValue.dwBuildNumber) }

    /// Whether this is a workstation, a server, or a domain controller.
    ///
    /// The corresponding C field is `wProductType`.
    @_alwaysEmitIntoClient
    public var productType: Win32.ProductType { Win32.ProductType(rawValue: rawValue.wProductType) }

    /// The product suites installed, a bit for each, such as
    /// `VER_SUITE_TERMINAL`.
    ///
    /// The corresponding C field is `wSuiteMask`.
    @_alwaysEmitIntoClient
    public var suiteMask: WORD { rawValue.wSuiteMask }
  }

  /// The running Windows release's version, whatever version the program
  /// declares that it supports.
  ///
  /// Unlike `GetVersionExW`, which reports at most the newest version the
  /// program's manifest names, this reports the real version.
  ///
  /// The corresponding C function is `RtlGetVersion`, which ntdll.dll
  /// exports.
  @_alwaysEmitIntoClient
  public static func osVersion() throws(Win32.Error) -> OSVersion {
    OSVersion(rawValue: try _osVersion().get())
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _systemInformation(native: Bool) -> SYSTEM_INFO {
    var information = SYSTEM_INFO()
    if native {
      system_GetNativeSystemInfo(&information)
    } else {
      system_GetSystemInfo(&information)
    }
    return information
  }

  @usableFromInline
  internal static func _activeProcessorCount() -> Int {
    Int(system_GetActiveProcessorCount(_ALL_PROCESSOR_GROUPS))
  }

  @usableFromInline
  internal static func _logicalProcessorInformation(
  ) -> Result<[SYSTEM_LOGICAL_PROCESSOR_INFORMATION], Win32.Error> {
    let stride = MemoryLayout<SYSTEM_LOGICAL_PROCESSOR_INFORMATION>.stride
    var length: DWORD = 0
    var entries: [SYSTEM_LOGICAL_PROCESSOR_INFORMATION] = []
    while true {
      // The first call, with no room, reports the size needed.
      let succeeded = entries.withUnsafeMutableBufferPointer { buffer in
        system_GetLogicalProcessorInformation(buffer.baseAddress, &length)
      }
      if succeeded { return .success(Array(entries.prefix(Int(length) / stride))) }
      let error = GetLastError()
      guard error == Win32.Error.insufficientBuffer.rawValue else {
        return .failure(Win32.Error(error))
      }
      entries = Array(
        repeating: SYSTEM_LOGICAL_PROCESSOR_INFORMATION(),
        count: (Int(length) + stride - 1) / stride)
    }
  }

  @usableFromInline
  internal static func _installedMemory() -> Result<UInt64, Win32.Error> {
    var kilobytes: ULONGLONG = 0
    guard system_GetPhysicallyInstalledSystemMemory(&kilobytes) else {
      return .failure(Win32.Error(GetLastError()))
    }
    let (bytes, overflow) = UInt64(kilobytes).multipliedReportingOverflow(by: 1024)
    return .success(overflow ? .max : bytes)
  }

  @usableFromInline
  internal static func _computerName(_ format: CInt) -> Result<String, Win32.Error> {
    var capacity = 64
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<String> in
        // The size, in and out, counts characters: the buffer's with its
        // terminator, then the name's without it, or, when the buffer is
        // too small, the size it needs, with it.
        var size = DWORD(buffer.count)
        guard system_GetComputerNameExW(format, buffer.baseAddress, &size) else {
          let error = GetLastError()
          if error == Win32.Error.moreData.rawValue {
            return .retry(capacity: max(Int(size), buffer.count + 1))
          }
          return .failure(Win32.Error(error))
        }
        return .success(
          String(decoding: UnsafeBufferPointer(start: buffer.baseAddress, count: Int(size)), as: UTF16.self))
      }
      switch outcome {
      case .success(let name): return .success(name)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }

  /// The signature of `RtlGetVersion`, which returns an `NTSTATUS`.
  internal typealias _RtlGetVersion = @convention(c) (
    UnsafeMutablePointer<RTL_OSVERSIONINFOEXW>
  ) -> NTSTATUS

  @usableFromInline
  internal static func _osVersion() -> Result<RTL_OSVERSIONINFOEXW, Win32.Error> {
    // ntdll.dll is loaded in every process, but isn't linked.
    let ntdll = "ntdll.dll".withCString(encodedAs: UTF16.self) { name in
      system_GetModuleHandleW(name)
    }
    guard let ntdll,
      let getVersion = unsafeBitCast(
        system_GetProcAddress(ntdll, "RtlGetVersion"), to: Optional<_RtlGetVersion>.self)
    else {
      return .failure(Win32.Error(GetLastError()))
    }
    var information = RTL_OSVERSIONINFOEXW()
    information.dwOSVersionInfoSize = DWORD(MemoryLayout<RTL_OSVERSIONINFOEXW>.size)
    // RtlGetVersion documents no failure: it returns STATUS_SUCCESS.
    _ = getVersion(&information)
    return .success(information)
  }
}

#endif // os(Windows)
