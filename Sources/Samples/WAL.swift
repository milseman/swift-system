/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct WAL: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "wal",
    abstract: "Keep an append-only log that survives a torn write, flushing each record in order"
  )

  @Argument(help: "Where to make a scratch log file, which is removed afterward")
  var directory: String

  @Argument(help: "The records to append")
  var records: [String] = ["deposit 100", "withdraw 30", "deposit 5"]

  func run() throws {
    let path = FilePath(directory).appending("wal-demo-\(ProcessID.current.rawValue).log")
    // Every write to a file opened for appending goes to its end,
    // wherever the file offset is.
    let log = try FileDescriptor.open(
      path, .readWrite, options: [.append, .create, .exclusiveCreate],
      permissions: .ownerReadWrite)
    defer { try? path.unlink() }
    try log.closeAfter {
      print("Appending to \(path), flushing after each record")
      for record in records {
        try append(record, to: log)
        print("  appended \"\(record)\"")
      }

      // A crash partway through an append leaves part of a record at the end.
      let torn = encode("deposit 1000000")
      _ = try torn.prefix(torn.count / 2).withUnsafeBytes { try log.write($0) }
      print("Wrote \(torn.count / 2) bytes of a \(torn.count)-byte record, as a crash during an append can")

      // Recovery keeps the records that are whole, and cuts off the rest.
      let valid = try replay(path)
      try log.resize(to: valid)
      try append("deposit 42", to: log)
      print("Cut the log back to \(valid) bytes, and appended \"deposit 42\"")
      _ = try replay(path)
    }

    #if SYSTEM_PACKAGE_DARWIN
    if #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) {
      try compareFlushes(in: FilePath(directory))
    }
    #endif
  }
}

/// Appends a record to the log, and flushes it before returning.
private func append(_ record: String, to log: FileDescriptor) throws {
  try log.writeAll(encode(record))
  #if SYSTEM_PACKAGE_DARWIN
  // The barrier makes the drive store the writes before it before any
  // writes after it, so after a crash the log holds a prefix of what was
  // appended: never a later record without an earlier one. It doesn't wait
  // for the drive to store the record, so the last records can be lost,
  // but only from the end.
  try log.synchronizeWithBarrier()
  #else
  // Without barriers, wait for the data to reach storage instead.
  try log.synchronizeData()
  #endif
}

/// Encodes a record as its length, a checksum, and its UTF-8 bytes.
private func encode(_ record: String) -> [UInt8] {
  let payload = Array(record.utf8)
  return littleEndianBytes(UInt32(payload.count)) + littleEndianBytes(checksum(payload)) + payload
}

/// Prints the whole records at the start of a log,
/// and returns the number of bytes they take.
private func replay(_ path: FilePath) throws -> Int64 {
  let bytes = try contents(of: path)
  print("Replaying \(bytes.count) bytes:")
  var offset = 0
  var number = 1
  while offset < bytes.count {
    // A header or payload cut short, or a checksum that doesn't match,
    // is a record torn by a crash.
    let header = bytes.dropFirst(offset).prefix(8)
    guard header.count == 8 else { break }
    let length = Int(littleEndianValue(header.prefix(4)))
    let payload = Array(bytes.dropFirst(offset + 8).prefix(length))
    guard payload.count == length, checksum(payload) == littleEndianValue(header.suffix(4)) else {
      break
    }
    print("  \(number): \(String(decoding: payload, as: UTF8.self))")
    offset += 8 + length
    number += 1
  }
  if offset < bytes.count {
    print("  then \(bytes.count - offset) bytes of a torn record")
  }
  return Int64(offset)
}

/// Returns the contents of a file.
private func contents(of path: FilePath) throws -> [UInt8] {
  let fd = try FileDescriptor.open(path, .readOnly)
  return try fd.closeAfter {
    var result: [UInt8] = []
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
      if count == 0 { return result }
      result += buffer[..<count]
    }
  }
}

/// The 32-bit FNV-1a hash of some bytes.
private func checksum(_ bytes: [UInt8]) -> UInt32 {
  bytes.reduce(2166136261) { ($0 ^ UInt32($1)) &* 16777619 }
}

private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
  (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
}

private func littleEndianValue(_ bytes: ArraySlice<UInt8>) -> UInt32 {
  bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
}

#if SYSTEM_PACKAGE_DARWIN
/// Times appends to a scratch log with each way to flush them.
@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
private func compareFlushes(in directory: FilePath) throws {
  let count = 50
  let flushes: [(name: String, flush: (FileDescriptor) throws -> Void)] = [
    // fsync hands the data to the drive, which can reorder or lose it.
    ("synchronize()", { try $0.synchronize() }),
    ("synchronizeWithBarrier()", { try $0.synchronizeWithBarrier() }),
    // F_FULLFSYNC waits until the drive has the data on permanent storage.
    ("synchronizeFully()", { try $0.synchronizeFully() }),
  ]
  print("Average time to append a record and flush it, over \(count) appends:")
  let path = directory.appending("wal-demo-\(ProcessID.current.rawValue)-timing.log")
  var rows: [[String]] = []
  for (name, flush) in flushes {
    let log = try FileDescriptor.open(
      path, .writeOnly, options: [.append, .create, .truncate], permissions: .ownerReadWrite)
    defer { try? path.unlink() }
    let record = encode("an entry of about fifty bytes, for the timing loop")
    let clock = ContinuousClock()
    let elapsed = try log.closeAfter {
      try clock.measure {
        for _ in 0..<count {
          try log.writeAll(record)
          try flush(log)
        }
      }
    }
    rows.append([name, milliseconds(elapsed / count)])
  }
  printTable(rows)
}

/// Formats a duration in milliseconds, to two decimal places.
@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
private func milliseconds(_ duration: Duration) -> String {
  let (seconds, attoseconds) = duration.components
  let hundredths = seconds * 100_000 + attoseconds / 10_000_000_000_000
  return "\(hundredths / 100).\(hundredths % 100 < 10 ? "0" : "")\(hundredths % 100) ms"
}
#endif
