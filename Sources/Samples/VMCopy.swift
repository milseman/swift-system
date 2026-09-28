/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin

struct VMCopy: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vm-copy",
    abstract: "Copy pages with Mach's vm_copy and with memmove, and time both, as Foundation's Data chooses between them"
  )

  @Option(name: .shortAndLong, help: "How many mebibytes to copy")
  var mebibytes: Int = 64

  func run() throws {
    guard #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) else {
      complain("vm-copy times with ContinuousClock, which requires macOS 13 or later")
      throw ExitCode.failure
    }
    let byteCount = mebibytes << 20
    let source = try Mach.VirtualMemory.allocate(byteCount: byteCount)
    defer { try? Mach.VirtualMemory.deallocate(source) }
    let destination = try Mach.VirtualMemory.allocate(byteCount: byteCount)
    defer { try? Mach.VirtualMemory.deallocate(destination) }
    // Touch every page, so that the copies copy memory that exists.
    for i in stride(from: 0, to: byteCount, by: 4096) { source[i] = UInt8(truncatingIfNeeded: i >> 12) }
    destination.initializeMemory(as: UInt8.self, repeating: 1)

    let clock = ContinuousClock()
    let moved = clock.measure {
      memmove(destination.baseAddress!, source.baseAddress!, byteCount)
    }
    print("memmove: \(mebibytes) MiB in \(moved)")

    var failure: Mach.KernelError?
    let copied = clock.measure {
      do throws(Mach.KernelError) {
        try Mach.VirtualMemory.copy(from: UnsafeRawBufferPointer(source), to: destination.baseAddress!)
      } catch {
        failure = error
      }
    }
    if let failure {
      complain("vm_copy failed: \(failure)")
      throw ExitCode.failure
    }
    print("vm_copy: \(mebibytes) MiB in \(copied)")

    // The copy can share pages copy-on-write, so the cost of copying moves
    // to the first write to each page.
    let written = clock.measure {
      for i in stride(from: 0, to: byteCount, by: 4096) { destination[i] &+= 1 }
    }
    print("writing to every page afterward: \(written)")
    print(destination.elementsEqual(source.lazy.enumerated().map { $0.offset % 4096 == 0 ? $0.element &+ 1 : $0.element })
          ? "The copy matches." : "The copy doesn't match!")
  }
}

#else
struct VMCopy: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vm-copy",
    abstract: "Unavailable: Mach virtual memory is Darwin's"
  )

  func run() throws {
    complain("vm-copy isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
