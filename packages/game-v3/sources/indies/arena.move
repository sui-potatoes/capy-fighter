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
    public struct ActivePlayer has store, drop {
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
    public struct Arena has store, drop {
        /// Active Player stats for the first player to join.
        p1: Option<ActivePlayer>,
        /// Active Player stats for the second player to join.
        p2: Option<ActivePlayer>,
        /// Round counter (starts from 0).
        round: u8,
        /// The winner of the game. If the game is not over yet, the value is
        /// `None`, otherwise it's the id of the winner.
        winner: Option<address>,
        /// History of the performed moves. The fastest player hits first,
        /// then the second player hits and so on.
        history: vector<HitRecord>,
    }

    /// A Struct representing a single attack.
    public struct HitRecord has copy, store, drop {
        /// The move performed by the attacker.
        move_: u8,
        /// The damage dealt to the defender.
        damage: u64,
        /// The effectiveness of the move.
        effectiveness: u64,
        /// The critical hit flag.
        stab: bool,
    }

    /// Create a new empty Arena; no bias towards any of the players.
    public fun new(): Arena {
        Arena {
            p1: option::none(),
            p2: option::none(),
            winner: option::none(),
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
            assert!(&option::borrow(&self.p1).id != &id, ESamePlayer);
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
        assert!(option::is_none(&self.winner), EWinnerAlreadySet);

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
        let mut commitment = vector[ move_ ];
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

    /// Check if the game is over.
    public fun is_game_over(self: &Arena): bool {
        option::is_some(&self.winner)
    }

    /// Getter for the winner. Fails if the game is not over yet.
    public fun winner(self: &Arena): address {
        *option::borrow(&self.winner)
    }

    /// Getter for the current round.
    public fun round(self: &Arena): u8 { self.round }

    /// Internal: util to check whether the game has started already
    public fun game_started(self: &Arena): bool {
        option::is_some(&self.p1) && option::is_some(&self.p2)
    }

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

    public fun has_character(self: &Arena, id: address): bool {
        let is_p1 = &option::borrow(&self.p1).id == &id;
        let is_p2 = &option::borrow(&self.p2).id == &id;

        is_p1 || is_p2
    }

    /// Return the ID of the first player.
    public fun p1_id(self: &Arena): address {
        option::borrow(&self.p1).id
    }

    /// Return the ID of the second player.
    public fun p2_id(self: &Arena): address {
        option::borrow(&self.p2).id
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

        let mut history = *&self.history; // bypassing borrow checker
        let (p1, p2) = by_speed(self);
        let p1_move = option::extract(&mut p1.next_move);
        let p2_move = option::extract(&mut p2.next_move);

        // IN YOUR FACE ;)
        let (dmg, eff, stab) = battle::attack(
            &p1.stats, &mut p2.stats, (p1_move as u64), 255
        );

        vector::push_back(&mut history, HitRecord {
            effectiveness: eff,
            move_: p1_move,
            damage: dmg,
            stab,
        });

        if (stats::hp(&p2.stats) == 0) {
            self.winner = option::some(p1.id);
            self.history = history;
            return
        };

        let (dmg, eff, stab) = battle::attack(
            &p2.stats, &mut p1.stats, (p2_move as u64), 255
        );

        vector::push_back(&mut history, HitRecord {
            effectiveness: eff,
            move_: p2_move,
            damage: dmg,
            stab,
        });

        if (stats::hp(&p1.stats) == 0) {
            self.winner = option::some(p2.id);
            self.history = history;
            return
        };

        self.history = history;
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

    // === Test Only ===

    #[test_only]
    public fun player_id_for_testing(player: &ActivePlayer): address {
        player.id
    }
}
