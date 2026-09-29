/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C math library's elementary functions.
//
// System wraps libm provisionally. Math functions are the C library's, not
// operating-system interfaces, and the standard library is where Swift code
// would look for them; swift-numerics has them as generic functions. Until
// the standard library has them, a package that needs a sine or a power can
// call these without importing the C library, as Foundation's calendar
// astronomy does. They are free functions of C, so they're static members
// of a namespace, `Math`, rather than members of Double and Float, which
// swift-numerics' RealModule extends with the same names.

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

/// A namespace for the C math library's elementary functions:
/// trigonometric, hyperbolic, exponential, logarithmic, power,
/// and error and gamma functions, for `Double` and `Float`.
///
///     let height = radius * Math.sin(angle)
///
/// The standard library already has what the rest of the math library does,
/// as members of the floating-point types:
/// `squareRoot()` for `sqrt`, `rounded(_:)` for `floor`, `ceil`,
/// `round`, and `trunc`, `truncatingRemainder(dividingBy:)` for `fmod`,
/// `remainder(dividingBy:)`, `magnitude` for `fabs`,
/// `minimum(_:_:)` and `maximum(_:_:)`, `addingProduct(_:_:)` for `fma`,
/// and `sign`, `exponent`, and `significand`.
///
/// These functions return NaN for a value outside their domain,
/// as C's do, rather than trap; C also sets `errno`, which they don't read.
///
/// - Note: Provisional: math functions may move to the Swift standard library.
@available(System 199, *)
public enum Math {}

@available(System 199, *)
extension Math {
  /// Returns the sine of an angle, in radians.
  ///
  /// The corresponding C function is `sin`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func sin(_ x: Double) -> Double { _sin(x) }

  @usableFromInline
  internal static func _sin(_ x: Double) -> Double { system_sin(x) }

  /// Returns the sine of an angle, in radians.
  ///
  /// The corresponding C function is `sinf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func sin(_ x: Float) -> Float { _sin(x) }

  @usableFromInline
  internal static func _sin(_ x: Float) -> Float { system_sinf(x) }

  /// Returns the cosine of an angle, in radians.
  ///
  /// The corresponding C function is `cos`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cos(_ x: Double) -> Double { _cos(x) }

  @usableFromInline
  internal static func _cos(_ x: Double) -> Double { system_cos(x) }

  /// Returns the cosine of an angle, in radians.
  ///
  /// The corresponding C function is `cosf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cos(_ x: Float) -> Float { _cos(x) }

  @usableFromInline
  internal static func _cos(_ x: Float) -> Float { system_cosf(x) }

  /// Returns the tangent of an angle, in radians.
  ///
  /// The corresponding C function is `tan`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tan(_ x: Double) -> Double { _tan(x) }

  @usableFromInline
  internal static func _tan(_ x: Double) -> Double { system_tan(x) }

  /// Returns the tangent of an angle, in radians.
  ///
  /// The corresponding C function is `tanf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tan(_ x: Float) -> Float { _tan(x) }

  @usableFromInline
  internal static func _tan(_ x: Float) -> Float { system_tanf(x) }

  /// Returns the arcsine of a value, in radians, from -π/2 through π/2.
  ///
  /// A value outside -1 through 1 returns NaN.
  ///
  /// The corresponding C function is `asin`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func asin(_ x: Double) -> Double { _asin(x) }

  @usableFromInline
  internal static func _asin(_ x: Double) -> Double { system_asin(x) }

  /// Returns the arcsine of a value, in radians, from -π/2 through π/2.
  ///
  /// A value outside -1 through 1 returns NaN.
  ///
  /// The corresponding C function is `asinf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func asin(_ x: Float) -> Float { _asin(x) }

  @usableFromInline
  internal static func _asin(_ x: Float) -> Float { system_asinf(x) }

  /// Returns the arccosine of a value, in radians, from 0 through π.
  ///
  /// A value outside -1 through 1 returns NaN.
  ///
  /// The corresponding C function is `acos`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func acos(_ x: Double) -> Double { _acos(x) }

  @usableFromInline
  internal static func _acos(_ x: Double) -> Double { system_acos(x) }

  /// Returns the arccosine of a value, in radians, from 0 through π.
  ///
  /// A value outside -1 through 1 returns NaN.
  ///
  /// The corresponding C function is `acosf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func acos(_ x: Float) -> Float { _acos(x) }

  @usableFromInline
  internal static func _acos(_ x: Float) -> Float { system_acosf(x) }

  /// Returns the arctangent of a value, in radians, from -π/2 through π/2.
  ///
  /// The corresponding C function is `atan`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atan(_ x: Double) -> Double { _atan(x) }

  @usableFromInline
  internal static func _atan(_ x: Double) -> Double { system_atan(x) }

  /// Returns the arctangent of a value, in radians, from -π/2 through π/2.
  ///
  /// The corresponding C function is `atanf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atan(_ x: Float) -> Float { _atan(x) }

  @usableFromInline
  internal static func _atan(_ x: Float) -> Float { system_atanf(x) }

  /// Returns the angle of the point (x, y) from the positive x-axis, in radians, from -π through π.
  ///
  /// Unlike `atan(y / x)`, it tells the quadrants apart.
  ///
  /// The corresponding C function is `atan2`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atan2(_ y: Double, _ x: Double) -> Double { _atan2(y, x) }

  @usableFromInline
  internal static func _atan2(_ y: Double, _ x: Double) -> Double { system_atan2(y, x) }

  /// Returns the angle of the point (x, y) from the positive x-axis, in radians, from -π through π.
  ///
  /// Unlike `atan(y / x)`, it tells the quadrants apart.
  ///
  /// The corresponding C function is `atan2f`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atan2(_ y: Float, _ x: Float) -> Float { _atan2(y, x) }

  @usableFromInline
  internal static func _atan2(_ y: Float, _ x: Float) -> Float { system_atan2f(y, x) }

  /// Returns the hyperbolic sine of a value.
  ///
  /// The corresponding C function is `sinh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func sinh(_ x: Double) -> Double { _sinh(x) }

  @usableFromInline
  internal static func _sinh(_ x: Double) -> Double { system_sinh(x) }

  /// Returns the hyperbolic sine of a value.
  ///
  /// The corresponding C function is `sinhf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func sinh(_ x: Float) -> Float { _sinh(x) }

  @usableFromInline
  internal static func _sinh(_ x: Float) -> Float { system_sinhf(x) }

  /// Returns the hyperbolic cosine of a value.
  ///
  /// The corresponding C function is `cosh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cosh(_ x: Double) -> Double { _cosh(x) }

  @usableFromInline
  internal static func _cosh(_ x: Double) -> Double { system_cosh(x) }

  /// Returns the hyperbolic cosine of a value.
  ///
  /// The corresponding C function is `coshf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cosh(_ x: Float) -> Float { _cosh(x) }

  @usableFromInline
  internal static func _cosh(_ x: Float) -> Float { system_coshf(x) }

  /// Returns the hyperbolic tangent of a value.
  ///
  /// The corresponding C function is `tanh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tanh(_ x: Double) -> Double { _tanh(x) }

  @usableFromInline
  internal static func _tanh(_ x: Double) -> Double { system_tanh(x) }

  /// Returns the hyperbolic tangent of a value.
  ///
  /// The corresponding C function is `tanhf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tanh(_ x: Float) -> Float { _tanh(x) }

  @usableFromInline
  internal static func _tanh(_ x: Float) -> Float { system_tanhf(x) }

  /// Returns the inverse hyperbolic sine of a value.
  ///
  /// The corresponding C function is `asinh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func asinh(_ x: Double) -> Double { _asinh(x) }

  @usableFromInline
  internal static func _asinh(_ x: Double) -> Double { system_asinh(x) }

  /// Returns the inverse hyperbolic sine of a value.
  ///
  /// The corresponding C function is `asinhf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func asinh(_ x: Float) -> Float { _asinh(x) }

  @usableFromInline
  internal static func _asinh(_ x: Float) -> Float { system_asinhf(x) }

  /// Returns the inverse hyperbolic cosine of a value.
  ///
  /// A value below 1 returns NaN.
  ///
  /// The corresponding C function is `acosh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func acosh(_ x: Double) -> Double { _acosh(x) }

  @usableFromInline
  internal static func _acosh(_ x: Double) -> Double { system_acosh(x) }

  /// Returns the inverse hyperbolic cosine of a value.
  ///
  /// A value below 1 returns NaN.
  ///
  /// The corresponding C function is `acoshf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func acosh(_ x: Float) -> Float { _acosh(x) }

  @usableFromInline
  internal static func _acosh(_ x: Float) -> Float { system_acoshf(x) }

  /// Returns the inverse hyperbolic tangent of a value.
  ///
  /// A value outside -1 through 1 returns NaN, and ±1 returns ±infinity.
  ///
  /// The corresponding C function is `atanh`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atanh(_ x: Double) -> Double { _atanh(x) }

  @usableFromInline
  internal static func _atanh(_ x: Double) -> Double { system_atanh(x) }

  /// Returns the inverse hyperbolic tangent of a value.
  ///
  /// A value outside -1 through 1 returns NaN, and ±1 returns ±infinity.
  ///
  /// The corresponding C function is `atanhf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func atanh(_ x: Float) -> Float { _atanh(x) }

  @usableFromInline
  internal static func _atanh(_ x: Float) -> Float { system_atanhf(x) }

  /// Returns e raised to a power.
  ///
  /// The corresponding C function is `exp`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func exp(_ x: Double) -> Double { _exp(x) }

  @usableFromInline
  internal static func _exp(_ x: Double) -> Double { system_exp(x) }

  /// Returns e raised to a power.
  ///
  /// The corresponding C function is `expf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func exp(_ x: Float) -> Float { _exp(x) }

  @usableFromInline
  internal static func _exp(_ x: Float) -> Float { system_expf(x) }

  /// Returns 2 raised to a power.
  ///
  /// The corresponding C function is `exp2`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func exp2(_ x: Double) -> Double { _exp2(x) }

  @usableFromInline
  internal static func _exp2(_ x: Double) -> Double { system_exp2(x) }

  /// Returns 2 raised to a power.
  ///
  /// The corresponding C function is `exp2f`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func exp2(_ x: Float) -> Float { _exp2(x) }

  @usableFromInline
  internal static func _exp2(_ x: Float) -> Float { system_exp2f(x) }

  /// Returns e raised to a power, minus 1.
  ///
  /// It's accurate for a power near zero, where `exp(x) - 1` isn't.
  ///
  /// The corresponding C function is `expm1`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func expm1(_ x: Double) -> Double { _expm1(x) }

  @usableFromInline
  internal static func _expm1(_ x: Double) -> Double { system_expm1(x) }

  /// Returns e raised to a power, minus 1.
  ///
  /// It's accurate for a power near zero, where `exp(x) - 1` isn't.
  ///
  /// The corresponding C function is `expm1f`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func expm1(_ x: Float) -> Float { _expm1(x) }

  @usableFromInline
  internal static func _expm1(_ x: Float) -> Float { system_expm1f(x) }

  /// Returns the natural logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `log`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log(_ x: Double) -> Double { _log(x) }

  @usableFromInline
  internal static func _log(_ x: Double) -> Double { system_log(x) }

  /// Returns the natural logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `logf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log(_ x: Float) -> Float { _log(x) }

  @usableFromInline
  internal static func _log(_ x: Float) -> Float { system_logf(x) }

  /// Returns the base-2 logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `log2`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log2(_ x: Double) -> Double { _log2(x) }

  @usableFromInline
  internal static func _log2(_ x: Double) -> Double { system_log2(x) }

  /// Returns the base-2 logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `log2f`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log2(_ x: Float) -> Float { _log2(x) }

  @usableFromInline
  internal static func _log2(_ x: Float) -> Float { system_log2f(x) }

  /// Returns the base-10 logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `log10`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log10(_ x: Double) -> Double { _log10(x) }

  @usableFromInline
  internal static func _log10(_ x: Double) -> Double { system_log10(x) }

  /// Returns the base-10 logarithm of a value.
  ///
  /// A negative value returns NaN, and zero returns -infinity.
  ///
  /// The corresponding C function is `log10f`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log10(_ x: Float) -> Float { _log10(x) }

  @usableFromInline
  internal static func _log10(_ x: Float) -> Float { system_log10f(x) }

  /// Returns the natural logarithm of 1 plus a value.
  ///
  /// It's accurate for a value near zero, where `log(1 + x)` isn't.
  ///
  /// The corresponding C function is `log1p`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log1p(_ x: Double) -> Double { _log1p(x) }

  @usableFromInline
  internal static func _log1p(_ x: Double) -> Double { system_log1p(x) }

  /// Returns the natural logarithm of 1 plus a value.
  ///
  /// It's accurate for a value near zero, where `log(1 + x)` isn't.
  ///
  /// The corresponding C function is `log1pf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func log1p(_ x: Float) -> Float { _log1p(x) }

  @usableFromInline
  internal static func _log1p(_ x: Float) -> Float { system_log1pf(x) }

  /// Returns a value raised to a power.
  ///
  /// A negative value raised to a power that isn't an integer returns NaN.
  ///
  /// The corresponding C function is `pow`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func pow(_ x: Double, _ y: Double) -> Double { _pow(x, y) }

  @usableFromInline
  internal static func _pow(_ x: Double, _ y: Double) -> Double { system_pow(x, y) }

  /// Returns a value raised to a power.
  ///
  /// A negative value raised to a power that isn't an integer returns NaN.
  ///
  /// The corresponding C function is `powf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func pow(_ x: Float, _ y: Float) -> Float { _pow(x, y) }

  @usableFromInline
  internal static func _pow(_ x: Float, _ y: Float) -> Float { system_powf(x, y) }

  /// Returns the cube root of a value.
  ///
  /// Unlike `pow(x, 1.0 / 3)`, it's defined for a negative value.
  ///
  /// The corresponding C function is `cbrt`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cbrt(_ x: Double) -> Double { _cbrt(x) }

  @usableFromInline
  internal static func _cbrt(_ x: Double) -> Double { system_cbrt(x) }

  /// Returns the cube root of a value.
  ///
  /// Unlike `pow(x, 1.0 / 3)`, it's defined for a negative value.
  ///
  /// The corresponding C function is `cbrtf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func cbrt(_ x: Float) -> Float { _cbrt(x) }

  @usableFromInline
  internal static func _cbrt(_ x: Float) -> Float { system_cbrtf(x) }

  /// Returns the length of the hypotenuse of a right triangle with sides x and y, √(x² + y²).
  ///
  /// It doesn't overflow or underflow where squaring the sides would.
  ///
  /// The corresponding C function is `hypot`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func hypot(_ x: Double, _ y: Double) -> Double { _hypot(x, y) }

  @usableFromInline
  internal static func _hypot(_ x: Double, _ y: Double) -> Double { system_hypot(x, y) }

  /// Returns the length of the hypotenuse of a right triangle with sides x and y, √(x² + y²).
  ///
  /// It doesn't overflow or underflow where squaring the sides would.
  ///
  /// The corresponding C function is `hypotf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func hypot(_ x: Float, _ y: Float) -> Float { _hypot(x, y) }

  @usableFromInline
  internal static func _hypot(_ x: Float, _ y: Float) -> Float { system_hypotf(x, y) }

  /// Returns the error function of a value.
  ///
  /// The corresponding C function is `erf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func erf(_ x: Double) -> Double { _erf(x) }

  @usableFromInline
  internal static func _erf(_ x: Double) -> Double { system_erf(x) }

  /// Returns the error function of a value.
  ///
  /// The corresponding C function is `erff`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func erf(_ x: Float) -> Float { _erf(x) }

  @usableFromInline
  internal static func _erf(_ x: Float) -> Float { system_erff(x) }

  /// Returns the complementary error function of a value, 1 - erf(x).
  ///
  /// It's accurate for a large value, where `1 - erf(x)` isn't.
  ///
  /// The corresponding C function is `erfc`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func erfc(_ x: Double) -> Double { _erfc(x) }

  @usableFromInline
  internal static func _erfc(_ x: Double) -> Double { system_erfc(x) }

  /// Returns the complementary error function of a value, 1 - erf(x).
  ///
  /// It's accurate for a large value, where `1 - erf(x)` isn't.
  ///
  /// The corresponding C function is `erfcf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func erfc(_ x: Float) -> Float { _erfc(x) }

  @usableFromInline
  internal static func _erfc(_ x: Float) -> Float { system_erfcf(x) }

  /// Returns the gamma function of a value.
  ///
  /// For a positive integer n, it's (n - 1)!.
  ///
  /// The corresponding C function is `tgamma`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tgamma(_ x: Double) -> Double { _tgamma(x) }

  @usableFromInline
  internal static func _tgamma(_ x: Double) -> Double { system_tgamma(x) }

  /// Returns the gamma function of a value.
  ///
  /// For a positive integer n, it's (n - 1)!.
  ///
  /// The corresponding C function is `tgammaf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func tgamma(_ x: Float) -> Float { _tgamma(x) }

  @usableFromInline
  internal static func _tgamma(_ x: Float) -> Float { system_tgammaf(x) }

  /// Returns the natural logarithm of the absolute value of the gamma function of a value.
  ///
  /// The corresponding C function is `lgamma`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func lgamma(_ x: Double) -> Double { _lgamma(x) }

  @usableFromInline
  internal static func _lgamma(_ x: Double) -> Double { system_lgamma(x) }

  /// Returns the natural logarithm of the absolute value of the gamma function of a value.
  ///
  /// The corresponding C function is `lgammaf`.
  ///
  /// - Note: Provisional: math functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func lgamma(_ x: Float) -> Float { _lgamma(x) }

  @usableFromInline
  internal static func _lgamma(_ x: Float) -> Float { system_lgammaf(x) }
}
