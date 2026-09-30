/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library's compile-time limit on atomic pipe writes, next to its
// limits on names and paths (CompileTimeLimits.swift): for sizing a write
// before there's a pipe to ask. `SystemConfig.value(.maxAtomicPipeWriteBytes,
// for: pipe)` is that pipe's, `SystemConfig.maxAtomicPipeWriteBytes` the
// headers'.

#if !os(Windows) && !os(WASI)

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

@_alwaysEmitIntoClient
internal var _PIPE_BUF: CInt { CInt(PIPE_BUF) }

@available(System 199, *)
extension SystemConfig {
  /// The maximum number of bytes that a write to a pipe or FIFO
  /// writes all at once, without interleaving the data of other writes,
  /// as the C library's headers define it.
  ///
  /// A longer write can be split,
  /// and other writers' data can come between its parts.
  /// The `value(_:for:)` methods with ``PathName/maxAtomicPipeWriteBytes``
  /// return a pipe's or FIFO's own limit.
  ///
  /// It's 512 on Darwin and 4096 on Linux,
  /// and POSIX requires at least 512.
  ///
  /// The corresponding C constant is `PIPE_BUF`.
  @_alwaysEmitIntoClient
  public static var maxAtomicPipeWriteBytes: Int { Int(_PIPE_BUF) }
}

#endif // !os(Windows) && !os(WASI)
