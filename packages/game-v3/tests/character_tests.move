// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module game::character_tests {
    use game::character::{Self as char, stats};
    use pokemon::stats;

    const BASE_XP: u64 = 250;

    #[test]
    /// Test the level xp requirement.
    /// Compares the results against the formula and current setup.
    fun test_level_xp_requirement() {
        assert!(char::level_xp_requirement(1) == 250, 1);
        assert!(char::level_xp_requirement(2) == 1000, 2);
        assert!(char::level_xp_requirement(3) == 2250, 3);
        assert!(char::level_xp_requirement(4) == 4000, 4);
        assert!(char::level_xp_requirement(5) == 6250, 5);
        assert!(char::level_xp_requirement(6) == 9000, 6);
        assert!(char::level_xp_requirement(7) == 12250, 7);
        assert!(char::level_xp_requirement(8) == 16000, 8);
        assert!(char::level_xp_requirement(9) == 20250, 9);
    }

    #[test]
    fun test_add_xp() {
        let ctx = &mut sui::tx_context::dummy();
        let character = char::new(
            0,
            vector[ 0, 0, 0, 0, 0, 0 ],
            vector[ 0, 0, 0, 0, 0, 0 ],
            ctx
        );

        assert!(stats::level(stats(&character)) == 1, 1);
        assert!(char::xp(&character) == BASE_XP, 2);

        char::add_xp(&mut character, 1000);

        assert!(stats::level(char::stats(&character)) == 2, 3);
        assert!(char::xp(&character) == 1000 + BASE_XP, 4);

        char::add_xp(&mut character, 4000);

        assert!(stats::level(char::stats(&character)) == 4, 5);
        assert!(char::xp(&character) == 5000 + BASE_XP, 6);
    }
}
