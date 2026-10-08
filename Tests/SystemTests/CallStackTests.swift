/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The call stack on Darwin and on Linux with glibc. SmallDarwinGapsTest's
// testCallStack checks the symbols' names, which Darwin's backtrace_symbols
// finds for the test's own functions; glibc's finds only the dynamic
// symbol table's, which a test executable's functions aren't in.

#if SYSTEM_PACKAGE_DARWIN || (os(Linux) && canImport(Glibc))

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Call stack")
private struct CallStackTests {
  @available(System 199, *)
  @Test func returnAddressesAndTheirSymbols() throws {
    let addresses = CallStack.returnAddresses()
    #expect(addresses.count > 2)
    #expect(CallStack.returnAddresses(maxCount: 2).count == 2)
    #expect(CallStack.returnAddresses(maxCount: 0).isEmpty)
    let symbols = try CallStack.symbols(for: addresses)
    #expect(symbols.count == addresses.count)
    #expect(symbols.allSatisfy { !$0.isEmpty })
    #expect(try CallStack.symbols(for: []).isEmpty)
  }

  #if SYSTEM_PACKAGE_DARWIN
  // From an async function, the stack goes through the async functions that
  // awaited it; the frames are the test's own.
  @available(System 199, *)
  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  @Test func asyncReturnAddresses() async throws {
    let addresses = await Self.awaited()
    #expect(addresses.count > 1)
    #expect(CallStack.asyncReturnAddresses(maxCount: 1).count == 1)
    #expect(CallStack.asyncReturnAddresses(maxCount: 0).isEmpty)
    let symbols = try CallStack.symbols(for: addresses)
    #expect(symbols.count == addresses.count)
  }

  @available(System 199, *)
  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  private static func awaited() async -> [UnsafeRawPointer] {
    await Task.yield()
    return CallStack.asyncReturnAddresses()
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || (os(Linux) && canImport(Glibc))
