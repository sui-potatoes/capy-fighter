// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_const, unused_use, unused_variable)]
module math::glicko2 {
    use sui::math;
    use math::pi;

    /// Choosing this value blindly for now. It allows for most of the constants
    /// to stay within the range of a 64-bit integer.
    const SCALING: u64 = 100_000_000;

    /// The default scaling factor for the calculations.
    const GLICKO_SCALE: u64 = 1737178; // x `SQRT(SCALING)` 10^4

    /// The default rating for a player.
    const DEFAULT_RATING: u64 = 1500;

    /// The system constant `Tau` - 0.5 scaled by 10.
    const SYSTEM_CONSTANT: u64 = 50;

    /// Internal type to store a value with a sign.
    struct SignedU64 has copy, store, drop { value: u64, sign: bool }

    /// Scaling the rating to the Glicko2 scale.
    /// Upscaled by `SQRT(SCALING)` (10^4).
    public fun mu(rating: u64): SignedU64 {
        // assert!(rating < 1_000_000, 0);
        let SignedU64 { sign, value } = sub(rating, DEFAULT_RATING);
        let value = (value * SCALING) / GLICKO_SCALE;

        SignedU64 { sign, value }
    }

    /// Transforms the rating deviation `rd` to the phi value.
    /// Upscaled by `SQRT(SCALING)` (10^4).
    public fun phi(rd: u64): u64 {
        (rd * SCALING) / GLICKO_SCALE
    }

    /// Returns the gamma(phi);
    /// Upscaled by `SQRT(SCALING)` (10^4).
    public fun gamma(phi: u64): u64 {
        let phi_squared = phi * phi; // scaling 10^8 due to ^2 operation
        let pi_squared = pi::pi_squared(8); // scaling 10^8 due to ^2 operation

        // we upscale every value by `SCALING` (10^8)
        let denominator = SCALING + (3 * SCALING * phi_squared / pi_squared);

        // the result is upscaled by 10^4
        (SCALING / math::sqrt(denominator))
    }

    /// Returns the `E` function for given `mu`, `mu_j` and `phi_j`.
    /// Upscaled by ???.
    /// ```
    ///  E(mu, mu_j , phi_j ) = 1 / ( 1 + exp( -g(phi_j) * (mu - mu_j ) ) )
    /// ```
    public fun epsilon(
        mu: SignedU64,
        mu_j: SignedU64,
        phi_j: u64
    ): u64 {

        let mu_sub = signed_sub(mu, mu_j);
        let exp_sign = (mu_sub.sign == false); // -g and -mu_sub -> +
        let exp_value = gamma(phi_j) * mu_sub.value;

        // SCALING / 1 + math::exp();



        std::debug::print(&vector[ g, sub.value ]);

        sub.value
    }

    /// Internal: returns the absolute difference between two values and the
    /// sign of the difference.
    fun sub(a: u64, b: u64): SignedU64 {
        if (a == b) {
            SignedU64 { sign: true, value: 0 }
        } else if (a < b) {
            SignedU64 { sign: false, value: b - a }
        } else {
            SignedU64 { sign: true, value: a - b }
        }
    }

    fun signed_sub(a: SignedU64, b: SignedU64): SignedU64 {
        if (a.value == b.value) {
            return SignedU64 { sign: true, value: 0 }
        };

        if (a.sign == b.sign) {
            if (a.value < b.value) {
                SignedU64 { sign: !a.sign, value: b.value - a.value }
            } else {
                SignedU64 { sign: a.sign, value: a.value - b.value }
            }
        } else {
            if (a.sign) {
                SignedU64 { sign: true, value: a.value + b.value }
            } else {
                SignedU64 { sign: false, value: a.value + b.value }
            }
        }
    }

    /// Internal: quick way to create SU64 values.
    fun su64(sign: bool, value: u64): SignedU64 {
        SignedU64 { sign, value }
    }

    // The values for this test are taken from the Glicko2 paper.
    // http://www.glicko.net/glicko/glicko2.pdf
    #[test] fun test_epsilon() {
        let res = epsilon(
            mu(1500), // Player
            mu(1400), // Opp1 mu
            phi(30)   // Opp1 phi
        );

        std::debug::print(&vector[ res, 6390 ])
    }

    // The values for this test are taken from the Glicko2 paper.
    // http://www.glicko.net/glicko/glicko2.pdf
    #[test] fun test_gamma() {
        assert!(gamma(phi(30)) == 9955, 0);
        assert!(gamma(phi(100)) == 9531, 0);
        assert!(gamma(phi(300)) == 7242, 0);
    }

    // The values for this test are taken from the Glicko2 paper.
    // http://www.glicko.net/glicko/glicko2.pdf
    #[test] fun test_mu() {
        let SignedU64 { sign, value } = mu(1500);
        assert!(sign && value == 0, 0); // 0.0

        let SignedU64 { sign, value } = mu(1400);
        assert!(!sign && value == 5756, 1); // 0.5756 * SCALING

        let SignedU64 { sign, value } = mu(1550);
        assert!(sign && value == 2878, 2); // 0.2878 * SCALING

        let SignedU64 { sign, value } = mu(1700);
        assert!(sign && value == 11512, 2); // 1.1513 * SCALING
    }

    // The values for this test are taken from the Glicko2 paper.
    // http://www.glicko.net/glicko/glicko2.pdf
    #[test] fun test_phi() {
        assert!(phi(200) == 11512, 0); // 1.1512 * SCALING
        assert!(phi(30) == 1726, 1); // 0.1726 * SCALING
        assert!(phi(100) == 5756, 2); // 0.5756 * SCALING
        assert!(phi(300) == 17269, 3); // 1.7269 * SCALING
    }

    #[test] fun test_signed_sub() {
        assert!(signed_sub(su64(true, 10), su64(true, 5)) == su64(true, 5), 0);
        assert!(signed_sub(su64(true, 5), su64(true, 10)) == su64(false, 5), 1);

        // -10 - (-5) = -5
        assert!(signed_sub(su64(false, 10), su64(false, 5)) == su64(false, 5), 2);
        // -5 - (-10) = 5
        assert!(signed_sub(su64(false, 5), su64(false, 10)) == su64(true, 5), 3);
        // 10 - (-5) = 15
        assert!(signed_sub(su64(true, 10), su64(false, 5)) == su64(true, 15), 4);
        // -10 - 5 = -15
        assert!(signed_sub(su64(false, 10), su64(true, 5)) == su64(false, 15), 5);
        // -0 - -0 = 0
        assert!(signed_sub(su64(false, 0), su64(false, 0)) == su64(true, 0), 6);
    }
}
