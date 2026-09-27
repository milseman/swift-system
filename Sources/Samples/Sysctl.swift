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

struct Sysctl: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sysctl",
    abstract: "Show the kernel's state variables, typed, or list processes as ps does"
  )

  @Argument(help: "Variables to show, read as strings (or as integers with --integer)")
  var names: [String] = []

  @Flag(help: "Read the named variables as 32- or 64-bit integers")
  var integer = false

  @Flag(help: "List the processes, from kern.proc.all")
  var processes = false

  func run() throws {
    if processes { return try listProcesses() }
    guard names.isEmpty else {
      for name in names { print("\(name): \(read(name))") }
      return
    }
    // Each name knows its value's type, so each read is the right size.
    printTable([
      ["hw.model", "\(try SystemControl.value(.model))"],
      ["hw.machine", "\(try SystemControl.value(.machine))"],
      ["machdep.cpu.brand_string", "\(try SystemControl.value(.cpuBrand))"],
      ["hw.logicalcpu", "\(try SystemControl.value(.logicalProcessorCount))"],
      ["hw.physicalcpu", "\(try SystemControl.value(.physicalProcessorCount))"],
      ["hw.memsize", amount(Int64(try SystemControl.value(.memorySize)))],
      ["hw.pagesize", amount(try SystemControl.value(.pageSize))],
      ["hw.cachelinesize", "\(try SystemControl.value(.cacheLineSize))"],
      ["hw.tbfrequency", "\(try SystemControl.value(.timebaseFrequency)) Hz"],
      ["kern.ostype", "\(try SystemControl.value(.osType))"],
      ["kern.osproductversion", "\(try SystemControl.value(.osProductVersion))"],
      ["kern.osversion", "\(try SystemControl.value(.osVersion))"],
      ["kern.osrelease", "\(try SystemControl.value(.osRelease))"],
      ["kern.hostname", "\(try SystemControl.value(.hostName))"],
      ["kern.boottime", "\(since(try SystemControl.value(.bootTime))) ago"],
      ["kern.maxfilesperproc", "\(try SystemControl.value(.maxFilesPerProcess))"],
      ["kern.argmax", amount(Int64(try SystemControl.value(.maxArgumentBytes)))],
      ["vm.loadavg", loads(try SystemControl.value(.loadAverage))],
    ])
  }

  /// Reads a variable whose type the command line doesn't give.
  private func read(_ name: String) -> String {
    do {
      guard integer else { return try SystemControl.value(SystemControl.Name<String>(name)) }
      // An integer variable is 4 or 8 bytes.
      switch try SystemControl.valueSize(SystemControl.Name<Int64>(name)) {
      case 4: return "\(try SystemControl.value(SystemControl.Name<Int32>(name)))"
      case 8: return "\(try SystemControl.value(SystemControl.Name<Int64>(name)))"
      case let size: return "not an integer, but \(size) bytes"
      }
    } catch {
      return "\(error)"
    }
  }

  private func listProcesses() throws {
    let all = try SystemControl.value(.allProcesses)
    var rows = [["PID", "PPID", "UID", "COMMAND"]]
    for info in all.sorted(by: { $0.kp_proc.p_pid < $1.kp_proc.p_pid }) {
      let command = withUnsafeBytes(of: info.kp_proc.p_comm) {
        String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
      }
      rows.append([
        "\(info.kp_proc.p_pid)", "\(info.kp_eproc.e_ppid)",
        "\(info.kp_eproc.e_ucred.cr_uid)", command,
      ])
    }
    printTable(rows)
    print("\(all.count) processes")
  }
}

/// Formats how long ago a time was, in days, hours, and minutes.
private func since(_ time: timeval) -> String {
  let seconds = Int(Darwin.time(nil)) - Int(time.tv_sec)
  return "\(seconds / 86400)d \(seconds / 3600 % 24)h \(seconds / 60 % 60)m"
}

/// Formats load averages, which are fixed point.
private func loads(_ load: loadavg) -> String {
  withUnsafeBytes(of: load.ldavg) { buffer in
    buffer.bindMemory(to: fixpt_t.self).map {
      String(Double($0) / Double(load.fscale)).prefix(5)
    }.joined(separator: " ")
  }
}

#else

struct Sysctl: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sysctl",
    abstract: "Unavailable: this platform has no sysctl wrapper"
  )

  func run() throws {
    complain("Error: sysctl needs Darwin's sysctl")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
