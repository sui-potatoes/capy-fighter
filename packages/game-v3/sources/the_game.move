// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The Game Extension and the interface.
///
/// Unlike most of the applications that we usually create this game tries a new
/// approach where all of the functions are `entry`, and all of the dependencies
/// can be replaced at any moment in any package upgrade.
///
/// The game does not aim to be compatible nor composable and instead focuses on
/// the simplicity of the interface and the ability to upgrade the internals
/// without worrying about the compatibility.
module game::the_game {
    use std::option;
    use sui::bcs;
    use sui::clock::Clock;
    use sui::bag::{Self, Bag};
    use sui::dynamic_field as df;
    use sui::kiosk_extension as ext;
    use sui::object::{Self, UID};
    use sui::transfer::{Self, Receiving};
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};

    use pokemon::stats;

    //
    use game::battle;
    use game::pool::{Self, Pool};
    use game::arena::{Self, Arena};
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
    /// The user is trying to create a new player, but the type is invalid.
    const EInvalidUserType: u64 = 5;
    /// There's no arena when trying to join.
    const ENoArena: u64 = 6;
    /// Emitted when the game is over.
    const EGameOver: u64 = 7;
    /// For when the user is not invited to this Host.
    const ENotInvited: u64 = 20;
    /// The user is trying to play, but the player is banned.
    const EPlayerIsBanned: u64 = 6;
    /// The user is trying to join, but the invite is not for them.
    const EWeDontKnowYou: u64 = 9;
    /// The user is trying to play, but the version is not supported (or legacy).
    const EInvalidVersion: u64 = 10;

    // === The main object ===

    #[allow(unused_field)]
    /// The game object is the central piece of application which currently acts
    /// as the data source for matchmaking and the version gating mechanism.
    struct TheGame has key {
        id: UID,
        /// The version tracker to keep compatibility. Not used in the V1,
        /// however will potentially be utilized in the future.
        version: u16,
    }

    // === Dynamic Field Keys ===

    /// The Dynamic Field Key for the Player.
    struct PlayerKey has store, copy, drop {}

    /// The Dynamic Field Key for an active Match in the Arena. Whenever present
    /// it either points to a Kiosk that has a match running or stores an actual
    /// Match in the P1 Kiosk.
    ///
    /// A `MatchKey` means inability to start another game nor withdraw without
    /// being punished for abandoning the match.
    ///
    /// The value stored under the `MatchKey` is an `Arena` or an `ID`.
    struct MatchKey has store, copy, drop {}

    /// A game invite for another player to join. By transferring this object
    /// to the other player's Kiosk, we avoid dynamic field creation and
    /// instead utilize the `transfer to object` feature.
    struct Invite has key {
        id: UID,
        kiosk: address,
    }

    /// The result of the game that is sent to the Kiosk of the guest. To
    /// continue playing they must claim the result and apply it to the Player.
    // struct Result has key {
        // id: UID,
        // kiosk: address,
        // winner: address,
    // }

    // === Extension ===

    /// The Extension Witness.
    struct Game has drop {}

    /// Currently the game requires 0 permissions. However, we might reconsider
    /// once the items / boosts / perks system is up.
    const PERMISSIONS: u128 = 2;

    /// The version of the game.
    const VERSION: u16 = 1;

    const POOL_KEY: vector<u8> = b"pool";

    /// Install the game in the user Kiosk; a necessary step to allow all the
    /// other operations in the game.
    entry fun install(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        ext::add(Game {}, kiosk, cap, PERMISSIONS, ctx)
    }

    /// Initialize the game.
    fun init(ctx: &mut TxContext) {
        let id = object::new(ctx);

        df::add(&mut id, POOL_KEY, pool::new(ctx));
        transfer::share_object(TheGame { id, version: VERSION });
    }

    // === The Game Itself ===

    // The Game features description:
    //
    // - [+] install a game
    // - [+] create a new player (drop a player) // currently there can be only 1P
    // - [+] search for a game
    // - [+] play the game
    // - calculate the results
    // - update Player ratings
    // - repeat

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

        // TODO: better randomness
        let moves = battle::starter_moves(type);
        let rand_source = bcs::to_bytes(&tx_context::fresh_object_address(ctx));
        let player = player::new(type, moves, rand_source, ctx);

        bag::add(storage_mut(kiosk), PlayerKey {}, player)
    }

    // === Matchmaking ===

    /// Search for a match, if found - host the game and send an invite to
    /// another player.
    entry fun play(
        game: &mut TheGame,
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(game.version == VERSION, EInvalidVersion);
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);

        let (my_id, level, tolerance) = order(kiosk);
        let pool_mut = pool_mut(game);

        pool::submit_order(pool_mut, my_id, level, tolerance);

        let match = pool::find_match(pool_mut, my_id, level, tolerance);
        if (option::is_none(&match)) {
            // bool would mean that we're waiting for a match
            bag::add(storage_mut(kiosk), MatchKey {}, false);
            return
        };

        // the other player matched with us
        let match = option::destroy_some(match);
        let (arena, player) = (arena::new(), player(kiosk));

        assert!(!player::is_banned(player), EPlayerIsBanned);

        // be nice and leave a note for the other player
        send_an_invite(my_id, match, ctx);

        arena::join(
            &mut arena,
            *player::stats(player),
            player::moves(player),
            my_id
        );

        // lastly, attach the Arena to another player's Kiosk
        bag::add(storage_mut(kiosk), MatchKey {}, arena)
    }

    /// To join a Game the invited party needs to show an invite. To do so, the
    /// transfer-to-object (TTO) argument needs to be supplied as well as both
    /// kiosks (invitee and the host).
    entry fun join(
        my_kiosk: &mut Kiosk,
        my_kiosk_cap: &KioskOwnerCap,
        other_kiosk: &mut Kiosk,

        // the transfer-to-object argument
        invite: Receiving<Invite>,
        _ctx: &mut TxContext
    ) {
        let my_id = id(my_kiosk);
        let destination = take_a_note(my_kiosk, my_kiosk_cap, invite);
        assert!(destination == id(other_kiosk), EWeDontKnowYou);

        // so now we are "playing", we know where the other Kiosk is
        let my_storage = storage_mut(my_kiosk);
        let is_waiting = bag::contains_with_type<MatchKey, address>(my_storage, MatchKey {});

        assert!(is_waiting, ENotInvited);
        assert!(has_arena(other_kiosk), ENoArena);

        bag::remove<MatchKey, bool>(my_storage, MatchKey {});
        bag::add(my_storage, MatchKey {}, destination);

        let player = player(my_kiosk);
        let stats = *player::stats(player);
        let moves = player::moves(player);
        let arena = arena_mut(other_kiosk);

        arena::join(arena, stats, moves, my_id);
    }

    /// Commit a Player's move in the Arena.
    ///
    /// Arguments:
    /// - `host_kiosk` - the Kiosk that is hosting the game (P1)
    /// - `cap` - the cap representing the user (for host - host's, for
    /// invitee - invitee's)
    /// ...
    ///
    /// Aborts if:
    /// - there's no arena in the host
    /// - the player is not in the arena
    /// - the game is over
    /// - (arena) if the player already committed
    /// - (arena) if the round is not over yet
    entry fun commit(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap, // KOC is for the invitee's Kiosk or the host's
        commitment: vector<u8>,
        _clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);

        let arena = arena_mut(host_kiosk);
        let player_id = object::id_to_address(&kiosk::kiosk_owner_cap_for(cap));

        assert!(arena::has_player(arena, player_id), EWeDontKnowYou);
        assert!(!arena::is_game_over(arena), EGameOver);

        arena::commit(arena, player_id, commitment)
    }

    /// Reveal the committed move of the Player in the Arena.
    ///
    /// Arguments:
    /// - `host_kiosk` - the Kiosk that is hosting the game (P1)
    /// - `cap` - the cap representing the user (for host - host's, for
    /// invitee - invitee's)
    /// ...
    ///
    /// Aborts if:
    /// - there's no arena in the host
    /// - the player is not in the arena
    /// - the game is over
    /// - (arena) if the player already revealed
    /// - (arena) if the round is not over yet
    entry fun reveal(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        move_: u8,
        salt: vector<u8>,
        _clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);

        let arena = arena_mut(host_kiosk);
        let player_id = object::id_to_address(&kiosk::kiosk_owner_cap_for(cap));

        assert!(arena::has_player(arena, player_id), EWeDontKnowYou);
        assert!(!arena::is_game_over(arena), EGameOver);

        // TODO: pass the rng_seed to the Arena
        arena::reveal(arena, player_id, move_, salt, vector[ 0 ]);

        let _is_over = arena::is_game_over(arena);

        // TODO: there needs to be a wrap up / assignment function for when the
        // game is over. both players will have to claim the results.
    }

    /// Destroy the arena, apply results of the Game and send them to the guest
    /// player to claim.
    entry fun wrapup(
        host_kiosk: &mut Kiosk,
        host_cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);
        assert!(kiosk::has_access(host_kiosk, host_cap), ENotOwner);

        // we made sure that the caller is the host, now what do we do

        let arena = arena_mut(host_kiosk);

        assert!(arena::is_game_over(arena), EGameOver);

        let winner_id = arena::winner(arena);
        if (winner_id == id(host_kiosk)) {
            apply_results(host_kiosk, true, 0)
        } else {
            apply_results(host_kiosk, false, 0)
        };
    }

    // === Internal: Results ===

    /// Apply the results of the game to the Player.
    fun apply_results(kiosk: &mut Kiosk, has_won: bool, p2_level: u8) {
        // let player_mut = player_mut(kiosk);
        // let my_level = stats::level(player::stats(player_mut));
        // let level_diff = math::max(my_level as u64, p2_level as u64)
        //     - math::min(my_level as u64, p2_level as u64);

        // if (has_won) {

        // }
    }

    // what does it mean to win? when the host can claim and destruct
    // the match the host gets the rebate;

    // === Internal Reads ===

    /// Check if the Kiosk has a player.
    fun has_player(kiosk: &Kiosk): bool {
        ext::is_installed<Game>(kiosk)
            && bag::contains(ext::storage(Game {}, kiosk), PlayerKey {})
    }

    /// Check whether the player is currently playing.
    /// Aborts if there is no player.
    fun is_playing(kiosk: &Kiosk): bool {
        assert!(has_player(kiosk), ENoPlayer);
        bag::contains(ext::storage(Game {}, kiosk), MatchKey {})
    }

    // === Internal Storage: The Game ===

    /// Get the mutable reference to the Pool of active orders.
    ///
    /// Note: while usually it would be considered a weak practice to use non-
    /// custom keys, we're utilizing the upgradeability of the inline primitives
    /// in case the data structure changes.
    fun pool_mut(the_game: &mut TheGame): &mut Pool {
        df::borrow_mut(&mut the_game.id, POOL_KEY)
    }

    // === Internal Storage: Kiosk ===

    #[allow(unused_function)]
    fun storage(kiosk: &Kiosk): &Bag {
        ext::storage(Game {}, kiosk)
    }

    fun storage_mut(kiosk: &mut Kiosk): &mut Bag {
        ext::storage_mut(Game {}, kiosk)
    }

    /// Check whether this Kiosk has an Arena and therefore is the Host.
    fun has_arena(kiosk: &Kiosk): bool {
        bag::contains_with_type<MatchKey, Arena>(
            ext::storage(Game {}, kiosk),
            MatchKey {}
        )
    }

    /// Get a mutable reference to the Arena.
    /// Does not perform a check of existance, can abort when misused.
    fun arena_mut(kiosk: &mut Kiosk): &mut Arena {
        bag::borrow_mut(ext::storage_mut(Game {}, kiosk), MatchKey {})
    }

    /// Leave a note to another player saying:
    /// "Hey buddy, the game has started, I'm waiting for you in the `to`"
    ///
    /// Note: similar to `pool_mut` this function utilizes top level DF storage
    /// without custom keys for upgradeability.
    fun send_an_invite(from: address, to: address, ctx: &mut TxContext) {
        transfer::transfer(Invite {
            id: object::new(ctx),
            kiosk: from
        }, to);
    }

    /// Check the address of the player who left a note for you. This is the way
    /// to discover the match that has already started and expecting you.
    fun take_a_note(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        invite: Receiving<Invite>
    ): address {
        let Invite { id, kiosk } = sui::transfer::receive(
            kiosk::uid_mut_as_owner(kiosk, cap),
            invite
        );

        object::delete(id);
        kiosk
    }

    /// Get a reference to the `Player` struct stored in the Extension.
    fun player(kiosk: &Kiosk): &Player {
        bag::borrow(ext::storage(Game {}, kiosk), PlayerKey {})
    }

    #[allow(unused_function)]
    /// Get a mutable reference to the `Player` struct stored in the Extension.
    fun player_mut(kiosk: &mut Kiosk): &mut Player {
        bag::borrow_mut(ext::storage_mut(Game {}, kiosk), PlayerKey {})
    }

    /// Prepare the data to place an order for the current player.
    fun order(kiosk: &Kiosk): (address, u8, u8) {
        (
            object::id_to_address(&object::id(kiosk)),
            stats::level(player::stats(player(kiosk))),
            0
        )
    }

    /// The libs operate on just IDs, this function helps get them faster-better
    fun id(kiosk: &Kiosk): address {
        object::id_to_address(&object::id(kiosk))
    }

    // === Test-only functions ===

    #[test_only]
    public fun new_game_for_testing(ctx: &mut TxContext): TheGame {
        TheGame {
            id: object::new(ctx),
            version: VERSION
        }
    }

    #[test_only]
    public fun burn_game_for_testing(game: TheGame) {
        let TheGame { version: _, id } = game;
        object::delete(id)
    }

    #[test_only]
    public fun install_for_testing(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        install(kiosk, cap, ctx)
    }

    #[test_only]
    public fun new_player_for_testing(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        type: u8,
        ctx: &mut TxContext
    ) {
        new_player(kiosk, cap, type, ctx)
    }

    #[test_only]
    public fun play_for_testing(
        game: &mut TheGame,
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        play(game, kiosk, cap, ctx)
    }

    #[test_only]
    public fun join_for_testing(
        my_kiosk: &mut Kiosk,
        my_kiosk_cap: &KioskOwnerCap,
        other_kiosk: &mut Kiosk,
        invite: Receiving<Invite>,
        ctx: &mut TxContext
    ) {
        join(my_kiosk, my_kiosk_cap, other_kiosk, invite, ctx)
    }

    #[test_only]
    public fun commit_for_testing(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        commitment: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        commit(host_kiosk, cap, commitment, clock, ctx)
    }

    #[test_only]
    public fun reveal_for_testing(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        move_: u8,
        salt: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        reveal(host_kiosk, cap, move_, salt, clock, ctx)
    }

    #[test_only]
    public fun wrapup_for_testing(
        host_kiosk: &mut Kiosk,
        host_cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        wrapup(host_kiosk, host_cap, ctx)
    }

    #[test_only]
    public fun get_invite_for_testing(
        kiosk: address, ctx: &mut TxContext
    ): Invite {
        Invite {
            id: object::new(ctx),
            kiosk: kiosk
        }
    }
}
