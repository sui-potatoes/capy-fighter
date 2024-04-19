// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// thoughts:
// - what if tolerance could be set from 1 to 5;
// - tolerance means you can play against your level or higher.
// - if you're level 1, you can play against 1-2.
// - if you're level 2, you can play against 2-4 and so on.
//
// if there's a lower ranking player who wants to play against a higher
// ranking player, it is considered a challenge and the higher ranking
// player treats it as a normal match.
//
// worst case scenario for the higher ranking player is that they lose
// and the lower ranking player gains a lot of points.
//
// but if the higher ranking player wins, they gain very few points, but
// it's very unlikely that they lose.

#[test_only]
module game::pool_tests {
    use game::pool;

    #[test]
    fun test_default_flow() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);
        let seed = x"A11CEB0B";

        let order_1 = pool.submit_order(@0x1, 1, 0);
        let order_2 = pool.submit_order(@0x2, 1, 0);
        let order_3 = pool.submit_order(@0x3, 1, 0);
        let order_4 = pool.submit_order(@0x4, 1, 0);

        // Order#1 should've matched with any of the other orders.
        // And with the given `seed` it matched with Order#3.
        let search_1 = pool.find_match(&order_1, seed);
        assert!(search_1.is_some(), 0);
        assert!(search_1.borrow() == &order_2.id(), 1);

        // Order#2 should've matched with any of the other orders.
        // And there's only Order#4 left.
        let search_3 = pool.find_match(&order_3, seed);
        assert!(search_3.is_some(), 2);
        assert!(search_3.borrow() == &order_4.id(), 3);

        pool.drop().delete()
    }

    #[test]
    // Almost identical to `test_default_flow` but with a different seed.
    fun test_default_flow_different_seed() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);
        let seed = b"some_other_seed_maybe";

        let order_1 = pool.submit_order(@0x1, 1, 0);
        let order_2 = pool.submit_order(@0x2, 1, 0);
        let order_3 = pool.submit_order(@0x3, 1, 0);
        let order_4 = pool.submit_order(@0x4, 1, 0);

        // Because the seed is different, the matching should be different.
        let search_1 = pool.find_match(&order_1, seed);
        assert!(search_1.is_some(), 0);
        assert!(search_1.borrow() == &order_3.id(), 1);

        // Check that the rest of the orders are working as expected.
        let search_2 = pool.find_match(&order_2, seed);
        assert!(search_2.is_some(), 2);
        assert!(search_2.borrow() == &order_4.id(), 3);

        pool.drop().delete()
    }

    #[test]
    fun test_cancel_order() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let order_1 = pool.submit_order(@0x1, 1, 0);
        pool.revoke_order(order_1);
        pool.drop().delete()
    }

    #[test]
    fun test_one_to_one() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let _order_1 = pool.submit_order(@0x1, 1, 0);
        let order_2 = pool.submit_order(@0x2, 1, 0);

        pool.find_match(&order_2, x"A11CEB0B");

        assert!(pool.size() == 0, 0);
        pool.drop().delete()
    }

    #[test]
    fun test_with_tolerance() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        // address, value, tolerance
        let _order_1 = pool.submit_order(@0x1, 1, 1);
        let order_2 = pool.submit_order(@0x2, 2, 0);
        let search = pool.find_match(&order_2, x"A11CEB0B");

        assert!(pool.size() == 0, 0);
        assert!(search.is_some(), 1);
        assert!(search.destroy_some() == @0x1, 2);

        pool.drop().delete()
    }

    #[test]
    fun no_matches_with_tolerance() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        // address, value, tolerance
        // Order#1 is 1 with a value 1 and tolerance of 8.
        // The rest of the orders are value 10 with tolerance 0.
        let order = pool.submit_order(@0x1, 1, 8);

        pool.submit_order(@0x2, 10, 0);
        pool.submit_order(@0x3, 10, 0);
        pool.submit_order(@0x4, 10, 0);

        let search = pool.find_match(&order, x"A11CEB0B");

        assert!(search.is_none(), 1);
        pool.drop().delete()
    }

    #[test]
    // Scenario:
    // - p1 has value + tolerance which matches with p2;
    // - p2 has value + tolerance which does not match with p1;
    fun p1_matches_p2_does_not() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let order = pool.submit_order(@0x1, 1, 8); // 1-9
        let _ = pool.submit_order(@0x2, 7, 2); // 5-9

        let search = pool.find_match(&order, x"A11CEB0B");
        assert!(search.is_some(), 0);
        pool.drop().delete()
    }
}
