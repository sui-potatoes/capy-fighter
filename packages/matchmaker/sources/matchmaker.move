// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Implements an Orderbook-like system to match players together.
/// We're looking for a match that matches the level and the stats of a Capy.
/// Everyone can submit their Kiosk to the matchmaker, and the matchmaker will
/// try to match them with other players.
module matchmaker::matchmaker {
    use std::vector;
    use std::type_name::{Self, TypeName};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::kiosk;

    /// Order or Match does not match the Matchmaker.
    const EIncorrectMatchmaker: u64 = 0;

    /// A Hot-Potato object which leads to a match. The opponent finds a match
    /// and delivers the Hot-Potato to the player's Kiosk therefore starting the
    /// match.
    ///
    /// There can be only one match per Kiosk happening at a time.
    struct Match { kiosk: address, type: TypeName }

    /// An open order for the battle.
    struct Order { kiosk: address, type: TypeName }

    /// For simplicity, we're making the Matchmaker an object. In the future,
    /// the system can be reworked
    struct Matchmaker has key, store {
        id: UID,
        /// The type of the Matchmaker. Keeping it a TypeName to slightly
        /// simplify the type arguments when using the prototype. The type itself
        /// serves as an authorization mechanism and a guard for Order and Match.
        type: TypeName,
        /// The list of all currently open orders
        orders: vector<address>
    }

    /// Create a new Matchmaker.
    public fun create_matchmaker<T: drop>(_w: T, ctx: &mut TxContext): Matchmaker {
        Matchmaker {
            id: object::new(ctx),
            type: type_name::get<T>(),
            orders: vector[]
        }
    }

    /// Open a new Order - must be delivered to the Matchmaker.
    public fun new_order<T: drop>(_w: T, kiosk: address): Order {
        Order { kiosk, type: type_name::get<T>() }
    }

    /// Place an order to the Matchmaker.
    public fun place_order(self: &mut Matchmaker, order: Order) {
        let Order { kiosk, type } = order;
        assert!(type == self.type, EIncorrectMatchmaker);

        // the magic of order placing happens here
        vector::push_back(&mut self.orders, kiosk)
    }

    /// Accept an order from the Matchmaker.
    public fun accept_order(self: &mut Matchmaker): Match {
        let kiosk = vector::pop_back(&mut self.orders);
        Match { kiosk, type: *&self.type }
    }

    /// Start a match.
    public fun start_match<T: drop>(_w: T, match: Match): address {
        let Match { kiosk, type } = match;
        assert!(type == type_name::get<T>(), EIncorrectMatchmaker);
        kiosk
    }
}
