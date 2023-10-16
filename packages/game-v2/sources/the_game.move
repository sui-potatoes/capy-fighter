// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Main interface for the game;
module game::the_game {
    use std::option;

    use sui::bcs;
    use sui::bag;
    use sui::object::{Self, ID};
    use sui::kiosk_extension as ext;
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};

    use game::player;
    use game::battle;
    use game::arena::{Self, Arena};
    use game::matchmaker::{Self, MatchPool};

    /// An extension is not installed and the user is trying to create a new player.
    const EExtensionNotInstalled: u64 = 0;
    /// The user is trying to create a new player, but there is already one.
    const EPlayerAlreadyExists: u64 = 1;
    /// The user is trying to take the player, but there is none.
    const ENoPlayer: u64 = 2;
    /// The user is trying to take the player, but the player is currently playing.
    const EPlayerIsPlaying: u64 = 3;
    /// The user is trying to do something, but is not the owner.
    const ENotOwner: u64 = 4;
    /// The user is trying to create a new player, but the type is invalid.
    const EInvalidUserType: u64 = 5;
    /// The user is trying to play, but the player is banned.
    const EPlayerIsBanned: u64 = 6;
    /// The user is trying to clear the arena, but the arena is not the same.
    const EWrongArena: u64 = 7;
    /// The user is trying to clear the arena, but the player is for a wrong Kiosk.
    const EWrongKiosk: u64 = 8;

    // === Dynamic Field Keys ===

    /// The Dynamic Field Key for the Player.
    struct PlayerKey has store, copy, drop {}

    /// The Dynamic Field Key for an active Match in the Arena.
    struct MatchKey has store, copy, drop {}

    // === Extension ===

    /// The Extension Witness.
    struct Game has drop {}

    /// Currently the game requires 0 permissions. However, we might reconsider
    /// once the items / boosts / perks system is up.
    const PERMISSIONS: u128 = 2;

    /// Add an extension to the Kiosk.
    public fun add(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
        ext::add(Game {}, kiosk, cap, PERMISSIONS, ctx)
    }

    // === The Game Itself ===

    /// Currently there can be only one player!
    entry fun new_player(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        type: u8,
        ctx: &mut TxContext
    ) {
        assert!(type < 4, EInvalidUserType);
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(!has_player(kiosk), EPlayerAlreadyExists);

        // very rough pseudo random seed generator
        let moves = battle::starter_moves(type);
        let rand_source = bcs::to_bytes(&tx_context::fresh_object_address(ctx));
        let player = player::new(object::id(kiosk), type, moves, rand_source, ctx);
        let storage = ext::storage_mut(Game {}, kiosk);

        bag::add(storage, PlayerKey {}, option::some(player))
    }

    // === Matchmaking ===

    #[allow(unused_variable)]
    entry fun play_v2(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        _match: &mut MatchPool, // do we even need it? hmm
    ) {
        // let storage = ext::storage_mut(Game {}, kiosk);
        // let player = option::extract(bag::borrow_mut(storage, PlayerKey {}));
        // let (id, level) = (object::id(&self), player::level(&player));

        // // tolerance is not implemented yet; only same level matching
        // pool::submit_order(&mut pool, id, level, 0);

        // // try luck with the pool and see if there is a match
        // let opponent_id = pool::find_match(&mut pool, id, level, 0);
        // if (option::is_none(opponent_id)) {
        //     return
        // };

        // if found - prepare the stage for the second player
        // we're implementing it in a way that the Arena can always be
        // replaced by a different module should we decide to upgrade
        // then we need to remove dependency from the Arena module on the
        // player struct; ha!


        // dependency graph
        // : arena ---> pokemon
        // : the_game ---> (pokemon, arena)
        // ...makes sense?

        // bag::add(
        //     storage,
        //     MatchKey {},
        //     // arena::new()
        // )



    }

    /// Play the game by finding or creating a match.
    /// The Match ID will be stored in the Extension storage.
    entry fun play(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        _matches: &mut MatchPool,
        _ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);

        let storage = ext::storage_mut(Game {}, kiosk);
        let player = option::extract(bag::borrow_mut(storage, PlayerKey {}));

        assert!(!player::is_banned(&player), EPlayerIsBanned);

        // let match_id = matchmaker::find_or_create_match(matches, player, ctx);
        // bag::add(storage, MatchKey {}, match_id)
    }

    /// Clear the arena by closing the match. Can only be performed when Arena
    /// reached the end of the game or when the game is aborted due to player
    /// disconnect / inactivity.
    ///
    /// - The Match ID will be removed from the Extension storage.
    /// - Players will be returned to their matching Kiosks.
    /// - The Match will be removed from the MatchPool.
    /// - Player stats will be updated.
    entry fun clear_arena(
        kiosk: &mut Kiosk,
        arena: &mut Arena,
        cap: &KioskOwnerCap,
        _matches: &mut MatchPool,
        _ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(is_playing(kiosk), EPlayerIsPlaying);

        let (player, _is_winner) = arena::wrap_up(arena, kiosk);
        let storage = ext::storage_mut(Game {}, kiosk);
        let match_id = bag::remove(storage, MatchKey {});

        assert!(arena::game_id(arena) == match_id, EWrongArena);
        assert!(player::kiosk(&player) == kiosk::kiosk_owner_cap_for(cap), EWrongKiosk);

        // TODO: apply level up, item drops, etc.
        // TODO: do the ELO ranking

        option::fill(bag::borrow_mut(storage, PlayerKey {}), player);

        // can't do this just yet; doesn't play well if one of the players did
        // the cleanup and the other one can't find the arena
        // matchmaker::try_marker_rebate(matches, match_id);
    }

    /// Cancel an active search if the match is not found yet.
    entry fun cancel_search(
        kiosk: &mut Kiosk,
        matches: &mut MatchPool,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(is_playing(kiosk), EPlayerIsPlaying);

        let player = matchmaker::cancel_search(matches, cap, ctx);
        let storage = ext::storage_mut(Game {}, kiosk);
        let _: ID = bag::remove(storage, MatchKey {});

        option::fill(bag::borrow_mut(storage, PlayerKey {}), player);
    }

    // === Reads ===

    /// Check if the Kiosk has a player.
    public fun has_player(kiosk: &Kiosk): bool {
        ext::is_installed<Game>(kiosk)
            && bag::contains(ext::storage(Game {}, kiosk), PlayerKey {})
    }

    /// Check whether the player is currently playing.
    /// Aborts if there is no player.
    public fun is_playing(kiosk: &Kiosk): bool {
        assert!(has_player(kiosk), ENoPlayer);
        bag::contains(ext::storage(Game {}, kiosk), MatchKey {})
    }
}
