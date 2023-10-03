// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Arena module manages the interaction between two players making sure the
/// transport layer is implemented correctly (as well as commit-reveal schemes).
///
/// - Depends on the `battle.move` for actual moves + attack calculation.
/// - Applies stats to temporary values stored in the self.
/// - Returns the result for the winner / loser.
/// - Handles the timings for the game - if a player did not act within 3
/// minutes we consider it abandoning and it must be returned in the result of
/// the match.
///
/// The Arena is created once for a match and can be accessed only by its
/// participants; the authorization is performed based on the KioskOwnerCap, as
/// `Player` struct stores the Kiosk ID.
module game::arena {
    use std::vector;
    use std::option::{Self, Option};

    use sui::tx_context::TxContext;
    use sui::kiosk::{Self, KioskOwnerCap};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::bcs;

    use game::battle;
    use game::player::{Self, Player};
    use pokemon::stats::{Self, Stats};

    /// Trying to perform an action while still searching for P2;
    const EArenaNotReady: u64 = 0;
    /// Trying to perform an action while the arena is over;
    const EArenaOver: u64 = 1;
    /// Can't do next round if P1 hasn't submitted their move;
    const EAnotherPlayerNotReady: u64 = 2;
    /// Trying to attack while Move is already there.
    const EMoveAlreadySubmitted: u64 = 4;
    /// Not a Player.
    const EUnknownSender: u64 = 5;
    /// Invalid commitment; the hash of the move doesn't match the commitment.
    const EInvalidCommitment: u64 = 6;

    /// The Arena where the game is played; both players interact with the Arena
    /// object to play the game; the rules are enforced by the self.
    struct Arena has key {
        id: UID,
        /// The pseudo-random seed for the game.
        seed: vector<u8>,
        /// The current round of the game.
        round: u8,
        /// Unique identifier for the game, passed by the matchmaker.
        game_id: ID,
        /// Player 1 stats and the current game state.
        p1: Option<ActivePlayer>,
        /// Player 2 stats and the current game state.
        p2: Option<ActivePlayer>,
    }

    /// Currently active player (wraps the Player struct).
    struct ActivePlayer has store, drop {
        /// The stats of the Player's Pokemon.
        stats: Stats,
        /// Player's Kiosk ID.
        kiosk_id: ID,
        /// Stores the hashed move.
        next_attack: Option<vector<u8>>,
        /// Helps track the round. So that a second reveal can be performed
        /// without rushing into async execution.
        next_round: u8,
        /// Store the original value of the player.
        player: Player
    }

    /// Create the arena and share it with the players.
    public fun create_arena(
        game_id: ID, p1: Player, p2: Player, ctx: &mut TxContext
    ): ID {
        let id = object::new(ctx);
        let arena_id = object::uid_to_inner(&id);

        // TODO: better rand stuff
        let seed = sui::hash::blake2b256(&bcs::to_bytes(&arena_id));

        transfer::share_object(Arena {
            id,
            seed,
            game_id,
            round: 0,
            p1: add_player(p1),
            p2: add_player(p2),
        });

        arena_id
    }

    /// Perfom an attack without revealing the details of the attack just yet.
    entry fun commit(
        self: &mut Arena,
        cap: &KioskOwnerCap,
        commitment: vector<u8>,
        _ctx: &mut TxContext
    ) {
        assert!(!is_over(self), EArenaOver);

        let kiosk_id = kiosk::kiosk_owner_cap_for(cap);

        // If it's a P1 attack
        let player = if (kiosk_id == option::borrow(&self.p1).kiosk_id) {
            option::borrow_mut(&mut self.p1)
        } else if (kiosk_id == option::borrow(&self.p2).kiosk_id) {
            option::borrow_mut(&mut self.p2)
        } else {
            abort EUnknownSender // we don't know who you are
        };

        // Store the commitment; record the action for the Player.
        assert!(option::is_none(&player.next_attack), EMoveAlreadySubmitted);
        option::fill(&mut player.next_attack, commitment);

        sui::event::emit(PlayerCommit {
            arena: object::uid_to_address(&self.id)
        });
    }

    /// Each of the players needs to reveal their move; so that the round can
    /// be calculated. The last player to reveal bumps the round.
    entry fun reveal(
        self: &mut Arena,
        cap: &KioskOwnerCap,
        player_move: u8,
        salt: vector<u8>,
        _ctx: &mut TxContext
    ) {
        assert!(!is_over(self), EArenaOver);

        // The player that is revealing.
        let kiosk_id = kiosk::kiosk_owner_cap_for(cap);

        // Get both players (as mutable references).
        let (attacker, defender) = if (is_player_one(self, kiosk_id)) {
            (
                option::borrow_mut(&mut self.p1),
                option::borrow_mut(&mut self.p2)
            )
        } else if (is_player_two(self, kiosk_id)) {
            (
                option::borrow_mut(&mut self.p2),
                option::borrow_mut(&mut self.p1)
            )
        } else {
            abort EUnknownSender // we don't know who you are bruh
        };

        // Check if the player is allowed to reveal and if they haven't already.
        assert!(option::is_some(&attacker.next_attack), EAnotherPlayerNotReady);
        assert!(attacker.next_round == self.round, EMoveAlreadySubmitted);

        let commitment = vector[ player_move ];
        vector::append(&mut commitment, salt);

        let commitment = sui::hash::blake2b256(&commitment);
        let next_attack = option::extract(&mut attacker.next_attack);
        assert!(&commitment == &next_attack, EInvalidCommitment);

        battle::attack(
            &attacker.stats,
            &mut defender.stats,
            (player_move as u64),
            hit_rng(commitment, 2, self.round),
            false
        );

        attacker.next_round = self.round + 1;

        let next_round_cond = option::is_none(&defender.next_attack)
            && (defender.next_round == (self.round + 1));

        sui::event::emit(PlayerReveal {
            arena: object::uid_to_address(&self.id),
            _move: player_move
        });

        // If both players have revealed, then the round is over; the last one
        // to reveal bumps the round.
        if (next_round_cond) {
            self.round = self.round + 1;

            sui::event::emit(RoundResult {
                arena: object::uid_to_address(&self.id),
                attacker_hp: stats::hp(&attacker.stats),
                defender_hp: stats::hp(&defender.stats),
            });
        };
    }

    // === Reads ===

    /// Returns the final state of the self. Given that the arena can only be
    /// created with both `Player`s in, not having one of them means the match
    /// has concluded for one of the possible reasons.
    public fun is_over(self: &Arena): bool {
        option::is_none(&self.p1) || option::is_none(&self.p2)
    }

    /// Returns the current round of the game.
    public fun round(self: &Arena): u8 {
        self.round
    }

    // === Internal ===

    /// Returns true if the player is Player 1.
    fun is_player_one(self: &Arena, kiosk_id: ID): bool {
        option::borrow(&self.p1).kiosk_id == kiosk_id
    }

    /// Internal function to check if the player is Player 2.
    fun is_player_two(self: &Arena, kiosk_id: ID): bool {
        option::borrow(&self.p2).kiosk_id == kiosk_id
    }

    /// Internal function to read the data from the `Player` struct and prepare
    /// the environment for the game.
    fun add_player(player: Player): Option<ActivePlayer> {
        option::some(ActivePlayer {
            stats: *player::stats(&player),
            kiosk_id: player::kiosk(&player),
            next_attack: option::none(),
            next_round: 0,
            player
        })
    }

    /// Generate a random number for a hit in the range [217; 255]
    fun hit_rng(seed: vector<u8>, path: u8, round: u8): u8 {
        let value = *vector::borrow(&derive(seed, path), (round as u64));
        ((value % (255 - 217)) + 217)
    }

    /// Derive a new seed from a previous seed and a path.
    fun derive(seed: vector<u8>, path: u8): vector<u8> {
        vector::push_back(&mut seed, path);
        sui::hash::blake2b256(&seed)
    }

    // === Events ===

    /// Emitted when a new Arena is created and available for joining.
    struct ArenaCreated has copy, drop { arena: address }

    /// Emitted when a player commits the hit move.
    struct PlayerCommit has copy, drop { arena: address }

    /// Emitted when a player reveals the result and hits the other player.
    struct PlayerReveal has copy, drop {
        arena: address,
        _move: u8
    }

    /// Emitted when both players have hit and the round is over.
    struct RoundResult  has copy, drop {
        arena: address,
        attacker_hp: u64,
        defender_hp: u64
    }
}
