/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Loaded images")
private struct LoadedImagesTests {
  /// The program and its libraries, at least two.
  @available(System 199, *)
  @Test func theProgramAndItsLibraries() {
    #expect(DynamicLibrary.loadedImageCount >= 2)
  }

  /// Loading a library that isn't loaded yet adds to the count. In an exit
  /// test, so that no other test loads or unloads anything meanwhile.
  @available(System 199, *)
  @Test func loadingALibraryAddsToTheCount() async {
    await #expect(processExitsWith: .success) {
      // Libraries a test process doesn't load by itself.
      let candidates: [FilePath] = [
        "/usr/lib/libsasl2.2.dylib", "/usr/lib/libpam.2.dylib", "/usr/lib/libexslt.0.dylib",
      ]
      func isLoaded(_ path: FilePath) -> Bool {
        guard let handle = try? DynamicLibrary(path, options: [.now, .noLoad]).relinquish()
        else { return false }
        _ = dlclose(handle)
        return true
      }
      for path in candidates where !isLoaded(path) {
        let before = DynamicLibrary.loadedImageCount
        guard let handle = try? DynamicLibrary(path).relinquish() else { continue }
        let after = DynamicLibrary.loadedImageCount
        _ = dlclose(handle)
        if after <= before { exit(1) }
        return
      }
      // Every candidate was loaded already, or none loads.
      exit(2)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
