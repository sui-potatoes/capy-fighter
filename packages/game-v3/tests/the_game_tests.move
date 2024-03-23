// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
/// The Game Tests module
module game::the_game_tests {
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::test_utils;
    use sui::clock::{Self, Clock};
    use game::the_game::{Self as game, TheGame};

    #[test] fun test_new_character() {
        let mut test = new();
        let ctx = &mut test.next_tx(@0x1);
        let clock = test.clock(0, ctx);
        let mut game = test.new_game(ctx);
        let (mut p1, mut p2) = (test.new_player(ctx), test.new_player(ctx));

        // Install the game for the first player.
        p1.install(ctx);
        p1.new_character(ctx);
        p1.play(&mut game, ctx);

        // Install the game for the second player.
        p2.install(ctx);
        p2.new_character(ctx);
        p2.play(&mut game, ctx);

        // Host is the second player since it matches with the first order.
        let host = p2.id();

        // Join the game started by the first player.
        game::join_for_testing(
            &mut p1.kiosk, &p1.cap,
            &mut p2.kiosk, host, ctx
        );

        test.destroy(game).destroy(clock).destroy(vector[p1, p2]);
    }

    // === Player Setup ===

    public struct Player {
        kiosk: Option<Kiosk>,
        cap: Option<KioskOwnerCap>,
    }

    public fun id(self: &Player): address {
        object::id(&self.kiosk).id_to_address()
    }

    public fun install(self: &mut Player, ctx: &mut TxContext) {
        game::install(&mut self.kiosk, &self.cap, ctx);
    }

    public fun new_character(self: &mut Player, ctx: &mut TxContext) {
        game::new_character(&mut self.kiosk, &self.cap, 0, ctx);
    }

    public fun play(self: &mut Player, game: &mut TheGame, ctx: &mut TxContext) {
        game.play(&mut self.kiosk, &self.cap, ctx);
    }

    public fun commit(
        self: &mut Player,
        cap: &KioskOwnerCap,
        move_: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let mut commitment = vector[ move_ ];
        commitment.append(b"salt");
        let commitment = sui::hash::blake2b256(&commitment);

        game::commit(&mut self.kiosk, cap, commitment, clock, ctx);
    }

    public fun reveal(
        self: &mut Player,
        cap: &KioskOwnerCap,
        move_: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        game::reveal(&mut self.kiosk, cap, move_, b"salt", clock, ctx);
    }

    public fun wrapup(self: &mut Player, ctx: &mut TxContext) {
        game::wrapup(&mut self.kiosk, &self.cap, ctx);
    }


    // === Test Runner ===

    /// A test runner to generate transactions.
    public struct TestRunner has drop {
        seq: u64,
    }

    /// Creates a new test runner to generate transactions.
    public fun new(): TestRunner {
        TestRunner { seq: 1 }
    }

    /// Creates a new player.
    public fun new_player(_: &TestRunner, ctx: &mut TxContext): Player {
        let (kiosk, cap) = kiosk::new(ctx);
        Player { kiosk, cap }
    }

    /// Returns the clock with the given time.
    public fun clock(_self: &TestRunner, time: u64, ctx: &mut TxContext): Clock {
        let mut clock = clock::create_for_testing(ctx);
        clock.set_for_testing(time);
        clock
    }

    /// Creates a new game.
    // public fun game(self: &mut TestRunner): &mut TheGame { &mut self.game }
    public fun new_game(_self: &TestRunner, ctx: &mut TxContext): TheGame {
        game::new_game_for_testing(ctx)
    }

    /// Destroys any object.
    public fun destroy<T>(self: &TestRunner, v: T): &TestRunner {
        test_utils::destroy(v);
        self
    }

    /// Creates a new transaction with the given sender. Make sure to keep the
    /// sequence number unique for each transaction.
    public fun next_tx(self: &mut TestRunner, sender: address): TxContext {
        self.seq = self.seq + 1;
        tx_context::new_from_hint(
            sender,
            self.seq,
            0, 0, 0
        )
    }
}
