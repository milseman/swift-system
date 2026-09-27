/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C members of the vectored I/O types; see Probe.swift.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ v: CInterop.IOVec) -> CInterop.IOVec {
  _ = v.iov_base
  _ = v.iov_len
  return CInterop.IOVec(iov_base: v.iov_base, iov_len: v.iov_len)
}
#endif
