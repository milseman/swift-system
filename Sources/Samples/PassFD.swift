/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

private typealias AncillaryMessageBuffer = SocketDescriptor.AncillaryMessageBuffer

struct PassFD: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pass-fd",
    abstract: "Pass open files from one end of a socket pair to the other, as SCM_RIGHTS messages"
  )

  @Argument(help: "Where to make a temporary file, which is removed as soon as it's open")
  var directory: String = "/tmp"

  func run() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("pass-fd sends its messages from spans, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    try passDescriptors()
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func passDescriptors() throws {
    // Descriptors travel over local sockets. Both ends are in this process,
    // but the kernel treats the receiver as it would another process.
    let (sender, receiver) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? sender.close()
      try? receiver.close()
    }

    // A pipe, and a file with no name: once the file is unlinked,
    // an open descriptor is the only way to reach it.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let path = FilePath(directory).appending("pass-fd-\(ProcessID.current.rawValue)")
    let file = try FileDescriptor.open(
      path, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    defer { try? file.close() }
    try path.unlink()
    try file.writeAll("written before passing".utf8)

    var outgoing = AncillaryMessageBuffer()
    outgoing.appendFileDescriptors([pipe.readEnd, file])
    try send("two descriptors", with: outgoing, on: sender)
    print("Sent descriptors \(pipe.readEnd.rawValue), a pipe's read end, and \(file.rawValue), "
      + "a file already unlinked from \(path), with the message \"two descriptors\"")

    // Make room for the descriptors the message is expected to carry.
    var incoming = AncillaryMessageBuffer(
      minimumCapacity: AncillaryMessageBuffer.space(forPayloadSize: 2 * MemoryLayout<CInt>.size))
    let (text, flags) = try receive(from: receiver, into: &incoming)
    print("Received \"\(text)\" with \(incoming.count) ancillary message, flags \(flags)")
    guard let message = incoming.first, let passed = message.fileDescriptors, passed.count == 2 else {
      complain("Error: the message didn't pass two descriptors")
      throw ExitCode.failure
    }
    defer { for descriptor in passed { try? descriptor.close() } }
    print("  Level \(message.level == .socket ? "SOL_SOCKET" : "\(message.level.rawValue)"), "
      + "type \(message.type == .rights ? "SCM_RIGHTS" : "\(message.type.rawValue)"), "
      + "\(message.withUnsafeBytes { $0.count })-byte payload: "
      + "descriptors \(passed[0].rawValue) and \(passed[1].rawValue), "
      + "new numbers for the same open files")

    try pipe.writeEnd.writeAll("hello through the pipe".utf8)
    print("Wrote to the pipe; the received read end reads \"\(try read(from: passed[0]))\"")

    // Both descriptors refer to one open file, so they share its offset.
    _ = try passed[1].seek(offset: 0, from: .start)
    print("The received file descriptor reads \"\(try read(from: passed[1]))\" "
      + "from a file with no name")
    print("That moved the original descriptor's offset too, "
      + "to \(try file.seek(offset: 0, from: .current))")

    // Without room for them, the descriptors don't arrive, and the kernel
    // closes them. Linux reports that with MSG_CTRUNC; Darwin reports it
    // only if there's a control buffer, too small, rather than none.
    try send("two more", with: outgoing, on: sender)
    var noRoom = AncillaryMessageBuffer()
    let (unlucky, truncation) = try receive(from: receiver, into: &noRoom)
    print("Sent two more, and received \"\(unlucky)\" with no room for them: "
      + "\(noRoom.count) ancillary messages, flags \(truncation)")
  }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func send(
  _ text: String, with ancillaryMessages: AncillaryMessageBuffer, on socket: SocketDescriptor
) throws {
  _ = try Array(text.utf8).withUnsafeBytes {
    try socket.sendMessage(RawSpan(_unsafeBytes: $0), ancillaryMessages: ancillaryMessages)
  }
}

/// Receives up to 1 KiB as UTF-8 text, with its ancillary messages.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func receive(
  from socket: SocketDescriptor, into ancillaryMessages: inout AncillaryMessageBuffer
) throws -> (String, SocketDescriptor.MessageFlags) {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { storage.deallocate() }
  var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
  let (count, flags) = try socket.receiveMessage(into: &buffer, ancillaryMessages: &ancillaryMessages)
  return (String(decoding: storage[..<count], as: UTF8.self), flags)
}

/// Reads up to 1 KiB as UTF-8 text.
private func read(from descriptor: FileDescriptor) throws -> String {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = try buffer.withUnsafeMutableBytes { try descriptor.read(into: $0) }
  return String(decoding: buffer[..<count], as: UTF8.self)
}
