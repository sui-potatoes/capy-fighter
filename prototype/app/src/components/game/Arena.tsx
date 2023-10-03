import { useEffect, useState } from "react";
import { GameMove, GameTypes, MOVES, PlayerStats, createArena, makeArenaMove } from "../../helpers/game";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { Moves } from "./parts/Moves";
import HealthBar from "./parts/HealthBar";

export type ArenaProps = {
    shouldInitGame: boolean;
    gameId?: string;
    gameType: GameTypes;
    end: () => void;
}


export function Arena({
    shouldInitGame,
    gameId,
    gameType = GameTypes.PVB,
    end
}: ArenaProps) {


    const [isExpectingMove, setIsExpectingMove] = useState<boolean>(false);
    const [arena, setArena] = useState<SharedObjectRef | null>(null);

    const [result, setResult] = useState<string | null>(null);

    const [playerOne, setPlayerOne] = useState<PlayerStats | null>(null);
    const [playerTwo, setPlayerTwo] = useState<PlayerStats | null>(null);

    const initGame = async () => {
        const res = await createArena();
        setArena(res.arena);
        setPlayerOne(res.stats.player);
        setPlayerTwo(res.stats.bot);
        setIsExpectingMove(true);
    }

    const makeMove = async (move: GameMove) => {
        setIsExpectingMove(false);

        if (!arena || !playerOne || !playerTwo) throw new Error("Arena or players are not set.");

        const { bot_hp, player_hp } = await makeArenaMove({
            arena,
            move
        });

        setPlayerOne({
            ...playerOne,
            current_hp: player_hp
        });

        setPlayerTwo({
            ...playerTwo,
            current_hp: bot_hp
        });

        if (bot_hp.toString() === '0') {
            setResult("You Won!")
        } else if (player_hp.toString() === '0') {
            setResult("You Lost!")
        } else {
            setIsExpectingMove(true);
        }

    }

    useEffect(() => {
        if (shouldInitGame) initGame();
    }, []);


    return (

        <div>
            <div className="mb-6">
                <h3 className="text-3xl">
                    Arena Fight
                </h3>
                <a href={`https://www.suiexplorer.com/object/${arena?.objectId}?network=devnet`} className="text-blue-500"
                    target="_blank">
                    View on explorer
                </a>
            </div>


            {result &&
                <div>
                    <h2 className="text-6xl mb-6">
                        {result}
                    </h2>
                    <button onClick={end}>
                        Play Again
                    </button>
                </div>
            }

            {!result &&
                <>
                    <div className="grid grid-cols-2 gap-10">
                        <div className=" whitespace-wrap break-words">
                            <h2 className="text-3xl text-left">YOU</h2>
                            <HealthBar initialHp={playerOne?.hp ?? 0n} currentHp={playerOne?.current_hp ?? 0n} />
                        </div>
                        <div className="break-words">
                            <h2 className="text-3xl text-right">Other Player</h2>
                            <div className="flex justify-end">
                                <HealthBar initialHp={playerTwo?.hp ?? 0n} currentHp={playerTwo?.current_hp ?? 0n} />
                            </div>

                        </div>
                    </div>
                    {
                        isExpectingMove && <Moves makeMove={makeMove} />
                    }
                </>
            }

        </div>
    )
}
