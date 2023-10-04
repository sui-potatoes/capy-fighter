// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { requestSuiFromFaucetV1, getFaucetHost } from "@mysten/sui.js/faucet";
import { fromB64, fromHEX, isValidSuiObjectId } from "@mysten/sui.js/utils";
import { program } from "commander";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import inquirer from "inquirer";
import { KioskClient, Network, KioskTransaction } from "@mysten/kiosk";
import blake2b from "blake2b";
import { bcs } from "@mysten/sui.js/bcs";
import { promisify } from "util";
import { combinePartialSigs } from "@mysten/sui.js";

/** Wait for the given number of ms */
const wait = promisify(setTimeout);

/** How long to wait before polls (3m is the timeout in the App) */
const WAIT_TIME = 10 * 1000;

// === Sui Devnet Environment ===

const pkg =
  "0x61421e6a00beb9ecb4cde032c275c081f82fa5398a57b180af008c55e52a0e40";
const matchPool = {
  objectId:
    "0x443d65f0c05acee48ef7bcc1181b1415db12dbba87d65c7aa33f5e1620f0df02",
  initialSharedVersion: 23,
  mutable: true,
};

/** The built-in client for the application */
const client = new SuiClient({ url: getFullnodeUrl("devnet") });
const kioskClient = new KioskClient({
  client,
  network: Network.CUSTOM,
});

const keys = [
  {
    schema: "ED25519",
    privateKey: "qx8t50sEo23Ahi2T8EpauMKpDutQYN+12KGgDIeocc0=",
  },
  {
    schema: "ED25519",
    privateKey: "7rUeO3yZXxfNNHlgp+pVu8lrYIp1AC+d8BOOcTlmIi4=",
  },
];

/** The private key for the address; only for testing purposes */
const myKey = keys[process.env.KEY || 0];
const keypair = Ed25519Keypair.fromSecretKey(fromB64(myKey.privateKey));
const address = keypair.toSuiAddress();

// === CLI Bits ===

program
  .name("capymon-devnet-player-vs-player")
  .description("A prototype for Capymon on devnet")
  .version("0.0.1");

program
  .command("init")
  .description("Prepare the environment and set up a Kiosk")
  .action(newAccount);

program
  .command("new-player")
  .description("Create a new player account")
  .action(newPlayer);

program.command("play").description("Play the game").action(play);

program.parse(process.argv);

// === Commands / Actions ===

/**
 * Create a new Account and install the extension on the Kiosk:
 * - creates Kiosk if there wasn't one
 * - installes the Game Extension into the Kiosk
 *
 * Fails if:
 * - Kiosk exists and has the extension already
 */
async function newAccount() {
  await checkOrRequestGas();

  const { kioskOwnerCaps, kioskIds } = await kioskClient.getOwnedKiosks({
    address,
  });

  // If there's already a Kiosk, check that it has the extension.
  if (kioskOwnerCaps.length !== 0) {
    let { data, error } = await getExtension(kioskIds[0]);

    // Error means dynamic field fetching failed.
    if (!error) {
      throw new Error("Extension already installed! Use `new-player` instead");
    }

    let tx = new TransactionBlock();
    let cap = tx.objectRef(kioskOwnerCaps[0]);
    let kioskArg = tx.object(kioskIds[0]);

    combinePartialSigs
    
    tx.moveCall({
      target: `${pkg}::the_game::add`,
      arguments: [kioskArg, cap],
    });

    let { result } = await signAndExecute(tx);
    console.log("Extension added!; %o", result.effects.status);

    return;
  }

  // If there's no Kiosk, create one and install the extension.

  let tx = new TransactionBlock();
  let kioskTx = new KioskTransaction({ transactionBlock: tx, kioskClient });

  kioskTx.create();

  tx.moveCall({
    target: `${pkg}::the_game::add`,
    arguments: [kioskTx.getKiosk(), kioskTx.getKioskCap()],
  });

  kioskTx.shareAndTransferCap(address);
  kioskTx.finalize();

  let { result } = await signAndExecute(tx);
  console.log("Init stage over!; %o", result.effects.status);
}

/**
 * Create a new Player account:
 * - checks that there's a Kiosk
 * - checks that the Kiosk has the extension
 * - creates a new Player account
 *
 * Fail if:
 * - Kiosk does not exist
 * - Kiosk does not have the extension
 * - Player already exists
 */
async function newPlayer() {
  let { kioskOwnerCaps, kioskIds } = await kioskClient.getOwnedKiosks({
    address,
  });

  if (kioskOwnerCaps.length === 0) {
    throw new Error("Kiosk does not exist; run `init` first!");
  }

  let { data: extData, error: extErr } = await getExtension(kioskIds[0]);

  if (extErr) {
    throw new Error("Extension not installed; run `init` first!");
  }

  let { data: playerData, error } = await getPlayer(extData.storage);

  if (playerData) {
    throw new Error("Player already exists!");
  }

  let cap = kioskOwnerCaps[0];
  let kioskId = kioskIds[0];

  let type = await chooseType();
  let tx = new TransactionBlock();

  tx.moveCall({
    target: `${pkg}::the_game::new_player`,
    arguments: [tx.object(kioskId), tx.objectRef(cap), tx.pure.u8(type)],
  });

  let { result } = await signAndExecute(tx);

  console.log("Player created!; %o", result.effects.status);

  let { data: player } = await getPlayer(extData.storage);

  console.log("Player: %o", player.content.fields.value.fields);
}

/**
 * Play the game:
 * - submit a request to the Matchmaker
 * - wait for the match to be found
 *
 * Fails if:
 * - Kiosk does not exist
 * - Kiosk does not have the extension
 * - Player does not exist
 */
async function play() {
  let { kioskOwnerCaps, kioskIds } = await kioskClient.getOwnedKiosks({
    address,
  });

  if (kioskOwnerCaps.length === 0) {
    throw new Error("Kiosk does not exist; run `init` first!");
  }

  let { data: extData, error: extErr } = await getExtension(kioskIds[0]);

  if (extErr) {
    throw new Error("Extension not installed; run `init` first!");
  }

  let { data: playerData, error } = await getPlayer(extData.storage);

  if (!playerData) {
    throw new Error("Player does not exist!");
  }

  let { data: matchIdData, error: matchIdErr } = await getMatchId(
    extData.storage
  );

  // having a marker in the Kiosk means that we're already waiting for a match
  // or there's an active match, so we query some more to see what's up;
  if (matchIdData) {
    let { matchId } = matchIdData;
    let { data: arenaData, error: arenaError } = await getArenaId(matchId);

    // if the second player hasn't joined yet, we're waiting for them
    if (arenaError) {
      console.log("Still searching; do you want to cancel the search?");
      let res = await inquirer.prompt([
        {
          type: "confirm",
          name: "cancel",
          prefix: ">",
          message: "Cancel the search?",
        },
      ]);

      if (res && res.cancel) {
        let tx = new TransactionBlock();
        let cap = tx.objectRef(kioskOwnerCaps[0]);
        let matchArg = tx.sharedObjectRef(matchPool);
        let kioskArg = tx.object(kioskIds[0]);

        tx.moveCall({
          target: `${pkg}::the_game::cancel_search`,
          arguments: [kioskArg, matchArg, cap],
        });

        let { result } = await signAndExecute(tx);
        console.log("Match canceled!; %o", result.effects.status);
        return;
      }
    }

    console.log("Found a match!");

    let { arenaId } = arenaData;
    let arenaObject = await client.getObject({
      id: arenaId,
      options: {
        showOwner: true,
      },
    });

    let arenaRef = {
      objectId: arenaId,
      initialSharedVersion:
        arenaObject.data.owner.Shared.initial_shared_version,
      mutable: true,
    };

    return listenAndPlay(arenaRef, kioskIds[0], kioskOwnerCaps[0]);
  }

  // if there's no matchId, then we need to request a match

  let tx = new TransactionBlock();
  let cap = tx.objectRef(kioskOwnerCaps[0]);
  let kioskArg = tx.object(kioskIds[0]);
  let matchArg = tx.sharedObjectRef(matchPool);

  tx.moveCall({
    target: `${pkg}::the_game::play`,
    arguments: [kioskArg, cap, matchArg],
  });

  let { result } = await signAndExecute(tx);
  console.log("Match search started!; %o", result.effects.status);
}

/**
 * Perform a full round of actions:
 * - commit
 * - reveal
 * - wait for the opponent
 *
 * Should not be called directly, only from `play`.
 * Does a lot of querying instead of listening to events.
 */
async function listenAndPlay(arenaRef, kioskId, kioskCapRef, move = null) {
  // I know, we do it for the sake of the prototype
  let salt = [1, 2, 3, 4];
  let { data: arenaData, error } = await client.getObject({
    id: arenaRef.objectId,
    options: { showContent: true },
  });

  if (error) {
    throw new Error(`Could not fetch arena: ${error}; Unknown error`);
  }

  const arena = arenaData.content.fields;
  const [player, opponent] =
    arena.p1.fields.kiosk_id == kioskId
      ? [arena.p1.fields, arena.p2.fields]
      : [arena.p2.fields, arena.p1.fields];

  const originalStats = player.player.fields.stats.fields;
  const moves = player.player.fields.moves;
  const stats = player.stats.fields;

  // console.log(player, moves, stats);

  let action;

  switch (true) {
    case stats.hp == '0' || opponent.stats.hp == '0':
      action = "end";
      break;
    case player.next_attack == null && opponent.next_attack == null:
      action = "commit";
      break;
    case player.next_attack != null && opponent.next_attack == null:
      action = "wait";
      break;
    case player.next_attack != null && opponent.next_attack != null:
      action = "reveal";
      break;
    default:
      action = "wait";
  }

  console.log(action);

  // means that the player needs to make the commitment;
  // if the player has already committed, then we wait for the opponent
  if (action == "commit") {
    console.log("Your type is %s:", typesDefinitions()[stats.types[0]].name);
    console.log("- %s", typesDefinitions()[stats.types[0]].description);
    console.log(
      "Your opponent type is: %s",
      typesDefinitions()[opponent.stats.fields.types[0]].name
    );
    console.log("Your HP / Opponent HP");
    console.log(`%s / %s`, formatHP(stats.hp), formatHP(originalStats.hp));

    let move = await chooseMove(moves);
    let res = await commit(arenaRef, kioskCapRef, move, salt);
    console.log("Committed!", res.result.effects.status);

    return listenAndPlay(arenaRef, kioskId, kioskCapRef, move);
  }

  // means that the player needs to reveal the commitment; if the player has
  // already revealed, then we wait for the opponent;
  if (action == "reveal") {
    if (move == null) {
      console.log(
        "Game restarted, secret lost; please a move again (has to be the same)"
      );
      move = await chooseMove(moves);
    }

    let res = await reveal(arenaRef, kioskCapRef, move, salt);
    console.log("Revealed!", res.result.effects.status);

    return listenAndPlay(arenaRef, kioskId, kioskCapRef, move);
  }

  // means that the player needs to wait for the opponent to make a move;
  // then we check the state again and repeat the cycle
  if (action == "wait") {
    console.log("Waiting for the opponent to make a move...");
    await wait(WAIT_TIME);
    return listenAndPlay(arenaRef, kioskId, kioskCapRef, move);
  }

  if (action == "end") {
    console.log("Game over!");

    let tx = new TransactionBlock();
    let cap = tx.objectRef(kioskCapRef);
    let kioskArg = tx.object(kioskId);
    let matchArg = tx.sharedObjectRef(matchPool);
    let arenaArg = tx.sharedObjectRef(arenaRef);

    tx.moveCall({
      target: `${pkg}::the_game::clear_arena`,
      arguments: [kioskArg, arenaArg, cap, matchArg],
    });

    let { result } = await signAndExecute(tx);
    console.log('Cleanup over!', result.effects.status);
    process.exit(0);
  }
}

// === Transactions ===

/** Submit a commitment with an attack */
function commit(arenaRef, kioskCapRef, move, salt, gas = null) {
  let data = new Uint8Array([move, 1, 2, 3, 4]);
  let hash = Array.from(blake2b(32).update(data).digest());

  let tx = new TransactionBlock();

  tx.moveCall({
    target: `${pkg}::arena::commit`,
    arguments: [
      tx.sharedObjectRef(arenaRef),
      // tx.objectRef(kioskCapRef),
      tx.object(kioskCapRef.objectId),
      tx.pure(bcs.vector(bcs.u8()).serialize(hash).toBytes()),
      tx.object("0x6"), // clock
    ],
  });

  return signAndExecute(tx, gas);
}

/** Reveal the commitment by providing the Move and Salt */
function reveal(arenaRef, kioskCapRef, move, salt, gas = null) {
  let tx = new TransactionBlock();

  tx.moveCall({
    target: `${pkg}::arena::reveal`,
    arguments: [
      tx.sharedObjectRef(arenaRef),
      // tx.objectRef(kioskCapRef),
      tx.object(kioskCapRef.objectId),
      tx.pure.u8(move),
      tx.pure(bcs.vector(bcs.u8()).serialize(salt).toBytes()),
      tx.object("0x6"), // clock
    ],
  });

  return signAndExecute(tx, gas);
}

/** Join the arena if not yet */
function join(arena, gas = null) {
  let tx = new TransactionBlock();
  tx.moveCall({
    target: `${pkg}::arena_pvp::join`,
    arguments: [tx.sharedObjectRef(arena)],
  });

  return signAndExecute(tx, gas);
}

// === Fetching and Listening ===

function formatHP(hp) {
  return +(hp / 100000000).toFixed(2);
}

/** Sign the TransactionBlock and send the tx to the network */
async function signAndExecute(tx, gasObj = null) {
  if (gasObj) {
    tx.setGasPayment([gasObj]);
    tx.setGasBudget("100000000");
    tx.setGasPrice(1000);
  }

  const result = await client.signAndExecuteTransactionBlock({
    signer: keypair,
    transactionBlock: tx,
    options: {
      showEffects: true,
      showObjectChanges: true,
      showEvents: true,
    },
  });

  return {
    result,
    gas: result.effects.gasObject.reference,
  };
}

/** Try to fetch the Extension in a given Kiosk */
async function getExtension(kioskId) {
  const { data, error } = await client.getDynamicFieldObject({
    parentId: kioskId,
    name: {
      type: `0x2::kiosk_extension::ExtensionKey<${pkg}::the_game::Game>`,
      value: {
        dummy_field: false,
      },
    },
  });

  if (error) {
    return { error };
  }

  // remind me to shoot myself in the head
  const fields = data.content.fields.value.fields;

  return {
    data: {
      is_enabled: fields.is_enabled,
      permissions: +fields.permissions,
      storage: fields.storage.fields.id.id, // and for this
    },
  };
}

/** Get the player in the Extension Storage */
async function getPlayer(extensionStorageId) {
  const { data, error } = await client.getDynamicFieldObject({
    parentId: extensionStorageId,
    name: {
      type: `${pkg}::the_game::PlayerKey`,
      value: {
        dummy_field: false,
      },
    },
  });

  return { data, error };
}

/** Get the MatchID from the Extension Storage */
async function getMatchId(extensionStorageId) {
  const { data, error } = await client.getDynamicFieldObject({
    parentId: extensionStorageId,
    name: {
      type: `${pkg}::the_game::MatchKey`,
      value: {
        dummy_field: false,
      },
    },
  });

  if (error) {
    return { error };
  }

  return {
    data: {
      matchId: data.content.fields.value,
    },
  };
}

/** Try to get the ArenaID from the MatchPool */
async function getArenaId(matchId) {
  const { data, error } = await client.getDynamicFieldObject({
    parentId: matchPool.objectId,
    name: {
      type: `0x2::object::ID`,
      value: matchId,
    },
  });

  if (error) {
    return { error };
  }

  return {
    data: {
      arenaId: data.content.fields.value,
    },
  };
}

/** Prompt to choose a type of the Player */
function chooseType() {
  return inquirer
    .prompt([
      {
        type: "list",
        name: "type",
        prefix: ">",
        message: "Choose your type (don't worry, you can start over later)",
        choices: [
          { name: "Water: Water is super effective against Fire", value: 0 },
          { name: "Fire: Fire is super effective against Air", value: 1 },
          { name: "Air: Air is super effective against Earth", value: 2 },
          { name: "Earth: Earth is super effective against Water", value: 3 },
        ],
      },
    ])
    .then((res) => res.type);
}

/**
 * Prompt a list to the user
 * @param moves number[]
 * */
function chooseMove(moves) {
  return inquirer
    .prompt([
      {
        type: "list",
        name: "move",
        prefix: ">",
        message: "Choose your move",
        choices: moves.map((id) => {
          let move = movesDefinitions()[id];
          return {
            name: `${move.name} (${move.type}: ${move.power}) Type: ${move.category}`,
            value: id,
          };
        }),
      },
    ])
    .then((res) => res.move);
}

// /** Hang until the cb is truthy */
// async function waitUntil(cb) {
//   const wait = () => new Promise((resolve) => setTimeout(resolve, 500));
//   await (async function forever() {
//     if (cb()) {
//       return;
//     }

//     return wait().then(forever);
//   })();
// }

/** Check that the account has at least 1 coin, if not - request from faucet */
async function checkOrRequestGas() {
  console.log("Checking for gas...");
  let coins = await client.getCoins({ owner: address });
  if (coins.data.length == 0) {
    console.log("No gas found; requesting from faucet...");
    await requestFromFaucet();
    return new Promise((resolve) => setTimeout(resolve, 10000));
  }
  console.log("All good!");
}

/** Request some SUI to the main address */
function requestFromFaucet() {
  return requestSuiFromFaucetV1({
    host: getFaucetHost("devnet"),
    recipient: address,
  });
}

/** Returns available types with hints */
function typesDefinitions() {
  return [
    { name: "Water", description: "Water is super effective against Fire" },
    { name: "Fire", description: "Fire is super effective against Air" },
    { name: "Air", description: "Air is super effective against Earth" },
    { name: "Earth", description: "Earth is super effective against Water" },
  ];
}

/** Return available moves and their power + type */
function movesDefinitions() {
  return [
    {
      name: "Hydro Pump",
      type: "Water",
      category: "Physical",
      power: 90,
      effectiveness: [10, 20, 5, 10],
    },
    {
      name: "Aqua Tail",
      type: "Water",
      category: "Special",
      power: 85,
      effectiveness: [10, 20, 5, 10],
    },
    {
      name: "Inferno",
      type: "Fire",
      category: "Physical",
      power: 85,
      effectiveness: [5, 10, 20, 10],
    },
    {
      name: "Flamethrower",
      type: "Fire",
      category: "Special",
      power: 90,
      effectiveness: [5, 10, 20, 10],
    },
    {
      name: "Quake Strike",
      type: "Earth",
      category: "Physical",
      power: 80,
      effectiveness: [20, 5, 10, 10],
    },
    {
      name: "Earthquake",
      type: "Earth",
      category: "Special",
      power: 85,
      effectiveness: [20, 5, 10, 10],
    },
    {
      name: "Gust",
      type: "Air",
      category: "Physical",
      power: 75,
      effectiveness: [10, 5, 10, 20],
    },
    {
      name: "Air Slash",
      type: "Air",
      category: "Special",
      power: 80,
      effectiveness: [10, 5, 10, 20],
    },
  ];
}
