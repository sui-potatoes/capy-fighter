// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// lets start simple first
// to calculate the attack of a pokemon we need attack, level, base attack

// critical is a random number between 1 and 2 (2 is for special attack)
// level is the level of the pokemon (0-100)


function genDamage(attack, level, baseAttack) {
  (((2 * level * critical / 5 + 2) * power * attack / defence) / 50 + 2)
  * stab * type * burn * other * rand(0.85, 1.00)
}

}



// Copy-pasta of the `heroes/sources/stats.move` file.
const BASE_STATS = [
  [45, 49, 49, 65, 65, 45], // Bulbasaur
  [60, 62, 63, 80, 80, 60], // Ivysaur
  [80, 82, 83, 100, 100, 80], // Venusaur
  [39, 52, 43, 60, 50, 65], // Charmander
  [58, 64, 58, 80, 65, 80], // Charmeleon
  [78, 84, 78, 109, 85, 100], // Charizard
  [44, 48, 65, 50, 64, 43], // Squirtle
  [59, 63, 80, 65, 80, 58], // Wartortle
  [79, 83, 100, 85, 105, 78], // Blastoise
  [45, 30, 35, 20, 20, 45], // Caterpie
  [50, 20, 55, 25, 25, 30], // Metapod
  [60, 45, 50, 90, 80, 70], // Butterfree
  [40, 35, 30, 20, 20, 50], // Weedle
  [45, 25, 50, 25, 25, 35], // Kakuna
  [65, 90, 40, 45, 80, 75], // Beedrill
  [40, 45, 40, 35, 35, 56], // Pidgey
  [63, 60, 55, 50, 50, 71], // Pidgeotto
  [83, 80, 75, 70, 70, 101], // Pidgeot
  [30, 56, 35, 25, 35, 72], // Rattata
  [55, 81, 60, 50, 70, 97], // Raticate
  [40, 60, 30, 31, 31, 70], // Spearow
  [65, 90, 65, 61, 61, 100], // Fearow
  [35, 60, 44, 40, 54, 55], // Ekans
  [60, 95, 69, 65, 79, 80], // Arbok
  [35, 60, 44, 40, 54, 55], // Pikachu
  [60, 90, 69, 65, 79, 80], // Raichu
  [50, 75, 85, 20, 30, 40], // Sandshrew
  [75, 100, 110, 45, 55, 65], // Sandslash
  [55, 47, 52, 40, 40, 41], // Nidoran
  [70, 62, 67, 55, 55, 56], // Nidorina
  [90, 82, 87, 75, 85, 76], // Nidoqueen
];

const SPECIES = [
  "Bulbasaur",
  "Ivysaur",
  "Venusaur",
  "Charmander",
  "Charmeleon",
  "Charizard",
  "Squirtle",
  "Wartortle",
  "Blastoise",
  "Caterpie",
  "Metapod",
  "Butterfree",
  "Weedle",
  "Kakuna",
  "Beedrill",
  "Pidgey",
  "Pidgeotto",
  "Pidgeot",
  "Rattata",
  "Raticate",
  "Spearow",
  "Fearow",
  "Ekans",
  "Arbok",
  "Pikachu",
  "Raichu",
  "Sandshrew",
  "Sandslash",
  "Nidoran",
  "Nidorina",
  "Nidoqueen",
];

// Each Move has a special affect on the opponent depending on the type of the
// move and the type of the opponent. The type of the move is determined by the
// move itself, and the type of the opponent is determined by the species of the
// opponent.
//
// A matrix of 18x18 (324) entries is used to determine the effectiveness of a
// move on an opponent. The matrix is symmetric, so only 153 entries are
// required.

// this is the matrix of effectiveness of a move on an opponent (given its
// specialization) one species has at least one and at most two specializations.

const SPECIES_TYPES = [
  ["Grass", "Poison"], // Bulbasaur
  ["Grass", "Poison"], // Ivysaur
  ["Grass", "Poison"], // Venusaur
  ["Fire"], // Charmander
  ["Fire"], // Charmeleon
  ["Fire", "Flying"], // Charizard
  ["Water"], // Squirtle
  ["Water"], // Wartortle
  ["Water"], // Blastoise
  ["Bug", "Flying"], // Caterpie
  ["Bug", "Flying"], // Metapod
  ["Bug", "Flying"], // Butterfree
  ["Bug", "Poison"], // Weedle
  ["Bug", "Poison"], // Kakuna
  ["Bug", "Poison"], // Beedrill
  ["Normal", "Flying"], // Pidgey
  ["Normal", "Flying"], // Pidgeotto
  ["Normal", "Flying"], // Pidgeot
  ["Normal"], // Rattata
  ["Normal"], // Raticate
  ["Normal", "Flying"], // Spearow
  ["Normal", "Flying"], // Fearow
  ["Poison"], // Ekans
  ["Poison"], // Arbok
  ["Electric"], // Pikachu
  ["Electric"], // Raichu
  ["Ground"], // Sandshrew
  ["Ground"], // Sandslash
  ["Poison"], // Nidoran
  ["Poison"], // Nidorina
  ["Poison", "Ground"], // Nidoqueen
];

// Each Move is either a physical attack, a special attack, or a status effect.
// The type of the move determines its specialization.
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

// This is the matrix of effectiveness of a move on an opponent (given its
// specialization) one species has at least one and at most two specializations.
// Top row is the type of the move, left column is the type of the opponent.
const EFFECTIVENESS = [
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

class Stats {
  constructor(genes) {
    if (!genes || genes.constructor !== Array || genes.length !== 32) {
      throw new Error("Genes must be an array with 32 bytes");
    }

    if (genes.find((v) => +v > 255)) {
      throw new Error("Each gene must be a byte (0-255)");
    }

    let species_index = genes[0] % 32;
    let individual_stats = [];

    for (let i = 0; i < 6; i++) {
      let stat = genes[i + 1] % 16;
      individual_stats.push(stat);
    }

    this.base_stats = BASE_STATS[species_index];
    this.species_name = SPECIES[species_index];
    this.types = SPECIES_TYPES[species_index];
    this.species_index = species_index;
    this.individual_stats = [];
  }

  get attack() {
    return this.individual_stats[0] + this.base_stats[0];
  }

  get defense() {
    return this.individual_stats[1] + this.base_stats[1];
  }

  get special_attack() {
    return this.individual_stats[2] + this.base_stats[2];
  }

  get special_defense() {
    return this.individual_stats[3] + this.base_stats[3];
  }

  get speed() {
    return this.individual_stats[4] + this.base_stats[4];
  }

  get hp() {
    return this.individual_stats[5] + this.base_stats[5];
  }
}

const random_genes = () => {
  return Array.from({ length: 32 }, () => Math.floor(Math.random() * 256));
};

const capy_one = stats(random_genes());
const capy_two = stats(random_genes());

// Function to get the effectiveness of a move on a given opponent
// move is a number between 0 and 15
// opponent is a number between 0 and 15
const effectiveness = (move, opponent) => {
  if (move < 0 || move > 15) {
    throw new Error("Move must be a number between 0 and 15");
  }

  if (opponent < 0 || opponent > 15) {
    throw new Error("Opponent must be a number between 0 and 15");
  }

  return EFFECTIVENESS[move][opponent];
};

// Function to calculate the damage of a move on a given opponent considering
// the attacker's attack and the opponent's defense or a speacial attack and
// special defense if the move is special. The damage is calculated using the
// formula from https://bulbapedia.bulbagarden.net/wiki/Damage
// move is a number between 0 and 15
// opponent is a number between 0 and 15
// special is a boolean
// attack is a number between 0 and 15
// defense is a number between 0 and 15
const damage = (move, attacker, defender) => {
  let attack = attacker.individual_stats[0] + attacker.base_stats[0];
  let special_attack = attacker.individual_stats[2] + attacker.base_stats[2];

  let defense = defender.individual_stats[1] + defender.base_stats[1];
  let special_defense = defender.individual_stats[3] + defender.base_stats[3];

  if (move < 0 || move > 15) {
    throw new Error("Move must be a number between 0 and 15");
  }

  if (opponent < 0 || opponent > 15) {
    throw new Error("Opponent must be a number between 0 and 15");
  }

  if (attack < 0 || attack > 15) {
    throw new Error("Attack must be a number between 0 and 15");
  }

  if (defense < 0 || defense > 15) {
    throw new Error("Defense must be a number between 0 and 15");
  }

  let power = POWER[move];
  let modifier = effectiveness(move, opponent);
  let level = 100;
  let a = special ? attack : defense;
  let d = special ? defense : attack;
  let damage = Math.floor(
    Math.floor(Math.floor((2 * level + 10) / 250) * (a / d) * power + 2) *
      modifier
  );

  return damage;
};
