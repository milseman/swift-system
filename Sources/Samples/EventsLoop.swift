/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: event notification sample. An event loop over a pipe and a
// timer, with a kernel event queue on Darwin, FreeBSD, and OpenBSD, and
// with an epoll instance, a timerfd, and an eventfd on Linux and Android.

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Linux) || os(Android)

struct EventsLoop: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "events-loop",
    abstract: "Run an event loop over a pipe and a timer, with kqueue or epoll"
  )

  @Option(help: "The number of messages that the timer sends through the pipe")
  var messages = 3

  @Option(help: "The timer's interval, in milliseconds")
  var interval = 20

  func validate() throws {
    guard messages >= 0, interval > 0 else {
      throw ValidationError("--messages can't be negative, and --interval must be positive")
    }
  }

  func run() throws {
    guard #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) else {
      complain("events-loop uses Duration, which requires macOS 13 or later")
      throw ExitCode.failure
    }
    try runEventLoop(messages: messages, intervalMilliseconds: interval)
  }
}

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func runEventLoop(messages: Int, intervalMilliseconds: Int) throws {
  let queue = try KernelQueue()
  let pipe = try OwnedFD.pipe()
  let readEnd = pipe.readEnd
  // An optional, so that the loop can take the write end out to close it.
  var writeEnd: OwnedFD? = pipe.writeEnd

  // A timer's and a user event's identifiers are numbers of your choosing.
  let timer: UInt = 1
  let stop: UInt = 2
  try queue.register(KernelEvent(readEnd.fileDescriptor, filter: .read, flags: .add))
  try queue.register(KernelEvent(
    identifier: timer, filter: .timer, flags: .add, data: intervalMilliseconds))
  try queue.register(KernelEvent(identifier: stop, filter: .user, flags: [.add, .clear]))
  print("Watching the pipe's read end, a \(intervalMilliseconds) ms timer, and a user event")

  // The loop reuses one buffer for every poll, as an event loop would.
  let buffer = UnsafeMutableBufferPointer<KernelEvent>.allocate(capacity: 8)
  defer { buffer.deallocate() }
  var sent = 0
  var handled = 0
  var running = true
  while running {
    var events = OutputSpan(buffer: buffer, initializedCount: 0)
    try queue.poll(into: &events, timeout: .seconds(5))
    let count = events.finalize(for: buffer)
    guard count > 0 else {
      complain("Error: no event arrived in 5 seconds")
      throw ExitCode.failure
    }

    for event in buffer[..<count] {
      handled += 1
      switch event.filter {
      case .timer:
        if sent < messages {
          sent += 1
          let message = "message \(sent)"
          try writeEnd?.writeAll(message.utf8)
          print("timer: wrote \"\(message)\" to the pipe")
        } else if let end = writeEnd.take() {
          try end.close()
          try queue.register(KernelEvent(identifier: timer, filter: .timer, flags: .delete))
          print("timer: closed the pipe's write end, and deleted the timer")
        }

      case .read:
        // The read filter reports how many bytes are ready to read.
        if event.data > 0 {
          let text = try read(event.data, from: readEnd)
          print("read: \(event.data) bytes, \"\(text)\"")
        }
        if event.flags.contains(.endOfFile) {
          // The pipe stays readable at the end of file, so stop watching it.
          try queue.register(KernelEvent(readEnd.fileDescriptor, filter: .read, flags: .delete))
          // Any thread could trigger the user event to stop the loop.
          try queue.register(KernelEvent(identifier: stop, filter: .user, filterFlags: .userTrigger))
          print("read: end of file, so the loop triggered the user event")
        }

      case .user:
        print("user: stopping")
        running = false

      default:
        print("unexpected: \(event)")
      }
    }
  }
  print("Handled \(handled) events")
  try queue.close()
}

#elseif os(Linux) || os(Android)
// Not run: nothing here builds for Linux. Prototype/Events/check-linux.sh
// typechecks it.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func runEventLoop(messages: Int, intervalMilliseconds: Int) throws {
  let epoll = try EventPoll(options: .closeOnExec)
  let pipe = try OwnedFD.pipe()
  let readEnd = pipe.readEnd
  // An optional, so that the loop can take the write end out to close it.
  var writeEnd: OwnedFD? = pipe.writeEnd

  // epoll watches file descriptors, so the timer and the stop event are
  // descriptors too. Each one's data is its descriptor.
  let timer = try IntervalTimer(options: [.closeOnExec, .nonBlocking])
  let stop = try EventCounter(options: [.closeOnExec, .nonBlocking])
  for descriptor in [readEnd.fileDescriptor, timer.fileDescriptor, stop.fileDescriptor] {
    try epoll.add(descriptor, events: .readable, data: .fileDescriptor(descriptor))
  }
  let interval = Duration.milliseconds(intervalMilliseconds)
  try timer.setSchedule(.init(nextExpiration: interval, interval: interval))
  print("Watching the pipe's read end, a \(intervalMilliseconds) ms timer, and an event counter")

  // The loop reuses one buffer for every wait, as an event loop would.
  let buffer = UnsafeMutableBufferPointer<EventPoll.Event>.allocate(capacity: 8)
  defer { buffer.deallocate() }
  var sent = 0
  var handled = 0
  var running = true
  while running {
    var events = OutputSpan(buffer: buffer, initializedCount: 0)
    try epoll.wait(into: &events, timeout: .seconds(5))
    let count = events.finalize(for: buffer)
    guard count > 0 else {
      complain("Error: no event arrived in 5 seconds")
      throw ExitCode.failure
    }

    for event in buffer[..<count] {
      handled += 1
      switch event.data.fileDescriptor {
      case timer.fileDescriptor:
        _ = try timer.readExpirations()
        if sent < messages {
          sent += 1
          let message = "message \(sent)"
          try writeEnd?.writeAll(message.utf8)
          print("timer: wrote \"\(message)\" to the pipe")
        } else if let end = writeEnd.take() {
          try end.close()
          try timer.setSchedule(.disarmed)
          print("timer: closed the pipe's write end, and stopped the timer")
        }

      case readEnd.fileDescriptor:
        // epoll doesn't report how many bytes are ready, so read what fits.
        if event.events.contains(.readable) {
          let text = try read(64, from: readEnd)
          if !text.isEmpty { print("read: \(text.utf8.count) bytes, \"\(text)\"") }
        }
        if event.events.contains(.hangUp) {
          // The pipe stays readable at the end of file, so stop watching it.
          try epoll.remove(readEnd.fileDescriptor)
          // Any thread could increment the counter to stop the loop.
          try stop.increment()
          print("read: end of file, so the loop incremented the event counter")
        }

      case stop.fileDescriptor:
        _ = try stop.read()
        print("counter: stopping")
        running = false

      default:
        print("unexpected: \(event)")
      }
    }
  }
  print("Handled \(handled) events")
  try epoll.close()
}
#endif

/// Reads up to `count` bytes from `file`, as UTF-8 text.
private func read(_ count: Int, from file: borrowing OwnedFD) throws(Errno) -> String {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
  defer { buffer.deallocate() }
  let read = try file.read(into: buffer)
  return String(decoding: buffer[..<read], as: UTF8.self)
}

#else
struct EventsLoop: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "events-loop",
    abstract: "Unavailable: this platform has neither kqueue nor epoll"
  )

  func run() throws {
    complain("Error: events-loop needs kqueue or epoll, which this platform doesn't have")
    throw ExitCode.failure
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Linux) || os(Android)
