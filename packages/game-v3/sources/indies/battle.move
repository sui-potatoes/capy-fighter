// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The battle engine for the game.
/// Contains Moves, their power, makes sure that the HP is decreased correctly.
///
/// Types (indexed): Water (0), Fire (1), Earth (2), Air (3);
/// Moves (indexed): Hydro Pump (0), Aqua Tail (1), Inferno (2), Flamethrower (3),
///                  Quake Strike (4), Earthquake (5), Gust (6), Air Slash (7).
module game::battle {
    use std::vector;

    use pokemon::pokemon_v1 as pokemon;
    use pokemon::stats::{Self, Stats};

    /// Trying to use a non-existent Move (only use 0, 1, 2).
    const EWrongMove: u64 = 0;

    /// Total number of Moves.
    const TOTAL_MOVES: u64 = 8;

    /// The starter moves for each of the 4 types.
    /// There's only 4 types for now, and 8 moves total.
    const STARTER_MOVES: vector<vector<u8>> = vector[
        vector[ 0, 1, 6, 2 ],
        vector[ 2, 3, 0, 4 ],
        vector[ 4, 5, 2, 6 ],
        vector[ 6, 7, 4, 0 ],
    ];

    const MOVES_SPECIAL: vector<bool> = vector[
        false, true, // Hydro Pump // Aqua Tail
        false, true, // Inferno // Flamethrower
        false, true, // Quake Strike // Earthquake
        false, true, // Gust // Air Slash
    ];

    const MOVES_TYPES: vector<u8> = vector[
        0, 0, // Water
        1, 1, // Fire
        2, 2, // Earth
        3, 3, // Air
    ];

    /// Starting with 3 Moves (and corresponding types). Each Capy can choose
    /// to attack with one of these Moves.
    const MOVES_POWER: vector<u8> = vector[
        90, // Hydro Pump (Water)
        85, // Aqua Tail (Water)
        85, // Inferno (Fire)
        90, // Flamethrower (Fire)
        80, // Quake Strike (Earth)
        85, // Earthquake (Earth)
        75, // Gust (Air),
        80, // Air Slash (Air)
    ];

    /// The map of effectiveness of Moves against types. The first index is the
    /// type of the Move, the second index is the type of the Capy this Move is
    /// used against.
    const MOVES_EFFECTIVENESS: vector<vector<u64>> = vector[
        // Water is effective against Fire (index 1), Earth (index 2),
        // Air (index 3), and neutral against Water (index 0).
        vector[10, 20, 5, 10],
        // Fire is effective against Air (index 3), Water (index 0),
        // Fire (index 1), and neutral against Earth (index 2).
        vector[5, 10, 20, 10],
        // Earth is effective against Water (index 0), Air (index 3),
        // Fire (index 1), and neutral against Earth (index 2).
        vector[20, 5, 10, 10],
        // Air is effective against Earth (index 2), Fire (index 1),
        // Water (index 0), and neutral against Air (index 3).
        vector[10, 5, 10, 20]
    ];

    /// Same type attack bonus. Requires division by `EFF_SCALING` when used.
    const STAB_BONUS: u64 = 15;

    /// This is the scaling for effectiveness and type bonus. Both are in range
    /// 0-2, so we need to scale them to 0-20 to apply in the uint calculations.
    const EFF_SCALING: u64 = 10;

    /// It magically wraps the HP decreasing.
    ///
    /// Returns: (damage, effectiveness, is_stab)
    ///
    /// TODO: add crit chance + move accuracy
    public fun attack(
        attacker: &Stats, defender: &mut Stats, move_: u64, rng: u8
    ): (u64, u64, bool) {
        assert!(move_ < TOTAL_MOVES, EWrongMove);

        let move_type = *vector::borrow(&MOVES_TYPES, move_);
        let move_power = *vector::borrow(&MOVES_POWER, move_);
        let is_special = *vector::borrow(&MOVES_SPECIAL, move_);

        // Currently Capys only have 1 type. Pokemons can have up to 2 types.
        let attacker_type = (*vector::borrow(&stats::types(attacker), 0) as u64);
        let defender_type = (*vector::borrow(&stats::types(defender), 0) as u64);

        // Calculate the raw damage.
        let raw_damage = if (is_special) {
            pokemon::special_damage(attacker, defender, move_power, rng)
        } else {
            pokemon::physical_damage(attacker, defender, move_power, rng)
        };

        // Get the effectiveness table for this specifc Move, then look up
        // defender's type in the table by index. That would be the TYPE1
        // modifier.
        let move_effectiveness = *vector::borrow(&MOVES_EFFECTIVENESS, (move_type as u64));
        let effectiveness = *vector::borrow(&move_effectiveness, defender_type);

        // Effectiveness of a move against the type is calculated as:
        raw_damage = raw_damage * effectiveness / EFF_SCALING;

        // Same type attack bonus = STAB - adds 50% to the damage.
        if (move_ == attacker_type) {
            raw_damage = raw_damage * STAB_BONUS / EFF_SCALING;
        };

        // now apply the damage to the defender (can get to 0, safe operation)
        stats::decrease_hp(defender, raw_damage);

        (raw_damage, effectiveness, move_ == attacker_type)
    }

    /// Returns the set of starter moves for the given type.
    public fun starter_moves(type: u8): vector<u8> {
        assert!(type < 4, EWrongMove);
        *vector::borrow(&STARTER_MOVES, (type as u64))
    }
}
