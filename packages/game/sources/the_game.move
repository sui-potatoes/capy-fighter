// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The Game is installed as an extension to the Kiosk to reuse the storage,
/// store player's assets' state and lock items when necessary for the game.
///
/// Game is not diving to much into the implementation and instead is using the
/// primitives defined throughout the application to implement business logic.
/// Think of it as the main interface and a router for the application.
module game::the_game {
    // use std::option::{Self, Option};

    use sui::kiosk::{Self, Kiosk, PurchaseCap, KioskOwnerCap};
    use sui::tx_context::TxContext;
    use sui::object::{Self, ID};
    use sui::kiosk_extension;
    use sui::bag;

    use suifrens::suifrens::SuiFren;
    use suifrens::capy::Capy;
    use pokemon::stats::Stats;

    use matchmaker::matchmaker::{Self as match, Order, Match};
    use game::capy_stats;

    /// Trying to register a Capy that's not in the Kiosk.
    const EIncorrectCapyId: u64 = 0;
    /// Trying to access the Kiosk without being the owner.
    const ENotOwner: u64 = 1;
    /// Trying to access the game without the extension being installed.
    const EExtensionNotInstalled: u64 = 2;
    /// Trying to accept the battle in a wrong Kiosk.
    const EWrongKiosk: u64 = 3;

    /// The BattleOrder is a currently open battle that is being played. Can only
    /// be resolved by the matchmaking application (and canceled). Once the
    /// Matchmaking module finds the right opponent, it will start the battle.
    struct BattleOrder has store {
        /// The PurchaseCap that is used to lock the Capy (not for sale).
        purchase_cap: PurchaseCap<SuiFren<Capy>>,
        /// The ID of the Capy that is participating in the battle.
        capy_id: ID,
        /// The stats of the Capy.
        stats: Stats,
        // The opponent's Kiosk address.
        // opponent: Option<address>
    }

    /// Dynamic field for the current battle. There can be only 1 battle at a time.
    struct Battle has store, copy, drop {}

    /// One Time Witness for the game.
    struct THE_GAME has drop {}

    // === Setting Up Extension ===

    /// The Extension Witness.
    struct Extension has drop {}

    /// Currently the game requires 0 permissions. However, we might reconsider
    /// once the items / boosts / perks system is up.
    const PERMISSIONS: u128 = 0;

    /// Add an extension to the Kiosk.
    public fun add(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
        kiosk_extension::add(Extension {}, kiosk, cap, PERMISSIONS, ctx)
    }

    // === Module Initializer ===

    /// For the matchmaking to work we need to create an instance of the
    /// Matchmaker, so the battle orders can be placed and matched.
    fun init(otw: THE_GAME, ctx: &mut TxContext) {
        sui::package::claim_and_keep(otw, ctx);
        sui::transfer::public_share_object(
            match::create_matchmaker(Extension {}, ctx)
        );
    }

    // === The Game Logic: Register Capy ===

    /// If a Capy is not registered or has no stats, we need to register it, so
    /// the stats are assigned and the Capy has its starting state.
    ///
    /// Because Capy is already stored in the Kiosk, we must access it through it.
    public fun register_capy(
        self: &mut Kiosk, cap: &KioskOwnerCap, capy_id: ID, _ctx: &mut TxContext
    ) {
        assert!(kiosk_extension::is_installed<Extension>(self), EExtensionNotInstalled);
        assert!(kiosk::has_item(self, capy_id), EIncorrectCapyId);
        assert!(kiosk::has_access(self, cap), ENotOwner);

        // We can borrow Capy because we're not in a PTB environment.
        let capy = kiosk::borrow<SuiFren<Capy>>(self, cap, capy_id);
        let stats = capy_stats::new(capy);

        let ext_storage_mut = kiosk_extension::storage_mut(Extension {}, self);
        bag::add(ext_storage_mut, capy_id, stats);
    }

    // === Matchmaking ===

    /// Put a Capy for a battle.
    public fun search_match(
        self: &mut Kiosk, cap: &KioskOwnerCap, capy_id: ID, ctx: &mut TxContext
    ): Order {
        // To lock a Capy we "purchase it" with a `PurchaseCap`. We don't intend
        // to sell the Capy - never. It's just a way to lock it for the duration
        // of the battle.
        let stats = *stats(self, capy_id);
        let purchase_cap = kiosk::list_with_purchase_cap(self, cap, capy_id, 0, ctx);
        let ext_storage_mut = kiosk_extension::storage_mut(Extension {}, self);

        bag::add(ext_storage_mut, Battle {}, BattleOrder {
            purchase_cap,
            capy_id,
            stats
        });

        match::new_order(Extension {}, object::id_to_address(&object::id(self)))
    }

    /// We don't really want to have the battle happening somewhere else, game
    /// extension seems ideal for the purpose. So we need to figure out how to
    /// bring another user's Kiosk and its BattleOrder here.
    public fun start_battle(
        self: &mut Kiosk, match: Match
    ) {
        let kiosk = match::start_match(Extension {}, match);
        assert!(object::id_to_address(&object::id(self)) == kiosk, EWrongKiosk);

        // What do we do now?
        // How does the battle work?
    }

    /// The battle is over, we can remove the BattleOrder.
    /// There needs to be some authorization here; that the battle is over.
    /// Note: Every authorization scheme is the way to version an application.
    public fun end_battle(self: &mut Kiosk, cap: &KioskOwnerCap) {
        assert!(kiosk::has_access(self, cap), ENotOwner);

        let ext_storage_mut = kiosk_extension::storage_mut(Extension {}, self);
        let BattleOrder {
            purchase_cap,
            capy_id,
            stats: _
        } = bag::remove(ext_storage_mut, Battle {});

        // Just to remember that stats are currently in the Kiosk Extension.
        let _stats = bag::borrow_mut<ID, Stats>(ext_storage_mut, capy_id);

        // Some XP calculation is happening somewhere. If we ever decide to make
        // the Stats permanent and not per Kiosk.
        let _capy_mut = kiosk::borrow_mut<SuiFren<Capy>>(self, cap, capy_id);


        // Unlock the Capy so it is now free! Yay!
        kiosk::return_purchase_cap(self, purchase_cap);
    }

    // === The Actual Battle ===

    // How is it happening? Can we delegate? Where is it stored?

    // === Getters ===

    /// Get the stats for a Capy; allows reading and using.
    public fun stats(self: &Kiosk, capy_id: ID): &Stats {
        let ext_storage = kiosk_extension::storage(Extension {}, self);
        bag::borrow(ext_storage, capy_id)
    }
}

#[test_only]
module game::the_game_tests {
    use sui::object::{Self, ID};
    use sui::tx_context::TxContext;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    // there's a handy module in sui framework
    use sui::kiosk_test_utils as kiosk_test;

    use suifrens::suifrens as sf;
    use suifrens::capy::Capy;

    use pokemon::stats;
    use game::the_game;
    use game::battle;

    // With preparation done, we can now write some tests.
    // Phew, there's a lot to keep in mind while writing these...
    #[test] fun test_capy_registration() {
        let ctx = &mut kiosk_test::ctx();
        let (kiosk, kiosk_cap, capy_id) = prepare_kiosk_with_capy(ctx);

        // install the game
        the_game::add(&mut kiosk, &kiosk_cap, ctx);

        // register the Capy; this should work
        the_game::register_capy(&mut kiosk, &kiosk_cap, capy_id, ctx);

        // now let's check that the stats are there
        let _stats = the_game::stats(&kiosk, capy_id);

        return_kiosk_with_capy(kiosk, kiosk_cap, capy_id);
    }

    #[test] fun test_capy_battle() {
        let ctx = &mut kiosk_test::ctx();
        let (kiosk_one, kiosk_cap_one, capy_id_one) = prepare_kiosk_with_capy(ctx);
        let (kiosk_two, kiosk_cap_two, capy_id_two) = prepare_kiosk_with_capy(ctx);

        // install the game to both of the Kiosks
        the_game::add(&mut kiosk_one, &kiosk_cap_one, ctx);
        the_game::add(&mut kiosk_two, &kiosk_cap_two, ctx);

        // register Capys and assign their stats
        the_game::register_capy(&mut kiosk_one, &kiosk_cap_one, capy_id_one, ctx);
        the_game::register_capy(&mut kiosk_two, &kiosk_cap_two, capy_id_two, ctx);

        // while we could focus on modifying the state in the Kiosk Extension
        // we can also just use the stats directly. It's not a problem right now.
        //
        // Using derefence operator to `copy` stats from the reference.
        let stats_one = *the_game::stats(&kiosk_one, capy_id_one);
        let stats_two = *the_game::stats(&kiosk_two, capy_id_two);

        // to check our guess, let's do a comparison
        assert!(stats::types(&stats_one) == vector[ 1 ], 0);
        assert!(stats::types(&stats_two) == vector[ 2 ], 1);

        // let's try different moves - this one is the most effective - 19 points
        // that means that the attacking Capy got a modifier of 2x for same type hit.
        {
            let stats_two = (copy stats_two);
            let hp_before = (stats::hp(&stats_two) / stats::scaling());
            battle::attack(&stats_one, &mut stats_two, 0, 240, false);
            let hp_after = (stats::hp(&stats_two) / stats::scaling());
            assert!((hp_before - 22) == hp_after, 0);
        };

        {
            let stats_two = (copy stats_two);
            let hp_before = (stats::hp(&stats_two) / stats::scaling());
            battle::attack(&stats_one, &mut stats_two, 1, 240, false);
            let hp_after = (stats::hp(&stats_two) / stats::scaling());
            assert!((hp_before - hp_after) == 12, 0);
        };

        {
            let stats_two = (copy stats_two);
            let hp_before = (stats::hp(&stats_two) / stats::scaling());
            battle::attack(&stats_one, &mut stats_two, 2, 240, false);
            let hp_after = (stats::hp(&stats_two) / stats::scaling());
            assert!((hp_before - hp_after) == 20, 0);
        };

        return_kiosk_with_capy(kiosk_one, kiosk_cap_one, capy_id_one);
        return_kiosk_with_capy(kiosk_two, kiosk_cap_two, capy_id_two);
    }

    // We won't cover all of the error cases just yet - the focus is to move forward
    // and implement a prototype; the errors are clear:
    // - Capy is not in a Kiosk
    // - Kiosk is not owned by the Kiosk owner
    // - The Game not installed
    // - The Capy is not registered and we try to read stats
    // ...all of these should be covered, but later.

    /// This function will help us prepare a Kiosk with a Capy in it. So that
    /// two users can battle each other; and the fun part is that we don't need
    /// their direct consent to do so just yet.
    ///
    /// We return Kiosk, KioskOwnerCap and the Capy ID (handy in tests!)
    fun prepare_kiosk_with_capy(ctx: &mut TxContext): (Kiosk, KioskOwnerCap, ID) {
        let (kiosk, kiosk_cap) = kiosk_test::get_kiosk(ctx);
        let capy = sf::mint_for_testing<Capy>(ctx); // get a Capy!
        let capy_id = object::id(&capy);

        kiosk::place(&mut kiosk, &kiosk_cap, capy);

        (kiosk, kiosk_cap, capy_id)
    }

    /// A wrap-up function to remove the Capy, burn it and then destroy Kiosk.
    fun return_kiosk_with_capy(kiosk: Kiosk, cap: KioskOwnerCap, capy_id: ID) {
        let capy = kiosk::take(&mut kiosk, &cap, capy_id);
        sf::burn_for_testing<Capy>(capy);
        kiosk_test::return_kiosk(kiosk, cap, &mut kiosk_test::ctx());
    }
}
