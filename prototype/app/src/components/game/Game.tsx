import { useEffect, useState } from "react";
import { GameTypes, createArena, joinAsSecondPlayer, parseGameStatsFromArena } from "../../helpers/game";
import { Arena } from "./Arena";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { isValidSuiObjectId, normalizeSuiObjectId } from "@mysten/sui.js/utils";
import { unsafe_getConnectedAddress } from "../../helpers/account";
import { useSearchParams } from "react-router-dom";

export type GameProps = {
  email: string;
}

// The game options.
export function Game() {


  const [searchParams, setSearchParams] = useSearchParams();

  // Handle URL navigation here.
  useEffect(() => {
    if(searchParams.get('join')){
      setJoinGameId(normalizeSuiObjectId(searchParams.get('join') || ''));
      setJoinGame(true);
    }
  }, []);

  const [gameStarted, setGameStarted] = useState<boolean>(false);

  const [joinGame, setJoinGame] = useState<boolean>(false);
  const [joinGameId, setJoinGameId] = useState<string>('');
  const [gameType, setGameType] = useState<GameTypes>(GameTypes.PVB);
  const [arena, setArena] = useState<SharedObjectRef | null>(null);

  const searchGameAndJoin = async (gameId?: string) => {

    const game = await parseGameStatsFromArena(gameId || joinGameId, true);
  
    if(game.playerOne && game.playerTwo
          && game.playerOne.account !== unsafe_getConnectedAddress()
          && game.playerTwo.account !== unsafe_getConnectedAddress()
      ){
      throw new Error("You are not part of this game.");
    }
    const arena = {
      mutable: true, objectId: joinGameId, initialSharedVersion: game.initialSharedVersion
    };

    if(!game.playerTwo) {
      await joinAsSecondPlayer({
        arena
      });
    }
    if(game && !game.isOver) {
      setJoinGame(false);
      setArena(arena);
      setGameType(GameTypes.PVP);
      setGameStarted(true);
    }
  }

  const startPvP = async () => {
      const res = await createArena({
        isPvP: true,
      });
      setGameType(GameTypes.PVP);
      setArena(res.arena);
      setGameStarted(true);
      setJoinGame(false);
  }

  const startPvB = async () => {
    const res = await createArena({
      isPvP: false,
    });
    setGameType(GameTypes.PVB);
    setArena(res.arena);
    setGameStarted(true);
    setJoinGame(false);
  }

  const end = () => {
    setGameStarted(false);
    setArena(null);
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
                startPvB();
              }}>Start a PVB match</button>
              <button onClick={() => {
                startPvP();
              }}>Start a PVP match</button>
              <button onClick={()=>setJoinGame(!joinGame)}>Join a game</button>
            </div>
          </div>
        }
        {
          gameStarted && arena && <Arena arena={arena} gameType={gameType} end={end} />
        }

        {/* Join game by ID. */}
        {
          !gameStarted && joinGame && <div>
            <p>Enter the arena ID</p>
            <input type="text"
                    value={joinGameId}
                    className="w-[350px] block mx-auto border-black border rounded-lg px-3 mt-3 py-2"
                    placeholder="Type the arena ID"
                    onChange={(e) => {
                        setJoinGameId(e.target.value)
                    }}
                />
                      <div className='pt-12'>
                <button className="disabled:opacity-30"
                    disabled={!joinGameId || !isValidSuiObjectId(joinGameId)}
                    onClick={() => searchGameAndJoin()}
                >Join Game</button>
            </div>
            </div>
        }

      </div>
    </div >
  )
}
