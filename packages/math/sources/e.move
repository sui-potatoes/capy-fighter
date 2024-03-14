// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module math::e {
    /// Euler's number, the base of the natural logarithm.
    const E: u64 = 2718281828459045235;

    

    /// Number of powers of ten that fit in a u256.
    const DECIMALS: u8 = 19;

    /// Scaling can be between 0 and 75.
    // const EInvalidScaling: u64 = 0;

    /// Returns Euler's number with the given scaling factor.
    /// `0` for 2 (no decimals)
    /// `1` for 27 (2.7) and so on.
    public fun e(scaling: u8): u64 {
        E / pow_ten(DECIMALS - scaling - 1)
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
