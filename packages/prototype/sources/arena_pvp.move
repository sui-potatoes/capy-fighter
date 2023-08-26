// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Arena module.
module prototype::arena_pvp {
    use std::vector;
    use std::option::{Self, Option};

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::bcs;

    use pokemon::stats::{Self, Stats};
    use prototype::battle;

    /// Trying to perform an action while still searching for P2;
    const EArenaNotReady: u64 = 0;
    /// Trying to perform an action while the arena is over;
    const EArenaOver: u64 = 1;
    /// Can't do next round if P1 hasn't submitted their move;
    const EPlayerOneNotReady: u64 = 2;
    /// Can't do next round if P2 hasn't submitted their move;
    const EPlayerTwoNotReady: u64 = 3;
    /// Trying to attack while Move is already there.
    const EMoveAlreadySubmitted: u64 = 4;
    /// Not a Player.
    const EUnknownSender: u64 = 5;

    struct Player has store, drop {
        stats: Stats,
        account: address,
        next_attack: Option<u8>,
    }

    struct Arena has key {
        id: UID,
        seed: vector<u8>,
        round: u8,
        /// Player1 is the one starting the Arena - so we alway have them.
        player_one: Player,
        /// Player2 is the one joining the Arena - so initally we don't have
        /// them. But they're free to join any time. As soon as they joined
        /// the battle can begin.
        player_two: Option<Player>,

        is_over: bool
    }

    struct ArenaCreated has copy, drop { arena: address }
    struct PlayerJoined has copy, drop { arena: address }
    struct PlayerHit    has copy, drop { arena: address }

    /// Create and share a new arena.
    entry fun new(ctx: &mut TxContext) {
        transfer::share_object(new_(ctx));
    }

    /// Join an existing arena and start the battle.
    entry fun join(arena: &mut Arena, ctx: &mut TxContext) {
        option::fill(&mut arena.player_two, Player {
            stats: generate_stats(derive(arena.seed, 1)),
            account: tx_context::sender(ctx),
            next_attack: option::none()
        });

        sui::event::emit(PlayerJoined {
            arena: object::uid_to_address(&arena.id)
        });
    }

    /// Attack the other player.
    entry fun attack(arena: &mut Arena, _move: u8, ctx: &mut TxContext) {
        assert!(!arena.is_over, EArenaOver);
        assert!(option::is_some(&arena.player_two), EArenaNotReady);

        let player = tx_context::sender(ctx);

        // If it's a P1 attack
        if (player == arena.player_one.account) {
            assert!(option::is_none(&arena.player_one.next_attack), EMoveAlreadySubmitted);
            arena.player_one.next_attack = option::some(_move);
        } else if (player == option::borrow(&arena.player_two).account) {
            let p2 = option::borrow_mut(&mut arena.player_two);
            assert!(option::is_none(&p2.next_attack), EMoveAlreadySubmitted);
            p2.next_attack = option::some(_move);
        } else {
            abort EUnknownSender // we don't know who you are
        };

        sui::event::emit(PlayerHit {
            arena: object::uid_to_address(&arena.id)
        });
    }

    /// Perform a round of the battle.
    entry fun round(arena: &mut Arena, _ctx: &mut TxContext) {
        assert!(option::is_some(&arena.player_two), EArenaNotReady);
        assert!(!arena.is_over, EArenaOver);

        let player1_rng = hit_rng(arena.seed, 3, arena.round);
        let player2_rng = hit_rng(arena.seed, 4, arena.round);

        let p1 = &mut arena.player_one;
        let p2 = option::borrow_mut(&mut arena.player_two);

        assert!(option::is_some(&p1.next_attack), EPlayerOneNotReady);
        assert!(option::is_some(&p2.next_attack), EPlayerTwoNotReady);

        let _move = *option::borrow(&p1.next_attack);
        battle::attack(
            &p1.stats, &mut p2.stats, (_move as u64), player1_rng, false
        );

        let _move = *option::borrow(&p2.next_attack);
        battle::attack(
            &p2.stats, &mut p1.stats, (_move as u64), player2_rng, false
        );

        p1.next_attack = option::none();
        p2.next_attack = option::none();

        let is_over = (stats::hp(&p1.stats) == 0) || (stats::hp(&p2.stats) == 0);

        arena.is_over = is_over;
        arena.round = arena.round + 1;
    }

    fun generate_stats(seed: vector<u8>): Stats {
        let level = *vector::borrow(&seed, 8) % 10;
        let level = if (level == 0) { 1 } else { level };
        stats::new(
            10 + smooth(*vector::borrow(&seed, 0)),
            smooth(*vector::borrow(&seed, 1)),
            smooth(*vector::borrow(&seed, 2)),
            smooth(*vector::borrow(&seed, 3)),
            smooth(*vector::borrow(&seed, 4)),
            smooth(*vector::borrow(&seed, 5)),
            level,
            vector[ *vector::borrow(&seed, 6) % 3 ]
        )
    }

    fun hit_rng(seed: vector<u8>, path: u8, round: u8): u8 {
        let value = *vector::borrow(&derive(seed, path), (round as u64));
        ((value % (255 - 217)) + 217)
    }

    fun smooth(value: u8): u8 {
        let value = ((value % 60) + 60) / 2;
        if (value == 0) {
            10
        } else {
            value
        }
    }

    fun derive(seed: vector<u8>, path: u8): vector<u8> {
        vector::push_back(&mut seed, path);
        sui::hash::blake2b256(&seed)
    }

    fun new_(ctx: &mut TxContext): Arena {
        let addr = tx_context::fresh_object_address(ctx);
        let seed = sui::hash::blake2b256(&bcs::to_bytes(&addr));
        let id = object::new(ctx);

        // Generate stats for player and bot.

        let player_stats = generate_stats(derive(seed, 0));

        // Emit events and share the Arena

        let player_one = Player {
            stats: player_stats,
            account: tx_context::sender(ctx),
            next_attack: option::none()
        };

        let player_two = option::none();

        sui::event::emit(ArenaCreated {
            arena: object::uid_to_address(&id)
        });

        Arena {
            id, seed, player_one, player_two, round: 0, is_over: false
        }
    }

    #[test_only] use sui::test_scenario as ts;
    #[test_only] const ALICE: address = @0x1;
    #[test_only] const BOB: address = @0x2;

    #[test] fun test_new_and_attack() {
        let scenario = ts::begin(ALICE);
        let test = &mut scenario;

        // Alice creates a new arena.
        ts::next_tx(test, ALICE); {
            new(ts::ctx(test));
        };

        // Bob joins the arena.
        ts::next_tx(test, BOB); {
            let arena = ts::take_shared<Arena>(test);
            join(&mut arena, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Alice attacks.
        ts::next_tx(test, ALICE); {
            let arena = ts::take_shared<Arena>(test);
            attack(&mut arena, 0, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Bob attacks.
        ts::next_tx(test, BOB); {
            let arena = ts::take_shared<Arena>(test);
            attack(&mut arena, 1, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Bob calculates the round.
        ts::next_tx(test, BOB); {
            let arena = ts::take_shared<Arena>(test);
            round(&mut arena, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Bob attacks
        ts::next_tx(test, BOB); {
            let arena = ts::take_shared<Arena>(test);
            attack(&mut arena, 2, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Alice attacks
        ts::next_tx(test, ALICE); {
            let arena = ts::take_shared<Arena>(test);
            attack(&mut arena, 1, ts::ctx(test));
            ts::return_shared(arena);
        };

        // Alice calculates the round.
        ts::next_tx(test, ALICE); {
            let arena = ts::take_shared<Arena>(test);
            round(&mut arena, ts::ctx(test));
            ts::return_shared(arena);
        };

        ts::end(scenario);
    }
}
