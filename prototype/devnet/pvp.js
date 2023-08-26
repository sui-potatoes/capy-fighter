// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { requestSuiFromFaucetV1, getFaucetHost } from "@mysten/sui.js/faucet";
import { fromB64, isValidSuiObjectId } from "@mysten/sui.js/utils";
import { program } from "commander";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import inquirer from "inquirer";
import config from "./config.json" assert { type: "json" };

// === Sui Devnet Environment ===

const pkg = config.packageId;

/** The built-in client for the application */
const client = new SuiClient({ url: getFullnodeUrl("devnet") });

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
  .command("create-arena")
  .description("Create an arena; then wait for another player to join")
  .action(createArena);

program
  .command("join-arena <arenaId>")
  .description("Join an arena")
  .action(joinArena);

program.parse(process.argv);

// === Commands / Actions ===

async function joinArena(arenaId) {
  await checkOrRequestGas();

  if (!isValidSuiObjectId(arenaId)) {
    throw new Error(`Invalid arena ID: ${arenaId}`);
  }

  let arenaFetch = await client.getObject({
    id: arenaId,
    options: { showOwner: true, showContent: true },
  });

  if ("error" in arenaFetch) {
    throw new Error(`Could not fetch arena: ${arenaFetch.error}`);
  }

  if (!"Shared" in arenaFetch.data.owner) {
    throw new Error(`Arena is not shared`);
  }

  let fields = arenaFetch.data.content.fields;
  let rejoin = false;

  if (fields.player_two !== null) {
    if (fields.player_two.fields.account !== address) {
      // Also handle a scenario where I rejoin the arena (quite important!)
      throw new Error(`Arena is full, second player is there...`);
    }

    rejoin = true;
  }

  let initialSharedVersion =
    arenaFetch.data.owner.Shared.initial_shared_version;

  // Prepare the Arena object; shared and the insides never change.
  let arena = {
    mutable: true,
    objectId: arenaId,
    initialSharedVersion,
  };

  // Currently we only expect 1 scenario - join and compete to the end. So no
  // way to leave the arena and then rejoin. And the game order is fixed.
  if (!rejoin) {
    let joinResult = await (function join() {
      let tx = new TransactionBlock();
      tx.moveCall({
        target: `${pkg}::arena_pvp::join`,
        arguments: [tx.sharedObjectRef(arena)],
      });

      return signAndExecute(tx);
    })();

    if ("errors" in joinResult) {
      throw new Error(`Could not join arena: ${joinResult.errors}`);
    }
  }

  console.log(rejoin ? "Rejoined!" : "Joined!");

  while (true) {
    let { p1, p2 } = await getStats(arenaId);
    console.table([p1, p2]);
    
    let move = await chooseMove();
    let attackResult = await (function attack() {
      let tx = new TransactionBlock();
      tx.moveCall({
        target: `${pkg}::arena_pvp::attack`,
        arguments: [tx.sharedObjectRef(arena), tx.pure(move, "u8")],
      });
      return signAndExecute(tx);
    })();

    console.log(attackResult.events);
  }
}

/** Create an arena and wait for another player */
async function createArena() {
  await checkOrRequestGas();

  // Run the create arena transaction

  let tx = new TransactionBlock();
  tx.moveCall({ target: `${pkg}::arena_pvp::new` });
  let result = await signAndExecute(tx);

  let event = result.events[0].parsedJson;
  let gasData = result.objectChanges.find((o) =>
    o.objectType.includes("sui::SUI")
  );
  let arenaData = result.objectChanges.find((o) =>
    o.objectType.includes("arena_pvp::Arena")
  );

  console.log("Arena Created", event.arena);

  /* The Arena object; shared and never changes */
  const arena = {
    mutable: true,
    objectId: arenaData.objectId,
    initialSharedVersion: arenaData.version,
  };

  /* The gas object that we used for this transaction */
  let gasObj = {
    digest: gasData.digest,
    objectId: gasData.objectId,
    version: gasData.version,
  };

  // Now wait until another player joins. This is a blocking call.
  console.log("Waiting for another player to join...");

  let player_two = null;
  let joinUnsub = await listenToArenaEvents(arena.objectId, (event) => {
    console.log(event);
    player_two = event.sender;
  });

  await waitUntil(() => player_two !== null);
  await joinUnsub();

  console.log("Player 2 joined! %s", player_two);
  console.log("Starting the battle!");

  while (true) {
    console.log('[NEXT ROUND]');
    let { p1, p2 } = await getStats(arena.objectId);
    console.table([ p1, p2 ]);

    let p2_moved = false;
    let moveUnsub = await listenToArenaEvents(arena.objectId, (event) => {
      if (event.sender === player_two) { p2_moved = true; }
      console.log(event.type.split('::').slice(1).join('::'));
    });

    let p1_move = await chooseMove();
    let moveResult = await (function attack() {
      let tx = new TransactionBlock();
      tx.moveCall({
        target: `${pkg}::arena_pvp::attack`,
        arguments: [ tx.sharedObjectRef(arena), tx.pure(p1_move, 'u8') ]
      });
      return signAndExecute(tx);
    })();

    console.log(moveResult.events, moveResult.objectChanges);

    await waitUntil(() => p2_moved);
    await moveUnsub();

    console.log('Both players have chosen a move, calculating...');

    let roundResult = await (function round() {
      let tx = new TransactionBlock();
      tx.moveCall({
        target: `${pkg}::arena_pvp::round`,
        arguments: [ tx.sharedObjectRef(arena) ]
      });
      return signAndExecute(tx);
    })();



    console.log(roundResult.events, roundResult.objectChanges);
  }

  return;

  // while (true) {

  //     let tx = new TransactionBlock();
  //     tx.setGasPayment([ gasObj ]);
  //     tx.setGasBudget('1000000000');
  //     tx.moveCall({
  //         target: `${pkg}::arena::attack`,
  //         arguments: [
  //             tx.sharedObjectRef(arena),
  //             tx.pure(move, 'u8')
  //         ]
  //     });

  //     let result = await signAndExecute(tx);
  //     let gasData = result.objectChanges.find((o) => o.objectType.includes('sui::SUI'));
  //     let event = result.events.map((e) => e.parsedJson)[0];

  //     // update gas to not fetch it again
  //     gasObj = { digest: gasData.digest, objectId: gasData.objectId, version: gasData.version };

  //     console.table([
  //         { name: 'Player', HP: +event.player_hp / (100000000) },
  //         { name: 'Bot', HP: +event.bot_hp / (100000000) }
  //     ]);
  // }

  // console.log(result);
}

/** Fetch current stats of both players */
async function getStats(arenaId) {
  let object = await client.getObject({ id: arenaId, options: { showContent: true }});
  let fields = object.data.content.fields;

  return {
    p1: fields.player_one.fields.stats.fields,
    p2: fields.player_two.fields.stats.fields
  };
}

/** Subscribe to all emitted events for a specified arena */
function listenToArenaEvents(arenaId, cb) {
  return client.subscribeEvent({
    filter: {
      All: [
        { MoveModule: { module: "arena_pvp", package: pkg } },
        { MoveEventModule: { module: "arena_pvp", package: pkg } },
        { Package: pkg },
      ],
    },
    onMessage: (event) => {
      let cond =
        event.packageId == pkg &&
        event.transactionModule == "arena_pvp" &&
        event.parsedJson.arena == arenaId;

      if (cond) {
        cb(event);
      } else {
        console.log(event);
      }
    },
  });
}

/** Sign the TransactionBlock and send the tx to the network */
function signAndExecute(tx) {
  return client.signAndExecuteTransactionBlock({
    signer: keypair,
    transactionBlock: tx,
    options: {
      showEffects: true,
      showObjectChanges: true,
      showEvents: true,
    },
  });
}

/** Prompt a list to the user */
function chooseMove() {
  return inquirer
    .prompt([
      {
        type: "list",
        name: "move",
        prefix: ">",
        message: "Choose your move",
        choices: [
          { name: "Rock", value: 0 },
          { name: "Paper", value: 1 },
          { name: "Scissors", value: 2 },
        ],
      },
    ])
    .then((res) => res.move);
}

/** Hang until the cb is truthy */
async function waitUntil(cb) {
  const wait = () => new Promise((resolve) => setTimeout(resolve, 500));
  await (async function forever() {
    if (cb()) {
      return;
    }

    return wait().then(forever);
  })();
}

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
