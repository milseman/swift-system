/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MemberImportVisibility canary for the record lock type; see Probe.swift.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ l: CInterop.FileLock) {
  _ = l.l_type
  _ = l.l_whence
  _ = l.l_start
  _ = l.l_len
  _ = l.l_pid
}
#endif
