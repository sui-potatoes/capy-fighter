// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only, allow(unused_variable, unused_function)]
/// It's testing time!
module game::arena_tests {
    use pokemon::stats::{Self, Stats};
    use game::arena;

    #[test]
    fun test_p1_joined() {
        let mut arena = arena::new();
        let (p1, id) = p1();

        arena.join(p1, vector[], id);
    }

    #[test, expected_failure(abort_code = arena::ESamePlayer)]
    fun test_p1_join_twice_fail() {
        let mut arena = arena::new();
        let (p1, id) = p1();

        arena.join(p1, vector[], id);
        arena.join(p1, vector[], id);
    }

    #[test]
    fun test_p1_p2_battle() {
        let mut arena = arena::new();
        let (p1_stats, p1) = p1();
        arena.join(p1_stats, vector[ 0, 1, 2, 3 ], p1);

        let (p2_stats, p2) = p2();
        arena.join(p2_stats, vector[ 0, 1, 2, 3 ], p2);

        // p1 hits with Hydro Pump
        arena.commit(p1, commit(0, b"Hydro Pump"));
        arena.commit(p2, commit(2, b"Inferno"));

        // p1 reveals first
        arena.reveal(p1, 0, b"Hydro Pump", vector[]);
        assert!(arena.round() == 0, 0);

        // make sure that that the round got bumped on second reveal
        arena.reveal(p2, 2, b"Inferno", vector[]);
        assert!(arena.round() == 1, 0);

        // checking stats; we expect that the HP of both players is reduced
        let (p1_stats_active, p2_stats_active) = arena.stats();

        assert!(p1_stats.hp() > p1_stats_active.hp(), 0);
        assert!(p2_stats.hp() > p2_stats_active.hp(), 0);

        // turns out p1 actually won this round lmao
        // let's act like we expected it to happen and add an assertion
        assert!(arena.is_game_over(), 0);
        assert!(arena.winner() == p1, 0);
    }

    // === Utils ===

    fun commit(move_: u8, salt: vector<u8>): vector<u8> {
        let mut commitment = vector[ move_ ];
        commitment.append(salt);
        sui::hash::blake2b256(&commitment)
    }

    fun p1(): (Stats, address) {
        (stats::new(10, 35, 35, 50, 50, 30, 10, vector[ 0 ]), @0x1)
    }

    fun p2(): (Stats, address) {
        (stats::new(10, 35, 35, 50, 50, 30, 10, vector[ 0 ]), @0x2)
    }
}
