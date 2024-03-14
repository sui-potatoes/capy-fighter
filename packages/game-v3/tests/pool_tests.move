// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module game::pool_tests {
    use std::option;
    use sui::tx_context;
    use sui::object;
    use game::pool;

    #[test]
    fun test_default_flow() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let order_1 = pool::submit_order(&mut pool, @0x1, 1, 0);
        let _order_2 = pool::submit_order(&mut pool, @0x2, 1, 0);
        let order_3 = pool::submit_order(&mut pool, @0x3, 1, 0);
        let _order_4 = pool::submit_order(&mut pool, @0x4, 1, 0);

        pool::find_match(&mut pool, &order_1);
        assert!(pool::size(&pool) == 2, 0);

        pool::find_match(&mut pool, &order_3);
        assert!(pool::size(&pool) == 0, 0);

        object::delete(pool::drop(pool));
    }

    #[test]
    fun test_cancel_order() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let order_1 = pool::submit_order(&mut pool, @0x1, 1, 0);
        pool::revoke_order(&mut pool, order_1);

        object::delete(pool::drop(pool));
    }

    #[test]
    fun test_one_to_one() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let _order_1 = pool::submit_order(&mut pool, @0x1, 1, 0);
        let order_2 = pool::submit_order(&mut pool, @0x2, 1, 0);

        pool::find_match(&mut pool, &order_2);

        assert!(pool::size(&pool) == 0, 0);
        object::delete(pool::drop(pool));
    }

    #[test]
    fun test_with_tolerance() {
        let ctx = &mut tx_context::dummy();
        let mut pool = pool::new(ctx);

        let _order_1 = pool::submit_order(&mut pool, @0x1, 1, 1);
        let order_2 = pool::submit_order(&mut pool, @0x2, 2, 0);
        let search = pool::find_match(&mut pool, &order_2);

        assert!(pool::size(&pool) == 0, 0);
        assert!(option::is_some(&search), 1);
        assert!(option::destroy_some(search) == @0x1, 2);

        object::delete(pool::drop(pool));
    }

    // #[test]
    // fun
}
