// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module aims to provide the functionality to generate Pokemon stats from
/// SuiFrens.
module game::capy_stats {
    use std::vector;

    use suifrens::capy::Capy;
    use suifrens::suifrens::{Self as sf, SuiFren};
    use pokemon::stats::{Self, Stats};

    /// The base HP stat - even if Capy is weak we'll add 10 HP to it.
    const BASE_HP: u8 = 10;
    /// The median value for a gene. This is used to balance out the stats.
    const MEDIAN: u8 = 50;

    public fun stats(capy: &SuiFren<Capy>): Stats {
        let genes = sf::genes(capy);
        let gen = sf::generation(capy);
        let level = if (gen > 2) { 1 } else { 10 - ((gen as u8) * 4) };
        let types = vector[*vector::borrow(genes, 6) % 3]; // 0-2

        // Genes V2 use u16 instead of u8, so we need to take every other byte
        // from the gene sequence to prevent inheriting two properties at once.

        let hp = BASE_HP + smooth(*vector::borrow(genes, 0), MEDIAN);
        let attack = smooth(*vector::borrow(genes, 2), MEDIAN);
        let defense = smooth(*vector::borrow(genes, 4), MEDIAN);
        let special_attack = smooth(*vector::borrow(genes, 6), MEDIAN);
        let special_defense = smooth(*vector::borrow(genes, 8), MEDIAN);
        let speed = smooth(*vector::borrow(genes, 10), MEDIAN);

        // Because Capy stats are pretty random,

        // For starters let's just take each gene and assign it to a stat.
        stats::new(
            hp, attack, defense,
            special_attack, special_defense,
            speed, level, types,
        )
    }

    /// Calculates the strength index of a Pokemon. This is used to determine if
    /// a Capy is strong enough or not - to have a better balance, we should
    /// add some stat if the strength index is too low.
    ///
    /// TODO: discuss with Alberto which stat is good enough.
    public fun strength_index(stat: &Stats): u8 {
        let sum =
            ((stats::hp(stat) / stats::scaling()) as u16) +
            (stats::attack(stat) as u16) +
            (stats::defense(stat) as u16) +
            (stats::special_attack(stat) as u16) +
            (stats::special_defense(stat) as u16) +
            (stats::speed(stat) as u16);

        ((sum / 6) as u8)
    }

    /// Smooths out the stat by adding the median value to it and dividing by 2.
    fun smooth(stat: u8, median: u8): u8 {
        ((stat & median) + median) / 2
    }
}

#[test_only]
module game::stats_test {
    use sui::tx_context::{fresh_object_address as skip, dummy};
    use suifrens::suifrens as sf;
    use game::capy_stats;

    #[test] fun test_gene_rator() {
        let ctx = &mut dummy();

        skip(ctx); skip(ctx); skip(ctx); skip(ctx);

        let capy = sf::mint_for_testing(ctx);
        let stats = capy_stats::stats(&capy);

        std::debug::print(&capy_stats::strength_index(&stats));
        std::debug::print(sf::genes(&capy));
        std::debug::print(&stats);

        sf::burn_for_testing(capy);
    }
}
