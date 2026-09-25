/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the multi-platform enums (Next/Vision.md, direction 4). Not API.
//
// There's one enum per kind of kernel object: file, directory, socket, and
// process. Each enum has a case for each representation a platform has for
// that kind, and each case wraps the platform's own owned type. So the enums
// are a layer for cross-platform code only. Single-platform code uses
// OwnedFD, Win32.FileHandle, and the rest directly, and never sees them.
//
// Each enum hosts the kind's common subset of operations. Anything else
// needs a `switch`, with each platform's arm under that platform's `#if`,
// since a case exists only on its platform (V16e). A client of System built
// with library evolution must also end each switch with `@unknown default`
// (V16a).
//
// Cases are declared under `#if`, so each platform sees only its own. The
// rejected alternative declares every platform's case everywhere, with
// uninhabited payloads off-platform (V16d). Switches could then omit foreign
// cases, but an arm that uses a foreign payload still needs `#if`, and each
// foreign type would need declaring on every platform.

import SystemPackage

/// A namespace for the multi-platform enums.
enum Platform {}

extension Platform {
  /// The error type that every enum's common subset throws: the platform's
  /// own, Errno on Unix and Win32.Error on Windows.
  ///
  /// In a real build, every representation on a platform reports errors the
  /// same way, so a switch arm that calls the platform's API throws the same
  /// type as the enum, with no conversion (and no loss, unlike
  /// `Errno(approximating:)`). A typed `catch Platform.Error.fileExists`
  /// compiles on both, and means each platform's own code.
  ///
  /// The simulated build has every platform's cases at once, so it has no
  /// single error type, and uses `any Error`.
  #if SIMULATE_PLATFORMS
  typealias Error = any Swift.Error
  #elseif os(Windows)
  typealias Error = Win32.Error
  #else
  typealias Error = Errno
  #endif

  /// Calls API that still throws untyped errors, such as FileDescriptor's
  /// `resize(to:)` and SocketDescriptor's operations, from typed code. On
  /// each platform the error is always that platform's.
  static func typed<R: ~Copyable>(_ body: () throws -> R) throws(Platform.Error) -> R {
    #if SIMULATE_PLATFORMS
    return try body()
    #else
    do {
      return try body()
    } catch let error as Platform.Error {
      throw error
    } catch {
      fatalError("Expected \(Platform.Error.self), got \(error)")
    }
    #endif
  }
}
