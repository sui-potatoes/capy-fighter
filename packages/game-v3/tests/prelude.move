// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
/// This module contains the necessary functions required to test the game and
/// make testing as simple as possible.
module game::prelude {
    use sui::kiosk_test_utils::{Self as test};
    use sui::kiosk::{Kiosk, KioskOwnerCap};
    use sui::tx_context::{Self, TxContext};

    // use game::the_game;

    /// Returns a dummy TxContext.
    public fun ctx(): TxContext {
        tx_context::dummy()
    }

    /// Returns a new Kiosk with the game installed.
    public fun get_kiosk(ctx: &mut TxContext): (Kiosk, KioskOwnerCap) {
        let (kiosk, kiosk_cap) = test::get_kiosk(ctx);

        // the_game::install_for_testing(&mut kiosk, &kiosk_cap, ctx);

        (kiosk, kiosk_cap)
    }

    /// Returns and wraps up the Kiosk.
    public fun return_kiosk(kiosk: Kiosk, cap: KioskOwnerCap, ctx: &mut TxContext) {
        test::return_kiosk(kiosk, cap, ctx);
    }
}
