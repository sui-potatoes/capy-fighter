// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The battle engine for the game.
/// Contains Moves, their power, makes sure that the HP is decreased correctly.
module game::battle {
    use std::vector;

    use pokemon::pokemon_v1 as pokemon;
    use pokemon::stats::{Self, Stats};

    /// Trying to use a non-existent Move (only use 0, 1, 2).
    const EWrongMove: u64 = 0;

    /// Total number of Moves.
    const TOTAL_MOVES: u64 = 4;

    /// Starting with 3 Moves (and corresponding types). Each Capy can choose
    /// to attack with one of these Moves.
    const MOVES_POWER: vector<u8> = vector[
        90, // Hydro Pump (Water)
        85, // Inferno (Fire)
        80, // Quake Strike (Earth)
        75, // Gust (Air)
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

    // TODO: remove once debug is over
    use std::string::utf8;

    /// It magically wraps the HP decreasing.
    public fun attack(
        attacker: &Stats, defender: &mut Stats, _move: u64, rng: u8, debug: bool
    ) {
        assert!(_move < 3, EWrongMove);

        // Currently Capys only have 1 type. Pokemons can have up to 2 types.
        let attacker_type = (*vector::borrow(&stats::types(attacker), 0) as u64);
        let defender_type = (*vector::borrow(&stats::types(defender), 0) as u64);

        let move_power = *vector::borrow(&MOVES_POWER, _move);
        let raw_damage = pokemon::physical_damage(
            attacker,
            defender,
            move_power,
            rng
        );

        // Get the effectiveness table for this specifc Move, then look up defender's
        // type in the table by index. That would be the TYPE1 modifier.
        let move_effectiveness = *vector::borrow(&MOVES_EFFECTIVENESS, _move);
        let effectiveness = *vector::borrow(&move_effectiveness, defender_type);

        // TODO: remove in the future.
        if (debug) {
            std::debug::print(&utf8(b"Defender type, effectiveness, original damage, new damage"));
            std::debug::print(&vector[
                defender_type,
                effectiveness,
                raw_damage / 1_000_000_000,
                (raw_damage * effectiveness / EFF_SCALING / 1_000_000_000)
            ]);
        };

        // Effectiveness of a move against the type is calculated as:
        raw_damage = raw_damage * effectiveness / EFF_SCALING;

        if (debug) {
            std::debug::print(&utf8(b"Attacker type and move"));
            std::debug::print(&vector[attacker_type, _move]);
        };

        // Same type attack bonus = STAB - adds 50% to the damage.
        if (_move == attacker_type) {
            if (debug) std::debug::print(&utf8(b"Same type attack bonus!"));
            raw_damage = raw_damage * STAB_BONUS / EFF_SCALING;
        };

        // Now apply the damage to the defender (can get to 0, safe operation)
        stats::decrease_hp(defender, raw_damage);
    }
}
