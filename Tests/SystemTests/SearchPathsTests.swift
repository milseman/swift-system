/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import Darwin
import Darwin.sysdir

@Suite("Search paths")
private struct SearchPathsTests {
  @available(System 199, *)
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @Test func pathsInSearchOrder() {
    let support = Array(SearchPaths(.applicationSupport, in: [.user, .local]))
    #if os(macOS)
    #expect(support == ["~/Library/Application Support", "/Library/Application Support"])
    #expect(Array(SearchPaths(.caches, in: .user)) == ["~/Library/Caches"])
    // The system domain can have more than one path: macOS 26's also has
    // the app cryptex's, /System/Cryptexes/App/System/Library.
    let library = Array(SearchPaths(.library, in: .all))
    #expect(library.starts(with: ["~/Library", "/Library", "/Network/Library", "/System/Library"]))
    #expect(Array(SearchPaths(.library, in: .system)) == Array(library.dropFirst(3)))
    #endif
    // Only the user's domain's paths begin with ~.
    for path in SearchPaths(.allLibraries, in: .all) {
      #expect(path.components.first == "~" || path.isAbsolute, "\(path)")
    }
    for path in SearchPaths(.allLibraries, in: [.local, .network, .system]) {
      #expect(path.isAbsolute, "\(path)")
    }
  }

  @available(System 199, *)
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @Test func iteratingAgainStartsOver() {
    let paths = SearchPaths(.allApplications, in: .all)
    let first = Array(paths)
    #expect(!first.isEmpty)
    #expect(Array(paths) == first)
    var iterator = paths.makeIterator()
    while iterator.next() != nil {}
    #expect(iterator.next() == nil, "an ended enumeration stays ended")
  }

  @available(System 199, *)
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @Test func noDomainsHaveNoPaths() {
    #expect(Array(SearchPaths(.caches, in: [])).isEmpty)
  }

  /// The paths match sysdir's, called directly.
  @available(System 199, *)
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @Test func everyDirectoryMatchesTheCLibrary() {
    let directories: [SearchPaths.Directory] = [
      .applications, .demoApplications, .developerApplications, .adminApplications,
      .library, .developer, .users, .documentation, .documents, .coreServices,
      .autosavedInformation, .desktop, .caches, .applicationSupport, .downloads,
      .inputMethods, .movies, .music, .pictures, .printerDescriptions,
      .sharedPublic, .preferencePanes, .allApplications, .allLibraries,
    ]
    #expect(directories.map(\.rawValue) == Array(1...22) + [100, 101])
    for directory in directories {
      var expected: [FilePath] = []
      var state = sysdir_start_search_path_enumeration(
        sysdir_search_path_directory_t(directory.rawValue), .SYSDIR_DOMAIN_MASK_ALL)
      var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
      while true {
        state = sysdir_get_next_search_path_enumeration(state, &buffer)
        guard state != 0 else { break }
        expected.append(FilePath(platformString: buffer))
      }
      #expect(Array(SearchPaths(directory, in: .all)) == expected, "\(directory)")
    }
  }

  @available(System 199, *)
  @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
  @Test func domains() {
    typealias Domains = SearchPaths.Domains
    #expect([Domains.user, .local, .network, .system].map(\.rawValue) == [1, 2, 4, 8])
    #expect(Domains.all.rawValue == 0xFFFF)
    #expect(Domains.all.isSuperset(of: [.user, .local, .network, .system]))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
