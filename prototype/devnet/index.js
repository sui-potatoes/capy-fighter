// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { requestSuiFromFaucetV1, getFaucetHost } from "@mysten/sui.js/faucet";
import { fromB64 } from "@mysten/sui.js/utils";
import { program } from "commander";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import inquirer from "inquirer";

// === Sui Devnet Environment ===

const pkg = "0x52a7fd0155248a9b05006b9f6fa900a0098c61c0b99f4ce3bde4cdc1bf5e2fe4";

/** The built-in client for the application */
const client = new SuiClient({ url: getFullnodeUrl("devnet") });

/** The private key for the address; only for testing purposes */
const myKey = {
  schema: "ED25519",
  privateKey: "7rUeO3yZXxfNNHlgp+pVu8lrYIp1AC+d8BOOcTlmIi4=",
};

const keypair = Ed25519Keypair.fromSecretKey(fromB64(myKey.privateKey));
const address = keypair.toSuiAddress();

// === CLI Bits ===

program
  .name("capymon-devnet")
  .description("A prototype for Capymon on devnet")
  .version("0.0.1");

program
  .command("create-arena")
  .description("Create an arena; then wait for another player to join")
  .action(createArena);

program.parse(process.argv);

// === Commands / Actions ===

/** Create an arena and wait for another player */
async function createArena() {

    // Run the create arena transaction

    let tx = new TransactionBlock();
    tx.moveCall({ target: `${pkg}::arena::new` });
    let result = await signAndExecute(tx);
    let event = result.events[0].parsedJson;

    let gasData = result.objectChanges.find((o) => o.objectType.includes('sui::SUI'));
    let arenaData = result.objectChanges.find((o) => o.objectType.includes('arena::Arena'));

    console.log('Arena Created', event.arena);
    console.table([
        { name: 'Player', ...event.player_stats },
        { name: 'Bot', ...event.bot_stats}
    ]);

    // We need this buddy for further calls.
    const arenaObj = {
        mutable: true,
        objectId: arenaData.objectId,
        initialSharedVersion: arenaData.version
    };

    let gasObj = {
        digest: gasData.digest,
        objectId: gasData.objectId,
        version: gasData.version
    };

    while (true) {
        const { move } = await inquirer.prompt([
            {
                type: 'list',
                name: 'move',
                prefix: '>',
                message: 'Choose your move',
                choices: [
                    { name: 'Rock', value: 0 },
                    { name: 'Paper', value: 1 },
                    { name: 'Scissors', value: 2 },
                ]
            }
        ]);

        let tx = new TransactionBlock();
        tx.setGasPayment([ gasObj ]);
        tx.setGasBudget('1000000000');
        tx.moveCall({
            target: `${pkg}::arena::attack`,
            arguments: [
                tx.sharedObjectRef(arenaObj),
                tx.pure(move, 'u8')
            ]
        });

        let result = await signAndExecute(tx);
        let gasData = result.objectChanges.find((o) => o.objectType.includes('sui::SUI'));
        let event = result.events.map((e) => e.parsedJson)[0];

        // update gas to not fetch it again
        gasObj = { digest: gasData.digest, objectId: gasData.objectId, version: gasData.version };

        console.table([
            { name: 'Player', HP: +event.player_hp / (100000000) },
            { name: 'Bot', HP: +event.bot_hp / (100000000) }
        ]);
    }

    console.log(result);
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

// (async () => {
//     // check that the address has some Coins on it;
//     await client.getCoins({ owner: address }).then(console.log);
// })();

/** Request some SUI to the main address */
function requestFromFaucet() {
  return requestSuiFromFaucetV1({
    host: getFaucetHost("devnet"),
    recipient: address,
  });
}
