// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module pokemon::pokemon_v1 {

    /// Default scaling used for damage calculation.
    const DEFAULT_SCALING: u64 = 1_000_000_000;

    /// The RANDOM parameter must be between 217 and 255 (inclusive).
    const EIncorrectRandomValue: u64 = 0;
    /// The MOVE_POWER parameter must be greater than 0.
    const EIncorrectMovePower: u64 = 1;
    /// The scaling factor of the attacker and defender must be the same.
    // const EScalingFactorMismatch: u64 = 2;
    /// The scaling factor must be greater than 0.
    const EIncorrectScalingFactor: u64 = 3;


    /// The stats of a Pokemon (basically, a structured collection of u8 values)
    /// Can be created using the `new` function.
    struct Stats has store, drop {
        /// The HP stat of the Pokemon: scaled by 10^9.
        hp: u64,
        /// The attack stat of the Pokemon.
        attack: u8,
        /// The defense stat of the Pokemon.
        defense: u8,
        /// The special attack stat of the Pokemon.
        special_attack: u8,
        /// The special defense stat of the Pokemon.
        special_defense: u8,
        /// The speed stat of the Pokemon.
        speed: u8,
        /// The level of the Pokemon (0-100)
        level: u8,
    }

    /// Returns damage scaled by the given scaling factor. This is useful for
    /// keeping more decimal places in the result if the result is intended to
    /// be used in further calculations.
    public fun physical_damage(
        attacker: &Stats,
        defender: &Stats,
        move_power: u8,
        random: u8,
    ): u64 {
        // assert!(attacker.scaling == defender.scaling, EIncorrectScalingFactor);
        assert!(random >= 217 && random <= 255, EIncorrectRandomValue);
        assert!(move_power > 0, EIncorrectMovePower);
        // assert!(scaling > 0, EIncorrectScalingFactor);

        damage(
            (attacker.level as u64),
            (attacker.attack as u64),
            (defender.defense as u64),
            (move_power as u64),
            (random as u64),
            DEFAULT_SCALING,
        )
    }

    /// Calculate the special damage of a move.
    ///
    public fun special_damage(
        attacker: &Stats,
        defender: &Stats,
        move_power: u8,
        random: u8,
    ): u64 {
        assert!(random >= 217 && random <= 255, EIncorrectRandomValue);
        assert!(move_power > 0, EIncorrectMovePower);

        damage(
            (attacker.level as u64),
            (attacker.special_attack as u64),
            (defender.special_defense as u64),
            (move_power as u64),
            (random as u64),
            DEFAULT_SCALING,
        )
    }

    /// Calculate the damage of a move.
    /// This is the core calculation that is used by both physical and special
    /// damage calculations.
    ///
    /// TODO: missing the effectiveness calculation.
    /// TODO: missing the STAB calculation.
    /// TODO: missing the critical hit calculation.
    /// TODO: missing the accuracy calculation.
    fun damage(
        level: u64,
        attack: u64,
        defence: u64,
        move_power: u64,
        random: u64,
        scaling: u64,
    ): u64 {
        let lvl_mod = (2 * level * 1 / 5) + (2);
        let atk_def = (scaling * attack) / defence;
        let result  = (lvl_mod * move_power * atk_def / 50) + (2 * scaling);
        let rnd_val = (scaling * random) / 255;
        let eff_val = (1);

        (result * rnd_val * eff_val / scaling)
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
            hp: (hp as u64) * DEFAULT_SCALING,
            attack,
            defense,
            special_attack,
            special_defense,
            speed,
            level,
        }
    }

    // === Getters ===

    /// Return the scaling factor used for damage calculation.
    public fun default_scaling(): u64 { DEFAULT_SCALING }

    /// Return the HP stat of the given Pokemon.
    public fun hp(stat: &Stats): u64 { stat.hp }

    /// Return the attack stat of the given Pokemon.
    public fun attack(stat: &Stats): u8 { stat.attack }

    /// Return the defense stat of the given Pokemon.
    public fun defense(stat: &Stats): u8 { stat.defense }

    /// Return the special attack stat of the given Pokemon.
    public fun special_attack(stat: &Stats): u8 { stat.special_attack }

    /// Return the special defense stat of the given Pokemon.
    public fun special_defense(stat: &Stats): u8 { stat.special_defense }

    /// Return the speed stat of the given Pokemon.
    public fun speed(stat: &Stats): u8 { stat.speed }

    /// Return the level of the given Pokemon.
    public fun level(stat: &Stats): u8 { stat.level }

    // === Setters ===

    /// Set the HP stat of the given Pokemon.
    public fun decrease_hp(stat: &mut Stats, value: u64) {
        if (value > stat.hp) {
            stat.hp = 0;
        } else {
            stat.hp = stat.hp - value;
        }
    }

    /// Increase the level of the given Pokemon.
    public fun level_up(stat: &mut Stats) {
        stat.level = stat.level + 1;
    }

    // === Tests ===

    #[test]
    fun test_physical() {
        let capy_one = new(45, 49, 49, 65, 65, 45, 13);
        let capy_two = new(40, 60, 30, 31, 31, 70, 10);

        // let scaled = physical_damage_scaled(&capy_one, &capy_two, 40, 217, scaling);
        let damage = physical_damage(&capy_one, &capy_two, 40, 217);

        std::debug::print(&std::string::utf8(b"first capy damage: "));
        std::debug::print(&vector[damage, capy_two.hp, capy_two.hp - damage]);

        let damage = physical_damage(&capy_two, &capy_one, 35, 230);

        std::debug::print(&std::string::utf8(b"second capy damage: "));
        std::debug::print(&vector[damage, capy_one.hp, capy_one.hp - damage]);
    }
}
