/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: directories through Platform.Directory, in a durable save:
// write a temporary file, flush it, rename it over the target, and make the
// rename durable.
//
// Platform.Directory's common subset is only opening and closing, and this
// shows why. The last step has a different shape on each platform:
// - Unix renames by path and makes the rename durable by syncing the
//   directory that holds it, which is what the directory's descriptor is
//   for.
// - Windows asks the rename itself to write through, with MoveFileExW's
//   MOVEFILE_WRITE_THROUGH (a C call: no draft wraps path operations). It has
//   no use for the directory's handle, which it has no way to flush.
// So the switch's Windows arm ignores its payload. Cross-platform code that
// knew this would write `#if` and open the directory only on Unix: an
// operation that needs a kind on one platform and not on another doesn't
// fit an enum of that kind.

import ArgumentParser
import SystemPackage

struct PlatformSave: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "save",
    abstract: "Replace a file's contents durably, through Platform.File and Platform.Directory"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "The file to replace, in an existing directory")
  var path: String

  @Argument(help: "Its new contents")
  var text: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    try saveDurably(text + "\n", to: FilePath(path))
  }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func saveDurably(_ contents: String, to path: FilePath) throws {
  guard let name = path.lastComponent else {
    throw ValidationError("\(path) has no file name")
  }
  let parent = path.removingLastComponent()
  let temporary = parent.appending(".\(name).tmp")

  // The common subset: write the new contents, and make them durable.
  let file = try Platform.File.open(temporary, .write, .createOrTruncate)
  try withSpan(of: contents) { try file.write($0) }
  try file.flush()
  try file.close()

  // Replace the target, and make the replacement durable.
  let directory = try Platform.Directory.open(parent.isEmpty ? "." : parent)
  print("opened the directory: \(directory.summary)")
  switch directory {
  #if !os(Windows)
  case .fd(let owner):
    // rename(2) replaces the target atomically. Syncing the directory makes
    // the new name survive a crash.
    try temporary.rename(to: path)
    try owner.fileDescriptor.synchronize()
    print("renamed with rename(2), then synced the directory's descriptor")
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle:
    // The directory's handle isn't used: MoveFileExW makes the rename
    // durable itself. C: no draft wraps MoveFileExW.
    let moved = temporary.withPlatformString { existing in
      path.withPlatformString { new in
        MoveFileExW(existing, new, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)
      }
    }
    guard moved else { throw Win32.Error(GetLastError()) }
    print("renamed with MoveFileExW(MOVEFILE_WRITE_THROUGH); the directory's handle had no part")
  #endif
  }
  try directory.close()
  print("saved \(path)")
}
