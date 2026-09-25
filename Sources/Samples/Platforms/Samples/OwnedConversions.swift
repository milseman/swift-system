/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 5: the owned enum's ownership, end to end.
//
// - Into the enum: the case constructors are the conversions, `.fd(owner)`
//   and `.handle(handle)`, so the enum needs no initializers.
// - Lending: `borrowing Platform.File` parameters, with a borrowing switch
//   inside, including over the standard-input static.
// - Out of the enum: a consuming switch per platform, which is exhaustive in
//   a real build, and a failable accessor that closes what it doesn't
//   return. A Narrowing result, as the Sketch proposed for sub-types, hands
//   the original back instead.
// - Across the platform types: on Windows, SYS-0011's bridges turn a handle
//   into a C runtime descriptor that owns it (`FileDescriptor(adopting:)`),
//   and lend a descriptor's handle (`withWin32HandleIfAvailable`). Owning a
//   descriptor's handle takes a duplicate.
// - Closing: explicitly through the enum, or implicitly, dropping errors,
//   when the enum is destroyed.

import ArgumentParser
import SystemPackage

struct PlatformOwned: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned",
    abstract: "Convert, lend, take apart, and close owned Platform.File values"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "A scratch file, which is created or truncated")
  var path: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let path = FilePath(path)

    // Into the enum: open a platform owner, and wrap it in its case.
    let file = try wrapNativeOwner(path)
    print("wrapped: \(file.summary)")

    // Lending: borrowing parameters, and borrowing switches inside them.
    try withSpan(of: "hello\n") { try file.write($0) }
    print("size, through a borrowing parameter: \(try describeSize(of: file))")
    print("standard input: \(describeStandardInput())")

    // Out of the enum: a Narrowing result hands the original back when the
    // case isn't this platform's owner.
    let other = try Platform.File.open(path, .read)
    switch other.narrowToNativeOwner() {
    case .narrowed(let native):
      print("narrowed to the platform's owner: \(describe(native))")
      try closeNative(native)
    case .notNarrowed(let original):
      print("not this platform's owner: kept \(original.summary)")
      try original.close()
    }

    // A failable accessor can't: it destroys, and so closes, the owner it
    // doesn't return.
    let third = try Platform.File.open(path, .read)
    let summary = third.summary
    if let native = third.nativeOwner() {
      print("nativeOwner() returned \(describe(native))")
      try closeNative(native)
    } else {
      print("nativeOwner() returned nil, and closed \(summary) on the way")
    }

    // Across the platform types, and back into the enum.
    let converted = try convertAcrossPlatformTypes(file)
    print("after converting: \(converted.summary)")

    // Closing through the enum reports errors; destroying it drops them.
    try converted.close()
    let dropped = try Platform.File.open(path, .read)
    print("destroying \(dropped.summary) closes it, and drops any error")
    _ = consume dropped
  }
}

// MARK: - Into the enum

#if !os(Windows)
/// The platform's owner, outside the enum: what single-platform code uses.
typealias NativeOwner = OwnedFD
#else
typealias NativeOwner = Win32.FileHandle
#endif

/// Opens the file with the platform's own API, then wraps it.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func wrapNativeOwner(_ path: FilePath) throws -> Platform.File {
  #if SIMULATE_PLATFORMS
  if Simulation.platform == .windows {
    let handle = try Win32.FileHandle.open(
      path, access: [.genericRead, .genericWrite], disposition: .createAlways)
    return .handle(handle)  // the case constructor is the conversion
  }
  #endif
  #if os(Windows)
  let handle = try Win32.FileHandle.open(
    path, access: [.genericRead, .genericWrite], disposition: .createAlways)
  return .handle(handle)
  #else
  let owner = try OwnedFD.open(
    path, .readWrite, options: [.create, .truncate, .closeOnExec],
    permissions: FilePermissions(rawValue: 0o644))
  return .fd(owner)  // the case constructor is the conversion
  #endif
}

// MARK: - Lending

/// A borrowing parameter, and a borrowing switch over it.
func describeSize(of file: borrowing Platform.File) throws -> String {
  let size = try file.size()
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    return "\(size) bytes, fd \(owner.fileDescriptor.rawValue)"
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    return "\(size) bytes, a \(try handle.fileType()) handle"
  #endif
  }
}

/// A borrowing switch over the standard-input static. Both levels are
/// switches: `if let` or `if case` would consume the static (V16c).
func describeStandardInput() -> String {
  switch Platform.File.standardInput {
  case .some(let input):
    switch input {
    #if !os(Windows)
    case .fd(let owner):
      return "\(input.summary), \(owner.fileDescriptor.isTerminal ? "a" : "not a") terminal"
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      // SYS-0012: a console is a character device, like NUL.
      let type = (try? handle.fileType())?.description ?? "unknown"
      return "\(input.summary), a \(type) device"
    #endif
    }
  case .none:
    return "none"
  }
}

// MARK: - Out of the enum

enum Narrowing<Narrowed: ~Copyable, Original: ~Copyable>: ~Copyable {
  case narrowed(Narrowed)
  case notNarrowed(Original)
}

extension Platform.File {
  /// The platform's owner, or `nil`, destroying (and closing) any other case.
  ///
  /// A consuming switch can only return the payload it matched; every other
  /// case's owner is destroyed at the end of its arm (V16b). In a real
  /// build this platform has one case, so the `nil` never happens, until a
  /// case is added (V16a).
  consuming func nativeOwner() -> NativeOwner? {
    switch consume self {
    #if !os(Windows)
    case .fd(let owner):
      return owner
    #endif
    #if SIMULATE_PLATFORMS
    case .handle:
      return nil  // the handle closes here
    #endif
    #if os(Windows)
    case .handle(let handle):
      return handle
    #endif
    }
  }

  /// The platform's owner, or this enum back, unharmed.
  consuming func narrowToNativeOwner() -> Narrowing<NativeOwner, Platform.File> {
    switch consume self {
    #if !os(Windows)
    case .fd(let owner):
      return .narrowed(owner)
    #endif
    #if SIMULATE_PLATFORMS
    case .handle(let handle):
      return .notNarrowed(.handle(handle))
    #endif
    #if os(Windows)
    case .handle(let handle):
      return .narrowed(handle)
    #endif
    }
  }
}

func describe(_ native: borrowing NativeOwner) -> String {
  #if !os(Windows)
  return "OwnedFD(\(native.fileDescriptor.rawValue))"
  #else
  return "Win32.FileHandle"
  #endif
}

func closeNative(_ native: consuming NativeOwner) throws {
  try native.close()
}

// MARK: - Across the platform types

/// Converts the file to the other ownership forms its platform has, and
/// back into the enum.
///
/// Unix has one owner for a file, OwnedFD, so there's nothing to convert.
/// Windows has two: the handle, and a C runtime descriptor over it, which
/// OwnedFD can own too. SYS-0011's bridges go between them:
/// `FileDescriptor(adopting:)` consumes the handle, and
/// `withWin32HandleIfAvailable` only lends one back, so owning the handle
/// again takes a duplicate, and closing the descriptor.
func convertAcrossPlatformTypes(_ file: consuming Platform.File) throws -> Platform.File {
  switch consume file {
  #if !os(Windows)
  case .fd(let owner):
    print("  Unix: OwnedFD is the only owner, and `relinquish()` its only exit")
    return .fd(owner)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    // Handle to C runtime descriptor, which now owns the handle. On failure,
    // this closes the handle before throwing.
    let descriptor = OwnedFD(taking: try FileDescriptor(adopting: handle))
    print("  handle -> C runtime descriptor \(descriptor.fileDescriptor.rawValue), owned by OwnedFD")

    // Descriptor to handle: a lend, valid only in the closure. Keeping the
    // handle takes a second one, and a second file-pointer-sharing object.
    let duplicate = try descriptor.fileDescriptor.withWin32HandleIfAvailable {
      (lent: borrowing Win32.FileHandle) throws(Win32.Error) -> Win32.FileHandle in
      try lent.duplicate()
    }
    guard let duplicate else {
      complain("  the descriptor has no handle to lend")
      throw ExitCode.failure
    }
    try descriptor.close()
    print("  C runtime descriptor -> a duplicated handle, and the descriptor closed")
    return .handle(duplicate)
  #endif
  }
}
