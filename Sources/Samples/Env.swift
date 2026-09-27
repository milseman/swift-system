/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Env: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "env",
    abstract: "Change the environment, as env(1) does before it runs a command, and print the result"
  )

  @Option(name: .shortAndLong, help: "A variable to remove first; repeat for more")
  var unset: [String] = []

  @Flag(name: .shortAndLong, help: "Start from an empty environment")
  var ignoreEnvironment = false

  @Argument(help: "NAME=value settings to apply, then NAMEs to print (all, if none)")
  var arguments: [String] = []

  func run() throws {
    if ignoreEnvironment {
      for (name, _) in ProcessEnvironment.entries() {
        try ProcessEnvironment.remove(name)
      }
    }
    for name in unset {
      try ProcessEnvironment.remove(name)
    }
    // Settings come first, as for env(1); the rest are names to print.
    let settings = arguments.prefix { $0.contains("=") }
    for setting in settings {
      let equals = setting.firstIndex(of: "=")!
      try ProcessEnvironment.set(
        String(setting[..<equals]), to: String(setting[setting.index(after: equals)...]))
    }

    let names = arguments.dropFirst(settings.count)
    if names.isEmpty {
      for (name, value) in ProcessEnvironment.entries() {
        print("\(name)=\(value)")
      }
    } else {
      for name in names {
        print("\(name)=\(ProcessEnvironment.value(of: name).map(\.debugDescription) ?? "(unset)")")
      }
    }

    // The C array is what a new program receives, so count what the
    // string view can't show: entries that aren't valid UTF-8, or aren't
    // NAME=value at all.
    let (count, odd) = ProcessEnvironment.withUnsafeEntries { entries -> (Int, Int) in
      var count = 0, odd = 0
      var entry = entries
      while let pointer = entry.pointee {
        count += 1
        if String(validatingPlatformString: pointer)?.contains("=") != true { odd += 1 }
        entry += 1
      }
      return (count, odd)
    }
    complain("\(count) entries for a new program, \(odd) of them not valid NAME=value UTF-8")
  }
}

#else
struct Env: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "env",
    abstract: "Unavailable: System has no environment API on Windows or WASI"
  )

  func run() throws {
    complain("env isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
