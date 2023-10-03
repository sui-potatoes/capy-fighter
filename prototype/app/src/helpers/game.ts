import { TransactionBlock } from "@mysten/sui.js/transactions";
import { signAndExecute } from "./transactions";
import { SuiEvent, SuiObjectData } from "@mysten/sui.js/client";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { getSuiClient } from "./account";
import blake2b from 'blake2b';

export const GAME_PACKAGE_ADDRESS = '0xe9143d117939e95c9fc623760c23799420ce2173199f2668d891a87430beff48';

/// Events to track
export const PlayerJoined = '::PlayerJoined';
export const RoundResult = '::RoundResult';
export const PlayerCommit = '::PlayerCommit';
export const PlayerReveal = '::PlayerReveal';


export enum GameTypes {
    PVB = 'PVB',
    PVP = 'PVP',
}

export type GameMove = {
    name: string;
    value: number;
    icon: string;
    keyStroke: string;
}

export const MOVES: GameMove[] = [
    { name: 'Fire', value: 0, icon: 'assets/fire.png', keyStroke: 'KeyQ' },
    { name: 'Air', value: 1, icon: 'assets/air.png', keyStroke: 'KeyW' },
    { name: 'Water', value: 2, icon: 'assets/water.png', keyStroke: 'KeyE' },
];

export type GameStatus = {
    round: number;
    isOver: boolean;
    playerOne: PlayerStats | null;
    playerTwo: PlayerStats | null;
    gameId: string;
    initialSharedVersion: number;
}
export type PlayerStats = {
    attack: number;
    defense: number;
    initial_hp: bigint;
    hp: bigint;
    level: number;
    special_attack: number;
    special_defense: number;
    speed: number;
    types: number[];
    account?: string;
    next_attack?: number;
    next_round?: number;
}

export type JoinGameProps = {
    email?: string | null,
    arena: SharedObjectRef
}

export const joinAsSecondPlayer = async ({
    arena,
    email = localStorage.getItem('email')
}: JoinGameProps) => {
    if (!email) throw new Error("Account not connected");

    let txb = new TransactionBlock();

    txb.moveCall({
      target: `${GAME_PACKAGE_ADDRESS}::arena_pvp::join`,
      arguments: [txb.sharedObjectRef(arena)],
    });
  
    return signAndExecute(email, txb)
}

export const parseGameStatsFromArena = async (arenaId: string, isPvP: boolean = false) => {

    const { data } = await getSuiClient().getObject({
        id: arenaId,
        options: {
            showContent: true,
            showOwner: true // find the initialSharedVersion
        }
    });

    const fields = (data?.content as {fields: any})?.fields;

    const playerOne =  isPvP ? fields.player_one?.fields?.stats?.fields : fields.player_stats?.fields;
    const playerTwo = isPvP ? fields.player_two?.fields?.stats?.fields : fields.bot_stats?.fields;

    console.log(fields);
    return {
        playerOne: playerOne  && {...playerOne, ...(isPvP ? {
            initial_hp: fields.player_one?.fields?.starting_hp,
            account: fields.player_one?.fields?.account,
            next_attack: fields.player_one?.fields?.next_attack,
            next_round: fields.player_one?.fields?.next_round,
        } : {
            initial_hp: playerOne.hp
        })},
        playerTwo: playerTwo && {...playerTwo, ...(isPvP ? {
            initial_hp: fields.player_two?.fields?.starting_hp,
            account: fields.player_two?.fields?.account,
            next_attack: fields.player_two?.fields?.next_attack,
            next_round: fields.player_two?.fields?.next_round,
        } : {
            initial_hp: playerTwo.hp
        })},
        round: fields.round,
        isOver: fields.is_over,
        gameId: arenaId,
        //@ts-ignore-next-line
        initialSharedVersion: data?.owner?.Shared.initial_shared_version
    } as GameStatus;
}

export const parseGameStatsFromEvent = (events: SuiEvent[]) => {
    const event = events![0].parsedJson as {
        player_stats: PlayerStats,
        bot_stats: PlayerStats
    };

    return {
        player: event.player_stats,
        bot: event.bot_stats
    }
}

export type CreateArenaProps = {
    email?: string | null,
    isPvP: boolean
}

export async function createArena({
    email = localStorage.getItem('email'),
    isPvP
}: CreateArenaProps) {
    if (!email) throw new Error("Account not connected");
    const txb = new TransactionBlock();

    txb.moveCall({
        target: `${GAME_PACKAGE_ADDRESS}::${isPvP ? 'arena_pvp' : 'arena'}::new`
    });

    const { events, objectChanges } = await signAndExecute(email, txb);

    const arena = objectChanges?.find(x => 'objectType' in x 
            && 
            x.objectType.endsWith(isPvP ? 'arena_pvp::Arena': 'arena::Arena')) as SuiObjectData;

    const arenaObj = {
        mutable: true,
        objectId: arena.objectId,
        initialSharedVersion: arena.version
    };

    return {
        arena: arenaObj,
        pvpStats: isPvP && await parseGameStatsFromArena(arenaObj.objectId),
        pvbStats: parseGameStatsFromEvent(events!)
    };
}


export type MakeArenaMoveProps = {
    email?: string | null,
    arena: SharedObjectRef,
    move: GameMove
}

export async function makeArenaMove({
    email = localStorage.getItem('email'),
    arena,
    move
}: MakeArenaMoveProps) {
    if (!email) throw new Error("Account not connected");
    const txb = new TransactionBlock();

    txb.moveCall({
        target: `${GAME_PACKAGE_ADDRESS}::arena::attack`,
        arguments: [
            txb.sharedObjectRef(arena),
            txb.pure(move.value, 'u8')
        ]
    });

    const { events } = await signAndExecute(email, txb);

    const event = events![0].parsedJson as {
        bot_hp: bigint,
        player_hp: bigint
    };

    return {
        bot_hp: event.bot_hp,
        player_hp: event.player_hp
    }
}

export async function commitPvPMove({
    email = localStorage.getItem('email'),
    arena,
    move
}: MakeArenaMoveProps) {
    if (!email) throw new Error("Account not connected");

    let data = new Uint8Array([move.value, 1, 2, 3, 4]);
    let hash = Array.from(blake2b(32).update(data).digest());

    const txb = new TransactionBlock();

    txb.moveCall({
        target: `${GAME_PACKAGE_ADDRESS}::arena_pvp::commit`,
        arguments: [
            txb.sharedObjectRef(arena),
            txb.pure(hash, 'vector<u8>')
        ]
    });

    return signAndExecute(email, txb);
}

export async function revealPvPMove({
    email = localStorage.getItem('email'),
    arena,
    move
}: MakeArenaMoveProps) {
    if (!email) throw new Error("Account not connected");

    const txb = new TransactionBlock();

    txb.moveCall({
        target: `${GAME_PACKAGE_ADDRESS}::arena_pvp::reveal`,
        arguments: [
            txb.sharedObjectRef(arena),
            txb.pure(move.value, 'u8'),
            txb.pure([1,2,3,4], 'vector<u8>')
        ]
    });

    return signAndExecute(email, txb);
}



/** Subscribe to all emitted events for a specified arena */
export function listenToArenaEvents(arenaId: string, cb: (inputs: any) => void) {
    return getSuiClient().subscribeEvent({
      filter: {
        All: [
          { MoveModule: { module: "arena_pvp", package: GAME_PACKAGE_ADDRESS } },
          { MoveEventModule: { module: "arena_pvp", package: GAME_PACKAGE_ADDRESS } },
          { Package: GAME_PACKAGE_ADDRESS },
        ],
      },
      onMessage: (event: SuiEvent) => {
        let cond =
          event.packageId == GAME_PACKAGE_ADDRESS &&
          event.transactionModule == "arena_pvp" &&
          (event.parsedJson as {arena: string}).arena == arenaId;
  
        if (cond) {
          cb(event);
        } else {
          console.log("Not tracked: %o", event);
        }
      },
    });
  }
