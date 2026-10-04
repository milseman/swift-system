/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
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
#else
#error("Unsupported Platform")
#endif

import SystemPackage
@testable import SystemSockets

private typealias AncillaryMessageBuffer = SocketDescriptor.AncillaryMessageBuffer
private typealias UnsafeAncillaryMessages = SocketDescriptor.UnsafeAncillaryMessages

// Messages built and read without a socket. SocketMessagesTests sends and
// receives them, and so checks the layout against what the kernel expects
// and produces.
@Suite("Ancillary Message Buffer")
private struct AncillaryMessageBufferTests {
  @available(System 199, *)
  @Test("Append and iterate messages")
  func testAppend() {
    // Create a buffer of 100 messages, with varying payload lengths.
    var buffer = AncillaryMessageBuffer(minimumCapacity: 0)
    for i in 0 ..< 100 {
      let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: i, alignment: 1)
      defer { bytes.deallocate() }
      system_memset(bytes, to: UInt8(i))
      buffer.appendMessage(level: .init(rawValue: CInt(100 * i)),
                           type: .init(rawValue: CInt(1000 * i)),
                           bytes: UnsafeRawBufferPointer(bytes))
    }
    // Check that we can access appended messages.
    var i = 0
    for message in buffer {
      #expect(Int(message.level.rawValue) == 100 * i)
      #expect(Int(message.type.rawValue) == 1000 * i)
      message.withUnsafeBytes { buffer in
        #expect(buffer.count == i)
        for idx in buffer.indices {
          #expect(buffer[idx] == UInt8(i), "byte #\(idx)")
        }
      }
      i += 1
    }
    #expect(i == 100, "Too many messages in buffer")
  }

  /// The sizes that the platform's CMSG_SPACE and CMSG_LEN give.
  @available(System 199, *)
  @Test func spaceAndLengthMatchTheCMacros() {
    // The header, and the padding that aligns the payload after it.
    #if SYSTEM_PACKAGE_DARWIN
    // A 12-byte cmsghdr, aligned to 4 bytes (__DARWIN_ALIGN32).
    let (header, alignment) = (12, 4)
    #else
    // Linux aligns to sizeof(size_t) (CMSG_ALIGN), and its cmsghdr starts
    // with a size_t. The BSDs align their 12-byte cmsghdr to sizeof(long)
    // (_ALIGN). Either way that's 16 bytes on 64-bit platforms.
    let (header, alignment) = (MemoryLayout<Int>.size == 8 ? 16 : 12, MemoryLayout<Int>.size)
    #endif
    #expect(AncillaryMessageBuffer.length(forPayloadSize: 0) == header)
    #expect(AncillaryMessageBuffer.space(forPayloadSize: 0) == header)
    for payload in [1, 3, 4, 5, 8, 12, 13, 16, 20] {
      let padded = (payload + alignment - 1) / alignment * alignment
      #expect(AncillaryMessageBuffer.length(forPayloadSize: payload) == header + payload)
      #expect(AncillaryMessageBuffer.space(forPayloadSize: payload) == header + padded)
    }
  }

  @available(System 199, *)
  @Test func messagesStartAtAlignedOffsets() {
    var buffer = AncillaryMessageBuffer()
    let payloads: [[UInt8]] = [[1], [2, 3, 4, 5, 6], [], [7, 8, 9]]
    for (i, payload) in payloads.enumerated() {
      payload.withUnsafeBytes {
        buffer.appendMessage(level: .init(rawValue: CInt(i)), type: .init(rawValue: 7), bytes: $0)
      }
    }
    // Each message takes up CMSG_SPACE of its payload, and the buffer ends
    // after the last one's padding.
    let spaces = payloads.map { AncillaryMessageBuffer.space(forPayloadSize: $0.count) }
    #expect(buffer.byteCount == spaces.reduce(0, +))
    #expect(buffer.capacity >= buffer.byteCount)

    buffer.withUnsafeBytes { bytes in
      let messages = UnsafeAncillaryMessages(bytes)
      #expect(messages.indices.map(\.offset) == [0] + spaces.dropLast().reduce(into: []) {
        $0.append(($0.last ?? 0) + $1)
      })
      // Each header records CMSG_LEN of its payload, and the padding is zero.
      for (index, payload) in zip(messages.indices, payloads) {
        let header = bytes.loadUnaligned(fromByteOffset: index.offset, as: CInterop.CMsgHdr.self)
        #expect(Int(header.cmsg_len) == AncillaryMessageBuffer.length(forPayloadSize: payload.count))
        let end = index.offset + AncillaryMessageBuffer.space(forPayloadSize: payload.count)
        let messageLength = Int(header.cmsg_len)
        #expect(bytes[index.offset + messageLength ..< end].allSatisfy { $0 == 0 })
        #expect(Array(messages[index].payload) == payload)
      }
    }
  }

  @available(System 199, *)
  @Test func fileDescriptorsRoundTrip() {
    var buffer = AncillaryMessageBuffer()
    buffer.appendFileDescriptors([FileDescriptor(rawValue: 3), FileDescriptor(rawValue: 42)])
    buffer.appendMessage(level: .ip, type: .init(rawValue: 1), bytes: UnsafeRawBufferPointer(start: nil, count: 0))
    buffer.appendFileDescriptors(CollectionOfOne(FileDescriptor(rawValue: 7)))

    let messages = Array(buffer)
    #expect(messages.count == 3)
    #expect(messages[0].level == .socket)
    #expect(messages[0].type == .rights)
    #expect(messages[0].type.rawValue == CInt(SCM_RIGHTS))
    #expect(messages[0].fileDescriptors == [FileDescriptor(rawValue: 3), FileDescriptor(rawValue: 42)])
    #expect(messages[0].withUnsafeBytes { $0.count } == 2 * MemoryLayout<CInt>.size)
    // Another kind of message has no descriptors.
    #expect(messages[1].fileDescriptors == nil)
    #expect(messages[2].fileDescriptors == [FileDescriptor(rawValue: 7)])

    // The unsafe view reads the same messages.
    buffer.withUnsafeBytes { bytes in
      let view = UnsafeAncillaryMessages(bytes)
      #expect(view.map(\.fileDescriptors) == [
        [FileDescriptor(rawValue: 3), FileDescriptor(rawValue: 42)], nil, [FileDescriptor(rawValue: 7)],
      ])
    }
  }

  @available(System 199, *)
  @Test func unsafeMessagesReadMemoryYouManage() throws {
    var buffer = AncillaryMessageBuffer()
    for (level, type, payload) in [(CInt(1), CInt(2), [UInt8](repeating: 9, count: 5)), (3, 4, [8, 7])] {
      payload.withUnsafeBytes {
        buffer.appendMessage(level: .init(rawValue: level), type: .init(rawValue: type), bytes: $0)
      }
    }
    // Copy the messages into memory that nothing else knows about,
    // at an odd address, which the loads must tolerate.
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: buffer.byteCount + 1, alignment: 16)
    defer { storage.deallocate() }
    let control = UnsafeMutableRawBufferPointer(rebasing: storage[1...])
    buffer.withUnsafeBytes { control.copyMemory(from: $0) }

    let messages = UnsafeAncillaryMessages(UnsafeRawBufferPointer(control))
    #expect(messages.count == 2)
    #expect(messages.map(\.level.rawValue) == [1, 3])
    #expect(messages.map(\.type.rawValue) == [2, 4])
    #expect(messages.map { Array($0.payload) } == [[9, 9, 9, 9, 9], [8, 7]])
    // The payload is in place, not a copy.
    let first = try #require(messages.first)
    #expect(first.payload.baseAddress == UnsafeRawPointer(control.baseAddress! + AncillaryMessageBuffer.length(forPayloadSize: 0)))

    // A message header's control buffer is msg_control and msg_controllen.
    var header = CInterop.MsgHdr()
    header.msg_control = control.baseAddress
    header.msg_controllen = .init(control.count)
    #expect(UnsafeAncillaryMessages(header).count == 2)
    header.msg_controllen = 0
    #expect(UnsafeAncillaryMessages(header).isEmpty)
    #expect(UnsafeAncillaryMessages(CInterop.MsgHdr()).isEmpty)
  }

  @available(System 199, *)
  @Test func corruptOrTruncatedMessagesEndTheCollection() {
    var buffer = AncillaryMessageBuffer()
    [UInt8](repeating: 1, count: 4).withUnsafeBytes {
      buffer.appendMessage(level: .socket, type: .init(rawValue: 5), bytes: $0)
      buffer.appendMessage(level: .socket, type: .init(rawValue: 6), bytes: $0)
    }
    let secondOffset = AncillaryMessageBuffer.space(forPayloadSize: 4)

    /// Returns the types of the messages in a copy of the buffer,
    /// after `corrupt` changes the copy's bytes.
    func types(after corrupt: (UnsafeMutableRawBufferPointer) -> Int) -> [CInt] {
      var copy = buffer
      copy.withUnsafeMutableBytes { bytes, count in count = corrupt(bytes) }
      let owned = copy.map(\.type.rawValue)
      let viewed = copy.withUnsafeBytes { UnsafeAncillaryMessages($0).map(\.type.rawValue) }
      #expect(owned == viewed)
      return owned
    }
    func setLength(_ length: Int, at offset: Int, in bytes: UnsafeMutableRawBufferPointer) {
      var header = bytes.loadUnaligned(fromByteOffset: offset, as: CInterop.CMsgHdr.self)
      header.cmsg_len = .init(length)
      bytes.storeBytes(of: header, toByteOffset: offset, as: CInterop.CMsgHdr.self)
    }
    let count = buffer.byteCount

    #expect(types { _ in count } == [5, 6])
    // A length too short for the header, which would make CMSG_NXTHDR
    // return the same header forever on some platforms.
    #expect(types { setLength(0, at: 0, in: $0); return count } == [])
    #expect(types { setLength(0, at: secondOffset, in: $0); return count } == [5])
    // A length that runs past the end of the buffer.
    #expect(types { setLength(count, at: secondOffset, in: $0); return count } == [5])
    // A buffer that ends partway through a message's payload, or its
    // header. (Ending in the padding after the last payload is fine.)
    let secondEnd = secondOffset + AncillaryMessageBuffer.length(forPayloadSize: 4)
    #expect(types { _ in secondEnd } == [5, 6])
    #expect(types { _ in secondEnd - 1 } == [5])
    #expect(types { _ in secondOffset + 2 } == [5])
    #expect(types { _ in 2 } == [])
    #expect(types { _ in 0 } == [])
  }

  @available(System 199, *)
  @Test func capacityAndRemoveAll() {
    var buffer = AncillaryMessageBuffer(minimumCapacity: 64)
    #expect(buffer.capacity >= 64)
    #expect(buffer.isEmpty)
    #expect(buffer.byteCount == 0)
    buffer.appendFileDescriptors([FileDescriptor(rawValue: 1)])
    #expect(buffer.count == 1)
    let capacity = buffer.capacity
    buffer.removeAll()
    #expect(buffer.isEmpty)
    #expect(buffer.capacity == capacity)

    // A new buffer allocates nothing until it needs to.
    #expect(AncillaryMessageBuffer().capacity == 0)
    #expect(AncillaryMessageBuffer().isEmpty)
  }

  @available(System 199, *)
  @Test func copiesDoNotShareMessages() {
    var original = AncillaryMessageBuffer()
    original.appendFileDescriptors([FileDescriptor(rawValue: 1)])
    var copy = original
    copy.appendFileDescriptors([FileDescriptor(rawValue: 2)])
    copy.withUnsafeMutableBytes { bytes, count in
      bytes.storeBytes(of: 99, toByteOffset: AncillaryMessageBuffer.length(forPayloadSize: 0), as: CInt.self)
    }
    #expect(original.map(\.fileDescriptors) == [[FileDescriptor(rawValue: 1)]])
    #expect(copy.map(\.fileDescriptors) == [[FileDescriptor(rawValue: 99)], [FileDescriptor(rawValue: 2)]])
  }
}

#endif // !os(Windows) && !os(WASI)
