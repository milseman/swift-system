/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing
import Darwin

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

// Mach's processor types and subtypes (MachCPUType.swift).
@Suite("Mach processor types")
private struct MachCPUTypeTests {
  @available(System 199, *)
  @Test func theConstants() {
    #expect(Mach.CPUType.any.rawValue == CPU_TYPE_ANY)
    #expect(Mach.CPUType.x86.rawValue == CPU_TYPE_X86)
    #expect(Mach.CPUType.x86.rawValue == CPU_TYPE_I386)
    #expect(Mach.CPUType.x86_64.rawValue == CPU_TYPE_X86_64)
    #expect(Mach.CPUType.arm.rawValue == CPU_TYPE_ARM)
    #expect(Mach.CPUType.arm64.rawValue == CPU_TYPE_ARM64)
    #expect(Mach.CPUType.arm64_32.rawValue == CPU_TYPE_ARM64_32)
  }

  /// A family's 32-bit and 64-bit types differ only in the 64-bit ABI's bit.
  @available(System 199, *)
  @Test func theABIBit() {
    #expect(Mach.CPUType.arm.with64BitABI == .arm64)
    #expect(Mach.CPUType.arm64.without64BitABI == .arm)
    #expect(Mach.CPUType.x86.with64BitABI == .x86_64)
    #expect(Mach.CPUType.x86_64.without64BitABI == .x86)
    #expect(Mach.CPUType.arm64.with64BitABI == .arm64)
    #expect(Mach.CPUType.arm64.has64BitABI && !Mach.CPUType.arm.has64BitABI)
    // arm64_32 has the 64-bit hardware ABI with 32-bit types, not the 64-bit one.
    #expect(!Mach.CPUType.arm64_32.has64BitABI)
  }

  /// The kernel reports the host's type, one of the 64-bit Mac ones.
  @available(System 199, *)
  @Test func theHostsType() throws {
    let host = Mach.CPUType(rawValue: try SystemControl.value(.cpuType))
    #expect(host == .arm64 || host == .x86_64, "\(host)")
    #expect(host.has64BitABI)
    _ = Mach.CPUSubtype(rawValue: try SystemControl.value(.cpuSubtype))
  }

  @available(System 199, *)
  @Test func featureFlags() {
    let subtype = Mach.CPUSubtype(rawValue: cpu_subtype_t(bitPattern: 0x8000_0002))
    #expect(subtype.featureFlags == 0x8000_0000)
    #expect(subtype.withoutFeatureFlags.rawValue == 2)
    #expect(subtype.featureFlags == UInt32(bitPattern: subtype.rawValue) & UInt32(CPU_SUBTYPE_MASK))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
