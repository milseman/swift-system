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
import SystemPackage
#else
import System
#endif

@Suite("POSIXErrorCode")
private struct ProvisionalPOSIXErrorCodeTests {
  @available(System 199, *)
  @Test func itIsTheOverlaysType() {
    #expect(CInterop.POSIXErrorCode.self == POSIXErrorCode.self)
    let code: CInterop.POSIXErrorCode = .ENOENT
    #expect(code == POSIXErrorCode.ENOENT)
  }

  @available(System 199, *)
  @Test func convertingThroughErrno() {
    #expect(CInterop.POSIXErrorCode(.notPermitted) == .EPERM)
    #expect(CInterop.POSIXErrorCode(.noSuchFileOrDirectory)?.errno == .noSuchFileOrDirectory)
    #expect(CInterop.POSIXErrorCode.ETIMEDOUT.errno == .timedOut)
    // An error number the overlay has no case for.
    #expect(CInterop.POSIXErrorCode(Errno(rawValue: 9999)) == nil)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
