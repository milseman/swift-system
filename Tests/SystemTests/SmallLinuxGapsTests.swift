/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The Linux side of SmallGapsTest, SmallDarwinGapsTest and PThreadMutexTests'
// static initializers: unique files with a suffix (mkostemps), dladdr,
// glibc's RTLD_DEEPBIND, O_SYNC, O_DSYNC and O_RSYNC, and the default
// pthread initializers.

#if os(Linux) || os(Android)

import XCTest

#if canImport(Glibc)
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

@available(System 199, *)
final class SmallLinuxGapsTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mkostemps", .interruptable, "aXXXXXX.txt", CInt(4), O_CLOEXEC) { retryOnInterrupt in
        _ = try FilePath("aXXXXXX.txt").makeUniqueFile(
          suffixLength: 4, options: .closeOnExec, retryOnInterrupt: retryOnInterrupt)
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testUniqueFileWithASuffix() throws {
    try withTemporaryFilePath(basename: "testUniqueFileWithASuffix") { dir in
      let (path, fd) = try dir.appending("report-XXXXXX.txt").makeUniqueFile(
        suffixLength: 4, options: .closeOnExec)
      defer { try? fd.close() }
      let name = try XCTUnwrap(path.lastComponent?.string)
      XCTAssertTrue(name.hasPrefix("report-") && name.hasSuffix(".txt"))
      XCTAssertEqual(name.count, "report-XXXXXX.txt".count)
      XCTAssertFalse(name.contains("XXXXXX"))
      XCTAssertEqual(try path.stat().type, .regular)
      XCTAssertEqual(try fd.stat().mode.permissions, .ownerReadWrite)
      XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))
      // Six X's must come before the suffix.
      XCTAssertThrowsError(try dir.appending("report-XXXXX.txt").makeUniqueFile(suffixLength: 4)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try dir.appending("XXXXXX").makeUniqueFile(suffixLength: 1)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  /// dladdr finds the library that contains a function, and its symbol.
  func testSymbolInfo() throws {
    let program = try DynamicLibrary.mainProgram()
    let found = program.address(of: "getpid")
    try program.close()
    guard let getpidAddress = found else {
      // A statically linked program, as Musl's are, has no symbols to find.
      throw XCTSkip("the program has no dynamic symbols")
    }
    let info = try XCTUnwrap(DynamicLibrary.symbolInfo(containing: getpidAddress))
    // The nearest symbol can be an alias, such as glibc's __getpid.
    XCTAssertTrue(info.symbolName?.hasSuffix("getpid") == true, "\(String(describing: info.symbolName))")
    XCTAssertEqual(info.symbolAddress, UnsafeRawPointer(getpidAddress))
    #if canImport(Glibc)
    XCTAssertTrue(info.libraryPath.string.contains("libc.so"), "\(info.libraryPath)")
    #endif
    XCTAssertNotNil(info.libraryAddress)
    // An address that no library contains.
    XCTAssertNil(DynamicLibrary.symbolInfo(containing: UnsafeRawPointer(bitPattern: 0x10)!))
  }

  /// O_SYNC includes O_DSYNC on Linux, and F_SETFL can't change either.
  /// O_RSYNC is O_SYNC.
  func testSynchronizedIO() throws {
    #if arch(x86_64) || arch(arm64)
    XCTAssertEqual(FileDescriptor.OpenOptions.sync.rawValue, 0o4010000)
    XCTAssertEqual(FileDescriptor.OpenOptions.dataSync.rawValue, 0o10000)
    #endif
    XCTAssertEqual(FileDescriptor.OpenOptions.readSync, .sync)
    XCTAssertEqual(FileDescriptor.StatusFlags.readSync, .sync)
    try withTemporaryFilePath(basename: "testSynchronizedIO") { dir in
      let path = dir.appending("file")
      let sync = try FileDescriptor.open(
        path, .writeOnly, options: [.create, .sync], permissions: .ownerReadWrite)
      defer { try? sync.close() }
      XCTAssertTrue(try sync.statusFlags().contains(.sync))
      XCTAssertTrue(try sync.statusFlags().contains(.dataSync))
      let dataSync = try FileDescriptor.open(path, .writeOnly, options: .dataSync)
      defer { try? dataSync.close() }
      XCTAssertTrue(try dataSync.statusFlags().contains(.dataSync))
      XCTAssertFalse(try dataSync.statusFlags().contains(.sync))
      // Linux's F_SETFL ignores both flags.
      try dataSync.setStatusFlags(try dataSync.statusFlags().union(.sync))
      XCTAssertFalse(try dataSync.statusFlags().contains(.sync))
      try dataSync.writeAll("synchronized".utf8)
      let readSync = try FileDescriptor.open(path, .readOnly, options: .readSync)
      defer { try? readSync.close() }
      XCTAssertTrue(try readSync.statusFlags().contains(.readSync))
      var bytes = [UInt8](repeating: 0, count: 12)
      XCTAssertEqual(try bytes.withUnsafeMutableBytes { try readSync.read(into: $0) }, 12)
      XCTAssertEqual(String(decoding: bytes, as: UTF8.self), "synchronized")
    }
  }

  /// The default initializers are all zero bytes, and make C objects that
  /// work without an init call.
  func testStaticInitializers() {
    func isZero<T>(_ value: T) -> Bool {
      withUnsafeBytes(of: value) { $0.allSatisfy { $0 == 0 } }
    }
    XCTAssertTrue(isZero(CInterop.PThreadMutex.initializer))
    XCTAssertTrue(isZero(CInterop.PThreadCondition.initializer))
    XCTAssertTrue(isZero(CInterop.PThreadReadWriteLock.initializer))

    let mutex = UnsafeMutablePointer<CInterop.PThreadMutex>.allocate(capacity: 1)
    defer { mutex.deallocate() }
    mutex.initialize(to: .initializer)
    XCTAssertEqual(pthread_mutex_trylock(mutex), 0)
    XCTAssertEqual(pthread_mutex_trylock(mutex), EBUSY)
    XCTAssertEqual(pthread_mutex_unlock(mutex), 0)
    XCTAssertEqual(pthread_mutex_destroy(mutex), 0)

    let condition = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    defer { condition.deallocate() }
    condition.initialize(to: .initializer)
    XCTAssertEqual(pthread_cond_signal(condition), 0)
    XCTAssertEqual(pthread_cond_destroy(condition), 0)

    let lock = UnsafeMutablePointer<CInterop.PThreadReadWriteLock>.allocate(capacity: 1)
    defer { lock.deallocate() }
    lock.initialize(to: .initializer)
    XCTAssertEqual(pthread_rwlock_rdlock(lock), 0)
    XCTAssertEqual(pthread_rwlock_rdlock(lock), 0)
    XCTAssertEqual(pthread_rwlock_trywrlock(lock), EBUSY)
    XCTAssertEqual(pthread_rwlock_unlock(lock), 0)
    XCTAssertEqual(pthread_rwlock_unlock(lock), 0)
    XCTAssertEqual(pthread_rwlock_destroy(lock), 0)
  }

  #if canImport(Glibc)
  /// A library loaded with deep binding still has its own symbols.
  func testDeepBinding() throws {
    XCTAssertEqual(DynamicLibrary.OpenOptions.deepBind.rawValue, 0x8)
    let library = try DynamicLibrary("libm.so.6", options: [.now, .local, .deepBind])
    let cosine = library.address(of: "cos")
    XCTAssertNotNil(cosine)
    try library.close()
  }
  #endif
}

#endif // os(Linux) || os(Android)
