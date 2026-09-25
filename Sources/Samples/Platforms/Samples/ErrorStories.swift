/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: how the enums' common subset could throw, compared at the same
// two catch sites. Each design is a pair of functions: an operation as the
// enum would host it, and the code that classifies its error.
//
// - E1 untyped: `throws`, with each platform's own error coming through.
// - E2 Errno everywhere: `throws(Errno)`, converting Windows' errors with
//   SYS-0010's `Errno(approximating:)`.
// - E3 an error enum: `throws(PlatformErrorEnum)`, with a case per platform.
// - E4 the platform's own type: `throws(Platform.Error)`, which is Errno on
//   Unix and Win32.Error on Windows, what the enums in this prototype use.
//
// The two catch sites:
// 1. An open that another open refuses. Windows reports a sharing
//    violation, which is worth retrying, apart from access denied, which
//    isn't. (Unix has no share modes, so there it's only a demonstration of
//    permission denied.)
// 2. A write to a pipe whose reader has closed. Unix reports EPIPE, which
//    Errno calls `brokenPipe`. Windows reports ERROR_NO_DATA, which
//    Win32.Error calls `noData`; its `brokenPipe` is ERROR_BROKEN_PIPE, a
//    pipe whose writer went away. Errno's `noData` is ENODATA, unrelated.
//    Of the 222 Errno names and the drafts' 34 Win32.Error names, these are
//    two of the five shared ones, and the two that are false friends.
//
// The platform-specific codes are matched in a `switch` in a catch-all,
// since `#if` can't wrap catch clauses (V16e2), and the types are spelled
// out, since implicit members are ambiguous with both types' `~=` (V16f).

import ArgumentParser
import SystemPackage

struct PlatformErrors: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "errors",
    abstract: "Compare four ways Platform's common subset could throw, at the same catch sites"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "A directory for a scratch file")
  var directory: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let path = FilePath(directory).appending("platform-errors.state")

    print("1. Opening a file for writing while another open holds it")
    let holder = try holdExclusively(path)
    print("   E1 untyped:       \(outcome(classifyE1) { try openForWritingE1(path) })")
    print("   E2 Errno:         \(outcomeE2 { () throws(Errno) in try openForWritingE2(path) })")
    print("   E3 error enum:    \(outcomeE3 { () throws(PlatformErrorEnum) in try openForWritingE3(path) })")
    print("   E4 platform's:    \(outcome(classifyE4) { try openForWritingE4(path) })")
    try holder.close()

    print("2. Writing to a pipe whose reader has closed")
    print("   E1 untyped:       \(outcome(classifyPipeE1) { try writeToClosedPipeE1() })")
    print("   E2 Errno:         \(outcomePipeE2 { () throws(Errno) in try writeToClosedPipeE2() })")
    print("   E3 error enum:    \(outcomePipeE3 { () throws(PlatformErrorEnum) in try writeToClosedPipeE3() })")
    print("   E4 platform's:    \(outcome(classifyPipeE4) { try writeToClosedPipeE4() })")
    print("   E4, by shared name: \(outcome(classifyPipeBySharedName) { try writeToClosedPipeE4() })")
  }
}

// MARK: - The scenarios, on each platform's own API

/// Opens the file the way another program might: on Windows, with no
/// sharing, so that every other open fails while this is alive. Unix has no
/// share modes; there, the file is made read-only instead, so that an open
/// for writing fails too, with permission denied.
func holdExclusively(_ path: FilePath) throws -> Platform.File {
  #if SIMULATE_PLATFORMS
  if Simulation.platform == .windows {
    return .handle(try Win32.FileHandle.open(
      path, access: .genericRead, shareMode: [], disposition: .openAlways))
  }
  #endif
  #if os(Windows)
  return .handle(try Win32.FileHandle.open(
    path, access: .genericRead, shareMode: [], disposition: .openAlways))
  #else
  let file = try OwnedFD.open(
    path, .readOnly, options: [.create, .closeOnExec], permissions: .ownerRead)
  try file.fileDescriptor.setPermissions(.ownerRead)
  return .fd(file)
  #endif
}

/// A pipe whose reader has closed, and its writer.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func writeToClosedPipe() throws -> Void {
  #if SIMULATE_PLATFORMS
  if Simulation.platform == .windows {
    // Take both ends apart first: once one is consumed, a closure can't
    // capture the pipe to reach the other (V13d).
    let pipe = try Win32.FileHandle.createPipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try readEnd.close()
    try withSpan(of: "x") { try writeEnd.write($0) }
    return
  }
  #endif
  #if os(Windows)
  let pipe = try Win32.FileHandle.createPipe()
  let readEnd = pipe.readEnd
  let writeEnd = pipe.writeEnd
  try readEnd.close()
  try withSpan(of: "x") { try writeEnd.write($0) }
  #else
  let pipe = try OwnedFD.pipe()
  try pipe.readEnd.close()
  #if SYSTEM_PACKAGE_DARWIN
  // Unix raises SIGPIPE first, which would end this process.
  try pipe.writeEnd.fileDescriptor.setNoSigPipe(true)
  #endif
  try pipe.writeEnd.writeAll("x".utf8)
  #endif
}

// MARK: - E1: untyped, the platform's own errors

func openForWritingE1(_ path: FilePath) throws -> Platform.File {
  try Platform.File.open(path, .write)
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func writeToClosedPipeE1() throws {
  try writeToClosedPipe()
}

/// Each platform's codes, spelled with their types, under `#if`. The hazard:
/// on Windows, where Errno also exists, a forgotten Win32 case leaves the
/// Errno patterns compiling and never matching.
func classifyE1(_ error: any Error) -> String {
  switch error {
  case Errno.permissionDenied: return "denied: give up"
  #if os(Windows) || SIMULATE_PLATFORMS
  case Win32.Error.sharingViolation: return "busy: retry later"
  case Win32.Error.accessDenied: return "denied: give up"
  #endif
  default: return "unexpected: \(describe(error))"
  }
}

func classifyPipeE1(_ error: any Error) -> String {
  switch error {
  case Errno.brokenPipe: return "reader gone (EPIPE)"
  #if os(Windows) || SIMULATE_PLATFORMS
  case Win32.Error.noData: return "reader gone (ERROR_NO_DATA)"
  #endif
  default: return "unexpected: \(describe(error))"
  }
}

// MARK: - E2: Errno everywhere, approximated on Windows

/// Converts a Windows error with SYS-0010's lossy `Errno(approximating:)`.
func approximatingErrno<R: ~Copyable>(_ body: () throws -> R) throws(Errno) -> R {
  do {
    return try body()
  } catch let error as Errno {
    throw error
  } catch {
    #if os(Windows) || SIMULATE_PLATFORMS
    if let error = error as? Win32.Error { throw Errno(approximating: error) }
    #endif
    throw .invalidArgument
  }
}

func openForWritingE2(_ path: FilePath) throws(Errno) -> Platform.File {
  try approximatingErrno { try Platform.File.open(path, .write) }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func writeToClosedPipeE2() throws(Errno) {
  try approximatingErrno { try writeToClosedPipe() }
}

/// One set of patterns for every platform, typed, and no `#if`. But
/// ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION, and ERROR_ACCESS_DENIED
/// all approximate to EACCES, so "busy" and "denied" look the same.
func classifyE2(_ error: Errno) -> String {
  switch error {
  case Errno.permissionDenied: return "denied, or busy: EACCES can't say which"
  default: return "unexpected: \(describe(error))"
  }
}

/// ERROR_NO_DATA isn't in the C runtime's table, so it approximates to
/// EINVAL, not EPIPE.
func classifyPipeE2(_ error: Errno) -> String {
  switch error {
  case Errno.brokenPipe: return "reader gone (EPIPE)"
  default: return "unexpected: \(describe(error))"
  }
}

// MARK: - E3: an error enum with a case per platform

/// A multi-platform enum for errors, like the value enums.
enum PlatformErrorEnum: Error {
  #if !os(Windows)
  case errno(Errno)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case win32(Win32.Error)
  #endif

  /// Wraps whichever platform error `error` is. Every switch arm that calls
  /// a platform's API, in the enum and in its callers, needs this.
  init(_ error: any Error) {
    #if os(Windows) || SIMULATE_PLATFORMS
    if let error = error as? Win32.Error {
      self = .win32(error)
      return
    }
    #endif
    #if !os(Windows)
    self = .errno(error as? Errno ?? .invalidArgument)
    #endif
  }
}

func openForWritingE3(_ path: FilePath) throws(PlatformErrorEnum) -> Platform.File {
  do {
    return try Platform.File.open(path, .write)
  } catch {
    throw PlatformErrorEnum(error)
  }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func writeToClosedPipeE3() throws(PlatformErrorEnum) {
  do {
    try writeToClosedPipe()
  } catch {
    throw PlatformErrorEnum(error)
  }
}

/// Typed and lossless, but each pattern is a platform's, under `#if`.
func classifyE3(_ error: PlatformErrorEnum) -> String {
  switch error {
  #if !os(Windows)
  case .errno(Errno.permissionDenied): return "denied: give up"
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .win32(Win32.Error.sharingViolation): return "busy: retry later"
  case .win32(Win32.Error.accessDenied): return "denied: give up"
  #endif
  default: return "unexpected"
  }
}

func classifyPipeE3(_ error: PlatformErrorEnum) -> String {
  switch error {
  #if !os(Windows)
  case .errno(Errno.brokenPipe): return "reader gone (EPIPE)"
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .win32(Win32.Error.noData): return "reader gone (ERROR_NO_DATA)"
  #endif
  default: return "unexpected"
  }
}

// MARK: - E4: the platform's own type

/// No conversion: the enum's operation already throws Platform.Error.
func openForWritingE4(_ path: FilePath) throws(Platform.Error) -> Platform.File {
  try Platform.File.open(path, .write)
}

/// No conversion in a switch arm either, since each platform's API throws
/// its Platform.Error. (Here it's untyped only because `writeToClosedPipe`
/// calls `withSpan`, which rethrows.)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func writeToClosedPipeE4() throws {
  try writeToClosedPipe()
}

/// E1's patterns, against a typed error. In the simulated build every
/// platform's cases exist, so there's no one platform type, and this is E1.
func classifyE4(_ error: any Error) -> String {
  #if SIMULATE_PLATFORMS
  return classifyE1(error)
  #else
  guard let error = error as? Platform.Error else { return "unexpected: \(error)" }
  switch error {
  #if os(Windows)
  case Win32.Error.sharingViolation: return "busy: retry later"
  case Win32.Error.accessDenied: return "denied: give up"
  #else
  case Errno.permissionDenied: return "denied: give up"
  #endif
  default: return "unexpected: \(describe(error))"
  }
  #endif
}

func classifyPipeE4(_ error: any Error) -> String {
  classifyPipeE1(error)
}

/// The tempting cross-platform spelling: `Platform.Error.brokenPipe`, a name
/// both error types have, with no `#if`. In a real build it compiles on
/// both platforms, and on Windows it names ERROR_BROKEN_PIPE, so it misses
/// this error, ERROR_NO_DATA. The simulated build checks both platforms'
/// `brokenPipe` to show the same thing.
func classifyPipeBySharedName(_ error: any Error) -> String {
  #if SIMULATE_PLATFORMS
  switch error {
  case Errno.brokenPipe: return "matched Errno.brokenPipe"
  case Win32.Error.brokenPipe: return "matched Win32.Error.brokenPipe"
  default: return "missed: brokenPipe doesn't name \(describe(error))"
  }
  #else
  switch error {
  case Platform.Error.brokenPipe: return "matched Platform.Error.brokenPipe"
  default: return "missed: brokenPipe doesn't name \(describe(error))"
  }
  #endif
}

// MARK: - Running an operation and classifying its error

func outcome<R: ~Copyable>(_ classify: (any Error) -> String, _ body: () throws -> R) -> String {
  do {
    _ = try body()
    return "succeeded"
  } catch {
    return classify(error)
  }
}

func outcomeE2<R: ~Copyable>(_ body: () throws(Errno) -> R) -> String {
  do {
    _ = try body()
    return "succeeded"
  } catch {
    return classifyE2(error)
  }
}

func outcomePipeE2(_ body: () throws(Errno) -> Void) -> String {
  do {
    try body()
    return "succeeded"
  } catch {
    return classifyPipeE2(error)
  }
}

func outcomeE3<R: ~Copyable>(_ body: () throws(PlatformErrorEnum) -> R) -> String {
  do {
    _ = try body()
    return "succeeded"
  } catch {
    return classifyE3(error)
  }
}

func outcomePipeE3(_ body: () throws(PlatformErrorEnum) -> Void) -> String {
  do {
    try body()
    return "succeeded"
  } catch {
    return classifyPipeE3(error)
  }
}
