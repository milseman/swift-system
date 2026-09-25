/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the platform-enum samples. Not API. The design write-up is
// Prototype/PlatformEnum/README.md.
//
// One source, two configurations:
//
// - Real, the default build. Each enum in `Platform` has only this
//   platform's cases, so on this Mac every file is `.fd` and every process
//   is `.id`, and each switch compiles as it would in a Darwin build.
// - Simulated, built with `-Xswiftc -DSIMULATE_PLATFORMS` (use a separate
//   `--scratch-path`). Every platform's cases exist on every platform.
//   Windows' cases wrap stand-ins for the Win32 drafts (`Platforms/StandIns`),
//   simulated over POSIX calls, and Linux's pidfd case wraps a stand-in
//   `ProcessDescriptor`. Pass `--as windows` or `--as linux` to make a
//   sample's factories produce those cases, so that the other platforms'
//   arms run too.
//
// How to read the conditions:
// - `#if os(Windows) || SIMULATE_PLATFORMS` is what real code would write as
//   `#if os(Windows)`, and `#if os(Linux) || SIMULATE_PLATFORMS` as
//   `#if os(Linux)`. Real code would write the Unix side as the `#else` of
//   the Windows condition; here it's a separate `#if !os(Windows)`, because
//   the simulated build compiles both sides.
// - Code under `#if SIMULATE_PLATFORMS` alone exists only to simulate.
//   Real code wouldn't have it.

import ArgumentParser

/// A platform whose representations a sample can produce.
enum SimulatedPlatform: String, CaseIterable, ExpressibleByArgument, Sendable {
  case darwin
  case linux
  case windows

  /// The platform this build runs on.
  static var host: SimulatedPlatform {
    #if os(Windows)
    return .windows
    #elseif os(Linux) || os(Android)
    return .linux
    #else
    return .darwin
    #endif
  }
}

/// The platform whose representations the samples' factories produce.
enum Simulation {
  /// Set once from `--as`, before a sample runs, and only read after that.
  nonisolated(unsafe) static var platform: SimulatedPlatform = .host

  /// Whether this is the simulated configuration.
  static var isSimulatedBuild: Bool {
    #if SIMULATE_PLATFORMS
    return true
    #else
    return false
    #endif
  }

  /// A line describing the configuration, which each sample prints first.
  static var banner: String {
    if isSimulatedBuild {
      return "[simulated build: every platform's cases exist; producing \(platform)'s]"
    }
    return "[real build: \(SimulatedPlatform.host)'s cases only]"
  }
}

/// The `--as` option that every platform sample takes.
struct SimulationOptions: ParsableArguments {
  @Option(
    name: .customLong("as"),
    help: ArgumentHelp(
      "The platform whose representations the sample produces (simulated builds only)",
      valueName: "platform"))
  var platform: SimulatedPlatform = .host

  func validate() throws {
    #if !SIMULATE_PLATFORMS
    guard platform == .host else {
      throw ValidationError(
        "This build has only \(SimulatedPlatform.host)'s cases. To run \(platform)'s, build with"
          + " -Xswiftc -DSIMULATE_PLATFORMS (see Sources/Samples/Platforms/Simulation.swift)")
    }
    #endif
  }

  /// Selects the platform and prints the banner.
  func apply() {
    Simulation.platform = platform
    print(Simulation.banner)
  }
}
