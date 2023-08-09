// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/*
 * Stats in order:
 * HP, Attack, Defense, Special Attack, Special Defense, Speed
 */

/** Stats for the first Capy */
const CAPY_ONE = {
    // stats: [393, 288, 268, 348, 208 ],
    stats: [ 45, 49, 49, 65, 65, 45 ],
    types: [ "Grass", "Psychic" ],
    level: 10
};

/** Stats for the second Capy */
const CAPY_TWO = {
    stats: [ 40, 60, 30, 31, 31, 70 ],
    // stats: [ 413, 358, 338, 188, 178  ],
    types: [ "Ground", "Rock" ],
    level: 10
};

// the fastest capy is the second one - its speed is 70
// the strongest attack is the second capy - its attack is 60
// the strongest special attack is the first capy - its special attack is 65

// We're using the 5 gen damage formula
// https://bulbapedia.bulbagarden.net/wiki/Damage#Damage_formula

const MOVES = [
    "Normal", // physical attack
    "Fighting", // physical attack
    "Flying", // physical attack
    "Poison", // status effect
    "Ground", // status effect
    "Rock", // physical attack
    "Bug", // physical attack

    "Ghost", // status effect
    "Fire", // special attack
    "Water", // special attack
    "Grass", // special attack
    "Electric", // special attack
    "Psychic", // special attack
    "Ice", // special attack
];

const MOVE_POWER = [
    40, // Normal
    60, // Fighting
    35, // Flying
    0, // Poison
    0, // Ground
    40, // Rock
    40, // Bug
    0, // Ghost
    95, // Fire
    95, // Water
    95, // Grass
    95, // Electric
    95, // Psychic
    95, // Ice
];

const EFFECTIVENESS = [
    // normal, fighting, flying, poison, ground, rock, bug, ghost, steel, fire, water, grass, electric, psychic, ice, dragon, dark, fairy
    [1, 1, 1, 1, 1, 0.5, 1, 0, 1, 1, 1, 1, 1, 1, 1], // Normal
    [2, 1, 0.5, 0.5, 1, 2, 0.5, 0, 1, 1, 1, 1, 0.5, 2, 1], // Fighting
    [1, 2, 1, 1, 1, 0.5, 2, 1, 1, 1, 2, 0.5, 1, 1, 1], // Flying
    [1, 1, 1, 0.5, 0.5, 0.5, 2, 0.5, 1, 1, 2, 1, 1, 1, 1], // Poison
    [1, 1, 0, 2, 1, 2, 0.5, 1, 2, 1, 0.5, 2, 1, 1, 1], // Ground
    [1, 0.5, 2, 1, 0.5, 1, 2, 1, 2, 1, 1, 1, 1, 2, 1], // Rock
    [1, 0.5, 0.5, 2, 1, 1, 1, 0.5, 0.5, 1, 2, 1, 2, 1, 1], // Bug
    [0, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 0, 1, 1], // Ghost
    [1, 1, 1, 1, 1, 0.5, 2, 1, 0.5, 0.5, 2, 1, 1, 2, 0.5], // Fire
    [1, 1, 1, 1, 2, 2, 1, 1, 2, 0.5, 0.5, 1, 1, 1, 0.5], // Water
    [1, 1, 0.5, 0.5, 2, 2, 0.5, 1, 0.5, 2, 0.5, 1, 1, 1, 0.5], // Grass
    [1, 1, 2, 1, 0, 1, 1, 1, 1, 2, 0.5, 0.5, 1, 1, 0.5], // Electric
    [1, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 0.5, 1, 1], // Psychic
    [1, 1, 2, 1, 2, 1, 1, 1, 1, 0.5, 2, 1, 1, 0.5, 2], // Ice
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2], // Dragon
];

function effectiveness(move, type) {
    return EFFECTIVENESS[MOVES.indexOf(move)][MOVES.indexOf(type)];
}

function isMoveSpecial(move) {
    return MOVES.indexOf(move) >= 8;
}

function calculatePhysicalDamage(attackingCapy, move, defendingCapy, random = 217) {

    let lvl_mod = 2 * attackingCapy.level * 1 / 5 + 2;
    let move_pw = MOVE_POWER[MOVES.indexOf(move)];
    let att_def = attackingCapy.stats[1] / defendingCapy.stats[2];
    let res = (lvl_mod * move_pw * att_def / 50) + 2;

    console.log('level mod: %s; move power: %s; attack / defence: %s', lvl_mod, move_pw, att_def);

    return res * effectiveness(move, defendingCapy.types[0]) * random / 255;
}

function calculateSpecialDamage(attackingCapy, move, defendingCapy, random = 217) {
    let level_modifier = 2 * attackingCapy.level / 5 + 2;
    let move_power = effectiveness(move, defendingCapy.types[0]);
    let attack_modifier = attackingCapy.stats[3] / defendingCapy.stats[4];

    let base = level_modifier * move_power * attack_modifier / 50 + 2;

    return base * random / 255;
}

console.log('damage: %s', calculatePhysicalDamage(CAPY_TWO, "Fighting", CAPY_ONE, 255));
console.log('damage: %s', calculatePhysicalDamage(CAPY_ONE, "Bug", CAPY_TWO, 255));
console.log('damage: %s', calculatePhysicalDamage(CAPY_TWO, "Normal", CAPY_ONE, 240));
