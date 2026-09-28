/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

@Suite("Time zone files")
private struct TimeZoneFilesTests {
  @available(System 199, *)
  @Test func theDirectoryAndTheDefault() throws {
    #expect(FilePath.timeZoneDirectory == "/var/db/timezone/zoneinfo")
    #expect(FilePath.defaultTimeZoneFile == "/etc/localtime")
    // The directory has a file for each zone.
    #expect(try FilePath.timeZoneDirectory.appending("America/Denver").stat().type == .regular)
    // The default is a link into a directory named zoneinfo.
    let target = try FilePath.defaultTimeZoneFile.readSymbolicLink()
    #expect(target.string.contains("zoneinfo/"))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
