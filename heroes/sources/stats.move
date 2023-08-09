// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Implements a statistic calculation for the Pokemon Battle algorithm.
/// The stats in place are:
/// - HP
/// - Attack
/// - Defense
/// - Special Attack
/// - Special Defense
/// - Speed
///
/// The base stats are defined by the "class" or a "type" of species.
/// The individual values are defined by the genes of the species.
///
/// The health points are a sum of the base HP and the individual HP:
/// - HP = base HP + individual HP
///
module heroes::stats {
    use std::vector as v;
    use suifrens::suifrens::{Self as sf, SuiFren as SF};
    use suifrens::capy::Capy;

    /// The base stats of the Pokemon species (predefined in this application).
    ///
    /// In order: HP, Attack, Defense, Special Attack, Special Defense, Speed.
    /// Total: 6 stats.
    /// Total number of species: 32.
    const BASE_STATS: vector<vector<u8>> = vector[
        vector[ 45,  49,  49,  65,  65,  45 ], // Bulbasaur
        vector[ 60,  62,  63,  80,  80,  60 ], // Ivysaur
        vector[ 80,  82,  83, 100, 100,  80 ], // Venusaur
        vector[ 39,  52,  43,  60,  50,  65 ], // Charmander
        vector[ 58,  64,  58,  80,  65,  80 ], // Charmeleon
        vector[ 78,  84,  78, 109,  85, 100 ], // Charizard
        vector[ 44,  48,  65,  50,  64,  43 ], // Squirtle
        vector[ 59,  63,  80,  65,  80,  58 ], // Wartortle
        vector[ 79,  83, 100,  85, 105,  78 ], // Blastoise
        vector[ 45,  30,  35,  20,  20,  45 ], // Caterpie
        vector[ 50,  20,  55,  25,  25,  30 ], // Metapod
        vector[ 60,  45,  50,  90,  80,  70 ], // Butterfree
        vector[ 40,  35,  30,  20,  20,  50 ], // Weedle
        vector[ 45,  25,  50,  25,  25,  35 ], // Kakuna
        vector[ 65,  90,  40,  45,  80,  75 ], // Beedrill
        vector[ 40,  45,  40,  35,  35,  56 ], // Pidgey
        vector[ 63,  60,  55,  50,  50,  71 ], // Pidgeotto
        vector[ 83,  80,  75,  70,  70, 101 ], // Pidgeot
        vector[ 30,  56,  35,  25,  35,  72 ], // Rattata
        vector[ 55,  81,  60,  50,  70,  97 ], // Raticate
        vector[ 40,  60,  30,  31,  31,  70 ], // Spearow
        vector[ 65,  90,  65,  61,  61, 100 ], // Fearow
        vector[ 35,  60,  44,  40,  54,  55 ], // Ekans
        vector[ 60,  95,  69,  65,  79,  80 ], // Arbok
        vector[ 35,  60,  44,  40,  54,  55 ], // Pikachu
        vector[ 60,  90,  69,  65,  79,  80 ], // Raichu
        vector[ 50,  75,  85,  20,  30,  40 ], // Sandshrew
        vector[ 75, 100, 110,  45,  55,  65 ], // Sandslash
        vector[ 55,  47,  52,  40,  40,  41 ], // Nidoran
        vector[ 70,  62,  67,  55,  55,  56 ], // Nidorina
        vector[ 90,  82,  87,  75,  85,  76 ], // Nidoqueen
    ];

    /// Can not be copied; assigned to the Capy.
    struct Stats has store, drop {
        base_stats: vector<u8>,
        individual_stats: vector<u8>,
        species_index: u8,
    }

    /// Create a new instance of Stats, droppable, does not mean anything unless
    /// stored under a certain key.
    public fun new(capy: &SF<Capy>): Stats {
        let genes = sf::genes(capy);

        // use the first gene to determine the species.
        let species_index = *v::borrow(genes, 0) % 32;
        let base_stats = *v::borrow(&BASE_STATS, (species_index as u64));

        // TODO: calculate the individual stats.
        let individual_stats = vector[];
        let i = 0;

        while (i < 6) {
            let stat = *v::borrow(genes, i) % 16;
            v::push_back(&mut individual_stats, stat);
            i = i + 1;
        };

        Stats {
            base_stats,
            individual_stats,
            species_index,
        }
    }

    /// Determines the health points of the Pokemon. A battle is over when the
    /// HP of the Pokemon is 0.
    public fun hp(stats: &Stats): u8 {
        let base_hp = *v::borrow(&stats.base_stats, 0);
        let individual_hp = *v::borrow(&stats.individual_stats, 0);
        base_hp + individual_hp
    }

    /// Determines the attack of the Pokemon which is used to determine the
    /// damage of the physical attacks (the lower the attack, the lower the
    /// damage)
    public fun attack(stats: &Stats): u8 {
        let base_attack = *v::borrow(&stats.base_stats, 1);
        let individual_attack = *v::borrow(&stats.individual_stats, 1);
        base_attack + individual_attack
    }

    /// Determines the defense of the Pokemon which is used to determine the
    /// damage of the physical attacks (the lower the defense, the higher the
    /// damage)
    public fun defense(stats: &Stats): u8 {
        let base_defense = *v::borrow(&stats.base_stats, 2);
        let individual_defense = *v::borrow(&stats.individual_stats, 2);
        base_defense + individual_defense
    }

    /// Determines the special attack of the Pokemon which is used to determine
    /// the damage of the special attacks.
    public fun special_attack(stats: &Stats): u8 {
        let base_special_attack = *v::borrow(&stats.base_stats, 3);
        let individual_special_attack = *v::borrow(&stats.individual_stats, 3);
        base_special_attack + individual_special_attack
    }

    /// Determines the special defense of the Pokemon which is used to determine
    /// the damage of the special attacks.
    public fun special_defense(stats: &Stats): u8 {
        let base_special_defense = *v::borrow(&stats.base_stats, 4);
        let individual_special_defense = *v::borrow(&stats.individual_stats, 4);
        base_special_defense + individual_special_defense
    }

    /// Determines the speed of the Pokemon which is used to determine the order
    /// of the Pokemon in the battle.
    public fun speed(stats: &Stats): u8 {
        let base_speed = *v::borrow(&stats.base_stats, 5);
        let individual_speed = *v::borrow(&stats.individual_stats, 5);
        base_speed + individual_speed
    }
}
