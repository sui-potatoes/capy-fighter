// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Simple library that implements PI to 76 decimal places.
module math::pi {

    /// PI, with 18 decimal places.
    const PI: u64 = 3141592653589793238;

    /// Square root of PI, with 18 decimal places.
    const PI_SQRT: u64 = 1772453850916883720;

    /// PI squared, with 15 decimal places.
    const PI_SQUARED: u64 = 9869604401089358618;

    /// Number of powers of ten that fit in a u256.
    const DECIMALS: u8 = 19;

    /// Scaling can be between 0 and 75.
    const EInvalidScaling: u64 = 0;

    /// Returns PI scaled to the given number of decimal places.
    /// `scaling` set to 0 returns PI as an integer: `3`
    /// `scaling` set to 1 returns PI + one decimal place: `31`
    /// ...and so on.
    public fun pi(scaling: u8): u64 {
        assert!(scaling < DECIMALS, EInvalidScaling);
        PI / pow_ten(DECIMALS - scaling - 1)
    }

    /// Returns square root of PI scaled to the given number of decimal places.
    public fun pi_sqrt(scaling: u8): u64 {
        assert!(scaling < DECIMALS, EInvalidScaling);
        PI_SQRT / pow_ten(DECIMALS - scaling - 1)
    }

    /// Returns PI squared scaled to the given number of decimal places.
    /// `scaling` set to 0 returns PI squared as an integer: `9`
    /// `scaling` set to 1 returns PI squared + one decimal place: `98`
    /// ...and so on.
    public fun pi_squared(scaling: u8): u64 {
        assert!(scaling < DECIMALS, EInvalidScaling);
        PI_SQUARED / pow_ten(DECIMALS - scaling - 1)
    }

    fun pow_ten(n: u8): u64 {
        let res = 1;
        while (n > 0) {
            res = res * 10;
            n = n - 1;
        };
        res
    }

    #[test] fun test_scaling() {
        assert!(pi(0) == 3, 0);
        assert!(pi(1) == 31, 0);
        assert!(pi(2) == 314, 0);
        assert!(pi(3) == 3141, 0);
        assert!(pi(18) == PI, 0);
    }
}
