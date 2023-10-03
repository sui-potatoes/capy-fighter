import { TransactionBlock } from "@mysten/sui.js/transactions";
import { signAndExecute } from "./transactions";
import { SuiEvent, SuiObjectData } from "@mysten/sui.js/client";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
// import fire from "assets/fire.png";
// import air from "@/assets/air.png";
// import water from "@/assets/water.png";


export const GAME_PACKAGE_ADDRESS = '0x5ae3e0d8fe32a8282059c4ca0511a66724e590b888465ed5eb77e826d2a7d63c';

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

export type PlayerStats = {
    attack: number;
    defense: number;
    hp: bigint;
    current_hp: bigint;
    level: number;
    special_attack: number;
    special_defense: number;
    speed: number;
    types: number[];
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

export async function createArena(email: string | null = localStorage.getItem('email')) {
    if (!email) throw new Error("Account not connected");
    const txb = new TransactionBlock();

    txb.moveCall({
        target: `${GAME_PACKAGE_ADDRESS}::arena::new`
    });

    const { events, objectChanges } = await signAndExecute(email, txb);

    const arena = objectChanges?.find(x => 'objectType' in x && x.objectType.endsWith('arena::Arena')) as SuiObjectData;

    const arenaObj = {
        mutable: true,
        objectId: arena.objectId,
        initialSharedVersion: arena.version
    };
    return {
        arena: arenaObj,
        stats: parseGameStatsFromEvent(events!)
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
