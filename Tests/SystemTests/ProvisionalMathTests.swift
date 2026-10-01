/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#elseif os(Windows)
import ucrt
#endif

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

// The provisional math functions (Provisional+Math.swift).
@Suite("Math")
private struct ProvisionalMathTests {
  @available(System 199, *)
  @Test func knownValues() {
    #expect(Math.sin(0.0) == 0 && Math.cos(0.0) == 1 && Math.tan(0.0) == 0)
    #expect(abs(Math.sin(Double.pi / 2) - 1) < 1e-15)
    #expect(abs(Math.atan2(1.0, -1.0) - 3 * Double.pi / 4) < 1e-15)
    #expect(Math.pow(2.0, 10.0) == 1024 && Math.pow(Float(2), 10) == 1024)
    #expect(Math.exp2(10.0) == 1024 && Math.log2(1024.0) == 10 && Math.log10(1000.0) == 3)
    // glibc's cbrt isn't correctly rounded.
    #expect(Math.hypot(3.0, 4.0) == 5 && abs(Math.cbrt(-27.0) + 3) < 1e-15)
    #expect(Math.expm1(0.0) == 0 && Math.log1p(0.0) == 0 && Math.exp(0.0) == 1 && Math.log(1.0) == 0)
    #expect(Math.acosh(1.0) == 0 && Math.asinh(0.0) == 0 && Math.atanh(0.0) == 0)
    #expect(Math.sinh(0.0) == 0 && Math.cosh(0.0) == 1 && Math.tanh(0.0) == 0)
    #expect(Math.erf(0.0) == 0 && Math.erfc(0.0) == 1)
    #expect(Math.tgamma(5.0) == 24 && abs(Math.lgamma(5.0) - Math.log(24.0)) < 1e-14)
    #expect(Math.asin(1.0) == Double.pi / 2 && Math.acos(1.0) == 0 && Math.atan(0.0) == 0)
  }

  @available(System 199, *)
  @Test func outsideTheDomain() {
    #expect(Math.asin(2.0).isNaN && Math.acos(-2.0).isNaN && Math.acosh(0.0).isNaN)
    #expect(Math.log(-1.0).isNaN && Math.log(0.0) == -.infinity)
    #expect(Math.pow(-8.0, 1.0 / 3).isNaN && Math.cbrt(-8.0) == -2)
    #expect(Math.atanh(1.0) == .infinity)
  }

  /// Each function is the C function, for Double and Float.
  @available(System 199, *)
  @Test func theCFunctions() {
    for x in stride(from: -2.5, through: 2.5, by: 0.37) {
      let f = Float(x)
      #expect(Math.sin(x) == sin(x) && Math.sin(f) == sinf(f))
      #expect(Math.cos(x) == cos(x) && Math.cos(f) == cosf(f))
      #expect(Math.exp(x) == exp(x) && Math.exp(f) == expf(f))
      #expect(Math.pow(x, 3) == pow(x, 3) && Math.pow(f, 3) == powf(f, 3))
      #expect(Math.atan2(x, 0.5) == atan2(x, 0.5) && Math.erf(f) == erff(f))
    }
  }
}
