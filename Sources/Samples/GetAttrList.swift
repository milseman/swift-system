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

struct GetAttrList: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "getattrlist",
    abstract: "Show files' attributes with getattrlist, their volume's capabilities, or a directory's entries with getattrlistbulk"
  )

  @Argument(help: "The files to show")
  var paths: [String]

  @Flag(help: "Show the volume each file is on, rather than the file")
  var volume = false

  @Flag(help: "List each directory's entries, with getattrlistbulk")
  var list = false

  func run() throws {
    for path in paths.map({ FilePath($0) }) {
      do {
        if volume {
          try showVolume(path)
        } else if list {
          try listEntries(path)
        } else {
          try show(path)
        }
      } catch {
        complain("Error: \(path): \(error)")
      }
    }
  }

  private func show(_ path: FilePath) throws {
    // One call reads what stat reads, and more, such as the creation time,
    // the resolved path, and the clone ID.
    let attributes = try path.attributes(
      [.name, .fullPath, .objectType, .fileID, .owner, .accessMask, .creationTime,
       .fileDataLength, .fileAllocatedSize, .directoryEntryCount, .cloneID, .privateSize],
      options: .noFollow)
    func describe<T>(_ value: T?) -> String { value.map { "\($0)" } ?? "?" }
    func describe(_ type: FileType?) -> String {
      switch type {
      case .regular: return "regular file"
      case .directory: return "directory"
      case .symbolicLink: return "symbolic link"
      case .characterSpecial, .blockSpecial: return "device"
      case .fifo: return "FIFO"
      case .socket: return "socket"
      default: return "?"
      }
    }
    var rows: [[String]] = [
      ["name", describe(attributes.name)],
      ["full path", describe(attributes.fullPath)],
      ["type", describe(attributes.objectType)],
      ["file ID", describe(attributes.fileID?.rawValue)],
      ["owner", describe(attributes.owner?.rawValue)],
      ["permissions", describe(attributes.permissions)],
    ]
    if let created = attributes.value(of: .creationTime, as: timespec.self) {
      rows.append(["created", "\(created.tv_sec) seconds since the Epoch"])
    }
    if let length = attributes.fileDataLength {
      rows.append(["data", "\(amount(length)), \(amount(attributes.fileAllocatedSize ?? 0)) allocated"])
    }
    if let count = attributes.directoryEntryCount { rows.append(["entries", "\(count)"]) }
    if let cloneID = attributes.cloneID {
      rows.append(["clone ID", "\(cloneID), \(amount(attributes.privateSize ?? 0)) unshared"])
    }
    print("\(path):")
    printTable(rows)
  }

  private func showVolume(_ path: FilePath) throws {
    let attributes = try path.attributes([
      .volumeName, .volumeMountPoint, .volumeFileSystemTypeName, .volumeCapabilities,
      .volumeSize, .volumeAvailableSpace,
    ])
    print("\(path) is on \(attributes.volumeName ?? "?"), "
      + "\(attributes.volumeFileSystemTypeName ?? "?") mounted at "
      + "\(attributes.volumeMountPoint.map { "\($0)" } ?? "?"):")
    if let size = attributes.value(of: .volumeSize, as: Int64.self),
      let available = attributes.value(of: .volumeAvailableSpace, as: Int64.self) {
      print("  \(amount(available)) available of \(amount(size))")
    }
    if let capabilities = attributes.volumeCapabilities {
      // A capability outside the valid ones is unknown, rather than missing.
      print("  format: \(capabilities.format)")
      print("  interfaces: \(capabilities.interfaces)")
      let missing = capabilities.validInterfaces.subtracting(capabilities.interfaces)
      print("  known to be missing: \(missing)")
    }
  }

  private func listEntries(_ path: FilePath) throws {
    let directory = try FileDescriptor.open(path, .readOnly, options: .directory)
    try directory.closeAfter {
      var rows: [[String]] = []
      // Each call reads as many entries as fit, until none are left.
      while case let entries = try directory.readEntryAttributes([.objectType, .fileDataLength]),
        !entries.isEmpty {
        for entry in entries {
          if let error = entry.error {
            rows.append([entry.name ?? "?", "error: \(error)"])
            continue
          }
          let kind = entry.objectType == .directory ? "directory" : ""
          rows.append([entry.name ?? "?", kind, entry.fileDataLength.map { amount($0) } ?? ""])
        }
      }
      print("\(path): \(rows.count) entries")
      printTable(rows.sorted { $0[0] < $1[0] })
    }
  }
}

#else

struct GetAttrList: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "getattrlist",
    abstract: "Unavailable: this platform has no getattrlist"
  )

  func run() throws {
    complain("Error: getattrlist needs Darwin's getattrlist")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
