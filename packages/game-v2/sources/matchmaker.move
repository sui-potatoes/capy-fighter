// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::matchmaker {
    use std::option::{Self, Option};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::dynamic_field as df;

    use game::player::{Self, Player};
    use game::arena::create_arena;

    /// The main storage for current matches.
    struct MatchPool has key, store {
        id: UID,
        request: Option<Player>
    }

    /// A unique identifier for a match.
    // struct MatchID has copy, store, drop { id: ID }

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
    public fun find_or_create_match(
        self: &mut MatchPool,
        player: Player,
        ctx: &mut TxContext
    ) {
        if (option::is_some(&self.request)) {
            let opponent = option::extract(&mut self.request);
            let marker_id = player::kiosk(&opponent);
            let arena_id = create_arena(player, opponent, ctx);

            *df::borrow_mut(&mut self.id, marker_id) = arena_id;
        } else {
            df::add(&mut self.id, player::kiosk(&player), 0);
            option::fill(&mut self.request, player);
        }
    }

    // fun new_id(ctx: &mut TxContext): ID {
    //     object::id_from_address(fresh_object_address(ctx))
    // }
}
