/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C members of struct ifaddrs, which NetworkInterface.Addresses.Entry's
// unsafeNode vends; see Probe.swift.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ node: UnsafeMutablePointer<ifaddrs>) {
  _ = node.pointee.ifa_next
  _ = node.pointee.ifa_name
  _ = node.pointee.ifa_flags
  _ = node.pointee.ifa_addr?.pointee.sa_family
  _ = node.pointee.ifa_netmask
  _ = node.pointee.ifa_ifu.ifu_broadaddr
  _ = node.pointee.ifa_ifu.ifu_dstaddr
  _ = node.pointee.ifa_data
}
#endif
