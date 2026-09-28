/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing
import Darwin

import SystemPackage
#if ENABLE_MOCKING
@testable import SystemSockets
#else
import SystemSockets
#endif

@Suite("VM sockets")
private struct SocketVMSocketTests {
  @available(System 199, *)
  @Test func theDomainAndConstants() {
    #expect(SocketDescriptor.Domain.vsock.rawValue == PF_VSOCK)
    #expect(SocketDescriptor.Domain.vsock.description == "vsock")
    #expect(VMSocketAddress.ContextID.any.rawValue == UInt32.max)
    #expect(VMSocketAddress.ContextID.hypervisor == 0)
    #expect(VMSocketAddress.ContextID.local == 1)
    #expect(VMSocketAddress.ContextID.host == 2)
    #expect(VMSocketAddress.Port.any.rawValue == UInt32.max)
  }

  @available(System 199, *)
  @Test func addressesRoundTrip() throws {
    let address = VMSocketAddress(contextID: .host, port: 1024)
    #expect(address.description == "2:1024")
    #expect(VMSocketAddress(contextID: .any, port: .any).description == "-1:-1")

    let socketAddress = SocketAddress(vsock: address)
    #expect(socketAddress.family == .vsock)
    #expect(socketAddress.length == MemoryLayout<sockaddr_vm>.size)
    #expect(socketAddress.vsock == address)
    #expect(socketAddress.ipv4 == nil)
    #expect(SocketAddress(ipv4: .loopback(port: 1)).vsock == nil)

    // The C structure's fields, as a client that imports Darwin reads them.
    let vm = socketAddress.withUnsafePointer { pointer, _ in
      UnsafeRawPointer(pointer).loadUnaligned(as: CInterop.SockAddrVM.self)
    }
    #expect(vm.svm_cid == 2 && vm.svm_port == 1024)
    #expect(Int(vm.svm_len) == MemoryLayout<sockaddr_vm>.size)
  }

  /// A Mac that isn't a virtual machine has no VM socket transport.
  @available(System 199, *)
  @Test func aSocketNeedsATransport() throws {
    do {
      let socket = try SocketDescriptor.open(.vsock, .stream, options: .closeOnExec)
      defer { try? socket.close() }
      // In a guest, the local context ID is the guest's, 3 or more.
      #expect(try socket.localContextID().rawValue >= 3)
    } catch {
      #expect(error == .operationNotSupportedByDevice)
    }
  }

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func theLocalContextIDCall() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let id = try SocketDescriptor(rawValue: 9).localContextID()
      // A mocked ioctl writes nothing.
      #expect(id == .any)
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "ioctl")
      #expect(entry?.arguments == [CInt(9), UInt(0x4004_73D1)])
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN
