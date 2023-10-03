// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module elo::elo {

    fun print<T>(str: vector<u8>, value: &T) {
        std::debug::print(&std::string::utf8(str));
        std::debug::print(value);
    }

    const SCALING: u64 = 1000_000;

    /// Function to calculate expected outcome
    public fun expected_outcome(max: u64, min: u64): u64 {
        let exponent = (max - min) / SCALING;
        let denominator = 1 + pow(10u64, exponent / 400u64);

        print(b"denominator", &denominator);

        SCALING / (denominator as u64)
    }

    fun update_ratings(winner_rating: u64, loser_rating: u64, k_factor: u64): (u64, u64) {
        let (max, min) = max_min(winner_rating, loser_rating);

        let expected_outcome = expected_outcome(max, min);

        print(b"expected outcome", &expected_outcome);

        let delta_winner = k_factor * (SCALING - expected_outcome);
        let delta_loser = k_factor * expected_outcome;

        let new_winner_rating = winner_rating + delta_winner;
        let new_loser_rating = loser_rating - delta_loser;

        (new_winner_rating, new_loser_rating)
    }

    fun pow(value: u64, power: u64): u128 {
        let result: u128 = 1;
        while (power > 0) {
            // std::debug::print(&vector[ (power as u128), result ]);
            result = result * (value as u128);
            power = power - 1;
        };

        result
    }

    fun max_min(a: u64, b: u64): (u64, u64) {
        if (a > b) {
            (a, b)
        } else {
            (b, a)
        }
    }

    #[test]
    fun test_expected_outcome() {
        // let (a, b) = expected_outcome(1500, 1400);
        // std::debug::assert!(expected_outcome(1500, 1400) == 240_253_899, 0);
        // std::debug::print(&vector[ expected_outcome(1400 * SCALING, 1500 * SCALING), 240_253_899 ]);

        let (p1, p2) = (1200 * SCALING, 2500 * SCALING);

        std::debug::print(&vector[ p1, p2 ]);

        // higher score wins
        let (p1, p2) = update_ratings(p1, p2, 32);


        std::debug::print(&vector[ p1, p2 ]);


        // assert!(expected_outcome(1400, 1500) == 759_746_101, 0);
        // playerARating = 1500
        // playerBRating = 1400
        // scalingFactor = 1000
    }
}
