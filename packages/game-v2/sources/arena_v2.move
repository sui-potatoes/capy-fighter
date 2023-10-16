// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable)]
/// New vision of the Arena: it's an interaction engine for the Pokemon algo
/// but without any authorization. It's just a pure commit and pure reveal and
/// stats + winner calculation in the end. Yay!
///
/// Shall we make a note that Context-less modules are the definition for what
/// a pure logic / generic impl is?
module game::arena_v2 {
    use std::option::{Self, Option};
    use std::vector;
    use sui::hash::blake2b256;

    use pokemon::stats::{Self, Stats};
    use game::battle;

    /// For when trying to use an arena and it's already over;
    const EWinnerAlreadySet: u64 = 0;
    /// The reveal does not match the commitment.
    const EIncorrectReveal: u64 = 1;
    /// Trying to get a player with ID but nope.
    const EUnknownSender: u64 = 2;

    const EArenaOver: u64 = 3;

    const EArenaNotStarted: u64 = 4;

    const ECommitmentAlreadySet: u64 = 5;

    const EArenaAlreadyStarted: u64 = 6;

    const ESamePlayer: u64 = 7;

    /// A Struct representing current player's state.
    /// As in: current move, next move, commitment etc
    struct ActivePlayer has store, drop {
        /// Address based identification is possible.
        id: address,
        /// The Stats of the Player.
        stats: Stats,
        /// The original (unmodified) Stats of the player.
        /// The stats can be modified using "Modifiers" as well as the HP is
        /// reduced when the player is hit.
        original_stats: Stats,
        ///
        commitment: Option<vector<u8>>,
        next_move: Option<u8>,
    }

    /// Having `drop` is a nice addition, isn't it?
    ///
    /// Thoughts:
    /// - no more UID, no IDs, no discovery = no TxContext dep
    /// - no authorization, no nothing = must be wrapped due to `store`
    /// - pure commit and pure reveal = auth is in the wrapper
    struct Arena has store, drop {
        p1: Option<ActivePlayer>,
        p2: Option<ActivePlayer>,

        /// We need this variable to store the p2 data before the second player
        /// actually joined the game. Or do we? :laughing:
        // p2_id: address,

        /// Let's hope there will never be a game longer than 255 rounds.
        /// Fingers crossed and it's a known flow if you think you're smart and
        /// want to highlight it.
        round: u8,

        /// 0 for None, 1 for P1, 2 for P2
        winner: u8,
    }

    /// Create a new Arena for the given stats.
    public fun new(): Arena {
        Arena {
            p1: option::none(),
            p2: option::none(),
            winner: 0,
            round: 0,
        }
    }

    /// Join an existing Arena with the given stats.
    public fun join(self: &mut Arena, stats: Stats, id: address) {
        assert!(!game_started(self), EArenaAlreadyStarted);

        if (option::is_none(&self.p1)) {
            option::fill(&mut self.p1, new_player(stats, id));
        } else {
            assert!(&option::borrow(&mut self.p1).id != &id, ESamePlayer);
            option::fill(&mut self.p2, new_player(stats, id));
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

        let (p1, _p2) = atk_def(self, id);
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
        let (p1, p2) = atk_def(self, id);
        let commitment = vector[ move_ ];
        vector::append(&mut commitment, salt);
        let commitment = blake2b256(&commitment);

        assert!(commitment == option::extract(&mut p1.commitment), EIncorrectReveal);

        // store the next Move for the last player to reveal and perform an attack.
        option::fill(&mut p1.next_move, move_);

        // now do the math and update the stats
        if (option::is_some(&p1.next_move) && option::is_some(&p2.next_move)) {
            calculate_round(self, rng_seed)
        };
    }

    // no checks and asserts necessary as we've already got to this point
    fun calculate_round(self: &mut Arena, rng_seed: vector<u8>) {
        self.round = self.round + 1;

        let (p1, p2) = by_speed(self);
        let p1_move = option::extract(&mut p1.next_move);
        let p2_move = option::extract(&mut p2.next_move);


        // IN YOUR FACE ;)
        battle::attack(&p1.stats, &mut p2.stats, (p1_move as u64), 255);

        if (stats::hp(&p2.stats) == 0) {
            self.winner = 1;
            return
        };

        battle::attack(&p2.stats, &mut p1.stats, (p2_move as u64), 255);

        if (stats::hp(&p1.stats) == 0) {
            self.winner = 2;
            return
        };
    }


    // === Internal ===

    /// Internal: util to create a new player
    fun new_player(stats: Stats, id: address): ActivePlayer {
        ActivePlayer {
            id,
            stats: *&stats,
            original_stats: stats,
            next_move: option::none(),
            commitment: option::none(),
        }
    }

    /// Internal: util to check whether the game has started already
    fun game_started(self: &Arena): bool {
        option::is_some(&self.p1) && option::is_some(&self.p2)
    }

    /// Internal: util to check whether the game is over
    fun is_game_over(self: &Arena): bool { self.winner != 0 }

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

    /// Return the attacker and defender in order based on the ID passed.
    fun atk_def(self: &mut Arena, id: address): (&mut ActivePlayer, &mut ActivePlayer) {
        assert!(game_started(self), EArenaNotStarted);
        assert!(!is_game_over(self), EArenaOver);

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
}
