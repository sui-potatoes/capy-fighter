import { PlayerStats } from "../../../helpers/game";
import HealthBar from "./HealthBar";

export type PlayerStatsProps = {
    currentPlayer: PlayerStats | null;
    otherPlayer: PlayerStats | null;
}

function SinglePlayerStats({ player, isCurrent }: { player: PlayerStats | null; isCurrent?: boolean }) {

    const attributes: Record<string, string> = {
        level: 'Lv.',
        attack: 'Att.',
        defense: 'Def.',
        special_attack: 'Sp. Att.',
        special_defense: 'Sp. Def.',
        speed: 'Speed',
        type: 'Type',
    }

    if (!player) return <p>Waiting for player...</p>

    return (
        <div className={`hitespace-wrap break-words ${!isCurrent && 'text-right'}`}>
            <h2 className={`text-3xl ${isCurrent ? 'text-left' : 'text-right'}`}>{isCurrent ? 'YOU' : 'Other Player'}</h2>
            <div className={`${!isCurrent && 'flex justify-end'}`}>

                <HealthBar initialHp={player?.initial_hp ?? 0n} currentHp={player?.hp ?? 0n} />
            </div>
            <div className={`flex flex-wrap gap-5 ${isCurrent ? 'text-left' : 'flex justify-end'}`}>
                {
                    Object.keys(attributes).map((key: string) => {
                        return (<span className="flex-shrink-0 text-lg" key={key}>{attributes[key]}: {(key in player) && player[key]} </span>)
                    })
                }
            </div>
        </div>
    )
}

export function PlayerStatistics({ currentPlayer, otherPlayer }: PlayerStatsProps) {

    return (
        <div className="grid grid-cols-2 gap-10 items-center">
            <SinglePlayerStats player={currentPlayer} isCurrent />
            <SinglePlayerStats player={otherPlayer} />
        </div>
    )
}
