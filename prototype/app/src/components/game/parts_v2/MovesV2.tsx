import { useEffect } from "react";
import { PlayerStats } from "../../../helpers/game";
import { GameMoveV2, MOVES_V2 } from "../../../helpers/game_v2";


export type MoveV2Props = {
    playerStats: PlayerStats,
    makeMove: (moveId: number) => void;
}
const eventCodes = ['KeyQ', 'KeyW', 'KeyE', 'KeyR'];

type MoveInput = {
    move: GameMoveV2,
    id: number
}
export function MovesV2({
    playerStats,
    makeMove
}: MoveV2Props) {

    const makeMoveHandler = ({move, id}: MoveInput) => {
        const audio = new Audio(move.soundEffect);
        audio.volume = 0.1;
        audio.play();
        makeMove(id);
    }

    const getMoves = () => {
        let moves: MoveInput[] = [];

        for (let move of playerStats.moves) {
            moves.push({
                move: MOVES_V2[move],
                id: move
            });
        }
        return moves
    }


    useEffect(() => {
        const keyDownHandler = (event: KeyboardEvent) => {
            const moveIndex = eventCodes.findIndex(x => x === event.code);

            if (moveIndex === -1) return;

            event.preventDefault();

            makeMoveHandler(getMoves()[moveIndex]);
        };

        document.addEventListener('keydown', keyDownHandler);

        return () => {
            document.removeEventListener('keydown', keyDownHandler);
        };
    }, []);

    return (
        <div>
            <h2 className="text-3xl mb-3">Choose your next move!</h2>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-5 px-6">

                {getMoves().map((move, index) => {
                    return (
                        <button key={index} className="bg-transparent border-black bg-black bg-opacity-50 py-3 md:py-6 rounded-lg"
                            onKeyUp={(e) => { console.log(e) }}
                            onClick={() => {
                                makeMoveHandler(move);
                            }
                            }>
                            <img src={move.move.icon} className="mx-auto w-16 mb-3" />
                            <p>
                                {move.move.name} - {eventCodes[index].replace('Key', '')}
                            </p>
                        </button>
                    )
                })
                }

            </div>
        </div>
    )
}
