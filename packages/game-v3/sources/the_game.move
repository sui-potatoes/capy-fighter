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
    use sui::bcs;
    use sui::clock::Clock;
    use sui::bag::{Self, Bag};
    use sui::dynamic_field as df;
    use sui::kiosk_extension as ext;
    use sui::transfer::Receiving;
    use sui::kiosk::{Kiosk, KioskOwnerCap};

    use pokemon::stats::Stats;

    use game::battle;
    use game::arena::{Self, Arena};
    use game::pool::{Self, Order, Pool};
    use game::character::{Self as char, Character};

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
    const ENotInvited: u64 = 8;
    /// The user is trying to play, but the player is banned.
    const EPlayerIsBanned: u64 = 9;
    /// The user is trying to join, but the invite is not for them.
    const EWeDontKnowYou: u64 = 10;
    /// The user is trying to play, but the version is not supported (or legacy).
    const EInvalidVersion: u64 = 11;
    /// Trying to cancel the search, but there's no search.
    const ENotSearching: u64 = 12;
    /// Trying to wrap up the game, but the game is not over.
    const EGameNotOver: u64 = 13;

    // === Constants ===

    /// The version of the game.
    const VERSION: u16 = 1;

    /// The key for the Pool in the Dynamic Field.
    const POOL_KEY: vector<u8> = b"pool";

    // === The main object ===

    /// The game object is the central piece of application which currently acts
    /// as the data source for matchmaking and the version gating mechanism.
    public struct TheGame has key {
        id: UID,
        /// Allows for version-gating the game.
        version: u16,
    }

    // === Dynamic Field Keys ===

    /// The Dynamic Field Key for the Player.
    public struct CharacterKey has store, copy, drop {}

    /// The Dynamic Field Key for an active Match in the Arena. Whenever present
    /// it either points to a Kiosk that has a match running or stores an actual
    /// Match in the P1 Kiosk.
    ///
    /// A `MatchKey` means inability to start another game nor withdraw without
    /// being punished for abandoning the match.
    ///
    /// The value stored under the `MatchKey` is an `Arena` or an `ID`.
    public struct MatchKey has store, copy, drop {}

    // === Messages (TTO) ===

    /// A game invite for another player to join. By transferring this object
    /// to the other player's Kiosk, we avoid dynamic field creation and
    /// instead utilize the `transfer to object` feature.
    public struct Invite has key {
        id: UID,
        kiosk: address,
    }

    /// The result of the game that is sent to the guest player by the host.
    /// To continue playing they must claim the result and apply it to the
    /// Player. Sent and claimed via the `transfer to object` feature.
    public struct Result has key {
        id: UID,
        has_won: bool,
        host_kiosk: address,
        opponent_stats: Stats,
    }

    // === Extension ===

    /// The Extension Witness.
    public struct Game has drop {}

    /// Currently the game requires 0 permissions. However, we might reconsider
    /// once the items / boosts / perks system is up.
    const PERMISSIONS: u128 = 2;

    /// Install the game in the user Kiosk; a necessary step to allow all the
    /// other operations in the game.
    entry fun install(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        ext::add(Game {}, kiosk, cap, PERMISSIONS, ctx)
    }

    /// Initialize the game: share the Game singleton for searching matches and
    /// attach a Pool to it.
    fun init(ctx: &mut TxContext) {
        let mut id = object::new(ctx);

        df::add(&mut id, POOL_KEY, pool::new(ctx));
        transfer::share_object(TheGame { id, version: VERSION });
    }

    // === The Game Itself ===

    /// Currently there can be only one player!
    entry fun new_character(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        type_: u8,
        ctx: &mut TxContext
    ) {
        assert!(type_ < 4, EInvalidUserType);
        assert!(kiosk.has_access(cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(!has_character(kiosk), EPlayerAlreadyExists);

        // TODO: better randomness
        let moves = battle::starter_moves(type_);
        let rand_source = bcs::to_bytes(&ctx.fresh_object_address());
        let player = char::new(type_, moves, rand_source, ctx);

        storage_mut(kiosk).add(CharacterKey {}, player)
    }

    // === Matchmaking ===

    /// Search for a match, if found - host the game and send an invite to
    /// another player.
    entry fun play(
        game: &mut TheGame,
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(game.version == VERSION, EInvalidVersion);
        assert!(kiosk.has_access(cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_character(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);

        let (my_id, level, tolerance) = order(kiosk);
        let pool = pool_mut(game);

        let order = pool.submit_order(my_id, level, tolerance);
        let match_ = pool.find_match(&order, b"todo: random_seed");
        if (match_.is_none()) {
            storage_mut(kiosk).add(MatchKey {}, order);
            return
        };

        // the other player matched with us
        let match_ = match_.destroy_some();
        let (mut arena, player) = (arena::new(), character(kiosk));

        assert!(!player.is_banned(), EPlayerIsBanned);

        // be nice and leave a note for the other player
        send_an_invite(my_id, match_, ctx);

        arena.join(
            *player.stats(),
            player.moves(),
            my_id
        );

        // lastly, attach the Arena to another player's Kiosk
        storage_mut(kiosk).add(MatchKey {}, arena)
    }

    /// Cancel the search for a match (if a match is still not found).
    ///
    /// Gas notes:
    /// - dynamic field access + `TheGame` access can get expensive
    /// - the `Order` is destroyed along with a dynamic field, so the gas is
    /// expected to be negative
    entry fun cancel(
        game: &mut TheGame,
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        _ctx: &mut TxContext
    ) {
        assert!(game.version == VERSION, EInvalidVersion);
        assert!(kiosk.has_access(cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_character(kiosk), ENoPlayer);
        assert!(is_searching(kiosk), ENotSearching);

        let pool = pool_mut(game);
        let order = storage_mut(kiosk).remove(MatchKey {});

        pool.revoke_order(order)
    }

    /// To join a Game the invited party needs to show an invite. To do so, the
    /// transfer-to-object (TTO) argument needs to be supplied as well as both
    /// kiosks (invitee and the host).
    ///
    /// Gas notes:
    /// - the `Invite` covers the cost of joining
    /// - expected to be a negative gas operation
    entry fun join(
        my_kiosk: &mut Kiosk,
        my_kiosk_cap: &KioskOwnerCap,
        host_kiosk: &mut Kiosk,

        // the transfer-to-object argument
        invite: Receiving<Invite>,
        _ctx: &mut TxContext
    ) {
        let my_id = id(my_kiosk);
        let destination = take_a_note(my_kiosk, my_kiosk_cap, invite);

        assert!(destination == id(host_kiosk), EWeDontKnowYou);
        assert!(is_searching(my_kiosk), ENotInvited);
        assert!(has_arena(host_kiosk), ENoArena);

        // so now we are "playing", we know where the other Kiosk is
        let my_storage = storage_mut(my_kiosk);

        let _ = my_storage.remove<MatchKey, Order>(MatchKey {});
        my_storage.add(MatchKey {}, destination);

        let player = character(my_kiosk);

        arena_mut(host_kiosk).join(
            *player.stats(),
            player.moves(),
            my_id
        );
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
    ///
    /// Gas notes:
    /// - both players pay for the commit
    entry fun commit(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap, // KOC is for the invitee's Kiosk or the host's
        commitment: vector<u8>,
        _clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);

        let arena = arena_mut(host_kiosk);
        let player_id = id_from_cap(cap);

        assert!(arena.has_character(player_id), EWeDontKnowYou);
        assert!(!arena.is_game_over(), EGameOver);

        arena.commit(player_id, commitment)
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
    ///
    /// Gas notes:
    /// - both players pay for the reveal
    entry fun reveal(
        host_kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        move_: u8,
        salt: vector<u8>,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);

        let arena = arena_mut(host_kiosk);
        let player_id = id_from_cap(cap);

        assert!(arena.has_character(player_id), EWeDontKnowYou);
        assert!(!arena.is_game_over(), EGameOver);

        // TODO: pass the rng_seed to the Arena
        arena.reveal(player_id, move_, salt, vector[ 0 ]);

        // TODO: consider early exit or automatic wrap up
        let is_over = arena.is_game_over();
        if (is_over && host_kiosk.has_access(cap)) {
            wrapup(host_kiosk, cap, ctx);
        }
    }

    /// Destroy the arena, apply results of the Game and send them to the guest
    /// player to claim.
    ///
    /// Emergency scenarios (TODO):
    /// - host is not responding
    ///
    /// Gas notes:
    /// - host claims the rebate for the Arena
    /// - host pays for sending the Result object to the guest
    entry fun wrapup(
        host_kiosk: &mut Kiosk,
        host_cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(has_arena(host_kiosk), ENoArena);
        assert!(host_kiosk.has_access(host_cap), ENotOwner);

        let arena: Arena = storage_mut(host_kiosk).remove(MatchKey {});

        assert!(arena.is_game_over(), EGameNotOver);

        let winner_id = arena.winner();
        let (p1_stats, p2_stats) = arena.stats();
        let host_id = arena.p1_id();
        let guest_id = arena.p2_id();

        // applies results to the host + sends results to the guest player
        if (winner_id == id(host_kiosk)) {
            apply_results(host_kiosk, true, p2_stats);
            send_results(guest_id, host_id, false, *p1_stats, ctx);
        } else {
            apply_results(host_kiosk, false, p2_stats);
            send_results(guest_id, host_id, true, *p1_stats, ctx);
        };

        let _ = arena; // just a reminder that Arena has `drop`
    }

    /// Claim the results of the game as a guest. This is the only way to
    /// unlock the Kiosk and continue playing.
    ///
    /// Gas notes:
    /// - host has already paid for the Result object
    entry fun unlock(
        guest_kiosk: &mut Kiosk,
        guest_cap: &KioskOwnerCap,
        // the transfer-to-object argument
        result: Receiving<Result>,
        _ctx: &mut TxContext
    ) {
        assert!(guest_kiosk.has_access(guest_cap), ENotOwner);
        assert!(is_playing(guest_kiosk), EPlayerIsPlaying);

        let host_id = storage_mut(guest_kiosk).remove(MatchKey {});
        let Result {
            id,
            has_won,
            opponent_stats,
            host_kiosk
        } = sui::transfer::receive(
            guest_kiosk.uid_mut_as_owner(guest_cap),
            result
        );

        assert!(host_kiosk == host_id, EWeDontKnowYou);

        apply_results(guest_kiosk, has_won, &opponent_stats);
        id.delete()
    }

    // === Internal: Results ===

    /// Apply the results of the game to the Player.
    fun apply_results(
        kiosk: &mut Kiosk,
        has_won: bool,
        opponent_stats: &Stats
    ) {
        let char = char_mut(kiosk);
        let xp = char.xp_for_level(opponent_stats.level());

        if (has_won) {
            char.add_win();
            char.add_xp(xp);
        } else {
            char.add_loss();
            char.add_xp(xp / 5);
        }
    }

    /// Send the results of the game to the guest player. The guest player will
    /// have to claim the results to apply them to their Kiosk to continue
    /// playing the game.
    fun send_results(
        guest_kiosk: address,
        host_kiosk: address,
        has_won: bool,
        opponent_stats: Stats,
        ctx: &mut TxContext
    ) {
        transfer::transfer(Result {
            id: object::new(ctx),
            opponent_stats,
            host_kiosk,
            has_won,
        }, guest_kiosk);
    }

    // what does it mean to win? when the host can claim and destruct
    // the match the host gets the rebate;

    // === Internal Reads ===

    /// Check if the Kiosk has a player.
    fun has_character(kiosk: &Kiosk): bool {
        ext::is_installed<Game>(kiosk)
            && bag::contains(ext::storage(Game {}, kiosk), CharacterKey {})
    }

    /// Check whether the player is currently playing.
    /// Aborts if there is no player.
    fun is_playing(kiosk: &Kiosk): bool {
        assert!(has_character(kiosk), ENoPlayer);
        storage(kiosk).contains(MatchKey {})
    }

    /// Check whether the player is currently searching for a match.
    /// Aborts if there is no player.
    fun is_searching(kiosk: &Kiosk): bool {
        storage(kiosk).contains_with_type<MatchKey, Order>(MatchKey {})
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

    /// Get a reference to the Extension Storage.
    fun storage(kiosk: &Kiosk): &Bag {
        ext::storage(Game {}, kiosk)
    }

    /// Get a mutable reference to the Extension Storage.
    fun storage_mut(kiosk: &mut Kiosk): &mut Bag {
        ext::storage_mut(Game {}, kiosk)
    }

    /// Check whether this Kiosk has an Arena and therefore is the Host.
    fun has_arena(kiosk: &Kiosk): bool {
        ext::storage(Game {}, kiosk)
            .contains_with_type<MatchKey, Arena>(MatchKey {})
    }

    /// Get a mutable reference to the Arena.
    /// Does not perform a check of existance, can abort when misused.
    fun arena_mut(kiosk: &mut Kiosk): &mut Arena {
        ext::storage_mut(Game {}, kiosk).borrow_mut(MatchKey {})
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
            kiosk.uid_mut_as_owner(cap),
            invite
        );

        id.delete();
        kiosk
    }

    /// Get a reference to the `Character` struct stored in the Extension.
    fun character(kiosk: &Kiosk): &Character {
        ext::storage(Game {}, kiosk).borrow(CharacterKey {})
    }

    /// Get a mutable reference to the `Character` struct stored in the Extension.
    fun char_mut(kiosk: &mut Kiosk): &mut Character {
        ext::storage_mut(Game {}, kiosk).borrow_mut(CharacterKey {})
    }

    /// Prepare the data to place an order for the current player.
    fun order(kiosk: &Kiosk): (address, u8, u8) {
        (
            id(kiosk),
            character(kiosk).stats().level(),
            0
        )
    }

    // === Utilities ===

    /// The libs operate on just IDs, this function helps get them faster
    fun id(kiosk: &Kiosk): address {
        object::id(kiosk).id_to_address()
    }

    /// Get the address of the Kiosk from the `KioskOwnerCap`
    fun id_from_cap(cap: &KioskOwnerCap): address {
        cap.kiosk_owner_cap_for().id_to_address()
    }

    // === Testing ===

    #[test_only]
    /// Create a new game for testing purposes.
    public fun new_game_for_testing(ctx: &mut TxContext): TheGame {
        let mut id = object::new(ctx);
        df::add(&mut id, POOL_KEY, pool::new(ctx));
        TheGame { id, version: VERSION }
    }

    #[test_only]
    /// Join the game for testing purposes.
    /// Current testing infrastructure does not support TTO yet.
    public fun join_for_testing(
        my_kiosk: &mut Kiosk,
        _my_kiosk_cap: &KioskOwnerCap,
        host_kiosk: &mut Kiosk,
        destination: address,
        _ctx: &mut TxContext
    ) {
        let my_id = id(my_kiosk);

        assert!(destination == id(host_kiosk), EWeDontKnowYou);
        assert!(is_searching(my_kiosk), ENotInvited);
        assert!(has_arena(host_kiosk), ENoArena);

        // so now we are "playing", we know where the other Kiosk is
        let my_storage = storage_mut(my_kiosk);

        let _ = my_storage.remove<MatchKey, Order>(MatchKey {});
        my_storage.add(MatchKey {}, destination);

        let player = character(my_kiosk);

        arena_mut(host_kiosk).join(
            *player.stats(),
            player.moves(),
            my_id
        );
    }
}
