/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Sparse: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Make a 1 GiB file that uses almost no storage, then map its data and holes"
  )

  @Argument(help: "Where to make a scratch file, which is removed afterward")
  var directory: String

  func run() throws {
    let path = FilePath(directory).appending("sparse-demo-\(ProcessID.current.rawValue)")
    let fd = try FileDescriptor.open(
      path, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    defer { try? path.unlink() }
    try fd.closeAfter {
      print("Created \(path)")
      // Growing a file doesn't write the new bytes. On a file system with
      // sparse files, they're a hole, which reads as zeros but uses no storage.
      try path.resize(to: 1 << 30)
      print("Resized it to 1 GiB by path: \(try usage(fd))")

      let message = Array("hello".utf8)
      _ = try message.withUnsafeBytes { try fd.write(toAbsoluteOffset: 512 << 20, $0) }
      print("Wrote \(message.count) bytes at 512 MiB: \(try usage(fd))")

      #if SYSTEM_PACKAGE_DARWIN
      // A hole can also be made in the middle of data, which frees its storage.
      // The range must be a multiple of the file system's block size;
      // otherwise the command throws EINVAL.
      let data = [UInt8](repeating: 0xAB, count: 1 << 20)
      _ = try data.withUnsafeBytes { try fd.write(toAbsoluteOffset: 0, $0) }
      print("Wrote 1 MiB at the start: \(try usage(fd))")
      var hole = FileDescriptor.ControlTypes.PunchHole(offset: 256 << 10, length: 512 << 10)
      try fd.control(.punchHole, &hole)
      print("Punched a hole in 256 KiB ..< 768 KiB with F_PUNCHHOLE: \(try usage(fd))")
      #endif

      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
      // Storage is allocated, and holes are found, in units of this size.
      if let holeSize = try SystemConfig.value(.minimumHoleSize, for: fd) {
        print("The file system's holes are multiples of \(amount(Int64(holeSize)))")
      }
      print("Its data and holes, found by seeking with SEEK_DATA and SEEK_HOLE:")
      let size = try fd.stat().size
      var offset: Int64 = 0
      for data in try dataRegions(fd, size: size) + [size..<size] {
        if offset < data.lowerBound {
          print("  hole  \(position(offset)) ..< \(position(data.lowerBound))")
        }
        if !data.isEmpty {
          print("  data  \(position(data.lowerBound)) ..< \(position(data.upperBound))")
        }
        offset = data.upperBound
      }
      #endif

      var bytes = [UInt8](repeating: 0xFF, count: 4)
      _ = try bytes.withUnsafeMutableBytes { try fd.read(fromAbsoluteOffset: 256 << 10, into: $0) }
      print("A hole reads as zeros: the 4 bytes at 256 KiB are \(bytes)")

      try fd.resize(to: 256 << 20)
      print("Resized it to 256 MiB, which cuts off the data at 512 MiB: \(try usage(fd))")

      // Preallocating is the opposite of a hole: storage without data,
      // so that later writes can't fail for lack of space.
      #if SYSTEM_PACKAGE_DARWIN
      var store = FileDescriptor.ControlTypes.Store(
        positionMode: .physicalEndOfFile, length: 8 << 20, flags: .allOrNone)
      try fd.control(.preallocate, &store)
      print("Preallocated \(amount(store.bytesAllocated)) with F_PREALLOCATE: \(try usage(fd))")
      #elseif os(Linux) || os(Android) || os(FreeBSD)
      try fd.allocateSpace(offset: 0, length: 8 << 20)
      print("Allocated the first 8 MiB with posix_fallocate: \(try usage(fd))")
      #endif
    }
  }
}

/// Describes a file's size and the storage allocated for it.
private func usage(_ fd: FileDescriptor) throws -> String {
  let status = try fd.stat()
  return "size \(amount(status.size)), \(amount(status.sizeAllocated)) allocated"
}

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
/// Returns the ranges of a file's offsets that hold data, rather than holes.
private func dataRegions(_ fd: FileDescriptor, size: Int64) throws -> [Range<Int64>] {
  var regions: [Range<Int64>] = []
  var offset: Int64 = 0
  while offset < size {
    let start: Int64
    do {
      start = try fd.seek(offset: offset, from: .nextData)
    } catch Errno.noSuchAddressOrDevice {
      // There's no data after the offset, only a hole to the end.
      break
    }
    let end = try fd.seek(offset: start, from: .nextHole)
    regions.append(start..<end)
    offset = end
  }
  return regions
}
#endif

/// Formats an offset in a file, which is a number of bytes.
private func position(_ offset: Int64) -> String {
  offset == 0 ? "0" : amount(offset)
}

/// Formats a number of bytes as a sum of units, such as "512 MiB + 4 KiB".
private func amount(_ bytes: Int64) -> String {
  var parts: [String] = []
  var rest = bytes
  for (unit, shift) in [("GiB", 30), ("MiB", 20), ("KiB", 10)] where rest >> shift > 0 {
    parts.append("\(rest >> shift) \(unit)")
    rest &= (1 << shift) - 1
  }
  if rest > 0 || parts.isEmpty { parts.append(rest == 1 ? "1 byte" : "\(rest) bytes") }
  return parts.joined(separator: " + ")
}
