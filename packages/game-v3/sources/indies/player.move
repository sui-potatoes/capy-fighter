// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Player module for the game.
///
/// It is responsible for the player stats, moves, rank, experience and banning.
///
/// Provides API for:
/// - creating and initializing a new player
/// - banning and unbanning a player
/// - adding experience to a player + level up
module game::player {
    use std::vector;
    use std::option::{Self, Option};
    use sui::clock::{Self, Clock};
    use sui::tx_context::TxContext;

    use pokemon::stats::{Self, Stats};

    /// The median value for stats.
    const MEDIAN: u8 = 35;
    /// The base XP for the player (to not tweak the algorithm too much).
    const BASE_XP: u64 = 250;

    /// Error code for when the player is not banned.
    const ENotBanned: u64 = 0;
    /// Error code for when the player is still banned and trying to remove ban,
    const EStillBanned: u64 = 1;

    /// A Playable Character type; for now not protected (to not overcompilate
    /// things with generics) but should be.
    struct Player has store, drop {
        /// The Pokemon stats for the Player.
        stats: Stats,
        /// Using this field to punish the player for bad behavior. Abandoning
        /// the match or cheating will result in a ban.
        banned_until: Option<u64>,
        /// The moves of the player; max 4.
        /// Currently assigned based on the type of the player.
        moves: vector<u8>,
        /// The rank of the player; starts at 1200.
        rank: u64,
        /// The experience of the player; starts at 0.
        xp: u64,
        /// The number of wins of the player.
        wins: u64,
        /// The number of losses of the player.
        losses: u64,
    }

    /// Create a new Player.
    public fun new(
        type: u8,
        moves: vector<u8>,
        seed: vector<u8>,
        _ctx: &mut TxContext
    ): Player {
        Player {
            moves, // *vector::borrow(&STARTER_MOVES, (type as u64))
            stats: generate_stats(type, seed),
            banned_until: option::none(),
            rank: 1200,
            xp: BASE_XP,
            wins: 0,
            losses: 0,
        }
    }

    /// Ban the player for a certain amount of time;
    /// Is public and it's up to the game to decide when to ban a player.
    public fun ban_player(
        self: &mut Player,
        clock: &Clock,
        duration_minutes: u64,
        _ctx: &mut TxContext
    ) {
        assert!(option::is_none(&self.banned_until), EStillBanned);

        let banned_until = clock::timestamp_ms(clock) + duration_minutes * 60 * 1000;
        self.banned_until = option::some(banned_until);
    }

    /// Remove the ban once the time has passed; requires a manual action from
    /// the player to make it more explicit.
    public fun remove_ban(
        self: &mut Player,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(option::is_some(&self.banned_until), ENotBanned);

        let banned_until = option::extract(&mut self.banned_until);
        assert!(clock::timestamp_ms(clock) >= banned_until, ENotBanned);
    }

    /// Add experience to the player. Level up if possible.
    public fun add_xp(self: &mut Player, xp: u64) {
        self.xp = self.xp + xp;

        let my_level = stats::level(&self.stats);
        let next_level_req = level_xp_requirement(my_level + 1);

        // Level up until we can't anymore; can be more than one level.
        while (self.xp >= next_level_req) {
            stats::level_up(&mut self.stats);

            my_level = stats::level(&self.stats);
            next_level_req = level_xp_requirement(my_level + 1);
        };
    }

    /// Add a win to the player.
    public fun add_win(self: &mut Player) { self.wins = self.wins + 1; }

    /// Add a loss to the player.
    public fun add_loss(self: &mut Player) { self.losses = self.losses + 1; }

    // === Reads ===

    /// Get the stats of the `Player`.
    public fun stats(self: &Player): &Stats { &self.stats }

    /// Get the rank of the Player.
    public fun rank(self: &Player): u64 { self.rank }

    /// Get the `moves` of the `Player`.
    public fun moves(self: &Player): vector<u8> { self.moves }

    /// Get the ban status of the `Player`.
    public fun banned_until(self: &Player): Option<u64> { self.banned_until }

    /// Check if the player is banned.
    public fun is_banned(self: &Player): bool {
        option::is_some(&self.banned_until)
    }

    // === Utils ===

    /// How much experience a Player would get for beating a player of a certain
    /// level.
    /// Formula: =LEVEL^2 * 50 + 100
    public fun xp_for_level(_self: &Player, level: u8): u64 {
        let level = (level as u64);
        (level * level * 50) + 300
    }

    // === Internal ===

    /// Generate stats based on a seed; currently just a dummy-something to
    /// make sure we can assemble the game.
    ///
    /// Add Level Calculation here!
    fun generate_stats(type: u8, seed: vector<u8>): Stats {
        let level = 1;

        stats::new(
            10 + smooth(*vector::borrow(&seed, 0)),
            smooth(*vector::borrow(&seed, 1)),
            smooth(*vector::borrow(&seed, 2)),
            smooth(*vector::borrow(&seed, 3)),
            smooth(*vector::borrow(&seed, 4)),
            smooth(*vector::borrow(&seed, 5)),
            level,
            vector[ type ]
        )
    }

    /// Calculate a requirement for the level of the player.
    /// Formula: =INT((LEVEL * 1000 / EXP )^2 / 1000)
    fun level_xp_requirement(level: u8): u64 {
        let level = (level as u64);
        let exp = 2;
        (level * 1000 / exp) * (level * 1000 / exp) / 1000
    }

    /// Smoothens out the value by making it closer to median = 50.
    fun smooth(value: u8): u8 {
        let value = ((value % MEDIAN) + MEDIAN) / 2;
        if (value < 10) {
            10
        } else {
            value
        }
    }

    #[test]
    /// Test the level xp requirement.
    /// Compares the results against the formula and current setup.
    fun test_level_xp_requirement() {
        assert!(level_xp_requirement(1) == 250, 1);
        assert!(level_xp_requirement(2) == 1000, 2);
        assert!(level_xp_requirement(3) == 2250, 3);
        assert!(level_xp_requirement(4) == 4000, 4);
        assert!(level_xp_requirement(5) == 6250, 5);
        assert!(level_xp_requirement(6) == 9000, 6);
        assert!(level_xp_requirement(7) == 12250, 7);
        assert!(level_xp_requirement(8) == 16000, 8);
        assert!(level_xp_requirement(9) == 20250, 9);
    }

    #[test]
    fun test_add_xp() {
        let ctx = &mut sui::tx_context::dummy();
        let player = new(
            0,
            vector[ 0, 0, 0, 0, 0, 0 ],
            vector[ 0, 0, 0, 0, 0, 0 ],
            ctx
        );

        assert!(stats::level(stats(&player)) == 1, 1);
        assert!(player.xp == BASE_XP, 2);

        add_xp(&mut player, 1000);

        assert!(stats::level(stats(&player)) == 2, 3);
        assert!(player.xp == 1000 + BASE_XP, 4);

        add_xp(&mut player, 4000);

        assert!(stats::level(stats(&player)) == 4, 5);
        assert!(player.xp == 5000 + BASE_XP, 6);
    }
}
