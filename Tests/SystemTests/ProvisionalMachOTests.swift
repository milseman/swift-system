/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// This file doesn't import MachO, or Darwin: it reads the structures as a
// client that imports only System does, through their accessors, under
// MemberImportVisibility. It reads the test image's own file, and never
// writes it.

/// Bytes from a file, read with pread until there are `count` or the file
/// ends.
@available(System 199, *)
private func read(_ count: Int, from fd: FileDescriptor, at offset: Int) throws -> [UInt8] {
  var bytes = [UInt8](repeating: 0, count: count)
  var filled = 0
  try bytes.withUnsafeMutableBytes { buffer in
    while filled < count {
      let read = try fd.read(
        fromAbsoluteOffset: Int64(offset + filled),
        into: UnsafeMutableRawBufferPointer(rebasing: buffer[filled...]))
      if read == 0 { break }
      filled += read
    }
  }
  return Array(bytes[..<filled])
}

/// The C string at an offset in a load command, which may be padded with
/// NULs to the command's end.
private func string(in command: UnsafeRawBufferPointer, at offset: Int) -> String? {
  guard offset < command.count else { return nil }
  let tail = command[offset...]
  guard let end = tail.firstIndex(of: 0) else { return nil }
  return String(decoding: tail[..<end], as: UTF8.self)
}

/// Bytes in the host's byte order, as a Mach-O file for the host has them.
private struct Builder {
  var bytes: [UInt8] = []
  mutating func append<T: FixedWidthInteger>(_ value: T) {
    withUnsafeBytes(of: value) { bytes += $0 }
  }
  mutating func append(bigEndian value: UInt32) { append(value.bigEndian) }
  mutating func append(bigEndian value: UInt64) { append(value.bigEndian) }
  mutating func append(name: String) {
    precondition(name.utf8.count <= 16)
    bytes += name.utf8 + [UInt8](repeating: 0, count: 16 - name.utf8.count)
  }
}

@Suite("Provisional Mach-O structures")
private struct ProvisionalMachOTests {
  @available(System 199, *)
  static var hostCPUType: Mach.CPUType {
    #if arch(arm64)
    .arm64
    #elseif arch(x86_64)
    .x86_64
    #endif
  }

  /// Where the slice for `cpuType` starts in the file: 0 for a thin file,
  /// or the offset that a fat file's header gives.
  @available(System 199, *)
  func sliceOffset(in fd: FileDescriptor, cpuType: Int32) throws -> Int {
    let start = try read(MemoryLayout<CInterop.FatHeader>.size, from: fd, at: 0)
    let fat = start.withUnsafeBytes { $0.loadUnaligned(as: CInterop.FatHeader.self) }
    let magic = UInt32(bigEndian: fat.magicNumber)
    guard magic == MachOFile.Magic.fatHeader || magic == MachOFile.Magic.fatHeader64 else {
      return 0
    }
    // A fat file's headers are big-endian.
    let count = Int(UInt32(bigEndian: fat.architectureCount))
    let is64 = magic == MachOFile.Magic.fatHeader64
    let stride = is64
      ? MemoryLayout<CInterop.FatArch64>.size : MemoryLayout<CInterop.FatArch>.size
    let table = try read(count * stride, from: fd, at: MemoryLayout<CInterop.FatHeader>.size)
    return try table.withUnsafeBytes { raw in
      for index in 0..<count {
        if is64 {
          let arch = raw.loadUnaligned(fromByteOffset: index * stride, as: CInterop.FatArch64.self)
          if Int32(bigEndian: arch.cpuType) == cpuType {
            return Int(UInt64(bigEndian: arch.fileOffset))
          }
        } else {
          let arch = raw.loadUnaligned(fromByteOffset: index * stride, as: CInterop.FatArch.self)
          if Int32(bigEndian: arch.cpuType) == cpuType {
            return Int(UInt32(bigEndian: arch.fileOffset))
          }
        }
      }
      throw Errno.noSuchFileOrDirectory
    }
  }

  /// The test image's file: its header is the one the loader mapped, and
  /// its load commands are what `otool -l` shows for a SwiftPM test bundle.
  @available(System 199, *)
  @Test func theTestImagesHeaderAndLoadCommands() throws {
    let image = try #require(DynamicLibrary.symbolInfo(containing: #dsohandle))
    // The loader maps the header and load commands where #dsohandle points.
    let loaded = #dsohandle.loadUnaligned(as: CInterop.MachHeader64.self)
    #expect(loaded.magicNumber == MachOFile.Magic.machHeader64)
    #expect(Mach.CPUType(rawValue: loaded.cpuType) == Self.hostCPUType)

    let fd = try FileDescriptor.open(image.libraryPath, .readOnly)
    defer { try? fd.close() }
    let slice = try sliceOffset(in: fd, cpuType: loaded.cpuType)
    let headerSize = MemoryLayout<CInterop.MachHeader64>.size
    let header = try read(headerSize, from: fd, at: slice)
      .withUnsafeBytes { $0.loadUnaligned(as: CInterop.MachHeader64.self) }
    #expect(header.magicNumber == MachOFile.Magic.machHeader64)
    #expect(header.cpuType == loaded.cpuType)
    #expect(header.cpuSubtype == loaded.cpuSubtype)
    #expect(header.fileType == loaded.fileType)
    #expect(header.loadCommandCount == loaded.loadCommandCount)
    #expect(header.loadCommandsSize == loaded.loadCommandsSize)
    #expect(header.headerFlags == loaded.headerFlags)
    // xctest loads SwiftPM's tests as a bundle.
    #expect(header.fileType == MachOFile.FileType.bundle)

    let commands = try read(Int(header.loadCommandsSize), from: fd, at: slice + headerSize)
    #expect(commands.count == Int(header.loadCommandsSize))
    let loadedCommands = UnsafeRawBufferPointer(
      start: #dsohandle + headerSize, count: Int(loaded.loadCommandsSize))
    var segments: [String: CInterop.SegmentCommand64] = [:]
    var sections: [String: CInterop.Section64] = [:]
    var libraries: [String: CInterop.Dylib] = [:]
    var runPaths: [String] = []
    var uuids: [[UInt8]] = []
    var buildVersions: [CInterop.BuildVersionCommand] = []
    var offset = 0
    try commands.withUnsafeBytes { raw in
      for _ in 0..<header.loadCommandCount {
        let base = raw.loadUnaligned(fromByteOffset: offset, as: CInterop.LoadCommand.self)
        let size = Int(base.commandSize)
        try #require(size >= MemoryLayout<CInterop.LoadCommand>.size)
        try #require(size % 8 == 0 && offset + size <= raw.count, "\(base.commandType)")
        let command = UnsafeRawBufferPointer(rebasing: raw[offset..<(offset + size)])
        // The loader mapped the same commands.
        #expect(command.elementsEqual(loadedCommands[offset..<(offset + size)]))
        switch base.commandType {
        case MachOFile.LoadCommandType.segment64:
          let segment = command.loadUnaligned(as: CInterop.SegmentCommand64.self)
          #expect(segment.commandType == base.commandType && segment.commandSize == base.commandSize)
          let segmentSize = MemoryLayout<CInterop.SegmentCommand64>.size
          let sectionSize = MemoryLayout<CInterop.Section64>.size
          #expect(size == segmentSize + Int(segment.sectionCount) * sectionSize)
          segments[segment.segmentName] = segment
          for index in 0..<Int(segment.sectionCount) {
            let section = command.loadUnaligned(
              fromByteOffset: segmentSize + index * sectionSize, as: CInterop.Section64.self)
            #expect(section.segmentName == segment.segmentName)
            sections[section.segmentName + "," + section.sectionName] = section
          }
        case MachOFile.LoadCommandType.loadDylib, MachOFile.LoadCommandType.loadWeakDylib,
          MachOFile.LoadCommandType.reexportDylib, MachOFile.LoadCommandType.loadUpwardDylib,
          MachOFile.LoadCommandType.lazyLoadDylib:
          let dylib = command.loadUnaligned(as: CInterop.DylibCommand.self)
          #expect(dylib.commandType == base.commandType && dylib.commandSize == base.commandSize)
          let name = try #require(string(in: command, at: Int(dylib.library.nameOffset)))
          libraries[name] = dylib.library
        case MachOFile.LoadCommandType.uuid:
          let uuid = command.loadUnaligned(as: CInterop.UUIDCommand.self)
          #expect(uuid.commandSize == UInt32(MemoryLayout<CInterop.UUIDCommand>.size))
          uuids.append(withUnsafeBytes(of: uuid.uuidBytes) { Array($0) })
        case MachOFile.LoadCommandType.rpath:
          let rpath = command.loadUnaligned(as: CInterop.RPathCommand.self)
          #expect(rpath.commandType == base.commandType)
          runPaths.append(try #require(string(in: command, at: Int(rpath.pathOffset))))
        case MachOFile.LoadCommandType.buildVersion:
          let version = command.loadUnaligned(as: CInterop.BuildVersionCommand.self)
          // The structure, then a build_tool_version (two UInt32s) per tool.
          #expect(size == MemoryLayout<CInterop.BuildVersionCommand>.size
            + Int(version.toolCount) * 8)
          buildVersions.append(version)
        default:
          break
        }
        offset += size
      }
    }
    #expect(offset == Int(header.loadCommandsSize))

    // __TEXT maps the start of the file, headers and all, to read and run.
    let text = try #require(segments["__TEXT"])
    #expect(text.fileOffset == 0 && text.fileSize > 0 && text.virtualSize >= text.fileSize)
    #expect(Mach.VirtualMemory.Protection(rawValue: text.initialProtection) == [.read, .execute])
    #expect(Mach.VirtualMemory.Protection(rawValue: text.maximumProtection).contains(.read))
    #expect(text.sectionCount > 0)
    let linkEdit = try #require(segments["__LINKEDIT"])
    #expect(Mach.VirtualMemory.Protection(rawValue: linkEdit.initialProtection) == .read)
    #expect(linkEdit.sectionCount == 0)

    // The code, inside __TEXT in the file and in memory, without relocations.
    let code = try #require(sections["__TEXT,__text"])
    #expect(code.sectionSize > 0 && code.alignmentExponent <= 15)
    #expect(UInt64(code.fileOffset) >= text.fileOffset)
    #expect(UInt64(code.fileOffset) + code.sectionSize <= text.fileOffset + text.fileSize)
    #expect(code.address >= text.virtualAddress)
    #expect(code.address + code.sectionSize <= text.virtualAddress + text.virtualSize)
    #expect(code.relocationCount == 0)

    // Every image links to libSystem.
    let libSystem = try #require(libraries["/usr/lib/libSystem.B.dylib"])
    #expect(libSystem.compatibilityVersion >= 1 << 16)  // 1.0.0
    #expect(libSystem.currentVersion >= libSystem.compatibilityVersion)

    #expect(uuids.count == 1)
    #expect(uuids.first?.contains { $0 != 0 } == true)
    #expect(!runPaths.isEmpty && runPaths.allSatisfy { !$0.isEmpty })
    let build = try #require(buildVersions.first)
    #expect(build.targetPlatform == 1)  // PLATFORM_MACOS
    #expect(build.minimumOSVersion >= 10 << 16)  // 10.0.0
    #expect(build.sdkVersion >= build.minimumOSVersion || build.sdkVersion == 0)
  }

  /// A fat header and its architectures, big-endian, laid over bytes built
  /// in memory.
  @available(System 199, *)
  @Test func fatHeadersAreBigEndian() {
    var fat32 = Builder()
    fat32.append(bigEndian: MachOFile.Magic.fatHeader)
    fat32.append(bigEndian: UInt32(1))
    fat32.append(bigEndian: UInt32(bitPattern: Mach.CPUType.arm64.rawValue))
    fat32.append(bigEndian: UInt32(0))
    fat32.append(bigEndian: UInt32(0x4000))
    fat32.append(bigEndian: UInt32(0x1234))
    fat32.append(bigEndian: UInt32(14))
    #expect(fat32.bytes.count
      == MemoryLayout<CInterop.FatHeader>.size + MemoryLayout<CInterop.FatArch>.size)
    fat32.bytes.withUnsafeBytes { raw in
      let header = raw.loadUnaligned(as: CInterop.FatHeader.self)
      #expect(UInt32(bigEndian: header.magicNumber) == MachOFile.Magic.fatHeader)
      #if _endian(little)
      #expect(header.magicNumber == MachOFile.Magic.swappedFatHeader)
      #endif
      #expect(UInt32(bigEndian: header.architectureCount) == 1)
      let arch = raw.loadUnaligned(
        fromByteOffset: MemoryLayout<CInterop.FatHeader>.size, as: CInterop.FatArch.self)
      #expect(Int32(bigEndian: arch.cpuType) == Mach.CPUType.arm64.rawValue)
      #expect(Int32(bigEndian: arch.cpuSubtype) == 0)
      #expect(UInt32(bigEndian: arch.fileOffset) == 0x4000)
      #expect(UInt32(bigEndian: arch.fileSize) == 0x1234)
      #expect(UInt32(bigEndian: arch.alignmentExponent) == 14)
    }

    var fat64 = Builder()
    fat64.append(bigEndian: MachOFile.Magic.fatHeader64)
    fat64.append(bigEndian: UInt32(1))
    fat64.append(bigEndian: UInt32(bitPattern: Mach.CPUType.x86_64.rawValue))
    fat64.append(bigEndian: UInt32(3))
    fat64.append(bigEndian: UInt64(1) << 33)
    fat64.append(bigEndian: UInt64(0x5678))
    fat64.append(bigEndian: UInt32(12))
    fat64.append(bigEndian: UInt32(0))  // reserved
    #expect(fat64.bytes.count
      == MemoryLayout<CInterop.FatHeader>.size + MemoryLayout<CInterop.FatArch64>.size)
    fat64.bytes.withUnsafeBytes { raw in
      let header = raw.loadUnaligned(as: CInterop.FatHeader.self)
      #expect(UInt32(bigEndian: header.magicNumber) == MachOFile.Magic.fatHeader64)
      #if _endian(little)
      #expect(header.magicNumber == MachOFile.Magic.swappedFatHeader64)
      #endif
      let arch = raw.loadUnaligned(
        fromByteOffset: MemoryLayout<CInterop.FatHeader>.size, as: CInterop.FatArch64.self)
      #expect(Int32(bigEndian: arch.cpuType) == Mach.CPUType.x86_64.rawValue)
      #expect(Int32(bigEndian: arch.cpuSubtype) == 3)
      #expect(UInt64(bigEndian: arch.fileOffset) == 1 << 33)
      #expect(UInt64(bigEndian: arch.fileSize) == 0x5678)
      #expect(UInt32(bigEndian: arch.alignmentExponent) == 12)
    }
  }

  /// The 32-bit structures, which no binary for this host has, laid over a
  /// 32-bit object file built in memory: a header, a segment with one
  /// section, and a minimum-version command.
  @available(System 199, *)
  @Test func thirtyTwoBitStructures() {
    let segmentSize = MemoryLayout<CInterop.SegmentCommand>.size
    let sectionSize = MemoryLayout<CInterop.Section>.size
    let versionSize = MemoryLayout<CInterop.VersionMinCommand>.size
    var file = Builder()
    file.append(MachOFile.Magic.machHeader)
    file.append(Mach.CPUType.arm.rawValue)
    file.append(Int32(9))  // CPU_SUBTYPE_ARM_V7
    file.append(MachOFile.FileType.object)
    file.append(UInt32(2))
    file.append(UInt32(segmentSize + sectionSize + versionSize))
    file.append(UInt32(0x2000))  // MH_SUBSECTIONS_VIA_SYMBOLS
    #expect(file.bytes.count == MemoryLayout<CInterop.MachHeader>.size)
    file.append(MachOFile.LoadCommandType.segment)
    file.append(UInt32(segmentSize + sectionSize))
    file.append(name: "")  // an object file's one segment has no name
    file.append(UInt32(0))  // vmaddr
    file.append(UInt32(0x10))  // vmsize
    file.append(UInt32(0x100))  // fileoff
    file.append(UInt32(0x10))  // filesize
    file.append(Int32(7))  // maxprot
    file.append(Int32(5))  // initprot
    file.append(UInt32(1))  // nsects
    file.append(UInt32(0))  // flags
    file.append(name: "__text")
    file.append(name: "__TEXT")
    file.append(UInt32(0))  // addr
    file.append(UInt32(0x10))  // size
    file.append(UInt32(0x100))  // offset
    file.append(UInt32(2))  // align
    file.append(UInt32(0x110))  // reloff
    file.append(UInt32(3))  // nreloc
    file.append(UInt32(0x8000_0400))  // S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS
    file.append(UInt32(0))  // reserved1
    file.append(UInt32(0))  // reserved2
    file.append(MachOFile.LoadCommandType.versionMinMacOS)
    file.append(UInt32(versionSize))
    file.append(UInt32(0x000a_0e00))  // 10.14
    file.append(UInt32(0x000a_0e04))  // 10.14.4

    file.bytes.withUnsafeBytes { raw in
      let header = raw.loadUnaligned(as: CInterop.MachHeader.self)
      #expect(header.magicNumber == MachOFile.Magic.machHeader)
      #expect(header.magicNumber.byteSwapped == MachOFile.Magic.swappedMachHeader)
      #expect(Mach.CPUType(rawValue: header.cpuType) == .arm)
      #expect(header.cpuSubtype == 9)
      #expect(header.fileType == MachOFile.FileType.object)
      #expect(header.loadCommandCount == 2)
      #expect(Int(header.loadCommandsSize) == raw.count - MemoryLayout<CInterop.MachHeader>.size)
      #expect(header.headerFlags == 0x2000)

      var offset = MemoryLayout<CInterop.MachHeader>.size
      let segment = raw.loadUnaligned(fromByteOffset: offset, as: CInterop.SegmentCommand.self)
      #expect(segment.commandType == MachOFile.LoadCommandType.segment)
      #expect(Int(segment.commandSize) == segmentSize + sectionSize)
      #expect(segment.segmentName == "")
      #expect(segment.virtualAddress == 0 && segment.virtualSize == 0x10)
      #expect(segment.fileOffset == 0x100 && segment.fileSize == 0x10)
      #expect(Mach.VirtualMemory.Protection(rawValue: segment.maximumProtection) == .all)
      #expect(
        Mach.VirtualMemory.Protection(rawValue: segment.initialProtection) == [.read, .execute])
      #expect(segment.sectionCount == 1 && segment.segmentFlags == 0)

      let section = raw.loadUnaligned(
        fromByteOffset: offset + segmentSize, as: CInterop.Section.self)
      #expect(section.sectionName == "__text" && section.segmentName == "__TEXT")
      #expect(section.address == 0 && section.sectionSize == 0x10)
      #expect(section.fileOffset == 0x100 && section.alignmentExponent == 2)
      #expect(section.relocationsOffset == 0x110 && section.relocationCount == 3)
      #expect(section.sectionFlags == 0x8000_0400)
      offset += Int(segment.commandSize)

      let version = raw.loadUnaligned(fromByteOffset: offset, as: CInterop.VersionMinCommand.self)
      #expect(version.commandType == MachOFile.LoadCommandType.versionMinMacOS)
      #expect(Int(version.commandSize) == versionSize)
      #expect(version.minimumOSVersion == 0x000a_0e00 && version.sdkVersion == 0x000a_0e04)
    }
  }

  /// A name that fills all 16 bytes has no NUL.
  @available(System 199, *)
  @Test func namesOfSixteenBytes() {
    var bytes = Builder()
    bytes.append(name: "__sixteen_bytes_")
    bytes.append(name: "__DATA_CONST")
    bytes.bytes += [UInt8](repeating: 0, count: MemoryLayout<CInterop.Section64>.size - 32)
    let section = bytes.bytes.withUnsafeBytes { $0.loadUnaligned(as: CInterop.Section64.self) }
    #expect(section.sectionName == "__sixteen_bytes_")
    #expect(section.segmentName == "__DATA_CONST")
  }

  /// The structures' sizes, and the constants' values, are <mach-o/loader.h>'s.
  @available(System 199, *)
  @Test func sizesAndConstants() {
    #expect(MemoryLayout<CInterop.MachHeader>.size == 28)
    #expect(MemoryLayout<CInterop.MachHeader64>.size == 32)
    #expect(MemoryLayout<CInterop.LoadCommand>.size == 8)
    #expect(MemoryLayout<CInterop.SegmentCommand>.size == 56)
    #expect(MemoryLayout<CInterop.SegmentCommand64>.size == 72)
    #expect(MemoryLayout<CInterop.Section>.size == 68)
    #expect(MemoryLayout<CInterop.Section64>.size == 80)
    #expect(MemoryLayout<CInterop.DylibCommand>.size == 24)
    #expect(MemoryLayout<CInterop.UUIDCommand>.size == 24)
    #expect(MemoryLayout<CInterop.RPathCommand>.size == 12)
    #expect(MemoryLayout<CInterop.BuildVersionCommand>.size == 24)
    #expect(MemoryLayout<CInterop.VersionMinCommand>.size == 16)
    #expect(MemoryLayout<CInterop.FatHeader>.size == 8)
    #expect(MemoryLayout<CInterop.FatArch>.size == 20)
    #expect(MemoryLayout<CInterop.FatArch64>.size == 32)

    #expect(MachOFile.Magic.machHeader == 0xfeed_face)
    #expect(MachOFile.Magic.swappedMachHeader == 0xcefa_edfe)
    #expect(MachOFile.Magic.machHeader64 == 0xfeed_facf)
    #expect(MachOFile.Magic.swappedMachHeader64 == 0xcffa_edfe)
    #expect(MachOFile.Magic.fatHeader == 0xcafe_babe)
    #expect(MachOFile.Magic.swappedFatHeader == 0xbeba_feca)
    #expect(MachOFile.Magic.fatHeader64 == 0xcafe_babf)
    #expect(MachOFile.Magic.swappedFatHeader64 == 0xbfba_feca)
    #expect([
      MachOFile.FileType.object, MachOFile.FileType.execute, MachOFile.FileType.dylib,
      MachOFile.FileType.bundle,
    ] == [1, 2, 6, 8])
    typealias Command = MachOFile.LoadCommandType
    #expect([
      Command.segment, Command.loadDylib, Command.idDylib, Command.loadWeakDylib,
      Command.segment64, Command.uuid, Command.rpath, Command.reexportDylib,
      Command.lazyLoadDylib, Command.loadUpwardDylib, Command.versionMinMacOS,
      Command.versionMinIOS, Command.versionMinTVOS, Command.versionMinWatchOS,
      Command.buildVersion,
    ] == [
      0x1, 0xc, 0xd, 0x8000_0018, 0x19, 0x1b, 0x8000_001c, 0x8000_001f, 0x20, 0x8000_0023,
      0x24, 0x25, 0x2f, 0x30, 0x32,
    ])
    #expect(MachOFile.ArchiveMemberName.symbolTable == "__.SYMDEF")
    #expect(MachOFile.ArchiveMemberName.sortedSymbolTable == "__.SYMDEF SORTED")
    #expect(MachOFile.ArchiveMemberName.symbolTable64 == "__.SYMDEF_64")
    #expect(MachOFile.ArchiveMemberName.sortedSymbolTable64 == "__.SYMDEF_64 SORTED")

    typealias Protection = Mach.VirtualMemory.Protection
    #expect([Protection.read, .write, .execute].map(\.rawValue) == [1, 2, 4])
    #expect(Protection.default == [.read, .write])
    #expect(Protection.all.rawValue == 7)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
