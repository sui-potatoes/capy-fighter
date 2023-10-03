// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The Player module; defines the Player generation + Stats accessors.
///
/// - All players start with Level = 1.
/// - Players can be created by anyone (for now).
module game::player {
    use std::vector;
    use std::option::{Self, Option};

    use sui::clock::{Self, Clock};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID, ID};

    use pokemon::stats::{Self, Stats};

    // TODO: using a friend before we recompose the system in a better way.
    friend game::the_game;

    /// Error code for when the player is not banned.
    const ENotBanned: u64 = 0;
    /// Error code for when the player is still banned and trying to remove ban,
    const EStillBanned: u64 = 1;

    /// A Playable Character type; for now not protected (to not overcompilate
    /// things with generics) but should be.
    struct Player has store, drop {
        stats: Stats,
        /// The Kiosk ID of the player.
        kiosk: ID,
        /// Using this field to punish the player for bad behavior. Abandoning
        /// the match or cheating will result in a ban.
        banned_until: Option<u64>,
        // ...
    }

    /// Create a new Player.
    public(friend) fun new(
        kiosk: &UID, // TODO: fixme
        seed: vector<u8>,
        _ctx: &mut TxContext
    ): Player {
        Player {
            stats: generate_stats(seed),
            kiosk: object::uid_to_inner(kiosk),
            banned_until: option::none(),
            // ...
        }
    }

    /// Remove the ban once the time has passed; requires a manual action from
    /// the player to make it more explicit.
    public fun remove_ban(self: &mut Player, clock: &Clock, _ctx: &mut TxContext) {
        assert!(option::is_some(&self.banned_until), ENotBanned);

        let banned_until = option::extract(&mut self.banned_until);
        assert!(clock::timestamp_ms(clock) >= banned_until, ENotBanned);
    }

    // === Reads ===

    /// Get the stats of the player.
    public fun stats(self: &Player): &Stats { &self.stats }

    /// Get the kiosk of the player.
    public fun kiosk(self: &Player): ID { self.kiosk }

    /// Get the ban status of the player.
    public fun banned_until(self: &Player): Option<u64> { self.banned_until }

    /// Check if the player is banned.
    public fun is_banned(self: &Player): bool {
        option::is_some(&self.banned_until)
    }

    // === Internal ===

    /// Generate stats based on a seed; currently just a dummy-something to
    /// make sure we can assemble the game.
    ///
    /// Add Level Calculation here!
    fun generate_stats(seed: vector<u8>): Stats {
        let level = 1;

        stats::new(
            10 + smooth(*vector::borrow(&seed, 0)),
            smooth(*vector::borrow(&seed, 1)),
            smooth(*vector::borrow(&seed, 2)),
            smooth(*vector::borrow(&seed, 3)),
            smooth(*vector::borrow(&seed, 4)),
            smooth(*vector::borrow(&seed, 5)),
            level,
            vector[ *vector::borrow(&seed, 6) % 3 ]
        )
    }

    /// Smoothens out the value by making it closer to median = 50.
    fun smooth(value: u8): u8 {
        let value = ((value % 50) + 50) / 2;
        if (value < 10) {
            10
        } else {
            value
        }
    }
}
