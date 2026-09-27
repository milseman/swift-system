/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 4: code that gets a Platform.File from a cross-platform
// library, and needs platform-only operations on it. It's written as a user
// would write it: first a switch, then, after the second or third one, a
// helper that does the switch once and hands back the platform's value,
// then the raw value that a C function needs. Each place where it leaves
// the typed layer is marked ESCAPE.
//
// What it shows:
// - Unix code escapes into a typed, copyable name: `owner.fileDescriptor`,
//   then `.rawValue` for C. Windows code, whose handle is noncopyable, can't
//   get a copyable name, so the helper that's easy to write returns the raw
//   HANDLE, `unsafeRawHandle`.
// - The helper traps on the other platform's case: a one-case match, which
//   is an unchecked downcast. Against the SDK's System, built with library
//   evolution, it would also need `@unknown default: fatalError()` (V16a).
// - Some operations can't follow the file across the enum at all:
//   Windows picks caching when it opens a handle, and the library opened
//   this one, so the only way is a second handle.

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

// MARK: - The cross-platform library

/// A cross-platform library. It vends Platform.File so that its API has one
/// signature on every platform, with no `#if`.
enum TinyJournal {
  /// Opens the journal, creating it if needed.
  static func open(at path: FilePath) throws(Platform.Error) -> Platform.File {
    try Platform.File.open(path, .readWrite, .openOrCreate)
  }

  /// Appends an entry, durably.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  static func append(_ entry: String, to journal: borrowing Platform.File) throws {
    try journal.seek(offset: 0, from: .end)
    try withSpan(of: entry + "\n") { try journal.write($0) }
    try journal.flush()
  }
}

// MARK: - The app

struct PlatformLibrary: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "library",
    abstract: "Use a Platform.File from a cross-platform library for platform-only work"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "The journal, which is created if needed")
  var path: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let journal = try TinyJournal.open(at: FilePath(path))
    print("TinyJournal opened \(journal.summary)")
    try TinyJournal.append("opened by the app", to: journal)

    // A first platform-only need, written as a switch.
    try turnOffCaching(journal)

    // More of them. The switch that routes to each platform's code stays;
    // inside, the user's helpers get the platform value out.
    switch journal {
    #if !os(Windows)
    case .fd:
      try unixWork(journal, path: FilePath(path))
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle:
      try windowsWork(journal)
    #endif
    }

    // Finally, hand the journal to C's stdio, which will own it.
    let stream = try handToStdio(journal)
    fputs("written through stdio\n", stream)
    guard fclose(stream) == 0 else { throw Errno(rawValue: errno) }
    print("Handed the journal to stdio, which wrote a line and closed it")
  }
}

/// Stops the system from caching the journal's data. The first
/// platform-only operation, written as a switch.
func turnOffCaching(_ journal: borrowing Platform.File) throws {
  switch journal {
  #if !os(Windows)
  case .fd(let owner):
    #if SYSTEM_PACKAGE_DARWIN
    // ESCAPE: `fileDescriptor`, the owner's vended name, for an operation
    // OwnedFD doesn't forward.
    try owner.fileDescriptor.setNoCache(true)
    print("Set F_NOCACHE on the journal's descriptor")
    #else
    // "Unix" isn't one platform: Linux has no F_NOCACHE, and chooses
    // O_DIRECT when a file is opened. So even this arm needs an `#if`.
    _ = owner
    print("Linux can't turn caching off for an open descriptor")
    #endif
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    // Windows chooses caching when a handle is opened, with
    // FILE_FLAG_NO_BUFFERING, and the library opened this one. The only way
    // is a second file object, with its own file pointer, that the app must
    // keep and close, and that the library can't see.
    let uncached = try handle.reopen(access: [.genericRead, .genericWrite], flags: .noBuffering)
    print("Windows can't change the library's handle; reopened another without buffering")
    try uncached.close()
  #endif
  }
}

// MARK: - Unix: a helper, then raw values

#if !os(Windows)
extension Platform.File {
  /// The file descriptor. What a Unix user writes after the second switch.
  ///
  /// ESCAPE: a one-case match, which traps on any other case. In a real Unix
  /// build `.fd` is the only case, so the switch is exhaustive. Built
  /// against a System with library evolution, it would need
  /// `@unknown default: fatalError()`, and a case added later traps.
  /// The descriptor is valid only while the Platform.File lives, and
  /// nothing checks that.
  var descriptor: FileDescriptor {
    switch self {
    case .fd(let owner):
      return owner.fileDescriptor
    #if SIMULATE_PLATFORMS
    case .handle:
      fatalError("\(summary) isn't a file descriptor")
    #endif
    }
  }
}

/// Unix-only work on the library's journal.
func unixWork(_ journal: borrowing Platform.File, path: FilePath) throws {
  // Security: a journal with more than one link may have been linked
  // somewhere an attacker can read it.
  let links = try journal.descriptor.stat().linkCount
  print("The journal has \(links) link\(links == 1 ? "" : "s")")

  #if SYSTEM_PACKAGE_DARWIN
  // Watch for the journal being renamed, as log rotation does. A kqueue
  // registration needs the raw descriptor.
  let queue = kqueue()
  guard queue >= 0 else { throw Errno(rawValue: errno) }
  defer { close(queue) }
  var change = kevent(
    // ESCAPE: `.rawValue`, for C.
    ident: UInt(journal.descriptor.rawValue), filter: Int16(EVFILT_VNODE),
    flags: UInt16(EV_ADD | EV_CLEAR), fflags: UInt32(NOTE_RENAME), data: 0, udata: nil)
  guard kevent(queue, &change, 1, nil, 0, nil) == 0 else { throw Errno(rawValue: errno) }
  let rotated = FilePath(path.string + ".1")
  try path.rename(to: rotated)
  var event = kevent()
  var zero = timespec(tv_sec: 0, tv_nsec: 0)
  let count = kevent(queue, nil, 0, &event, 1, &zero)
  print(count == 1 ? "kqueue saw the journal renamed" : "kqueue saw nothing")
  try rotated.rename(to: path)
  #endif
}
#endif

// MARK: - Windows: a helper that can't return the handle

#if os(Windows) || SIMULATE_PLATFORMS
extension Platform.File {
  /// Calls `body` with the handle. The noncopyable handle can't be returned
  /// from a property, so the correct helper takes a closure. (An underscored
  /// `_read` accessor could yield it, and SE-0474's `yielding borrow`
  /// doesn't parse in Swift 6.2; V16j.)
  func withHandle<R>(_ body: (borrowing Win32.FileHandle) throws -> R) rethrows -> R {
    switch self {
    case .handle(let handle):
      return try body(handle)
    #if !os(Windows)
    case .fd:
      fatalError("\(summary) isn't a handle")
    #endif
    }
  }

  /// The raw handle: what a Windows user writes instead, because it's
  /// copyable and returns like the Unix helper does.
  ///
  /// ESCAPE: `unsafeRawHandle`, an untyped pointer, valid only while the
  /// Platform.File lives. Unix's helper escapes into a typed name; this one
  /// can only escape into C's.
  var rawHandle: HANDLE {
    switch self {
    case .handle(let handle):
      return handle.unsafeRawHandle
    #if !os(Windows)
    case .fd:
      fatalError("\(summary) isn't a handle")
    #endif
    }
  }
}

/// Windows-only work on the library's journal.
func windowsWork(_ journal: borrowing Platform.File) throws {
  // A wrapped operation, through the closure helper.
  let volume = try journal.withHandle { try $0.volumeInformation() }
  print("The journal's volume is formatted \(volume.fileSystemName)")

  // An operation no draft wraps yet, SYS-0010's "querying file
  // information", through the raw handle, as C.
  var information = BY_HANDLE_FILE_INFORMATION()
  guard GetFileInformationByHandle(journal.rawHandle, &information) else {
    throw Win32.Error(GetLastError())
  }
  let links = information.nNumberOfLinks
  print("The journal has \(links) link\(links == 1 ? "" : "s")")
  // Watching for renames on Windows is ReadDirectoryChangesW, on the
  // directory's handle rather than the file's, so nothing here can do it.
}
#endif

// MARK: - Handing ownership to C

/// Transfers the journal to C's stdio, which closes it with `fclose`.
///
/// A consuming switch: each arm gives its owner up. ESCAPE: `relinquish()`,
/// then a raw descriptor for `fdopen`.
func handToStdio(_ journal: consuming Platform.File) throws -> UnsafeMutablePointer<FILE> {
  let descriptor: FileDescriptor
  switch consume journal {
  #if !os(Windows)
  case .fd(let owner):
    descriptor = owner.relinquish()
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    // SYS-0011's bridge: a C runtime descriptor that owns the handle. On
    // failure, it closes the handle before throwing.
    descriptor = try FileDescriptor(adopting: handle)
  #endif
  }
  guard let stream = fdopen(descriptor.rawValue, "a") else {
    let error = Errno(rawValue: errno)
    _ = try? descriptor.close()
    throw error
  }
  return stream
}
