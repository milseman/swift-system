/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: OwnedFD sample. Handing ownership to C with `relinquish()`.

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

struct OwnedLines: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-lines",
    abstract: "Number the lines of a file by handing its OwnedFD to C stdio"
  )

  @Argument(help: "The file to read")
  var path: String

  func run() throws {
    let file = try OwnedFD.open(FilePath(path), .readOnly)

    // fdopen(3) takes ownership only if it succeeds, so pass it the raw
    // descriptor first and relinquish ownership afterward.
    guard let stream = file.withDescriptor(body: { fdopen($0.rawValue, "r") }) else {
      // `file` still owns the descriptor, and closes it on the way out.
      throw Errno(rawValue: errno)
    }
    // The stream owns the descriptor now; `fclose` closes it.
    _ = file.relinquish()
    defer { fclose(stream) }

    var line: UnsafeMutablePointer<CChar>? = nil
    var capacity = 0
    defer { free(line) }
    var number = 0
    while getline(&line, &capacity, stream) >= 0 {
      number += 1
      print("\(number): \(String(cString: line!))", terminator: "")
    }
  }
}
