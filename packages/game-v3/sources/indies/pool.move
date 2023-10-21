// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Trying to keep this module agnostic to the game logic.
// So that we can tune the matching algorithm without changes to the game.

/// A better version of the matchmaking engine which takes the player value and
/// tolerance into account. This version would allow us to match players based
/// on their skill value.
///
/// Given that the computation is performed on vectors it is cheap in terms of
/// gas but quite costly in terms of CPU, however we never ran any benchmarks to
/// find a balance between computation and storage costs. The actual results are
/// yet to be seen...
///
/// Logic:
/// - player submits a request to the Pool stating their value and tolerance
/// - another player submits a request to the Pool as well
/// - at some point any of them can run the "match" function to perform the
///  actual matching
module game::pool {
    use std::vector;
    use std::option::{Self, Option};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    /// The current orders pool.
    struct Pool has key, store {
        id: UID,
        orders: vector<Order>,
    }

    /// Represents a single order in the pool.
    struct Order has store, drop {
        id: address,
        value: u8,
        tolerance: u8,
    }

    /// Create a new Pool.
    public fun new(ctx: &mut TxContext): Pool {
        Pool {
            id: object::new(ctx),
            orders: vector[]
        }
    }

    /// Drop the Pool. I don't want to call it "burn" eye'nae it's an NFT
    /// something but "burning a pool"... c'mon
    public fun drop(self: Pool): UID {
        let Pool { id, orders: _ } = self;
        id // hehe; proof of deletion!
    }

    /// Submit a single order. An attempt to match
    public fun submit_order(
        self: &mut Pool,
        id: address,
        value: u8,
        tolerance: u8,
    ) {
        let order = Order { id, tolerance, value };
        vector::push_back(&mut self.orders, order);
    }

    /// Find a match in a Pool with given parameters.
    public fun find_match(
        self: &mut Pool,
        id: address,
        value: u8,
        tolerance: u8,
    ): Option<address> {
        let orders = &mut self.orders;
        let (i, len) = (0, vector::length(orders));

        if (len < 2) {
            return option::none()
        };

        let (is_found, idx) = vector::index_of(orders, &Order {
            id, value, tolerance
        });

        if (!is_found) {
            return option::none()
        };

        let match = option::none();

        while (i < len) {
            let order = vector::borrow(orders, i);
            let exit_cond = &order.id != &id
                && order.value == value
                && option::is_none(&match);

            if (exit_cond) {
                option::fill(&mut match, i);
                break
            };

            i = i + 1;
        };

        if (option::is_none(&match)) {
            return option::none()
        };

        // first we need to remove the player from the pool
        let match = option::extract(&mut match);
        let match = if (match > idx) {
            let match = vector::remove(orders, match);
            let _player = vector::remove(orders, idx);
            match
        } else {
            let _player = vector::remove(orders, match);
            vector::remove(orders, idx)
        };

        option::some(match.id)
    }

    // === Getters ===

    /// Public getter for the size of the Pool.
    public fun size(self: &Pool): u64 { vector::length(&self.orders) }

    // === Testing ===

    #[test]
    fun test_default_flow() {
        let ctx = &mut sui::tx_context::dummy();
        let pool = Pool { id: object::new(ctx), orders: vector[] };

        submit_order(&mut pool, @0x1, 1, 0);
        submit_order(&mut pool, @0x2, 1, 0);
        submit_order(&mut pool, @0x3, 1, 0);
        submit_order(&mut pool, @0x4, 1, 0);

        find_match(&mut pool, @0x1, 1, 0);
        assert!(size(&pool) == 2, 0);

        find_match(&mut pool, @0x3, 1, 0);
        assert!(size(&pool) == 0, 0);

        let Pool { id, orders: _ } = pool;

        object::delete(id)
    }
}
