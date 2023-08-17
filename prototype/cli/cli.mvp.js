// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// rock beats: fire, scissors, snake, human, tree, wolf, sponge,
// gun beats: rock, fire, scissors, snake, human, tree, wolf
// lightning beats: gun, rock, fire, scissors, snake, human, tree
// devil beats: lightning, gun, rock, fire, scissors, snake, human
// dragon beats: devil, lightning, gun, rock, fire, scissors, snake
// water beats: dragon, devil, lightning, gun, rock, fire, scissors
// air beats: water, dragon, devil, lightning, gun, rock, fire
// paper beats: air, water, dragon, devil, lightning, gun, rock
// sponge beats: paper, air, water, dragon, devil, lightning, gun
// wolf beats: sponge, paper, air, water, dragon, devil, lightning
// tree beats: wolf, sponge, paper, air, water, dragon, devil
// human beats: tree, wolf, sponge, paper, air, water, dragon
// snake beats: human, tree, wolf, sponge, paper, air, water
// scissors beats: snake, human, tree, wolf, sponge, paper, air
// fire beats: scissors, snake, human, tree, wolf, sponge, paper
// and that makes the circle complete

export const MOVES = {
    rock: {
        name: "Rock",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 2, 2, 0.5, 2, 2, 2, 2, 2],
    },
    gun: {
        name: "Gun",
        type: "physical",
        power: 60,
        effectiveness: [2, 1, 0.5, 0.5, 1, 2, 0.5, 0, 1, 1, 1, 1, 0.5, 2, 1]
    },
    lightning: {
        name: "Lightning",
        type: "magic",
        power: 35,
        effectiveness: [1, 2, 1, 1, 1, 0.5, 2, 1, 1, 1, 2, 0.5, 1, 1, 1]
    },
    devil: {
        name: "Devil",
        type: "physical",
        power: 66,
        effectiveness: [1, 1, 1, 0.5, 0.5, 0.5, 2, 0.5, 1, 1, 2, 1, 1, 1, 1]
    },
    dragon: {
        name: "Dragon",
        type: "magical",
        power: 80,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 0.5, 1, 1, 2, 1, 1, 1, 0]
    },
    water: {
        name: "Water",
        type: "magic",
        power: 60,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 0.5, 0.5, 2, 1, 1, 1, 1, 1]
    },
    air: {
        name: "Air",
        type: "magic",
        power: 60,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 0.5, 2, 0.5, 1, 1, 1, 1, 1]
    },
    paper: {
        name: "Paper",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 2, 0.5, 0.5, 1, 1, 1, 1, 1]
    },
    sponge: {
        name: "Sponge",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 1, 2, 0.5, 0.5, 1, 1, 1, 1, 1]
    },
    wolf: {
        name: "Wolf",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 0.5, 1, 2, 2, 1, 1, 1, 0.5, 1]
    },
    tree: {
        name: "Tree",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 0.5, 1, 2, 2, 1, 1, 1, 0.5, 1]
    },
    human: {
        name: "Human",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 0.5, 1, 2, 2, 1, 1, 1, 0.5, 1]
    },
    snake: {
        name: "Snake",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 0.5, 1, 2, 2, 1, 1, 1, 0.5, 1]
    },
    scissors: {
        name: "Scissors",
        type: "physical",
        power: 40,
        effectiveness: [1, 1, 1, 1, 1, 1, 2, 1, 0.5, 0.5, 1, 1, 1, 1, 1]
    },
    // fire is effective against paper and sponge
    fire: {
        name: "Fire",
        type: "magic",
        power: 60,
        effectiveness: [0, 0, 0, 0.5, 0, 0.5, 0.5, 2, 2, 1, 1, 1, 1, 1, 1]
    },
};

function effectiveness(move, type) {
    return MOVES[move].effectiveness[type];
}

export function calculatePhysicalDamage(attackingCapy, move, defendingCapy, criticalRandom = 255, random = 217) {

    let lvl_mod = 2 * attackingCapy.level * 1 / 5 + 2;

    let move_pw = MOVES[move].power;
    let atk_def = attackingCapy.stats[1] / defendingCapy.stats[2];
    let crit_hit_mod = (attackingCapy.stats[5] > criticalRandom) ? 2 : 1;
    let result = (lvl_mod * move_pw * atk_def * crit_hit_mod / 50) + 2;
    let rnd_val = random / 255;

    let eff_val = effectiveness(move, defendingCapy.types[0]);
    let stab = attackingCapy.types.includes(Object.keys(MOVES).indexOf(move)) ? 1.5 : 1;
    let damage = result * rnd_val * eff_val * stab;

    return {
        DMG: damage,
        CRIT: crit_hit_mod,
        STAB: stab,
        TYPE: eff_val,
        MISS: damage == 0
    }
}

export function calculateSpecialDamage(attackingCapy, move, defendingCapy, criticalRandom = 255, random = 217) {

    let lvl_mod = 2 * attackingCapy.level * 1 / 5 + 2;

    let move_pw = MOVES[move].power;
    let atk_def = attackingCapy.stats[3] / defendingCapy.stats[4];
    let crit_hit_mod = (attackingCapy.stats[5] > criticalRandom) ? 2 : 1;
    let result = (lvl_mod * move_pw * atk_def * crit_hit_mod / 50) + 2;
    let rnd_val = random / 255;

    let eff_val = effectiveness(move, defendingCapy.types[0]);
    let stab = attackingCapy.types.includes(Object.keys(MOVES).indexOf(move)) ? 1.5 : 1;
    let damage = result * rnd_val * eff_val * stab;

    return {
        DMG: damage,
        CRIT: crit_hit_mod,
        STAB: stab,
        TYPE: eff_val,
        MISS: damage == 0
    }
}

// function calculateSpecialDamage(attackingCapy, move, defendingCapy, random = 217) {
//     let level_modifier = 2 * attackingCapy.level / 5 + 2;
//     let move_power = effectiveness(move, defendingCapy.types[0]);
//     let attack_modifier = attackingCapy.stats[3] / defendingCapy.stats[4];
//     let base = level_modifier * move_power * attack_modifier / 50 + 2;
//     return base * random / 255;
// }
