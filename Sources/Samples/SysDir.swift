/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private let directories: [(String, SearchPaths.Directory)] = [
  ("applications", .applications), ("demoApplications", .demoApplications),
  ("developerApplications", .developerApplications),
  ("adminApplications", .adminApplications), ("library", .library),
  ("developer", .developer), ("users", .users), ("documentation", .documentation),
  ("documents", .documents), ("coreServices", .coreServices),
  ("autosavedInformation", .autosavedInformation), ("desktop", .desktop),
  ("caches", .caches), ("applicationSupport", .applicationSupport),
  ("downloads", .downloads), ("inputMethods", .inputMethods), ("movies", .movies),
  ("music", .music), ("pictures", .pictures),
  ("printerDescriptions", .printerDescriptions), ("sharedPublic", .sharedPublic),
  ("preferencePanes", .preferencePanes), ("allApplications", .allApplications),
  ("allLibraries", .allLibraries),
]

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private let domainNames: [(String, SearchPaths.Domains)] = [
  ("user", .user), ("local", .local), ("network", .network), ("system", .system),
  ("all", .all),
]

struct SysDir: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sysdir",
    abstract: "List the search paths of the standard directories, such as Library/Caches, in each domain"
  )

  @Argument(help: "A directory, such as caches or applicationSupport; every one if omitted")
  var directory: String?

  @Option(name: .shortAndLong, parsing: .upToNextOption,
          help: "Domains to look in: user, local, network, system, or all")
  var domains: [String] = ["all"]

  @Flag(help: "Replace a leading ~ with the home directory that HOME names")
  var expandTilde = false

  func run() throws {
    guard #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) else {
      complain("sysdir requires macOS 10.12 or later")
      throw ExitCode.failure
    }
    var mask: SearchPaths.Domains = []
    for name in domains {
      guard let domain = domainNames.first(where: { $0.0 == name })?.1 else {
        throw ValidationError("Unknown domain \(name)")
      }
      mask.formUnion(domain)
    }
    let home = expandTilde ? ProcessEnvironment.value(of: "HOME").map(FilePath.init(_:)) : nil

    // The ~ that begins a path in the user's domain is left for the caller
    // to replace: which home directory it means depends on the program.
    func display(_ path: FilePath) -> String {
      guard let home, path.components.first == "~" else { return path.string }
      return home.appending(path.components.dropFirst()).string
    }

    if let directory {
      guard let chosen = directories.first(where: { $0.0 == directory })?.1 else {
        throw ValidationError("Unknown directory \(directory)")
      }
      for path in SearchPaths(chosen, in: mask) { print(display(path)) }
      return
    }
    var rows: [[String]] = []
    for (name, directory) in directories {
      let paths = SearchPaths(directory, in: mask).map(display)
      rows.append([name, paths.isEmpty ? "(none)" : paths.joined(separator: ", ")])
    }
    printTable(rows)
  }
}

#else
struct SysDir: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sysdir",
    abstract: "Unavailable: sysdir is Darwin's"
  )

  func run() throws {
    complain("sysdir isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
