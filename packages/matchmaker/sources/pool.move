// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module defines the pool of active orders. Each order is placed into a
/// bucket based on the level of the participating Capy. A new submission is
/// either matched against existing orders and a match is created or it is
/// placed into the pool. The pool is then periodically scanned for matches by
/// new orders.
module matchmaker::pool {
    use std::vector;
    use sui::tx_context::{sender, TxContext};
    use sui::dynamic_field as df;
    use sui::object::{Self, UID, ID};

    use pokemon::stats::{Self, Stats};

    /// The pool of active orders.
    struct Pool has key {
        id: UID
    }

    /// A single order placed into the pool. We don't need to store Capy's level
    /// because it is stored in the key of the pool.
    struct Order has store, drop {
        capy_id: ID,
        player: address
    }

    // In the module initializer we create the pool and populate it with empty
    // vectors for each level (0-99).
    fun init(ctx: &mut TxContext) {
        let pool = Pool { id: object::new(ctx) };
        let (i, len) = (0, 100);
        while (i < len) {
            df::add<u8, vector<Order>>(&mut pool.id, i, vector[]);
            i = i + 1;
        };

        sui::transfer::share_object(pool)
    }

    /// Place an order into the pool.
    public fun place_order(pool: &mut Pool, capy_id: ID, stats: &Stats, ctx: &mut TxContext) {
        let level = stats::level(stats);
        let player = sender(ctx);
        let order = { capy_id, player };

        let orders = df::borrow_mut(&mut pool.id, level);
        vector::push_back(&mut orders, order);

        // This is wrong.
    }
}
