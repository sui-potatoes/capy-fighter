// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable)]
/// New vision of the Arena: it's an interaction engine for the Pokemon algo
/// but without any authorization. It's just a pure commit + reveal and
/// stats + winner calculation in the end.
///
/// Arena states:
/// - Empty: no players joined yet
/// - Joined: one player joined
/// - Started: both players joined
/// - Over: the game is over (one of the players joined)
module game::arena {
    use std::option::{Self, Option};
    use std::vector;
    use sui::hash::blake2b256;

    use pokemon::stats::{Self, Stats};
    use game::battle;

    /// Trying to commit a move but the battle is over.
    const EWinnerAlreadySet: u64 = 0;
    /// The reveal does not match the commitment.
    const EIncorrectReveal: u64 = 1;
    /// Trying to get a player with ID but nope.
    const EUnknownSender: u64 = 2;
    /// Trying to get a player with ID but the game has not started yet.
    const EArenaNotStarted: u64 = 4;
    /// Commitment already set for the player.
    const ECommitmentAlreadySet: u64 = 5;
    /// Both players already joined the game, no more players allowed.
    const EArenaAlreadyStarted: u64 = 6;
    /// Player already joined the arena and trying to do it again.
    const ESamePlayer: u64 = 7;
    /// The move is not in the initial set.
    const EIllegalMove: u64 = 8;

    /// A Struct representing current player's state.
    /// As in: current move, next move, commitment etc
    struct ActivePlayer has store, drop {
        /// Address based identification is possible.
        id: address,
        /// List of allowed moves for the Player.
        moves: vector<u8>,
        /// The Stats of the Player.
        stats: Stats,
        /// The original (unmodified) Stats of the player.
        /// The stats can be modified using "Modifiers" as well as the HP is
        /// reduced when the player is hit.
        original_stats: Stats,
        /// Stores the commitment for the next move. When commitment is revealed
        /// the revealed data is stored in the `next_move`.
        commitment: Option<vector<u8>>,
        /// Next move to be performed when the round is over (the last player to
        /// reveal their move triggers the `calculate_round`). The move is unset
        /// when the round result is calculated.
        next_move: Option<u8>,
    }

    /// Having `drop` is a nice addition, isn't it?
    ///
    /// Thoughts:
    /// - no more UID, no IDs, no discovery = no TxContext dep
    /// - no authorization, no nothing = must be wrapped due to `store`
    /// - pure commit and pure reveal = auth is in the wrapper
    struct Arena has store, drop {
        /// Active Player stats for the first player to join.
        p1: Option<ActivePlayer>,
        /// Active Player stats for the second player to join.
        p2: Option<ActivePlayer>,
        /// Round counter (starts from 0).
        round: u8,
        /// Enum-like field which stores the winner when over.
        /// Values: `0` for None, `1` for P1, `2` for P2
        winner: u8,
        /// History of the performed moves. The fastest player hits first,
        /// then the second player hits and so on.
        history: vector<u8>,
    }

    /// Create a new empty Arena; no bias towards any of the players.
    public fun new(): Arena {
        Arena {
            p1: option::none(),
            p2: option::none(),
            winner: 0,
            round: 0,
            history: vector[],
        }
    }

    /// Join an existing Arena with the given stats.
    public fun join(
        self: &mut Arena,
        stats: Stats,
        moves: vector<u8>,
        id: address
    ) {
        assert!(!game_started(self), EArenaAlreadyStarted);

        if (option::is_none(&self.p1)) {
            option::fill(&mut self.p1, new_player(stats, moves, id));
        } else {
            assert!(&option::borrow(&mut self.p1).id != &id, ESamePlayer);
            option::fill(&mut self.p2, new_player(stats, moves, id));
        }
    }

    /// Commit a move for the given player (authorization is performed based on
    /// the `id` passed).
    public fun commit(
        self: &mut Arena,
        id: address,
        commitment: vector<u8>,
    ) {
        assert!(self.winner == 0, EWinnerAlreadySet);

        let (p1, _p2) = players_by_id(self, id);
        assert!(option::is_none(&p1.commitment), ECommitmentAlreadySet);

        option::fill(&mut p1.commitment, commitment);
    }

    /// Reveal a move for the given player (authorization is performed based on
    /// the `id` passed).
    public fun reveal(
        self: &mut Arena,
        id: address,
        move_: u8,
        salt: vector<u8>,
        rng_seed: vector<u8>,
    ) {
        let (p1, p2) = players_by_id(self, id);
        let commitment = vector[ move_ ];
        vector::append(&mut commitment, salt);
        let commitment = blake2b256(&commitment);

        assert!(vector::contains(&p1.moves, &move_), EIllegalMove);
        assert!(commitment == option::extract(&mut p1.commitment), EIncorrectReveal);

        // store the next Move for the last player to reveal and perform an attack.
        option::fill(&mut p1.next_move, move_);

        // now do the math and update the stats
        if (option::is_some(&p1.next_move) && option::is_some(&p2.next_move)) {
            calculate_round(self, rng_seed)
        };
    }

    // === Getters ===

    /// Getter for the winner.
    public fun winner(self: &Arena): u8 { self.winner }

    /// Getter for the current round.
    public fun round(self: &Arena): u8 { self.round }

    /// Internal: util to check whether the game has started already
    public fun game_started(self: &Arena): bool {
        option::is_some(&self.p1) && option::is_some(&self.p2)
    }

    /// Internal: util to check whether the game is over
    public fun is_game_over(self: &Arena): bool { self.winner != 0 }

    /// Getter for current player stats (changes every round).
    public fun stats(self: &Arena): (&Stats, &Stats) {
        (
            &option::borrow(&self.p1).stats,
            &option::borrow(&self.p2).stats,
        )
    }

    /// Getter for original players' stats (never changes).
    public fun original_stats(self: &Arena): (&Stats, &Stats) {
        (
            &option::borrow(&self.p1).original_stats,
            &option::borrow(&self.p2).original_stats,
        )
    }

    /// Return the attacker and defender in order based on the ID passed.
    public fun players_by_id(self: &mut Arena, id: address): (&mut ActivePlayer, &mut ActivePlayer) {
        assert!(game_started(self), EArenaNotStarted);

        let is_p1 = &option::borrow(&self.p1).id == &id;
        let is_p2 = &option::borrow(&self.p2).id == &id;

        if (is_p1) {
            (
                option::borrow_mut(&mut self.p1),
                option::borrow_mut(&mut self.p2)
            )
        } else if (is_p2) {
            (
                option::borrow_mut(&mut self.p2),
                option::borrow_mut(&mut self.p1)
            )
        } else {
            abort EUnknownSender // we don't know who you are bruh
        }
    }

    public fun has_player(self: &Arena, id: address): bool {
        let is_p1 = &option::borrow(&self.p1).id == &id;
        let is_p2 = &option::borrow(&self.p2).id == &id;

        is_p1 || is_p2
    }

    // === Internal ===

    /// Return Pokemons based on their speed.
    fun by_speed(self: &mut Arena): (&mut ActivePlayer, &mut ActivePlayer) {
        let p1_speed = stats::speed(&option::borrow(&self.p1).stats);
        let p2_speed = stats::speed(&option::borrow(&self.p2).stats);

        if (p1_speed > p2_speed) {
            (
                option::borrow_mut(&mut self.p1),
                option::borrow_mut(&mut self.p2)
            )
        } else {
            (
                option::borrow_mut(&mut self.p2),
                option::borrow_mut(&mut self.p1)
            )
        }
    }

    /// The most important function - calculates the round result and updates
    /// the stats + round. Defines the winner if there is.
    fun calculate_round(self: &mut Arena, rng_seed: vector<u8>) {
        self.round = self.round + 1;

        let history = *&self.history; // bypassing borrow checker
        let (p1, p2) = by_speed(self);
        let p1_move = option::extract(&mut p1.next_move);
        let p2_move = option::extract(&mut p2.next_move);


        // IN YOUR FACE ;)
        battle::attack(&p1.stats, &mut p2.stats, (p1_move as u64), 255);
        vector::push_back(&mut history, p1_move);

        if (stats::hp(&p2.stats) == 0) {
            self.winner = 1;
            self.history = history;
            return
        };

        battle::attack(&p2.stats, &mut p1.stats, (p2_move as u64), 255);
        vector::push_back(&mut history, p2_move);

        if (stats::hp(&p1.stats) == 0) {
            self.winner = 2;
            self.history = history;
            return
        };
    }

    /// Internal: util to create a new player
    fun new_player(stats: Stats, moves: vector<u8>, id: address): ActivePlayer {
        ActivePlayer {
            id,
            moves,
            stats: *&stats,
            original_stats: stats,
            next_move: option::none(),
            commitment: option::none(),
        }
    }
}

#[test_only, allow(unused_variable, unused_function)]
/// It's testing time!
module game::arena_tests {
    use std::vector;
    use pokemon::stats::{Self, Stats};
    use game::arena;

    #[test]
    fun test_p1_joined() {
        let arena = arena::new();
        let (p1, id) = p1();

        arena::join(&mut arena, p1, vector[], id);
    }

    #[test, expected_failure(abort_code = arena::ESamePlayer)]
    fun test_p1_join_twice_fail() {
        let arena = arena::new();
        let (p1, id) = p1();

        arena::join(&mut arena, p1, vector[], id);
        arena::join(&mut arena, p1, vector[], id);
    }

    #[test]
    fun test_p1_p2_battle() {
        let arena = arena::new();
        let (p1_stats, p1) = p1();
        arena::join(&mut arena, p1_stats, vector[ 0, 1, 2, 3 ], p1);

        let (p2_stats, p2) = p2();
        arena::join(&mut arena, p2_stats, vector[ 0, 1, 2, 3 ], p2);

        // p1 hits with Hydro Pump
        arena::commit(&mut arena, p1, commit(0, b"Hydro Pump"));
        arena::commit(&mut arena, p2, commit(2, b"Inferno"));

        // p1 reveals first
        arena::reveal(&mut arena, p1, 0, b"Hydro Pump", vector[]);
        assert!(arena::round(&arena) == 0, 0);

        // make sure that that the round got bumped on second reveal
        arena::reveal(&mut arena, p2, 2, b"Inferno", vector[]);
        assert!(arena::round(&arena) == 1, 0);

        // checking stats; we expect that the HP of both players is reduced
        let (p1_stats_active, p2_stats_active) = arena::stats(&arena);

        assert!(stats::hp(&p1_stats) > stats::hp(p1_stats_active), 0);
        assert!(stats::hp(&p2_stats) > stats::hp(p2_stats_active), 0);

        std::debug::print(&arena::winner(&arena));

        // turns out p2 actually won this round lmao
        // let's act like we expected it to happen and add an assertion
        assert!(arena::winner(&arena) == 2, 0);
    }

    // === Utils ===

    fun commit(move_: u8, salt: vector<u8>): vector<u8> {
        let commitment = vector[ move_ ];
        vector::append(&mut commitment, salt);
        sui::hash::blake2b256(&commitment)
    }

    fun p1(): (Stats, address) {
        (stats::new(10, 35, 35, 50, 50, 30, 10, vector[ 0 ]), @0x1)
    }

    fun p2(): (Stats, address) {
        (stats::new(10, 35, 35, 50, 50, 30, 10, vector[ 0 ]), @0x2)
    }
}
