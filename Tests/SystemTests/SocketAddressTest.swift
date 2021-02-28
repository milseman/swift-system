/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class SocketAddressTest: XCTestCase {
  func test_addressWithArbitraryData() {
    for length in MemoryLayout<CInterop.SockAddr>.size ... 255 {
      let range = 0 ..< UInt8(truncatingIfNeeded: length)
      let data = Array<UInt8>(range)
      data.withUnsafeBytes { source in
        let address = SocketAddress(source)
        address.withUnsafeBytes { copy in
          XCTAssertEqual(copy.count, length)
          XCTAssertTrue(range.elementsEqual(copy), "\(length)")
        }
      }
    }
  }

  func test_addressWithSockAddr() {
    for length in MemoryLayout<CInterop.SockAddr>.size ... 255 {
      let range = 0 ..< UInt8(truncatingIfNeeded: length)
      let data = Array<UInt8>(range)
      data.withUnsafeBytes { source in
        let p = source.baseAddress!.assumingMemoryBound(to: CInterop.SockAddr.self)
        let address = SocketAddress(
          address: p,
          length: CInterop.SockLen(source.count))
        address.withUnsafeBytes { copy in
          XCTAssertEqual(copy.count, length)
          XCTAssertTrue(range.elementsEqual(copy), "\(length)")
        }
      }
    }
  }

  // MARK: IPv4

  func test_addressWithIPv4Address() {
    let ipv4 = SocketAddress.IPv4(address: "1.2.3.4", port: 42)!
    let address = SocketAddress(ipv4)
    if case .large = address._variant {
      XCTFail("IPv4 address in big representation")
    }
    XCTAssertEqual(address.family, .ipv4)
    if let extracted = SocketAddress.IPv4(address) {
      XCTAssertEqual(extracted, ipv4)
    } else {
      XCTFail("Cannot extract IPv4 address")
    }
  }

  func test_ipv4_address_string_conversions() {
    typealias Address = SocketAddress.IPv4.Address

    func check(
      _ string: String,
      _ value: UInt32?,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      switch (Address(string), value) {
      case let (address?, value?):
        XCTAssertEqual(address.rawValue, value, file: file, line: line)
      case let (address?, nil):
        let s = String(address.rawValue, radix: 16)
        XCTFail("Got \(s), expected nil", file: file, line: line)
      case let (nil, value?):
        let s = String(value, radix: 16)
        XCTFail("Got nil, expected \(s), file: file, line: line")
      case (nil, nil):
        // OK
        break
      }

      if let value = value {
        let address = Address(rawValue: value)
        let actual = "\(address)"
        XCTAssertEqual(
          actual, string,
          "Mismatching description. Expected: \(string), actual: \(actual)",
          file: file, line: line)
      }
    }
    check("0.0.0.0", 0)
    check("0.0.0.1", 1)
    check("1.2.3.4", 0x01020304)
    check("255.255.255.255", 0xFFFFFFFF)
    check("apple.com", nil)
    check("256.0.0.0", nil)
  }

  func test_ipv4_description() {
    let a1 = SocketAddress.IPv4(address: "1.2.3.4", port: 42)!
    XCTAssertEqual("\(a1)", "1.2.3.4:42")

    let a2 = SocketAddress.IPv4(address: "192.168.1.1", port: 80)!
    XCTAssertEqual("\(a2)", "192.168.1.1:80")
  }
}
