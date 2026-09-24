/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import ArgumentParser
import SystemPackage

struct GetConf: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "getconf",
    abstract: "Show the system's limits and options, and the limits for some files, as getconf(1) does"
  )

  @Argument(help: "Files or directories to show limits for")
  var paths: [String] = ["."]

  func run() throws {
    let paths = paths.map { FilePath($0) }
    for path in paths {
      do {
        _ = try path.stat()
      } catch {
        complain("Error: \(path): \(error)")
        throw ExitCode.failure
      }
    }

    print("System-wide (sysconf):")
    let pageSize = try SystemConfig.value(.pageSize) ?? 0
    let pages = try SystemConfig.value(.physicalMemoryPages)
    let configured = try SystemConfig.value(.processorsConfigured)
    let online = try SystemConfig.value(.processorsOnline)
    var rows: [[String]] = [
      ["page size", "\(pageSize) bytes"],
      ["physical memory", pages.map { "\($0) pages, \(($0 * pageSize) >> 20) MiB" } ?? "no limit"],
      ["processors", "\(limit(configured)) configured, \(limit(online)) online"],
    ]
    // For a limit, nil means that the system has no limit. For an option,
    // it means that the system doesn't support the option.
    let limits: [(String, SystemConfig.Name)] = [
      ("open files per process", .maxOpenFiles),
      ("processes per user", .maxUserProcesses),
      ("argument and environment bytes", .maxArgumentBytes),
      ("supplementary groups", .maxSupplementaryGroups),
      ("buffers per vectored read or write", .maxIOVectors),
      ("host name bytes", .maxHostNameBytes),
      ("clock ticks per second", .clockTicksPerSecond),
    ]
    rows += try limits.map { [$0.0, limit(try SystemConfig.value($0.1))] }
    rows.append(["POSIX version", limit(try SystemConfig.value(.posixVersion))])
    let options: [(String, SystemConfig.Name)] = [
      ("job control", .jobControl),
      ("saved set-user-IDs", .savedIDs),
      ("FORTRAN development tools", .fortranDevelopment),
    ]
    rows += try options.map {
      [$0.0, try SystemConfig.value($0.1) == nil ? "not supported" : "supported"]
    }
    printTable(rows)

    // A pipe has no path, so its column comes from fpathconf.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    print("For each file (pathconf, or fpathconf for the pipe):")
    var variables: [(String, SystemConfig.PathName, (Int?) -> String)] = [
      ("file name bytes", .maxFileNameBytes, limit),
      ("path bytes", .maxPathBytes, limit),
      ("symbolic link bytes", .maxSymbolicLinkBytes, limit),
      ("hard links", .maxLinks, limit),
      ("file size bits", .fileSizeBits, limit),
    ]
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    variables.append(("minimum hole size", .minimumHoleSize, limit))
    #endif
    variables += [
      ("atomic pipe write bytes", .maxAtomicPipeWriteBytes, limit),
      ("terminal input line bytes", .maxTerminalCanonicalLineBytes, limit),
      ("chown restricted", .chownRestricted, option),
      ("names too long are errors", .noTruncation, option),
    ]
    rows = [[""] + paths.map { "\($0)" } + ["a pipe"]]
    for (name, variable, format) in variables {
      var row = [name]
      for path in paths {
        row.append(try cell(format) { try SystemConfig.value(variable, for: path) })
      }
      row.append(try cell(format) { try SystemConfig.value(variable, for: pipe.readEnd) })
      rows.append(row)
    }
    printTable(rows)
    print("A - means that the variable doesn't apply to that kind of file.")
  }
}

/// Formats a file's value for a variable, or "-" if it doesn't apply.
private func cell(_ format: (Int?) -> String, _ value: () throws -> Int?) throws -> String {
  do {
    return format(try value())
  } catch Errno.invalidArgument {
    // A variable that doesn't apply to a kind of file, such as a terminal's
    // line length for a directory, throws EINVAL.
    return "-"
  }
}

private func limit(_ value: Int?) -> String {
  value.map { "\($0)" } ?? "no limit"
}

// A path option is on if its value isn't 0, and off if it's 0 or nil.
private func option(_ value: Int?) -> String {
  (value ?? 0) != 0 ? "yes" : "no"
}

/// Prints rows of cells in left-aligned columns, indented.
private func printTable(_ rows: [[String]]) {
  let columns = rows.map(\.count).max() ?? 0
  let widths = (0..<columns).map { column in
    rows.map { column < $0.count ? $0[column].count : 0 }.max()! + 2
  }
  for row in rows {
    var line = "  "
    for (column, text) in row.enumerated() {
      let isLast = column == row.count - 1
      line += isLast ? text : text + String(repeating: " ", count: widths[column] - text.count)
    }
    print(line)
  }
}

#endif // !os(Windows) && !os(WASI)
