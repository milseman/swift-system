/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Linux) || os(Android)

struct DiskFree: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "statfs",
    abstract: "Show file systems' size, free space, and mount flags, like df"
  )

  @Argument(help: "Files whose file systems to show (default: every mounted file system)")
  var paths: [String] = []

  @Flag(name: .customShort("i"), help: "Show the file systems' inodes too")
  var inodes = false

  @Flag(name: .customShort("f"), help: "Show the file systems' mount flags too")
  var flags = false

  @Flag(name: .customShort("a"), help: "Include file systems with no blocks, such as autofs and proc")
  var all = false

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  @Flag(help: "Ask each mounted file system for new statistics first, which can wait on a network one")
  var wait = false
  #endif

  #if os(Linux) || os(Android)
  @Flag(help: "Say which version of control groups this system has, as NIO works it out")
  var cgroups = false
  #endif

  func run() throws {
    #if os(Linux) || os(Android)
    if cgroups {
      try printControlGroupsVersion()
      return
    }
    #endif

    var fileSystems: [FileSystem] = []
    var failed = false
    if paths.isEmpty {
      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
      let mounted = try mountedFileSystems(waitForUpdates: wait)
      #else
      let mounted = try mountedFileSystems(all: all)
      #endif
      fileSystems = mounted.filter { all || $0.statistics.totalBlocks > 0 }
    }
    for path in paths {
      do {
        fileSystems.append(try fileSystem(containing: FilePath(path)))
      } catch {
        complain("Error: \(path): \(error)")
        failed = true
      }
    }

    var header = ["Filesystem", "Size", "Used", "Avail", "Capacity"]
    if inodes { header += ["IUsed", "IFree", "%IUsed"] }
    header.append("Type")
    if flags { header.append("Flags") }
    header.append("Mounted on")
    printTable([header] + fileSystems.map { row($0) })
    if failed { throw ExitCode.failure }
  }

  private func row(_ fileSystem: FileSystem) -> [String] {
    let statistics = fileSystem.statistics
    // As df counts them: used space is what isn't free, and the capacity is
    // how much of the space available to users is used, which leaves out the
    // superuser's reserve. APFS volumes share their container's space, so
    // there this counts the whole container's use; macOS's df asks
    // getattrlist for the volume's own (ATTR_VOL_SPACEUSED) instead.
    let used = statistics.totalSpace - min(statistics.freeSpace, statistics.totalSpace)
    var row = [
      fileSystem.source,
      size(statistics.totalSpace),
      size(used),
      size(statistics.availableSpace),
      percent(Double(used), of: Double(used) + Double(statistics.availableSpace)),
    ]
    if inodes {
      let usedInodes = statistics.totalInodes - min(statistics.freeInodes, statistics.totalInodes)
      row += [
        String(usedInodes),
        String(statistics.freeInodes),
        percent(Double(usedInodes), of: Double(statistics.totalInodes)),
      ]
    }
    row.append(fileSystem.type)
    if flags { row.append(describe(statistics.mountFlags)) }
    row.append(fileSystem.mountPoint)
    return row
  }
}

/// A mounted file system: its statistics, and where it's mounted from and on.
private struct FileSystem {
  var source: String
  var mountPoint: String
  var type: String
  var statistics: StatFS
}

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

// A statfs says where its file system is mounted, and getfsstat lists them.

extension FileSystem {
  init(_ statistics: StatFS) {
    self.init(
      source: statistics.mountSource.string,
      mountPoint: statistics.mountPoint.string,
      type: statistics.typeName,
      statistics: statistics)
  }
}

private func mountedFileSystems(waitForUpdates: Bool) throws -> [FileSystem] {
  try StatFS.mountedFileSystems(waitForUpdates: waitForUpdates).map(FileSystem.init)
}

private func fileSystem(containing path: FilePath) throws -> FileSystem {
  FileSystem(try path.statfs())
}

#else

// A statvfs doesn't say where its file system is mounted, so the mounts come
// from /proc/self/mounts. The file system type comes from both: the name
// that the mount lists, and the magic number that statfs reports.

extension FileSystem {
  init(_ mount: Mount, _ statistics: StatFS) throws {
    let type = try FilePath(mount.mountPoint).fileSystemType()
    self.init(
      source: mount.source,
      mountPoint: mount.mountPoint,
      type: "\(mount.type) (0x\(String(type.rawValue, radix: 16)))",
      statistics: statistics)
  }
}

private func mountedFileSystems(all: Bool) throws -> [FileSystem] {
  var fileSystems: [FileSystem] = []
  for mount in try mounts() {
    // Looking at an autofs mount point mounts what it stands for.
    if mount.type == "autofs" && !all { continue }
    do {
      fileSystems.append(try FileSystem(mount, FilePath(mount.mountPoint).statfs()))
    } catch {
      complain("Error: \(mount.mountPoint): \(error)")
    }
  }
  return fileSystems
}

private func fileSystem(containing path: FilePath) throws -> FileSystem {
  let statistics = try path.statfs()
  // The mount is the last one listed, the one on top, whose mount point
  // contains the path and is on the same device.
  let device = try path.stat().deviceID
  let absolute = path.isAbsolute ? path : try FilePath.currentWorkingDirectory().pushing(path)
  let normalized = absolute.lexicallyNormalized()
  let mount = try mounts().last { mount in
    let mountPoint = FilePath(mount.mountPoint)
    return normalized.starts(with: mountPoint) && (try? mountPoint.stat().deviceID) == device
  }
  guard let mount else {
    let type = try path.fileSystemType()
    return FileSystem(
      source: "-", mountPoint: path.string,
      type: "0x\(String(type.rawValue, radix: 16))", statistics: statistics)
  }
  return try FileSystem(mount, statistics)
}

/// A line of /proc/self/mounts.
private struct Mount {
  var source: String
  var mountPoint: String
  var type: String
}

/// The mounts that /proc/self/mounts lists, in the order they were mounted.
private func mounts() throws -> [Mount] {
  let lines = try contents(of: "/proc/self/mounts").split(separator: UInt8(ascii: "\n"))
  return lines.compactMap { line in
    // Fields: source, mount point, type, options, and two numbers.
    let fields = line.split(separator: UInt8(ascii: " "))
    guard fields.count >= 3 else { return nil }
    return Mount(
      source: unescape(fields[0]), mountPoint: unescape(fields[1]), type: unescape(fields[2]))
  }
}

/// Undoes /proc/self/mounts's octal escapes, such as `\040` for a space.
private func unescape(_ field: ArraySlice<UInt8>) -> String {
  var bytes: [UInt8] = []
  var index = field.startIndex
  while index < field.endIndex {
    let digits = field[(index + 1)...].prefix(3)
    if field[index] == UInt8(ascii: "\\"), digits.count == 3,
      digits.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "7")).contains($0) })
    {
      bytes.append(digits.reduce(0) { $0 << 3 | ($1 - UInt8(ascii: "0")) })
      index += 4
    } else {
      bytes.append(field[index])
      index += 1
    }
  }
  return String(decoding: bytes, as: UTF8.self)
}

/// Reads a whole file, for /proc files, whose size stat reports as 0.
private func contents(of path: FilePath) throws -> [UInt8] {
  let fd = try FileDescriptor.open(path, .readOnly)
  return try fd.closeAfter {
    var bytes: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 64 << 10)
    while true {
      let count = try chunk.withUnsafeMutableBytes { try fd.read(into: $0) }
      if count == 0 { return bytes }
      bytes += chunk[..<count]
    }
  }
}

/// Tells control groups version 1 from version 2 by the type of the file
/// system at /sys/fs/cgroup, as NIO does to find its CPU quota. Version 2 has
/// one cgroup2 hierarchy there. Version 1 has a tmpfs, with a cgroup
/// hierarchy for each controller under it.
private func printControlGroupsVersion() throws {
  let path: FilePath = "/sys/fs/cgroup"
  switch try path.fileSystemType() {
  case .cgroup2:
    print("\(path) is cgroup2: control groups version 2")
  case .tmpfs:
    print("\(path) is tmpfs: control groups version 1, with a hierarchy for each controller")
  case let type:
    print("\(path) is neither cgroup2 nor tmpfs, but 0x\(String(type.rawValue, radix: 16))")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

/// The flags that describe(_:) names, with the names mount(8) gives them.
private var mountFlagNames: [(MountFlags, String)] {
  var names: [(MountFlags, String)] = [
    (.readOnly, "ro"),
    (.synchronous, "sync"),
    (.noExecution, "noexec"),
    (.noSetUserID, "nosuid"),
    (.noAccessTime, "noatime"),
  ]
  #if !os(FreeBSD)
  names.append((.noDevices, "nodev"))
  #endif
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  names += [
    (.asynchronous, "async"),
    (.exported, "exported"),
    (.local, "local"),
    (.quota, "quota"),
    (.rootFileSystem, "root"),
  ]
  #endif
  #if SYSTEM_PACKAGE_DARWIN
  names += [
    (.union, "union"),
    (.automounted, "automounted"),
    (.multiLabel, "multilabel"),
    (.contentProtection, "protect"),
    (.removable, "removable"),
    (.quarantine, "quarantine"),
    (.volumeFileSystem, "dovolfs"),
    (.noBrowsing, "nobrowse"),
    (.ignoreOwnership, "noowners"),
    (.journaled, "journaled"),
    (.noUserExtendedAttributes, "nouserxattr"),
    (.deferWrites, "defwrite"),
    (.noSymlinkFollowAtMountPoint, "nofollow"),
    (.snapshot, "snapshot"),
    (.strictAccessTime, "strictatime"),
  ]
  #endif
  #if os(Linux) || os(Android)
  names += [
    (.mandatoryLockingPermitted, "mand"),
    (.noDirectoryAccessTime, "nodiratime"),
    (.relativeAccessTime, "relatime"),
    (.noSymlinkFollow, "nosymfollow"),
  ]
  #endif
  return names
}

/// Names a file system's mount flags, and shows any it has no name for in
/// hexadecimal.
private func describe(_ flags: MountFlags) -> String {
  var rest = flags
  var names: [String] = []
  for (flag, name) in mountFlagNames where rest.contains(flag) {
    names.append(name)
    rest.remove(flag)
  }
  if !rest.isEmpty { names.append("0x" + String(rest.rawValue, radix: 16)) }
  return names.isEmpty ? "-" : names.joined(separator: ",")
}

/// Formats a number of bytes as df -h does, in powers of 1024.
private func size(_ bytes: UInt64) -> String {
  let units = ["B", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei"]
  var value = Double(bytes)
  var unit = 0
  while value >= 1024 && unit < units.count - 1 {
    value /= 1024
    unit += 1
  }
  let tenths = Int((value * 10).rounded())
  if unit == 0 || tenths >= 100 { return "\(Int(value.rounded()))\(units[unit])" }
  return "\(tenths / 10).\(tenths % 10)\(units[unit])"
}

/// Formats a fraction as a percentage, rounded up as df rounds it.
private func percent(_ part: Double, of whole: Double) -> String {
  whole > 0 ? "\(Int((part / whole * 100).rounded(.up)))%" : "-"
}

#else

struct DiskFree: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "statfs",
    abstract: "Unavailable: this platform has no statfs or statvfs that works"
  )

  func run() throws {
    complain("Error: statfs needs statfs or statvfs, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Linux) || os(Android)
