/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: variants of the file enum, for the `platform variants` sample.
// Not API. Each has only what that sample uses: writing, flushing,
// inheritance, and closing. `Platform.File` is the design the other samples
// use: Unix unchanged, and Windows as drafted, with a noncopyable handle.

import SystemPackage

// MARK: - An unowned enum, which needs a copyable Windows handle

extension Platform {
  /// VARIANT: an unowned, copyable file enum over raw names.
  ///
  /// With the drafts' noncopyable handle it has no Windows case. Its payload
  /// must be copyable, and the drafts' only copyable Windows handle is
  /// `unsafeRawHandle`'s bare `HANDLE`, whose operations are C calls. So on
  /// real Windows, where `Win32.RawFileHandle` doesn't exist, this enum would
  /// have no cases, and it's a cross-platform type only in the simulated
  /// build, over the rejected copyable-handle stand-in (Win32Copyable.swift).
  ///
  /// Like FileDescriptor, it closes nothing on its own, and any copy can
  /// close the file under the others.
  enum UnownedFile {
    #if !os(Windows)
    case fd(FileDescriptor)
    #endif

    #if SIMULATE_PLATFORMS
    case handle(Win32.RawFileHandle)
    #endif
  }
}

extension Platform.UnownedFile {
  /// Closes the file. Every copy of this value is now stale.
  func close() throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let descriptor):
      try Platform.typed { try descriptor.close() }
    #endif
    #if SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.close()
    #endif
    }
  }

  func flush() throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let descriptor):
      try descriptor.synchronize()
    #endif
    #if SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.flush()
    #endif
    }
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  func write(_ data: RawSpan) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let descriptor):
      _ = try descriptor.writeAll(data)
    #endif
    #if SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.write(data)
    #endif
    }
  }
}

extension Platform.File {
  /// VARIANT: the unowned name of an owned file, valid only while the owner
  /// is alive, as `OwnedFD.fileDescriptor` is. Needs the copyable handle.
  var unowned: Platform.UnownedFile {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return .fd(owner.fileDescriptor)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      #if SIMULATE_PLATFORMS
      return .handle(handle.rawHandle)
      #else
      fatalError("Windows' handle has no copyable form")
      #endif
    #endif
    }
  }
}

// MARK: - An owned-first Unix side

extension Platform {
  /// VARIANT: the file enum over owned-first types on both platforms.
  ///
  /// Its Unix case wraps `Unix.FileHandle`, which hosts the operations
  /// itself, as Windows' handle does. So both arms of a switch call
  /// operations on the payload directly, and both escape hatches are
  /// `@unsafe` raw values. It has the same one type per platform, and the
  /// same number of conversions, as `Platform.File`; the difference is in
  /// the Unix API behind it (see Unix/OwnedFirst.swift).
  enum OwnedFirstFile: ~Copyable, Sendable {
    #if !os(Windows)
    case fd(Unix.FileHandle)
    #endif

    #if os(Windows) || SIMULATE_PLATFORMS
    case handle(Win32.FileHandle)
    #endif
  }
}

extension Platform.OwnedFirstFile {
  static func open(
    _ path: FilePath, creatingOrTruncating: Bool
  ) throws(Platform.Error) -> Platform.OwnedFirstFile {
    #if SIMULATE_PLATFORMS
    if Simulation.platform == .windows {
      return .handle(try Win32.FileHandle.open(
        path, access: .genericWrite, disposition: creatingOrTruncating ? .createAlways : .openExisting))
    }
    #endif
    #if os(Windows)
    return .handle(try Win32.FileHandle.open(
      path, access: .genericWrite, disposition: creatingOrTruncating ? .createAlways : .openExisting))
    #else
    return .fd(try Unix.FileHandle.open(
      path, .writeOnly, options: creatingOrTruncating ? [.create, .truncate] : [],
      permissions: FilePermissions(rawValue: 0o666)))
    #endif
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  func write(_ data: RawSpan) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let file):
      try file.writeAll(data)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let file):
      try file.write(data)
    #endif
    }
  }

  func flush() throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let file):
      try file.synchronize()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let file):
      try file.flush()
    #endif
    }
  }

  consuming func close() throws(Platform.Error) {
    switch consume self {
    #if !os(Windows)
    case .fd(let file):
      try file.close()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let file):
      try file.close()
    #endif
    }
  }
}

// MARK: - No enum: a typealias to each platform's own type

/// ALTERNATIVE: no enum. Each platform's own owned type goes by one name,
/// and the common subset is members of the same names on each type.
///
/// Cross-platform code, and a cross-platform library's signatures, use
/// `NativeFile`; on each platform it *is* the platform's type, so
/// single-platform callers get OwnedFD or Win32.FileHandle directly, with
/// no switch to write and nothing to escape from. The costs: nothing checks
/// that the members agree across platforms (a protocol would, and
/// Next/Vision.md says not to draft protocols for methods), and a platform
/// can have only one representation per kind, so processes, which have two
/// on Linux and on Windows, still need an enum.
///
/// It can't simulate: a build has one platform's alias.
#if os(Windows)
typealias NativeFile = Win32.FileHandle
#else
typealias NativeFile = OwnedFD
#endif

#if !os(Windows)
/// The common subset, on Unix's type.
extension OwnedFD {
  static func openForCommonUse(
    _ path: FilePath, creatingOrTruncating: Bool
  ) throws(Platform.Error) -> OwnedFD {
    try OwnedFD.open(
      path, .writeOnly,
      options: creatingOrTruncating ? [.create, .truncate, .closeOnExec] : [.closeOnExec],
      permissions: FilePermissions(rawValue: 0o666))
  }

  /// Makes the file durable, as `Platform.File.flush()` does.
  func flushDurably() throws(Platform.Error) {
    #if SYSTEM_PACKAGE_DARWIN
    try fileDescriptor.synchronizeFully()
    #else
    try fileDescriptor.synchronize()
    #endif
  }
}
#endif

#if os(Windows) || SIMULATE_PLATFORMS
/// The same common subset, written again on Windows' type, where nothing
/// but each platform's build checks that it matches Unix's.
extension Win32.FileHandle {
  static func openForCommonUse(
    _ path: FilePath, creatingOrTruncating: Bool
  ) throws(Platform.Error) -> Win32.FileHandle {
    try Win32.FileHandle.open(
      path, access: .genericWrite, disposition: creatingOrTruncating ? .createAlways : .openExisting)
  }

  func flushDurably() throws(Platform.Error) {
    try flush()
  }
}
#endif
