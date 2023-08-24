// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The Game is installed as an extension to the Kiosk to reuse the storage,
/// store player's assets' state and lock items when necessary for the game.
module game::the_game {
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::tx_context::TxContext;
    use sui::kiosk_extension;
    use sui::object::ID;
    use std::vector;
    use sui::bag;

    use pokemon::stats::{Self, Stats};

    use suifrens::suifrens::{Self as sf, SuiFren};
    use suifrens::capy::Capy;

    /// Trying to register a Capy that's not in the Kiosk.
    const EIncorrectCapyId: u64 = 0;
    /// Trying to access the Kiosk without being the owner.
    const ENotOwner: u64 = 1;
    /// Trying to access the game without the extension being installed.
    const EExtensionNotInstalled: u64 = 2;

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

        // Now we need to generate stats for it. We will use Capy genes as the
        // base for the stats + maybe add some randomness to it (TBD).
        let genes = sf::genes(capy);

        // To make game more engaging we can base our level off the Gen or Cohort.
        // Why not try and make it more fun this way?
        //
        // If the Gen is 0, then the level is 10.
        // If the Gen is 1, then the level is 6.
        // If the Gen is 2, then the level is 2.
        // If the Gen is 3+, then the level is 1.
        let gen = sf::generation(capy);
        let level = if (gen > 2) { 1 } else { 10 - ((gen as u8) * 4) };
        let types = vector[*vector::borrow(genes, 6) % 3]; // 0-2

        // For starters let's just take each gene and assign it to a stat.
        let stats = stats::new(
            *vector::borrow(genes, 0), // HP
            *vector::borrow(genes, 1), // Attack
            *vector::borrow(genes, 2), // Defense
            *vector::borrow(genes, 3), // Special Attack
            *vector::borrow(genes, 4), // Special Defense
            *vector::borrow(genes, 5), // Speed
            level,                     // Level
            types,                     // A single type of a Capy (represented as a vector)
        );

        // Now where do we want to store the stats? Well, for starters, we could
        // store them in the Extension. That would simplify things but won't
        // allow trading Capys with their stats inherited just yet. The game state
        // will be "per Kiosk" and reset when a Capy is leaving Kiosk (however old
        // stats will stay here...). We'll figure it out.
        let ext_storage_mut = kiosk_extension::storage_mut(Extension {}, self);
        bag::add(ext_storage_mut, capy_id, stats);

        // Now that we added the stats into the Extension, we're good to go. The
        // battle can happen between two Kiosks without the need to access the
        // stored assets (users are free to mutate, dress etc). It's not a problem
        // right now as we're heading towards an MVP, but we'll need to figure
        // out how to lock assets when the battle is happening and attach stats
        // to Capys in the Kiosk.
    }

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
            assert!((hp_before - 19) == hp_after, 0);
        };

        {
            let stats_two = (copy stats_two);
            let hp_before = (stats::hp(&stats_two) / stats::scaling());
            battle::attack(&stats_one, &mut stats_two, 1, 240, false);
            let hp_after = (stats::hp(&stats_two) / stats::scaling());
            assert!((hp_before - hp_after) == 10, 0);
        };

        {
            let stats_two = (copy stats_two);
            let hp_before = (stats::hp(&stats_two) / stats::scaling());
            battle::attack(&stats_one, &mut stats_two, 2, 240, false);
            let hp_after = (stats::hp(&stats_two) / stats::scaling());
            std::debug::print(&vector[ hp_before, hp_after ]);
            assert!((hp_before - hp_after) == 18, 0);
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
