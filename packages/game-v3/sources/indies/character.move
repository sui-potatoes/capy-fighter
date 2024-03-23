// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Character module for the game.
///
/// It is responsible for the character stats, moves, rank, experience and banning.
///
/// Provides API for:
/// - creating and initializing a new character
/// - banning and unbanning a character
/// - adding experience to a character + level up
module game::character {
    use sui::clock::{Clock};
    use pokemon::stats::{Self, Stats};

    /// The median value for stats.
    const MEDIAN: u8 = 35;
    /// The base XP for the character (to not tweak the algorithm too much).
    const BASE_XP: u64 = 250;

    /// Error code for when the character is not banned.
    const ENotBanned: u64 = 0;
    /// Error code for when the character is still banned and trying to remove ban,
    const EStillBanned: u64 = 1;

    /// A Playable Character type; for now not protected (to not overcompilate
    /// things with generics) but should be.
    public struct Character has store, drop {
        /// The Pokemon stats for the Character.
        stats: Stats,
        /// Using this field to punish the character for bad behavior. Abandoning
        /// the match or cheating will result in a ban.
        banned_until: Option<u64>,
        /// The moves of the character; max 4.
        /// Currently assigned based on the type of the character.
        moves: vector<u8>,
        /// The rank of the character; starts at 1200.
        rank: u64,
        /// The experience of the character; starts at 0.
        xp: u64,
        /// The number of wins of the character.
        wins: u64,
        /// The number of losses of the character.
        losses: u64,
    }

    /// Create a new Character.
    public fun new(
        type_: u8,
        moves: vector<u8>,
        seed: vector<u8>,
        _ctx: &mut TxContext
    ): Character {
        Character {
            moves,
            stats: generate_stats(type_, seed),
            banned_until: option::none(),
            rank: 1200,
            xp: BASE_XP,
            wins: 0,
            losses: 0,
        }
    }

    /// Ban the character for a certain amount of time;
    /// Is public and it's up to the game to decide when to ban a character.
    public fun ban(
        self: &mut Character,
        clock: &Clock,
        duration_minutes: u64,
        _ctx: &mut TxContext
    ) {
        assert!(self.banned_until.is_none(), EStillBanned);

        let banned_until = clock.timestamp_ms() + duration_minutes * 60 * 1000;
        self.banned_until.fill(banned_until);
    }

    /// Remove the ban once the time has passed; requires a manual action from
    /// the character to make it more explicit.
    public fun remove_ban(
        self: &mut Character,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(option::is_some(&self.banned_until), ENotBanned);

        let banned_until = self.banned_until.extract();
        assert!(clock.timestamp_ms() >= banned_until, ENotBanned);
    }

    /// Add experience to the character. Level up if possible.
    public fun add_xp(self: &mut Character, xp: u64) {
        self.xp = self.xp + xp;

        let mut my_level = stats::level(&self.stats);
        let mut next_level_req = level_xp_requirement(my_level + 1);

        // Level up until we can't anymore; can be more than one level.
        while (self.xp >= next_level_req) {
            self.stats.level_up();

            my_level = self.stats.level();
            next_level_req = level_xp_requirement(my_level + 1);
        };
    }

    /// Add a win to the character.
    public fun add_win(self: &mut Character) { self.wins = self.wins + 1; }

    /// Add a loss to the character.
    public fun add_loss(self: &mut Character) { self.losses = self.losses + 1; }

    // === Reads ===

    /// Get the XP of the `Character`.
    public fun xp(self: &Character): u64 { self.xp }

    /// Get the stats of the `Character`.
    public fun stats(self: &Character): &Stats { &self.stats }

    /// Get the rank of the Character.
    public fun rank(self: &Character): u64 { self.rank }

    /// Get the `moves` of the `Character`.
    public fun moves(self: &Character): vector<u8> { self.moves }

    /// Get the ban status of the `Character`.
    public fun banned_until(self: &Character): Option<u64> { self.banned_until }

    /// Check if the character is banned.
    public fun is_banned(self: &Character): bool { self.banned_until.is_some() }

    // === Utils ===

    /// How much experience a Character would get for beating a character of a certain
    /// level.
    /// Formula: =LEVEL^2 * 50 + 100
    public fun xp_for_level(_self: &Character, level: u8): u64 {
        let level = (level as u64);
        (level * level * 50) + 300
    }

    /// Calculate a requirement for the level of the character.
    /// Formula: =INT((LEVEL * 1000 / EXP )^2 / 1000)
    public fun level_xp_requirement(level: u8): u64 {
        let level = (level as u64);
        let exp = 2;
        (level * 1000 / exp) * (level * 1000 / exp) / 1000
    }

    // === Internal ===

    /// Generate stats based on a seed; currently just a dummy-something to
    /// make sure we can assemble the game.
    ///
    /// Add Level Calculation here!
    fun generate_stats(type_: u8, seed: vector<u8>): Stats {
        let level = 1;

        stats::new(
            smooth(seed[0]) + 10,
            smooth(seed[1]),
            smooth(seed[2]),
            smooth(seed[3]),
            smooth(seed[4]),
            smooth(seed[5]),
            level,
            vector[ type_ ]
        )
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
}
