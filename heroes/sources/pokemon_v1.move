// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module heroes::pokemon_v1 {

    /// The RANDOM parameter must be between 217 and 255 (inclusive).
    const EIncorrectRandomValue: u64 = 0;

    /// The scaling factor for operations.
    const SCALING: u8 = 256;

    /// The stats of a Pokemon (basically, a structured collection of u8 values)
    /// Can be created using the `new` function.
    struct Stats has store, drop {
        hp: u8,
        attack: u8,
        defense: u8,
        special_attack: u8,
        special_defense: u8,
        speed: u8,
        level: u8,
    }

    public fun physicalDamage(
        attacker: &Stats,
        defender: &Stats,
        move_power: u8,
        random: u8
    ): u8 {
        assert!(random >= 217 && random <= 255, EIncorrectRandomValue);

        let lvl_mod = 2 * attacker.

    }


    /// Create a new instance of Stats with the given values. It simplifies the
    /// calculation by wrapping the values in a struct.
    public fun new(
        hp: u8,
        attack: u8,
        defense: u8,
        special_attack: u8,
        special_defense: u8,
        speed: u8,
        level: u8
    ): Stats {
        Stats {
            hp,
            attack,
            defense,
            special_attack,
            special_defense,
            speed,
        }
    }
}
