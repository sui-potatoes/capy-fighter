// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::the_game {
    use std::option;

    use sui::bag;
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::kiosk_extension as ext;

    use game::player;
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

    // === Dynamic Field Keys ===

    /// The Dynamic Field Key for the Player.
    struct PlayerKey has store, copy, drop {}

    /// The Dynamic Field Key for the Match.
    struct MatchKey has store, copy, drop {}

    // === Extension ===

    /// The Extension Witness.
    struct Game has drop {}

    /// Currently the game requires 0 permissions. However, we might reconsider
    /// once the items / boosts / perks system is up.
    const PERMISSIONS: u128 = 2;

    /// Add an extension to the Kiosk.
    entry fun add(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
        ext::add(Game {}, kiosk, cap, PERMISSIONS, ctx)
    }

    // === The Game Itself ===

    /// Currently there can be only one player!
    entry fun new_player(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);

        // very rough pseudo random seed generator
        let rand_source = sui::bcs::to_bytes(&tx_context::fresh_object_address(ctx));
        let player = player::new(kiosk::uid(kiosk), rand_source, ctx);
        let storage = ext::storage_mut(Game {}, kiosk);

        assert!(!bag::contains(storage, PlayerKey {}), EPlayerAlreadyExists);

        bag::add(
            storage,
            PlayerKey {},
            option::some(player)
        );
    }

    /// Play the game by finding or creating a match.
    /// The Match ID will be stored in the Extension storage.
    entry fun play(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        matches: &mut MatchPool,
        ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);

        let storage = ext::storage_mut(Game {}, kiosk);
        let player = option::extract(bag::borrow_mut(storage, PlayerKey {}));
        let match_id = matchmaker::find_or_create_match(matches, player, ctx);

        bag::add(storage, MatchKey {}, match_id);
    }

    // entry fun finish_match(
    //     kiosk: &mut Kiosk,
    //     cap: &KioskOwnerCap,

    // )

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
