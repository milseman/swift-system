/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The accessors of CInterop+Accessors.swift read and write the C fields
// they name. This file imports the C library, as a client that uses both
// would, and so also checks that the two sets of names don't collide.

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

/// Whether two values of a C type have the same bytes.
private func sameBytes<T>(_ a: T, _ b: T) -> Bool {
  withUnsafeBytes(of: a) { a in withUnsafeBytes(of: b) { b in a.elementsEqual(b) } }
}

@Suite("C structure accessors")
private struct CInteropAccessorsTests {
  @available(System 199, *)
  @Test func timeSpecAccessors() {
    var time = CInterop.TimeSpec(seconds: 3, nanoseconds: 4)
    #expect(time.tv_sec == 3 && time.tv_nsec == 4)
    time.seconds = 5
    time.nanoseconds = 6
    #expect(time.tv_sec == 5 && time.tv_nsec == 6)
    #expect(sameBytes(CInterop.TimeSpec(), timespec()))
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timeSpecDurations() {
    let time = CInterop.TimeSpec(duration: .milliseconds(1500))
    #expect(time.seconds == 1 && time.nanoseconds == 500_000_000)
    #expect(time.duration == .milliseconds(1500))
    // Normalized: the nanoseconds are never negative.
    let negative = CInterop.TimeSpec(duration: .milliseconds(-500))
    #expect(negative.seconds == -1 && negative.nanoseconds == 500_000_000)
    #expect(negative.duration == .milliseconds(-500))
    // Rounded down to a nanosecond.
    #expect(CInterop.TimeSpec(duration: .nanoseconds(1) / 2).nanoseconds == 0)
    var changed = time
    changed.duration += .seconds(1)
    #expect(changed.seconds == 2)
    // The C library's own conversion, which has no label, is still there.
    #expect(timespec(Duration.seconds(2)).tv_sec == 2)
  }

  @available(System 199, *)
  @Test func timeValAccessors() {
    var time = CInterop.TimeVal(seconds: 3, microseconds: 4)
    #expect(time.tv_sec == 3 && time.tv_usec == 4)
    time.seconds = 5
    time.microseconds = 6
    #expect(time.tv_sec == 5 && time.tv_usec == 6)
    // timeval has padding after tv_usec on 64-bit Darwin, so compare fields.
    let zero = CInterop.TimeVal()
    #expect(zero.tv_sec == 0 && zero.tv_usec == 0)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timeValDurations() {
    let time = CInterop.TimeVal(duration: .milliseconds(1500))
    #expect(time.seconds == 1 && time.microseconds == 500_000)
    #expect(time.duration == .milliseconds(1500))
    // Normalized: the microseconds are never negative.
    let negative = CInterop.TimeVal(duration: .milliseconds(-500))
    #expect(negative.seconds == -1 && negative.microseconds == 500_000)
    #expect(negative.duration == .milliseconds(-500))
    // Rounded down to a microsecond, for negative durations too.
    #expect(CInterop.TimeVal(duration: .nanoseconds(999)).microseconds == 0)
    let justBelow = CInterop.TimeVal(duration: .nanoseconds(-1))
    #expect(justBelow.seconds == -1 && justBelow.microseconds == 999_999)
    var changed = time
    changed.duration += .microseconds(500_001)
    #expect(changed.seconds == 2 && changed.microseconds == 1)
  }

  #if !os(WASI)
  @available(System 199, *)
  @Test func ioVecAccessors() {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    var vector = CInterop.IOVec(buffer)
    #expect(vector.iov_base == buffer.baseAddress && vector.iov_len == 8)
    vector.length = 3
    vector.base = buffer.baseAddress! + 1
    #expect(vector.iov_base == buffer.baseAddress! + 1 && vector.iov_len == 3)
    #expect(sameBytes(CInterop.IOVec(), iovec()))
    #expect(sameBytes(CInterop.IOVec(base: nil, length: 0), iovec(iov_base: nil, iov_len: 0)))
  }
  #endif

  @available(System 199, *)
  @Test func statAccessors() throws {
    var status = CInterop.Stat(inode: Inode(rawValue: 7), size: 100)
    #expect(status.st_ino == 7 && status.st_size == 100)
    status.mode = FileMode(rawValue: 0o100644)
    status.linkCount = 2
    status.userID = UserID(rawValue: 501)
    status.groupID = GroupID(rawValue: 20)
    status.blocksAllocated = 8
    status.preferredIOBlockSize = 4096
    status.modificationTime = CInterop.TimeSpec(seconds: 9, nanoseconds: 10)
    #expect(status.st_mode == 0o100644 && status.st_nlink == 2)
    #expect(status.st_uid == 501 && status.st_gid == 20)
    #expect(status.st_blocks == 8 && status.st_blksize == 4096)
    #expect(Stat(rawValue: status).st_mtim.tv_sec == 9)
    #expect(Stat(rawValue: status).type == .regular)
    // stat has padding, which Swift doesn't keep when it copies a value,
    // so compare fields.
    let zero = CInterop.Stat()
    #expect(zero.st_ino == 0 && zero.st_size == 0 && zero.st_mode == 0 && zero.st_nlink == 0)
    // A real file's status reads the same through both.
    let real = try FilePath("/").stat().rawValue
    #expect(real.inode == Stat(rawValue: real).inode)
    #expect(real.accessTime.seconds == Stat(rawValue: real).st_atim.tv_sec)
  }

  #if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func keventAccessors() {
    var event = CInterop.KEvent(identifier: 3, eventFilter: .read, eventFlags: .add, filterData: 5)
    #expect(event.ident == 3 && event.filter == Int16(EVFILT_READ))
    #expect(event.flags == UInt16(EV_ADD) && event.data == 5)
    event.filterFlags = KernelEvent.FilterFlags(rawValue: 0x10)
    event.userData = UnsafeMutableRawPointer(bitPattern: 0x40)
    #expect(event.fflags == 0x10 && event.udata == UnsafeMutableRawPointer(bitPattern: 0x40))
    #expect(KernelEvent(rawValue: event).identifier == 3)
    #expect(sameBytes(CInterop.KEvent(), Darwin.kevent()))
  }
  #endif
}

#endif // !os(Windows)
