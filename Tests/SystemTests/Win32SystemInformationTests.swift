/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Processors, memory pages, installed memory, the computer's name, and the
// Windows version.
@available(System 199, *)
final class Win32SystemInformationTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let architectures: [(Win32.ProcessorArchitecture, Int)] = [
      (.x86, Int(WinSDK.PROCESSOR_ARCHITECTURE_INTEL)),
      (.arm, Int(WinSDK.PROCESSOR_ARCHITECTURE_ARM)),
      (.ia64, Int(WinSDK.PROCESSOR_ARCHITECTURE_IA64)),
      (.x64, Int(WinSDK.PROCESSOR_ARCHITECTURE_AMD64)),
      (.arm64, Int(WinSDK.PROCESSOR_ARCHITECTURE_ARM64)),
      (.unknown, Int(WinSDK.PROCESSOR_ARCHITECTURE_UNKNOWN)),
    ]
    for (architecture, value) in architectures {
      XCTAssertEqual(Int(architecture.rawValue), value, "\(architecture)")
    }
    let relationships: [(Win32.ProcessorRelationship, CInt)] = [
      (.processorCore, CInt(RelationProcessorCore.rawValue)),
      (.numaNode, CInt(RelationNumaNode.rawValue)),
      (.cache, CInt(RelationCache.rawValue)),
      (.processorPackage, CInt(RelationProcessorPackage.rawValue)),
    ]
    for (relationship, value) in relationships {
      XCTAssertEqual(relationship.rawValue, value, "\(relationship)")
    }
    let formats: [(Win32.ComputerNameFormat, CInt)] = [
      (.netBIOS, CInt(ComputerNameNetBIOS.rawValue)),
      (.dnsHostName, CInt(ComputerNameDnsHostname.rawValue)),
      (.dnsDomain, CInt(ComputerNameDnsDomain.rawValue)),
      (.dnsFullyQualified, CInt(ComputerNameDnsFullyQualified.rawValue)),
      (.physicalNetBIOS, CInt(ComputerNamePhysicalNetBIOS.rawValue)),
      (.physicalDnsHostName, CInt(ComputerNamePhysicalDnsHostname.rawValue)),
      (.physicalDnsDomain, CInt(ComputerNamePhysicalDnsDomain.rawValue)),
      (.physicalDnsFullyQualified, CInt(ComputerNamePhysicalDnsFullyQualified.rawValue)),
    ]
    for (format, value) in formats {
      XCTAssertEqual(format.rawValue, value, "\(format)")
    }
    let products: [(Win32.ProductType, Int)] = [
      (.workstation, Int(WinSDK.VER_NT_WORKSTATION)),
      (.domainController, Int(WinSDK.VER_NT_DOMAIN_CONTROLLER)),
      (.server, Int(WinSDK.VER_NT_SERVER)),
    ]
    for (product, value) in products {
      XCTAssertEqual(Int(product.rawValue), value, "\(product)")
    }
    XCTAssertEqual(Int(_ALL_PROCESSOR_GROUPS), Int(WinSDK.ALL_PROCESSOR_GROUPS))
  }

  func testSystemInformation() {
    let information = Win32.systemInformation()
    // Every 64-bit Windows has 4 KiB pages and 64 KiB granularity.
    XCTAssertEqual(information.pageSize, 4096)
    XCTAssertEqual(information.allocationGranularity, 65536)
    XCTAssertGreaterThanOrEqual(information.processorCount, 1)
    XCTAssertEqual(information.activeProcessorMask.nonzeroBitCount, information.processorCount)
    XCTAssertLessThan(information.minimumApplicationAddress, information.maximumApplicationAddress)
    #if arch(x86_64)
    XCTAssertEqual(information.processorArchitecture, .x64)
    #elseif arch(arm64)
    XCTAssertEqual(information.processorArchitecture, .arm64)
    #endif
    // An x64 process emulated on ARM64 sees x64, and its native system ARM64.
    let native = Win32.nativeSystemInformation().processorArchitecture
    XCTAssertTrue(native == .x64 || native == .arm64, "\(native)")
  }

  func testActiveProcessorCount() {
    let count = Win32.activeProcessorCount()
    XCTAssertGreaterThanOrEqual(count, Win32.systemInformation().processorCount)
  }

  func testLogicalProcessors() throws {
    let entries = try Win32.logicalProcessorInformation()
    let cores = entries.filter { $0.relationship == .processorCore }
    XCTAssertGreaterThanOrEqual(cores.count, 1)
    XCTAssertGreaterThanOrEqual(entries.filter { $0.relationship == .processorPackage }.count, 1)
    // The cores' processors are the group's.
    let coreProcessors = cores.reduce(UInt(0)) { $0 | $1.processorMask }
    XCTAssertEqual(coreProcessors, Win32.systemInformation().activeProcessorMask)
  }

  func testInstalledMemory() throws {
    let bytes = try Win32.installedMemory()
    XCTAssertGreaterThanOrEqual(bytes, 512 << 20)
    XCTAssertEqual(bytes % 1024, 0)
  }

  func testComputerName() throws {
    let host = try Win32.computerName()
    XCTAssertFalse(host.isEmpty)
    XCTAssertFalse(host.contains("."), host)
    // COMPUTERNAME holds the NetBIOS name.
    let netBIOS = try Win32.computerName(.netBIOS)
    let fromEnvironment = try XCTUnwrap(win32RawEnvironmentValue("COMPUTERNAME"))
    XCTAssertEqual(netBIOS.uppercased(), fromEnvironment.uppercased())
    let qualified = try Win32.computerName(.dnsFullyQualified)
    XCTAssertTrue(qualified.lowercased().hasPrefix(host.lowercased()), "\(qualified), \(host)")
  }

  func testOSVersion() throws {
    let version = try Win32.osVersion()
    // Windows 10 and 11, and their servers, are 10.0, from build 10240.
    XCTAssertEqual(version.majorVersion, 10)
    XCTAssertEqual(version.minorVersion, 0)
    XCTAssertGreaterThanOrEqual(version.buildNumber, 10240)
    let products: [Win32.ProductType] = [.workstation, .domainController, .server]
    XCTAssertTrue(products.contains(version.productType), "\(version.productType)")
  }
}

#endif // os(Windows)
