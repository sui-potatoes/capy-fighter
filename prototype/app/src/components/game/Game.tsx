import { useState } from "react";
import { GameTypes } from "../../helpers/game";
import { Arena } from "./Arena";

export type GameProps = {
  email: string;
}

// The game options.
export function Game() {

  const [gameStarted, setGameStarted] = useState<boolean>(false);

  const [gameType, setGameType] = useState<GameTypes>(GameTypes.PVB);

  const start = (type: GameTypes) => {
    setGameStarted(true);
  }

  const end = () => {
    setGameStarted(false);
  }

  return (
    <div className="py-12 text-center">
      <div>
        {
          !gameStarted &&
          <div>
            <p>
              Welcome back. Select one game mode from the list to start playing.
            </p>
            <div className="md:flex gap-5 justify-center py-6">
              <button onClick={() => {
                start(GameTypes.PVB);
              }}>Start a PVB match</button>
              <button>Start a PVP match</button>
              <button>Join a game</button>
            </div>
          </div>
        }


        {
          gameStarted && <Arena shouldInitGame={true} gameType={gameType} end={end} />
        }

      </div>
    </div >
  )
}
