// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { program } from 'commander';
import blake2b from 'blake2b';
import { calculatePhysicalDamage, calculateSpecialDamage, MOVES } from './cli.mvp.js';
import inquirer from 'inquirer';

/*
 * Stat indexes are:
 * - HP (0)
 * - Attack (1)
 * - Defense (2)
 * - Special Attack (3)
 * - Special Defense (4)
 * - Speed (5)
 */

program
    .name('capymon-prototype')
    .description('A prototype for Capymon')
    .version('0.0.1');

program
    .command('challenge')
    .argument('[seed]', 'The seed to use for the challenge')
    .action(botFight);

program.parse(process.argv);


/** The main function for the bot fight */
async function botFight(input) {
    let seed = useOrCreateSeed(input);

    console.log('='.repeat(84));
    console.log('|| Using the seed: %s', seed);
    console.log('|| If you want to use this seed again, run the command with the seed as an argument');
    console.log('='.repeat(84));
    console.log();

    const player = capyFromBytes(derive(seed, 0));
    const bot = capyFromBytes(derive(seed, 1));

    // console.log('Player: %o', player);
    // console.log('Bot: %o', bot);

    console.table([
        { name: 'Player', LVL: player.level, TYPE: Object.keys(MOVES)[player.types[0]], HP: player.stats[0], ATK: player.stats[1], DEF: player.stats[2], S_ATK: player.stats[3], S_DEF: player.stats[4], SPD: player.stats[5] },
        { name: 'Bot', LVL: bot.level, TYPE: Object.keys(MOVES)[bot.types[0]], HP: bot.stats[0], ATK: bot.stats[1], DEF: bot.stats[2], S_ATK: bot.stats[3], S_DEF: bot.stats[4], SPD: bot.stats[5] },
    ]);

    // Now to the fight

    let round = 1;

    while (player.stats[0] > 0 && bot.stats[0] > 0) {
        console.log('\n==== ROUND %s '.padEnd(84, '='), round);

        const playerMove = await inquirer.prompt([
            {
                type: 'list',
                name: 'move',
                prefix: '>',
                message: 'Choose your move',
                choices: Object.keys(MOVES).map((move) => ({
                    name: `${move.padEnd(9, ' ')} | Power: ${MOVES[move].power} | Type: ${MOVES[move].type}`,
                    value: move,
                })),

            }
        ]);

        // calculate stats for player

        const playerHitRng = Buffer.from(derive(seed, 3), 'hex')[round] % (255 - 217) + 217;
        const playerCritRng = Buffer.from(derive(seed, 3), 'hex')[round + 1] % 255;
        const playerIsSpecial = MOVES[playerMove.move].type == 'magic';
        const playerDamage = playerIsSpecial
            ? calculateSpecialDamage(player, playerMove.move, bot, playerCritRng, playerHitRng)
            : calculatePhysicalDamage(player, playerMove.move, bot, playerCritRng, playerHitRng);

        // do the same with bot but use rng for everything

        const botMoveRng = Buffer.from(derive(seed, 2), 'hex')[round] % 4;
        const botMove = Object.keys(MOVES)[botMoveRng];
        const botHitRng = Buffer.from(derive(seed, 4), 'hex')[round] % (255 - 217) + 217;
        const botCritRng = Buffer.from(derive(seed, 4), 'hex')[round + 1] % 255;
        const botIsSpecial = MOVES[botMove].type == 'magic';
        const botDamage = botIsSpecial
            ? calculateSpecialDamage(bot, botMove, player, botCritRng, botHitRng)
            : calculatePhysicalDamage(bot, botMove, player, botCritRng, botHitRng);

        // print the results of the round

        console.table([
            { name: 'Player', ...playerDamage, DMG: playerDamage.DMG.toFixed(0) },
            { name: 'Bot', ...botDamage, DMG: botDamage.DMG.toFixed(0) },
        ]);

        player.stats[0] -= botDamage.DMG;
        bot.stats[0] -= playerDamage.DMG;

        console.log('[Player] HP: %s (-%s)', (player.stats[0] < 0 ? 0 : player.stats[0]).toFixed(0), botDamage.DMG.toFixed(0));
        console.log('[Bot]    HP: %s (-%s)', (bot.stats[0] < 0 ? 0 : bot.stats[0]).toFixed(0), playerDamage.DMG.toFixed(0));

        round++;
    }

    if (player.stats[0] > 0) {
        console.log('You win!');
    } else {
        console.log('You lose!');
    }

    console.log('Seed: %s', seed);
}

/** Generate a Capy from stats */
function capyFromBytes(hash) {
    let bytes = Buffer.from(hash, 'hex');
    let stats = [...bytes.slice(0, 6)];
    let types = [...bytes.slice(6, 8)].map((type) => type % 15);
    let level = (+bytes.slice(8, 9)[0] % 10) || 1;

    // normalizing stats: making it closer to 60 (average)
    // and adding a level modifier (10 levels total, modifier is level / 10 - 2)
    stats = stats.map((stat) => Math.floor((60 + stat % 60) / 2 * level / 8));

    // adding 10 to the HP stat
    stats[0] += 10;

    return { stats, types, level };
}

/** Derive a hash from an input */
function derive(seed, index) {
    const toHash = Buffer.from(`${seed}${index}`, 'ascii');
    return blake2b(32).update(toHash).digest('hex');
}

/** Creates a new seed from hash or hashes existing seed */
function useOrCreateSeed(seed) {
    if (!seed) {
        return blake2b(32).update(Buffer.from(Math.random().toString(), 'ascii')).digest('hex');
    }

    return seed;
}
