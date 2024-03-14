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

        // Install the game for the first player.
        test.p1().install(ctx);
        test.p1().new_character(ctx);
        test.p1().play(&mut game, ctx);

        // Install the game for the second player.
        test.p2().install(ctx);
        test.p2().new_character(ctx);
        test.p2().play(&mut game, ctx);

        // Host is the second player since it matches with the first order.
        let host = test.p2().id();
        let (p1, p2) = test.players();

        // Join the game started by the first player.
        game::join_for_testing(
            &mut p1.kiosk, &p1.cap,
            &mut p2.kiosk, host, ctx
        );

        // p1.commit(&p1.cap, 1, &clock, ctx);
        // p2.commit(&p2.cap, 2, &clock, ctx);

        // Play the game. (TODO: commit happens in the host kiosk, using the other player's cap)
        // test.p1().commit(1, &clock, ctx);
        // test.p2().commit(2, &clock, ctx);

        // test.p1().reveal(1, &clock, ctx);
        // test.p2().reveal(2, &clock, ctx);

        test.destroy(game).destroy(clock);
        test.drop();
    }

    // === Player Setup ===

    public struct Player {
        kiosk: Kiosk,
        cap: KioskOwnerCap,
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
    public struct TestRunner {
        seq: u64,
        p1: Player,
        p2: Player,
    }

    /// Creates a new test runner to generate transactions.
    public fun new(): TestRunner {

        let ctx = &mut tx_context::new_from_hint(@0x0, 0, 0, 0, 0);
        let (kiosk_1, cap_1) = kiosk::new(ctx);
        let (kiosk_2, cap_2) = kiosk::new(ctx);

        TestRunner {
            seq: 1,
            p1: Player { kiosk: kiosk_1, cap: cap_1 },
            p2: Player { kiosk: kiosk_2, cap: cap_2 },
        }
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

    public fun p1(self: &mut TestRunner): &mut Player { &mut self.p1 }
    public fun p2(self: &mut TestRunner): &mut Player { &mut self.p2 }
    public fun players(self: &mut TestRunner): (&mut Player, &mut Player) {
        (&mut self.p1, &mut self.p2)
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

    public fun drop(self: TestRunner) {
        let TestRunner {
            seq: _,
            p1: Player {
                kiosk: kiosk_1,
                cap: cap_1,
            },
            p2: Player {
                kiosk: kiosk_2,
                cap: cap_2
            }
        } = self;

        test_utils::destroy(kiosk_1);
        test_utils::destroy(cap_1);
        test_utils::destroy(kiosk_2);
        test_utils::destroy(cap_2);
    }
}
