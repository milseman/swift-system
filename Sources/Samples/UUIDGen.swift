/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct UUIDGen: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uuidgen",
    abstract: "Print random (version 4) UUIDs, made from the system's secure random bytes"
  )

  @Option(name: [.customShort("n"), .long], help: "How many UUIDs to print")
  var count: Int = 1

  func run() throws {
    // One call for all of them; Entropy splits it into getentropy's
    // 256-byte calls.
    let bytes = try Entropy.bytes(count: 16 * count)
    for start in stride(from: 0, to: bytes.count, by: 16) {
      var uuid = Array(bytes[start..<(start + 16)])
      uuid[6] = (uuid[6] & 0x0F) | 0x40  // version 4
      uuid[8] = (uuid[8] & 0x3F) | 0x80  // the RFC 9562 variant
      let hex = uuid.map { $0 < 16 ? "0" + String($0, radix: 16) : String($0, radix: 16) }
      print([hex[0..<4], hex[4..<6], hex[6..<8], hex[8..<10], hex[10..<16]]
        .map { $0.joined() }.joined(separator: "-").uppercased())
    }
  }
}

#else
struct UUIDGen: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uuidgen",
    abstract: "Unavailable: System has no getentropy on Windows or WASI"
  )

  func run() throws {
    complain("uuidgen isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
