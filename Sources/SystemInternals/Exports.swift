/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import CSystem

// TODO: Should CSystem just include all the header files we need?

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
#error("Unsupported Platform")
#endif

/// Namespace for C types used internally but not present in public API
public enum _CTypes {
  public typealias Off = off_t

  public typealias SpawnAttr = posix_spawnattr_t
}


#if os(Windows)
public typealias CModeT = CInt
#else
public typealias CModeT = mode_t
#endif

// MARK: syscalls and variables

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
public var system_errno: CInt {
  get { Darwin.errno }
  set { Darwin.errno = newValue }
}
#else
public var system_errno: CInt {
  get { Glibc.errno }
  set { Glibc.errno = newValue }
}
#endif

// MARK: C stdlib decls

public func system_strerror(_ __errnum: Int32) -> UnsafeMutablePointer<Int8>! {
  strerror(__errnum)
}

public func system_strlen(_ s: UnsafePointer<Int8>) -> Int {
  strlen(s)
}
