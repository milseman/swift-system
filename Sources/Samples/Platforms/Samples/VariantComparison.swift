/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: one task under each ownership model, to compare their switches
// and escape hatches. The task: create a file, keep it from child processes,
// write a line, make it durable, and close it, reporting errors.
//
// - A, the design the other samples use: Unix unchanged (FileDescriptor and
//   OwnedFD), Windows as drafted (a noncopyable Win32.FileHandle). One
//   owned enum, Platform.File.
// - B, a copyable Windows handle (the drafts' rejected RawFileHandle): both
//   platforms then have a copyable name and an owner, so an unowned enum,
//   Platform.UnownedFile, is possible, with the hazards of any copyable
//   name.
// - C, an owned-first Unix side that mirrors the drafts: Unix.FileHandle
//   hosts its operations, as Win32.FileHandle does, so both arms call
//   operations on the payload directly.
// - D, no enum: NativeFile, a typealias to each platform's own owner, with
//   the common subset written once per platform.

import ArgumentParser
import SystemPackage

struct PlatformVariants: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "variants",
    abstract: "One task under each ownership model: A (drafts), B (copyable handle), C (owned-first Unix), D (typealias)"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "A directory for scratch files")
  var directory: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let directory = FilePath(directory)
    try variantA(directory.appending("variant-a.log"))
    try variantB(directory.appending("variant-b.log"))
    try variantC(directory.appending("variant-c.log"))
    try variantD(directory.appending("variant-d.log"))
  }
}

// MARK: - A: Unix unchanged, Windows as drafted

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func variantA(_ path: FilePath) throws {
  let file = try Platform.File.open(path, .write, .createOrTruncate)
  // The one platform-specific step. The Unix arm vends the owner's
  // FileDescriptor to reach an operation OwnedFD doesn't forward; the
  // Windows arm calls the handle's own.
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    try owner.fileDescriptor.setDescriptorFlags(.closeOnExec)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    try handle.setInheritable(false)
  #endif
  }
  try withSpan(of: "variant A\n") { try file.write($0) }
  try file.flush()
  print("A \(file.summary): owned enum over OwnedFD and the drafts' FileHandle")
  try file.close()
}

// MARK: - B: a copyable Windows handle

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func variantB(_ path: FilePath) throws {
  // B keeps the owned enum, and adds the unowned one: each owner vends a
  // copyable name, OwnedFD's FileDescriptor or the owner's RawFileHandle.
  let file = try Platform.File.open(path, .write, .createOrTruncate)
  let name = file.unowned
  // The platform-specific step, on the copyable names: both arms have the
  // same shape, a name and an operation on it.
  switch name {
  #if !os(Windows)
  case .fd(let descriptor):
    try descriptor.setDescriptorFlags(.closeOnExec)
  #endif
  #if SIMULATE_PLATFORMS
  case .handle(let handle):
    try handle.setInheritable(false)
  #endif
  }
  // The names can be stored, copied, and put in dictionaries, which owners
  // can't (V16h). They're valid only while `file` lives, and any copy can
  // close the file under the others: `name.close()` here would leave `file`
  // to close a stale descriptor or handle, whose number Windows or Unix
  // may have reused.
  let names: [String: Platform.UnownedFile] = ["log": name]
  try withSpan(of: "variant B\n") { try names["log"]!.write($0) }
  try names["log"]!.flush()
  print("B \(file.summary): owned enum, plus an unowned one over copyable names")
  try file.close()
}

// MARK: - C: an owned-first Unix side

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func variantC(_ path: FilePath) throws {
  let file = try Platform.OwnedFirstFile.open(path, creatingOrTruncating: true)
  // Both payloads host their operations, so neither arm vends anything.
  switch file {
  #if !os(Windows)
  case .fd(let owner):
    try owner.setDescriptorFlags(.closeOnExec)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let handle):
    try handle.setInheritable(false)
  #endif
  }
  try withSpan(of: "variant C\n") { try file.write($0) }
  try file.flush()
  print("C: owned enum over Unix.FileHandle and the drafts' FileHandle")
  try file.close()
}

// MARK: - D: a typealias, no enum

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func variantD(_ path: FilePath) throws {
  // `NativeFile` is OwnedFD on Unix and Win32.FileHandle on Windows. One
  // build has one platform, so this can't simulate: it's OwnedFD here.
  let file = try NativeFile.openForCommonUse(path, creatingOrTruncating: true)
  // The platform-specific step: `#if`, and no switch.
  #if os(Windows)
  try file.setInheritable(false)
  #else
  try file.fileDescriptor.setDescriptorFlags(.closeOnExec)
  #endif
  // The common subset, from members of the same names on each platform's
  // type. The write is OwnedFD's own; Win32.FileHandle's has the same
  // shape, by coincidence of the drafts, not by any check.
  #if os(Windows)
  try withSpan(of: "variant D\n") { try file.write($0) }
  #else
  try file.writeAll("variant D\n".utf8)
  #endif
  try file.flushDurably()
  print("D: no enum; NativeFile is \(NativeFile.self) in this build")
  try file.close()
}
