import { PlayerStats } from "../../../helpers/game";
import HealthBar from "./HealthBar";

export type PlayerStatsProps = {
    currentPlayer: PlayerStats | null;
    otherPlayer: PlayerStats | null;
}

export function PlayerStatistics({ currentPlayer, otherPlayer }: PlayerStatsProps) {

    return (
        <div className="grid grid-cols-2 gap-10 items-center">
            <div className=" whitespace-wrap break-words">
                <h2 className="text-3xl text-left">YOU</h2>
                <HealthBar initialHp={currentPlayer?.initial_hp ?? 0n} currentHp={currentPlayer?.hp ?? 0n} />
                <p className="text-left">{JSON.stringify(currentPlayer)}</p>
            </div>
            <div className="break-words text-right">
                {
                    otherPlayer ? (
                        <>
                            <h2 className="text-3xl text-right">Other Player</h2>
                            <div className="flex justify-end">
                                <HealthBar initialHp={otherPlayer?.initial_hp ?? 0n} currentHp={otherPlayer?.hp ?? 0n} />
                            </div>

                            {otherPlayer && <p className="text-right">{JSON.stringify(otherPlayer)}</p>}
                        </>

                    ) : <p>Waiting for player two...</p>
                }
            </div>
        </div>
    )
}
