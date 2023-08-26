// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module multi::tictaktoe {
    use sui::tx_context::{sender, TxContext};
    use sui::object::{Self, UID};

    const X: u8 = 1;
    const O: u8 = 2;

    /// A simple field - a matrix of X by Y bytes where each of the two players
    /// can move; however,
    struct Field has key {
        id: UID,
        data: vector<vector<u8>>,
    }

    fun init(ctx: &mut TxContext) {
        sui::transfer::share_object(Field {
            id: object::new(ctx),
            data: vector[
                vector[ 0, 0, 0 ],
                vector[ 0, 0, 0 ],
                vector[ 0, 0, 0 ],
            ],
        })
    }
}
