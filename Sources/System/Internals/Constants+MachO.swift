/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The constants of the Mach-O file format that System's provisional API
// uses (Provisional/Provisional+MachO.swift): <mach-o/loader.h>'s magic
// numbers, file types and load command types, <mach-o/fat.h>'s magic
// numbers, and <mach-o/ranlib.h>'s table of contents names; and
// <mach/vm_prot.h>'s protections. The file types and load command types are
// UInt32, the type of the fields they're values of, though Swift imports the
// macros without LC_REQ_DYLD as Int32.

#if SYSTEM_PACKAGE_DARWIN

import Darwin.Mach
import MachO

// MARK: - Magic numbers

@_alwaysEmitIntoClient
internal var _MH_MAGIC: UInt32 { UInt32(MH_MAGIC) }

@_alwaysEmitIntoClient
internal var _MH_CIGAM: UInt32 { UInt32(MH_CIGAM) }

@_alwaysEmitIntoClient
internal var _MH_MAGIC_64: UInt32 { UInt32(MH_MAGIC_64) }

@_alwaysEmitIntoClient
internal var _MH_CIGAM_64: UInt32 { UInt32(MH_CIGAM_64) }

@_alwaysEmitIntoClient
internal var _FAT_MAGIC: UInt32 { UInt32(FAT_MAGIC) }

@_alwaysEmitIntoClient
internal var _FAT_CIGAM: UInt32 { UInt32(FAT_CIGAM) }

@_alwaysEmitIntoClient
internal var _FAT_MAGIC_64: UInt32 { UInt32(FAT_MAGIC_64) }

@_alwaysEmitIntoClient
internal var _FAT_CIGAM_64: UInt32 { UInt32(FAT_CIGAM_64) }

// MARK: - File types

@_alwaysEmitIntoClient
internal var _MH_OBJECT: UInt32 { UInt32(MH_OBJECT) }

@_alwaysEmitIntoClient
internal var _MH_EXECUTE: UInt32 { UInt32(MH_EXECUTE) }

@_alwaysEmitIntoClient
internal var _MH_DYLIB: UInt32 { UInt32(MH_DYLIB) }

@_alwaysEmitIntoClient
internal var _MH_BUNDLE: UInt32 { UInt32(MH_BUNDLE) }

// MARK: - Load command types

@_alwaysEmitIntoClient
internal var _LC_SEGMENT: UInt32 { UInt32(LC_SEGMENT) }

@_alwaysEmitIntoClient
internal var _LC_SEGMENT_64: UInt32 { UInt32(LC_SEGMENT_64) }

@_alwaysEmitIntoClient
internal var _LC_ID_DYLIB: UInt32 { UInt32(LC_ID_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_LOAD_DYLIB: UInt32 { UInt32(LC_LOAD_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_LOAD_WEAK_DYLIB: UInt32 { UInt32(LC_LOAD_WEAK_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_REEXPORT_DYLIB: UInt32 { UInt32(LC_REEXPORT_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_LAZY_LOAD_DYLIB: UInt32 { UInt32(LC_LAZY_LOAD_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_LOAD_UPWARD_DYLIB: UInt32 { UInt32(LC_LOAD_UPWARD_DYLIB) }

@_alwaysEmitIntoClient
internal var _LC_UUID: UInt32 { UInt32(LC_UUID) }

@_alwaysEmitIntoClient
internal var _LC_RPATH: UInt32 { UInt32(LC_RPATH) }

@_alwaysEmitIntoClient
internal var _LC_BUILD_VERSION: UInt32 { UInt32(LC_BUILD_VERSION) }

@_alwaysEmitIntoClient
internal var _LC_VERSION_MIN_MACOSX: UInt32 { UInt32(LC_VERSION_MIN_MACOSX) }

@_alwaysEmitIntoClient
internal var _LC_VERSION_MIN_IPHONEOS: UInt32 { UInt32(LC_VERSION_MIN_IPHONEOS) }

@_alwaysEmitIntoClient
internal var _LC_VERSION_MIN_TVOS: UInt32 { UInt32(LC_VERSION_MIN_TVOS) }

@_alwaysEmitIntoClient
internal var _LC_VERSION_MIN_WATCHOS: UInt32 { UInt32(LC_VERSION_MIN_WATCHOS) }

@_alwaysEmitIntoClient
internal var _LC_SYMTAB: UInt32 { UInt32(LC_SYMTAB) }

@_alwaysEmitIntoClient
internal var _LC_MAIN: UInt32 { UInt32(LC_MAIN) }

// MARK: - Static library tables of contents

@_alwaysEmitIntoClient
internal var _SYMDEF: String { SYMDEF }

@_alwaysEmitIntoClient
internal var _SYMDEF_SORTED: String { SYMDEF_SORTED }

@_alwaysEmitIntoClient
internal var _SYMDEF_64: String { SYMDEF_64 }

@_alwaysEmitIntoClient
internal var _SYMDEF_64_SORTED: String { SYMDEF_64_SORTED }

// MARK: - Virtual memory protections

@_alwaysEmitIntoClient
internal var _VM_PROT_READ: vm_prot_t { VM_PROT_READ }

@_alwaysEmitIntoClient
internal var _VM_PROT_WRITE: vm_prot_t { VM_PROT_WRITE }

@_alwaysEmitIntoClient
internal var _VM_PROT_EXECUTE: vm_prot_t { VM_PROT_EXECUTE }

#endif // SYSTEM_PACKAGE_DARWIN
