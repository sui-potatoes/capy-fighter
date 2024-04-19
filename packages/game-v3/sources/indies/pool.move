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
    /// The current orders pool.
    public struct Pool has key, store {
        id: UID,
        orders: vector<Order>,
    }

    /// Represents a single order in the pool.
    public struct Order has store, drop {
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
    ): Order {
        let order = Order { id, tolerance, value };
        self.orders.push_back(order);
        Order { id, tolerance, value } // "copy" the order
    }

    /// Revoke an already placed order.
    public fun revoke_order(self: &mut Pool, order: Order) {
        let (is_found, idx) = self.orders.index_of(&order);
        if (is_found) {
            self.orders.remove(idx);
        }
    }

    /// Find a match in a Pool with given parameters.
    ///
    /// The `seed` parameter is used to randomize the search, the source must be
    /// non-deterministic to prevent front-running attacks.
    public fun find_match(
        self: &mut Pool,
        order: &Order,
        seed: vector<u8>,
    ): Option<address> {
        let (is_found, idx) = self.orders.index_of(order);
        if (!is_found || self.orders.length() < 2) {
            return option::none()
        };

        let mut matches = vector[];
        let _player = self.orders.remove(idx);
        let (mut i, len) = (0, self.orders.length());

        while (i < len) {
            let search = &self.orders[i];
            let match_cond = (
                search.value == order.value ||
                search.value <= (order.value + order.tolerance) ||
                order.value >= (search.value + search.tolerance)
            );

            if (match_cond) {
                matches.push_back(i)
            };

            i = i + 1;
        };

        // exit early if there are no games to match with
        if (matches.length() == 0) {
            return option::none()
        };

        // if we have multiple matches, we need to pick one
        // we use first 4 bytes of the seed with 4 zero bytes to get a
        // random number as bcs::peel_u64() requires 8 bytes
        let hash = sui::hash::blake2b256(&seed);
        let rnd = sui::bcs::new(vector[
            hash[0], hash[1], hash[2], hash[3],
            0, 0, 0, 0
        ]).peel_u64();

        let idx = rnd % matches.length();
        let game = self.orders.remove(matches[idx]);
        option::some(game.id)
    }

    // === Getters ===

    /// Public getter for the `id` of the Order.
    public fun id(self: &Order): address { self.id }

    /// Public getter for the size of the Pool.
    public fun size(self: &Pool): u64 { self.orders.length() }
}
