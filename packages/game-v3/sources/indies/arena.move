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
    use sui::hash::blake2b256;
    use pokemon::stats::Stats;
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

        if (self.p1.is_none()) {
            self.p1.fill(new_player(stats, moves, id));
        } else {
            assert!(self.p1.borrow().id != &id, ESamePlayer);
            self.p2.fill(new_player(stats, moves, id));
        }
    }

    /// Commit a move for the given player (authorization is performed based on
    /// the `id` passed).
    public fun commit(self: &mut Arena, id: address, commitment: vector<u8>) {
        assert!(self.winner.is_none(), EWinnerAlreadySet);

        let (p1, _p2) = self.players_by_id(id);
        assert!(p1.commitment.is_none(), ECommitmentAlreadySet);

        p1.commitment.fill(commitment);
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
        let (p1, p2) = self.players_by_id(id);
        let mut commitment = vector[ move_ ];
        commitment.append(salt);
        let commitment = blake2b256(&commitment);

        assert!(p1.moves.contains(&move_), EIllegalMove);
        assert!(commitment == p1.commitment.extract(), EIncorrectReveal);

        // store the next Move for the last player to reveal and perform an attack.
        p1.next_move.fill(move_);

        // now do the math and update the stats
        if (p1.next_move.is_some() && p2.next_move.is_some()) {
            self.calculate_round(rng_seed)
        };
    }

    // === Getters ===

    /// Check if the game is over.
    public fun is_game_over(self: &Arena): bool {
        option::is_some(&self.winner)
    }

    /// Getter for the winner. Fails if the game is not over yet.
    public fun winner(self: &Arena): address {
        *self.winner.borrow()
    }

    /// Getter for the current round.
    public fun round(self: &Arena): u8 { self.round }

    /// Internal: util to check whether the game has started already
    public fun game_started(self: &Arena): bool {
        self.p1.is_some() && self.p2.is_some()
    }

    /// Getter for current player stats (changes every round).
    public fun stats(self: &Arena): (&Stats, &Stats) {
        (
            &self.p1.borrow().stats,
            &self.p2.borrow().stats,
        )
    }

    /// Getter for original players' stats (never changes).
    public fun original_stats(self: &Arena): (&Stats, &Stats) {
        (
            &self.p1.borrow().original_stats,
            &self.p2.borrow().original_stats,
        )
    }

    /// Return the attacker and defender in order based on the ID passed.
    public fun players_by_id(self: &mut Arena, id: address): (&mut ActivePlayer, &mut ActivePlayer) {
        assert!(self.game_started(), EArenaNotStarted);

        let is_p1 = self.p1.borrow().id == &id;
        let is_p2 = self.p2.borrow().id == &id;

        if (is_p1) {
            (
                self.p1.borrow_mut(),
                self.p2.borrow_mut()
            )
        } else if (is_p2) {
            (
                self.p2.borrow_mut(),
                self.p1.borrow_mut()
            )
        } else {
            abort EUnknownSender // we don't know who you are bruh
        }
    }

    public fun has_character(self: &Arena, id: address): bool {
        let is_p1 = &self.p1.borrow().id == &id;
        let is_p2 = &self.p2.borrow().id == &id;

        is_p1 || is_p2
    }

    /// Return the ID of the first player.
    public fun p1_id(self: &Arena): address {
        self.p1.borrow().id
    }

    /// Return the ID of the second player.
    public fun p2_id(self: &Arena): address {
        self.p2.borrow().id
    }

    // === Internal ===

    /// Return Pokemons based on their speed.
    fun by_speed(self: &mut Arena): (&mut ActivePlayer, &mut ActivePlayer) {
        let p1_speed = self.p1.borrow().stats.speed();
        let p2_speed = self.p2.borrow().stats.speed();

        if (p1_speed > p2_speed) {
            (
                self.p1.borrow_mut(),
                self.p2.borrow_mut()
            )
        } else {
            (
                self.p2.borrow_mut(),
                self.p1.borrow_mut()
            )
        }
    }

    /// The most important function - calculates the round result and updates
    /// the stats + round. Defines the winner if there is.
    fun calculate_round(self: &mut Arena, rng_seed: vector<u8>) {
        self.round = self.round + 1;

        let mut history = *&self.history; // bypassing borrow checker
        let (p1, p2) = self.by_speed();
        let p1_move = p1.next_move.extract();
        let p2_move = p2.next_move.extract();

        // IN YOUR FACE ;)
        let (dmg, eff, stab) = battle::attack(
            &p1.stats, &mut p2.stats, (p1_move as u64), 255
        );

        history.push_back(HitRecord {
            effectiveness: eff,
            move_: p1_move,
            damage: dmg,
            stab,
        });

        if (p2.stats.hp() == 0) {
            self.winner = option::some(p1.id);
            self.history = history;
            return
        };

        let (dmg, eff, stab) = battle::attack(
            &p2.stats, &mut p1.stats, (p2_move as u64), 255
        );

        history.push_back(HitRecord {
            effectiveness: eff,
            move_: p2_move,
            damage: dmg,
            stab,
        });

        if (p1.stats.hp() == 0) {
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
