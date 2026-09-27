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
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

struct ErrnoSample: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "errno",
    abstract: "Call C functions that System doesn't wrap, and turn their errno into thrown errors"
  )

  @Argument(help: "A directory to list with opendir and readdir")
  var directory: String = "."

  func run() throws {
    // A call that returns -1 and sets errno when it fails.
    var checked: Errno? = nil
    do {
      _ = try Errno.check { open("/nonexistent/file", O_RDONLY) }
    } catch {
      checked = error
      print("open(\"/nonexistent/file\") threw \"\(error)\"")
    }

    // A call that returns NULL when it fails, and one that returns NULL
    // both at the end and on an error, which checkOptional tells apart.
    let stream = try Errno.check { opendir(directory) }
    defer { closedir(stream) }
    var names: [String] = []
    while let entry = try Errno.checkOptional({ readdir(stream) }) {
      names.append(withUnsafeBytes(of: entry.pointee.d_name) {
        String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
      })
    }
    print("\(directory) has \(names.count) entries: \(names.sorted().prefix(8).joined(separator: " "))"
      + (names.count > 8 ? " ..." : ""))

    // getpriority can return -1 without failing, so only errno tells:
    // clear it, make the call, and read it right after.
    Errno.current = Errno(rawValue: 0)
    let priority = getpriority(PRIO_PROCESS, 0)
    let error = Errno.current
    if priority == -1 && error.rawValue != 0 { throw error }
    print("This process's nice value is \(priority)")

    // Reading errno later can see a different error: here a deinitializer
    // that runs between the call and the read makes a failing call itself.
    var holder: Holder? = Holder()
    let result = open("/nonexistent/file", O_RDONLY)
    withExtendedLifetime(holder) {}
    holder = nil
    let late = Errno.current
    print("open returned \(result) again, but errno read after a release says \"\(late)\","
      + " where Errno.check caught \"\(checked.map { "\($0)" } ?? "nothing")\"")
  }
}

/// A class whose deinitializer makes a system call that fails.
private final class Holder {
  deinit { _ = close(-1) }
}
