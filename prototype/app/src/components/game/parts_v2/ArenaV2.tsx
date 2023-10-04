import { useEffect, useState } from "react";
import { GameTypes, PlayerStats, parseGameStatsFromArena } from "../../../helpers/game";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { cleanUpGame, commit, reveal } from "../../../helpers/game_v2";
import { ArenaTitle } from "../parts/ArenaTitle";
import { ArenaResult } from "../parts/ArenaResult";
import { PlayerStatistics } from "../parts/PlayerStatistics";
import { MovesV2 } from "./Moves_v2";
import { KioskOwnerCap } from "@mysten/kiosk";
import { useBackgroundAudio } from "../../../hooks/useBackgroundAudio";

export type ArenaProps = {
    arena: SharedObjectRef;
    kiosk: KioskOwnerCap;
    end: () => void;
}
export function ArenaV2({
    kiosk,
    arena,
    end
}: ArenaProps) {
    // we play audio here.
    const { pause: pauseBgAudio } = useBackgroundAudio();

    const [isExpectingMove, setIsExpectingMove] = useState<boolean>(false);

    const [result, setResult] = useState<string | null>(null);

    const [currentPlayer, setCurrentPlayer] = useState<PlayerStats | null>(null);
    const [otherPlayer, setOtherPlayer] = useState<PlayerStats | null>(null);

    const gameFinished = async (isWinner: boolean) => {
        await cleanUpGame({
            arena,
            cap: kiosk
        });

        const audio = new Audio(isWinner ? 'assets/won.wav' : 'assets/lost.wav');
        audio.volume = 0.1;
        audio.play();

        if (isWinner) {
            setResult("You Won!");
        } else {
            setResult("You Lost!");
        }

        pauseBgAudio();
    }

    const isCurrentPlayer = (player: PlayerStats | null) => {
        if (!player) return false;
        return player.account === kiosk?.kioskId;
    }

    const getGameStatus = async (arenaId: string) => {

        setIsExpectingMove(false);
        const stats = await parseGameStatsFromArena(arenaId, true);

        const currentPlayer = isCurrentPlayer(stats.playerOne) ?
            stats.playerOne : stats.playerTwo;
        const otherPlayer = isCurrentPlayer(stats.playerTwo) ? stats.playerOne : stats.playerTwo;

        setCurrentPlayer(currentPlayer);
        setOtherPlayer(otherPlayer);

        if (currentPlayer?.hp.toString() === '0') {
            await gameFinished(false);
            return;
        } else if (otherPlayer?.hp.toString() === '0') {
            await gameFinished(true);
            return;
        }

        if (!currentPlayer) throw new Error("Cant join a game where you are not taking part");

        if (!otherPlayer) {
            // we poll to get the status of the game until another player joins.
            setTimeout(() => { getGameStatus(arenaId) }, 2500);
            return;
        }

        // if we are waiting to reveal, and the other player attacked.
        // It's time to reveal!
        if ((currentPlayer.next_attack && otherPlayer.next_attack) ||
            (currentPlayer.next_attack && currentPlayer.next_round! < otherPlayer.next_round!)) {
            console.log("Pending reveal is triggered!");
            // now we reveal.
            await reveal(Number(localStorage.getItem('lastMove') as string), arena, kiosk);
            // we refetch game state after revealing.
            getGameStatus(arenaId);

            return;
        }

        // if we are pending reveal & the other player hasn't attacked yet. We are polling until they attack.
        if (currentPlayer.next_attack && !otherPlayer.next_attack) {
            console.log("Pending reveal but waiting for the other player to commit first")
            setTimeout(() => { getGameStatus(arenaId) }, 1000);
            return;
        }
        // If we don't have the next attack, we are expecting a move.
        if (!currentPlayer.next_attack && currentPlayer.next_round! <= otherPlayer.next_round!) {
            setIsExpectingMove(true);
            return;
        }

        // in any other case. poll! :D
        setTimeout(() => {
            getGameStatus(arenaId)
        }, 1000)
    }

    /// Commits the move.
    const commitMove = async (moveId: number) => {
        localStorage.setItem('lastMove', moveId.toString());
        await commit(moveId, arena, kiosk);
        getGameStatus(arena.objectId);
        setIsExpectingMove(false);
    }

    useEffect(() => {
        getGameStatus(arena.objectId);
    }, []);


    return (

        <div className="bg-contain py-12 min-h-[600px] before:bg-black before:bg-opacity-40" style={{backgroundImage: "url('assets/bg.jpg')"}}>
            <ArenaTitle arena={arena} gameType={GameTypes.PVP_V2} />
            <ArenaResult result={result} end={end} />
            {!result &&
                <div>
                    <PlayerStatistics
                        currentPlayer={currentPlayer}
                        otherPlayer={otherPlayer} />


                    {isExpectingMove && currentPlayer &&
                        <MovesV2 playerStats={currentPlayer} makeMove={commitMove} />}

                    {!isExpectingMove && <div className="text-center py-12 block mt-3">

                        <p>Waiting for the other player's move</p>
            
                        
                        <button onClick={
                            () => {
                                cleanUpGame({
                                    arena,
                                    cap: kiosk
                                }).then(() => {
                                    window.location.reload();
                                });
               
                            }
                        }>Taking too long? End Game!</button>
                        </div>}
                </div>
            }

        </div>
    )
}
