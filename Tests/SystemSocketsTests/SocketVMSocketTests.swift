/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

import Testing
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

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
    #expect(SocketDescriptor.Domain.vsock.rawValue == AF_VSOCK)
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
    #expect(socketAddress.length == MemoryLayout<CInterop.SockAddrVM>.size)
    #expect(socketAddress.vsock == address)
    #expect(socketAddress.ipv4 == nil)
    #expect(SocketAddress(ipv4: .loopback(port: 1)).vsock == nil)

    // The C structure's fields, as a client that imports the C library
    // reads them.
    let vm = socketAddress.withUnsafePointer { pointer, _ in
      UnsafeRawPointer(pointer).loadUnaligned(as: CInterop.SockAddrVM.self)
    }
    #expect(vm.svm_cid == 2 && vm.svm_port == 1024)
    #expect(vm.svm_family == sa_family_t(AF_VSOCK))
    #if SYSTEM_PACKAGE_DARWIN
    #expect(Int(vm.svm_len) == MemoryLayout<sockaddr_vm>.size)
    #else
    #expect(MemoryLayout<CInterop.SockAddrVM>.size == 16)
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
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
  #else
  /// A socket needs the kernel's VM sockets, which a container may not
  /// load, or a seccomp filter (such as Docker's default) may refuse.
  @available(System 199, *)
  @Test func aSocketNeedsVMSockets() throws {
    do {
      let socket = try SocketDescriptor.open(.vsock, .stream, options: .closeOnExec)
      try socket.close()
    } catch {
      // close() throws untyped errors.
      let errno = error as? Errno
      #expect(errno == .addressFamilyNotSupported || errno == .notPermitted)
    }
  }

  /// The VM sockets device reports this machine's context ID: a guest's,
  /// the host's, or with no transport, any. Without the device, as in most
  /// containers, there's nothing to ask.
  @available(System 199, *)
  @Test func theDeviceHasTheLocalContextID() throws {
    let device: FileDescriptor
    do {
      device = try FileDescriptor.open("/dev/vsock", .readOnly, options: .closeOnExec)
    } catch {
      return
    }
    defer { try? device.close() }
    let id = try device.localContextID()
    #expect(id == .any || id == .host || id.rawValue >= 3)
  }

  /// Only the device answers the call.
  @available(System 199, *)
  @Test func anotherDescriptorIsNotTheDevice() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    #expect(throws: Errno.inappropriateIOCTLForDevice) {
      try pipe.readEnd.localContextID()
    }
  }
  #endif

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func theLocalContextIDCall() throws {
    try MockingDriver.withMockingEnabled { mocking in
      #if SYSTEM_PACKAGE_DARWIN
      let id = try SocketDescriptor(rawValue: 9).localContextID()
      #else
      let id = try FileDescriptor(rawValue: 9).localContextID()
      #endif
      // A mocked ioctl writes nothing.
      #expect(id == .any)
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "ioctl")
      #if SYSTEM_PACKAGE_DARWIN
      #expect(entry?.arguments == [CInt(9), UInt(0x4004_73D1)])
      #elseif arch(x86_64) || arch(arm64)
      // _IO(7, 0xb9), from the header, through shims.c.
      #expect(entry?.arguments == [CInt(9), UInt(0x7B9)])
      #endif
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
