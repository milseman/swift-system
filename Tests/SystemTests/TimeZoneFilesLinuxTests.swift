/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

import Testing

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

// TimeZoneFilesTests has Darwin's paths.
@Suite("Time zone files on Linux")
private struct TimeZoneFilesLinuxTests {
  /// The conventional paths. A container can have neither: the plain
  /// Ubuntu images have no time zone data. Android has neither: its time
  /// zones are in one file.
  @available(System 199, *)
  @Test func theDirectoryAndTheDefault() throws {
    #expect(FilePath.timeZoneDirectory == "/usr/share/zoneinfo")
    #expect(FilePath.defaultTimeZoneFile == "/etc/localtime")
    // Where there's data, there's a file for each zone, and every tzdata
    // has Etc/UTC.
    if let directory = try? FilePath.timeZoneDirectory.stat(), directory.type == .directory {
      let utc = try FilePath.timeZoneDirectory.appending("Etc/UTC").stat()
      #expect(utc.type == .regular)
    }
  }
}

#endif // os(Linux) || os(Android)
