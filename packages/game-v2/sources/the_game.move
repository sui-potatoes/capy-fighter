// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module game::the_game {
    use std::option::{Self, Option};

    use sui::bag;
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::kiosk_extension as ext;

    use game::player::{Self, Player};

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

    /// The Dynamic Field Key for the Player.
    struct PlayerKey has store, copy, drop {}

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
    entry fun new_player(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
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

    /// Take the player to play the game.
    public fun take_player(kiosk: &mut Kiosk, cap: &KioskOwnerCap, _ctx: &mut TxContext): Player {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);

        let player = bag::borrow_mut(ext::storage_mut(Game {}, kiosk), PlayerKey {});
        option::extract(player)
    }

    /// Return the player to the Kiosk.
    public fun return_player(kiosk: &mut Kiosk, player: Player, _ctx: &mut TxContext) {
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(is_playing(kiosk), EPlayerIsPlaying);

        let storage = ext::storage_mut(Game {}, kiosk);
        let player_storage = bag::borrow_mut(storage, PlayerKey {});

        option::fill(player_storage, player)
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

        let player = bag::borrow<PlayerKey, Option<Player>>(
            ext::storage(Game {}, kiosk),
            PlayerKey {}
        );
        
        option::is_some(player)
    }
}
