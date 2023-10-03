// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::matchmaker {
    use std::option::{Self, Option};
    use sui::tx_context::{fresh_object_address, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::dynamic_field as df;

    use game::player::{Self, Player};
    use game::arena::create_arena;

    /// The main storage for current matches.
    struct MatchPool has key, store {
        id: UID,
        request: Option<Player>
    }

    // to track the matchpool we can use effects from the publishing tx, then we
    // set the value once and for good.
    fun init(ctx: &mut TxContext) {
        sui::transfer::share_object(MatchPool {
            id: object::new(ctx),
            request: option::none(),
        });
    }

    /// A single function to find a match in the pool or join the waitline.
    /// We're expecting to have only 1 waiting player at the time because every
    /// second request will be matched with one before it.
    ///
    /// Returns a Unique ID (stays the same for both players).
    ///
    /// Notes:
    ///
    /// - Second player pays for the arena creation;
    /// - First player partially reserves gas for the second player by creating
    /// a dynamic field which is destroyed when an arena is created;
    public fun find_or_create_match(
        self: &mut MatchPool,
        player: Player,
        ctx: &mut TxContext
    ): ID {
        if (option::is_some(&self.request)) {
            let opponent = option::extract(&mut self.request);
            let match_id = df::remove(&mut self.id, player::kiosk(&opponent));
            create_arena(match_id, player, opponent, ctx);
            match_id
        } else {
            let match_id = new_id(ctx);
            df::add(&mut self.id, player::kiosk(&player), match_id);
            option::fill(&mut self.request, player);
            match_id
        }

        // Tip: we can link `match_id` and `arena_id` to be claimed when the
        // game is over; this way we can track the game state and the winner
        // without listening to any events.
    }

    // === Internal ===

    /// Util: generate a new unique ID for a match (to listen to).
    fun new_id(ctx: &mut TxContext): ID {
        object::id_from_address(fresh_object_address(ctx))
    }
}
