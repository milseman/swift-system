/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Processor types and subtypes, as Mach-O headers, fat archives and the
// kernel (hw.cputype, hw.cpusubtype) identify them.

#if SYSTEM_PACKAGE_DARWIN

// Must import here to use mach/machine.h's constants in
// @_alwaysEmitIntoClient API.
import Darwin.Mach

@available(System 199, *)
extension Mach {
  /// A processor type: a family of processors, and its ABI.
  ///
  /// The high byte holds the ABI's bits, such as the 64-bit ABI's,
  /// so the 32-bit and 64-bit types of a family differ only in them:
  ///
  ///     Mach.CPUType.arm.with64BitABI == .arm64  // true
  ///
  /// The corresponding C type is `cpu_type_t`.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct CPUType: RawRepresentable, Hashable, Sendable {
    /// The raw C processor type.
    @_alwaysEmitIntoClient
    public var rawValue: cpu_type_t

    /// Creates a strongly-typed processor type from a raw C processor type.
    @_alwaysEmitIntoClient
    public init(rawValue: cpu_type_t) { self.rawValue = rawValue }
  }

  /// A processor subtype: a processor within a type's family,
  /// with feature flags in its high byte.
  ///
  /// The corresponding C type is `cpu_subtype_t`.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct CPUSubtype: RawRepresentable, Hashable, Sendable {
    /// The raw C processor subtype.
    @_alwaysEmitIntoClient
    public var rawValue: cpu_subtype_t

    /// Creates a strongly-typed processor subtype from a raw C subtype.
    @_alwaysEmitIntoClient
    public init(rawValue: cpu_subtype_t) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Mach.CPUType {
  /// Any processor type, as a fat archive's wildcard.
  ///
  /// The corresponding C constant is `CPU_TYPE_ANY`.
  @_alwaysEmitIntoClient
  public static var any: Self { Self(rawValue: CPU_TYPE_ANY) }

  /// 32-bit Intel processors.
  ///
  /// The corresponding C constants are `CPU_TYPE_X86` and `CPU_TYPE_I386`.
  @_alwaysEmitIntoClient
  public static var x86: Self { Self(rawValue: CPU_TYPE_X86) }

  /// 64-bit Intel processors.
  ///
  /// The corresponding C constant is `CPU_TYPE_X86_64`.
  @_alwaysEmitIntoClient
  public static var x86_64: Self { Self(rawValue: CPU_TYPE_X86_64) }

  /// 32-bit Arm processors.
  ///
  /// The corresponding C constant is `CPU_TYPE_ARM`.
  @_alwaysEmitIntoClient
  public static var arm: Self { Self(rawValue: CPU_TYPE_ARM) }

  /// 64-bit Arm processors.
  ///
  /// The corresponding C constant is `CPU_TYPE_ARM64`.
  @_alwaysEmitIntoClient
  public static var arm64: Self { Self(rawValue: CPU_TYPE_ARM64) }

  /// 64-bit Arm processors running code with 32-bit pointers,
  /// as Apple Watch does.
  ///
  /// The corresponding C constant is `CPU_TYPE_ARM64_32`.
  @_alwaysEmitIntoClient
  public static var arm64_32: Self { Self(rawValue: CPU_TYPE_ARM64_32) }

  /// Whether the type has the 64-bit ABI.
  ///
  /// The corresponding C constant is `CPU_ARCH_ABI64`.
  @_alwaysEmitIntoClient
  public var has64BitABI: Bool { rawValue & CPU_ARCH_ABI64 != 0 }

  /// The type of the same family with the 64-bit ABI,
  /// which may be this type.
  ///
  /// The corresponding C constant is `CPU_ARCH_ABI64`.
  @_alwaysEmitIntoClient
  public var with64BitABI: Self { Self(rawValue: rawValue | CPU_ARCH_ABI64) }

  /// The type of the same family without the 64-bit ABI,
  /// which may be this type.
  ///
  /// The corresponding C constant is `CPU_ARCH_ABI64`.
  @_alwaysEmitIntoClient
  public var without64BitABI: Self { Self(rawValue: rawValue & ~CPU_ARCH_ABI64) }
}

@available(System 199, *)
extension Mach.CPUSubtype {
  /// The subtype without its feature flags.
  ///
  /// The corresponding C constant is `CPU_SUBTYPE_MASK`, the flags' bits.
  @_alwaysEmitIntoClient
  public var withoutFeatureFlags: Self {
    Self(rawValue: cpu_subtype_t(bitPattern: UInt32(bitPattern: rawValue) & ~UInt32(CPU_SUBTYPE_MASK)))
  }

  /// The subtype's feature flags: its high byte.
  ///
  /// The corresponding C constant is `CPU_SUBTYPE_MASK`.
  @_alwaysEmitIntoClient
  public var featureFlags: UInt32 { UInt32(bitPattern: rawValue) & UInt32(CPU_SUBTYPE_MASK) }
}

#endif // SYSTEM_PACKAGE_DARWIN
