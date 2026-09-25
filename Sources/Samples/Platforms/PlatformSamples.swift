/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the platform-enum samples. See Simulation.swift for the two
// configurations, and Prototype/PlatformEnum/README.md for the findings.

import ArgumentParser

struct PlatformSamples: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "platform",
    abstract: "Cross-platform code over multi-platform enums, and the code around it (prototype)",
    discussion: """
      The default build is real: only this platform's cases exist. To compile \
      every platform's cases, over simulated Windows and Linux types, build with
        swift build --scratch-path /tmp/swift-system-sim -Xswiftc -DSIMULATE_PLATFORMS
      and run a sample with --as windows or --as linux to take the other \
      platforms' paths. See Prototype/PlatformEnum/README.md.
      """,
    subcommands: [
      PlatformCopy.self,
      PlatformLock.self,
      PlatformDarwinOnly.self,
      PlatformWindowsOnly.self,
    ])
}
