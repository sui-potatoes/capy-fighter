// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Arena module. (We should also enable spectating and maybe even replays in
// the future; could be badass given that all data on chain is stored).
// module heroes::arena {
//     use std::option::{Self, Option};
//     use sui::object::{Self, UID};
//     use sui::tx_context::TxContext;
//     use suifrens::suifrens::{Self as sf, SuiFren as SF};
//     use suifrens::capy::Capy;

//     /// A single arena where a competition is held.
//     struct Arena has key {
//         id: UID,

//         player_one: Option<SF<Capy>>,
//         player_two: Option<SF<Capy>>,

//         round: u32,
//         round_start: u64,
//         round_end: u64,

//     }

//     /// Create a new Arena for the competition.
//     public fun new(turn_timeout: u32, ctx: &mut TxContext): Arena {
//         Arena {
//             id: object::new(ctx),

//             player_one: option::none(),
//             player_two: option::none(),

//             round: 0,
//             round_start: 0,
//             round_end: 0,
//         }
//     }

//     /// Join the arena.
//     public fun join(arena: &mut Arena, sf: SF<Capy>) {
//         if (option::is_none(arena.player_one)) {
//             option::fill(&mut arena.player_one, sf);
//         } else if (option::is_none(arena.player_two)) {
//             option::fill(&mut arena.player_two, sf);
//         } else {
//             abort 0 // EArenaIsFull;
//         }
//     }


// }
