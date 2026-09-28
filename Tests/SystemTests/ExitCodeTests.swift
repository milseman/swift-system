/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Exit codes")
private struct ExitCodeTests {
  @available(System 199, *)
  @Test func theCodesAreTheCLibrarys() {
    typealias Code = ProcessID.ExitCode
    #expect(Code.success.rawValue == EXIT_SUCCESS && Code.success.rawValue == EX_OK)
    #expect(Code.failure.rawValue == EXIT_FAILURE)
    let sysexits: [(Code, CInt)] = [
      (.usageError, EX_USAGE), (.dataError, EX_DATAERR), (.cannotOpenInput, EX_NOINPUT),
      (.unknownUser, EX_NOUSER), (.unknownHost, EX_NOHOST), (.serviceUnavailable, EX_UNAVAILABLE),
      (.internalError, EX_SOFTWARE), (.systemError, EX_OSERR), (.systemFileError, EX_OSFILE),
      (.cannotCreateOutput, EX_CANTCREAT), (.ioError, EX_IOERR), (.temporaryFailure, EX_TEMPFAIL),
      (.protocolError, EX_PROTOCOL), (.permissionDenied, EX_NOPERM), (.configurationError, EX_CONFIG),
    ]
    #expect(sysexits.map { $0.0.rawValue } == sysexits.map { $0.1 })
    // <sysexits.h> numbers them from 64 through 78, one each.
    #expect(sysexits.map { $0.1 } == Array(EX__BASE...EX__MAX))
  }

  @available(System 199, *)
  @Test func descriptions() {
    #expect(ProcessID.ExitCode.usageError.description == "usageError (64)")
    #expect(ProcessID.ExitCode.success.description == "success (0)")
    #expect(ProcessID.ExitCode(rawValue: 3).description == "3")
  }

  @available(System 199, *)
  @Test func exitWithACode() async {
    await #expect(processExitsWith: .exitCode(EX_USAGE)) {
      ProcessID.exit(.usageError)
    }
  }

  @available(System 199, *)
  @Test func exitImmediatelyWithACode() async {
    await #expect(processExitsWith: .exitCode(EX_TEMPFAIL)) {
      ProcessID.exitImmediately(.temporaryFailure)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
