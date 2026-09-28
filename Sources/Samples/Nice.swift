/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Nice: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "nice",
    abstract: "Run a program at a lower priority, as nice(1) does, or print the priorities of this process, its group, and its user"
  )

  @Option(name: .customShort("n"), help: "How much to add to the nice value")
  var increment: Int = 10

  @Argument(parsing: .captureForPassthrough, help: "The program to run, and its arguments")
  var command: [String] = []

  func run() throws {
    guard let program = command.first else {
      // With no program, print the nice values, as nice(1) prints its own.
      let targets: [(String, ProcessPriority.Target)] = [
        ("process", .process(.current)),
        ("process group", .processGroup(.currentProcessGroup)),
        ("user", .user(.real)),
      ]
      for (name, target) in targets {
        print("\(name): \(try ProcessPriority.current(for: target))")
      }
      return
    }
    // The program inherits the nice value.
    let niceness = try ProcessPriority.adjust(by: increment)
    complain("running \(program) with a nice value of \(niceness)")
    try ProcessID.execute(searchingPathFor: FilePath(program), arguments: command)
  }
}

#else
struct Nice: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "nice",
    abstract: "Unavailable: System has no scheduling priorities on Windows or WASI"
  )

  func run() throws {
    complain("nice isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
