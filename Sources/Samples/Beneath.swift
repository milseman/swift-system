/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#endif

#if canImport(Darwin, _version: 346) || os(FreeBSD)

struct Beneath: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Look up untrusted paths, rejecting any that would leave a directory"
  )

  @Argument(help: "The directory that the paths must stay beneath")
  var directory: String

  @Argument(help: "The paths to look up, relative to the directory")
  var paths: [String]

  #if SYSTEM_PACKAGE_DARWIN
  @Flag(help: "Follow no symbolic links, even ones that stay beneath the directory")
  var noSymlinks = false
  #endif

  func run() throws {
    // Every lookup resolves against this descriptor, so they all start in
    // the same directory, even if it's renamed or replaced meanwhile.
    let base = try FileDescriptor.open(FilePath(directory), .readOnly, options: .directory)
    defer { try? base.close() }

    // A path fails if resolving it would leave the directory at any point,
    // through `..`, an absolute path, or a symbolic link.
    var flags: Stat.Flags = .resolveBeneath
    #if SYSTEM_PACKAGE_DARWIN
    // A symbolic link in the middle of the path then fails with ELOOP,
    // and one at the end describes the link itself.
    if noSymlinks { flags.insert(.symlinkNoFollowAny) }
    #endif

    var rejected = false
    for path in paths {
      do {
        let status = try FilePath(path).stat(relativeTo: base, flags: flags)
        print("\(path): \(describe(status))")
      } catch {
        rejected = true
        print("\(path): \(error == escapeError ? "escapes \(directory)" : "\(error)")")
      }
    }
    if rejected { throw ExitCode.failure }
  }
}

#if os(FreeBSD)
private let escapeError = Errno.notCapable
#else
// Darwin reports ENOTCAPABLE too, but System names it only on FreeBSD.
private let escapeError = Errno(rawValue: ENOTCAPABLE)
#endif

private func describe(_ status: Stat) -> String {
  switch status.type {
  case .regular: return "regular file, \(status.size) bytes"
  case .directory: return "directory"
  case .symbolicLink: return "symbolic link"
  default: return "file of type \(String(status.type.rawValue, radix: 8))"
  }
}

#else

struct Beneath: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no AT_RESOLVE_BENEATH"
  )

  func run() throws {
    // Linux resolves beneath a directory only in openat2, which System
    // doesn't wrap.
    complain("Error: beneath needs AT_RESOLVE_BENEATH, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // canImport(Darwin, _version: 346) || os(FreeBSD)
