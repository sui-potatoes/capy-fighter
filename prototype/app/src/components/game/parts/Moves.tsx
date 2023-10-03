import { useEffect } from "react";
import { GameMove, MOVES } from "../../../helpers/game";


export type MoveProps = {
    makeMove: (move: GameMove) => void;
}

export function Moves({
    makeMove
}: MoveProps) {

    useEffect(() => {
        const keyDownHandler = (event: KeyboardEvent) => {
            console.log('User pressed: ', event.key);

            if(MOVES.find(move => move.keyStroke === event.code)) {
                event.preventDefault();
                const move = MOVES.find(move => move.keyStroke === event.code);
                console
                if(move) {
                    makeMove(move);
                }
            }
        };

        document.addEventListener('keydown', keyDownHandler);

        return () => {
            document.removeEventListener('keydown', keyDownHandler);
        };
    }, []);

    return (
        <div>
            <h2 className="text-3xl mb-3">Choose your next move!</h2>

            <div className="grid md:grid-cols-3 gap-5">

                {MOVES.map((move, index) => {
                    return (
                        <button key={index} className="bg-transparent border-black py-6 rounded-lg"
                            onKeyUp={(e) => { console.log(e) }}
                            onClick={() => {
                                makeMove(move);
                            }
                            }>
                            <img src={move.icon} className="mx-auto w-16 mb-3" />
                            <p>
                                {move.name} - {move.keyStroke.replace('Key', '')}
                            </p>
                        </button>
                    )
                })
                }

            </div>
        </div>
    )
}
