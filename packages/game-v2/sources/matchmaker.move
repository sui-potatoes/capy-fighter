// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::matchmaker {
    use std::option::{Self, Option};

    use sui::tx_context::{fresh_object_address, TxContext};
    use sui::kiosk::{Self, KioskOwnerCap};
    use sui::object::{Self, ID, UID};
    use sui::dynamic_field as df;
    use sui::transfer;

    use game::player::{Self, Player};
    use game::arena::create_arena;

    /// For when the player is not waiting for a match.
    const ENoSearch: u64 = 0;
    /// For when player is not from this Kiosk.
    const ENotFromKiosk: u64 = 1;

    // TODO: temporary.
    friend game::the_game;

    /// The main storage for current matches.
    struct MatchPool has key, store {
        id: UID,
        request: Option<Player>
    }

    // to track the matchpool we can use effects from the publishing tx, then we
    // set the value once and for good.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(MatchPool {
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
        // kiosk: &mut Kiosk,
        player: Player,
        ctx: &mut TxContext
    ): ID {
        if (option::is_some(&self.request)) {
            let opponent = option::extract(&mut self.request);
            let match_id = df::remove(&mut self.id, player::kiosk(&opponent));
            let arena_id = create_arena(match_id, player, opponent, ctx);
            df::add(&mut self.id, match_id, arena_id);
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

    /// Cancel the search if the player is still waiting.
    public(friend) fun cancel_search(
        self: &mut MatchPool,
        cap: &KioskOwnerCap,
        _ctx: &mut TxContext
    ): Player {
        assert!(option::is_some(&self.request), ENoSearch);

        let player: Player = option::extract(&mut self.request);
        df::remove<ID, ID>(&mut self.id, player::kiosk(&player));

        assert!(player::kiosk(&player) == kiosk::kiosk_owner_cap_for(cap), ENotFromKiosk);
        player
    }

    // === Internal ===

    /// Get the rebate for removing the marker from the pool. Safe to call by
    /// anyone even if marker rebate was already claimed.
    public(friend) fun try_marker_rebate(
        self: &mut MatchPool,
        match_id: ID,
    ) {
        if (df::exists_(&self.id, match_id)) {
            let _: ID = df::remove(&mut self.id, match_id);
        }
    }

    /// Util: generate a new unique ID for a match (to listen to).
    fun new_id(ctx: &mut TxContext): ID {
        object::id_from_address(fresh_object_address(ctx))
    }
}

// / The Facts:
// / - we always know the player level but we don't know their tolerance setting
// / - the Player struct can be used to perform auth
// / - when a Player is searching for a match, we need to lock the Player struct
// / so that a second order can't be submitted
// / - when an order is matched, the game needs to begin, where do we store it?
// / that's a tricky one. How do we know where the match is happening? Should it
// / be Kiosk? Well, I'd like it this way tho let's see if it's not too much.
// module game::matchmaker_v2 {
//     use sui::object::{Self, UID};
//     use game::pool::{Self, Pool};

//     /// A singleton object that stores order Pool(s).
//     struct Matchmaker has key { id: UID }

    // / Search for a match.
    // public fun search(
    //     self: &mut Matchmaker,
    //     player: Player,
    //     ctx: &mut TxContext
    // ) {
    //     // let pool = Pool::new(ctx);
    //     // pool.add(player);
    //     // object::add(&mut self.id, pool);
    // }
// }
