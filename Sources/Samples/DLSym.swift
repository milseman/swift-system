/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct DLSym: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "dlsym",
    abstract: "Look up symbols in a library, or in the program, and call a C function found that way"
  )

  @Option(name: .shortAndLong, help: "The library to load; the program itself if omitted")
  var library: String?

  @Argument(help: "Symbols to look up")
  var symbols: [String] = ["strlen", "no_such_symbol"]

  func run() throws {
    let handle: DynamicLibrary
    if let library {
      handle = try DynamicLibrary(FilePath(library))
      print("Loaded \(library)")
    } else {
      handle = try DynamicLibrary.mainProgram()
      print("Looking in the program and the libraries it started with")
    }
    for symbol in symbols {
      let address = handle.address(of: symbol)
      print("  \(symbol): \(address.map { "\($0)" } ?? "not found")")
    }

    // An address is only as good as the type it's cast to, which nothing checks.
    if let address = handle.address(of: "strlen") {
      let strlen = unsafeBitCast(address, to: (@convention(c) (UnsafePointer<CChar>) -> Int).self)
      print("strlen(\"dynamic\") through the lookup: \("dynamic".withCString { strlen($0) })")
    }

    // Closing reports an error, where dropping the library would ignore it.
    try handle.close()
  }
}

#else
struct DLSym: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "dlsym",
    abstract: "Unavailable: System has no dynamic loading on Windows or WASI"
  )

  func run() throws {
    complain("dlsym isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
