// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { SharedObjectRef, bcs } from "@mysten/sui.js/bcs";
import { getKioskClient, getOwnedKiosk, getSuiClient } from "./account";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { KioskOwnerCap, KioskTransaction } from "@mysten/kiosk";
import { signAndExecute } from "./transactions";
import { KioskExtension } from "../hooks/useUserGameData";
import blake2b from "blake2b";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js/utils";

export const GAME_V2_PACKAGE_ID: string =
  "0xbc50935f395840be759de782cb0bd026613e7fb23ab23223f82940b7e37062fb";

export const MATCH_POOL: SharedObjectRef = {
  objectId:
    "0xc1bc67692dd2a0eac01e6bb7cd036146d5589e76cef6a415e71423c337851455",
  initialSharedVersion: 8,
  mutable: true,
};

export type PlayerType = {
  name: string;
  description: string;
  icon: string;
  value: number;
};
export type GameMoveV2 = {
  name: string;
  type: string;
  category: string;
  icon: string;
  keyStroke: string;
  soundEffect: string;
};

export const MOVES_V2: GameMoveV2[] = [
  {
    name: "Hydro Pump",
    type: "Water",
    category: "Physical",

    icon: "assets/hydro-pump.png",
    keyStroke: "KeyQ",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Aqua Tail",
    type: "Water",
    category: "Special",
    icon: "assets/aqua-tail.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Inferno",
    type: "Fire",
    category: "Physical",
    icon: "assets/inferno.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Flamethrower",
    type: "Fire",
    category: "Special",
    icon: "assets/flamethrower.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Quake Strike",
    type: "Earth",
    category: "Physical",
    icon: "assets/quake-strike.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Earthquake",
    type: "Earth",
    category: "Special",
    icon: "assets/earthquake.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Gust",
    type: "Air",
    category: "Physical",
    icon: "assets/gust.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
  {
    name: "Air Slash",
    type: "Air",
    category: "Special",
    icon: "assets/air-slash.png",
    keyStroke: "KeyW",
    soundEffect: "assets/effect.wav",
  },
];

/// The different player types we have.
export const TYPES: PlayerType[] = [
  {
    name: "Water",
    description:
      "Water is super effective against Fire; and not effective against Earth",
    icon: "assets/water.png",
    value: 0,
  },
  {
    name: "Fire",
    description:
      "Fire is super effective against Air; and not effective against Water",
    icon: "assets/fire.png",
    value: 1,
  },
  {
    name: "Earth",
    description:
      "Earth is super effective against Water; and not effective against Air",
    icon: "assets/earth.png",
    value: 2,
  },
  {
    name: "Air",
    description:
      "Air is super effective against Earth; and not effective against Fire",
    icon: "assets/air.png",
    value: 3,
  },
];

// export const createKiosk =
export async function getExtension(kioskId: string) {
  const { data, error } = await getSuiClient().getDynamicFieldObject({
    parentId: kioskId,
    name: {
      type: `0x2::kiosk_extension::ExtensionKey<${GAME_V2_PACKAGE_ID}::the_game::Game>`,
      value: {
        dummy_field: false,
      },
    },
  });

  if (error) {
    return null;
  }

  // remind me to shoot myself in the head
  //@ts-ignore-next-line
  const fields = data?.content?.fields?.value.fields;

  return {
    isEnabled: fields.is_enabled,
    permissions: +fields.permissions,
    storage: fields.storage.fields.id.id, // and for this
  };
}

export async function getPlayer(extensionStorageId: string) {
  const { data, error } = await getSuiClient().getDynamicFieldObject({
    parentId: extensionStorageId,
    name: {
      type: `${GAME_V2_PACKAGE_ID}::the_game::PlayerKey`,
      value: {
        dummy_field: false,
      },
    },
  });

  return { data, error };
}

export async function createPlayer(type: number) {
  let txb = new TransactionBlock();

  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap: await getOwnedKiosk(),
  });

  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::the_game::new_player`,
    arguments: [kioskTx.getKiosk(), kioskTx.getKioskCap(), txb.pure.u8(type)],
  });

  kioskTx.finalize();
  await signAndExecute(txb);
}

export async function getActiveMatch(extension: KioskExtension) {
  const { data, error } = await getSuiClient().getDynamicFieldObject({
    parentId: extension.storage,
    name: {
      type: `${GAME_V2_PACKAGE_ID}::the_game::MatchKey`,
      value: {
        dummy_field: false,
      },
    },
  });

//   console.log(data);

  if (error) {
    return { error };
  }

  return {
    //@ts-ignore-next-line
    matchId: data.content.fields.value,
  };
}

export async function requestNewGame() {
  const cap = await getOwnedKiosk();

  let txb = new TransactionBlock();

  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap,
  });

  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::the_game::play`,
    arguments: [
      kioskTx.getKiosk(),
      kioskTx.getKioskCap(),
      txb.sharedObjectRef(MATCH_POOL),
    ],
  });

  await signAndExecute(txb);
  return;
}

export async function cancelSearch(cap: KioskOwnerCap) {
  let txb = new TransactionBlock();

  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap,
  });

  let matchArg = txb.sharedObjectRef(MATCH_POOL);

  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::the_game::cancel_search`,
    arguments: [kioskTx.getKiosk(), matchArg, kioskTx.getKioskCap()],
  });

  kioskTx.finalize();

  await signAndExecute(txb);
}

/** Try to get the ArenaID from the MatchPool */
export async function getArenaId(matchId: string) {
  const { data, error } = await getSuiClient().getDynamicFieldObject({
    parentId: MATCH_POOL.objectId,
    name: {
      type: `0x2::object::ID`,
      value: matchId,
    },
  });

  if (error)
    return {
      error,
    };

  // @ts-ignore-next-line
  return data.content.fields.value;
}

const SALT = [1, 2, 3, 4];

export async function commit(
  moveId: number,
  arena: SharedObjectRef,
  cap: KioskOwnerCap
) {
  let data = new Uint8Array([moveId, ...SALT]);
  let hash = Array.from(blake2b(32).update(data).digest());

  let txb = new TransactionBlock();

  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap,
  });
  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::arena::commit`,
    arguments: [
      txb.sharedObjectRef(arena),
      kioskTx.getKioskCap(),
      txb.pure(bcs.vector(bcs.u8()).serialize(hash).toBytes()),
      txb.object(SUI_CLOCK_OBJECT_ID), // clock
    ],
  });

  return signAndExecute(txb);
}

export async function reveal(
  moveId: number,
  arena: SharedObjectRef,
  cap: KioskOwnerCap
) {
  let txb = new TransactionBlock();

  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap,
  });
  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::arena::reveal`,
    arguments: [
      txb.sharedObjectRef(arena),
      kioskTx.getKioskCap(),
      txb.pure.u8(moveId),
      txb.pure(
        bcs
          .vector(bcs.u8())
          .serialize([...SALT])
          .toBytes()
      ),
      txb.object(SUI_CLOCK_OBJECT_ID), // clock
    ],
  });

  return signAndExecute(txb);
}

// cleans up the game.
export async function cleanUpGame({
  arena,
  cap,
}: {
  arena: SharedObjectRef;
  cap: KioskOwnerCap;
}) {
  let txb = new TransactionBlock();
  const kioskTx = new KioskTransaction({
    kioskClient: getKioskClient(),
    transactionBlock: txb,
    cap,
  });
  let matchArg = txb.sharedObjectRef(MATCH_POOL);
  let arenaArg = txb.sharedObjectRef(arena);

  txb.moveCall({
    target: `${GAME_V2_PACKAGE_ID}::the_game::clear_arena`,
    arguments: [kioskTx.getKiosk(), arenaArg, kioskTx.getKioskCap(), matchArg],
  });

  kioskTx.finalize();

  txb.setGasBudget(10000000n);

  const res = await signAndExecute(txb);
  console.log(res);
}
