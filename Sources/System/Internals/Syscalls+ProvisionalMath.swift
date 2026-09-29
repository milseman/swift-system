/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C math library's elementary functions, which System wraps
// provisionally (Provisional+Math.swift). They can't fail, so they have no
// mock hooks.

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
#else
#error("Unsupported Platform")
#endif

internal func system_sin(_ x: Double) -> Double { sin(x) }
internal func system_sinf(_ x: Float) -> Float { sinf(x) }
internal func system_cos(_ x: Double) -> Double { cos(x) }
internal func system_cosf(_ x: Float) -> Float { cosf(x) }
internal func system_tan(_ x: Double) -> Double { tan(x) }
internal func system_tanf(_ x: Float) -> Float { tanf(x) }
internal func system_asin(_ x: Double) -> Double { asin(x) }
internal func system_asinf(_ x: Float) -> Float { asinf(x) }
internal func system_acos(_ x: Double) -> Double { acos(x) }
internal func system_acosf(_ x: Float) -> Float { acosf(x) }
internal func system_atan(_ x: Double) -> Double { atan(x) }
internal func system_atanf(_ x: Float) -> Float { atanf(x) }
internal func system_atan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) }
internal func system_atan2f(_ y: Float, _ x: Float) -> Float { atan2f(y, x) }
internal func system_sinh(_ x: Double) -> Double { sinh(x) }
internal func system_sinhf(_ x: Float) -> Float { sinhf(x) }
internal func system_cosh(_ x: Double) -> Double { cosh(x) }
internal func system_coshf(_ x: Float) -> Float { coshf(x) }
internal func system_tanh(_ x: Double) -> Double { tanh(x) }
internal func system_tanhf(_ x: Float) -> Float { tanhf(x) }
internal func system_asinh(_ x: Double) -> Double { asinh(x) }
internal func system_asinhf(_ x: Float) -> Float { asinhf(x) }
internal func system_acosh(_ x: Double) -> Double { acosh(x) }
internal func system_acoshf(_ x: Float) -> Float { acoshf(x) }
internal func system_atanh(_ x: Double) -> Double { atanh(x) }
internal func system_atanhf(_ x: Float) -> Float { atanhf(x) }
internal func system_exp(_ x: Double) -> Double { exp(x) }
internal func system_expf(_ x: Float) -> Float { expf(x) }
internal func system_exp2(_ x: Double) -> Double { exp2(x) }
internal func system_exp2f(_ x: Float) -> Float { exp2f(x) }
internal func system_expm1(_ x: Double) -> Double { expm1(x) }
internal func system_expm1f(_ x: Float) -> Float { expm1f(x) }
internal func system_log(_ x: Double) -> Double { log(x) }
internal func system_logf(_ x: Float) -> Float { logf(x) }
internal func system_log2(_ x: Double) -> Double { log2(x) }
internal func system_log2f(_ x: Float) -> Float { log2f(x) }
internal func system_log10(_ x: Double) -> Double { log10(x) }
internal func system_log10f(_ x: Float) -> Float { log10f(x) }
internal func system_log1p(_ x: Double) -> Double { log1p(x) }
internal func system_log1pf(_ x: Float) -> Float { log1pf(x) }
internal func system_pow(_ x: Double, _ y: Double) -> Double { pow(x, y) }
internal func system_powf(_ x: Float, _ y: Float) -> Float { powf(x, y) }
internal func system_cbrt(_ x: Double) -> Double { cbrt(x) }
internal func system_cbrtf(_ x: Float) -> Float { cbrtf(x) }
internal func system_hypot(_ x: Double, _ y: Double) -> Double { hypot(x, y) }
internal func system_hypotf(_ x: Float, _ y: Float) -> Float { hypotf(x, y) }
internal func system_erf(_ x: Double) -> Double { erf(x) }
internal func system_erff(_ x: Float) -> Float { erff(x) }
internal func system_erfc(_ x: Double) -> Double { erfc(x) }
internal func system_erfcf(_ x: Float) -> Float { erfcf(x) }
internal func system_tgamma(_ x: Double) -> Double { tgamma(x) }
internal func system_tgammaf(_ x: Float) -> Float { tgammaf(x) }
internal func system_lgamma(_ x: Double) -> Double { lgamma(x) }
internal func system_lgammaf(_ x: Float) -> Float { lgammaf(x) }
