/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A client of the C structures System vends that imports neither the C
// library nor CSystem, as a package that enables MemberImportVisibility and
// uses only System's API would be. Under MemberImportVisibility, a C
// structure's own fields and initializers need the module that declares
// them, so everything here must come from System's accessors
// (CInterop+Accessors.swift, CInterop+SocketAccessors.swift). A C field
// used here by mistake fails to compile, with "not available due to missing
// import of defining module".
//
// Unlike the other probes, this one checks Darwin too: the rule is the same
// there.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)

import SystemPackage

func _accessorProbe() {
  // timespec
  var time = CInterop.TimeSpec()
  time = CInterop.TimeSpec(seconds: 1, nanoseconds: 2)
  time.seconds += time.nanoseconds
  time.nanoseconds = 0
  if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
    time = CInterop.TimeSpec(duration: .milliseconds(1500))
    time.duration += .seconds(1)
  }

  // iovec
  var vector = CInterop.IOVec()
  vector = CInterop.IOVec(base: nil, length: 0)
  vector.base = nil
  vector.length += 1
  _ = CInterop.IOVec(UnsafeMutableRawBufferPointer(start: nil, count: 0))

  // stat
  var status = CInterop.Stat()
  status = CInterop.Stat(size: 1, preferredIOBlockSize: 4096)
  status.deviceID = status.specialDeviceID
  status.inode = Inode(rawValue: 2)
  status.mode = FileMode(rawValue: 0o100644)
  status.linkCount += 1
  status.userID = status.userID
  status.groupID = status.groupID
  status.size += 1
  status.preferredIOBlockSize += status.linkCount
  status.blocksAllocated += 1
  status.accessTime = time
  status.modificationTime = status.accessTime
  status.statusChangeTime = status.modificationTime
  #if canImport(Darwin)
  status.creationTime = time
  status.flags = status.flags
  status.generationNumber += 1

  // kevent
  var event = CInterop.KEvent()
  event = CInterop.KEvent(identifier: 1, eventFilter: .read, eventFlags: .add)
  event.identifier += 1
  event.eventFilter = .read
  event.eventFlags = [.add, .enable]
  event.filterFlags = []
  event.filterData += 1
  event.userData = nil
  #endif
  _ = (time, vector, status)
}

#if canImport(SystemSockets)
import SystemSockets

func _socketAccessorProbe() {
  // msghdr and cmsghdr
  var header = CInterop.MsgHdr()
  header = CInterop.MsgHdr(nameLength: 0, vectorCount: 0)
  header.name = nil
  header.nameLength += 1
  header.vectors = nil
  header.vectorCount += 1
  header.control = nil
  header.controlLength += 1
  header.flags = header.flags.union(.dataTruncated)

  var control = CInterop.CMsgHdr()
  control = CInterop.CMsgHdr(length: 16, level: .socket, type: .rights)
  control.length += 1
  control.level = .ip
  control.type = control.type

  // The socket addresses and host addresses
  var address = CInterop.SockAddr()
  address = CInterop.SockAddr(family: .ipv4)
  address.family = .ipv6

  var ipv4 = CInterop.SockAddrIn()
  ipv4 = CInterop.SockAddrIn(family: .ipv4, port: 80, address: CInterop.InAddr(integerValue: 0x7F00_0001))
  ipv4.family = .ipv4
  ipv4.port += 1
  ipv4.address.integerValue = 0

  var ipv6 = CInterop.SockAddrIn6()
  ipv6 = CInterop.SockAddrIn6(family: .ipv6, port: 443, address: CInterop.In6Addr())
  ipv6.family = .ipv6
  ipv6.port += 1
  ipv6.flowInfo = 0
  ipv6.scopeID = 1
  ipv6.address.bytes.15 = 1
  var host6 = CInterop.In6Addr(bytes: ipv6.address.bytes)
  host6.bytes.0 = 0xfe

  var local = CInterop.SockAddrUn()
  local = CInterop.SockAddrUn(family: .local, path: "/tmp/probe.sock")
  local.family = .local
  local.path = FilePath(local.path.string + ".1")
  _ = CInterop.SockAddrUn.pathCapacity

  var storage = CInterop.SockAddrStorage()
  storage = CInterop.SockAddrStorage(family: .ipv4)
  storage.family = .unspecified

  var host4 = CInterop.InAddr()
  host4.integerValue = 1

  #if canImport(Darwin)
  address.length = 16
  ipv4.length = 16
  ipv6.length = 28
  local.length = 106
  storage.length = 128

  var vm = CInterop.SockAddrVM()
  vm = CInterop.SockAddrVM(family: .vsock, port: 1024, contextID: 2)
  vm.length = 12
  vm.family = .vsock
  vm.port += 1
  vm.contextID = 3
  _ = vm
  #endif
  _ = (header, control, address, ipv4, ipv6, host6, local, storage, host4)
}
#endif // canImport(SystemSockets)

#endif
