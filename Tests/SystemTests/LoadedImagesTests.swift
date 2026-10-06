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
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Loaded images")
private struct LoadedImagesTests {
  /// The program and its libraries, at least two.
  @available(System 199, *)
  @Test func theProgramAndItsLibraries() {
    #expect(DynamicLibrary.loadedImageCount >= 2)
  }

  /// Loading a library that isn't loaded yet adds to the count. In an exit
  /// test, so that no other test loads or unloads anything meanwhile.
  @available(System 199, *)
  @Test func loadingALibraryAddsToTheCount() async {
    await #expect(processExitsWith: .success) {
      // Libraries a test process doesn't load by itself.
      let candidates: [FilePath] = [
        "/usr/lib/libsasl2.2.dylib", "/usr/lib/libpam.2.dylib", "/usr/lib/libexslt.0.dylib",
      ]
      func isLoaded(_ path: FilePath) -> Bool {
        guard let handle = try? DynamicLibrary(path, options: [.now, .noLoad]).relinquish()
        else { return false }
        _ = dlclose(handle)
        return true
      }
      for path in candidates where !isLoaded(path) {
        let before = DynamicLibrary.loadedImageCount
        guard let handle = try? DynamicLibrary(path).relinquish() else { continue }
        let after = DynamicLibrary.loadedImageCount
        _ = dlclose(handle)
        if after <= before { exit(1) }
        return
      }
      // Every candidate was loaded already, or none loads.
      exit(2)
    }
  }

  /// Image 0 is the program, an executable, and no image has an index past
  /// the count, or a negative one.
  @available(System 199, *)
  @Test func theProgramIsImageZero() throws {
    let program = try #require(DynamicLibrary.loadedImageHeader(at: 0))
    #expect(program.pointee.magicNumber == MachOFile.Magic.machHeader64)
    #expect(program.pointee.fileType == MachOFile.FileType.execute)
    #expect(DynamicLibrary.loadedImageHeader(at: -1) == nil)
    #expect(DynamicLibrary.loadedImageHeader(at: Int(UInt32.max) + 1) == nil)
    #expect(DynamicLibrary.loadedImageHeader(at: DynamicLibrary.loadedImageCount + 10_000) == nil)
  }

  /// The program's header names the program's architecture.
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 8.0, tvOS 16.0, *)
  @Test func theProgramsArchitecture() throws {
    let program = try #require(DynamicLibrary.loadedImageHeader(at: 0))
    #expect(MachOFile.architectureName(ofHeaderAt: program) == MachOFile.programArchitectureName)
  }

  /// The test image is among the loaded images, at the address of its own
  /// header. Another test can unload a library meanwhile, which can move
  /// the images after it, so a look that misses looks again.
  @available(System 199, *)
  @Test func theTestImageIsLoaded() {
    func look() -> Bool {
      (0..<DynamicLibrary.loadedImageCount).contains {
        UnsafeRawPointer(DynamicLibrary.loadedImageHeader(at: $0)) == #dsohandle
      }
    }
    #expect(look() || look() || look())
  }

  /// The test image's __TEXT,__text is where its load commands put it, plus
  /// the slide; its __swift5_proto, swift-syntax's section, is a table of
  /// 32-bit relative pointers; and a section it doesn't have is nil.
  @available(System 199, *)
  @Test func sectionsOfTheTestImage() throws {
    // Walk the mapped load commands for __TEXT and its __text section.
    let header = #dsohandle.loadUnaligned(as: CInterop.MachHeader64.self)
    var offset = MemoryLayout<CInterop.MachHeader64>.size
    var text: (segment: CInterop.SegmentCommand64, section: CInterop.Section64)? = nil
    for _ in 0..<header.loadCommandCount {
      let command = #dsohandle.loadUnaligned(fromByteOffset: offset, as: CInterop.LoadCommand.self)
      if command.commandType == MachOFile.LoadCommandType.segment64 {
        let segment = #dsohandle.loadUnaligned(
          fromByteOffset: offset, as: CInterop.SegmentCommand64.self)
        if segment.segmentName == "__TEXT" {
          for index in 0..<Int(segment.sectionCount) {
            let section = #dsohandle.loadUnaligned(
              fromByteOffset: offset + MemoryLayout<CInterop.SegmentCommand64>.size
                + index * MemoryLayout<CInterop.Section64>.size,
              as: CInterop.Section64.self)
            if section.sectionName == "__text" { text = (segment, section) }
          }
        }
      }
      offset += Int(command.commandSize)
    }
    let (segment, section) = try #require(text)
    // __TEXT maps the start of the file, so the header is at its address
    // plus the slide.
    let slide = Int(bitPattern: #dsohandle) - Int(segment.virtualAddress)
    let found = try #require(
      DynamicLibrary.sectionData(segment: "__TEXT", section: "__text", inImageAt: #dsohandle))
    #expect(Int(bitPattern: found.baseAddress) == slide + Int(section.address))
    #expect(found.count == Int(section.sectionSize))

    let conformances = try #require(
      DynamicLibrary.sectionData(segment: "__TEXT", section: "__swift5_proto", inImageAt: #dsohandle))
    #expect(conformances.count > 0 && conformances.count % 4 == 0)

    #expect(DynamicLibrary.sectionData(
      segment: "__TEXT", section: "__nosuchsection", inImageAt: #dsohandle) == nil)
    #expect(DynamicLibrary.sectionData(
      segment: "__NO_SUCH", section: "__text", inImageAt: #dsohandle) == nil)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
