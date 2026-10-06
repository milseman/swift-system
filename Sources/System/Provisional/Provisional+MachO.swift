/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the Mach-O file format's structures and constants, from
// <mach-o/loader.h>, <mach-o/fat.h> and <mach-o/ranlib.h>, the virtual
// memory protections of its segments, from <mach/vm_prot.h>, and the
// dynamic loader's names for its architectures, from <mach-o/utils.h>.
//
// System wraps the Mach-O format provisionally. It's a file format, not an
// operating-system interface: its lasting home is a library that reads
// object files, or a Swift overlay of the C module, MachO. Until there's
// one, code that reads a binary's headers and load commands, as swift-build
// reads a binary's slices, linked libraries and platforms, can do it
// without importing MachO, whose structures' fields a client can't read
// under MemberImportVisibility without the import. The structures are the
// C ones, as CInterop's other types are, with accessors under Swift names,
// and the constants are statics of a namespace, MachOFile, since MachO is
// the C module's name. Darwin only: no other platform's headers declare
// them, and a reader of Mach-O files elsewhere has its own copies.

#if SYSTEM_PACKAGE_DARWIN

// Must import here to read the structures' fields in
// @_alwaysEmitIntoClient accessors.
import Darwin.Mach
import MachO

// MARK: - Types

@available(System 199, *)
extension CInterop {
  /// The header at the start of a 32-bit Mach-O file,
  /// or of a 32-bit slice of a fat file.
  ///
  /// Its fields are as the file stores them, in the file's byte order,
  /// which its `magicNumber` gives: see ``MachOFile/Magic``.
  ///
  /// The corresponding C type is `struct mach_header`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias MachHeader = mach_header

  /// The header at the start of a 64-bit Mach-O file,
  /// or of a 64-bit slice of a fat file.
  ///
  /// Its fields are as the file stores them, in the file's byte order,
  /// which its `magicNumber` gives: see ``MachOFile/Magic``.
  ///
  /// The corresponding C type is `struct mach_header_64`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias MachHeader64 = mach_header_64

  /// The part that every load command starts with:
  /// its type and its size.
  ///
  /// The load commands follow the header, one after another,
  /// each starting where the one before it ends.
  ///
  /// The corresponding C type is `struct load_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias LoadCommand = load_command

  /// A load command that maps part of a 32-bit file into memory,
  /// followed by its sections, if any.
  ///
  /// The corresponding C type is `struct segment_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias SegmentCommand = segment_command

  /// A load command that maps part of a 64-bit file into memory,
  /// followed by its sections, if any.
  ///
  /// The corresponding C type is `struct segment_command_64`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias SegmentCommand64 = segment_command_64

  /// A section of a 32-bit segment.
  ///
  /// The corresponding C type is `struct section`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias Section = section

  /// A section of a 64-bit segment.
  ///
  /// The corresponding C type is `struct section_64`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias Section64 = section_64

  /// A dynamic library, as a load command identifies it:
  /// where its name is, and its versions.
  ///
  /// The corresponding C type is `struct dylib`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias Dylib = dylib

  /// A load command that names a dynamic library:
  /// the file's own name, if it's a library,
  /// or one that it links to.
  ///
  /// The library's name follows the structure, in the command.
  ///
  /// The corresponding C type is `struct dylib_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias DylibCommand = dylib_command

  /// A load command that holds the file's UUID.
  ///
  /// The corresponding C type is `struct uuid_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias UUIDCommand = uuid_command

  /// A load command that adds a directory to the run path,
  /// which `@rpath` searches.
  ///
  /// The path follows the structure, in the command.
  ///
  /// The corresponding C type is `struct rpath_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias RPathCommand = rpath_command

  /// A load command that names the platform the file is built for,
  /// with the oldest OS version it runs on and the SDK it's built with.
  ///
  /// The corresponding C type is `struct build_version_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias BuildVersionCommand = build_version_command

  /// A load command, older than ``BuildVersionCommand``,
  /// with the oldest OS version the file runs on and the SDK it's built with;
  /// its type names the OS.
  ///
  /// The corresponding C type is `struct version_min_command`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias VersionMinCommand = version_min_command

  /// The header at the start of a fat file,
  /// which holds a Mach-O file for each of several architectures.
  ///
  /// A fat file's headers are big-endian,
  /// so on a little-endian host each field needs `byteSwapped`,
  /// or `UInt32(bigEndian:)`: see ``MachOFile/Magic``.
  ///
  /// The corresponding C type is `struct fat_header`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias FatHeader = fat_header

  /// Where a fat file holds one architecture's Mach-O file,
  /// in a file whose offsets and sizes fit in 32 bits.
  /// One follows the ``FatHeader`` for each architecture.
  ///
  /// Its fields are big-endian, as the header's are.
  ///
  /// The corresponding C type is `struct fat_arch`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias FatArch = fat_arch

  /// Where a fat file holds one architecture's Mach-O file,
  /// in a file whose header has ``MachOFile/Magic/fatHeader64``.
  ///
  /// Its fields are big-endian, as the header's are.
  ///
  /// The corresponding C type is `struct fat_arch_64`.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public typealias FatArch64 = fat_arch_64
}

// MARK: - Constants

/// A namespace for the Mach-O file format's constants:
/// the magic numbers that a file starts with,
/// the kinds of file, and the kinds of load command.
///
/// Each is the value of a field of the format's structures,
/// such as ``CInterop/MachHeader64``, which hold the C types' fields
/// as the file stores them:
///
///     let header = bytes.loadUnaligned(as: CInterop.MachHeader64.self)
///     guard header.magicNumber == MachOFile.Magic.machHeader64,
///           header.fileType == MachOFile.FileType.execute
///     else { return }
///
/// - Note: Provisional: Mach-O structures may move to a library for object files.
/// - Note: Only available on Darwin.
@available(System 199, *)
public enum MachOFile {}

@available(System 199, *)
extension MachOFile {
  /// The magic numbers that a Mach-O file, or a fat file, starts with,
  /// as a header's `magicNumber` reads on the host.
  ///
  /// A Mach-O file is in the byte order of the processor it's for.
  /// Its header's magic number reads as ``machHeader64`` or ``machHeader``
  /// where that's the host's,
  /// and as ``swappedMachHeader64`` or ``swappedMachHeader`` where it isn't:
  /// then each field of the file's structures needs `byteSwapped`.
  /// A fat file is big-endian, so on a little-endian host
  /// its magic number reads as ``swappedFatHeader`` or ``swappedFatHeader64``.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public enum Magic {}

  /// The kinds of Mach-O file, which a header's `fileType` is.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public enum FileType {}

  /// The kinds of load command, which a load command's `commandType` is.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public enum LoadCommandType {}

  /// The names of the archive member that holds a static library's
  /// table of contents: its symbols, and the members that define them.
  ///
  /// A static library is an archive (see ``ArchiveFile``)
  /// of Mach-O object files, and its table of contents
  /// is a member of its own, first, under one of these names.
  ///
  /// - Note: Provisional: Mach-O structures may move to a library for object files.
  /// - Note: Only available on Darwin.
  public enum ArchiveMemberName {}
}

@available(System 199, *)
extension MachOFile.Magic {
  /// A 32-bit Mach-O file's magic number, in the host's byte order.
  ///
  /// The corresponding C constant is `MH_MAGIC`.
  @_alwaysEmitIntoClient
  public static var machHeader: UInt32 { _MH_MAGIC }

  /// A 32-bit Mach-O file's magic number, read in the other byte order.
  ///
  /// The corresponding C constant is `MH_CIGAM`.
  @_alwaysEmitIntoClient
  public static var swappedMachHeader: UInt32 { _MH_CIGAM }

  /// A 64-bit Mach-O file's magic number, in the host's byte order.
  ///
  /// The corresponding C constant is `MH_MAGIC_64`.
  @_alwaysEmitIntoClient
  public static var machHeader64: UInt32 { _MH_MAGIC_64 }

  /// A 64-bit Mach-O file's magic number, read in the other byte order.
  ///
  /// The corresponding C constant is `MH_CIGAM_64`.
  @_alwaysEmitIntoClient
  public static var swappedMachHeader64: UInt32 { _MH_CIGAM_64 }

  /// A fat file's magic number, as it reads on a big-endian host,
  /// when the file's architectures are ``CInterop/FatArch``s.
  ///
  /// The corresponding C constant is `FAT_MAGIC`.
  @_alwaysEmitIntoClient
  public static var fatHeader: UInt32 { _FAT_MAGIC }

  /// A fat file's magic number, as it reads on a little-endian host,
  /// when the file's architectures are ``CInterop/FatArch``s.
  ///
  /// The corresponding C constant is `FAT_CIGAM`.
  @_alwaysEmitIntoClient
  public static var swappedFatHeader: UInt32 { _FAT_CIGAM }

  /// A fat file's magic number, as it reads on a big-endian host,
  /// when the file's architectures are ``CInterop/FatArch64``s.
  ///
  /// The corresponding C constant is `FAT_MAGIC_64`.
  @_alwaysEmitIntoClient
  public static var fatHeader64: UInt32 { _FAT_MAGIC_64 }

  /// A fat file's magic number, as it reads on a little-endian host,
  /// when the file's architectures are ``CInterop/FatArch64``s.
  ///
  /// The corresponding C constant is `FAT_CIGAM_64`.
  @_alwaysEmitIntoClient
  public static var swappedFatHeader64: UInt32 { _FAT_CIGAM_64 }
}

@available(System 199, *)
extension MachOFile.FileType {
  /// A relocatable object file, as a compiler writes one.
  ///
  /// The corresponding C constant is `MH_OBJECT`.
  @_alwaysEmitIntoClient
  public static var object: UInt32 { _MH_OBJECT }

  /// An executable.
  ///
  /// The corresponding C constant is `MH_EXECUTE`.
  @_alwaysEmitIntoClient
  public static var execute: UInt32 { _MH_EXECUTE }

  /// A dynamic library.
  ///
  /// The corresponding C constant is `MH_DYLIB`.
  @_alwaysEmitIntoClient
  public static var dylib: UInt32 { _MH_DYLIB }

  /// A bundle, which a program loads at run time, as a plug-in.
  ///
  /// The corresponding C constant is `MH_BUNDLE`.
  @_alwaysEmitIntoClient
  public static var bundle: UInt32 { _MH_BUNDLE }
}

@available(System 199, *)
extension MachOFile.LoadCommandType {
  /// A 32-bit segment: ``CInterop/SegmentCommand``.
  ///
  /// The corresponding C constant is `LC_SEGMENT`.
  @_alwaysEmitIntoClient
  public static var segment: UInt32 { _LC_SEGMENT }

  /// A 64-bit segment: ``CInterop/SegmentCommand64``.
  ///
  /// The corresponding C constant is `LC_SEGMENT_64`.
  @_alwaysEmitIntoClient
  public static var segment64: UInt32 { _LC_SEGMENT_64 }

  /// A dynamic library's own name: ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_ID_DYLIB`.
  @_alwaysEmitIntoClient
  public static var idDylib: UInt32 { _LC_ID_DYLIB }

  /// A dynamic library the file links to: ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_LOAD_DYLIB`.
  @_alwaysEmitIntoClient
  public static var loadDylib: UInt32 { _LC_LOAD_DYLIB }

  /// A dynamic library the file links to weakly, which may be missing:
  /// ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_LOAD_WEAK_DYLIB`.
  @_alwaysEmitIntoClient
  public static var loadWeakDylib: UInt32 { _LC_LOAD_WEAK_DYLIB }

  /// A dynamic library the file links to and re-exports:
  /// ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_REEXPORT_DYLIB`.
  @_alwaysEmitIntoClient
  public static var reexportDylib: UInt32 { _LC_REEXPORT_DYLIB }

  /// A dynamic library the file loads when it first uses it:
  /// ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_LAZY_LOAD_DYLIB`.
  @_alwaysEmitIntoClient
  public static var lazyLoadDylib: UInt32 { _LC_LAZY_LOAD_DYLIB }

  /// A dynamic library the file links to that links back to it:
  /// ``CInterop/DylibCommand``.
  ///
  /// The corresponding C constant is `LC_LOAD_UPWARD_DYLIB`.
  @_alwaysEmitIntoClient
  public static var loadUpwardDylib: UInt32 { _LC_LOAD_UPWARD_DYLIB }

  /// The file's UUID: ``CInterop/UUIDCommand``.
  ///
  /// The corresponding C constant is `LC_UUID`.
  @_alwaysEmitIntoClient
  public static var uuid: UInt32 { _LC_UUID }

  /// A directory for the run path: ``CInterop/RPathCommand``.
  ///
  /// The corresponding C constant is `LC_RPATH`.
  @_alwaysEmitIntoClient
  public static var rpath: UInt32 { _LC_RPATH }

  /// The platform and versions the file is built for:
  /// ``CInterop/BuildVersionCommand``.
  ///
  /// The corresponding C constant is `LC_BUILD_VERSION`.
  @_alwaysEmitIntoClient
  public static var buildVersion: UInt32 { _LC_BUILD_VERSION }

  /// The macOS versions the file is built for:
  /// ``CInterop/VersionMinCommand``.
  ///
  /// The corresponding C constant is `LC_VERSION_MIN_MACOSX`.
  @_alwaysEmitIntoClient
  public static var versionMinMacOS: UInt32 { _LC_VERSION_MIN_MACOSX }

  /// The iOS versions the file is built for:
  /// ``CInterop/VersionMinCommand``.
  ///
  /// The corresponding C constant is `LC_VERSION_MIN_IPHONEOS`.
  @_alwaysEmitIntoClient
  public static var versionMinIOS: UInt32 { _LC_VERSION_MIN_IPHONEOS }

  /// The tvOS versions the file is built for:
  /// ``CInterop/VersionMinCommand``.
  ///
  /// The corresponding C constant is `LC_VERSION_MIN_TVOS`.
  @_alwaysEmitIntoClient
  public static var versionMinTVOS: UInt32 { _LC_VERSION_MIN_TVOS }

  /// The watchOS versions the file is built for:
  /// ``CInterop/VersionMinCommand``.
  ///
  /// The corresponding C constant is `LC_VERSION_MIN_WATCHOS`.
  @_alwaysEmitIntoClient
  public static var versionMinWatchOS: UInt32 { _LC_VERSION_MIN_WATCHOS }
}

@available(System 199, *)
extension MachOFile.ArchiveMemberName {
  /// The table of contents, with 32-bit offsets, in no order.
  ///
  /// The corresponding C constant is `SYMDEF`.
  @_alwaysEmitIntoClient
  public static var symbolTable: String { _SYMDEF }

  /// The table of contents, with 32-bit offsets, sorted by symbol.
  ///
  /// The corresponding C constant is `SYMDEF_SORTED`.
  @_alwaysEmitIntoClient
  public static var sortedSymbolTable: String { _SYMDEF_SORTED }

  /// The table of contents, with 64-bit offsets, in no order.
  ///
  /// The corresponding C constant is `SYMDEF_64`.
  @_alwaysEmitIntoClient
  public static var symbolTable64: String { _SYMDEF_64 }

  /// The table of contents, with 64-bit offsets, sorted by symbol.
  ///
  /// The corresponding C constant is `SYMDEF_64_SORTED`.
  @_alwaysEmitIntoClient
  public static var sortedSymbolTable64: String { _SYMDEF_64_SORTED }
}

// MARK: - Headers

@available(System 199, *)
extension CInterop.MachHeader {
  /// The magic number: one of ``MachOFile/Magic``'s.
  ///
  /// The corresponding C field is `magic`.
  @_alwaysEmitIntoClient
  public var magicNumber: UInt32 { magic }

  /// The processor type: `Mach.CPUType(rawValue: header.cpuType)`.
  ///
  /// The corresponding C field is `cputype`.
  @_alwaysEmitIntoClient
  public var cpuType: cpu_type_t { cputype }

  /// The processor subtype: `Mach.CPUSubtype(rawValue: header.cpuSubtype)`.
  ///
  /// The corresponding C field is `cpusubtype`.
  @_alwaysEmitIntoClient
  public var cpuSubtype: cpu_subtype_t { cpusubtype }

  /// The kind of file: one of ``MachOFile/FileType``'s.
  ///
  /// The corresponding C field is `filetype`.
  @_alwaysEmitIntoClient
  public var fileType: UInt32 { filetype }

  /// The number of load commands that follow the header.
  ///
  /// The corresponding C field is `ncmds`.
  @_alwaysEmitIntoClient
  public var loadCommandCount: UInt32 { ncmds }

  /// The size of the load commands that follow the header, in bytes.
  ///
  /// The corresponding C field is `sizeofcmds`.
  @_alwaysEmitIntoClient
  public var loadCommandsSize: UInt32 { sizeofcmds }

  /// The header's flags, `MH_` constants such as `MH_PIE`.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var headerFlags: UInt32 { flags }
}

@available(System 199, *)
extension CInterop.MachHeader64 {
  /// The magic number: one of ``MachOFile/Magic``'s.
  ///
  /// The corresponding C field is `magic`.
  @_alwaysEmitIntoClient
  public var magicNumber: UInt32 { magic }

  /// The processor type: `Mach.CPUType(rawValue: header.cpuType)`.
  ///
  /// The corresponding C field is `cputype`.
  @_alwaysEmitIntoClient
  public var cpuType: cpu_type_t { cputype }

  /// The processor subtype: `Mach.CPUSubtype(rawValue: header.cpuSubtype)`.
  ///
  /// The corresponding C field is `cpusubtype`.
  @_alwaysEmitIntoClient
  public var cpuSubtype: cpu_subtype_t { cpusubtype }

  /// The kind of file: one of ``MachOFile/FileType``'s.
  ///
  /// The corresponding C field is `filetype`.
  @_alwaysEmitIntoClient
  public var fileType: UInt32 { filetype }

  /// The number of load commands that follow the header.
  ///
  /// The corresponding C field is `ncmds`.
  @_alwaysEmitIntoClient
  public var loadCommandCount: UInt32 { ncmds }

  /// The size of the load commands that follow the header, in bytes.
  ///
  /// The corresponding C field is `sizeofcmds`.
  @_alwaysEmitIntoClient
  public var loadCommandsSize: UInt32 { sizeofcmds }

  /// The header's flags, `MH_` constants such as `MH_PIE`.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var headerFlags: UInt32 { flags }
}

// MARK: - Load commands

@available(System 199, *)
extension CInterop.LoadCommand {
  /// The kind of load command: one of ``MachOFile/LoadCommandType``'s,
  /// which says which structure the command is.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the whole command, in bytes,
  /// including what follows its structure:
  /// the next command starts this far from this one's start.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }
}

@available(System 199, *)
extension CInterop.SegmentCommand {
  /// The kind of load command: ``MachOFile/LoadCommandType/segment``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command in bytes, including its sections.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The segment's name, such as `__TEXT`.
  ///
  /// The corresponding C field is `segname`.
  @_alwaysEmitIntoClient
  public var segmentName: String { _machOName(segname) }

  /// The segment's address in memory.
  ///
  /// The corresponding C field is `vmaddr`.
  @_alwaysEmitIntoClient
  public var virtualAddress: UInt32 { vmaddr }

  /// The segment's size in memory, in bytes.
  ///
  /// The corresponding C field is `vmsize`.
  @_alwaysEmitIntoClient
  public var virtualSize: UInt32 { vmsize }

  /// Where the segment's contents start in the file.
  ///
  /// The corresponding C field is `fileoff`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt32 { fileoff }

  /// The size of the segment's contents in the file, in bytes.
  ///
  /// The corresponding C field is `filesize`.
  @_alwaysEmitIntoClient
  public var fileSize: UInt32 { filesize }

  /// The most access the segment's memory can ever allow:
  /// `Mach.VirtualMemory.Protection(rawValue: segment.maximumProtection)`.
  ///
  /// The corresponding C field is `maxprot`.
  @_alwaysEmitIntoClient
  public var maximumProtection: vm_prot_t { maxprot }

  /// The access the segment's memory allows when it's mapped:
  /// `Mach.VirtualMemory.Protection(rawValue: segment.initialProtection)`.
  ///
  /// The corresponding C field is `initprot`.
  @_alwaysEmitIntoClient
  public var initialProtection: vm_prot_t { initprot }

  /// The number of sections that follow the command.
  ///
  /// The corresponding C field is `nsects`.
  @_alwaysEmitIntoClient
  public var sectionCount: UInt32 { nsects }

  /// The segment's flags, `SG_` constants such as `SG_READ_ONLY`.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var segmentFlags: UInt32 { flags }
}

@available(System 199, *)
extension CInterop.SegmentCommand64 {
  /// The kind of load command: ``MachOFile/LoadCommandType/segment64``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command in bytes, including its sections.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The segment's name, such as `__TEXT`.
  ///
  /// The corresponding C field is `segname`.
  @_alwaysEmitIntoClient
  public var segmentName: String { _machOName(segname) }

  /// The segment's address in memory.
  ///
  /// The corresponding C field is `vmaddr`.
  @_alwaysEmitIntoClient
  public var virtualAddress: UInt64 { vmaddr }

  /// The segment's size in memory, in bytes.
  ///
  /// The corresponding C field is `vmsize`.
  @_alwaysEmitIntoClient
  public var virtualSize: UInt64 { vmsize }

  /// Where the segment's contents start in the file.
  ///
  /// The corresponding C field is `fileoff`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt64 { fileoff }

  /// The size of the segment's contents in the file, in bytes.
  ///
  /// The corresponding C field is `filesize`.
  @_alwaysEmitIntoClient
  public var fileSize: UInt64 { filesize }

  /// The most access the segment's memory can ever allow:
  /// `Mach.VirtualMemory.Protection(rawValue: segment.maximumProtection)`.
  ///
  /// The corresponding C field is `maxprot`.
  @_alwaysEmitIntoClient
  public var maximumProtection: vm_prot_t { maxprot }

  /// The access the segment's memory allows when it's mapped:
  /// `Mach.VirtualMemory.Protection(rawValue: segment.initialProtection)`.
  ///
  /// The corresponding C field is `initprot`.
  @_alwaysEmitIntoClient
  public var initialProtection: vm_prot_t { initprot }

  /// The number of sections that follow the command.
  ///
  /// The corresponding C field is `nsects`.
  @_alwaysEmitIntoClient
  public var sectionCount: UInt32 { nsects }

  /// The segment's flags, `SG_` constants such as `SG_READ_ONLY`.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var segmentFlags: UInt32 { flags }
}

@available(System 199, *)
extension CInterop.Section {
  /// The section's name, such as `__text`.
  ///
  /// The corresponding C field is `sectname`.
  @_alwaysEmitIntoClient
  public var sectionName: String { _machOName(sectname) }

  /// The name of the segment the section is in, such as `__TEXT`.
  ///
  /// The corresponding C field is `segname`.
  @_alwaysEmitIntoClient
  public var segmentName: String { _machOName(segname) }

  /// The section's address in memory.
  ///
  /// The corresponding C field is `addr`.
  @_alwaysEmitIntoClient
  public var address: UInt32 { addr }

  /// The section's size, in bytes.
  ///
  /// The corresponding C field is `size`.
  @_alwaysEmitIntoClient
  public var sectionSize: UInt32 { size }

  /// Where the section's contents start in the file.
  ///
  /// The corresponding C field is `offset`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt32 { offset }

  /// The section's alignment, as a power of two:
  /// it's aligned to `1 << alignmentExponent` bytes.
  ///
  /// The corresponding C field is `align`.
  @_alwaysEmitIntoClient
  public var alignmentExponent: UInt32 { align }

  /// Where the section's relocation entries start in the file.
  ///
  /// The corresponding C field is `reloff`.
  @_alwaysEmitIntoClient
  public var relocationsOffset: UInt32 { reloff }

  /// The number of the section's relocation entries.
  ///
  /// The corresponding C field is `nreloc`.
  @_alwaysEmitIntoClient
  public var relocationCount: UInt32 { nreloc }

  /// The section's type and attributes, `S_` constants.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var sectionFlags: UInt32 { flags }
}

@available(System 199, *)
extension CInterop.Section64 {
  /// The section's name, such as `__text`.
  ///
  /// The corresponding C field is `sectname`.
  @_alwaysEmitIntoClient
  public var sectionName: String { _machOName(sectname) }

  /// The name of the segment the section is in, such as `__TEXT`.
  ///
  /// The corresponding C field is `segname`.
  @_alwaysEmitIntoClient
  public var segmentName: String { _machOName(segname) }

  /// The section's address in memory.
  ///
  /// The corresponding C field is `addr`.
  @_alwaysEmitIntoClient
  public var address: UInt64 { addr }

  /// The section's size, in bytes.
  ///
  /// The corresponding C field is `size`.
  @_alwaysEmitIntoClient
  public var sectionSize: UInt64 { size }

  /// Where the section's contents start in the file.
  ///
  /// The corresponding C field is `offset`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt32 { offset }

  /// The section's alignment, as a power of two:
  /// it's aligned to `1 << alignmentExponent` bytes.
  ///
  /// The corresponding C field is `align`.
  @_alwaysEmitIntoClient
  public var alignmentExponent: UInt32 { align }

  /// Where the section's relocation entries start in the file.
  ///
  /// The corresponding C field is `reloff`.
  @_alwaysEmitIntoClient
  public var relocationsOffset: UInt32 { reloff }

  /// The number of the section's relocation entries.
  ///
  /// The corresponding C field is `nreloc`.
  @_alwaysEmitIntoClient
  public var relocationCount: UInt32 { nreloc }

  /// The section's type and attributes, `S_` constants.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var sectionFlags: UInt32 { flags }
}

@available(System 199, *)
extension CInterop.Dylib {
  /// Where the library's name starts, as an offset in bytes
  /// from the start of the load command that holds this structure.
  /// The name is a C string, padded to the end of the command.
  ///
  /// The corresponding C field is `name.offset`.
  @_alwaysEmitIntoClient
  public var nameOffset: UInt32 { name.offset }

  /// The library's build time stamp.
  ///
  /// The corresponding C field is `timestamp`.
  @_alwaysEmitIntoClient
  public var buildTimestamp: UInt32 { timestamp }

  /// The library's current version, X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `current_version`.
  @_alwaysEmitIntoClient
  public var currentVersion: UInt32 { current_version }

  /// The oldest version of the library that the file is compatible with,
  /// X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `compatibility_version`.
  @_alwaysEmitIntoClient
  public var compatibilityVersion: UInt32 { compatibility_version }
}

@available(System 199, *)
extension CInterop.DylibCommand {
  /// The kind of load command:
  /// ``MachOFile/LoadCommandType/idDylib``, or one of the kinds of link,
  /// such as ``MachOFile/LoadCommandType/loadDylib``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command in bytes, including the library's name.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The library.
  ///
  /// The corresponding C field is `dylib`.
  @_alwaysEmitIntoClient
  public var library: CInterop.Dylib { dylib }
}

@available(System 199, *)
extension CInterop.UUIDCommand {
  /// The kind of load command: ``MachOFile/LoadCommandType/uuid``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command, in bytes.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The file's UUID, as Foundation's `UUID(uuid:)` takes it.
  ///
  /// The corresponding C field is `uuid`.
  @_alwaysEmitIntoClient
  public var uuidBytes: (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  ) { uuid }
}

@available(System 199, *)
extension CInterop.RPathCommand {
  /// The kind of load command: ``MachOFile/LoadCommandType/rpath``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command in bytes, including the path.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// Where the path starts, as an offset in bytes
  /// from the start of the command.
  /// The path is a C string, padded to the end of the command.
  ///
  /// The corresponding C field is `path.offset`.
  @_alwaysEmitIntoClient
  public var pathOffset: UInt32 { path.offset }
}

@available(System 199, *)
extension CInterop.BuildVersionCommand {
  /// The kind of load command: ``MachOFile/LoadCommandType/buildVersion``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command in bytes, including the tools that follow it.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The platform the file is built for, a `PLATFORM_` constant,
  /// such as `PLATFORM_MACOS`, 1.
  ///
  /// The corresponding C field is `platform`.
  @_alwaysEmitIntoClient
  public var targetPlatform: UInt32 { platform }

  /// The oldest OS version the file runs on, X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `minos`.
  @_alwaysEmitIntoClient
  public var minimumOSVersion: UInt32 { minos }

  /// The version of the SDK the file is built with,
  /// X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `sdk`.
  @_alwaysEmitIntoClient
  public var sdkVersion: UInt32 { sdk }

  /// The number of tool versions that follow the command's structure.
  ///
  /// The corresponding C field is `ntools`.
  @_alwaysEmitIntoClient
  public var toolCount: UInt32 { ntools }
}

@available(System 199, *)
extension CInterop.VersionMinCommand {
  /// The kind of load command, which names the OS:
  /// such as ``MachOFile/LoadCommandType/versionMinMacOS``.
  ///
  /// The corresponding C field is `cmd`.
  @_alwaysEmitIntoClient
  public var commandType: UInt32 { cmd }

  /// The size of the command, in bytes.
  ///
  /// The corresponding C field is `cmdsize`.
  @_alwaysEmitIntoClient
  public var commandSize: UInt32 { cmdsize }

  /// The oldest OS version the file runs on, X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `version`.
  @_alwaysEmitIntoClient
  public var minimumOSVersion: UInt32 { version }

  /// The version of the SDK the file is built with,
  /// X.Y.Z in the nibbles xxxx.yy.zz.
  ///
  /// The corresponding C field is `sdk`.
  @_alwaysEmitIntoClient
  public var sdkVersion: UInt32 { sdk }
}

// MARK: - Fat files

@available(System 199, *)
extension CInterop.FatHeader {
  /// The magic number: ``MachOFile/Magic/swappedFatHeader``
  /// or ``MachOFile/Magic/swappedFatHeader64`` on a little-endian host.
  ///
  /// The corresponding C field is `magic`.
  @_alwaysEmitIntoClient
  public var magicNumber: UInt32 { magic }

  /// The number of architectures, whose structures follow the header;
  /// big-endian.
  ///
  /// The corresponding C field is `nfat_arch`.
  @_alwaysEmitIntoClient
  public var architectureCount: UInt32 { nfat_arch }
}

@available(System 199, *)
extension CInterop.FatArch {
  /// The architecture's processor type; big-endian.
  ///
  /// The corresponding C field is `cputype`.
  @_alwaysEmitIntoClient
  public var cpuType: cpu_type_t { cputype }

  /// The architecture's processor subtype; big-endian.
  ///
  /// The corresponding C field is `cpusubtype`.
  @_alwaysEmitIntoClient
  public var cpuSubtype: cpu_subtype_t { cpusubtype }

  /// Where the architecture's Mach-O file starts in the fat file;
  /// big-endian.
  ///
  /// The corresponding C field is `offset`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt32 { offset }

  /// The size of the architecture's Mach-O file, in bytes; big-endian.
  ///
  /// The corresponding C field is `size`.
  @_alwaysEmitIntoClient
  public var fileSize: UInt32 { size }

  /// The alignment of the architecture's Mach-O file in the fat file,
  /// as a power of two; big-endian.
  ///
  /// The corresponding C field is `align`.
  @_alwaysEmitIntoClient
  public var alignmentExponent: UInt32 { align }
}

@available(System 199, *)
extension CInterop.FatArch64 {
  /// The architecture's processor type; big-endian.
  ///
  /// The corresponding C field is `cputype`.
  @_alwaysEmitIntoClient
  public var cpuType: cpu_type_t { cputype }

  /// The architecture's processor subtype; big-endian.
  ///
  /// The corresponding C field is `cpusubtype`.
  @_alwaysEmitIntoClient
  public var cpuSubtype: cpu_subtype_t { cpusubtype }

  /// Where the architecture's Mach-O file starts in the fat file;
  /// big-endian.
  ///
  /// The corresponding C field is `offset`.
  @_alwaysEmitIntoClient
  public var fileOffset: UInt64 { offset }

  /// The size of the architecture's Mach-O file, in bytes; big-endian.
  ///
  /// The corresponding C field is `size`.
  @_alwaysEmitIntoClient
  public var fileSize: UInt64 { size }

  /// The alignment of the architecture's Mach-O file in the fat file,
  /// as a power of two; big-endian.
  ///
  /// The corresponding C field is `align`.
  @_alwaysEmitIntoClient
  public var alignmentExponent: UInt32 { align }
}

// MARK: - Architecture names

// The dynamic loader's names for architectures, from mach-o/utils.h. The
// header declares them from macOS 13, iOS 16, tvOS 16 and watchOS 8, so
// the extension carries those floors as well as System 199's.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 8.0, tvOS 16.0, *)
extension MachOFile {
  /// Returns the name of the architecture that a processor type
  /// and subtype identify, such as `arm64e` or `x86_64`.
  ///
  /// - Parameters:
  ///   - cpuType: The processor type.
  ///   - cpuSubtype: The processor subtype, with its feature flags, if any.
  /// - Returns: The architecture's name,
  ///   or `nil` if the dynamic loader doesn't know the type and subtype.
  ///
  /// A Mach-O header's `cpuType` and `cpuSubtype` are in the file's
  /// byte order, and a fat file's architectures' are big-endian:
  /// swap them first where that isn't the host's.
  ///
  /// The corresponding C function is `macho_arch_name_for_cpu_type`.
  ///
  /// - Note: Provisional: Mach-O's architecture names may move to a library for object files.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func architectureName(
    cpuType: Mach.CPUType, cpuSubtype: Mach.CPUSubtype
  ) -> String? {
    _architectureName(cpuType: cpuType, cpuSubtype: cpuSubtype)
  }

  @usableFromInline
  internal static func _architectureName(
    cpuType: Mach.CPUType, cpuSubtype: Mach.CPUSubtype
  ) -> String? {
    system_macho_arch_name_for_cpu_type(cpuType.rawValue, cpuSubtype.rawValue)
      .map { String(cString: $0) }
  }

  /// Returns the name of the architecture that a Mach-O header's
  /// processor type and subtype identify.
  ///
  /// - Parameter header: The address of a 32-bit or a 64-bit Mach-O header
  ///   in the host's byte order, such as a loaded image's:
  ///   `#dsohandle`, or what
  ///   ``DynamicLibrary/loadedImageHeader(at:)`` returns.
  ///   The two headers' processor types and subtypes are in the same place.
  /// - Returns: The architecture's name,
  ///   or `nil` if the dynamic loader doesn't know it.
  ///
  /// The corresponding C function is `macho_arch_name_for_mach_header`.
  ///
  /// - Note: Provisional: Mach-O's architecture names may move to a library for object files.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func architectureName(ofHeaderAt header: UnsafeRawPointer) -> String? {
    _architectureName(ofHeaderAt: header)
  }

  @usableFromInline
  internal static func _architectureName(ofHeaderAt header: UnsafeRawPointer) -> String? {
    system_macho_arch_name_for_mach_header(header.assumingMemoryBound(to: mach_header.self))
      .map { String(cString: $0) }
  }

  /// The name of the program's architecture: its main executable's,
  /// such as `arm64e`, or `x86_64` for a program that Rosetta translates.
  ///
  /// It's `nil` if the dynamic loader doesn't know it.
  ///
  /// The corresponding C function is `macho_arch_name_for_mach_header`,
  /// called without a header.
  ///
  /// - Note: Provisional: Mach-O's architecture names may move to a library for object files.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var programArchitectureName: String? { _programArchitectureName }

  @usableFromInline
  internal static var _programArchitectureName: String? {
    system_macho_arch_name_for_mach_header(nil).map { String(cString: $0) }
  }

  /// Returns the processor type and subtype that an architecture's name
  /// identifies.
  ///
  ///     let arm64e = MachOFile.cpuType(forArchitectureName: "arm64e")
  ///     // arm64e?.cpuType == .arm64
  ///
  /// - Parameter name: An architecture's name, such as `arm64e` or `x86_64`.
  /// - Returns: The processor type and subtype,
  ///   or `nil` if the dynamic loader doesn't know the name.
  ///
  /// The corresponding C function is `macho_cpu_type_for_arch_name`.
  ///
  /// - Note: Provisional: Mach-O's architecture names may move to a library for object files.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func cpuType(
    forArchitectureName name: String
  ) -> (cpuType: Mach.CPUType, cpuSubtype: Mach.CPUSubtype)? {
    _cpuType(forArchitectureName: name)
  }

  @usableFromInline
  internal static func _cpuType(
    forArchitectureName name: String
  ) -> (cpuType: Mach.CPUType, cpuSubtype: Mach.CPUSubtype)? {
    var type: cpu_type_t = 0
    var subtype: cpu_subtype_t = 0
    guard name.withCString({ system_macho_cpu_type_for_arch_name($0, &type, &subtype) }) else {
      return nil
    }
    return (Mach.CPUType(rawValue: type), Mach.CPUSubtype(rawValue: subtype))
  }
}

/// A segment or section name: its 16 bytes up to the first NUL, if any.
@_alwaysEmitIntoClient
internal func _machOName<Field>(_ field: Field) -> String {
  withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
}

// MARK: - Protections

@available(System 199, *)
extension Mach.VirtualMemory {
  /// The access that a region of virtual memory allows,
  /// or the most it can ever allow,
  /// as a Mach-O segment's `initialProtection` and `maximumProtection` say.
  ///
  /// The corresponding C type is `vm_prot_t`.
  ///
  /// - Note: Provisional, with the Mach-O structures whose segments it describes;
  ///   its lasting home is Mach's virtual memory API, as here.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Protection: OptionSet, Sendable, Hashable {
    /// The raw C protection.
    @_alwaysEmitIntoClient
    public var rawValue: vm_prot_t

    /// Creates a strongly-typed protection from a raw C protection.
    @_alwaysEmitIntoClient
    public init(rawValue: vm_prot_t) { self.rawValue = rawValue }

    /// Reading.
    ///
    /// The corresponding C constant is `VM_PROT_READ`.
    @_alwaysEmitIntoClient
    public static var read: Protection { Protection(rawValue: _VM_PROT_READ) }

    /// Writing.
    ///
    /// The corresponding C constant is `VM_PROT_WRITE`.
    @_alwaysEmitIntoClient
    public static var write: Protection { Protection(rawValue: _VM_PROT_WRITE) }

    /// Running code.
    ///
    /// The corresponding C constant is `VM_PROT_EXECUTE`.
    @_alwaysEmitIntoClient
    public static var execute: Protection { Protection(rawValue: _VM_PROT_EXECUTE) }

    /// Reading and writing, which memory that the kernel allocates allows.
    ///
    /// The corresponding C constant is `VM_PROT_DEFAULT`.
    @_alwaysEmitIntoClient
    public static var `default`: Protection { [.read, .write] }

    /// Reading, writing, and running code.
    ///
    /// The corresponding C constant is `VM_PROT_ALL`.
    @_alwaysEmitIntoClient
    public static var all: Protection { [.read, .write, .execute] }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
