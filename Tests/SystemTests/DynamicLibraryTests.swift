/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

/// A library that's on the system, and a function it has that takes nothing
/// and returns a C string, or nil where there isn't one to use.
private let knownLibrary: (path: FilePath, function: String)? = {
  #if SYSTEM_PACKAGE_DARWIN
  // In the dyld shared cache, rather than on disk.
  return ("/usr/lib/libz.1.dylib", "zlibVersion")
  #elseif canImport(Glibc)
  return ("libc.so.6", "gnu_get_libc_version")
  #else
  return nil
  #endif
}()

private typealias StringFunction = @convention(c) () -> UnsafePointer<CChar>?

@Suite("Dynamic loading")
private struct DynamicLibraryTests {
  @available(System 199, *)
  @Test func mainProgramFindsTheCLibrary() throws {
    let program = try DynamicLibrary.mainProgram()
    // Outside #require, which can't take a noncopyable receiver.
    let found = program.address(of: "strlen")
    let address = try #require(found)
    let strlen = unsafeBitCast(address, to: (@convention(c) (UnsafePointer<CChar>) -> Int).self)
    #expect("hello".withCString { strlen($0) } == 5)
    let missing = program.address(of: "not_a_symbol_\(UInt64.random(in: 0 ... .max))")
    #expect(missing == nil)
    try program.close()
  }

  @available(System 199, *)
  @Test func loadACallAndClose() throws {
    guard let (path, function) = knownLibrary else { return }
    let library = try DynamicLibrary(path)
    let found = library.address(of: function)
    let address = try #require(found)
    let call = unsafeBitCast(address, to: StringFunction.self)
    let version = try #require(call().map { String(cString: $0) })
    #expect(!version.isEmpty)
    try library.close()
  }

  @available(System 199, *)
  @Test func failuresDescribeThemselves() {
    let missing = "/nonexistent/libnothing-\(UInt32.random(in: 0 ... .max)).so"
    do {
      _ = try DynamicLibrary(FilePath(missing))
      Issue.record("loading \(missing) succeeded")
    } catch {
      #expect(error.message.contains("libnothing"), "\(error)")
      #expect(error.description == error.message)
    }
  }

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
  @available(System 199, *)
  @Test func noLoadFindsOnlyLoadedLibraries() throws {
    guard let (path, _) = knownLibrary else { return }
    let loaded = try DynamicLibrary(path)
    let again = try DynamicLibrary(path, options: [.now, .noLoad])
    try again.close()
    try loaded.close()
    #expect(throws: DynamicLibrary.LoaderError.self) {
      try DynamicLibrary("/nonexistent/libnothing.so", options: [.now, .noLoad])
    }
  }
  #endif

  @available(System 199, *)
  @Test func relinquishAndTakeBack() throws {
    let program = try DynamicLibrary.mainProgram()
    let handle = program.relinquish()
    let adopted = DynamicLibrary(taking: handle)
    let (adoptedHandle, found) = (adopted.handle, adopted.address(of: "strlen"))
    #expect(adoptedHandle == handle)
    #expect(found != nil)
    try adopted.close()
  }
}

#endif // !os(Windows) && !os(WASI)
