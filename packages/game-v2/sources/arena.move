// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::arena {
    use std::option::{Self, Option};

    use sui::tx_context::TxContext;
    use sui::object::{Self, ID, UID};
    use sui::transfer;

    use game::player::{Self, Player};
    use pokemon::stats::{Stats};

    /// The Arena where the game is played.
    struct Arena has key {
        id: UID,
        p1: Option<ActivePlayer>,
        p2: Option<ActivePlayer>,
    }

    /// Currently active player (wraps the Player struct).
    struct ActivePlayer has store, drop {
        /// The stats of the Player's Pokemon.
        stats: Stats,
        /// Player's Kiosk ID.
        account: ID,
        /// Stores the hashed move.
        next_attack: Option<vector<u8>>,
        /// Helps track the round. So that a second reveal can be performed
        /// without rushing into async execution.
        next_round: u8,
        /// Store the original value of the player.
        player: Player
    }

    /// Create the arena and share it with the players.
    public fun create_arena(p1: Player, p2: Player, ctx: &mut TxContext): ID {
        let id = object::new(ctx);
        let arena_id = object::uid_to_inner(&id);

        transfer::share_object(Arena {
            id,
            p1: add_player(p1),
            p2: add_player(p2),
        });

        arena_id
    }

    /// Internal function to read the data from the `Player` struct and prepare
    /// the environment for the game.
    fun add_player(player: Player): Option<ActivePlayer> {
        option::some(ActivePlayer {
            stats: *player::stats(&player),
            account: player::kiosk(&player),
            next_attack: option::none(),
            next_round: 0,
            player
        })
    }
}
