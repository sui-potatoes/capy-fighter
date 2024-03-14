// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines a fixed-point numeric type with a 32-bit integer part and
/// a 32-bit fractional part.

module math::fp32 {
    /// Define a fixed-point numeric type with 32 fractional bits.
    /// This is just a u64 integer but it is wrapped in a struct to
    /// make a unique type. This is a binary representation, so decimal
    /// values may not be exactly representable, but it provides more
    /// than 9 decimal digits of precision both before and after the
    /// decimal point (18 digits total). For comparison, double precision
    /// floating-point has less than 16 decimal digits of precision, so
    /// be careful about using floating-point to convert these values to
    /// decimal.
    struct FixedPoint32 has copy, drop, store { value: u64 }

    ///> TODO: This is a basic constant and should be provided somewhere centrally in the framework.
    const MAX_U64: u128 = 18446744073709551615;

    /// The denominator provided was zero
    const EDENOMINATOR: u64 = 0x10001;
    /// The quotient value would be too large to be held in a `u64`
    const EDIVISION: u64 = 0x20002;
    /// The multiplied value would be too large to be held in a `u64`
    const EMULTIPLICATION: u64 = 0x20003;
    /// A division by zero was encountered
    const EDIVISION_BY_ZERO: u64 = 0x10004;
    /// The computed ratio when converting to a `FixedPoint32` would be unrepresentable
    const ERATIO_OUT_OF_RANGE: u64 = 0x20005;

    /// Multiply a u64 integer by a fixed-point number, truncating any
    /// fractional part of the product. This will abort if the product
    /// overflows.
    public fun multiply_u64(val: u64, multiplier: FixedPoint32): u64 {
        // The product of two 64 bit values has 128 bits, so perform the
        // multiplication with u128 types and keep the full 128 bit product
        // to avoid losing accuracy.
        let unscaled_product = (val as u128) * (multiplier.value as u128);
        // The unscaled product has 32 fractional bits (from the multiplier)
        // so rescale it by shifting away the low bits.
        let product = unscaled_product >> 32;
        // Check whether the value is too large.
        assert!(product <= MAX_U64, EMULTIPLICATION);
        (product as u64)
    }

    /// Divide a u64 integer by a fixed-point number, truncating any
    /// fractional part of the quotient. This will abort if the divisor
    /// is zero or if the quotient overflows.
    public fun divide_u64(val: u64, divisor: FixedPoint32): u64 {
        // Check for division by zero.
        assert!(divisor.value != 0, EDIVISION_BY_ZERO);
        // First convert to 128 bits and then shift left to
        // add 32 fractional zero bits to the dividend.
        let scaled_value = (val as u128) << 32;
        let quotient = scaled_value / (divisor.value as u128);
        // Check whether the value is too large.
        assert!(quotient <= MAX_U64, EDIVISION);
        // the value may be too large, which will cause the cast to fail
        // with an arithmetic error.
        (quotient as u64)
    }

    /// Create a fixed-point value from a rational number specified by its
    /// numerator and denominator. Calling this function should be preferred
    /// for using `Self::create_from_raw_value` which is also available.
    /// This will abort if the denominator is zero. It will also
    /// abort if the numerator is nonzero and the ratio is not in the range
    /// 2^-32 .. 2^32-1. When specifying decimal fractions, be careful about
    /// rounding errors: if you round to display N digits after the decimal
    /// point, you can use a denominator of 10^N to avoid numbers where the
    /// very small imprecision in the binary representation could change the
    /// rounding, e.g., 0.0125 will round down to 0.012 instead of up to 0.013.
    public fun create_from_rational(numerator: u64, denominator: u64): FixedPoint32 {
        // If the denominator is zero, this will abort.
        // Scale the numerator to have 64 fractional bits and the denominator
        // to have 32 fractional bits, so that the quotient will have 32
        // fractional bits.
        let scaled_numerator = (numerator as u128) << 64;
        let scaled_denominator = (denominator as u128) << 32;
        assert!(scaled_denominator != 0, EDENOMINATOR);
        let quotient = scaled_numerator / scaled_denominator;
        assert!(quotient != 0 || numerator == 0, ERATIO_OUT_OF_RANGE);
        // Return the quotient as a fixed-point number. We first need to check whether the cast
        // can succeed.
        assert!(quotient <= MAX_U64, ERATIO_OUT_OF_RANGE);
        FixedPoint32 { value: (quotient as u64) }
    }

    /// Create a fixedpoint value from a raw value.
    public fun create_from_raw_value(value: u64): FixedPoint32 {
        FixedPoint32 { value }
    }

    /// Accessor for the raw u64 value. Other less common operations, such as
    /// adding or subtracting FixedPoint32 values, can be done using the raw
    /// values directly.
    public fun get_raw_value(num: FixedPoint32): u64 {
        num.value
    }

    /// Returns true if the ratio is zero.
    public fun is_zero(num: FixedPoint32): bool {
        num.value == 0
    }
}


module math::log {
    use math::fp32::{Self, FixedPoint32};
    use math::e;

    const EInvalidArgument: u64 = 0;
    // const LOG2_E: u64 = ; // log_2(e): 0.693147180559945309
                                            //

    /// Binary logarithm is the MSB - most significant bit in the number.
    /// So for number 8 (2^3) it is 3.
    /// ---
    /// Calculate logarith of x with base 2.
    /// Log2(X)
    fun log_2(x: u64): u64 {
        let n = 0;
        while (x > 1) {
            x = x >> 1;
            n = n + 1;
        };
        n
    }

    fun e(): FixedPoint32 {
        fp32::create_from_rational(
            2718281828459045235,
            pow_ten(18)
        )
    }

    fun log2e(): FixedPoint32 {
        fp32::create_from_rational(
            693147180559945309,
            pow_ten(18)
        )
    }

    fun exp(x: u64): u256 {
        assert!(x < 0x400000000000000000, 0);

        0x171547652B82FE1777D0FFDA0D23A7D12
    }

    fun ln(x: u64): u64 {
        assert!(x > 0, EInvalidArgument);

        fp32::multiply_u64(log_2(x) * 1000, log2e())
    }

    use std::debug::print;

    #[test]
    // for (n = 0; x > 1; x >>= 1) n += 1;
    fun log_test() {
        print(&ln(2));
        print(&ln(10));
    }

    fun pow_ten(n: u8): u64 {
        let res = 1;
        while (n > 0) {
            res = res * 10;
            n = n - 1;
        };
        res
    }
}
