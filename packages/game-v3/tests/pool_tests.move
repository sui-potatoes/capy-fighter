// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module game::pool_tests {
    use sui::tx_context;
    use game::pool;

    #[test]
    fun test_default_flow() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let order_1 = pool.submit_order(@0x1, 1, 0);
        let _order_2 = pool.submit_order(@0x2, 1, 0);
        let order_3 = pool.submit_order(@0x3, 1, 0);
        let _order_4 = pool.submit_order(@0x4, 1, 0);

        pool.find_match(&order_1);
        assert!(pool.size() == 2, 0);

        pool.find_match(&order_3);
        assert!(pool.size() == 0, 0);

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

        pool.find_match(&order_2);

        assert!(pool.size() == 0, 0);
        pool.drop().delete()
    }

    #[test]
    fun test_with_tolerance() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let _order_1 = pool.submit_order(@0x1, 1, 1);
        let order_2 = pool.submit_order(@0x2, 2, 0);
        let search = pool::find_match(&mut pool, &order_2);

        assert!(pool.size() == 0, 0);
        assert!(search.is_some(), 1);
        assert!(search.destroy_some() == @0x1, 2);

        pool.drop().delete()
    }

    // #[test]
    // fun
}
