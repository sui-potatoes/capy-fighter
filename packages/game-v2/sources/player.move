// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The Player module; defines the Player generation + Stats accessors.
module game::player {
    use std::vector;
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID, ID};
    use pokemon::stats::{Self, Stats};

    /// A Playable Character type; for now not protected (to not overcompilate
    /// things with generics) but should be.
    struct Player has store, drop {
        stats: Stats,
        kiosk: ID,
        // punished ???
        // inventory ???
        // ...
        // maybe more fields to come (like App ID? Hmm)
    }

    /// Create a new Player.
    public fun new(
        kiosk: &UID, // TODO: fixme
        seed: vector<u8>,
        _ctx: &mut TxContext
    ): Player {
        Player {
            stats: generate_stats(seed),
            kiosk: object::uid_to_inner(kiosk),
            // ...
        }
    }

    // === Reads ===

    /// Get the stats of the player.
    public fun stats(self: &Player): &Stats {
        &self.stats
    }

    /// Get the kiosk of the player.
    public fun kiosk(self: &Player): ID {
        self.kiosk
    }

    // === Internal ===

    /// Generate stats based on a seed; currently just a dummy-something to
    /// make sure we can assemble the game.
    fun generate_stats(seed: vector<u8>): Stats {
        // let level = *vector::borrow(&seed, 8) % 10;
        // let level = if (level == 0) { 1 } else { level };
        let level = 10;
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
