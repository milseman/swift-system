/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI) && !os(Android)

struct ConfStr: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "confstr",
    abstract: "Show the system's configuration strings: the default PATH and, on Darwin, the user's directories"
  )

  func run() throws {
    var names: [(String, SystemConfig.StringName)] = [("_CS_PATH", .defaultSearchPath)]
    #if SYSTEM_PACKAGE_DARWIN
    names += [
      ("_CS_DARWIN_USER_DIR", .userDirectory),
      ("_CS_DARWIN_USER_TEMP_DIR", .userTemporaryDirectory),
      ("_CS_DARWIN_USER_CACHE_DIR", .userCacheDirectory),
    ]
    #endif
    printTable(names.map { label, name in
      do {
        // A name without a value is nil, which confstr reports as 0 without
        // an error.
        return [label, try SystemConfig.string(name) ?? "(no value)"]
      } catch {
        return [label, "\(error)"]
      }
    })
  }
}

#else

struct ConfStr: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "confstr",
    abstract: "Unavailable: this platform has no confstr"
  )

  func run() throws {
    complain("Error: confstr needs a C library with confstr")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
