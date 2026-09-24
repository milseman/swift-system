/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin

struct Extents: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show where a file's data is on its storage device, and read part of it in ahead of time"
  )

  @Argument(help: "Where to make a scratch file, which is removed afterward")
  var directory: String

  func run() throws {
    let path = FilePath(directory).appending("extents-demo-\(ProcessID.current.rawValue)")
    let file = try OwnedFD.open(
      path, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    defer { try? path.unlink() }
    // Most of this goes through fcntl, which OwnedFD doesn't forward.
    // The descriptor is valid until `file` is destroyed, at the end of run().
    let fd = file.fileDescriptor

    // With caching off, the data goes to the device without staying in
    // memory, which the read-ahead below then shows.
    try fd.setNoCache(true)
    let size: Int64 = 8 << 20
    let chunk = [UInt8](repeating: 0x5A, count: 1 << 20)
    for _ in 0..<(size >> 20) { try file.writeAll(chunk) }
    try fd.synchronize()
    print("Wrote \(amount(size)) with caching off, and flushed it. Its extents on the device:")
    let extents = try locate(fd, 0..<size)
    printTable(extents.map { extent in
      ["file \(position(extent.file.lowerBound)) ..< \(position(extent.file.upperBound))",
       deviceOffset(extent.device)]
    })

    // F_LOG2PHYS looks up the current offset, rather than a given one.
    let offset: Int64 = 3 << 20
    try fd.seek(offset: offset, from: .start)
    var location = FileDescriptor.ControlTypes.LogicalToPhysical()
    try fd.control(.logicalToPhysical, &location)
    let expected = extents.first { $0.file.contains(offset) }
      .map { $0.device + (offset - $0.file.lowerBound) }
    print("At the current offset, \(amount(offset)), F_LOG2PHYS reports "
      + deviceOffset(location.deviceOffset)
      + (location.deviceOffset == expected ? ", which matches the extents" : ""))

    // Growing the file makes a hole, which no storage backs.
    try fd.resize(to: 16 << 20)
    let hole: Int64 = 12 << 20
    print("Resized the file to 16 MiB: at \(amount(hole)), a hole, there's "
      + deviceOffset(try locate(fd, hole..<(hole + 4096))[0].device))

    // A cached write gets its storage when it's flushed.
    try fd.setNoCache(false)
    _ = try chunk.prefix(16 << 10).withUnsafeBytes { try fd.write(toAbsoluteOffset: hole, $0) }
    let beforeFlush = try locate(fd, hole..<(hole + 4096))[0].device
    try fd.synchronize()
    let afterFlush = try locate(fd, hole..<(hole + 4096))[0].device
    print("Wrote 16 KiB there with caching on: \(deviceOffset(beforeFlush)) before flushing, "
      + "then \(deviceOffset(afterFlush))")

    // System wraps neither mmap nor mincore, so this check comes from C.
    let pageSize = try SystemConfig.value(.pageSize) ?? 4096
    guard let map = mmap(nil, Int(size), PROT_READ, MAP_SHARED, fd.rawValue, 0),
      map != UnsafeMutableRawPointer(bitPattern: -1)
    else { throw Errno(rawValue: errno) }
    defer { munmap(map, Int(size)) }
    let pages = Int(size) / pageSize
    print("Of the first \(amount(size)), \(resident(map, pages: pages, pageSize: pageSize)) "
      + "of \(pages) pages are in memory")

    // The read-ahead starts reading into the cache, without waiting.
    var advisory = FileDescriptor.ControlTypes.ReadAdvisory(offset: 0, count: 4 << 20)
    try fd.control(.readAdvise, &advisory)
    var inMemory = resident(map, pages: pages, pageSize: pageSize)
    for _ in 0..<100 where inMemory < pages / 2 {
      usleep(10_000)
      inMemory = resident(map, pages: pages, pageSize: pageSize)
    }
    print("After F_RDADVISE for the first 4 MiB, \(inMemory) of \(pages) pages are in memory")
  }
}

/// Returns where each part of a range of a file is on its storage device,
/// merging parts that are contiguous there.
private func locate(
  _ fd: FileDescriptor, _ range: Range<Int64>
) throws -> [(file: Range<Int64>, device: Int64)] {
  var extents: [(file: Range<Int64>, device: Int64)] = []
  var offset = range.lowerBound
  while offset < range.upperBound {
    // The file offset to look up goes in the deviceOffset field, which the
    // command replaces with the location on the device.
    var location = FileDescriptor.ControlTypes.LogicalToPhysical(
      contiguousBytes: range.upperBound - offset, deviceOffset: offset)
    try fd.control(.logicalToPhysicalExtended, &location)
    let length = max(location.contiguousBytes, 1)
    if let last = extents.last, last.device >= 0,
      last.device + Int64(last.file.count) == location.deviceOffset
    {
      extents[extents.count - 1].file = last.file.lowerBound..<(offset + length)
    } else {
      extents.append((offset..<(offset + length), location.deviceOffset))
    }
    offset += length
  }
  return extents
}

/// Describes an offset on a device, where `-1` means no storage.
private func deviceOffset(_ offset: Int64) -> String {
  guard offset >= 0 else { return "no storage (-1)" }
  // Shifting binds more tightly than multiplying, hence the parentheses.
  let hundredths = ((offset & ((1 << 30) - 1)) * 100) >> 30
  return "\(offset >> 30).\(hundredths < 10 ? "0" : "")\(hundredths) GiB into the device"
}

/// Returns how many of a mapping's pages are in memory, as mincore reports.
private func resident(_ map: UnsafeMutableRawPointer, pages: Int, pageSize: Int) -> Int {
  var status = [CChar](repeating: 0, count: pages)
  _ = status.withUnsafeMutableBufferPointer { mincore(map, pages * pageSize, $0.baseAddress) }
  return status.filter { $0 & CChar(MINCORE_INCORE) != 0 }.count
}

#else

struct Extents: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no F_LOG2PHYS or F_RDADVISE"
  )

  func run() throws {
    complain("Error: extents needs fcntl's F_LOG2PHYS_EXT and F_RDADVISE, which only Darwin has")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
