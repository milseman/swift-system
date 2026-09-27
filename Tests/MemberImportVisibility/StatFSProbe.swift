/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MemberImportVisibility canary for the statvfs type that StatFS wraps on
// these platforms; see Probe.swift. CInterop.FileSystemID and MountFlags
// are integers here, with no members.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ s: CInterop.StatFS) {
  _ = s.f_bsize
  _ = s.f_frsize
  _ = s.f_blocks
  _ = s.f_bfree
  _ = s.f_bavail
  _ = s.f_files
  _ = s.f_ffree
  _ = s.f_favail
  _ = s.f_fsid
  _ = s.f_flag
  _ = s.f_namemax
}
#endif
