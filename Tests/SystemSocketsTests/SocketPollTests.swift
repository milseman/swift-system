/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

@testable import SystemSockets
import SystemPackage

// SocketDescriptor's poll, with the names SystemWinSocks gives WSAPoll, over
// SystemPackage's poll. Each test polls a socket pair and pipe of its own,
// which it closes once: Swift Testing runs these in parallel.
@Suite("Socket polling")
private struct SocketPollTests {
  @available(System 199, *)
  @Test func theTypesAreFileDescriptors() {
    #expect(SocketDescriptor.PollEvents.self == FileDescriptor.PollEvents.self)
    #expect(SocketDescriptor.PollEntry.self == FileDescriptor.PollEntry.self)
  }

  @available(System 199, *)
  @Test func anEntryHoldsItsSocket() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    var entry = SocketDescriptor.PollEntry(first, events: [.readable, .writable])
    #expect(entry.socket == first)
    #expect(entry.fileDescriptor == first.fileDescriptor)
    #expect(entry.events == [.readable, .writable])
    #expect(entry.returnedEvents.isEmpty)
    entry.socket = second
    #expect(entry.fileDescriptor == second.fileDescriptor)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func aConnectedSocketIsWritableThenReadable() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    let before = try first.poll(for: [.readable, .writable], timeout: .zero)
    #expect(before == .writable)
    _ = try second.fileDescriptor.writeAll([UInt8(1)])
    let after = try first.poll(for: .readable, timeout: .seconds(hangGuardSeconds))
    #expect(after == .readable)
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func socketsAndOtherDescriptorsShareAPoll() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    let pipe = try FileDescriptor.pipe()
    defer {
      try? first.close()
      try? second.close()
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    _ = try pipe.writeEnd.writeAll([UInt8(1)])
    var entries = [
      SocketDescriptor.PollEntry(first, events: .readable),
      SocketDescriptor.PollEntry(pipe.readEnd, events: .readable),
    ]
    let ready = try poll(&entries, timeout: .seconds(hangGuardSeconds))
    #expect(ready == 1)
    #expect(entries[0].returnedEvents.isEmpty)
    #expect(entries[1].returnedEvents == .readable)
    #expect(entries[0].socket == first)
  }
}

/// Polls `entries` through a mutable span.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func poll(_ entries: inout [SocketDescriptor.PollEntry], timeout: Duration?) throws -> Int {
  try entries.withUnsafeMutableBufferPointer { buffer in
    var span = MutableSpan(_unsafeElements: buffer)
    return try SocketDescriptor.poll(&span, timeout: timeout)
  }
}

#endif // !os(Windows) && !os(WASI)
