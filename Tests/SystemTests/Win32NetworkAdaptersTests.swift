/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Network adapters. Every computer has the loopback adapter, with
// 127.0.0.1/8 and ::1/128; the others depend on the computer.
@available(System 199, *)
final class Win32NetworkAdaptersTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let types: [(Win32.NetworkAdapter.InterfaceType, UInt32)] = [
      (.other, UInt32(WinSDK.IF_TYPE_OTHER)),
      (.ethernet, UInt32(WinSDK.IF_TYPE_ETHERNET_CSMACD)),
      (.tokenRing, UInt32(WinSDK.IF_TYPE_ISO88025_TOKENRING)),
      (.pointToPoint, UInt32(WinSDK.IF_TYPE_PPP)),
      (.softwareLoopback, UInt32(WinSDK.IF_TYPE_SOFTWARE_LOOPBACK)),
      (.atm, UInt32(WinSDK.IF_TYPE_ATM)),
      (.wireless, UInt32(WinSDK.IF_TYPE_IEEE80211)),
      (.tunnel, UInt32(WinSDK.IF_TYPE_TUNNEL)),
      (.ieee1394, UInt32(WinSDK.IF_TYPE_IEEE1394)),
    ]
    for (type, value) in types {
      XCTAssertEqual(type.rawValue, value, "\(type)")
    }
    let statuses: [(Win32.NetworkAdapter.OperationalStatus, CInt)] = [
      (.up, CInt(IfOperStatusUp.rawValue)),
      (.down, CInt(IfOperStatusDown.rawValue)),
      (.testing, CInt(IfOperStatusTesting.rawValue)),
      (.unknown, CInt(IfOperStatusUnknown.rawValue)),
      (.dormant, CInt(IfOperStatusDormant.rawValue)),
      (.notPresent, CInt(IfOperStatusNotPresent.rawValue)),
      (.lowerLayerDown, CInt(IfOperStatusLowerLayerDown.rawValue)),
    ]
    for (status, value) in statuses {
      XCTAssertEqual(status.rawValue, value, "\(status)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_AF_UNSPEC, ULONG(WinSDK.AF_UNSPEC))
    XCTAssertEqual(
      _GAA_FLAGS_UNICAST_ONLY,
      ULONG(WinSDK.GAA_FLAG_SKIP_ANYCAST) | ULONG(WinSDK.GAA_FLAG_SKIP_MULTICAST)
        | ULONG(WinSDK.GAA_FLAG_SKIP_DNS_SERVER))
    XCTAssertEqual(_IP_ADAPTER_NO_MULTICAST, ULONG(WinSDK.IP_ADAPTER_NO_MULTICAST))
    XCTAssertEqual(_ERROR_BUFFER_OVERFLOW, ULONG(WinSDK.ERROR_BUFFER_OVERFLOW))
  }

  func testTheLoopbackAdapter() throws {
    let adapters = try Win32.networkAdapters()
    let loopback = try XCTUnwrap(adapters.first { $0.type == .softwareLoopback })
    XCTAssertEqual(loopback.operationalStatus, .up)
    XCTAssertTrue(loopback.name.hasPrefix("{"), loopback.name)
    XCTAssertFalse(loopback.friendlyName.isEmpty)
    XCTAssertEqual(loopback.physicalAddress, [])

    // 127.0.0.1/8: a sockaddr_in, of 16 bytes: its family, port 0, and the
    // address.
    let v4 = try XCTUnwrap(loopback.unicastAddresses.first { $0.family == CInt(WinSDK.AF_INET) })
    XCTAssertEqual(v4.bytes.count, 16)
    XCTAssertEqual(Array(v4.bytes[0..<8]), [UInt8(WinSDK.AF_INET), 0, 0, 0, 127, 0, 0, 1])
    XCTAssertEqual(v4.prefixLength, 8)
    XCTAssertNotEqual(loopback.index, 0)

    // ::1/128: a sockaddr_in6, of 28 bytes, its address after the port and
    // the flow label.
    if let v6 = loopback.unicastAddresses.first(where: { $0.family == CInt(WinSDK.AF_INET6) }) {
      XCTAssertEqual(v6.bytes.count, 28)
      XCTAssertEqual(Array(v6.bytes[8..<24]), [UInt8](repeating: 0, count: 15) + [1])
      XCTAssertEqual(v6.prefixLength, 128)
      XCTAssertNotEqual(loopback.ipv6Index, 0)
    }
  }

  func testAdapters() throws {
    let adapters = try Win32.networkAdapters()
    XCTAssertFalse(adapters.isEmpty)
    for adapter in adapters {
      for address in adapter.unicastAddresses {
        XCTAssertTrue(
          address.family == CInt(WinSDK.AF_INET) || address.family == CInt(WinSDK.AF_INET6),
          "\(adapter.friendlyName): \(address)")
        let maximum = address.family == CInt(WinSDK.AF_INET) ? 32 : 128
        XCTAssertTrue((0...maximum).contains(address.prefixLength), "\(address)")
      }
      if adapter.unicastAddresses.contains(where: { $0.family == CInt(WinSDK.AF_INET) }) {
        XCTAssertNotEqual(adapter.index, 0, adapter.friendlyName)
      }
    }
  }
}

#endif // os(Windows)
